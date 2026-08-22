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
        const start = p.pos;
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
            // No $-prefixed composition present — fall back to a plain
            // literal token, e.g. a resolution-body fill like
            // "init< 0 >" or "state<S0>" carrying a bare constant
            // rather than a name-composition expression.
            _ = try p.readName();
        }
        return p.src[start..p.pos];
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
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ')') break;

            var name: []const u8 = "";
            if (c != '<') {
                name = try p.readName();
                p.skipWhitespaceAndComments();
            }

            if (p.peek() != '<') return ParseError.ExpectedToken;
            _ = p.advance(); // consume '<'
            p.skipWhitespaceAndComments();

            var content: ?[]const u8 = null;
            if (p.peek() != '>') {
                const content_start = p.pos;
                while (p.pos < p.src.len and p.src[p.pos] != '>') p.pos += 1;
                content = std.mem.trim(u8, p.src[content_start..p.pos], " \t\r\n");
            }
            try p.expect('>');

            try list.append(p.allocator, .{ .name = name, .kind = kind, .content = content });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(','); // §12.4 — comma is a general, optional separator
        }
        try p.expect(')');
        return list.toOwnedSlice(p.allocator);
    }

    /// Definition first list: (name<> ...) — source places, tokens flow IN
    fn parseDefSourceList(p: *Parser) ![]const network.Place {
        return p.parsePlaceList(.source);
    }

    /// Definition second list: ($name ...) — destination places, tokens flow OUT
    fn parseDefDestList(p: *Parser) ![]const network.Place {
        try p.expect('(');
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            try list.append(p.allocator, .{ .name = name, .kind = .destination });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(','); // §12.4 — comma is a general, optional separator
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
            if (p.peek() == '$') {
                const expr = try p.parseILExpr();
                try args.append(p.allocator, expr);
            } else {
                const lit = try p.readName();
                try args.append(p.allocator, lit);
            }
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(','); // §12.4 — comma is a general, optional separator
            p.skipWhitespaceAndComments();
        }
        try p.expect(')');
        return args.toOwnedSlice(p.allocator);
    }

    /// Invocation second list: (name<> ...) — outputs returned to caller
    fn parseInvOutputList(p: *Parser) ![]const network.Place {
        return p.parsePlaceList(.source);
    }

    // ----------------------------------------------------------------
    // Resolution area
    // ----------------------------------------------------------------

    fn parseSourceFill(p: *Parser, name: []const u8) !network.Statement {
        _ = p.advance(); // consume <
        const expr = try p.parseILExpr();
        try p.expect('>');
        return network.Statement{ .fill = .{ .dest_name = name, .expr = expr } };
    }

    fn parseInvocation(p: *Parser, name: []const u8) !network.Statement {
        const args = try p.parseInvArgList();
        const outputs = try p.parseInvOutputList();
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
            if (c == '|' or c == ']') break;
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            const next = p.peek() orelse return ParseError.UnexpectedEnd;
            if (next == '<') {
                try stmts.append(p.allocator, try p.parseSourceFill(name));
            } else if (next == '(') {
                try stmts.append(p.allocator, try p.parseInvocation(name));
            } else return ParseError.UnexpectedChar;
        }
        return stmts.toOwnedSlice(p.allocator);
    }

    // ----------------------------------------------------------------
    // Constants
    // ----------------------------------------------------------------

    fn parseConstants(p: *Parser) ![]const network.TableDef {
        var tables: std.ArrayListUnmanaged(network.TableDef) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ']') break;
            if (c != '$') break;

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
                try tables.append(p.allocator, .{
                    .composed_name = composed,
                    .kind = .{ .generate = gen },
                });
            } else {
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
                try tables.append(p.allocator, .{
                    .composed_name = composed,
                    .kind = .{ .explicit = try entries.toOwnedSlice(p.allocator) },
                });
            }
        }
        return tables.toOwnedSlice(p.allocator);
    }

    // ----------------------------------------------------------------
    // Definition and entry invocation
    // ----------------------------------------------------------------

    fn parseDefinition(p: *Parser) !network.Definition {
        const name = try p.readName();
        try p.expect('[');

        // Fant order: sources first (name<>), then destinations ($name)
        const sources = try p.parseDefSourceList();
        const destinations = try p.parseDefDestList();
        const resolution = try p.parseResolution();
        _ = p.tryConsume('|');
        const constants = try p.parseConstants();
        try p.expect(']');

        return network.Definition{
            .name = name,
            .sources = sources,
            .destinations = destinations,
            .resolution = resolution,
            .constants = constants,
        };
    }

    fn parseEntryInvocation(p: *Parser, name: []const u8) !network.EntryInvocation {
        // Fant invocation order: args first ($name/literal), outputs second (name<>)
        const args = try p.parseInvArgList();
        const outputs = try p.parseInvOutputList();
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
    var p = Parser.init(allocator, source);
    var definitions: std.ArrayListUnmanaged(network.Definition) = .empty;
    var entry: ?network.EntryInvocation = null;

    while (true) {
        p.skipWhitespaceAndComments();
        if (p.pos >= p.src.len) break;

        const name_start = p.pos;
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        const next = p.peek() orelse break;

        if (next == '[') {
            p.pos = name_start;
            const def = try p.parseDefinition();
            try definitions.append(allocator, def);
        } else if (next == '(') {
            // The entry invocation can appear anywhere in the source —
            // Fant's own examples often show the call site before the
            // definitions it depends on (e.g. Example 12.40's GCD).
            // Parsing it no longer halts the whole network: keep
            // scanning so trailing definitions aren't silently dropped.
            const parsed_entry = try p.parseEntryInvocation(name);
            if (entry != null) return error.MultipleEntryInvocations;
            entry = parsed_entry;
        } else return error.UnexpectedChar;
    }

    return network.Network{
        .definitions = try definitions.toOwnedSlice(allocator),
        .entry = entry,
    };
}
