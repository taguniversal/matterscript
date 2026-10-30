// src/tests/parser_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const boundary = matterscript.boundary;
const network_entity = matterscript.vhdl.network_entity;
const rules = matterscript.runtime.rules;
const export_value_transform = matterscript.vhdl.value_transform_export;
// Import the module relative to this test file
const parser = matterscript.ipl_parser;
pub const network = matterscript.network;

fn dumpAst(def: network.Definition) void {
    std.debug.print("\n=== AST DUMP FOR: {s} ===\n", .{def.name});
    std.debug.print("Sources ({d}):\n", .{def.sources.len});
    for (def.sources, 0..) |s, i| {
        std.debug.print("  [{d}] kind={s}, name='{s}', text='{s}'\n", .{ i, @tagName(s.kind), s.name, s.text });
    }
    std.debug.print("Destinations ({d}):\n", .{def.destinations.len});
    for (def.destinations, 0..) |d, i| {
        std.debug.print("  [{d}] kind={s}, name='{s}', text='{s}'\n", .{ i, @tagName(d.kind), d.name, d.text });
    }
    std.debug.print("Resolution ({d}):\n", .{def.resolution.len});
    for (def.resolution, 0..) |stmt, i| {
        std.debug.print("  [{d}] tag={s}\n", .{ i, @tagName(stmt) });
        switch (stmt) {
            .fill => |f| std.debug.print("      fill: dest='{s}', expr='{s}'\n", .{ f.dest_name, f.expr }),
            .pure_value => |v| std.debug.print("      pure_value: '{s}'\n", .{v}),
            .invoke => |inv| std.debug.print("      invoke: name='{s}', label='{s}'\n", .{ inv.name, inv.label orelse "none" }),
            else => {},
        }
    }
    std.debug.print("Contained ({d}):\n", .{def.contained.len});
    for (def.contained, 0..) |c, i| {
        std.debug.print("  [{d}] name='{s}', resolution.len={d}\n", .{ i, c.name, c.resolution.len });
    }
    std.debug.print("===============================\n", .{});
}

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

        // Unwrap the optional size array [width, height]
        if (domain.size) |size| {
            try testing.expectEqual(@as(usize, 300), size[0]);
            try testing.expectEqual(@as(usize, 500), size[1]);
        } else {
            return error.MissingDomainSize;
        }
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
        \\     1,1[TRUE]  
        \\]
    ;

    const net = try parser.parse(allocator, src);

    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    try testing.expectEqualStrings("binaryequal", def.name);

    // Sources: (a<> b<>)
    try testing.expectEqual(@as(usize, 2), def.sources.len);
    try testing.expectEqualStrings("a", def.sources[0].name);
    try testing.expectEqualStrings("b", def.sources[1].name);

    // No explicit destination list -> implicit single return path to caller,
    // synthesized as ms_result (§12.3.4).
    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqualStrings("ms_result", def.destinations[0].name);

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
        \\FULLADDTEST184($A,$B,$C)(<> CARRYOUT<>)
        \\
        \\FULLADDTEST184[(A<> B<> CI<> )($SUM $CO)
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

    try testing.expectEqualStrings("FULLADDTEST184", def.name);
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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "AND[(A<> B<>)<$A$B()>: 00[0] 01[0] 10[0] 11[1]]";

    try testing.expectError(parser.core.ParseError.AmbiguousComposedKey, parser.parse(allocator, src));
}

test "TAG-160 comma-separated multi-source keys parse as rules" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "OR160[(A<>B<>)<$A$B()>: 0,0[0] 0,1[1] 1,0[1] 1,1[1]]";

    const net = try parser.parse(allocator, src);

    // Exactly one definition in this source.
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];
    try testing.expectEqualStrings("OR160", def.name);

    // ---- Sources: two flat places ----
    try testing.expectEqual(@as(usize, 2), def.sources.len);
    try testing.expectEqualStrings("A", def.sources[0].name);
    try testing.expectEqualStrings("B", def.sources[1].name);

    // ---- Destination: synthesized from the anonymous < $A$B() > ----
    // The `<...>` form with no `($name)` header means the definition
    // returns to the place of invocation; the parser synthesizes a
    // single place named "ms_result".
    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqual(network.ArgKind.place, def.destinations[0].kind);
    try testing.expectEqualStrings("ms_result", def.destinations[0].name);
    try testing.expectEqualStrings("", def.destinations[0].text);

    // ---- Resolution: one fill with the composed key ----
    // `<$A$B()>` becomes fill { dest='ms_result', expr='$A$B()' }.
    try testing.expectEqual(@as(usize, 1), def.resolution.len);
    const res0 = def.resolution[0];
    try testing.expectEqual(
        std.meta.Tag(network.Statement).fill,
        std.meta.activeTag(res0),
    );
    try testing.expectEqualStrings("ms_result", res0.fill.dest_name);
    try testing.expectEqualStrings("$A$B()", res0.fill.expr);

    // ---- Contained rows: anonymous key→value, NOT fills ----
    // This is the crux: `0,0[0]` parses as name="0,0" with a single
    // `.pure_value` statement, NOT as a fill. The value `0` is what
    // gets asserted on the synthesized destination once the pattern
    // matches. If this ever becomes a `.fill` or `.invoke`, the
    // contained-lookup emitter (writeContainedLookupTable's
    // all_anonymous branch) will stop recognizing the shape.
    try testing.expectEqual(@as(usize, 4), def.contained.len);

    const RowExpect = struct { name: []const u8, value: []const u8 };
    const expected_rows = [_]RowExpect{
        .{ .name = "0,0", .value = "0" },
        .{ .name = "0,1", .value = "1" },
        .{ .name = "1,0", .value = "1" },
        .{ .name = "1,1", .value = "1" },
    };

    for (def.contained, expected_rows) |row, exp| {
        try testing.expectEqualStrings(exp.name, row.name);
        try testing.expectEqual(@as(usize, 0), row.sources.len);
        try testing.expectEqual(@as(usize, 0), row.destinations.len);
        try testing.expectEqual(@as(usize, 1), row.resolution.len);

        const stmt = row.resolution[0];
        try testing.expectEqual(
            std.meta.Tag(network.Statement).pure_value,
            std.meta.activeTag(stmt),
        );
        try testing.expectEqualStrings(exp.value, stmt.pure_value);
    }

    // ---- No entry invocation in this source ----
    // The source has no top-level `OR(...)` line, so `net.entries`
    // should be empty. (If you later add one to the source, this
    // assertion changes to check the entry's synthesized ms_result.)
    try testing.expectEqual(@as(usize, 0), net.entries.len);
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
        \\  AND[($A $B)(res<>)
        \\   $A$B()
        \\   : 0,0[res<0>]
        \\     0,1[res<0>]
        \\     1,0[res<0>]
        \\     1,1[res<1>]
        \\]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 2), net.definitions.len);

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

test "an unlabeled bare invoke with no destinations parses as a pure_value expression" {
    // Regression test for TAG-138's LTsteer: "LT($A $B)" is a bare
    // resolution statement with no destinations list and no label.
    // Companion to the TAG-192 test above, which confirms the
    // opposite case (a LABEL with empty destinations must stay a
    // real .invoke, since the label supplies a hygienic temporary
    // name for the implicit result). Without a label, there's no
    // name to hang a synthesized component instantiation off of, and
    // this shape is syntactically identical to the "$name(args)"
    // pure-value pattern (dualfanin's "$steer()") — just naming a
    // primitive function ("LT", "Equal") instead of a plain variable.
    // Before this fix, codegen tried to instantiate a nonexistent
    // "LT" component (ghdl: "unit ..._lt not found in library work").
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\LTSTEER[(A<>B<>)
        \\  LT($A $B) : True[out1<$A> out2<$B>]
        \\              False[out1<$B> out2<$A>]]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);

    const resolution = net.definitions[0].resolution;
    try testing.expectEqual(@as(usize, 1), resolution.len);
    try testing.expect(resolution[0] == .pure_value);
    try testing.expectEqualStrings("LT($A $B)", resolution[0].pure_value);
}

