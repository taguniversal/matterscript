const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;
const helpers = @import("helpers.zig");

// TAG-211: Example 12.18, bundling digits into numbers — parser
// diagnostic suite.
//
// rules.zig's own header comment says "No .invoke" is implemented yet,
// so even a clean parse anywhere in this file does NOT mean 4BITADD
// will run — buildRules would need a new case for .invoke before any
// runtime/.tb.vec test could pass. This suite is parser-only.
//
// Isolated in order:
//   1. Bundle group in a DEFINITION's own source-port declaration,
//      alongside a plain scalar source — the half of the pattern your
//      draft's own header already uses ([A0<>..A3<>] inside 4BITADD[...]).
//   1b. Bundle group as an argument at an INVOCATION call site (both a
//       top-level entry line, and a .invoke statement inside another
//       definition's resolution) — the other half: can a caller pass a
//       bundle compactly the way 4BITADD's own entry line implies with
//       bare $A/$B? Untested by step 1, and a different parser code
//       path (invocation-argument parsing vs. definition-header parsing).
//   2. Bundle group (of $-refs) in a definition's DESTINATION list,
//      alongside a plain scalar destination.
//   3. A bare .invoke-shaped statement chain in resolution — two known-
//      good scalar FULLADD invocations wired through a local place —
//      with no bundling at all.
//   4. The full original 4BITADD script, combining both, with a
//      verbatim copy of TAG-198's FULLADD supplied ahead of it.

// --- 1. Bundle group in a DEFINITION's own source-port declaration ---
test "TAG-211 step 1: bundle group in definition source list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\STEP1($SEL $A0 $A1 $A2 $A3)(OUT<>)
        \\STEP1[(SEL<> [A0<> A1<> A2<> A3<>])($OUT)
        \\  $SEL( ) : X[OUT<1>]
        \\            Y[OUT<0>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 1 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    // Always dump — makes the failure mode readable even if assertions
    // below short-circuit.
    helpers.dumpDef("step 1", net.definitions[0]);

    // --- Shape assertions ---
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];
    try testing.expectEqualStrings("STEP1", def.name);

    // Source list: exactly 2 top-level args — a place (SEL) and a bundle group.
    try testing.expectEqual(@as(usize, 2), def.sources.len);

    // Arg 0: scalar place, named "SEL".
    try testing.expectEqual(network.ArgKind.place, def.sources[0].kind);
    try testing.expectEqualStrings("SEL", def.sources[0].name);
    try testing.expect(def.sources[0].group == null);

    // Arg 1: group, kind = bundle, 4 member places A0..A3 in order.
    const g1 = def.sources[1];
    try testing.expectEqual(network.ArgKind.group, g1.kind);
    try testing.expect(g1.group != null);
    const bundle = g1.group.?;
    try testing.expectEqual(network.PlaceGroupKind.bundle, bundle.kind);
    try testing.expectEqual(@as(usize, 4), bundle.places.len);

    const expected_members = [_][]const u8{ "A0", "A1", "A2", "A3" };
    for (bundle.places, expected_members, 0..) |m, want, i| {
        testing.expectEqual(network.ArgKind.place, m.kind) catch |err| {
            std.debug.print(
                "member[{d}]: expected place, got {s}\n",
                .{ i, @tagName(m.kind) },
            );
            return err;
        };
        testing.expectEqualStrings(want, m.name) catch |err| {
            std.debug.print(
                "member[{d}]: expected name '{s}', got '{s}'\n",
                .{ i, want, m.name },
            );
            return err;
        };
    }
}
// --- 1b. Bundle group as an argument AT AN INVOCATION call site ---
// (a) a top-level entry line passing a bundle instead of flat scalars
// (b) a .invoke statement inside another definition doing the same
// This is the half your draft's asymmetry implies (compact $A/$B at the
// entry) but that step 1 never actually tests — bundling *inside* a
// call's argument list, not just inside a definition's own header.
test "TAG-211 step 1b: bundle group at an invocation call site" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\STEP1B([$A0 $A1 $A2 $A3])(OUT<>)
        \\
        \\STEP1B[([A0<> A1<> A2<> A3<>])($OUT)
        \\  :
        \\ A0[OUT<1>]
        \\]
        \\
        \\WRAP($X0 $X1 $X2 $X3)(RESULT<>)
        \\WRAP[(X0<> X1<> X2<> X3<>)($RESULT)
        \\  STEP1B([$X0 $X1 $X2 $X3])(RESULT<>)
        \\  :
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 1b FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    for (net.entries) |e| helpers.dumpEntry("step 1b entry", e);
    for (net.definitions) |def| helpers.dumpDef("step 1b", def);
}

