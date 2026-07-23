// parser.zig
// Recursive descent parser for the MatterScript Invocation Language
//
// Grammar:
//   network      = definition* entry?
//   definition   = name '[' dest-list source-list resolution '|' constants ']'
//   dest-list    = '(' dest* ')'
//   source-list  = '(' source* ')'
//   dest         = '$' name
//   source       = name '<>'
//   resolution   = statement*
//   statement    = source-fill | invocation
//   source-fill  = name '<' expr '>'
//   expr         = ('$' name)+ '()'?
//   invocation   = name '(' '(' arg* ')' '(' output* ')' ')'
//   constants    = table-def*
//   table-def    = composition ':' (generate-block | entry+)
//   generate     = 'generate' '{' expr 'inputs:' decls 'output:' range
//                  ('const' name '=' int)* '}'
//   entry        = key ':' value

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

    /// Check if the next non-whitespace token is this keyword, without consuming.
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
        _ = p.tryConsume(':'); // optional colon for inputs: output:
    }

    // ----------------------------------------------------------------
    // IL expression parser (source fills, composition refs)
    // ----------------------------------------------------------------

    fn parseExpr(p: *Parser) ![]const u8 {
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
        if (p.pos == start) return ParseError.ExpectedDollar;
        return p.src[start..p.pos];
    }

    // ----------------------------------------------------------------
    // Generate block expression parser (arithmetic AST)
    // ----------------------------------------------------------------

    const GenExprError = ParseError || std.mem.Allocator.Error || error{ Overflow, InvalidCharacter };
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

        // parenthesized expression
        if (p.peek() == '(') {
            _ = p.advance();
            const inner = try p.parseGenExpr();
            try p.expect(')');
            return inner;
        }

        // variable: $name
        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }

        // negative integer
        if (p.peek() == '-') {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        // positive integer
        if (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        // name — function call or constant reference
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

        // named constant
        const node = try p.allocator.create(network.Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }

    // ----------------------------------------------------------------
    // Generate block parser
    // ----------------------------------------------------------------

    fn parseGenerateBlock(p: *Parser) !network.GenerateBlock {
        // consume 'generate'
        try p.consumeKeyword("generate");
        try p.expect('{');

        // read expression source — everything up to 'inputs'
        const expr_start = p.pos;
        while (p.pos < p.src.len) {
            if (p.peekKeyword("inputs")) break;
            p.pos += 1;
        }
        const expr_src = std.mem.trim(u8, p.src[expr_start..p.pos], " \t\n\r");

        // parse the expression from extracted source
        var ep = Parser.init(p.allocator, expr_src);
        const expr = try ep.parseGenExpr();

        // inputs: $name min..max, ...
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
            try inputs.append(p.allocator, .{
                .name = name,
                .min = range.min,
                .max = range.max,
            });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
        }

        // output: min..max
        try p.consumeKeyword("output");
        const out_range = try p.readRange();

        // const name = value (zero or more)
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
    // Statement parsers
    // ----------------------------------------------------------------

    fn parseSourceFill(p: *Parser, name: []const u8) !network.Statement {
        _ = p.advance(); // consume <
        const expr = try p.parseExpr();
        try p.expect('>');
        return network.Statement{ .fill = .{ .source_name = name, .expr = expr } };
    }

    fn parseInvocation(p: *Parser, name: []const u8) !network.Statement {
        try p.expect('(');
        try p.expect('(');
        var args: std.ArrayListUnmanaged([]const u8) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() != ')' and p.peek() != null) {
            p.skipWhitespaceAndComments();
            if (p.peek() == '$') {
                const expr = try p.parseExpr();
                try args.append(p.allocator, expr);
            } else {
                const lit = try p.readName();
                try args.append(p.allocator, lit);
            }
            p.skipWhitespaceAndComments();
        }
        try p.expect(')');
        const outputs = try p.parseSourceList();
        try p.expect(')');
        return network.Statement{ .invoke = .{
            .name = name,
            .args = try args.toOwnedSlice(p.allocator),
            .outputs = outputs,
        } };
    }

    fn parseDestList(p: *Parser) ![]const network.Place {
        try p.expect('(');
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            try list.append(p.allocator, .{ .name = name, .kind = .destination });
            p.skipWhitespaceAndComments();
        }
        try p.expect(')');
        return list.toOwnedSlice(p.allocator);
    }

    fn parseSourceList(p: *Parser) ![]const network.Place {
        try p.expect('(');
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ')') break;
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            if (p.peek() != '<') return ParseError.ExpectedToken;
            _ = p.advance();
            try p.expect('>');
            try list.append(p.allocator, .{ .name = name, .kind = .source });
        }
        try p.expect(')');
        return list.toOwnedSlice(p.allocator);
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

    fn parseConstants(p: *Parser) ![]const network.TableDef {
        var tables: std.ArrayListUnmanaged(network.TableDef) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse break;
            if (c == ']') break;
            if (c != '$') break;

            // read composed name: $a$b()
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

            // decide: generate block or explicit entries
            if (p.peekKeyword("generate")) {
                const gen = try p.parseGenerateBlock();
                try tables.append(p.allocator, .{
                    .composed_name = composed,
                    .kind = .{ .generate = gen },
                });
            } else {
                // explicit key:value pairs
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

    fn parseDefinition(p: *Parser) !network.Definition {
        const name = try p.readName();
        try p.expect('[');
        const destinations = try p.parseDestList();
        const sources = try p.parseSourceList();
        const resolution = try p.parseResolution();
        _ = p.tryConsume('|');
        const constants = try p.parseConstants();
        try p.expect(']');
        return network.Definition{
            .name = name,
            .destinations = destinations,
            .sources = sources,
            .resolution = resolution,
            .constants = constants,
        };
    }

    fn parseEntry(p: *Parser, name: []const u8) !network.EntryInvocation {
        try p.expect('(');
        try p.expect('(');
        var args: std.ArrayListUnmanaged([]const u8) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() != ')' and p.peek() != null) {
            p.skipWhitespaceAndComments();
            if (p.peek() == '$') {
                _ = p.advance();
                const n = try p.readName();
                try args.append(p.allocator, n);
            } else {
                const lit = try p.readName();
                try args.append(p.allocator, lit);
            }
            p.skipWhitespaceAndComments();
        }
        try p.expect(')');
        const outputs = try p.parseSourceList();
        try p.expect(')');
        return network.EntryInvocation{
            .name = name,
            .args = try args.toOwnedSlice(p.allocator),
            .outputs = outputs,
        };
    }
};

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
            entry = try p.parseEntry(name);
            break;
        } else return error.UnexpectedChar;
    }

    return network.Network{
        .definitions = try definitions.toOwnedSlice(allocator),
        .entry = entry,
    };
}