test "TAG-219 single-source definition with digit keys parses as rules, not pure_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\INNER[(A<>)($Y)
        \\  $A
        \\  :
        \\  0[Y<0>]
        \\  1[Y<1>]
        \\]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    // resolution must be the keyed-transition form, not pure_value

    // The source clause is recorded as a pure_value naming the sources
    // involved. This mirrors FULLADD (TAG-184), whose resolution clause
    // "$A $B $CI" is also a .pure_value. Matching is driven by the
    // contained rule entries, not by resolution[0].
    try testing.expectEqual(@as(usize, 1), def.resolution.len);
    try testing.expect(def.resolution[0] == .pure_value);

    // two rules, each a .fill, not two constants
    try testing.expectEqual(@as(usize, 2), def.contained.len);

    try testing.expectEqualStrings("0", def.contained[0].name);
    try testing.expectEqual(@as(usize, 1), def.contained[0].resolution.len);
    try testing.expect(def.contained[0].resolution[0] == .fill);
    try testing.expectEqualSlices(u8, "Y", def.contained[0].resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "0", def.contained[0].resolution[0].fill.expr);

    try testing.expectEqualStrings("1", def.contained[1].name);
    try testing.expectEqual(@as(usize, 1), def.contained[1].resolution.len);
    try testing.expect(def.contained[1].resolution[0] == .fill);
    try testing.expectEqualSlices(u8, "Y", def.contained[1].resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "1", def.contained[1].resolution[0].fill.expr);
}

test "TAG-219 single-source definition with identifier keys parses as rules" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\INNER[(A<>)($Y)
        \\  $A
        \\  :
        \\  K[Y<K>]
        \\  L[Y<L>]
        \\]
    ;

    const net = try parser.parse(allocator, src);
    const def = net.definitions[0];

    // ---- TEMPORARY DEBUG DUMP ----
    std.debug.print("\n--- INNER dump ---\n", .{});
    std.debug.print("resolution.len = {d}\n", .{def.resolution.len});
    for (def.resolution, 0..) |stmt, i| {
        std.debug.print("resolution[{d}] = .{s}\n", .{ i, @tagName(stmt) });
        switch (stmt) {
            .pure_value => |v| std.debug.print("  pure_value = '{s}'\n", .{v}),
            .invoke => |inv| std.debug.print("  invoke = '{s}'\n", .{inv.name}),
            .fill => |f| std.debug.print("  fill = {s}<{s}>\n", .{ f.dest_name, f.expr }),
            else => {},
        }
    }
    std.debug.print("contained.len = {d}\n", .{def.contained.len});
    for (def.contained, 0..) |c, i| {
        std.debug.print("contained[{d}].name = '{s}'\n", .{ i, c.name });
        std.debug.print("contained[{d}].sources.len = {d}\n", .{ i, c.sources.len });
        std.debug.print("contained[{d}].resolution.len = {d}\n", .{ i, c.resolution.len });
    }
    // ---- END TEMPORARY DEBUG DUMP ----

    try testing.expectEqual(@as(usize, 1), def.resolution.len);
    try testing.expect(def.resolution[0] == .pure_value);

    try testing.expectEqual(@as(usize, 2), def.contained.len);
    try testing.expectEqualStrings("K", def.contained[0].name);
    try testing.expect(def.contained[0].resolution[0] == .fill);
    try testing.expectEqualSlices(u8, "Y", def.contained[0].resolution[0].fill.dest_name);
    try testing.expectEqualSlices(u8, "K", def.contained[0].resolution[0].fill.expr);
}

test "TAG-219 trailing comma in single-segment key is a syntax error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // A trailing comma after a single key segment. The comma's only
    // purpose is to disambiguate multi-segment composed keys (e.g.
    // `0,S0` needing to split into `0` + `S0`). With one segment there
    // is nothing to disambiguate, so the comma is malformed, not a
    // no-op — accepting it silently would invite the reader to believe
    // it means something it doesn't.
    const src =
        \\INNER[(A<>)($Y)
        \\  $A
        \\  :
        \\  0,[Y<0>]
        \\  1,[Y<1>]
        \\]
    ;

    try testing.expectError(
        error.ExpectedToken, // adjust to core.ParseError.ExpectedToken if needed
        parser.parse(allocator, src),
    );
}

test "parseDefinition synthesizes ms_result for a definition with an implicit return" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // No destination list; resolution is a bare fill expression.
    // The parser should synthesize a single ms_result destination.
    const src =
        \\IMPLICIT[(a<> b<>)
        \\  <$a$b()>
        \\   : 0,0[TRUE]
        \\     0,1[FALSE]
        \\     1,0[FALSE]
        \\     1,1[TRUE]
        \\]
    ;

    const net = try parser.parse(allocator, src);
    const def = net.definitions[0];

    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqualStrings("ms_result", def.destinations[0].name);

    // The fill's dest_name should also have been rewritten by the parser's
    // fill-normalization pass (§12.3.4).
    try testing.expect(def.resolution.len > 0);
    try testing.expect(def.resolution[0] == .fill);
    try testing.expectEqualStrings("ms_result", def.resolution[0].fill.dest_name);
}

test "parseDefinition preserves an explicit destination list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\MYGATE[(a<> b<>)($q)
        \\  q<1>
        \\ :
        \\]
    ;

    const net = try parser.parse(allocator, src);
    const def = net.definitions[0];

    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqualStrings("q", def.destinations[0].name);
}

