// parser.zig
// Recursive descent parser for the MatterScript Invocation Language
//
// Grammar summary:
//
//   network      = definition* entry?
//   definition   = name '[' dest-list source-list resolution '|' constants ']'
//   dest-list    = '(' dest* ')'
//   source-list  = '(' source* ')'
//   dest         = '$' name
//   source       = name '<>'
//   resolution   = statement*
//   statement    = source-fill | invocation
//   source-fill  = name '<' expr '>'
//   expr         = '$' name | composition
//   composition  = ('$' name)+ '()'
//   invocation   = name '(' '(' arg* ')' '(' output* ')' ')'
//   arg          = '$' name | literal
//   output       = name '<>'
//   constants    = table-def*
//   table-def    = composition ':' entry+
//   entry        = key ':' value
//
// Whitespace and newlines are insignificant.
// Comments begin with // and run to end of line.

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
            } else if (c == '/' and p.pos + 1 < p.src.len and p.src[p.pos + 1] == '/') {
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
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                p.pos += 1;
            } else break;
        }
        if (p.pos == start) return ParseError.ExpectedName;
        return p.src[start..p.pos];
    }

    fn readDest(p: *Parser) !network.Place {
        p.skipWhitespaceAndComments();
        if (p.peek() != '$') return ParseError.ExpectedDollar;
        _ = p.advance();
        const name = try p.readName();
        return network.Place{ .name = name, .kind = .destination };
    }

    fn readSource(p: *Parser) !network.Place {
        p.skipWhitespaceAndComments();
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        if (p.peek() != '<') return ParseError.ExpectedToken;
        _ = p.advance();
        try p.expect('>');
        return network.Place{ .name = name, .kind = .source };
    }

    fn parseDestList(p: *Parser) ![]const network.Place {
        try p.expect('(');
        var list: std.ArrayListUnmanaged(network.Place) = .empty;
        p.skipWhitespaceAndComments();
        while (p.peek() == '$') {
            const dest = try p.readDest();
            try list.append(p.allocator, dest);
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
            const src = try p.readSource();
            try list.append(p.allocator, src);
        }
        try p.expect(')');
        return list.toOwnedSlice(p.allocator);
    }

    // expr: one or more $name segments, optionally followed by ()
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

    fn parseSourceFill(p: *Parser, name: []const u8) !network.Statement {
        _ = p.advance(); // consume <
        const expr = try p.parseExpr();
        try p.expect('>');
        return network.Statement{ .fill = .{
            .source_name = name,
            .expr = expr,
        } };
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
                const stmt = try p.parseSourceFill(name);
                try stmts.append(p.allocator, stmt);
            } else if (next == '(') {
                const stmt = try p.parseInvocation(name);
                try stmts.append(p.allocator, stmt);
            } else {
                return ParseError.UnexpectedChar;
            }
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
            const start = p.pos;
            while (p.peek() == '$') {
                _ = p.advance();
                _ = try p.readName();
            }
            try p.expect('(');
            try p.expect(')');
            const composed = p.src[start..p.pos];
            try p.expect(':');
            var entries: std.ArrayListUnmanaged(network.TableEntry) = .empty;
            p.skipWhitespaceAndComments();
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
                .entries = try entries.toOwnedSlice(p.allocator),
            });
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
        } else {
            return error.UnexpectedChar;
        }
    }

    return network.Network{
        .definitions = try definitions.toOwnedSlice(allocator),
        .entry = entry,
    };
}