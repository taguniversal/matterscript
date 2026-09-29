const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const core = matterscript.core;
const network = matterscript.network;
const statements = matterscript.statements;
const tb_vectors = matterscript.runtime.tb_vectors;

test "parse: full adder vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\// full adder
        \\@dut(FULLADD)
        \\@encoding(X: 0=A, 1=B)
        \\@encoding(SUM: 0=s, 1=t)
        \\@vectors(X,Y : SUM)
        \\0,C : 0
        \\1,C : -
        \\1,D : !stall
    ;
    var diag: tb_vectors.Diag = .{};
    const v = try tb_vectors.parse(a, src, &diag);
    try std.testing.expectEqualStrings("FULLADD", v.dut.?);
    try std.testing.expectEqual(@as(usize, 2), v.in_cols.len);
    try std.testing.expectEqual(@as(usize, 3), v.rows.len);
    try std.testing.expect(v.rows[2].stall);
}

test "parse: row before @vectors is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var diag: tb_vectors.Diag = .{};
    try std.testing.expectError(error.MalformedTestbench, tb_vectors.parse(arena.allocator(), "0,0 : 1\n", &diag));
    try std.testing.expectEqual(@as(usize, 1), diag.line);
}