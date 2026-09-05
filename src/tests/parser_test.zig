// src/tests/parser_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

// Import the module relative to this test file
const parser = matterscript.ipl_parser;
pub const network = matterscript.network;

// Force-reference your submodules so Zig's test runner discovers them
test "reference submodules for testing" {
    _ = parser.core;
    _ = parser.arguments;
    _ = parser.definitions;
    _ = parser.expressions;
}

test "TAG-187 parse 2D cellular automaton generate block and domain" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\ca2d[()()
        \\  @domain(spatial2d, size: [300, 500])
        \\  @generate {
        \\    [2, 1, 5]: 4
        \\    [3, 2, 4]: 6
        \\    [4, 4, 6]: 4
        \\  }
        \\  :
        \\]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);

    const def = net.definitions[0];

    // Access the newly assigned generateBlock field directly
    const gen = def.generateBlock.?;

    // Assert domain bounds (from gen.domain or def.domain_spec)
    if (gen.domain) |domain| {
        try testing.expectEqual(parser.network.SpatialDomainKind.spatial2d, domain.kind);
        try testing.expectEqual(@as(usize, 300), domain.size_x);
        try testing.expectEqual(@as(usize, 500), domain.size_y);
    } else {
        return error.MissingDomainSpec;
    }

    // Assert rules
    try testing.expectEqual(@as(usize, 3), gen.rules.len);
    try testing.expectEqualStrings("2", gen.rules[0].pattern[0]);
    try testing.expectEqualStrings("1", gen.rules[0].pattern[1]);
    try testing.expectEqualStrings("5", gen.rules[0].pattern[2]);
    try testing.expectEqualStrings("4", gen.rules[0].value);
}

test "TAG-190 Example 12.5 AND Function with value transform rule definitions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\binaryequal[(a<> b<>) 
        \\  <$a$b()>
        \\   : 0,0[TRUE]
        \\     0,1[FALSE]
        \\     1,0[FALSE]
        \\     1,1[TRUE]  ]
    ;

    const net = try parser.parse(allocator, src);

    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    try testing.expectEqualStrings("binaryequal", def.name);

    // Sources: (a<> b<>)
    try testing.expectEqual(@as(usize, 2), def.sources.len);
    try testing.expectEqualStrings("a", def.sources[0].name);
    try testing.expectEqualStrings("b", def.sources[1].name);

    // No explicit destination list -> implicit single return path to caller
    try testing.expectEqual(@as(usize, 0), def.destinations.len);

    // Resolution contains $a$b()
    try testing.expect(def.resolution.len > 0);
    // Contained section holds the 4 value transform rule definitions
    try testing.expectEqual(@as(usize, 4), def.contained.len);

    // Each row's name is the comma-joined composed key; the row has
    // no sources/destinations of its own, and its single value
    // ("TRUE"/"FALSE") is a bare pure_value resolution statement —
    // matching the OUTER definition's implicit-single-return shape
    // (dest_name="", filled in by writeDefinition later), the same
    // as e.g. "0[1]" for a single-source definition.

    // Row 0: 0,0[TRUE]
    try testing.expectEqualStrings("0,0", def.contained[0].name);
    try testing.expectEqual(@as(usize, 0), def.contained[0].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[0].destinations.len);
    try testing.expectEqual(@as(usize, 1), def.contained[0].resolution.len);
    try testing.expectEqualStrings("TRUE", def.contained[0].resolution[0].pure_value);

    // Row 1: 0,1[FALSE]
    try testing.expectEqualStrings("0,1", def.contained[1].name);
    try testing.expectEqual(@as(usize, 0), def.contained[1].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[1].destinations.len);
    try testing.expectEqual(@as(usize, 1), def.contained[1].resolution.len);
    try testing.expectEqualStrings("FALSE", def.contained[1].resolution[0].pure_value);

    // Row 2: 1,0[FALSE]
    try testing.expectEqualStrings("1,0", def.contained[2].name);
    try testing.expectEqual(@as(usize, 0), def.contained[2].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[2].destinations.len);
    try testing.expectEqual(@as(usize, 1), def.contained[2].resolution.len);
    try testing.expectEqualStrings("FALSE", def.contained[2].resolution[0].pure_value);

    // Row 3: 1,1[TRUE]
    try testing.expectEqualStrings("1,1", def.contained[3].name);
    try testing.expectEqual(@as(usize, 0), def.contained[3].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[3].destinations.len);
    try testing.expectEqual(@as(usize, 1), def.contained[3].resolution.len);
    try testing.expectEqualStrings("TRUE", def.contained[3].resolution[0].pure_value);
}