// --- flatten entry sources: arbitration is atomic, bundle and mutex expand ---
test "flatten entry sources: arbitration is atomic, bundle and mutex expand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // INNER gives WRAP something to invoke. WRAP's body calls INNER
    // with four source args exercising each group kind at the
    // invocation level:
    //
    //   0: bundle [A0 A1]      — flattens to 2 slots
    //   1: mutex  {B0 B1}      — flattens to 2 slots
    //   2: arbitration {{C0 C1}} — flattens to 1 slot (atomic)
    //   3: scalar D            — flattens to 1 slot
    //
    // The definitions themselves declare scalar members so INNER's
    // source list is unremarkable; the interesting structure lives
    // in the invocation.
    const src =
        \\INNER([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\INNER[([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\  $A0$A1$B0$B1$C0$C1$D : K[0]
        \\]
        \\WRAP([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\WRAP[([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\  INNER([$A0 $A1] {$B0 $B1} {{$C0 $C1}} $D)($OUT)
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("flatten test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var wrapper: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "WRAP")) wrapper = d;
    }
    try testing.expect(wrapper != null);
    try testing.expect(wrapper.?.resolution.len >= 1);

    // WRAP's resolution[0] must be an invocation of INNER. If the
    // parser produced a pure_value instead, resolution[0].invoke
    // would panic; assert the tag first so the failure is readable.
    const res0 = wrapper.?.resolution[0];
    const tag = std.meta.activeTag(res0);
    testing.expectEqualStrings("invoke", @tagName(tag)) catch |err| {
        std.debug.print(
            "WRAP.resolution[0]: expected invoke, got {s}\n",
            .{@tagName(tag)},
        );
        return err;
    };

    const invoke = res0.invoke;
    try testing.expect(std.ascii.eqlIgnoreCase(invoke.name, "INNER"));

    // The invocation has 4 top-level source args, one per group kind
    // plus the trailing scalar. Their AST shapes are what we assert.
    try testing.expectEqual(@as(usize, 4), invoke.sources.len);

    // Arg 0: bundle [A0 A1].
    try testing.expectEqual(network.ArgKind.group, invoke.sources[0].kind);
    try testing.expect(invoke.sources[0].group != null);
    try testing.expectEqual(network.PlaceGroupKind.bundle, invoke.sources[0].group.?.kind);
    try testing.expectEqual(@as(usize, 2), invoke.sources[0].group.?.places.len);

    // Arg 1: mutex {B0 B1}.
    try testing.expectEqual(network.ArgKind.group, invoke.sources[1].kind);
    try testing.expect(invoke.sources[1].group != null);
    try testing.expectEqual(network.PlaceGroupKind.mutex, invoke.sources[1].group.?.kind);
    try testing.expectEqual(@as(usize, 2), invoke.sources[1].group.?.places.len);

    // Arg 2: arbitration {{C0 C1}}.
    try testing.expectEqual(network.ArgKind.group, invoke.sources[2].kind);
    try testing.expect(invoke.sources[2].group != null);
    try testing.expectEqual(network.PlaceGroupKind.arbitration, invoke.sources[2].group.?.kind);
    try testing.expectEqual(@as(usize, 2), invoke.sources[2].group.?.places.len);

    // Arg 3: scalar D.
    try testing.expectEqual(network.ArgKind.place, invoke.sources[3].kind);
    try testing.expectEqualStrings("D", invoke.sources[3].name);

    // Flatten and assert the slot list.
    //
    //   bundle [A0 A1]        -> 2 slots (A0, A1)
    //   mutex  {B0 B1}        -> 2 slots (B0, B1)
    //   arbitration {{C0 C1}} -> 1 slot  (the group itself, atomic)
    //   scalar D              -> 1 slot  (D)
    //   total:                = 6 slots
    var slots: std.ArrayListUnmanaged(network.Arg) = .empty;
    defer slots.deinit(a);
    try network_entity.flattenEntrySources(a, invoke.sources, &slots);

    testing.expectEqual(@as(usize, 6), slots.items.len) catch |err| {
        std.debug.print("flatten produced {d} slots, expected 6:\n", .{slots.items.len});
        for (slots.items, 0..) |s, i| {
            std.debug.print(
                "  slot[{d}]: kind={s} name='{s}' group={s}\n",
                .{
                    i,
                    @tagName(s.kind),
                    s.name,
                    if (s.group) |g| @tagName(g.kind) else "none",
                },
            );
        }
        return err;
    };

    // Slots 0-1: the bundle's members, in order.
    try testing.expectEqual(network.ArgKind.place, slots.items[0].kind);
    try testing.expectEqualStrings("A0", slots.items[0].name);
    try testing.expectEqual(network.ArgKind.place, slots.items[1].kind);
    try testing.expectEqualStrings("A1", slots.items[1].name);

    // Slots 2-3: the mutex's members, in order.
    try testing.expectEqual(network.ArgKind.place, slots.items[2].kind);
    try testing.expectEqualStrings("B0", slots.items[2].name);
    try testing.expectEqual(network.ArgKind.place, slots.items[3].kind);
    try testing.expectEqualStrings("B1", slots.items[3].name);

    // Slot 4: the arbitration group itself, still a group. This is
    // the atomicity claim — flatten must NOT expand its members.
    testing.expectEqual(network.ArgKind.group, slots.items[4].kind) catch |err| {
        std.debug.print(
            "slot[4]: expected group (arbitration atomic), got {s} name='{s}'\n",
            .{ @tagName(slots.items[4].kind), slots.items[4].name },
        );
        return err;
    };
    try testing.expect(slots.items[4].group != null);
    try testing.expectEqual(
        network.PlaceGroupKind.arbitration,
        slots.items[4].group.?.kind,
    );
    try testing.expectEqual(@as(usize, 2), slots.items[4].group.?.places.len);

    // Slot 5: the trailing scalar.
    try testing.expectEqual(network.ArgKind.place, slots.items[5].kind);
    try testing.expectEqualStrings("D", slots.items[5].name);
}

test "arity invariant: top-level arg counts match across entry and DUT" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\INNER([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\INNER[([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\  $A0$A1$B0$B1$C0$C1$D : K[0]
        \\]
        \\WRAP([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\WRAP[([A0<> A1<>] {B0<> B1<>} {{C0<> C1<>}} D<>)(OUT<>)
        \\  INNER([$A0 $A1] {$B0 $B1} {{$C0 $C1}} $D)($OUT)
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("arity test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var wrapper: ?network.Definition = null;
    var inner: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "WRAP")) wrapper = d;
        if (std.ascii.eqlIgnoreCase(d.name, "INNER")) inner = d;
    }
    try testing.expect(wrapper != null);
    try testing.expect(inner != null);

    try testing.expect(wrapper.?.resolution.len >= 1);
    const invoke = wrapper.?.resolution[0].invoke;

    // The invariant the arity check relies on: the entry's top-level
    // source arg count equals the matched definition's top-level
    // source arg count.
    try testing.expectEqual(inner.?.sources.len, invoke.sources.len);
}

// --- rule decomposition: contained definitions whose names carry patterns ---
test "rule decomposition: AND's rules are contained defs named by pattern" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND[(A<> B<>)($result)
        \\  $A$B()
        \\  :0,0[0]
        \\   0,1[0]
        \\   1,0[0]
        \\   1,1[1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("AND rule test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var and_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND")) and_def = d;
    }
    try testing.expect(and_def != null);

    // Outer resolution names the input places the rule set observes.
    try testing.expectEqual(@as(usize, 1), and_def.?.resolution.len);
    try testing.expectEqual(network.Statement.pure_value, std.meta.activeTag(and_def.?.resolution[0]));
    const outer = and_def.?.resolution[0].pure_value;
    try testing.expectEqualStrings("$A$B()", outer);

    // Four contained definitions, one per rule.
    try testing.expectEqual(@as(usize, 4), and_def.?.contained.len);

    // The contained definitions must be named by their patterns, in
    // source order. If this fails, the parser is either reordering or
    // renaming, and buildRules can't rely on names-as-patterns.
    const expected_names = [_][]const u8{ "0,0", "0,1", "1,0", "1,1" };
    const expected_bodies = [_][]const u8{ "0", "0", "0", "1" };

    for (and_def.?.contained, expected_names, expected_bodies, 0..) |cd, want_name, want_body, i| {
        testing.expectEqualStrings(want_name, cd.name) catch |err| {
            std.debug.print(
                "contained[{d}].name: expected '{s}', got '{s}'\n",
                .{ i, want_name, cd.name },
            );
            return err;
        };
        try testing.expectEqual(@as(usize, 1), cd.resolution.len);
        try testing.expectEqual(network.Statement.pure_value, std.meta.activeTag(cd.resolution[0]));
        testing.expectEqualStrings(want_body, cd.resolution[0].pure_value) catch |err| {
            std.debug.print(
                "contained[{d}] body: expected '{s}', got '{s}'\n",
                .{ i, want_body, cd.resolution[0].pure_value },
            );
            return err;
        };
    }
}

test "rule decomposition: FULLADD's rules are contained defs named by pattern" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADDTESTDECOMP[(A<> B<> CI<>)($SUM $CO)
        \\  $A$B$CI
        \\  :
        \\  K,M[SUM<0>]
        \\  L,M[SUM<1>]
        \\  L,N[CO<1>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("FULLADDTESTDECOMP rule test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var fa_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "FULLADDTESTDECOMP")) fa_def = d;
    }
    try testing.expect(fa_def != null);

    // Outer resolution is the input-place composition. The doc says
    // $A$B$CI and $A$B$CI() are equivalent; the parser may preserve
    // either form. Assert the content without over-constraining the
    // exact spelling.
    try testing.expectEqual(@as(usize, 1), fa_def.?.resolution.len);
    try testing.expectEqual(network.Statement.pure_value, std.meta.activeTag(fa_def.?.resolution[0]));
    const outer_raw = fa_def.?.resolution[0].pure_value;
    const outer = std.mem.trim(u8, outer_raw, " \t\r\n");
    testing.expectEqualStrings("$A$B$CI", outer) catch |err| {
        std.debug.print(
            "FULLADDTESTDECOMP outer resolution: expected '$A$B$CI', got '{s}' (raw: '{s}')\n",
            .{ outer, outer_raw },
        );
        return err;
    };

    // Three rules in this reduced example.
    try testing.expectEqual(@as(usize, 3), fa_def.?.contained.len);

    const expected_names = [_][]const u8{ "K,M", "L,M", "L,N" };
    for (fa_def.?.contained, expected_names, 0..) |cd, want_name, i| {
        testing.expectEqualStrings(want_name, cd.name) catch |err| {
            std.debug.print(
                "contained[{d}].name: expected '{s}', got '{s}'\n",
                .{ i, want_name, cd.name },
            );
            return err;
        };
    }
}

// --- decomposeRules: decompose AND7's token rule set ---
test "decomposeRules: AND7's rule set decomposes to four fill outputs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND7[(A<> B<>)($result)
        \\  $A$B()
        \\  :0,0[result<0>]
        \\   0,1[result<0>]
        \\   1,0[result<0>]
        \\   1,1[result<1>]
        \\]
    ;

    const net = parser.parse(a, src) catch |err| {
        std.debug.print("decomposeRules AND7 test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var and_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND7")) and_def = d;
    }
    try testing.expect(and_def != null);

    const rs = (try rules.decomposeRules(a, and_def.?)) orelse {
        std.debug.print("decomposeRules returned null for AND7\n", .{});
        return error.TestUnexpectedResult;
    };

    // The outer resolution names two input places.
    try testing.expectEqual(@as(usize, 2), rs.inputs.places.len);
    try testing.expectEqualStrings("A", rs.inputs.places[0]);
    try testing.expectEqualStrings("B", rs.inputs.places[1]);

    // Four rules, in source order.
    try testing.expectEqual(@as(usize, 4), rs.rules.len);

    // Pattern 0,0 -> result<0>
    try testing.expectEqual(@as(usize, 2), rs.rules[0].pattern.symbols.len);
    try testing.expectEqualStrings("0", rs.rules[0].pattern.symbols[0]);
    try testing.expectEqualStrings("0", rs.rules[0].pattern.symbols[1]);
    try testing.expectEqualDeep(
        rules.Output{ .fill = .{ .dest = "result", .content = .{ .token = "0" } } },
        rs.rules[0].output,
    );

    // Pattern 0,1 -> result<0>
    try testing.expectEqualStrings("0", rs.rules[1].pattern.symbols[0]);
    try testing.expectEqualStrings("1", rs.rules[1].pattern.symbols[1]);
    try testing.expectEqualDeep(
        rules.Output{ .fill = .{ .dest = "result", .content = .{ .token = "0" } } },
        rs.rules[1].output,
    );

    // Pattern 1,0 -> result<0>
    try testing.expectEqualStrings("1", rs.rules[2].pattern.symbols[0]);
    try testing.expectEqualStrings("0", rs.rules[2].pattern.symbols[1]);
    try testing.expectEqualDeep(
        rules.Output{ .fill = .{ .dest = "result", .content = .{ .token = "0" } } },
        rs.rules[2].output,
    );

    // Pattern 1,1 -> result<1>
    try testing.expectEqualStrings("1", rs.rules[3].pattern.symbols[0]);
    try testing.expectEqualStrings("1", rs.rules[3].pattern.symbols[1]);
    try testing.expectEqualDeep(
        rules.Output{ .fill = .{ .dest = "result", .content = .{ .token = "1" } } },
        rs.rules[3].output,
    );
}
// --- decomposeRules: decompose FULLADD's rule set ---
test "decomposeRules: FULLADD's rules decompose to token outputs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADDTESTDECOMP1[(A<> B<> CI<>)($SUM$CO)
        \\  $A$B$CI
        \\  :
        \\  K,M[SUM0]
        \\  L,M[SUM1]
        \\  L,N[CO1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("decomposeRules FULLADDTESTDECOMP1 test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var fa_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "FULLADDTESTDECOMP1")) fa_def = d;
    }
    try testing.expect(fa_def != null);

    const rs = (try rules.decomposeRules(a, fa_def.?)) orelse {
        std.debug.print("decomposeRules returned null for FULLADD\n", .{});
        return error.TestUnexpectedResult;
    };

    // The outer resolution names three input places.
    try testing.expectEqual(@as(usize, 3), rs.inputs.places.len);
    try testing.expectEqualStrings("A", rs.inputs.places[0]);
    try testing.expectEqualStrings("B", rs.inputs.places[1]);
    try testing.expectEqualStrings("CI", rs.inputs.places[2]);

    // Three rules.
    try testing.expectEqual(@as(usize, 3), rs.rules.len);

    // Pattern K,M -> token SUM0
    try testing.expectEqual(@as(usize, 2), rs.rules[0].pattern.symbols.len);
    try testing.expectEqualStrings("K", rs.rules[0].pattern.symbols[0]);
    try testing.expectEqualStrings("M", rs.rules[0].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .token = "SUM0" }, rs.rules[0].output);
    try testing.expectEqualDeep(rules.Output{ .token = "SUM0" }, rs.rules[0].output);
    // Pattern L,M -> token SUM1
    try testing.expectEqualStrings("L", rs.rules[1].pattern.symbols[0]);
    try testing.expectEqualStrings("M", rs.rules[1].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .token = "SUM1" }, rs.rules[1].output);

    // Pattern L,N -> token CO1
    try testing.expectEqualStrings("L", rs.rules[2].pattern.symbols[0]);
    try testing.expectEqualStrings("N", rs.rules[2].pattern.symbols[1]);

    try testing.expectEqualDeep(rules.Output{ .token = "CO1" }, rs.rules[2].output);
}

// --- decomposeRules: fill with name content normalizes the name ---
test "decomposeRules: fill output normalizes name content" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\PASSTHRU[(A<>)($Y)
        \\  $A
        \\  :
        \\  K[Y<$A>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("decomposeRules fill test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "PASSTHRU")) def = d;
    }
    try testing.expect(def != null);

    const rs = (try rules.decomposeRules(a, def.?)) orelse {
        std.debug.print("decomposeRules returned null for PASSTHRU\n", .{});
        return error.TestUnexpectedResult;
    };

    try testing.expectEqual(@as(usize, 1), rs.rules.len);

    // Pattern: one token, "K".
    try testing.expectEqual(@as(usize, 1), rs.rules[0].pattern.symbols.len);
    try testing.expectEqualStrings("K", rs.rules[0].pattern.symbols[0]);

    // Output: fill { dest = "Y", content = token "A" }.
    //
    // The "$" prefix on the source reference is decoration; it is
    // stripped during parsing so the AST carries the bare token name.
    // Same convention as parseInputs, which strips "$" from the outer
    // composition.
    const output = rs.rules[0].output;
    const fill = switch (output) {
        .fill => |f| f,
        else => {
            std.debug.print("expected .fill output, got .{s}\n", .{@tagName(output)});
            return error.TestUnexpectedResult;
        },
    };
    try testing.expectEqualStrings("Y", fill.dest);

    const content = switch (fill.content) {
        .token => |s| s,
        else => {
            std.debug.print("expected .token content, got .{s}\n", .{@tagName(fill.content)});
            return error.TestUnexpectedResult;
        },
    };
    try testing.expectEqualStrings("A", content);
}

test "buildSymbolTable: AND8 interns 0 and 1 in first-seen order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND8[(A<> B<>)($result)
        \\  $A$B()
        \\  :0,0[result<0>]
        \\   0,1[result<0>]
        \\   1,0[result<0>]
        \\   1,1[result<1>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("buildSymbolTable AND8 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var and_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND8")) and_def = d;
    }
    try testing.expect(and_def != null);

    const rs = (try rules.decomposeRules(a, and_def.?)) orelse {
        std.debug.print("decomposeRules returned null for AND8\n", .{});
        return error.TestUnexpectedResult;
    };

    const table = try rules.buildSymbolTable(a, rs);

    // "0" is seen first (rule 0's pattern), then "1" (rule 1's second
    // pattern symbol). Both re-appear in later rules and later
    // outputs, but they're already interned.
    try testing.expectEqual(@as(usize, 2), table.entries.len);
    try testing.expectEqualStrings("0", table.entries[0]);
    try testing.expectEqualStrings("1", table.entries[1]);

    try testing.expectEqual(@as(u64, 0), table.lookup("0").?);
    try testing.expectEqual(@as(u64, 1), table.lookup("1").?);

    try testing.expectEqualStrings("0", table.nameOf(0).?);
    try testing.expectEqualStrings("1", table.nameOf(1).?);

    try testing.expect(table.lookup("2") == null);
    try testing.expect(table.nameOf(2) == null);
}

test "buildSymbolTable: FULLADD2 interns token names in first-seen order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADD2[(A<> B<> CI<>)($SUM$CO)
        \\  $A$B$CI
        \\  :
        \\  K,M[SUM0]
        \\  L,M[SUM1]
        \\  L,N[CO1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("buildSymbolTable FULLADD2 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var fa_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "FULLADD2")) fa_def = d;
    }
    try testing.expect(fa_def != null);

    const rs = (try rules.decomposeRules(a, fa_def.?)) orelse {
        std.debug.print("decomposeRules returned null for FULLADD2\n", .{});
        return error.TestUnexpectedResult;
    };

    const table = try rules.buildSymbolTable(a, rs);

    // Source-order first-seen:
    //   rule 0: pattern K, M  -> K=0, M=1
    //           output SUM0   -> SUM0=2
    //   rule 1: pattern L, M  -> L=3 (M already seen)
    //           output SUM1   -> SUM1=4
    //   rule 2: pattern L, N  -> N=5 (L already seen)
    //           output CO1    -> CO1=6
    try testing.expectEqual(@as(usize, 7), table.entries.len);
    try testing.expectEqualStrings("K", table.entries[0]);
    try testing.expectEqualStrings("M", table.entries[1]);
    try testing.expectEqualStrings("SUM0", table.entries[2]);
    try testing.expectEqualStrings("L", table.entries[3]);
    try testing.expectEqualStrings("SUM1", table.entries[4]);
    try testing.expectEqualStrings("N", table.entries[5]);
    try testing.expectEqualStrings("CO1", table.entries[6]);

    try testing.expectEqual(@as(u64, 0), table.lookup("K").?);
    try testing.expectEqual(@as(u64, 1), table.lookup("M").?);
    try testing.expectEqual(@as(u64, 2), table.lookup("SUM0").?);
    try testing.expectEqual(@as(u64, 3), table.lookup("L").?);
    try testing.expectEqual(@as(u64, 4), table.lookup("SUM1").?);
    try testing.expectEqual(@as(u64, 5), table.lookup("N").?);
    try testing.expectEqual(@as(u64, 6), table.lookup("CO1").?);
}

test "lowerRules: AND8 emits a case statement with four branches" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND8[(A<> B<>)($result)
        \\  $A$B()
        \\  :0,0[result<0>]
        \\   0,1[result<0>]
        \\   1,0[result<0>]
        \\   1,1[result<1>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("lowerRules AND8 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var and_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND8")) and_def = d;
    }
    try testing.expect(and_def != null);

    const rs = (try rules.decomposeRules(a, and_def.?)) orelse {
        std.debug.print("decomposeRules returned null for AND8\n", .{});
        return error.TestUnexpectedResult;
    };
    const table = try rules.buildSymbolTable(a, rs);

    var aw: std.Io.Writer.Allocating = .init(a);
    defer aw.deinit();

    try export_value_transform.lowerRules(a, &aw.writer, rs, table);

    const vhdl = aw.written();
    std.debug.print("\n--- lowerRules AND8 output ---\n{s}\n--- end ---\n", .{vhdl});

    // Symbol encoding comment lists both tokens in interning order.
    try testing.expect(std.mem.indexOf(u8, vhdl, "-- symbol encoding: 0=0, 1=1") != null);

    // Case statement is present.
    try testing.expect(std.mem.indexOf(u8, vhdl, "case ") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "end case;") != null);

    // Four branches with the expected case labels.
    // The DATA_WIDTH in the library is 7, so each token occupies
    // 7 bits. "0" interns to id 0 -> "0000000"; "1" to id 1 -> "0000001".
    try testing.expect(std.mem.indexOf(u8, vhdl, "when \"0000000\" & \"0000000\" => result <= data_value(0);") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "when \"0000000\" & \"0000001\" => result <= data_value(0);") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "when \"0000001\" & \"0000000\" => result <= data_value(0);") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "when \"0000001\" & \"0000001\" => result <= data_value(1);") != null);

    // Default fallback.
    try testing.expect(std.mem.indexOf(u8, vhdl, "when others => null;") != null);
}

test "TAG-143: unnamed destination parses to ms_result with composed-key fill" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\AND143($A $B)
        \\AND143[(X<>Y<>)
        \\<$X$Y()>
        \\:
        \\   0,0[0]
        \\   0,1[0]
        \\   1,1[1]
        \\   1,0[0]
        \\]
    ;

    const net = try parser.parse(a, src);

    // ---- Locate the definition ----
    const def = for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND143")) break d;
    } else return error.DefinitionNotFound;

    // ---- Definition: sources ----
    try std.testing.expectEqual(@as(usize, 2), def.sources.len);
    try std.testing.expectEqualStrings("X", def.sources[0].name);
    try std.testing.expectEqual(network.ArgKind.place, def.sources[0].kind);
    try std.testing.expectEqualStrings("X<>", def.sources[0].text);
    try std.testing.expectEqualStrings("Y", def.sources[1].name);
    try std.testing.expectEqual(network.ArgKind.place, def.sources[1].kind);
    try std.testing.expectEqualStrings("Y<>", def.sources[1].text);

    // ---- Definition: destinations ----
    // An unnamed destination `<$X$Y()>` is normalized by the parser
    // into a single synthesized place named "ms_result" whose text
    // is empty (it doesn't appear literally in the source).
    try std.testing.expectEqual(@as(usize, 1), def.destinations.len);
    try std.testing.expectEqual(network.ArgKind.place, def.destinations[0].kind);
    try std.testing.expectEqualStrings("ms_result", def.destinations[0].name);
    try std.testing.expectEqualStrings("", def.destinations[0].text);

    // ---- Definition: resolution ----
    // Exactly one statement: a fill routing the composed key
    // "$X$Y()" into the synthesized ms_result destination.
    try std.testing.expectEqual(@as(usize, 1), def.resolution.len);
    const res0 = def.resolution[0];
    try std.testing.expectEqual(std.meta.Tag(network.Statement).fill, std.meta.activeTag(res0));
    try std.testing.expectEqualStrings("ms_result", res0.fill.dest_name);
    try std.testing.expectEqualStrings("$X$Y()", res0.fill.expr);

    // ---- Definition: contained rows ----
    try std.testing.expectEqual(@as(usize, 4), def.contained.len);

    const RowExpect = struct { name: []const u8, value: []const u8 };
    const expected_rows = [_]RowExpect{
        .{ .name = "0,0", .value = "0" },
        .{ .name = "0,1", .value = "0" },
        .{ .name = "1,1", .value = "1" },
        .{ .name = "1,0", .value = "0" },
    };

    for (def.contained, expected_rows) |row, exp| {
        try std.testing.expectEqualStrings(exp.name, row.name);
        try std.testing.expectEqual(@as(usize, 0), row.sources.len);
        try std.testing.expectEqual(@as(usize, 0), row.destinations.len);
        try std.testing.expectEqual(@as(usize, 1), row.resolution.len);

        const stmt = row.resolution[0];
        try std.testing.expectEqual(
            std.meta.Tag(network.Statement).pure_value,
            std.meta.activeTag(stmt),
        );
        try std.testing.expectEqualStrings(exp.value, stmt.pure_value);
    }

    // ---- Entry ----
    // The entry invocation `AND143($A $B)` has no explicit destination
    // in the source; the parser synthesizes one named "ms_result" so
    // the network wrapper can bind it to the DUT's output port.
    const entry = for (net.entries) |e| {
        if (std.ascii.eqlIgnoreCase(e.name, "AND143")) break e;
    } else return error.EntryNotFound;

    try std.testing.expectEqual(@as(usize, 2), entry.sources.len);
    try std.testing.expectEqualStrings("A", entry.sources[0].name);
    try std.testing.expectEqualStrings("$A", entry.sources[0].text);
    try std.testing.expectEqualStrings("B", entry.sources[1].name);
    try std.testing.expectEqualStrings("$B", entry.sources[1].text);

    try std.testing.expectEqual(@as(usize, 1), entry.destinations.len);
    try std.testing.expectEqual(network.ArgKind.place, entry.destinations[0].kind);
    try std.testing.expectEqualStrings("ms_result", entry.destinations[0].name);
    try std.testing.expectEqualStrings("", entry.destinations[0].text);
}

