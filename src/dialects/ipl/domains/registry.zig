const std = @import("std");
const matterscript = @import("matterscript");
const network = matterscript.network;
const spatial = matterscript.spatial;


pub const DomainFn = *const fn (
    graph: *spatial.SpatialGraph,
    names: *std.StringHashMapUnmanaged(GeometryHandle), // "p0" -> PointId, etc.
    allocator: std.mem.Allocator,
    call_name: []const u8,   // "point", "edge", "loop", "face"
    args: []const network.Arg,
    bind_name: ?[]const u8,  // "p0" if this call's result should be nameable
) anyerror!void;

pub const GeometryHandle = union(enum) {
    point: spatial.PointId,
    edge: spatial.EdgeId,
    loop: spatial.LoopId,
    face: spatial.FaceId,
};

pub const spatial_domain = std.StaticStringMap(DomainFn).initComptime(.{
    .{ "point", handlePoint },
    .{ "edge", handleEdge },
    .{ "loop", handleLoop },
    .{ "face", handleFace },
});

fn handlePoint {};