// --- 2. Bundle group (of $-refs) in destinations, plain scalar dest ---
test "TAG-211 step 2: bundle group of $-refs in destination list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\STEP2($SEL)([$SUM0 $SUM1 $SUM2 $SUM3] $CO)
        \\STEP2[(SEL<>)([SUM0<> SUM1<> SUM2<> SUM3<>] CO<>)
        \\  $SEL( ) : X[CO<1>]
        \\            Y[CO<0>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 2 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    helpers.dumpDef("step 2", net.definitions[0]);
}


// --- 2. Case A: bare place in an invocation resolves through the
//        enclosing definition's source list, where the bundle is declared.
test "TAG-211 step 2: bare place in nested invocation gets bundle structure from enclosing scope" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // A wrapper whose sources declare A and B as 4-bundles and CI scalar.
    // Its body invokes 4BITADD with the bare names $A $B $CI — no brackets
    // on the invocation side, because the bundle was declared above.
     const src =
        \\WRAPPER([A0<> A1<> A2<> A3<>] [B0<> B1<> B2<> B3<>] CI<>)(RESULT<>)
        \\WRAPPER[([A0<> A1<> A2<> A3<>] [B0<> B1<> B2<> B3<>] CI<>)($RESULT)
        \\  4BITADD($A $B $CI)($RESULT)
        \\]
        \\4BITADD([A0<> A1<> A2<> A3<>] [B0<> B1<> B2<> B3<>] CI<>)([S0<> S1<> S2<> S3<>] CO<>)
        \\4BITADD[([A0<> A1<> A2<> A3<>] [B0<> B1<> B2<> B3<>] CI<>)([SUM0<> SUM1<> SUM2<> SUM3<>] CO<>)
        \\  $A $B $CI : X[K]  //nonsense since we're not testing the functionality, just the parse shape
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 2 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };

    // Dump both definitions so a failure shows the actual shape.
    for (net.definitions) |d| {
        helpers.dumpDef("step 2 def", d);
    }

    // Locate the WRAPPER definition.
    var wrapper: ?network.Definition = null;
    for (net.definitions) |d| {
        if (std.ascii.eqlIgnoreCase(d.name, "WRAPPER")) wrapper = d;
    }
    try testing.expect(wrapper != null);

    // --- Enclosing scope shape ---
    // WRAPPER sources: 3 top-level args — two 4-bundles and a scalar.
    try testing.expectEqual(@as(usize, 3), wrapper.?.sources.len);

    try testing.expectEqual(network.ArgKind.group, wrapper.?.sources[0].kind);
    try testing.expectEqual(network.PlaceGroupKind.bundle, wrapper.?.sources[0].group.?.kind);
    try testing.expectEqual(@as(usize, 4), wrapper.?.sources[0].group.?.places.len);

    try testing.expectEqual(network.ArgKind.group, wrapper.?.sources[1].kind);
    try testing.expectEqual(network.PlaceGroupKind.bundle, wrapper.?.sources[1].group.?.kind);
    try testing.expectEqual(@as(usize, 4), wrapper.?.sources[1].group.?.places.len);

    try testing.expectEqual(network.ArgKind.place, wrapper.?.sources[2].kind);
    try testing.expectEqualStrings("CI", wrapper.?.sources[2].name);

    // --- Nested invocation shape ---
    // The WRAPPER's resolution should contain a 4BITADD invoke.
    try testing.expect(wrapper.?.resolution.len >= 1);

    const invoke = wrapper.?.resolution[0].invoke;
    try testing.expect(std.ascii.eqlIgnoreCase(invoke.name, "4BITADD"));

    // The invocation's sources: 3 bare places. Crucially NOT groups —
    // the brackets are absent on the invocation side. This is exactly
    // the shape that trips the current arity check.
    try testing.expectEqual(@as(usize, 3), invoke.sources.len);

    const expected_names = [_][]const u8{ "A", "B", "CI" };
    for (invoke.sources, expected_names, 0..) |arg, want, i| {
        testing.expectEqual(network.ArgKind.place, arg.kind) catch |err| {
            std.debug.print(
                "invoke.sources[{d}]: expected bare place, got {s} (name='{s}' text='{s}')\n",
                .{ i, @tagName(arg.kind), arg.name, arg.text },
            );
            return err;
        };
        testing.expectEqualStrings(want, arg.name) catch |err| {
            std.debug.print(
                "invoke.sources[{d}]: expected name '{s}', got '{s}'\n",
                .{ i, want, arg.name },
            );
            return err;
        };
        // No group field should be attached — that's the whole point.
        try testing.expect(arg.group == null);
    }

    // --- The paired fact ---
    // The WRAPPER's scope *does* know A and B are bundles, because they're
    // declared in wrapper.sources. So the missing information the arity check
    // needs is available at emit time — it just isn't being looked up.
    //
    // Nothing to assert here beyond confirming both facts are in the AST
    // simultaneously: the invocation has bare names, and the enclosing
    // source list has the matching bundle declarations.
}   