test "parse TAG-181 controlled fanout expression and definition" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\// Linear: TAG-181 Controlled Fan-out Expression
        \\fanout($select $input)({output1< > output2< > output3< > output4< >})
        \\
        \\fanout[(select< > in< >)({$out1 $out2 $out3 $out4})
        \\     $select( ) : A[out1< $in >]
        \\                 B[out2< $in >]
        \\                 C[out3< $in >]
        \\                 D[out4< $in>] 
        \\]
    ;
    const net = try parser.parse(allocator, src);

    // 1. Verify vTop-Level Definition
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];
    try testing.expectEqualStrings("fanout", def.name);

    // Definition sources: ($select $input)
    try testing.expectEqual(@as(usize, 2), def.sources.len);
    try testing.expectEqualStrings("select", def.sources[0].name);
    try testing.expectEqualStrings("in", def.sources[1].name);

    // Definition destinations: a group containing 4 outputs
    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    const dest_arg = def.destinations[0];
    try testing.expectEqual(network.ArgKind.group, dest_arg.kind);

    const dest_group = dest_arg.group.?;
    try testing.expectEqual(@as(usize, 4), dest_group.places.len);
    try testing.expectEqualStrings("out1", dest_group.places[0].name);
    try testing.expectEqualStrings("out2", dest_group.places[1].name);
    try testing.expectEqualStrings("out3", dest_group.places[2].name);
    try testing.expectEqualStrings("out4", dest_group.places[3].name);
}

test "parse TAG-185 preserve case-sensitive IPL identifiers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\// TAG-185 Preserve case-sensitive IPL identifiers when emitting VHD
        \\
        \\test[(a<> A<> b<> B<>)($result)
        \\    $a$A$b$B()
        \\:
        \\    0,0,0,0[0]
        \\    1,1,1,1[1]
        \\]
    ;

    const net = try parser.parse(allocator, src);

    // Verify top-level definition was successfully parsed
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    // Sources: four individual arguments (a<>, A<>, b<>, B<>)
    try testing.expectEqual(@as(usize, 4), def.sources.len);

    // Verify strict case preservation and attached group modifiers on sources
    try testing.expectEqualStrings("a", def.sources[0].name);
    try testing.expectEqual(network.ArgKind.place, def.sources[0].kind);

    try testing.expectEqualStrings("A", def.sources[1].name);
    try testing.expectEqual(network.ArgKind.place, def.sources[1].kind);

    try testing.expectEqualStrings("b", def.sources[2].name);
    try testing.expectEqual(network.ArgKind.place, def.sources[2].kind);

    try testing.expectEqualStrings("B", def.sources[3].name);
    try testing.expectEqual(network.ArgKind.place, def.sources[3].kind);

    // Verify destinations: ($result)
    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqualStrings("result", def.destinations[0].name);

    // Verify body rules / truth-table transitions are present
    try testing.expect(def.resolution.len > 0);
}

test "parse TAG-184 Pure Value Place of Resolution - explicit contained rows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\// Linear: TAG-184 Pure Value Place of Resolution
        \\
        \\FULLADD($A,$B,$C)(<> CARRYOUT<>)
        \\
        \\FULLADD[(A<> B<> CI<> )($SUM $CO)
        \\
        \\$A$B$CI :
        \\
        \\S,U,W[SUM<S> CO<W>] 
        \\S,U,X[SUM<T> CO<W>]
        \\S,V,W[SUM<T> CO<W>] 
        \\S,V,X[SUM<S> CO<X>]
        \\T,U,W[SUM<T> CO<W>] 
        \\T,U,X[SUM<S> CO<X>]
        \\T,V,W[SUM<S> CO<X>] 
        \\T,V,X[SUM<T> CO<X>] ]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    try testing.expectEqualStrings("FULLADD", def.name);
    try testing.expectEqual(@as(usize, 3), def.sources.len);
    try testing.expectEqual(@as(usize, 2), def.destinations.len);

    // Verify all 8 truth-table transition rows are captured in contained
    try testing.expectEqual(@as(usize, 8), def.contained.len);

    // Each row is a composed-key Definition: name is the comma-joined
    // key, with no sources/destinations of its own — S, U, W etc. are
    // tokens in the key, not source or destination declarations (they
    // carry no $ or <> designators). The bracket contents are fills
    // against the ENCLOSING definition's own destinations (SUM, CO).

    // Validate Row 1: S,U,W[SUM<S> CO<W>]
    const row0 = def.contained[0];
    try testing.expectEqualStrings("S,U,W", row0.name);
    try testing.expectEqual(@as(usize, 0), row0.sources.len);
    try testing.expectEqual(@as(usize, 0), row0.destinations.len);
    try testing.expectEqual(@as(usize, 2), row0.resolution.len);
    try testing.expectEqualStrings("SUM", row0.resolution[0].fill.dest_name);
    try testing.expectEqualStrings("S", row0.resolution[0].fill.expr);
    try testing.expectEqualStrings("CO", row0.resolution[1].fill.dest_name);
    try testing.expectEqualStrings("W", row0.resolution[1].fill.expr);

    // Validate Row 2: S,U,X[SUM<T> CO<W>]
    const row1 = def.contained[1];
    try testing.expectEqualStrings("S,U,X", row1.name);
    try testing.expectEqual(@as(usize, 0), row1.sources.len);
    try testing.expectEqual(@as(usize, 0), row1.destinations.len);
    try testing.expectEqual(@as(usize, 2), row1.resolution.len);
    try testing.expectEqualStrings("SUM", row1.resolution[0].fill.dest_name);
    try testing.expectEqualStrings("T", row1.resolution[0].fill.expr);
    try testing.expectEqualStrings("CO", row1.resolution[1].fill.dest_name);
    try testing.expectEqualStrings("W", row1.resolution[1].fill.expr);

    // Validate final Row 8: T,V,X[SUM<T> CO<X>]
    const row7 = def.contained[7];
    try testing.expectEqualStrings("T,V,X", row7.name);
    try testing.expectEqual(@as(usize, 0), row7.sources.len);
    try testing.expectEqual(@as(usize, 0), row7.destinations.len);
    try testing.expectEqual(@as(usize, 2), row7.resolution.len);
    try testing.expectEqualStrings("SUM", row7.resolution[0].fill.dest_name);
    try testing.expectEqualStrings("T", row7.resolution[0].fill.expr);
    try testing.expectEqualStrings("CO", row7.resolution[1].fill.dest_name);
    try testing.expectEqualStrings("X", row7.resolution[1].fill.expr);
}

