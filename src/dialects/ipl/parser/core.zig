const std = @import("std");
const network = @import("../network.zig");
const expressions = @import("expressions.zig");
const definitions = @import("definitions.zig");
const arguments = @import("arguments.zig");

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
    /// A contained-definition row name for a multi-source definition
    /// concatenated its signal values with no comma between them (e.g.
    /// "00[0]" for a 2-source table). With more than one source there
    /// is no reliable way to infer where one value ends and the next
    /// begins — symbolic states aren't fixed-width — so this is
    /// rejected rather than silently misparsed. Separate each value
    /// with a comma (e.g. "0,0[0]").
    AmbiguousComposedKey,
};

pub const Parser = struct {
    src: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,
    last_expr: ?*const network.Expr = null,

    pub fn init(allocator: std.mem.Allocator, src: []const u8) Parser {
        return .{ .src = src, .pos = 0, .allocator = allocator };
    }

    pub fn peek(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        return p.src[p.pos];
    }

    pub fn peekNext(p: *Parser) ?u8 {
        if (p.pos + 1 < p.src.len) {
            return p.src[p.pos + 1];
        }
        return null;
    }

    pub fn advance(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        const c = p.src[p.pos];
        p.pos += 1;
        return c;
    }

    pub fn skipWhitespaceAndComments(p: *Parser) void {
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

    pub fn expect(p: *Parser, ch: u8) !void {
        p.skipWhitespaceAndComments();
        if (p.peek() != ch) return ParseError.ExpectedToken;
        _ = p.advance();
    }

    pub fn tryConsume(p: *Parser, ch: u8) bool {
        p.skipWhitespaceAndComments();
        if (p.peek() == ch) {
            _ = p.advance();
            return true;
        }
        return false;
    }

    pub fn readName(p: *Parser) ![]const u8 {
        p.skipWhitespaceAndComments();
        const start = p.pos;
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_' or c == '$' or c == '@') {
                p.pos += 1;
            } else {
                break;
            }
        }
        if (p.pos == start) return ParseError.ExpectedName;
        return p.src[start..p.pos];
    }

    pub fn readInteger(p: *Parser) !i64 {
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

    pub fn peekKeyword(p: *Parser, kw: []const u8) bool {
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

    pub fn consumeKeyword(p: *Parser, kw: []const u8) !void {
        p.skipWhitespaceAndComments();
        const name = try p.readName();
        if (!std.mem.eql(u8, name, kw)) return ParseError.ExpectedName;
        _ = p.tryConsume(':');
    }
};
