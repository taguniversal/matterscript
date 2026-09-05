// src/tests/parser_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

// Import the module relative to this test file
const parser = matterscript.ipl_parser;
pub const network = matterscript.network;

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
    try testing.expectEqualStrings("anon_0", def.contained[0].name);
    try testing.expectEqual(@as(usize, 2), def.contained[0].sources.len);
    try testing.expectEqualStrings("0", def.contained[0].sources[0].name);
    try testing.expectEqualStrings("0", def.contained[0].sources[1].name);
    try testing.expectEqual(@as(usize, 1), def.contained[0].destinations.len);
    try testing.expectEqualStrings("TRUE", def.contained[0].destinations[0].name);

    // Row 1: 0, 1 [FALSE]
    try testing.expectEqualStrings("anon_1", def.contained[1].name);
    try testing.expectEqual(@as(usize, 2), def.contained[1].sources.len);
    try testing.expectEqualStrings("0", def.contained[1].sources[0].name);
    try testing.expectEqualStrings("1", def.contained[1].sources[1].name);
    try testing.expectEqual(@as(usize, 1), def.contained[1].destinations.len);
    try testing.expectEqualStrings("FALSE", def.contained[1].destinations[0].name);

    // Row 2: 1, 0 [FALSE]
    try testing.expectEqualStrings("anon_2", def.contained[2].name);
    try testing.expectEqual(@as(usize, 2), def.contained[2].sources.len);
    try testing.expectEqualStrings("1", def.contained[2].sources[0].name);
    try testing.expectEqualStrings("0", def.contained[2].sources[1].name);
    try testing.expectEqual(@as(usize, 1), def.contained[2].destinations.len);
    try testing.expectEqualStrings("FALSE", def.contained[2].destinations[0].name);

    // Row 3: 1, 1 [TRUE]
    try testing.expectEqualStrings("anon_3", def.contained[3].name);
    try testing.expectEqual(@as(usize, 2), def.contained[3].sources.len);
    try testing.expectEqualStrings("1", def.contained[3].sources[0].name);
    try testing.expectEqualStrings("1", def.contained[3].sources[1].name);
    try testing.expectEqual(@as(usize, 1), def.contained[3].destinations.len);
    try testing.expectEqualStrings("TRUE", def.contained[3].destinations[0].name);
    
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
    try testing.expectEqualStrings("$out1", dest_group.places[0].name);
    try testing.expectEqualStrings("$out2", dest_group.places[1].name);
    try testing.expectEqualStrings("$out3", dest_group.places[2].name);
    try testing.expectEqualStrings("$out4", dest_group.places[3].name);
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
    try testing.expectEqual(network.ArgKind.group, def.sources[0].kind);

    try testing.expectEqualStrings("A", def.sources[1].name);
    try testing.expectEqual(network.ArgKind.group, def.sources[1].kind);

    try testing.expectEqualStrings("b", def.sources[2].name);
    try testing.expectEqual(network.ArgKind.group, def.sources[2].kind);

    try testing.expectEqualStrings("B", def.sources[3].name);
    try testing.expectEqual(network.ArgKind.group, def.sources[3].kind);

    // Verify destinations: ($result)
    try testing.expectEqual(@as(usize, 1), def.destinations.len);
    try testing.expectEqualStrings("$result", def.destinations[0].name);

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

    // Validate Row 1: S,U,W[SUM<S> CO<W>]
    const row0 = def.contained[0];
    try testing.expectEqual(@as(usize, 3), row0.sources.len);
    try testing.expectEqualStrings("S", row0.sources[0].name);
    try testing.expectEqualStrings("U", row0.sources[1].name);
    try testing.expectEqualStrings("W", row0.sources[2].name);
    try testing.expectEqual(@as(usize, 2), row0.destinations.len);
    try testing.expectEqualStrings("SUM", row0.destinations[0].name);
    try testing.expectEqualStrings("CO", row0.destinations[1].name);

    // Validate Row 2: S,U,X[SUM<T> CO<W>]
    const row1 = def.contained[1];
    try testing.expectEqual(@as(usize, 3), row1.sources.len);
    try testing.expectEqualStrings("S", row1.sources[0].name);
    try testing.expectEqualStrings("U", row1.sources[1].name);
    try testing.expectEqualStrings("X", row1.sources[2].name);
    try testing.expectEqual(@as(usize, 2), row1.destinations.len);
    try testing.expectEqualStrings("SUM", row1.destinations[0].name);
    try testing.expectEqualStrings("CO", row1.destinations[1].name);

    // Validate final Row 8: T,V,X[SUM<T> CO<X>]
    const row7 = def.contained[7];
    try testing.expectEqual(@as(usize, 3), row7.sources.len);
    try testing.expectEqualStrings("T", row7.sources[0].name);
    try testing.expectEqualStrings("V", row7.sources[1].name);
    try testing.expectEqualStrings("X", row7.sources[2].name);
    try testing.expectEqual(@as(usize, 2), row7.destinations.len);
    try testing.expectEqualStrings("SUM", row7.destinations[0].name);
    try testing.expectEqualStrings("CO", row7.destinations[1].name);
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
    try testing.expectEqualStrings("anon_0", net.definitions[0].contained[0].name);
}