// --- 3. Bare invoke-statement chain, no bundling at all ---
test "TAG-211 step 3: chained invoke statements, no bundling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADD($A,$B,$C)(< > CARRYOUT< >)
        \\FULLADD[(A< > B< > CI< >)($SUM$CO)
        \\$A$B$CI :
        \\K[SUM<K>] L[SUM<L>] M[CO<M>] N[CO<N>]
        \\S,U,W[K,M] S,U,X[L,M] S,V,W[L,M] S,V,X[K,N]
        \\T,U,W[L,M] T,U,X[K,N] T,V,W[K,N] T,V,X[L,N] 
        \\]
        \\
        \\CHAIN($X0 $X1 $X2)(SUM0<> SUM1<> COUT<>)
        \\CHAIN[(X0<> X1<> X2<>)($SUM0 $SUM1 $COUT)
        \\  FULLADD($X0 $X1 $X2)(SUM0<> C1<>)
        \\  FULLADD($X0 $X1 $C1)(SUM1<> COUT<>)
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 3 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    for (net.definitions) |def| helpers.dumpDef("step 3", def);
}

// --- 4. Full original 4BITADD, with a known-good FULLADD supplied ---
test "TAG-211 step 4: full 4BITADD with bundling and invocation combined" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FULLADD($A,$B,$C)(< > CARRYOUT< >)
        \\FULLADD[(A< > B< > CI< >)($SUM$CO)
        \\$A$B$CI :
        \\K[SUM<K>] L[SUM<L>] M[CO<M>] N[CO<N>]
        \\S,U,W[K,M] S,U,X[L,M] S,V,W[L,M] S,V,X[K,N]
        \\T,U,W[L,M] T,U,X[K,N] T,V,W[K,N] T,V,X[L,N] 
        \\]
        \\
        \\4BITADD($A $B $CARRYIN)(SUM<> CARRYOUT<>)
        \\4BITADD[([A0<> A1<> A2<> A3<>] [B0<> B1<> B2<> B3<>] CI<>)
        \\  ([$SUM0 $SUM1 $SUM2 $SUM3] $CO)
        \\
        \\  FULLADD($A0 $B0 $CI)(SUM0<> C1<>)
        \\  FULLADD($A1 $B1 $C1)(SUM1<> C2<>)
        \\  FULLADD($A2 $B2 $C2)(SUM2<> C3<>)
        \\  FULLADD($A3 $B3 $C3)(SUM3<> CO<>)
        \\  :
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 4 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    for (net.definitions) |def| helpers.dumpDef("step 4", def);
}

// --- 5. Bare single name standing for a bundle, both as an
//        invocation's destination AND, immediately after, as the same
//        bare name reused as a subsequent invocation's source. ---
//
// FOOBAR: bare $T in -> 3-wide bundle [A1 A2 A3] in its own header;
//         3-wide bundle [$K1 $K2 $K3] out of its own header -> bare
//         U<> at the call site.
// BAR:    bare $U in -> 3-wide bundle [T1 T2 T3] in its own header.
// PIPE:   feeds FOOBAR explicitly-bracketed (mechanism already proven
//         in step 1b), captures its output as bare U<>, then reuses
//         bare $U as BAR's bundle-shaped source — the untested part.
//
// If this fails, the error location should say whether it's the bare
// destination binding (FOOBAR(...)(U<>)) or the bare source reuse
// ($U into BAR) that the parser/binder doesn't handle.
test "TAG-211 step 5: bare name aliasing a bundle across two invocation hops" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\FOOBAR($T)(U<>)
        \\FOOBAR[([A1<> A2<> A3<>])([$K1 $K2 $K3])
        \\ :
        \\  A1[K1<$A1>]
        \\  A2[K2<$A2>]
        \\  A3[K3<$A3>]
        \\]
        \\
        \\BAR($U)(RESULT<>)
        \\BAR[([T1<> T2<> T3<>])($RESULT)
        \\ :
        \\  T1[RESULT<$T1>]
        \\]
        \\
        \\PIPE($X1 $X2 $X3)(FINAL<>)
        \\PIPE[(X1<> X2<> X3<>)($FINAL)
        \\  FOOBAR([$X1 $X2 $X3])(U<>)
        \\  BAR($U)(FINAL<>)
        \\ :
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 5 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    for (net.definitions) |def| helpers.dumpDef("step 5", def);
}


test "Example 12.9: two adjacent mutex source groups" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\OR[({A0<> A1<>}{B0<> B1<>})({$0 $1})
        \\  :
        \\  A0,B0[0]
        \\  A0,B1[1]
        \\  A1,B0[1]
        \\  A1,B1[1]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    helpers.dumpDef("Example 12.9", net.definitions[0]); // reuse the existing dump helper
}