test "TAG-144 variant: unnamed source-place destination parses to ms_result" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\AND144($A $B)
        \\AND144[(X<>Y<>)<>
        \\<$X$Y()>
        \\:
        \\   0,0[0]
        \\   0,1[0]
        \\   1,1[1]
        \\   1,0[0]
        \\]
    ;

    const net = try parser.parse(a, src);

    const def = for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND144")) break d;
    } else return error.DefinitionNotFound;

    // ---- Sources: unchanged ----
    try std.testing.expectEqual(@as(usize, 2), def.sources.len);
    try std.testing.expectEqualStrings("X", def.sources[0].name);
    try std.testing.expectEqualStrings("X<>", def.sources[0].text);
    try std.testing.expectEqualStrings("Y", def.sources[1].name);
    try std.testing.expectEqualStrings("Y<>", def.sources[1].text);

    // ---- Destinations: same synthesized ms_result ----
    // The `<>` after the source list is an *unnamed destination*
    // expressed in source-list position. The parser normalizes it to
    // the same synthesized place as the bare `<$X$Y()>` form, so
    // the emitted VHDL is identical between the two variants.
    try std.testing.expectEqual(@as(usize, 1), def.destinations.len);
    try std.testing.expectEqual(network.ArgKind.place, def.destinations[0].kind);
    try std.testing.expectEqualStrings("ms_result", def.destinations[0].name);
    try std.testing.expectEqualStrings("", def.destinations[0].text);

    // ---- Resolution: same composed-key fill ----
    try std.testing.expectEqual(@as(usize, 1), def.resolution.len);
    const res0 = def.resolution[0];
    try std.testing.expectEqual(
        std.meta.Tag(network.Statement).fill,
        std.meta.activeTag(res0),
    );
    try std.testing.expectEqualStrings("ms_result", res0.fill.dest_name);
    try std.testing.expectEqualStrings("$X$Y()", res0.fill.expr);

    // ---- Contained rows: identical to the non-variant test ----
    try std.testing.expectEqual(@as(usize, 4), def.contained.len);
    const RowExpect = struct { name: []const u8, value: []const u8 };
    const expected_rows = [_]RowExpect{
        .{ .name = "0,0", .value = "0" },
        .{ .name = "0,1", .value = "0" },
        .{ .name = "1,1", .value = "1" },
        .{ .name = "1,0", .value = "0" },
    };
    for (def.contained, expected_rows) |row, exp| {
        try std.testing.expectEqualStrings(exp.name, row.name);
        try std.testing.expectEqual(@as(usize, 1), row.resolution.len);
        const stmt = row.resolution[0];
        try std.testing.expectEqual(
            std.meta.Tag(network.Statement).pure_value,
            std.meta.activeTag(stmt),
        );
        try std.testing.expectEqualStrings(exp.value, stmt.pure_value);
    }

    // ---- Entry: same as before ----
    const entry = for (net.entries) |e| {
        if (std.ascii.eqlIgnoreCase(e.name, "AND144")) break e;
    } else return error.EntryNotFound;
    try std.testing.expectEqual(@as(usize, 2), entry.sources.len);
    try std.testing.expectEqual(@as(usize, 1), entry.destinations.len);
    try std.testing.expectEqualStrings("ms_result", entry.destinations[0].name);
    try std.testing.expectEqualStrings("", entry.destinations[0].text);
}

