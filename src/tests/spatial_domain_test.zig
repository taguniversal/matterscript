const std = @import("std");
const matterscript = @import("matterscript");
const network = matterscript.network;
const spatial_domain = matterscript.spatial_domain;

fn constExpr(arena: std.mem.Allocator, text: []const u8) !*network.Expr {
    const e = try arena.create(network.Expr);
    e.* = .{ .kind = .constant, .name = text };
    return e;
}

fn varExpr(arena: std.mem.Allocator, name: []const u8) !*network.Expr {
    const e = try arena.create(network.Expr);
    e.* = .{ .kind = .variable, .name = name };
    return e;
}

fn callExpr(arena: std.mem.Allocator, func: []const u8, args: []const *network.Expr) !*network.Expr {
    const e = try arena.create(network.Expr);
    e.* = .{ .kind = .call, .func = func, .args = args };
    return e;
}

fn pointCall(arena: std.mem.Allocator, x: []const u8, y: []const u8) !*network.Expr {
    const args = try arena.alloc(*network.Expr, 2);
    args[0] = try constExpr(arena, x);
    args[1] = try constExpr(arena, y);
    return callExpr(arena, "point", args);
}

fn edgeCall(arena: std.mem.Allocator, from: []const u8, to: []const u8) !*network.Expr {
    const args = try arena.alloc(*network.Expr, 2);
    args[0] = try varExpr(arena, from);
    args[1] = try varExpr(arena, to);
    return callExpr(arena, "edge", args);
}

fn refListCall(arena: std.mem.Allocator, func: []const u8, names: []const []const u8) !*network.Expr {
    const args = try arena.alloc(*network.Expr, names.len);
    for (names, 0..) |name, i| args[i] = try varExpr(arena, name);
    return callExpr(arena, func, args);
}

test "spatial domain binds points once and resolves edges by $-reference" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const p0_expr = try pointCall(arena, "0.0", "0.0");
    const p1_expr = try pointCall(arena, "1.0", "0.0");
    const e0_expr = try edgeCall(arena, "p0", "p1");

    const resolution = [_]network.Statement{
        .{ .fill = .{ .dest_name = "p0", .expr = "point(0.0,0.0)", .parsed_expr = p0_expr } },
        .{ .fill = .{ .dest_name = "p1", .expr = "point(1.0,0.0)", .parsed_expr = p1_expr } },
        .{ .fill = .{ .dest_name = "e0", .expr = "edge($p0,$p1)", .parsed_expr = e0_expr } },
    };

    const def = network.Definition{
        .name = "Shape",
        .sources = &.{},
        .destinations = &.{},
        .domain_spec = .{ .kind = .spatial2d },
        .resolution = &resolution,
        .constants = &.{},
    };

    var ctx = try spatial_domain.resolveSpatialBindings(allocator, def);
    defer ctx.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), ctx.graph.points.items.len);
    try std.testing.expectEqual(@as(usize, 1), ctx.graph.edges.items.len);

    const e0 = ctx.bindings.get("e0").?.edge;
    const edge = ctx.graph.edges.items[@intFromEnum(e0)];
    try std.testing.expectEqual(@as(usize, 0), @intFromEnum(edge.start));
    try std.testing.expectEqual(@as(usize, 1), @intFromEnum(edge.end));
}

test "spatial domain rejects rebinding an existing name" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const first = try pointCall(arena, "0.0", "0.0");
    const second = try pointCall(arena, "9.0", "9.0");

    const resolution = [_]network.Statement{
        .{ .fill = .{ .dest_name = "p0", .expr = "point(0.0,0.0)", .parsed_expr = first } },
        .{ .fill = .{ .dest_name = "p0", .expr = "point(9.0,9.0)", .parsed_expr = second } },
    };

    const def = network.Definition{
        .name = "Shape2D",
        .sources = &.{},
        .destinations = &.{},
        .domain_spec = .{ .kind = .spatial2d },
        .resolution = &resolution,
        .constants = &.{},
    };

    const result = spatial_domain.resolveSpatialBindings(allocator, def);
    try std.testing.expectError(error.DuplicateGeometryBinding, result);
}

