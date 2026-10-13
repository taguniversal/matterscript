// src/tests/parser_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const boundary = matterscript.boundary;
const network_entity = matterscript.vhdl.network_entity;
const rules = matterscript.runtime.rules;

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

    const src = "OR[(A<>B<>)<$A$B()>: 0,0[0] 0,1[1] 1,0[1] 1,1[1]]";

    const net = try parser.parse(allocator, src);
    const def = net.definitions[0];

    try testing.expectEqual(@as(usize, 4), def.contained.len);
    try testing.expectEqualStrings("0,0", def.contained[0].name);
    // ...assert .fill shape as in the tests above...
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
test "rule decomposition: AND's numeric rules are contained defs named by pattern" {
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

test "rule decomposition: FULLADD's symbolic rules are contained defs named by pattern" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADD[(A<> B<> CI<>)($SUM$CO)
        \\  $A$B$CI
        \\  :
        \\  K,M[SUM0]
        \\  L,M[SUM1]
        \\  L,N[CO1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("FULLADD rule test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var fa_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "FULLADD")) fa_def = d;
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
            "FULLADD outer resolution: expected '$A$B$CI', got '{s}' (raw: '{s}')\n",
            .{ outer, outer_raw },
        );
        return err;
    };

    // Three symbolic rules in this reduced example.
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

// --- decomposeRules: decompose AND's numeric rule set ---
test "decomposeRules: AND's numeric rule set decomposes to four literal rules" {
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
        std.debug.print("decomposeRules AND test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var and_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "AND")) and_def = d;
    }
    try testing.expect(and_def != null);

    const rs = (try rules.decomposeRules(a, and_def.?)) orelse {
        std.debug.print("decomposeRules returned null for AND\n", .{});
        return error.TestUnexpectedResult;
    };

    // The outer resolution names two input places.
    try testing.expectEqual(@as(usize, 2), rs.inputs.places.len);
    try testing.expectEqualStrings("A", rs.inputs.places[0]);
    try testing.expectEqualStrings("B", rs.inputs.places[1]);

    // Four rules, in source order.
    try testing.expectEqual(@as(usize, 4), rs.rules.len);

    // Pattern 0,0 -> literal 0
    try testing.expectEqual(@as(usize, 2), rs.rules[0].pattern.symbols.len);
    try testing.expectEqualStrings("0", rs.rules[0].pattern.symbols[0]);
    try testing.expectEqualStrings("0", rs.rules[0].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .literal = 0 }, rs.rules[0].output);
    // Pattern 0,1 -> literal 0
    try testing.expectEqualStrings("0", rs.rules[1].pattern.symbols[0]);
    try testing.expectEqualStrings("1", rs.rules[1].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .literal = 0 }, rs.rules[1].output);

    // Pattern 1,0 -> literal 0
    try testing.expectEqualStrings("1", rs.rules[2].pattern.symbols[0]);
    try testing.expectEqualStrings("0", rs.rules[2].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .literal = 0 }, rs.rules[2].output);

    // Pattern 1,1 -> literal 1
    try testing.expectEqualStrings("1", rs.rules[3].pattern.symbols[0]);
    try testing.expectEqualStrings("1", rs.rules[3].pattern.symbols[1]);
    try testing.expectEqual(rules.Output{ .literal = 1 }, rs.rules[3].output);
}

// --- decomposeRules: decompose FULLADD's symbolic rule set ---
test "decomposeRules: FULLADD's symbolic rules decompose to symbol outputs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADD[(A<> B<> CI<>)($SUM$CO)
        \\  $A$B$CI
        \\  :
        \\  K,M[SUM0]
        \\  L,M[SUM1]
        \\  L,N[CO1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("decomposeRules FULLADD test FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    var fa_def: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "FULLADD")) fa_def = d;
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

    // Pattern K,M -> symbol SUM0
    try testing.expectEqual(@as(usize, 2), rs.rules[0].pattern.symbols.len);
    try testing.expectEqualStrings("K", rs.rules[0].pattern.symbols[0]);
    try testing.expectEqualStrings("M", rs.rules[0].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .symbol = "SUM0" }, rs.rules[0].output);
    try testing.expectEqualDeep(rules.Output{ .symbol = "SUM0" }, rs.rules[0].output);
    // Pattern L,M -> symbol SUM1
    try testing.expectEqualStrings("L", rs.rules[1].pattern.symbols[0]);
    try testing.expectEqualStrings("M", rs.rules[1].pattern.symbols[1]);
    try testing.expectEqualDeep(rules.Output{ .symbol = "SUM1" }, rs.rules[1].output);
 
    // Pattern L,N -> symbol CO1
    try testing.expectEqualStrings("L", rs.rules[2].pattern.symbols[0]);
    try testing.expectEqualStrings("N", rs.rules[2].pattern.symbols[1]);
    
    try testing.expectEqualDeep(rules.Output{ .symbol = "CO1" }, rs.rules[2].output);
}
