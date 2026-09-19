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

test "TAG-177: Example 12.26 - try testing.expectError(error.TransformRuleSymbolCollidesWithBoundaryPort, result);" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const net = parser.parse(allocator, example_12_26_script);
    try testing.expectError(error.TransformRuleSymbolCollidesWithBoundaryPort, net);
}
