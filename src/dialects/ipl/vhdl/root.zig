// export_vhdl.zig
// VHDL emitter for MatterScript Invocation Language networks
//
// Port mapping (Fant authoritative grammar):
//   Definition source place  (name<>) → VHDL input  port  (tokens flow IN)
//   Definition destination place ($name) → VHDL output port (tokens flow OUT)
//
// Signal encoding:
//   signal[7:0] = { data[6:0], valid }
//   signal[0]   = valid bit  (1=DATA, 0=NULL)
//   signal[7:1] = 7-bit data payload (up to 127 distinct token values)

const std = @import("std");
const network = @import("../network.zig");
const entity = @import("entity.zig");
const workspace = @import("../../../common/workspace.zig");

pub const sanitizer = @import("sanitizer.zig");

pub fn writeVhdlNetwork(
    io: std.Io,
    allocator: std.mem.Allocator,
    namespace: []const u8,
    net: network.Network,
    output_name: []const u8,
) !void {
    const output_path = try std.fmt.allocPrint(allocator, "../workspace/{s}/{s}", .{ namespace, output_name });
    defer allocator.free(output_path);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer file.close(io);

    var buffer: [65536]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try write(allocator, &writer.interface, net);
    try writer.interface.flush();
}

pub fn write(allocator: std.mem.Allocator, writer: anytype, net: network.Network) !void {
    for (net.definitions) |def| {
        try entity.writeDefinition(allocator, writer, def, "");
    }
    try entity.writeNetworkEntity(allocator, writer, net);
}


