const std = @import("std");
const core = @import("core.zig");
const network: type = @import("../network.zig");
const arguments = @import("arguments.zig");
const expressions = @import("expressions.zig");
const directives = @import("directives.zig");
const statements = @import("statements.zig");
const groups = @import("groups.zig");

const testing = std.testing;

// ----------------------------------------------------------------
// Definition and entry invocation
// ----------------------------------------------------------------

/// Parses a network definition from the given parser, enclosed in `[` and `]`.
///
/// Expects a comma-separated name, optional `(sources)` and `(destinations)` argument lists,
/// zero or more `@domain` or `@generate` directives, a resolution specifier, and a contained section.
///
/// * `p`: A pointer to the active `Parser` state.
///
/// **Errors:**
/// Returns `error.UnknownDirective` if an unhandled `@` directive is encountered, or any
/// parsing error produced while reading names, argument lists, directives, or sections.
///
/// Returns the fully constructed `network.Definition`.
pub fn parseDefinition(p: *core.Parser) anyerror!network.Definition {
    const name = try groups.readCommaSeparatedName(p);
    try p.expect('[');

    p.skipWhitespaceAndComments();
    const sources: []const network.Arg = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{};

    p.skipWhitespaceAndComments();
    const destinations: []const network.Arg = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{};

    p.skipWhitespaceAndComments();

    var domain_spec: ?network.DomainSpec = null;
    var generate_block: ?network.GenerateBlock = null;
    // Loop to consume all '@' directives inside the definition header
    while (p.peek() == '@') {
        p.pos += 1; // Consume '@'
        const directive = try p.readName();
        p.skipWhitespaceAndComments();

        if (std.mem.eql(u8, directive, "domain")) {
            domain_spec = try parseDomainSpec(p);
            p.skipWhitespaceAndComments();
        } else if (std.mem.eql(u8, directive, "generate")) {
            // parseNeighborhoodRuleBlock expects and consumes '{'
            const rules = try directives.parseNeighborhoodRulesBlock(p);
            generate_block = network.GenerateBlock{
                .domain = domain_spec,
                .rules = rules,
            };
            p.skipWhitespaceAndComments();
        } else {
            return error.UnknownDirective;
        }
    }
    p.skipWhitespaceAndComments();
    const resolution = try parseResolution(p);
    _ = p.tryConsume(':');
    const section = try parseContainedSection(p, composedKeySegmentCount(resolution));
    try p.expect(']');

    return network.Definition{
        .name = name,
        .sources = sources,
        .destinations = destinations,
        .domain_spec = domain_spec,
        .generateBlock = generate_block,
        .resolution = resolution,
        .constants = section.constants,
        .contained = section.contained,
    };
}

/// How many $-separated segments a contained row's composed key
/// is expected to have, derived from counting distinct $-referenced
/// names in a fill statement's expression (e.g. "$A$B()" → 2).
///
/// This is deliberately NOT def.sources.len: a definition can have
/// sources that aren't part of the lookup key at all — e.g. a
/// "steer"-selector pattern (fanout/fanin/dualfanin) where a single
/// $select()/$steer() reference picks between named cases like
/// "True"/"False" or "A"/"B"/"C"/"D", while the OTHER sources are
/// just data being routed, referenced inside the row bodies rather
/// than composed into the key. Using sources.len there would flag
/// those single-token case names as ambiguous multi-source keys when
/// they aren't keys at all in that sense. If no fill composes a key,
/// this returns 0 and AmbiguousComposedKey never fires for the row.
pub fn composedKeySegmentCount(resolution: []const network.Statement) usize {
    for (resolution) |stmt| {
        if (stmt != .fill) continue;
        var count: usize = 0;
        var i: usize = 0;
        const expr = stmt.fill.expr;
        while (i < expr.len) {
            if (expr[i] != '$') {
                i += 1;
                continue;
            }
            i += 1;
            const start = i;
            while (i < expr.len and (std.ascii.isAlphanumeric(expr[i]) or expr[i] == '_')) i += 1;
            if (i > start) count += 1;
        }
        if (count > 0) return count;
    }
    return 0;
}




