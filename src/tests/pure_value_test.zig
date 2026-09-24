const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;
const runtime = matterscript.runtime;

// Example 12.26 with the carry-stage symbol X renamed to Z
// (X collides with boundary port X).
const example_12_26_script =
    \\FULLADD($A,$B,$C)(<> CARRYOUT<>)
    \\FULLADD[(X<>Y<>CI<>)( $SUM $CARRY)
    \\  
    \\  $X $Y $CI:
    \\A[g,k,o] B[h,l,p] C[G,K,O] D[H,L,P] E[I,M,Q] F[J,N,R]
    \\G,I[S] G,J[T] H,I[S] H,J[S]
    \\K,M[U] K,N[U] L,M[V] L,N[U]
    \\O,Q[W] O,R[W] P,Q[W] P,R[Z]
    \\S,U[a,c,e] S,V[b,d,f] T,U[b,d,f] T,V[b,d,f]
    \\g,a[i] g,b[j] h,a[i] h,b[i]
    \\k,c[m] k,d[m] l,c[n] l,d[m]
    \\o,e[q] o,f[q] p,e[q] p,f[r]
    \\i,m[s] i,n[t] j,m[t] j,n[t]
    \\q,W[u] q,Z[v] r,W[v] r,Z[v]
    \\s[SUM<s>] t[SUM<t>] u[CARRY<u>] v[CARRY<v>]
    \\]
;

// Adapt to whatever parse() returns; I don't know its shape.
fn fulladdDef(net: anytype) network.Definition {
    return net.definitions[0];
}

test "TAG-177: Example 12.26 full adder, all 8 wavefronts via Testbench" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const net = try parser.parse(allocator, example_12_26_script);
    const def = fulladdDef(net);

    // Row i encodes x = i>>2, y = (i>>1)&1, ci = i&1.
    // Symbols: X -> A/B, Y -> C/D, CI -> E/F  (0/1 respectively)
    const x_toks = [_][]const u8{ "A", "A", "A", "A", "B", "B", "B", "B" };
    const y_toks = [_][]const u8{ "C", "C", "D", "D", "C", "C", "D", "D" };
    const ci_toks = [_][]const u8{ "E", "F", "E", "F", "E", "F", "E", "F" };

    var streams = [_]runtime.testbench.PortStream{
        .{ .port = "X", .tokens = &x_toks },
        .{ .port = "Y", .tokens = &y_toks },
        .{ .port = "CI", .tokens = &ci_toks },
    };

    var tb = try runtime.testbench.Testbench.init(allocator, def, &streams);
    const presentations = try tb.run();

    // A wavefront that never completes ends the run early, so this
    // catches stuck rows before the value checks do.
    try testing.expectEqual(@as(usize, 8), presentations.len);

    for (presentations, 0..) |p, i| {
        const x: u2 = @intCast(i >> 2);
        const y: u2 = @intCast((i >> 1) & 1);
        const ci: u2 = @intCast(i & 1);
        const total = x + y + ci;

        // Assumed: SUM s/t = 0/1, CARRY u/v = 0/1
        const want_sum: []const u8 = if (total & 1 == 0) "s" else "t";
        const want_carry: []const u8 = if (total >> 1 == 0) "u" else "v";

        const got_sum = p.outputs.get("SUM") orelse {
            std.debug.print("row {d} ({d}+{d}+{d}): SUM never valid\n", .{ i, x, y, ci });
            return error.MissingOutput;
        };
        const got_carry = p.outputs.get("CARRY") orelse {
            std.debug.print("row {d} ({d}+{d}+{d}): CARRY never valid\n", .{ i, x, y, ci });
            return error.MissingOutput;
        };

        testing.expectEqualStrings(want_sum, got_sum) catch |e| {
            std.debug.print("row {d} ({d}+{d}+{d}): SUM mismatch\n", .{ i, x, y, ci });
            return e;
        };
        testing.expectEqualStrings(want_carry, got_carry) catch |e| {
            std.debug.print("row {d} ({d}+{d}+{d}): CARRY mismatch\n", .{ i, x, y, ci });
            return e;
        };
    }
}