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

    std.debug.print("Contained definitions (len: {d}):\n", .{def.contained.len});
    for (def.contained, 0..) |c_def, i| {
        std.debug.print("  [{d}] name: '{s}' | sources: {d} | destinations: {d}\n", .{
            i,
            c_def.name,
            c_def.sources.len,
            c_def.destinations.len,
        });
        for (c_def.sources) |src2| {
            std.debug.print("       -> src: {s}\n", .{src2.name});
        }
        for (c_def.destinations) |dest| {
            std.debug.print("       -> dest: {s}\n", .{dest.name});
        }
    }

    // Contained section holds the 4 value transform rule definitions
    try testing.expectEqual(@as(usize, 4), def.contained.len);

    // Row 0: 0, 0 [TRUE]
    try testing.expectEqualStrings("0,0", def.contained[0].name);
    try testing.expectEqual(@as(usize, 0), def.contained[0].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[0].destinations.len);

    // Row 1: 0, 1 [FALSE]
    try testing.expectEqualStrings("0,1", def.contained[1].name);
    try testing.expectEqual(@as(usize, 0), def.contained[1].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[1].destinations.len);

    // Row 2: 1, 0 [FALSE]
    try testing.expectEqualStrings("1,0", def.contained[2].name);
    try testing.expectEqual(@as(usize, 0), def.contained[2].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[2].destinations.len);

    // Row 3: 1, 1 [TRUE]
    try testing.expectEqualStrings("1,1", def.contained[3].name);
    try testing.expectEqual(@as(usize, 0), def.contained[3].sources.len);
    try testing.expectEqual(@as(usize, 0), def.contained[3].destinations.len);
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
    // Validate Row 0: S,U,W[SUM<S> CO<W>]
    const row0: network.Definition = def.contained[0];
    try testing.expectEqualStrings("S,U,W", row0.name);
    try testing.expectEqual(@as(usize, 2), row0.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row0.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "S", row0.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row0.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "W", row0.resolution[1].fill.expr);

    // Validate Row 1: S,U,X[SUM<T> CO<W>]
    const row1: network.Definition = def.contained[1];
    try testing.expectEqualStrings("S,U,X", row1.name);
    try testing.expectEqual(@as(usize, 2), row1.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row1.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "T", row1.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row1.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "W", row1.resolution[1].fill.expr);

    // Validate Row 2: S,V,W[SUM<T> CO<W>]
    const row2: network.Definition = def.contained[2];
    try testing.expectEqualStrings("S,V,W", row2.name);
    try testing.expectEqual(@as(usize, 2), row2.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row2.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "T", row2.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row2.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "W", row2.resolution[1].fill.expr);

    // Validate Row 3: S,V,X[SUM<S> CO<X>]
    const row3: network.Definition = def.contained[3];
    try testing.expectEqualStrings("S,V,X", row3.name);
    try testing.expectEqual(@as(usize, 2), row3.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row3.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "S", row3.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row3.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "X", row3.resolution[1].fill.expr);

    // Validate Row 4: T,U,W[SUM<T> CO<W>]
    const row4: network.Definition = def.contained[4];
    try testing.expectEqualStrings("T,U,W", row4.name);
    try testing.expectEqual(@as(usize, 2), row4.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row4.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "T", row4.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row4.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "W", row4.resolution[1].fill.expr);

    // Validate Row 5: T,U,X[SUM<S> CO<X>]
    const row5: network.Definition = def.contained[5];
    try testing.expectEqualStrings("T,U,X", row5.name);
    try testing.expectEqual(@as(usize, 2), row5.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row5.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "S", row5.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row5.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "X", row5.resolution[1].fill.expr);

    // Validate Row 6: T,V,W[SUM<S> CO<X>]
    const row6: network.Definition = def.contained[6];
    try testing.expectEqualStrings("T,V,W", row6.name);
    try testing.expectEqual(@as(usize, 2), row6.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row6.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "S", row6.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row6.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "X", row6.resolution[1].fill.expr);

    // Validate Row 7: T,V,X[SUM<T> CO<X>]
    const row7: network.Definition = def.contained[7];
    try testing.expectEqualStrings("T,V,X", row7.name);
    try testing.expectEqual(@as(usize, 2), row7.resolution.len);
    try testing.expectEqualSlices(u8, "SUM", row7.resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "T", row7.resolution[0].fill.expr);
    try testing.expectEqualSlices(u8, "CO", row7.resolution[1].fill.dest_name);
    try testing.expectEqualSlices(u8, "X", row7.resolution[1].fill.expr);
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
    const result = parser.parse(allocator, src);

    if (result) |_| {
        std.debug.print("Expected parse error, but parsing succeeded!\n", .{});
        return error.TestExpectedError;
    } else |err| {
        std.debug.print("Got actual error: {}\n", .{err});
        try testing.expectEqual(parser.core.ParseError.AmbiguousComposedKey, err);
    }
}