test "TAG-142 variant: unbracketed composed key after bare '<>' parses to ms_result" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\AND142($A $B)
        \\AND142[(X<>Y<>)<>
        \\  $X$Y() :
        \\    0,0[0]
        \\    0,1[0]
        \\    1,0[0]
        \\    1,1[1]
        \\]
    ;

    const net = try parser.parse(a, src);

    const def = for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND142")) break d;
    } else return error.DefinitionNotFound;

    // ---- Sources: unchanged ----
    try std.testing.expectEqual(@as(usize, 2), def.sources.len);
    try std.testing.expectEqualStrings("X", def.sources[0].name);
    try std.testing.expectEqualStrings("X<>", def.sources[0].text);
    try std.testing.expectEqualStrings("Y", def.sources[1].name);
    try std.testing.expectEqualStrings("Y<>", def.sources[1].text);

    // ---- Destinations: same synthesized ms_result ----
    try std.testing.expectEqual(@as(usize, 1), def.destinations.len);
    try std.testing.expectEqual(network.ArgKind.place, def.destinations[0].kind);
    try std.testing.expectEqualStrings("ms_result", def.destinations[0].name);
    try std.testing.expectEqualStrings("", def.destinations[0].text);

    // ---- Resolution: this is the crux ----
    // The bare '<>' followed by an unbracketed '$X$Y()' must
    // normalize to the same single fill as the bracketed form:
    // one statement, dest='ms_result', expr='$X$Y()'. Before the
    // parseResolution merge, this shape produced two statements
    // (empty fill + pure_value) and diverged from the canonical
    // form, breaking decomposeRules downstream.
    try std.testing.expectEqual(@as(usize, 1), def.resolution.len);
    const res0 = def.resolution[0];
    try std.testing.expectEqual(
        std.meta.Tag(network.Statement).fill,
        std.meta.activeTag(res0),
    );
    try std.testing.expectEqualStrings("ms_result", res0.fill.dest_name);
    try std.testing.expectEqualStrings("$X$Y()", res0.fill.expr);

    // ---- Contained rows: identical to the other two forms ----
    try std.testing.expectEqual(@as(usize, 4), def.contained.len);

    const RowExpect = struct { name: []const u8, value: []const u8 };
    // Source order preserved: 0,0 0,1 1,0 1,1
    const expected_rows = [_]RowExpect{
        .{ .name = "0,0", .value = "0" },
        .{ .name = "0,1", .value = "0" },
        .{ .name = "1,0", .value = "0" },
        .{ .name = "1,1", .value = "1" },
    };

    for (def.contained, expected_rows) |row, exp| {
        try std.testing.expectEqualStrings(exp.name, row.name);
        try std.testing.expectEqual(@as(usize, 0), row.sources.len);
        try std.testing.expectEqual(@as(usize, 0), row.destinations.len);
        try std.testing.expectEqual(@as(usize, 1), row.resolution.len);

        const stmt = row.resolution[0];
        try std.testing.expectEqual(
            std.meta.Tag(network.Statement).pure_value,
            std.meta.activeTag(stmt),
        );
        try std.testing.expectEqualStrings(exp.value, stmt.pure_value);
    }

    // ---- Entry: same as the other two forms ----
    const entry = for (net.entries) |e| {
        if (std.ascii.eqlIgnoreCase(e.name, "AND142")) break e;
    } else return error.EntryNotFound;

    try std.testing.expectEqual(@as(usize, 2), entry.sources.len);
    try std.testing.expectEqualStrings("A", entry.sources[0].name);
    try std.testing.expectEqualStrings("$A", entry.sources[0].text);
    try std.testing.expectEqualStrings("B", entry.sources[1].name);
    try std.testing.expectEqualStrings("$B", entry.sources[1].text);

    try std.testing.expectEqual(@as(usize, 1), entry.destinations.len);
    try std.testing.expectEqual(network.ArgKind.place, entry.destinations[0].kind);
    try std.testing.expectEqualStrings("ms_result", entry.destinations[0].name);
    try std.testing.expectEqualStrings("", entry.destinations[0].text);
}

