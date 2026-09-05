const std = @import("std");
const core = @import("core.zig");
const network: type = @import("../network.zig");
const arguments = @import("arguments.zig");
const expressions = @import("expressions.zig");

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
    const name = try p.readCommaSeparatedName();
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
            const rules = try p.parseNeighborhoodRulesBlock();
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
    const section = try parseContainedSection(p, sources.len);
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

/// Parses everything after a definition's resolution-terminating ':'
/// — Fant's "contained definitions" position (§12.3.2). Can hold
/// $-composed constant tables and/or genuine nested Definitions
/// (with their own sources/destinations/resolution), in any order.
///
/// `source_count` is the enclosing definition's source count, used
/// only to detect an ambiguous composed lookup-table key: with
/// more than one source, a row name must comma-separate each
/// source's value (e.g. "0,0[0]"), since symbolic values aren't
/// fixed-width and a concatenated "00[0]" has no reliable split
/// point. See AmbiguousComposedKey.
pub fn parseContainedSection(p: *core.Parser, source_count: usize) anyerror!struct {
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
            const names = p.readCommaSeparatedName() catch {
                p.pos = save;
                break;
            };
            p.skipWhitespaceAndComments();
            if (p.peek() == '[') {
                if (std.mem.indexOfScalar(u8, names, ',') != null) {
                    // Shorthand truth-table row (e.g. S,U,W[...])
                    p.pos = save;
                    const row = try parseTruthTableRow(p);
                    try nested.append(p.allocator, row);
                    continue;
                } else {
                    // Standard nested definition (e.g. AND[...]) —
                    // unless this is actually a multi-source
                    // lookup-table row whose values were
                    // concatenated instead of comma-separated,
                    // which is ambiguous and must be rejected.
                    if (source_count > 1 and names.len > 1) {
                        p.pos = save;
                        return core.ParseError.AmbiguousComposedKey;
                    }
                    p.pos = save;
                    const def = try parseDefinition(p);
                    try nested.append(p.allocator, def);
                    continue;
                }
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

/// Parses a shorthand truth-table row like S,U,W[SUM<S> CO<W>]
fn parseTruthTableRow(p: *core.Parser) anyerror!network.Definition {
    var sources: std.ArrayListUnmanaged(network.Arg) = .empty;
    while (true) {
        p.skipWhitespaceAndComments();
        const name = try p.readName();
        try sources.append(p.allocator, network.Arg{
            .name = name,
            .kind = .place,
            .group = null,
        });
        p.skipWhitespaceAndComments();
        if (p.peek() == ',') {
            p.pos += 1;
        } else {
            break;
        }
    }

    try p.expect('[');
    p.skipWhitespaceAndComments();

    var destinations: std.ArrayListUnmanaged(network.Arg) = .empty;
    while (true) {
        p.skipWhitespaceAndComments();
        const c = p.peek() orelse return error.UnexpectedEof;
        if (c == ']') {
            p.pos += 1; // consume ']'
            break;
        }

        // Parse the destination argument (handles name and optional <modifier> automatically)
        const arg = try arguments.parseArg(p);
        try destinations.append(p.allocator, arg);

        p.skipWhitespaceAndComments();
        if (p.peek() == ',') {
            p.pos += 1;
        }
    }

    return network.Definition{
        .name = "",
        .sources = try sources.toOwnedSlice(p.allocator),
        .destinations = try destinations.toOwnedSlice(p.allocator),
        .resolution = &.{},
        .constants = &.{},
        .contained = &.{},
    };
}

pub fn parseResolution(p: *core.Parser) ![]const network.Statement {
    var stmts: std.ArrayListUnmanaged(network.Statement) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        const c = p.peek() orelse break;
        if (c == ':' or c == ']') break;

        if (c == '<') {
            try stmts.append(p.allocator, try p.parseSourceFill(""));
            continue;
        }

        if (c == '$') {
            const expr = try expressions.parseILExpr(p);
            try stmts.append(p.allocator, .{ .pure_value = expr });
            continue;
        }

        const tok_start = p.pos;
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        const next = p.peek() orelse return core.ParseError.UnexpectedEnd;
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
