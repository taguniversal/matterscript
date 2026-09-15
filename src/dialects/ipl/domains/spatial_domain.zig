// Resolves @domain(spatial2d|spatial3d)-scoped fill statements whose
// expression is a call to a registered geometry function (point, edge,
// loop, face) into a parallel SpatialGraph, keeping IPL's own AST
// completely untouched.
//
// Binding semantics: a name (a fill's dest_name) may be bound to a
// geometry handle exactly once. Later occurrences of $name inside another
// geometry call's arguments resolve to that same handle — they route
// through it, they never redefine it. A second attempt to bind the same
// name is a DuplicateGeometryBinding error, not a silent overwrite.
//
// Every geometric element — point, edge, loop, face — is bound and
// referenced the same way: `name<func(...)>` to define, `$name` to refer
// to an already-bound element elsewhere. There is no inline/nested form;
// loop($e1, $e2, ...) and face($l0) take $-references to already-bound
// edges/loops, not nested anonymous calls, so every element stays
// individually addressable and no parser changes were needed to get here.
//
// Ordering: this is a single top-to-bottom pass over def.resolution in
// source order, so a name must be bound before it's referenced by $name
// in a later statement. Forward references aren't supported (yet) — this
// matches how you'd naturally write points-then-edges-then-loops anyway.

const std = @import("std");
const network = @import("../network.zig");
const spatial = @import("../../geo/spatial.zig");

pub const GeometryHandle = union(enum) {
    point: spatial.PointId,
    edge: spatial.EdgeId,
    loop: spatial.LoopId,
    face: spatial.FaceId,
};

pub const GeometryContext = struct {
    graph: spatial.SpatialGraph,
    bindings: std.StringHashMapUnmanaged(GeometryHandle) = .empty,

    pub fn deinit(self: *GeometryContext, allocator: std.mem.Allocator) void {
        self.graph.deinit();
        self.bindings.deinit(allocator);
    }
};

const DomainFn = *const fn (
    ctx: *GeometryContext,
    allocator: std.mem.Allocator,
    args: []const *network.Expr,
) anyerror!GeometryHandle;

const registry = std.StaticStringMap(DomainFn).initComptime(.{
    .{ "point", handlePoint },
    .{ "edge", handleEdge },
    .{ "loop", handleLoop },
    .{ "face", handleFace },
});

/// Only call this once `def.domain_spec` is confirmed to be a spatial2d
/// or spatial3d kind — spatial1d has no geometry-function registry (it's
/// still purely the existing CA-generate-block domain) and returns
/// error.UnsupportedSpatialDomain.
pub fn resolveSpatialBindings(
    allocator: std.mem.Allocator,
    def: network.Definition,
) !GeometryContext {
    const kind = def.domain_spec orelse return error.MissingDomainSpec;
    const dim: spatial.SpatialDimension = switch (kind.kind) {
        .spatial2d => .spatial2d,
        .spatial3d => .spatial3d,
        .spatial1d => return error.UnsupportedSpatialDomain,
    };

    var ctx = GeometryContext{ .graph = spatial.SpatialGraph.init(allocator, dim) };
    errdefer ctx.deinit(allocator);

    for (def.resolution) |stmt| {
        if (stmt != .fill) continue;
        const f = stmt.fill;
        const call = f.parsed_expr orelse continue;
        if (call.kind != .call) continue;

        const handler = registry.get(call.func) orelse continue; // not a geometry call — leave for normal fill handling

        if (ctx.bindings.contains(f.dest_name)) {
            return error.DuplicateGeometryBinding;
        }

        const handle = try handler(&ctx, allocator, call.args);
        try ctx.bindings.put(allocator, f.dest_name, handle);
    }

    return ctx;
}

fn resolveCoord(arg: *const network.Expr) !f64 {
    // Numeric literals inside a call's args arrive as .constant nodes
    // holding the raw text (e.g. "0.0"), not .integer — that's a quirk
    // of parseILCallArgument, not something to work around elsewhere.
    if (arg.kind != .constant) return error.InvalidGeometryArgument;
    return std.fmt.parseFloat(f64, arg.name);
}
fn resolvePointHandle(ctx: *const GeometryContext, arg: *const network.Expr) !spatial.PointId {
    if (arg.kind != .variable) return error.InvalidGeometryArgument;
    const handle = ctx.bindings.get(arg.name) orelse return error.UndefinedGeometryReference;
    return switch (handle) {
        .point => |id| id,
        else => error.InvalidGeometryArgument,
    };
}

fn resolveEdgeHandle(ctx: *const GeometryContext, arg: *const network.Expr) !spatial.EdgeId {
    if (arg.kind != .variable) return error.InvalidGeometryArgument;
    const handle = ctx.bindings.get(arg.name) orelse return error.UndefinedGeometryReference;
    return switch (handle) {
        .edge => |id| id,
        else => error.InvalidGeometryArgument,
    };
}

fn resolveLoopHandle(ctx: *const GeometryContext, arg: *const network.Expr) !spatial.LoopId {
    if (arg.kind != .variable) return error.InvalidGeometryArgument;
    const handle = ctx.bindings.get(arg.name) orelse return error.UndefinedGeometryReference;
    return switch (handle) {
        .loop => |id| id,
        else => error.InvalidGeometryArgument,
    };
}

fn handlePoint(ctx: *GeometryContext, allocator: std.mem.Allocator, args: []const *network.Expr) !GeometryHandle {
    _ = allocator;
    const is_3d = ctx.graph.dim == .spatial3d;
    if (args.len != (if (is_3d) @as(usize, 3) else 2)) return error.InvalidGeometryArgument;

    const x = try resolveCoord(args[0]);
    const y = try resolveCoord(args[1]);
    const z: f64 = if (is_3d) try resolveCoord(args[2]) else 0.0;

    const id = try spatial.addPoint(&ctx.graph, .{ .x = x, .y = y, .z = z });
    return .{ .point = id };
}

fn handleEdge(ctx: *GeometryContext, allocator: std.mem.Allocator, args: []const *network.Expr) !GeometryHandle {
    _ = allocator;
    if (args.len != 2) return error.InvalidGeometryArgument;

    const start = try resolvePointHandle(ctx, args[0]);
    const end = try resolvePointHandle(ctx, args[1]);

    const id = try spatial.addEdge(&ctx.graph, start, end);
    return .{ .edge = id };
}

fn handleLoop(ctx: *GeometryContext, allocator: std.mem.Allocator, args: []const *network.Expr) !GeometryHandle {
    const edge_ids = try allocator.alloc(spatial.EdgeId, args.len);
    defer allocator.free(edge_ids);

    for (args, 0..) |arg, i| {
        edge_ids[i] = try resolveEdgeHandle(ctx, arg);
    }

    // addLoop copies edge_ids into its own owned list (appendSlice) and
    // validates closure (continuity + returning to the start point), so
    // this temporary slice doesn't need to outlive the call, and a
    // malformed loop surfaces as one of addLoop's own validation errors
    // (error.DegenerateLoop / error.DiscontinuousLoop / error.UnclosedLoop)
    // rather than anything the spatial domain needs to check itself.
    const id = try spatial.addLoop(&ctx.graph, edge_ids);
    return .{ .loop = id };
}

fn handleFace(ctx: *GeometryContext, allocator: std.mem.Allocator, args: []const *network.Expr) !GeometryHandle {
    _ = allocator;
    if (args.len != 1) return error.InvalidGeometryArgument;

    const loop_id = try resolveLoopHandle(ctx, args[0]);

    const id = try spatial.addFace(&ctx.graph, loop_id);
    return .{ .face = id };
}