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

    pub fn parseNeighborhoodRulesBlock(p: *Parser) ![]const network.NeighborhoodRule {
        try p.expect('{');
        var rules: std.ArrayListUnmanaged(network.NeighborhoodRule) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const c = p.peek() orelse return ParseError.UnexpectedEnd;
            if (c == '}') break;
            if (c != '[') return ParseError.UnexpectedChar;
            _ = p.advance(); // consume '['

            var pattern: std.ArrayListUnmanaged([]const u8) = .empty;
            while (true) {
                p.skipWhitespaceAndComments();
                const pc = p.peek() orelse return ParseError.UnexpectedEnd;
                if (pc == '*') {
                    _ = p.advance();
                    try pattern.append(p.allocator, "*");
                } else {
                    const tok = try p.readName();
                    try pattern.append(p.allocator, tok);
                }
                p.skipWhitespaceAndComments();
                if (p.tryConsume(',')) continue;
                break;
            }
            try p.expect(']');
            try p.expect(':');
            p.skipWhitespaceAndComments();
            const value = try p.readName();
            try rules.append(p.allocator, .{
                .pattern = try pattern.toOwnedSlice(p.allocator),
                .value = value,
            });
            p.skipWhitespaceAndComments();
            _ = p.tryConsume(',');
        }
        try p.expect('}');
        return rules.toOwnedSlice(p.allocator);
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
            if (std.ascii.isAlphanumeric(c) or c == '_' or c == '$') {
                p.pos += 1;
            } else {
                break;
            }
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

    fn parseDomainDirective(p: *Parser) !network.DomainSpec {
        try p.consumeKeyword("@domain");
        try p.expect('(');
        p.skipWhitespaceAndComments();

        // Parse domain kind (e.g. "spatial2d")
        const kind_str = try p.readName();
        const kind: network.SpatialDomainKind = if (std.mem.eql(u8, kind_str, "spatial2d"))
            .spatial2d
        else
            return error.UnknownDomainKind;

        p.skipWhitespaceAndComments();
        try p.expect(',');
        p.skipWhitespaceAndComments();

        // Parse "size:" parameter
        try p.consumeKeyword("size");
        try p.expect(':');
        p.skipWhitespaceAndComments();

        // Parse bounds array [width, height]
        try p.expect('[');
        const size_x = try p.readInteger(usize);
        p.skipWhitespaceAndComments();
        try p.expect(',');
        p.skipWhitespaceAndComments();
        const size_y = try p.readInteger(usize);
        p.skipWhitespaceAndComments();
        try p.expect(']');

        p.skipWhitespaceAndComments();
        try p.expect(')');

        return network.DomainSpec{
            .kind = kind,
            .size_x = size_x,
            .size_y = size_y,
        };
    }
    

    // ----------------------------------------------------------------
    // Definition list parsers (corrected Fant order)
    // ----------------------------------------------------------------
    /// Shared helper for parsing symmetric source/destination lists
    pub fn parseGroup(p: *Parser) anyerror!*const network.PlaceGroup {
        p.skipWhitespaceAndComments();

        var kind: network.PlaceGroupKind = .bundle;
        var close_delim: u8 = '>';

        if (p.peek() == '<') {
            kind = .bundle;
            close_delim = '>';
            p.pos += 1;
        } else if (p.peek() == '(') {
            // Bare parenthesized sub-group — parens are used the same
            // way <> wraps a bundle elsewhere in the grammar (e.g. a
            // second arg tacked directly onto an arbitration group:
            // "{{$a $b}}(next<>)").
            kind = .bundle;
            close_delim = ')';
            p.pos += 1;
        } else if (p.peek() == '[') {
            // Bundle-brackets (§12.6) — same semantics as <>, matching
            // the mapping already used by parseArgSequence.
            kind = .bundle;
            close_delim = ']';
            p.pos += 1;
        } else if (p.peek() == '{') {
            p.pos += 1;
            if (p.peek() == '{') {
                kind = .arbitration;
                close_delim = '}'; // Will consume the second '}' on loop exit
                p.pos += 1;
            } else {
                kind = .mutex;
                close_delim = '}';
            }
        } else {
            return error.InvalidGroupDelimiter;
        }

        var places: std.ArrayListUnmanaged(network.Arg) = .empty;

        while (true) {
            p.skipWhitespaceAndComments();
            const ch = p.peek() orelse return error.UnexpectedEof;

            if (ch == close_delim) {
                p.pos += 1;
                // Handle secondary closing brace for double-curly arbitration {{ ... }}
                if (kind == .arbitration) {
                    p.skipWhitespaceAndComments();
                    if (p.peek() == '}') {
                        p.pos += 1;
                    } else {
                        return error.ExpectedClosingBrace;
                    }
                }
                break;
            }

            const child_arg = try arguments.parseArg(p);
            try places.append(p.allocator, child_arg);

            p.skipWhitespaceAndComments();
            if (p.peek() == ',') {
                p.pos += 1;
            } else if (p.peek() == close_delim) {
                // Loop continue will consume close_delim and perform arbitration check
                continue;
            }
        }

        const group_ptr = try p.allocator.create(network.PlaceGroup);
        group_ptr.* = network.PlaceGroup{
            .kind = kind,
            .places = try places.toOwnedSlice(p.allocator),
        };

        return group_ptr;
    }

    /// Consume a balanced-delimiter span starting at the current
    /// position, returning the full text including both delimiters.
    /// Used for brace groups ({...} — mutex/conditional completeness,
    /// §12.5.2/12.5.3) and bundle brackets ([...] — bundling/
    /// unbundling, §12.6). Each call only tracks its own delimiter's
    /// depth, so the two kinds nest inside each other transparently —
    /// a "[" span just copies through any "{"/"}" it encounters as
    /// inert content, and vice versa.
    pub fn consumeBalanced(p: *Parser, open: u8, close: u8) ![]const u8 {
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
    fn parseDefSourceList() ![]const network.Arg {
        return arguments.parseArgList(')');
    }

    /// Definition second list: ($name ...) — destination places, tokens flow OUT
    fn parseDefDestinationList() ![]const network.Arg {
        return arguments.parseArgList(')');
    }

    /// Invocation second list: (name<> ...) — outputs returned to caller
    fn parseInvOutputList() ![]const network.Place {
        return arguments.parsePlaceList(')');
    }

    /// Reads a name that may be split into comma-separated segments
    /// (§12.4 — the comma is a general, freely-insertable separator).
    /// Used for contained-definition names formed by composition,
    /// where a segment boundary would otherwise be ambiguous (e.g.
    /// "0,S0" rather than the unsplittable "0S0"). Returns the
    /// segments joined with a single comma, e.g. "0,S0" — downstream
    /// consumers should split on ',' and trim each segment, to
    /// tolerate incidental whitespace like "0, S0".
    pub fn readCommaSeparatedName(p: *Parser) ![]const u8 {
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

    pub fn parseSourceFill(p: *Parser, name: []const u8) !network.Statement {
        _ = p.advance(); // consume <
        const expr = try expressions.parseILExpr(p);
        try p.expect('>');
        return network.Statement{ .fill = .{
            .dest_name = name,
            .expr = expr,
            .parsed_expr = p.last_expr,
        } };
    }

    pub fn parseInvocation(p: *Parser, name: []const u8) !network.Statement {
        const sources = if (p.peek() == '(')
            try arguments.parseArgList(p, ')')
        else
            &.{};

        p.skipWhitespaceAndComments();

        const destinations: []const network.Arg = if (p.peek() == '(')
            try arguments.parseArgList(p, ')')
        else
            &.{}; // §12.3.4 — destination list omitted, implicit single unnamed return

        return network.Statement{ .invoke = .{
            .name = name,
            .sources = sources,
            .destinations = destinations,
        } };
    }


    pub fn parseEntryInvocation(p: *Parser, name: []const u8) !network.EntryInvocation {
        // Fant invocation order: sources first ($name/literal/groups), destinations second (name<>)
        const sources = try arguments.parseArgList(p, ')');
        p.skipWhitespaceAndComments();
        const destinations: []const network.Arg = if (p.peek() == '(')
            try arguments.parseArgList(p, ')')
        else
            &.{}; // §12.3.4 — destination list omitted, implicit single unnamed return

        return network.EntryInvocation{
            .name = name,
            .sources = sources,
            .destinations = destinations,
        };
    }
};
