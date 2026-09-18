const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;

// TAG-177: Pure Value Expression Fan-Out Parsing Test Suite
const example_12_26_script =
    \\// Linear: TAG-177 Example 12.26 Pure Value Expression of Boolean Full Adder
    \\
    \\FULLADD($A,$B,$C)(<> CARRYOUT<>)
    \\FULLADD[(X<>Y<>CI<>)( $SUM $CARRY)
    \\  $X $Y $CI:
    \\///"fan-out input symbols"
    \\A[g,k,o] B[h,l,p] C[G,K,O] D[H,L,P] E[I,M,Q] F[J,N,R]
    \\// "define combinational resolution stages"
    \\GI[S] GJ[T] HI[S] HJ[S]
    \\KM[U] KN[U] LM[V] LN[U]
    \\OQ[W] OR[W] PQ[W] PR[X]
    \\SU[a,c,e] SV[b,d,f] TU[b,d,f] TV[b,d,f] //"fan out input to second half-adder"
    \\ga[i] gb[j] ha[i] hb[i]
    \\kc[m] kd[m] lc[n] ld[m]
    \\oe[q] of[q] pe[q] pf[r]
    \\im[s] in[t] jm[t] jn[t] //"sum"
    \\qW[u] qX[v] rW[v] rX[v] //"carry"
    \\s[SUM<s>] t[SUM<t>] u[CARRY<u>] v[CARRY<v>] //"output"
    \\]
;

fn findPureValueInDefinitions(defs: []const network.Definition, target_name: []const u8) ?[]const u8 {
    for (defs) |child_def| {
        if (std.mem.eql(u8, child_def.name, target_name)) {
            for (child_def.resolution) |stmt| {
                switch (stmt) {
                    .pure_value => |val| return val,
                    else => {},
                }
            }
        }
    }
    return null;
}

test "TAG-177: Example 12.26 - Full Adder Pure Value Expression AST Parsing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const net = try parser.parse(allocator, example_12_26_script);

    try testing.expect(net.definitions.len > 0);
    const def = net.definitions[0];
    try testing.expectEqualStrings("FULLADD", def.name);

    // Fan-out definitions are in def.contained after the ':' separator
    try testing.expect(def.contained.len > 0);

    // Multi-target fan-out list: A[g,k,o] -> name="A", resolution=[.pure_value="g,k,o"]
    const a_val = findPureValueInDefinitions(def.contained, "A") orelse return error.StatementNotFound;
    try testing.expectEqualStrings("g,k,o", a_val);

    const su_val = findPureValueInDefinitions(def.contained, "SU") orelse return error.StatementNotFound;
    try testing.expectEqualStrings("a,c,e", su_val);

    // Single-target degenerated wire case: GI[S] -> name="GI", resolution=[.pure_value="S"]
    const gi_val = findPureValueInDefinitions(def.contained, "GI") orelse return error.StatementNotFound;
    try testing.expectEqualStrings("S", gi_val);
}

test "TAG-177: parseResolution edge cases and comma lists" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const snippet =
        \\TEST_NET[(X)(Y) $X:
        \\  WIRE_SINGLE[A]
        \\  WIRE_FANOUT[a, b, c]
        \\  WIRE_COMPACT[x,y,z]
        \\]
    ;

    const net = try parser.parse(allocator, snippet);
    const contained = net.definitions[0].contained;

    try testing.expectEqualStrings("A", findPureValueInDefinitions(contained, "WIRE_SINGLE").?);
    try testing.expectEqualStrings("a, b, c", findPureValueInDefinitions(contained, "WIRE_FANOUT").?);
    try testing.expectEqualStrings("x,y,z", findPureValueInDefinitions(contained, "WIRE_COMPACT").?);
}

test "TAG-177: Inspect AST Output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const net = try parser.parse(allocator, example_12_26_script);

    try testing.expect(net.definitions.len > 0);
    const def = net.definitions[0];

    std.debug.print("\n--- DEF RESOLUTION STATEMENTS ({d} items) ---\n", .{def.resolution.len});
    for (def.resolution, 0..) |stmt, i| {
        switch (stmt) {
            .pure_value => |val| std.debug.print("[{d}] .pure_value = \"{s}\"\n", .{ i, val }),
            .fill => |f| std.debug.print("[{d}] .fill = {}\n", .{ i, f }),
            .invoke => |inv| std.debug.print("[{d}] .invoke = {}\n", .{ i, inv }),
            .directive => |dir| std.debug.print("[{d}] .directive = {}\n", .{ i, dir }),
        }
    }
    std.debug.print("--------------------------------------------\n", .{});
}