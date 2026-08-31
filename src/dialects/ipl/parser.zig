// parser.zig
// Recursive descent parser for the MatterScript Invocation Language
//
// Authoritative grammar (Fant 2007 p.203):
//
//   Invocation:  NAME($dest1 $dest2)(source1<> source2<>)
//   Definition:  NAME[(source1<> source2<>)($dest1 $dest2) resolution : tables ]
//
//   In a definition:
//     first list  = source places (name<>) — tokens flow IN from outside
//     second list = destination places ($name) — tokens flow OUT to outside
//
//   In an invocation:
//     first list  = destination args ($name or literal) — values passed to definition sources
//     second list = source places (name<>) — outputs returned to caller

const std = @import("std");
const network = @import("network.zig");

pub const ParseError = error{
    UnexpectedEnd,
    UnexpectedChar,
    ExpectedName,
    ExpectedToken,
    ExpectedDollar,
    ExpectedBracket,
    ExpectedColon,
    ExpectedInteger,
    ExpectedRange,
    UnknownFunction,
    OutOfMemory,
};

const Parser = struct {
    src: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,
    last_expr: ?*const network.Expr = null,

    fn init(allocator: std.mem.Allocator, src: []const u8) Parser {
        return .{ .src = src, .pos = 0, .allocator = allocator };
    }

    fn peek(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        return p.src[p.pos];
    }

    fn advance(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        const c = p.src[p.pos];
        p.pos += 1;
        return c;
    }

    fn skipWhitespaceAndComments(p: *Parser) void {
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                p.pos += 1;
            } else if (c == '/' and p.pos + 1 < p.src.len and
                p.src[p.pos + 1] == '/')
            {
                while (p.pos < p.src.len and p.src[p.pos] != '\n') p.pos += 1;
            } else break;
        }
    }

    fn parseDirective(p: *Parser) !network.Statement {
        _ = p.advance(); // consume '@'
        const name = try p.readName();
        try p.expect('(');
        const args_start = p.pos;
        var depth: usize = 1;
        while (depth > 0) {
            const ch = p.advance() orelse return ParseError.UnexpectedEnd;
            if (ch == '(') depth += 1;
            if (ch == ')') depth -= 1;
        }
        const args = p.src[args_start .. p.pos - 1]; // exclude the closing ')'
        return network.Statement{ .directive = .{ .name = name, .args = args } };
    }

    fn expect(p: *Parser, ch: u8) !void {
        p.skipWhitespaceAndComments();
        if (p.peek() != ch) return ParseError.ExpectedToken;
        _ = p.advance();
    }

    fn tryConsume(p: *Parser, ch: u8) bool {
        p.skipWhitespaceAndComments();
        if (p.peek() == ch) {
            _ = p.advance();
            return true;
        }
        return false;
    }

    fn readName(p: *Parser) ![]const u8 {
        p.skipWhitespaceAndComments();
        const start = p.pos;
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_') p.pos += 1 else break;
        }
        if (p.pos == start) return ParseError.ExpectedName;
        return p.src[start..p.pos];
    }

    fn readInteger(p: *Parser) !i64 {
        p.skipWhitespaceAndComments();
        const negative = p.tryConsume('-');
        const start = p.pos;
        while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos]))
            p.pos += 1;
        if (p.pos == start) return ParseError.ExpectedInteger;
        const val = try std.fmt.parseInt(i64, p.src[start..p.pos], 10);
        return if (negative) -val else val;
    }

    fn readRange(p: *Parser) !struct { min: i64, max: i64 } {
        const min = try p.readInteger();
        p.skipWhitespaceAndComments();
        if (p.pos + 1 >= p.src.len or
            p.src[p.pos] != '.' or p.src[p.pos + 1] != '.')
            return ParseError.ExpectedRange;
        p.pos += 2;
        const max = try p.readInteger();
        return .{ .min = min, .max = max };
    }

    fn peekKeyword(p: *Parser, kw: []const u8) bool {
        const saved = p.pos;
        p.skipWhitespaceAndComments();
        const start = p.pos;
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_') p.pos += 1 else break;
        }
        const word = p.src[start..p.pos];
        p.pos = saved;
        return std.mem.eql(u8, word, kw);
    }

    fn consumeKeyword(p: *Parser, kw: []const u8) !void {
        p.skipWhitespaceAndComments();
        const name = try p.readName();
        if (!std.mem.eql(u8, name, kw)) return ParseError.ExpectedName;
        _ = p.tryConsume(':');
    }

    // ----------------------------------------------------------------
    // IL source-fill expression parser (composition refs like $a$b())
    // ----------------------------------------------------------------

    fn parseILExpr(p: *Parser) ![]const u8 {
        p.skipWhitespaceAndComments();
        p.last_expr = null;
        const start = p.pos;
        if (p.pos < p.src.len and
            (std.ascii.isAlphanumeric(p.src[p.pos]) or p.src[p.pos] == '_'))
        {
            const saved = p.pos;
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            if (p.peek() == '(') {
                _ = p.advance();
                var args: std.ArrayListUnmanaged(*network.Expr) = .empty;
                p.skipWhitespaceAndComments();
                while (p.peek() != ')' and p.peek() != null) {
                    const arg = try p.parseILCallArgument();
                    try args.append(p.allocator, arg);
                    p.skipWhitespaceAndComments();
                    _ = p.tryConsume(',');
                    p.skipWhitespaceAndComments();
                }
                try p.expect(')');
                const call = try p.allocator.create(network.Expr);
                call.* = .{
                    .kind = .call,
                    .func = name,
                    .args = try args.toOwnedSlice(p.allocator),
                };
                p.last_expr = call;
                return p.src[start..p.pos];
            }
            p.pos = saved;
        }
        while (p.peek() == '$') {
            _ = p.advance();
            _ = try p.readName();
        }
        p.skipWhitespaceAndComments();
        if (p.peek() == '(') {
            _ = p.advance();
            try p.expect(')');
        }
        if (p.pos == start) {
            // No $-composition present. Try a plain literal token
            // (e.g. "init< 0 >"); if there isn't one either — the
            // content is genuinely empty, "<>" — that's valid too
            // (an unnamed/empty fill, §12.3.4), so don't error.
            if (p.pos < p.src.len and
                (std.ascii.isAlphanumeric(p.src[p.pos]) or p.src[p.pos] == '_'))
            {
                _ = try p.readName();
            }
        }
        return p.src[start..p.pos];
    }

    fn parseILCallArgument(p: *Parser) !*network.Expr {
        p.skipWhitespaceAndComments();

        // 1. Variable references ($var)
        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }

        // 2. Numeric literals (integers, floats, negative values)
        const start = p.pos;
        if (p.peek() == '-') _ = p.advance();
        if (p.pos < p.src.len and (std.ascii.isDigit(p.src[p.pos]) or p.src[p.pos] == '.')) {
            while (p.pos < p.src.len and (std.ascii.isDigit(p.src[p.pos]) or p.src[p.pos] == '.')) {
                p.pos += 1;
            }
            const val_str = p.src[start..p.pos];
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .constant, .name = val_str };
            return node;
        }

        // 3. Standard identifiers
        const name = try p.readName();
        const node = try p.allocator.create(network.Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }

    // ----------------------------------------------------------------
    // Generate block expression parser (arithmetic AST)
    // ----------------------------------------------------------------

    const GenExprError = ParseError ||
        std.mem.Allocator.Error ||
        error{ Overflow, InvalidCharacter };

    fn parseGenExpr(p: *Parser) GenExprError!*network.Expr {
        return p.parseGenAddSub();
    }

    fn parseGenAddSub(p: *Parser) GenExprError!*network.Expr {
        var left = try p.parseGenMulDiv();
        while (true) {
            p.skipWhitespaceAndComments();
            const op: network.BinaryOp = if (p.peek() == '+') .add else if (p.peek() == '-') .sub else break;
            _ = p.advance();
            const right = try p.parseGenMulDiv();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .binary, .op = op, .left = left, .right = right };
            left = node;
        }
        return left;
    }

    fn parseGenMulDiv(p: *Parser) GenExprError!*network.Expr {
        var left = try p.parseGenAtom();
        while (true) {
            p.skipWhitespaceAndComments();
            const op: network.BinaryOp = if (p.peek() == '*') .mul else if (p.peek() == '/') .div else break;
            _ = p.advance();
            const right = try p.parseGenAtom();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .binary, .op = op, .left = left, .right = right };
            left = node;
        }
        return left;
    }

    fn parseGenAtom(p: *Parser) GenExprError!*network.Expr {
        p.skipWhitespaceAndComments();

        if (p.peek() == '(') {
            _ = p.advance();
            const inner = try p.parseGenExpr();
            try p.expect(')');
            return inner;
        }

        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }

        if (p.peek() == '-') {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        if (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        const name = try p.readName();
        p.skipWhitespaceAndComments();
        if (p.peek() == '(') {
            _ = p.advance();
            var args: std.ArrayListUnmanaged(*network.Expr) = .empty;
            p.skipWhitespaceAndComments();
            while (p.peek() != ')' and p.peek() != null) {
                const arg = try p.parseGenExpr();
                try args.append(p.allocator, arg);
                p.skipWhitespaceAndComments();
                _ = p.tryConsume(',');
                p.skipWhitespaceAndComments();
            }
            try p.expect(')');
            const node = try p.allocator.create(network.Expr);
            node.* = .{
                .kind = .call,
                .func = name,
                .args = try args.toOwnedSlice(p.allocator),
            };
            return node;
        }

        const node = try p.allocator.create(network.Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }

    // ----------------------------------------------------------------
    // Generate block
    // ----------------------------------------------------------------

    fn parseGenerateBlock(p: *Parser) !network.GenerateBlock {
        try p.consumeKeyword("generate");
        try p.expect('{');

        const expr_start = p.pos;
        while (p.pos < p.src.len) {
            if (p.peekKeyword("inputs")) break;
            p.pos += 1;
        }
        const expr_src = std.mem.trim(u8, p.src[expr_start..p.pos], " \t\n\r");

        var ep = Parser.init(p.allocator, expr_src);
        const expr = try ep.parseGenExpr();

        try p.consumeKeyword("inputs");
        var inputs: std.ArrayListUnmanaged(network.InputDecl) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            if (p.peek() != '$') break;
            if (p.peekKeyword("output")) break;
            _ = p.advance(); // $
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            const range = try p.readRange();
            try inputs.append(p.allocator, .{ .name = name, .min = range.min, .max = range.max });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
        }

        try p.consumeKeyword("output");
        const out_range = try p.readRange();

        var constants: std.ArrayListUnmanaged(network.ConstDecl) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            if (p.peek() == '}') break;
            if (!p.peekKeyword("const")) break;
            try p.consumeKeyword("const");
            const name = try p.readName();
            try p.expect('=');
            const val = try p.readInteger();
            try constants.append(p.allocator, .{ .name = name, .value = val });
        }

        try p.expect('}');

        return network.GenerateBlock{
            .expr = expr,
            .inputs = try inputs.toOwnedSlice(p.allocator),
            .output_min = out_range.min,
            .output_max = out_range.max,
            .constants = try constants.toOwnedSlice(p.allocator),
        };
    }

    // ----------------------------------------------------------------
    // Definition list parsers (corrected Fant order)
    // ----------------------------------------------------------------

    /// Shared parser for "(name<> ...)"-style lists — a definition's
    /// source-place list and an invocation's output list share
    /// identical grammar. Handles three forms per Fant §12.3.4:
    ///   name<>        — normal named, empty place
    ///   name<content> — named place carrying literal content (state<S0>)
    ///   <>  / <content> — unnamed place (abbreviated single-return
    ///                     form), represented as Place{ .name = "" }
    fn parsePlaceList(p: *Parser, kind: network.PlaceKind) ![]const network.Place {
        try p.expect('(');
        const list = try p.parsePlaceSequence(kind, ')', false);
        try p.expect(')');
        return list;
    }

    fn parsePlaceSequence(
        p: *Parser,
        kind: network.PlaceKind,
        terminator: u8,
        definition_destinations: bool,
    ) ![]const network.Place {
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == terminator) break;

            if (c == '{' or c == '[') {
                const group_kind: network.PlaceGroupKind = if (c == '{') .mutex else .bundle;
                const closing: u8 = if (c == '{') '}' else ']';
                const group_start = p.pos;
                _ = p.advance();
                p.skipWhitespaceAndComments();
                const has_nested_lists = p.peek() == '(';
                p.pos = group_start;
                const raw_group = if (has_nested_lists)
                    try p.consumeBalanced(c, closing)
                else
                    null;
                const places = if (raw_group != null) &.{} else blk: {
                    _ = p.advance();
                    const nested = try p.parsePlaceSequence(kind, closing, definition_destinations);
                    try p.expect(closing);
                    break :blk nested;
                };
                const group = try p.allocator.create(network.PlaceGroup);
                group.* = .{ .kind = group_kind, .places = places };
                try list.append(p.allocator, .{
                    .name = "{group}",
                    .kind = kind,
                    .content = raw_group,
                    .group = group,
                });
            } else {
                var name: []const u8 = "";
                if (definition_destinations) {
                    try p.expect('$');
                    name = try p.readName();
                    try list.append(p.allocator, .{ .name = name, .kind = kind });
                    p.skipWhitespaceAndComments();
                    _ = p.tryConsume(',');
                    continue;
                } else if (c != '<') name = try p.readName();
                p.skipWhitespaceAndComments();
                if (p.peek() != '<') {
                    if (kind == .destination) return ParseError.ExpectedToken;
                    return ParseError.ExpectedToken;
                }
                _ = p.advance();
                p.skipWhitespaceAndComments();
                var content: ?[]const u8 = null;
                if (p.peek() != '>') {
                    const content_start = p.pos;
                    while (p.pos < p.src.len and p.src[p.pos] != '>') p.pos += 1;
                    content = std.mem.trim(u8, p.src[content_start..p.pos], " \t\r\n");
                }
                try p.expect('>');
                try list.append(p.allocator, .{ .name = name, .kind = kind, .content = content });
            }
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
        }
        return list.toOwnedSlice(p.allocator);
    }

    /// Consume a balanced-delimiter span starting at the current
    /// position, returning the full text including both delimiters.
    /// Used for brace groups ({...} — mutex/conditional completeness,
    /// §12.5.2/12.5.3) and bundle brackets ([...] — bundling/
    /// unbundling, §12.6). Each call only tracks its own delimiter's
    /// depth, so the two kinds nest inside each other transparently —
    /// a "[" span just copies through any "{"/"}" it encounters as
    /// inert content, and vice versa.
    fn consumeBalanced(p: *Parser, open: u8, close: u8) ![]const u8 {
        const start = p.pos;
        _ = p.advance();
        var depth: usize = 1;
        while (depth > 0) {
            const ch = p.advance() orelse return ParseError.UnexpectedEnd;
            if (ch == open) depth += 1;
            if (ch == close) depth -= 1;
        }
        return p.src[start..p.pos];
    }

    /// Definition first list: (name<> ...) — source places, tokens flow IN
    fn parseDefSourceList(p: *Parser) ![]const network.Place {
        return p.parsePlaceList(.source);
    }

    fn parseDefDestList(p: *Parser) ![]const network.Place {
        try p.expect('(');
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ')') break;

            if (c == '{' or c == '[') {
                const span = if (c == '{')
                    try p.consumeBalanced('{', '}')
                else
                    try p.consumeBalanced('[', ']');
                try list.append(p.allocator, .{
                    .name = if (c == '{') "{group}" else "[bundle]",
                    .kind = .destination,
                    .content = span,
                });
                p.skipWhitespaceAndComments();
                _ = p.tryConsume(',');
                continue;
            }

            if (c != '$') break;
            _ = p.advance();
            const name = try p.readName();
            try list.append(p.allocator, .{ .name = name, .kind = .destination });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
        }
        try p.expect(')');
        return list.toOwnedSlice(p.allocator);
    }

    /// Invocation first list: ($name or literal ...) — args passed to definition sources
    fn parseInvArgList(p: *Parser) ![]const []const u8 {
        try p.expect('(');
        var args: std.ArrayListUnmanaged([]const u8) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() != ')' and p.peek() != null) {
            p.skipWhitespaceAndComments();
            const c = p.peek().?;
            if (c == '{' or c == '[') {
                const span = if (c == '{')
                    try p.consumeBalanced('{', '}')
                else
                    try p.consumeBalanced('[', ']');
                try args.append(p.allocator, span);
            } else if (c == '$') {
                const expr = try p.parseILExpr();
                try args.append(p.allocator, expr);
            } else {
                const lit = try p.readName();
                try args.append(p.allocator, lit);
            }
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
            p.skipWhitespaceAndComments();
        }
        try p.expect(')');
        return args.toOwnedSlice(p.allocator);
    }

    /// Invocation second list: (name<> ...) — outputs returned to caller
    fn parseInvOutputList(p: *Parser) ![]const network.Place {
        return p.parsePlaceList(.source);
    }

    /// Reads a name that may be split into comma-separated segments
    /// (§12.4 — the comma is a general, freely-insertable separator).
    /// Used for contained-definition names formed by composition,
    /// where a segment boundary would otherwise be ambiguous (e.g.
    /// "0,S0" rather than the unsplittable "0S0"). Returns the
    /// segments joined with a single comma, e.g. "0,S0" — downstream
    /// consumers should split on ',' and trim each segment, to
    /// tolerate incidental whitespace like "0, S0".
    fn readCommaSeparatedName(p: *Parser) ![]const u8 {
        const start = p.pos;
        _ = try p.readName();
        while (true) {
            const save = p.pos;
            p.skipWhitespaceAndComments();
            if (p.peek() != ',') {
                p.pos = save;
                break;
            }
            _ = p.advance(); // consume ','
            p.skipWhitespaceAndComments();
            _ = p.readName() catch {
                p.pos = save;
                break;
            };
        }
        return p.src[start..p.pos];
    }

    // ----------------------------------------------------------------
    // Resolution area
    // ----------------------------------------------------------------

    fn parseSourceFill(p: *Parser, name: []const u8) !network.Statement {
        _ = p.advance(); // consume <
        const expr = try p.parseILExpr();
        try p.expect('>');
        return network.Statement{ .fill = .{
            .dest_name = name,
            .expr = expr,
            .parsed_expr = p.last_expr,
        } };
    }

    fn parseInvocation(p: *Parser, name: []const u8) !network.Statement {
        const args = try p.parseInvArgList();
        p.skipWhitespaceAndComments();
        const outputs: []const network.Place = if (p.peek() == '(')
            try p.parseInvOutputList()
        else
            &.{}; // §12.3.4 — output list omitted, implicit single
        // unnamed return
        return network.Statement{ .invoke = .{
            .name = name,
            .args = args,
            .outputs = outputs,
        } };
    }

    fn parseResolution(p: *Parser) ![]const network.Statement {
        var stmts: std.ArrayListUnmanaged(network.Statement) = .empty;

        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ':' or c == ']') break;

            if (c == '@') {
                try stmts.append(p.allocator, try p.parseDirective());
                continue;
            }

            if (c == '<') {
                try stmts.append(p.allocator, try p.parseSourceFill(""));
                continue;
            }

            if (c == '$') {
                const expr = try p.parseILExpr();
                try stmts.append(p.allocator, .{ .pure_value = expr });
                continue;
            }

            const tok_start = p.pos;
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            const next = p.peek() orelse return ParseError.UnexpectedEnd;
            if (next == '<') {
                try stmts.append(p.allocator, try p.parseSourceFill(name));
            } else if (next == '(') {
                try stmts.append(p.allocator, try p.parseInvocation(name));
            } else if (next == ',') {
                p.pos = tok_start;
                const full = try p.readCommaSeparatedName();
                try stmts.append(p.allocator, .{ .pure_value = full });
            } else if (next == ':' or next == ']') {
                try stmts.append(p.allocator, .{ .pure_value = p.src[tok_start..p.pos] });
            } else return ParseError.UnexpectedChar;
        }
        return stmts.toOwnedSlice(p.allocator);
    }

    // ----------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------

    /// Parses a single $-composed constant table: "$a$b() : entries" or
    /// "$a$b() : generate { ... }".
    fn parseOneConstantTable(p: *Parser) !network.TableDef {
        const start = p.pos;
        while (p.peek() == '$') {
            _ = p.advance();
            _ = try p.readName();
        }
        try p.expect('(');
        try p.expect(')');
        const composed = p.src[start..p.pos];
        try p.expect(':');
        p.skipWhitespaceAndComments();

        if (p.peekKeyword("generate")) {
            const gen = try p.parseGenerateBlock();
            return .{ .composed_name = composed, .kind = .{ .generate = gen } };
        }

        var entries: std.ArrayListUnmanaged(network.TableEntry) = .empty;
        while (p.pos < p.src.len) {
            p.skipWhitespaceAndComments();
            const d = p.peek() orelse break;
            if (d == ']' or d == '$') break;
            const key = try p.readName();
            try p.expect(':');
            const val = try p.readName();
            try entries.append(p.allocator, .{ .key = key, .value = val });
        }
        return .{ .composed_name = composed, .kind = .{ .explicit = try entries.toOwnedSlice(p.allocator) } };
    }

    /// Parses everything after a definition's resolution-terminating ':'
    /// — Fant's "contained definitions" position (§12.3.2). Can hold
    /// $-composed constant tables and/or genuine nested Definitions
    /// (with their own sources/destinations/resolution), in any order.
    fn parseContainedSection(p: *Parser) anyerror!struct {
        constants: []const network.TableDef,
        contained: []const network.Definition,
    } {
        var tables: std.ArrayListUnmanaged(network.TableDef) = .empty;
        var nested: std.ArrayListUnmanaged(network.Definition) = .empty;

        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ']') break;

            if (c == '$') {
                try tables.append(p.allocator, try p.parseOneConstantTable());
                continue;
            }

            if (std.ascii.isAlphanumeric(c) or c == '_') {
                const save = p.pos;
                _ = p.readCommaSeparatedName() catch {
                    p.pos = save;
                    break;
                };
                p.skipWhitespaceAndComments();
                if (p.peek() == '[') {
                    p.pos = save;
                    const def = try p.parseDefinition();
                    try nested.append(p.allocator, def);
                    continue;
                }
                p.pos = save;
                break;
            }

            break;
        }

        return .{
            .constants = try tables.toOwnedSlice(p.allocator),
            .contained = try nested.toOwnedSlice(p.allocator),
        };
    }

    // ----------------------------------------------------------------
    // Definition and entry invocation
    // ----------------------------------------------------------------
    fn parseDefinition(p: *Parser) anyerror!network.Definition {
        const name = try p.readCommaSeparatedName();
        try p.expect('[');

        p.skipWhitespaceAndComments();
        const sources: []const network.Place = if (p.peek() == '(')
            try p.parseDefSourceList()
        else
            &.{};

        p.skipWhitespaceAndComments();
        const destinations: []const network.Place = if (p.peek() == '(')
            try p.parseDefDestList()
        else
            &.{};

        const resolution = try p.parseResolution();
        _ = p.tryConsume(':');
        const section = try p.parseContainedSection();
        try p.expect(']');

        return network.Definition{
            .name = name,
            .sources = sources,
            .destinations = destinations,
            .resolution = resolution,
            .constants = section.constants,
            .contained = section.contained,
        };
    }

    fn parseEntryInvocation(p: *Parser, name: []const u8) !network.EntryInvocation {
        // Fant invocation order: args first ($name/literal), outputs second (name<>)
        const args = try p.parseInvArgList();
        p.skipWhitespaceAndComments();
        const outputs: []const network.Place = if (p.peek() == '(')
            try p.parseInvOutputList()
        else
            &.{}; // §12.3.4 — output list omitted, implicit single
        // unnamed return to the place of the invocation
        return network.EntryInvocation{
            .name = name,
            .args = args,
            .outputs = outputs,
        };
    }
}; // <-- Parser struct closes HERE, not at the end of the file