test "TAG-151: bundling mutually exclusive paths into a single path" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\OR151($A $B)(Y< >)
        \\OR151[( [{A0< > A1< >}] [{B0< > B1< >}] ) ( [{$0 $1}] )
        \\     1< 3of6($A1 $A1 $A0 $B0 $B1 $B1) >  // output = 1
        \\     0< 2of2($A0 $B0) >                  // output = 0
        \\     : 
        \\]
        \\
        \\2of2[(A<> B<>)(Y<>)
        \\  $A$B : K[Y<0>]
        \\]
        \\
        \\3of6[(I0<> I1<> I2<> I3<> I4<> I5<>)(Y<>)
        \\  $I0$I1$I2$I3$I4$I5() : K[Y<0>]
        \\]
    ;

    const net = try parser.parse(a, src);

    // ---- Verify top-level definitions ----
    try std.testing.expectEqual(@as(usize, 3), net.definitions.len);

    const def = for (net.definitions) |d| {
        dumpAst(d);
        if (std.ascii.eqlIgnoreCase(d.name, "OR151")) break d;
    } else return error.DefinitionNotFound;

    // Because 2of2 and 3of6 are top-level definitions, OR151 has no contained definitions
    try std.testing.expectEqual(@as(usize, 0), def.contained.len);

    // ---- Sources: bundled mutex groups ----
    try std.testing.expectEqual(@as(usize, 2), def.sources.len);
    try std.testing.expectEqual(network.ArgKind.group, def.sources[0].kind);
    try std.testing.expectEqual(network.ArgKind.group, def.sources[1].kind);

    // ---- Destinations: bundled mutex group output ----
    try std.testing.expectEqual(@as(usize, 1), def.destinations.len);
    try std.testing.expectEqual(network.ArgKind.group, def.destinations[0].kind);

    // ---- Resolution: two invocations, one per destination member ----
    try std.testing.expectEqual(@as(usize, 2), def.resolution.len);

    // res[0]: `1< 3of6($A1 $A1 $A0 $B0 $B1 $B1) >`
    const res0 = def.resolution[0];
    try std.testing.expectEqual(
        std.meta.Tag(network.Statement).invoke,
        std.meta.activeTag(res0),
    );
    try std.testing.expectEqualStrings("3of6", res0.invoke.name);
    try std.testing.expectEqual(@as(usize, 6), res0.invoke.sources.len);
    try std.testing.expectEqualStrings("A1", res0.invoke.sources[0].name);
    try std.testing.expectEqualStrings("A1", res0.invoke.sources[1].name);
    try std.testing.expectEqualStrings("A0", res0.invoke.sources[2].name);
    try std.testing.expectEqualStrings("B0", res0.invoke.sources[3].name);
    try std.testing.expectEqualStrings("B1", res0.invoke.sources[4].name);
    try std.testing.expectEqualStrings("B1", res0.invoke.sources[5].name);
    try std.testing.expectEqual(@as(usize, 1), res0.invoke.destinations.len);
    try std.testing.expectEqualStrings("1", res0.invoke.destinations[0].name);

    // res[1]: `0< 2of2($A0 $B0) >`
    const res1 = def.resolution[1];
    try std.testing.expectEqual(
        std.meta.Tag(network.Statement).invoke,
        std.meta.activeTag(res1),
    );
    try std.testing.expectEqualStrings("2of2", res1.invoke.name);
    try std.testing.expectEqual(@as(usize, 2), res1.invoke.sources.len);
    try std.testing.expectEqualStrings("A0", res1.invoke.sources[0].name);
    try std.testing.expectEqualStrings("B0", res1.invoke.sources[1].name);
    try std.testing.expectEqual(@as(usize, 1), res1.invoke.destinations.len);
    try std.testing.expectEqualStrings("0", res1.invoke.destinations[0].name);

    // ---- Entry: flattened interface mapping ----
    const entry = for (net.entries) |e| {
        if (std.ascii.eqlIgnoreCase(e.name, "OR151")) break e;
    } else return error.EntryNotFound;

    try std.testing.expectEqual(@as(usize, 2), entry.sources.len);
    try std.testing.expectEqualStrings("A", entry.sources[0].name);
    try std.testing.expectEqualStrings("B", entry.sources[1].name);

    try std.testing.expectEqual(@as(usize, 1), entry.destinations.len);
    try std.testing.expectEqualStrings("Y", entry.destinations[0].name);
}