test "TAG-190 concatenated multi-source keys are rejected as ambiguous" {
    // The programmer's intent (confirmed): with more than one source,
    // a contained row's key must comma-separate each source's value
    // ("0,0[0]"), since symbolic values aren't fixed-width and a
    // concatenated key ("00[0]") has no reliable split point. This
    // used to parse "silently", then collapse downstream in the VHDL
    // exporter into an undeclared "ab" signal reference (ghdl:
    // `no declaration for "ab"`) — now it's rejected at parse time
    // with a specific error instead.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "AND[(A<> B<>)<$A$B()>: 00[0] 01[0] 10[0] 11[1]]";

    try testing.expectError(parser.core.ParseError.AmbiguousComposedKey, parser.parse(allocator, src));
}

test "TAG-160 comma-separated multi-source keys parse as composed keys and resolve cleanly" {
    // Previously misdiagnosed here as a separate known issue: comma
    // rows used to be routed to a since-deleted parseTruthTableRow,
    // producing a row with real sources/destinations that
    // writeContainedLookupTable's guard clause rejected — falling
    // through to the same undeclared "ab" signal bug as the
    // concatenated-key case. Now that parseContainedSection routes
    // every row through parseDefinition uniformly, this parses to the
    // same composed-key shape as the single-source case and no
    // longer needs a comma-vs-no-comma special case at all.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "OR[(A<>B<>)<$A$B()>: 0,0[0] 0,1[1] 1,0[1] 1,1[1]]";

    const net = try parser.parse(allocator, src);
    const def = net.definitions[0];
    try testing.expectEqual(@as(usize, 4), def.contained.len);
    for (def.contained) |row| {
        try testing.expectEqual(@as(usize, 0), row.sources.len);
        try testing.expectEqual(@as(usize, 0), row.destinations.len);
    }
    try testing.expectEqualStrings("0,0", def.contained[0].name);
    try testing.expectEqualStrings("0", def.contained[0].resolution[0].pure_value);
}

test "a single-source definition's multi-character row names are not flagged as ambiguous" {
    // source_count == 1 means there's nothing to disambiguate between,
    // so a multi-character symbolic value with no comma is fine.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "IDENT[(A<>)($res) res<$A()>: TRUE[FALSE] FALSE[TRUE]]";

    _ = try parser.parse(allocator, src);
}

test "canonicalizeNames assigns anonymous definitions a name without a leading double underscore" {
    // No current parser path actually produces Definition.name == ""
    // any more — parseTruthTableRow, the one function that did, has
    // been removed, since parseContainedSection now routes every
    // contained-row header (comma-separated or not) through
    // parseDefinition, which always reads at least one name
    // character. Kept as a direct unit test of the naming mechanism
    // itself, since getting this wrong was the exact cause of a real
    // ghdl error ("two underscores can't be consecutive" on
    // "code___anon_11") and some future producer of an anonymous
    // Definition could still reach it — see the sanitizeName
    // hardening test in export_vhdl.zig for the other half of that
    // fix (the join with a parent scope).
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var defs: std.ArrayListUnmanaged(network.Definition) = .empty;
    try defs.append(allocator, .{
        .name = "",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
    });
    try defs.append(allocator, .{
        .name = "",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
    });

    try parser.canonicalizeNames(allocator, &defs);

    try testing.expectEqualStrings("anon_0", defs.items[0].name);
    try testing.expectEqualStrings("anon_1", defs.items[1].name);
    try testing.expect(std.mem.indexOf(u8, defs.items[0].name, "__") == null);
}