const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;

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

fn printIndent(depth: usize) void {
    var i: usize = 0;
    while (i < depth) : (i += 1) std.debug.print("  ", .{});
}

fn dumpArg(depth: usize, arg: network.Arg) void {
    printIndent(depth);
    std.debug.print("kind={s} name='{s}' text='{s}'\n", .{ @tagName(arg.kind), arg.name, arg.text });
    if (arg.group) |g| {
        printIndent(depth + 1);
        std.debug.print("group.kind={s}\n", .{@tagName(g.kind)});
        for (g.places) |p| dumpArg(depth + 2, p);
    }
}

fn dumpArgs(depth: usize, label: []const u8, args: []const network.Arg) void {
    printIndent(depth);
    std.debug.print("{s} ({d}):\n", .{ label, args.len });
    for (args) |arg| dumpArg(depth + 1, arg);
}

fn dumpStatement(depth: usize, i: usize, stmt: network.Statement) void {
    printIndent(depth);
    std.debug.print("resolution[{d}]: {s}\n", .{ i, @tagName(stmt) });
    switch (stmt) {
        .fill => |f| {
            printIndent(depth + 1);
            std.debug.print("dest_name='{s}' expr='{s}'\n", .{ f.dest_name, f.expr });
        },
        .invoke => |inv| {
            printIndent(depth + 1);
            std.debug.print("invoke name='{s}' label={?s}\n", .{ inv.name, inv.label });
            dumpArgs(depth + 1, "invoke.sources", inv.sources);
            dumpArgs(depth + 1, "invoke.destinations", inv.destinations);
        },
        .pure_value => |v| {
            printIndent(depth + 1);
            std.debug.print("pure_value='{s}'\n", .{v});
        },
        .directive => |d| {
            printIndent(depth + 1);
            std.debug.print("directive name='{s}' args='{s}'\n", .{ d.name, d.args });
        },
    }
}

fn dumpDef(label: []const u8, def: network.Definition) void {
    std.debug.print("--- {s}: def '{s}' ---\n", .{ label, def.name });
    dumpArgs(0, "sources", def.sources);
    dumpArgs(0, "destinations", def.destinations);
    for (def.resolution, 0..) |stmt, i| dumpStatement(0, i, stmt);
    for (def.contained) |c| std.debug.print("contained: '{s}'\n", .{c.name});
    std.debug.print("\n", .{});
}

fn dumpEntry(label: []const u8, e: network.EntryInvocation) void {
    std.debug.print("--- {s}: entry '{s}' ---\n", .{ label, e.name });
    dumpArgs(0, "sources", e.sources);
    dumpArgs(0, "destinations", e.destinations);
    std.debug.print("\n", .{});
}

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
    dumpDef("step 1", net.definitions[0]);
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
    for (net.entries) |e| dumpEntry("step 1b entry", e);
    for (net.definitions) |def| dumpDef("step 1b", def);
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
    dumpDef("step 2", net.definitions[0]);
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
    for (net.definitions) |def| dumpDef("step 3", def);
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
    for (net.definitions) |def| dumpDef("step 4", def);
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
    for (net.definitions) |def| dumpDef("step 5", def);
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
    dumpDef("Example 12.9", net.definitions[0]); // reuse the existing dump helper
}