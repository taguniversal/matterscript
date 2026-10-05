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
const workspace = @import("../../../common/workspace.zig");
const network_entity = @import("export/network_entity.zig");
pub const sanitizer = @import("sanitizer.zig");
const definition = @import("definition.zig");
const invocation = @import("export/invocation.zig");

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
    // Emit callees before callers so that an `entity work.X` reference
    // never precedes `entity X is` in the output file. GHDL analyzes
    // strictly top-to-bottom; an instantiation of an entity that is
    // declared later fails with "unit X not found", and every
    // subsequent architecture for that entity then fails with
    // "entity X was not analysed". The previous flat loop emitted
    // definitions in net.definitions order, which for examples like
    // TAG-218 (WRAP invoking INNER) put the caller first.
    var emitted: std.StringHashMapUnmanaged(void) = .empty;
    defer emitted.deinit(allocator);

    for (net.definitions) |def| {
        try emitDefWithDeps(allocator, writer, def, net.definitions, &emitted);
    }
    try network_entity.writeNetworkEntity(allocator, writer, net);
}

/// Emits `def` and, recursively, every callee it invokes — callees
/// first. The `emitted` set prevents double emission when two callers
/// share a callee, and also serves as the recursion's cycle guard:
/// a definition is marked emitted *before* its dependencies are
/// walked, so a mutual-recursion pair (A invokes B, B invokes A)
/// terminates instead of looping. VHDL can't express mutual
/// recursion at the entity level anyway, so emitting both once and
/// letting GHDL reject the arrangement (if it ever arises) is the
/// right failure mode.
fn emitDefWithDeps(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    top: []const network.Definition,
    emitted: *std.StringHashMapUnmanaged(void),
) !void {
    const gop = try emitted.getOrPut(allocator, def.name);
    if (gop.found_existing) return;
    gop.value_ptr.* = {};
    // The key must outlive the map (it's stored by pointer, not copied),
    // so it's duped into the caller's arena rather than borrowed from
    // def.name — def is a by-value copy of the caller's definition, and
    // nothing guarantees its .name slice survives past this frame.
    gop.key_ptr.* = try allocator.dupe(u8, def.name);

    for (def.resolution) |stmt| {
        if (stmt != .invoke) continue;
        const callee = invocation.findCallee(def, top, stmt.invoke.name) orelse continue;
        try emitDefWithDeps(allocator, writer, callee, top, emitted);
    }

    try definition.writeDefinition(allocator, writer, def, "", top);
}