// ----------------------------------------------------------------
// Public API
// ----------------------------------------------------------------

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !network.Network {
    return parseWithTag(allocator, source, null);
}

pub fn parseWithTag(
    allocator: std.mem.Allocator,
    source: []const u8,
    tag: ?[]const u8,
) !network.Network {
    var p = Parser.init(allocator, source);
    return parseInner(&p, allocator) catch |err| {
        reportError(&p, err, tag);
        return err;
    };
}

fn parseInner(p: *Parser, allocator: std.mem.Allocator) !network.Network {
    var definitions: std.ArrayListUnmanaged(network.Definition) = .empty;
    var entries: std.ArrayListUnmanaged(network.EntryInvocation) = .empty;
    var free_refs: std.ArrayListUnmanaged([]const u8) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        if (p.pos >= p.src.len) break;

        if (p.peek() == ':') {
            _ = p.advance();
            continue;
        }

        // A bare $name at the top level is a free-floating "outlying
        // destination place" (§12.7) — not attached to any invocation
        // or definition structure. Zero or more may appear anywhere.
        if (p.peek() == '$') {
            _ = p.advance();
            const ref_name = try p.readName();
            try free_refs.append(allocator, ref_name);
            continue;
        }

        const name_start = p.pos;
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        const next = p.peek() orelse break;

        if (next == '[') {
            p.pos = name_start;
            const def = try p.parseDefinition();
            try definitions.append(allocator, def);
        } else if (next == '(') {
            const parsed_entry = try p.parseEntryInvocation(name);
            try entries.append(allocator, parsed_entry);
        } else return error.UnexpectedChar;
    }

    return network.Network{
        .definitions = try definitions.toOwnedSlice(allocator),
        .entries = try entries.toOwnedSlice(allocator),
        .free_destinations = try free_refs.toOwnedSlice(allocator),
    };
}