test "TAG-160 comma-separated multi-source keys are not flagged as ambiguous" {
    // The comma-separated form is exactly what the check above
    // requires, so it must parse without error. (Whether the VHDL
    // exporter then does the right thing with it is a separate,
    // already-known issue — see the comment on parseTruthTableRow's
    // dispatch in parseContainedSection: a comma-separated row name
    // is currently parsed as Fant's "S,U,W[...]" fresh-source-name
    // shorthand, not as a composed lookup key, which is its own bug
    // to resolve separately.)
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "OR[(A<>B<>)<$A$B()>: 0,0[0] 0,1[1] 1,0[1] 1,1[1]]";

    _ = try parser.parse(allocator, src);
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

test "a steer-selector definition's case names are not flagged as ambiguous multi-source keys" {
    // Regression test for a real false positive (TAG-138, TAG-177):
    // this definition has THREE top-level sources (steer, and two
    // mutex groups), but the row keys "True"/"False" aren't a
    // composed multi-source key at all — they're case labels selected
    // by "$steer()" alone, a single reference. def.sources.len (3)
    // is the wrong basis for "how many segments should a key have"
    // here; composedKeySegmentCount looks for an actual composing
    // fill expression instead, finds none (the bare "$steer()"
    // statement isn't a fill), and correctly never requires commas.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\dualfanin[(steer<> {A<> B<>}{C<> D<>})($out1 $out2)
        \\   $steer( ) : True[out1< $A > out2<$B >]
        \\               False[out1< $C > out2<$D >] ]
    ;

    _ = try parser.parse(allocator, src);
}

test "anonymous contained definitions are canonicalized without a leading double underscore" {
    // Regression test: this used to be "__anon_0" (leading double
    // underscore). export_vhdl.zig's scopedDefinitionName joins a
    // scope and a name with a single "_", so under a scope like
    // "code" that produced "code___anon_0" — three consecutive
    // underscores, which ghdl rejects ("two underscores can't be
    // consecutive"). The row shorthand "X,Y[SUM<X>]" below produces
    // an anonymous (empty-name) contained definition via
    // parseTruthTableRow, which is exactly what canonicalizeNames
    // assigns a synthesized name to.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\CODE[(X<> Y<>)($OUT)
        \\  OUT<$X$Y()>
        \\: X,Y[SUM<X>]
        \\]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    try testing.expectEqual(@as(usize, 1), net.definitions[0].contained.len);
    try testing.expectEqualStrings("X,Y", net.definitions[0].contained[0].name);
}

test "TAG-192 Support Explicit Instance Labelling (prefixlabel: invocation) for Invocations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
       \\ TEST_NET[()()
       \\
        \\     u1: AND($A $B)
        \\     u2: AND($C $D)
        \\:
        \\ ]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);

    const resolution = net.definitions[0].resolution;
    try testing.expectEqual(@as(usize, 2), resolution.len);

    // Verify first labeled invocation (u1)
    try testing.expect(resolution[0] == .invoke);
    try testing.expectEqualStrings("u1", resolution[0].invoke.label.?);
    try testing.expectEqualStrings("AND", resolution[0].invoke.name);

    // Verify second labeled invocation (u2)
    try testing.expect(resolution[1] == .invoke);
    try testing.expectEqualStrings("u2", resolution[1].invoke.label.?);
    try testing.expectEqualStrings("AND", resolution[1].invoke.name);
}