/// Parses everything after a definition's resolution-terminating ':'
/// — Fant's "contained definitions" position (§12.3.2). Can hold
/// $-composed constant tables and/or genuine nested Definitions
/// (with their own sources/destinations/resolution), in any order.
///
/// `expected_segments` is the composed-key segment count derived by
/// composedKeySegmentCount above — NOT the enclosing definition's
/// source count. With more than one expected segment, a row name
/// must comma-separate each value (e.g. "0,0[0]"), since symbolic
/// values aren't fixed-width and a concatenated "00[0]" has no
/// reliable split point. See AmbiguousComposedKey.
pub fn parseContainedSection(p: *core.Parser, expected_segments: usize) anyerror!struct {
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
            try tables.append(p.allocator, try parseOneConstantTable(p));
            continue;
        }

        if (std.ascii.isAlphanumeric(c) or c == '_') {
            const save = p.pos;
            const names = groups.readCommaSeparatedName(p) catch {
                p.pos = save;
                break;
            };
            p.skipWhitespaceAndComments();
            if (p.peek() == '[') {
                // A contained-definition row: the composed key is
                // just the comma-joined name (or a bare token for a
                // single source) and the bracket holds the row's
                // value(s) as ordinary resolution statements — parsed
                // identically whether the key itself uses commas
                // ("0,0[0]", "S,U,W[SUM<S> CO<W>]") or not ("00[0]"
                // for a single source, "1[2]" for a bare constant).
                // There's no separate "declare fresh source names"
                // construct here — S, U, W above carry no $ or <>
                // designators, so they're composed-key tokens like
                // any other. (Routing comma rows to a separate
                // "declare fresh sources" parse used to misread
                // "0,0" as two source places both literally named
                // "0", which both collapsed to the same sanitized
                // "ms_0" name and produced a duplicate port
                // declaration on top of ghdl's "no declaration for
                // ab" from the resulting expression-fill fallback.)
                if (expected_segments > 1 and names.len > 1 and
                    std.mem.indexOfScalar(u8, names, ',') == null)
                {
                    p.pos = save;
                    return core.ParseError.AmbiguousComposedKey;
                }
                p.pos = save;
                const def = try parseDefinition(p);
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
// Constants
// ----------------------------------------------------------------

/// Parses a single $-composed constant table: "$a$b() : entries" or
/// "$a$b() : generate { ... }".
fn parseOneConstantTable(p: *core.Parser) !network.TableDef {
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
        const gen = try parseGenerateBlock(p);
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

pub fn parseResolution(p: *core.Parser) ![]const network.Statement {
    var stmts: std.ArrayListUnmanaged(network.Statement) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        const c = p.peek() orelse break;
        if (c == ':' or c == ']') break;

        if (c == '<') {
            try stmts.append(p.allocator, try statements.parseSourceFill(p,""));
            continue;
        }

        if (c == '$') {
            const expr = try expressions.parseILExpr(p);
            try stmts.append(p.allocator, .{ .pure_value = expr });
            continue;
        }

        const tok_start = p.pos;

        // 1. Check for optional prefix label (e.g., "u1: AND(...)")
        var label: ?[]const u8 = null;
        const potential_label = p.readName() catch |err| {
            // If it's not a valid name starting the statement, let it fall through 
            // or handle whatever token error occurs.
            return err;
        };
        
        p.skipWhitespaceAndComments();
        var name: []const u8 = undefined;
        
        if (p.peek() == ':') {
            p.pos += 1; // consume ':'
            label = potential_label;
            p.skipWhitespaceAndComments();
            // Now read the actual component/invocation name that follows the label
            name = try p.readName();
            p.skipWhitespaceAndComments();
        } else {
            // No colon, so `potential_label` was actually the regular name/identifier!
            p.pos = tok_start; // backtrack to start
            name = try p.readName();
            p.skipWhitespaceAndComments();
        }

        const next = p.peek() orelse return core.ParseError.UnexpectedEnd;
        if (next == '<') {
            try stmts.append(p.allocator, try statements.parseSourceFill(p, name));
        } else if (next == '(') {
            // Pass the label here!
            try stmts.append(p.allocator, try statements.parseInvocation(p,label, name));
        } else if (next == ',') {
            p.pos = tok_start;
            const full = try groups.readCommaSeparatedName(p);
            try stmts.append(p.allocator, .{ .pure_value = full });
        } else if (next == ':' or next == ']') {
            try stmts.append(p.allocator, .{ .pure_value = p.src[tok_start..p.pos] });
        } else return core.ParseError.UnexpectedChar;
    }
    return stmts.toOwnedSlice(p.allocator);
}

pub fn parseDomainSpec(p: *core.Parser) !network.DomainSpec {
    // 1. Consume opening parenthesis: '('
    try p.expect('(');
    p.skipWhitespaceAndComments();

    // 2. Read domain kind string: "spatial1d", "spatial2d", "spatial3d"
    const kind_str = try p.readName();
    const kind: network.SpatialDomainKind = if (std.mem.eql(u8, kind_str, "spatial1d"))
        .spatial1d
    else if (std.mem.eql(u8, kind_str, "spatial2d"))
        .spatial2d
    else if (std.mem.eql(u8, kind_str, "spatial3d"))
        .spatial3d
    else
        return error.UnknownDomainKind;

    p.skipWhitespaceAndComments();

    var size_x: usize = 0;
    var size_y: usize = 0;
    var size_z: usize = 0;

    // 3. Parse optional parameters (e.g. `, size: [300, 500]`)
    if (p.peek() == ',') {
        p.pos += 1; // Consume ','
        p.skipWhitespaceAndComments();

        const param_name = try p.readName();
        if (std.mem.eql(u8, param_name, "size")) {
            p.skipWhitespaceAndComments();
            try p.expect(':');
            p.skipWhitespaceAndComments();
            try p.expect('[');
            p.skipWhitespaceAndComments();

            // Read X dimension
            const x_str = try p.readName();
            size_x = try std.fmt.parseInt(usize, x_str, 10);
            p.skipWhitespaceAndComments();

            // Read Y dimension if present
            if (p.peek() == ',') {
                p.pos += 1;
                p.skipWhitespaceAndComments();
                const y_str = try p.readName();
                size_y = try std.fmt.parseInt(usize, y_str, 10);
                p.skipWhitespaceAndComments();
            }

            // Read Z dimension if present
            if (p.peek() == ',') {
                p.pos += 1;
                p.skipWhitespaceAndComments();
                const z_str = try p.readName();
                size_z = try std.fmt.parseInt(usize, z_str, 10);
                p.skipWhitespaceAndComments();
            }

            try p.expect(']');
            p.skipWhitespaceAndComments();
        }
    }

    try p.expect(')');

    return network.DomainSpec{
        .kind = kind,
        .size_x = size_x,
        .size_y = size_y,
        .size_z = size_z,
    };
}

// ----------------------------------------------------------------
// Generate block
// ----------------------------------------------------------------
// Inside src/dialects/ipl/parser.zig

pub fn parseGenerateBlock(p: *core.Parser) !network.GenerateBlock {
    try p.consumeKeyword("generate");
    p.skipWhitespaceAndComments();
    try p.expect('{');

    var rules: std.ArrayListUnmanaged(network.NeighborhoodRule) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        if (p.peek() == '}' or p.pos >= p.src.len) break;

        // Parse rule pattern: [ Left, Center, Right ]
        if (p.peek() == '[') {
            _ = p.advance(); // consume '['
            var pattern_tokens: std.ArrayListUnmanaged([]const u8) = .empty;

            while (true) {
                p.skipWhitespaceAndComments();
                if (p.peek() == ']') break;

                const token = try p.readName();
                try pattern_tokens.append(p.allocator, token);

                p.skipWhitespaceAndComments();
                if (p.peek() == ',') {
                    _ = p.advance();
                }
            }
            try p.expect(']');
            p.skipWhitespaceAndComments();

            // Parse rule output delimiter (':' or '->')
            if (p.peek() == ':') {
                _ = p.advance();
            } else if (p.peek() == '-' and p.peekNext() == '>') {
                p.pos += 2;
            }
            p.skipWhitespaceAndComments();

            // Parse new state value
            const target_val = try p.readName();

            try rules.append(p.allocator, .{
                .pattern = try pattern_tokens.toOwnedSlice(p.allocator),
                .value = target_val,
            });
        } else {
            // Handle unexpected tokens inside @generate block
            return error.InvalidGenerateRule;
        }
    }

    try p.expect('}');

    return network.GenerateBlock{
        .rules = try rules.toOwnedSlice(p.allocator),
    };
}