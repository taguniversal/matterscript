// Exports a 3D-printable/viewable mesh (.ply) for any definition whose
// @domain is spatial2d or spatial3d, by running it through the spatial
// domain's resolution pass (spatial_domain.zig) and then the existing
// triangulate/exportPly pipeline in geo/spatial.zig. This never touches
// VHDL emission — a geometry-only definition has nothing meaningful to
// say as hardware, and this module doesn't try to make it.

const std = @import("std");
const network = @import("../network.zig");
const spatial = @import("../../geo/spatial.zig");
const spatial_domain = @import("../domains/spatial_domain.zig");
const workspace = @import("../../../common/workspace.zig");

pub fn writeDefinitionMesh(
    io: std.Io,
    allocator: std.mem.Allocator,
    namespace: []const u8,
    def: network.Definition,
) !void {
    var ctx = try spatial_domain.resolveSpatialBindings(allocator, def);
    defer ctx.deinit(allocator);

    var mesh = try spatial.triangulate(&ctx.graph, allocator);
    defer mesh.deinit(allocator);

    const filename = try std.fmt.allocPrint(allocator, "{s}.ply", .{def.name});
    defer allocator.free(filename);

    try workspace.ensureNamespace(io, .{ .namespace = namespace });
    const output_path = try workspace.artifactPath(allocator, .{ .namespace = namespace }, filename);
    defer allocator.free(output_path);

    std.debug.print("Writing to path: {s}\n", .{output_path});
    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer file.close(io);

    var buffer: [65536]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try spatial.exportPly(&mesh, &writer.interface);
    try writer.interface.flush();
}

/// Walks every definition in a parsed network and exports one .ply per
/// spatial2d/spatial3d-domain definition, named after the definition
/// (e.g. "mobius_strip.ply"). Definitions with no @domain, or with
/// @domain(spatial1d) (still CA-generate-only), are left untouched.
pub fn writeNetworkMeshes(
    io: std.Io,
    allocator: std.mem.Allocator,
    namespace: []const u8,
    net: network.Network,
) !void {
    for (net.definitions) |def| {
        const spec = def.domain_spec orelse continue;
        switch (spec.kind) {
            .spatial2d, .spatial3d => try writeDefinitionMesh(io, allocator, namespace, def),
            .spatial1d => continue,
        }
    }
}