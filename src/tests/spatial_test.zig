const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const spatial = matterscript.spatial;

test "SpatialGraph initialization and deinitialization" {
    var graph = spatial.SpatialGraph.init(testing.allocator, .spatial3d);
    defer graph.deinit();

    try testing.expectEqual(spatial.SpatialDimension.spatial3d, graph.dim);
    try testing.expectEqual(@as(usize, 0), graph.points.items.len);
    try testing.expectEqual(@as(usize, 0), graph.edges.items.len);
}

test "addPoint dimension enforcement" {
    // Test 3D context allows Z coordinates
    {
        var graph3d = spatial.SpatialGraph.init(testing.allocator, .spatial3d);
        defer graph3d.deinit();

        const p0 = try spatial.addPoint(&graph3d, .{ .x = 1.0, .y = 2.0, .z = 3.0 });
        try testing.expectEqual(spatial.PointId, @TypeOf(p0));
        try testing.expectEqual(@as(u32, 0), @intFromEnum(p0));
    }

    // Test 2D context rejects non-zero Z coordinates
    {
        var graph2d = spatial.SpatialGraph.init(testing.allocator, .spatial2d);
        defer graph2d.deinit();

        _ = try spatial.addPoint(&graph2d, .{ .x = 1.0, .y = 2.0, .z = 0.0 });
        try testing.expectError(
            error.InvalidDimensionFor2DContext,
            spatial.addPoint(&graph2d, .{ .x = 1.0, .y = 2.0, .z = 0.5 }),
        );
    }
}

test "edge length and latency calculation" {
    var graph = spatial.SpatialGraph.init(testing.allocator, .spatial3d);
    defer graph.deinit();

    const p0 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 0.0, .z = 0.0 });
    const p1 = try spatial.addPoint(&graph, .{ .x = 3.0, .y = 4.0, .z = 0.0 });

    const e0 = try spatial.addEdge(&graph, p0, p1);
    const edge = graph.edges.items[@intFromEnum(e0)];

    // Euclidean distance: sqrt(3^2 + 4^2) = 5.0
    const len = edge.length(&graph);
    try testing.expectApproxEqAbs(@as(f64, 5.0), len, 1e-6);

    // Propagation latency at velocity = 2.0 units/sec (5.0 / 2.0 = 2.5)
    const latency = spatial.calculateChannelLatency(&graph, e0, 2.0);
    try testing.expectApproxEqAbs(@as(f64, 2.5), latency, 1e-6);
}

test "validateLoopClosure" {
    var graph = spatial.SpatialGraph.init(testing.allocator, .spatial2d);
    defer graph.deinit();

    const p0 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 0.0, .z = 0.0 });
    const p1 = try spatial.addPoint(&graph, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const p2 = try spatial.addPoint(&graph, .{ .x = 1.0, .y = 1.0, .z = 0.0 });
    const p3 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 1.0, .z = 0.0 });

    const e0 = try spatial.addEdge(&graph, p0, p1);
    const e1 = try spatial.addEdge(&graph, p1, p2);
    const e2 = try spatial.addEdge(&graph, p2, p3);
    const e3 = try spatial.addEdge(&graph, p3, p0);

    // Valid closed 4-edge loop
    const valid_edges = [_]spatial.EdgeId{ e0, e1, e2, e3 };
    const loop_id = try spatial.addLoop(&graph, &valid_edges);
    try testing.expectEqual(@as(u32, 0), @intFromEnum(loop_id));

    // Test degenerate loop (< 3 edges)
    const short_edges = [_]spatial.EdgeId{ e0, e1 };
    try testing.expectError(error.DegenerateLoop, spatial.addLoop(&graph, &short_edges));

    // Test unclosed loop (doesn't return to start point)
    const unclosed_edges = [_]spatial.EdgeId{ e0, e1, e2 };
    try testing.expectError(error.UnclosedLoop, spatial.addLoop(&graph, &unclosed_edges));
}

test "isWithinDistance relationship operator" {
    var graph = spatial.SpatialGraph.init(testing.allocator, .spatial3d);
    defer graph.deinit();

    const p0 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 0.0, .z = 0.0 });
    const p1 = try spatial.addPoint(&graph, .{ .x = 1.0, .y = 1.0, .z = 0.0 });

    // Distance is ~1.414
    try testing.expect(spatial.isWithinDistance(&graph, p0, p1, 1.5));
    try testing.expect(!spatial.isWithinDistance(&graph, p0, p1, 1.0));
}
test "triangulation and binary PLY export" {
    var graph = spatial.SpatialGraph.init(testing.allocator, .spatial2d);
    defer graph.deinit();

    // Create a 2D quad (2 triangles after triangulation)
    const p0 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 0.0, .z = 0.0 });
    const p1 = try spatial.addPoint(&graph, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const p2 = try spatial.addPoint(&graph, .{ .x = 1.0, .y = 1.0, .z = 0.0 });
    const p3 = try spatial.addPoint(&graph, .{ .x = 0.0, .y = 1.0, .z = 0.0 });

    const e0 = try spatial.addEdge(&graph, p0, p1);
    const e1 = try spatial.addEdge(&graph, p1, p2);
    const e2 = try spatial.addEdge(&graph, p2, p3);
    const e3 = try spatial.addEdge(&graph, p3, p0);

    const edges = [_]spatial.EdgeId{ e0, e1, e2, e3 };
    const loop_id = try spatial.addLoop(&graph, &edges);
    _ = try spatial.addFace(&graph, loop_id);

    // Triangulate
    var mesh = try spatial.triangulate(&graph, testing.allocator);
    defer mesh.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), mesh.vertices.items.len);
    try testing.expectEqual(@as(usize, 2), mesh.indices.items.len);

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try spatial.exportPly(&mesh, &aw.writer);

    const output = aw.written();
    try testing.expect(std.mem.startsWith(u8, output, "ply\nformat binary_little_endian 1.0\n"));
    try testing.expect(std.mem.indexOf(u8, output, "element vertex 4") != null);
    try testing.expect(std.mem.indexOf(u8, output, "element face 2") != null);
}