test "TAG-163: set of definitions establishing correspondence name convention" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\// Linear - TAG-163 Set of definitions establishing correspondence name convention
        \\
        \\TAG163_TOP[(a<> b<>)($result)
        \\  BINEQ($a $b)(eq<>)
        \\  BIGT($a $b)(gt<>)
        \\  LAND($a $b)(andout<>)
        \\  LNOT($a)(notout<>)
        \\
        \\  $eq$gt$andout$notout() :
        \\    TRUE,FALSE,TRUE,FALSE[result<TRUE>]      // (TRUE,TRUE)
        \\    FALSE,TRUE,FALSE,FALSE[result<FALSE>]    // (TRUE,FALSE)
        \\    FALSE,FALSE,FALSE,TRUE[result<FALSE>]    // (FALSE,TRUE)
        \\    TRUE,FALSE,FALSE,TRUE[result<TRUE>]      // (FALSE,FALSE)
        \\]
        \\
        \\BINEQ[(a<> b<>)($eq)
        \\  $a$b() :
        \\    FALSE,FALSE[eq<TRUE>]
        \\    FALSE,TRUE[eq<FALSE>]
        \\    TRUE,FALSE[eq<FALSE>]
        \\    TRUE,TRUE[eq<TRUE>]
        \\]
        \\
        \\BIGT[(a<> b<>)($gt)
        \\  $a$b() :
        \\    FALSE,FALSE[gt<FALSE>]
        \\    FALSE,TRUE[gt<FALSE>]
        \\    TRUE,FALSE[gt<TRUE>]
        \\    TRUE,TRUE[gt<FALSE>]
        \\]
        \\
        \\LAND[(a<> b<>)($andout)
        \\  $a$b() :
        \\    FALSE,FALSE[andout<FALSE>]
        \\    FALSE,TRUE[andout<FALSE>]
        \\    TRUE,FALSE[andout<FALSE>]
        \\    TRUE,TRUE[andout<TRUE>]
        \\]
        \\
        \\LNOT[(a<>)($notout)
        \\  $a() :
        \\    TRUE[notout<FALSE>]
        \\    FALSE[notout<TRUE>]
        \\]
    ;

    const net = try parser.parse(a, src);

    // ---- Verify top-level definitions (TAG163_TOP, BINEQ, BIGT, LAND, LNOT) ----
    try std.testing.expectEqual(@as(usize, 5), net.definitions.len);

    for (net.definitions) |d| {
        dumpAst(d);
    }

    // ---- Verify TAG163_TOP definition shape ----
    const top_def = for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "TAG163_TOP")) break d;
    } else return error.DefinitionNotFound;

    // Sources: (a<> b<>)
    try std.testing.expectEqual(@as(usize, 2), top_def.sources.len);
    try std.testing.expectEqualStrings("a", top_def.sources[0].name);
    try std.testing.expectEqualStrings("b", top_def.sources[1].name);

    // Destinations: ($result) synthesized or explicit
    try std.testing.expectEqual(@as(usize, 1), top_def.destinations.len);
    try std.testing.expectEqualStrings("result", top_def.destinations[0].name);

    // Resolution: 4 invocations + 1 composed-key pure_value header = 5 statements
    try std.testing.expectEqual(@as(usize, 5), top_def.resolution.len);

    // Check invocations
    try std.testing.expectEqual(network.Statement.invoke, std.meta.activeTag(top_def.resolution[0]));
    try std.testing.expectEqualStrings("BINEQ", top_def.resolution[0].invoke.name);

    try std.testing.expectEqual(network.Statement.invoke, std.meta.activeTag(top_def.resolution[1]));
    try std.testing.expectEqualStrings("BIGT", top_def.resolution[1].invoke.name);

    try std.testing.expectEqual(network.Statement.invoke, std.meta.activeTag(top_def.resolution[2]));
    try std.testing.expectEqualStrings("LAND", top_def.resolution[2].invoke.name);

    try std.testing.expectEqual(network.Statement.invoke, std.meta.activeTag(top_def.resolution[3]));
    try std.testing.expectEqualStrings("LNOT", top_def.resolution[3].invoke.name);

    // Check composed-key pure_value statement
    try std.testing.expectEqual(network.Statement.pure_value, std.meta.activeTag(top_def.resolution[4]));
    try std.testing.expectEqualStrings("$eq$gt$andout$notout()", top_def.resolution[4].pure_value);

    // Contained rows for TAG163_TOP truth-table
    try std.testing.expectEqual(@as(usize, 4), top_def.contained.len);
    try std.testing.expectEqualStrings("TRUE,FALSE,TRUE,FALSE", top_def.contained[0].name);
    try std.testing.expectEqualStrings("FALSE,TRUE,FALSE,FALSE", top_def.contained[1].name);
    try std.testing.expectEqualStrings("FALSE,FALSE,FALSE,TRUE", top_def.contained[2].name);
    try std.testing.expectEqualStrings("TRUE,FALSE,FALSE,TRUE", top_def.contained[3].name);

    // ---- Verify Leaf Definition: BINEQ ----
    const bineq_def = for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "BINEQ")) break d;
    } else return error.DefinitionNotFound;

    try std.testing.expectEqual(@as(usize, 2), bineq_def.sources.len);
    try std.testing.expectEqual(@as(usize, 1), bineq_def.destinations.len);
    try std.testing.expectEqualStrings("eq", bineq_def.destinations[0].name);
    try std.testing.expectEqual(@as(usize, 4), bineq_def.contained.len);
    try std.testing.expectEqualStrings("FALSE,FALSE", bineq_def.contained[0].name);
}