test "spatial domain builds a face from a closed loop of $-referenced edges" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const coords = [4][2][]const u8{
        .{ "0.0", "0.0" },
        .{ "1.0", "0.0" },
        .{ "1.0", "1.0" },
        .{ "0.0", "1.0" },
    };
    var point_exprs: [4]*network.Expr = undefined;
    for (&point_exprs, 0..) |*pe, i| {
        pe.* = try pointCall(arena, coords[i][0], coords[i][1]);
    }

    const edge_names = [4][2][]const u8{
        .{ "p0", "p1" }, .{ "p1", "p2" }, .{ "p2", "p3" }, .{ "p3", "p0" },
    };
    var edge_exprs: [4]*network.Expr = undefined;
    for (&edge_exprs, 0..) |*ee, i| {
        ee.* = try edgeCall(arena, edge_names[i][0], edge_names[i][1]);
    }

    const loop_expr = try refListCall(arena, "loop", &.{ "e0", "e1", "e2", "e3" });
    const face_expr = try refListCall(arena, "face", &.{"l0"});

    const resolution = [_]network.Statement{
        .{ .fill = .{ .dest_name = "p0", .expr = "point(0.0,0.0)", .parsed_expr = point_exprs[0] } },
        .{ .fill = .{ .dest_name = "p1", .expr = "point(1.0,0.0)", .parsed_expr = point_exprs[1] } },
        .{ .fill = .{ .dest_name = "p2", .expr = "point(1.0,1.0)", .parsed_expr = point_exprs[2] } },
        .{ .fill = .{ .dest_name = "p3", .expr = "point(0.0,1.0)", .parsed_expr = point_exprs[3] } },
        .{ .fill = .{ .dest_name = "e0", .expr = "edge($p0,$p1)", .parsed_expr = edge_exprs[0] } },
        .{ .fill = .{ .dest_name = "e1", .expr = "edge($p1,$p2)", .parsed_expr = edge_exprs[1] } },
        .{ .fill = .{ .dest_name = "e2", .expr = "edge($p2,$p3)", .parsed_expr = edge_exprs[2] } },
        .{ .fill = .{ .dest_name = "e3", .expr = "edge($p3,$p0)", .parsed_expr = edge_exprs[3] } },
        .{ .fill = .{ .dest_name = "l0", .expr = "loop($e0,$e1,$e2,$e3)", .parsed_expr = loop_expr } },
        .{ .fill = .{ .dest_name = "f0", .expr = "face($l0)", .parsed_expr = face_expr } },
    };

    const def = network.Definition{
        .name = "Square",
        .sources = &.{},
        .destinations = &.{},
        .domain_spec = .{ .kind = .spatial2d },
        .resolution = &resolution,
        .constants = &.{},
    };

    var ctx = try spatial_domain.resolveSpatialBindings(allocator, def);
    defer ctx.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), ctx.graph.points.items.len);
    try std.testing.expectEqual(@as(usize, 4), ctx.graph.edges.items.len);
    try std.testing.expectEqual(@as(usize, 1), ctx.graph.loops.items.len);
    try std.testing.expectEqual(@as(usize, 1), ctx.graph.faces.items.len);

    const f0 = ctx.bindings.get("f0").?.face;
    const face = ctx.graph.faces.items[@intFromEnum(f0)];
    try std.testing.expectEqual(@as(usize, 0), @intFromEnum(face.outer_loop));
}

test "spatial domain rejects an unclosed loop" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const coords = [3][2][]const u8{ .{ "0.0", "0.0" }, .{ "1.0", "0.0" }, .{ "1.0", "1.0" } };
    var point_exprs: [3]*network.Expr = undefined;
    for (&point_exprs, 0..) |*pe, i| {
        pe.* = try pointCall(arena, coords[i][0], coords[i][1]);
    }

    // Only 2 edges (p0->p1, p1->p2) — never closes back to p0.
    const edge_names = [2][2][]const u8{ .{ "p0", "p1" }, .{ "p1", "p2" } };
    var edge_exprs: [2]*network.Expr = undefined;
    for (&edge_exprs, 0..) |*ee, i| {
        ee.* = try edgeCall(arena, edge_names[i][0], edge_names[i][1]);
    }

    const loop_expr = try refListCall(arena, "loop", &.{ "e0", "e1" });

    const resolution = [_]network.Statement{
        .{ .fill = .{ .dest_name = "p0", .expr = "point(0.0,0.0)", .parsed_expr = point_exprs[0] } },
        .{ .fill = .{ .dest_name = "p1", .expr = "point(1.0,0.0)", .parsed_expr = point_exprs[1] } },
        .{ .fill = .{ .dest_name = "p2", .expr = "point(1.0,1.0)", .parsed_expr = point_exprs[2] } },
        .{ .fill = .{ .dest_name = "e0", .expr = "edge($p0,$p1)", .parsed_expr = edge_exprs[0] } },
        .{ .fill = .{ .dest_name = "e1", .expr = "edge($p1,$p2)", .parsed_expr = edge_exprs[1] } },
        .{ .fill = .{ .dest_name = "l0", .expr = "loop($e0,$e1)", .parsed_expr = loop_expr } },
    };

    const def = network.Definition{
        .name = "OpenShape",
        .sources = &.{},
        .destinations = &.{},
        .domain_spec = .{ .kind = .spatial2d },
        .resolution = &resolution,
        .constants = &.{},
    };

    const result = spatial_domain.resolveSpatialBindings(allocator, def);
    try std.testing.expectError(error.DegenerateLoop, result);
}