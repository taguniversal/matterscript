const std = @import("std");

const parser = @import("parser.zig");
const export_jsonl = @import("export_jsonl.zig");
const export_pgm = @import("export_pgm.zig");
const export_obj = @import("export_obj.zig");
const export_voxel_obj = @import("export_voxel_obj.zig");

pub fn build(
    io: std.Io,
    allocator: std.mem.Allocator,
    source: []const u8,
) !void {
    const program = try parser.parseProgram(source);

    try export_jsonl.writeCaStateJsonl(io, allocator, program);
    try export_pgm.writeHeightmapPgm(io, allocator, program);
    try export_obj.writeObjHeightmap(io, allocator, program);
    try export_voxel_obj.writeObjVoxel(io, allocator, program);
}