test "TAG-149: mutex completeness with explicit per-row destinations" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const src =
        \\ORTest149[({A0<> A1<>}{B0<> B1<>})({$0 $1})
        \\  :
        \\  A0,B0[0<0>]
        \\  A0,B1[1<1>]
        \\  A1,B0[1<1>]
        \\  A1,B1[1<1>]
        \\]
    ;

    const net = try parser.parse(a, src);

    // ---- One top-level definition, no entries needed for this test ----
    try std.testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];
    try std.testing.expectEqualStrings("ORTest149", def.name);

    // ---- Sources: two mutex groups ----
    try std.testing.expectEqual(@as(usize, 2), def.sources.len);
    try std.testing.expectEqual(network.ArgKind.group, def.sources[0].kind);
    try std.testing.expectEqual(network.ArgKind.group, def.sources[1].kind);
    {
        const sg0 = def.sources[0].group.?;
        const sg1 = def.sources[1].group.?;
        try std.testing.expectEqual(network.PlaceGroupKind.mutex, sg0.kind);
        try std.testing.expectEqual(network.PlaceGroupKind.mutex, sg1.kind);
        try std.testing.expectEqual(@as(usize, 2), sg0.places.len);
        try std.testing.expectEqual(@as(usize, 2), sg1.places.len);
    }

    // ---- Destination: one mutex group with two members ----
    try std.testing.expectEqual(@as(usize, 1), def.destinations.len);
    try std.testing.expectEqual(network.ArgKind.group, def.destinations[0].kind);
    {
        const dg = def.destinations[0].group.?;
        try std.testing.expectEqual(network.PlaceGroupKind.mutex, dg.kind);
        try std.testing.expectEqual(@as(usize, 2), dg.places.len);
        try std.testing.expectEqualStrings("0", dg.places[0].name);
        try std.testing.expectEqualStrings("1", dg.places[1].name);
    }
    // ---- Resolution: no fill/pure_value at top level (rules-only shape) ----
    try std.testing.expectEqual(@as(usize, 0), def.resolution.len);

    // ---- Contained rows: composed-key names + explicit <dest> fills ----
    try std.testing.expectEqual(@as(usize, 4), def.contained.len);

    const expected = [_]struct {
        name: []const u8,
        dest: []const u8,
        expr: []const u8,
    }{
        .{ .name = "A0,B0", .dest = "0", .expr = "0" },
        .{ .name = "A0,B1", .dest = "1", .expr = "1" },
        .{ .name = "A1,B0", .dest = "1", .expr = "1" },
        .{ .name = "A1,B1", .dest = "1", .expr = "1" },
    };

    for (def.contained, expected) |row, want| {
        try std.testing.expectEqualStrings(want.name, row.name);

        // A contained row is a nested Definition with no I/O...
        try std.testing.expectEqual(@as(usize, 0), row.sources.len);
        try std.testing.expectEqual(@as(usize, 0), row.destinations.len);

        // ...and exactly one synthesized fill from the [sym<dest>] bracket.
        try std.testing.expectEqual(@as(usize, 1), row.resolution.len);
        const stmt = row.resolution[0];
        try std.testing.expectEqual(
            std.meta.Tag(network.Statement).fill,
            std.meta.activeTag(stmt),
        );
        try std.testing.expectEqualStrings(want.dest, stmt.fill.dest_name);
        try std.testing.expectEqualStrings(want.expr, stmt.fill.expr);
    }
}

test "TAG-149: bare [N] on a group destination is rejected as ambiguous" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    // TAG-149 Example 12.9 as currently written: bare [0]/[1] brackets
    // against a two-member mutex destination {$0 $1}. The bracket says
    // "emit symbol N" but does not say which of $0/$1 receives it. The
    // parser should reject this; the [sym<dest>] form (A0,B0[0<0>])
    // disambiguates.
    const src =
        \\OR[({A0<> A1<>}{B0<> B1<>})({$0 $1})
        \\  :
        \\  A0,B0[0]
        \\  A0,B1[1]
        \\  A1,B0[1]
        \\  A1,B1[1]
        \\]
    ;

    try std.testing.expectError(error.AmbiguousContainedDestination, parser.parse(a, src));
}