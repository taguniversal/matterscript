// src/tests/golden_mesh_test.zig
//
// Golden-file regression test for the geometry export pipeline:
// parse -> resolveSpatialBindings -> triangulate -> exportPly, compared
// byte-for-byte against a .ply verified once by eye in MeshLab. This is
// deliberately narrow — it proves "did the output change since the last
// verified snapshot," not "is the output correct" (that's what the
// import/round-trip test in spatial_test.zig is for; see the discussion
// that led to both existing side by side).
//
// The IPL source below is a duplicate of examples/docs/TAG-196/cube.ms.ipl,
// not a read of that file — matching how every other parser/export test
// in this suite embeds its source inline. If you edit the doc example,
// update this copy too.

const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const ipl_parser = matterscript.ipl_parser;
const spatial_domain = matterscript.spatial_domain;
const spatial = matterscript.spatial;

const cube_src =
    \\cube[()()
    \\    @domain(spatial3d)
    \\    p0< point(0.0, 0.0, 0.0) >
    \\    p1< point(1.0, 0.0, 0.0) >
    \\    p2< point(1.0, 1.0, 0.0) >
    \\    p3< point(0.0, 1.0, 0.0) >
    \\    p4< point(0.0, 0.0, 1.0) >
    \\    p5< point(1.0, 0.0, 1.0) >
    \\    p6< point(1.0, 1.0, 1.0) >
    \\    p7< point(0.0, 1.0, 1.0) >
    \\    e_b0<edge($p0, $p1)>
    \\    e_b1<edge($p1, $p2)>
    \\    e_b2<edge($p2, $p3)>
    \\    e_b3<edge($p3, $p0)>
    \\    l_bottom<loop($e_b0, $e_b1, $e_b2, $e_b3)>
    \\    f_bottom<face($l_bottom)>
    \\    e_t0<edge($p4, $p5)>
    \\    e_t1<edge($p5, $p6)>
    \\    e_t2<edge($p6, $p7)>
    \\    e_t3<edge($p7, $p4)>
    \\    l_top<loop($e_t0, $e_t1, $e_t2, $e_t3)>
    \\    f_top<face($l_top)>
    \\    e_f0<edge($p0, $p1)>
    \\    e_f1<edge($p1, $p5)>
    \\    e_f2<edge($p5, $p4)>
    \\    e_f3<edge($p4, $p0)>
    \\    l_front<loop($e_f0, $e_f1, $e_f2, $e_f3)>
    \\    f_front<face($l_front)>
    \\    e_r0<edge($p1, $p2)>
    \\    e_r1<edge($p2, $p6)>
    \\    e_r2<edge($p6, $p5)>
    \\    e_r3<edge($p5, $p1)>
    \\    l_right<loop($e_r0, $e_r1, $e_r2, $e_r3)>
    \\    f_right<face($l_right)>
    \\    e_k0<edge($p2, $p3)>
    \\    e_k1<edge($p3, $p7)>
    \\    e_k2<edge($p7, $p6)>
    \\    e_k3<edge($p6, $p2)>
    \\    l_back<loop($e_k0, $e_k1, $e_k2, $e_k3)>
    \\    f_back<face($l_back)>
    \\    e_l0<edge($p3, $p0)>
    \\    e_l1<edge($p0, $p4)>
    \\    e_l2<edge($p4, $p7)>
    \\    e_l3<edge($p7, $p3)>
    \\    l_left<loop($e_l0, $e_l1, $e_l2, $e_l3)>
    \\    f_left<face($l_left)>
    \\    :
    \\]
;

test "cube.ms.ipl matches golden PLY output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const net = try ipl_parser.parse(allocator, cube_src);

    var def: ?matterscript.network.Definition = null;
    for (net.definitions) |d| {
        if (std.mem.eql(u8, d.name, "cube")) def = d;
    }
    const cube_def = def orelse return error.CubeDefinitionNotFound;

    var ctx = try spatial_domain.resolveSpatialBindings(allocator, cube_def);
    defer ctx.deinit(allocator);

    var mesh = try spatial.triangulate(&ctx.graph, allocator);
    defer mesh.deinit(allocator);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try spatial.exportPly(&mesh, &aw.writer);
    const actual = aw.written();

    // --- UNVERIFIED against this Zig snapshot — see note below ---
    const golden = try std.Io.Dir.cwd().readFileAlloc(
        testing.io,
        "src/tests/golden/cube.ply",
        allocator,
        @enumFromInt(16 * 1024 * 1024),
    );
    // --- end unverified section ---

    try testing.expect(std.mem.eql(u8, golden, actual));
}