/// On parse failure, print the 1-indexed line/column and the offending
/// line's text. p.pos reflects wherever the deepest failing call left
/// it — Parser is threaded through every function by pointer and never
/// rewound except at a couple of controlled backtrack points — so this
/// works without touching any individual parse function.
///
/// Known gap: parseGenerateBlock spins up a *second*, independent
/// Parser over an extracted sub-string for generate-block expressions.
/// A failure inside that inner parser won't be reflected here — the
/// outer p.pos will just show wherever parseGenerateBlock was called
/// from, not the actual failure point within the expression.
fn reportError(p: *const Parser, err: anyerror, tag: ?[]const u8) void {
    var line: usize = 1;
    var col: usize = 1;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i < p.pos and i < p.src.len) : (i += 1) {
        if (p.src[i] == '\n') {
            line += 1;
            col = 1;
            line_start = i + 1;
        } else {
            col += 1;
        }
    }
    var line_end = line_start;
    while (line_end < p.src.len and p.src[line_end] != '\n') line_end += 1;
    const line_text = p.src[line_start..line_end];

    if (tag) |issue_tag| std.debug.print("  [{s}]\n", .{issue_tag});
    std.debug.print("  parse error: {s} at line {d}, column {d}\n", .{ @errorName(err), line, col });
    std.debug.print("    {s}\n", .{line_text});
    std.debug.print("    ", .{});
    var j: usize = 1;
    while (j < col) : (j += 1) std.debug.print(" ", .{});
    std.debug.print("^\n\n", .{});
}
