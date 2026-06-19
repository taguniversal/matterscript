const std = @import("std");
const ca1d = @import("ca1d.zig");
const Program = @import("program.zig").Program;
const workspace = @import("workspace.zig");

pub fn writeObjVoxel(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Program,
) !void {
    const stdout = std.debug;
    _ = stdout;

    const width = program.ca_width;
    const steps = program.ca_steps;

    var current = try allocator.alloc(u8, width);
    var next = try allocator.alloc(u8, width);

    @memset(current, 0);
    current[width / 2] = 1;

    try workspace.ensureNamespace(io, program);

    const output_path = try workspace.artifactPath(
        allocator,
        program,
        "voxel.obj",
    );

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(io, &buffer);
    const w = &writer.interface;

    try w.print("# MatterScript voxel OBJ\n", .{});
    try w.print("# width={d} steps={d} rule={d}\n", .{
        width,
        steps,
        program.ca_rule,
    });

    var vertex_index: usize = 1;

    var row: usize = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;
        while (col < width) : (col += 1) {
            if (current[col] == 1) {
                try emitCube(
                    w,
                    &vertex_index,
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    0.0,
                    1.0,
                );
            }
        }

        ca1d.step(current, next);
        const tmp = current;
        current = next;
        next = tmp;
    }

    try writer.interface.flush();
}

fn emitCube(
    writer: anytype,
    vertex_index: *usize,
    x: f32,
    y: f32,
    z: f32,
    size: f32,
) !void {
    const x1 = x + size;
    const y1 = y + size;
    const z1 = z + size;

    try writer.print("v {d} {d} {d}\n", .{ x, y, z });
    try writer.print("v {d} {d} {d}\n", .{ x1, y, z });
    try writer.print("v {d} {d} {d}\n", .{ x1, y1, z });
    try writer.print("v {d} {d} {d}\n", .{ x, y1, z });

    try writer.print("v {d} {d} {d}\n", .{ x, y, z1 });
    try writer.print("v {d} {d} {d}\n", .{ x1, y, z1 });
    try writer.print("v {d} {d} {d}\n", .{ x1, y1, z1 });
    try writer.print("v {d} {d} {d}\n", .{ x, y1, z1 });

    const b = vertex_index.*;

    // bottom
    try writer.print("f {d} {d} {d}\n", .{ b, b + 2, b + 1 });
    try writer.print("f {d} {d} {d}\n", .{ b, b + 3, b + 2 });

    // top
    try writer.print("f {d} {d} {d}\n", .{ b + 4, b + 5, b + 6 });
    try writer.print("f {d} {d} {d}\n", .{ b + 4, b + 6, b + 7 });

    // front
    try writer.print("f {d} {d} {d}\n", .{ b, b + 1, b + 5 });
    try writer.print("f {d} {d} {d}\n", .{ b, b + 5, b + 4 });

    // back
    try writer.print("f {d} {d} {d}\n", .{ b + 3, b + 7, b + 6 });
    try writer.print("f {d} {d} {d}\n", .{ b + 3, b + 6, b + 2 });

    // left
    try writer.print("f {d} {d} {d}\n", .{ b, b + 4, b + 7 });
    try writer.print("f {d} {d} {d}\n", .{ b, b + 7, b + 3 });

    // right
    try writer.print("f {d} {d} {d}\n", .{ b + 1, b + 2, b + 6 });
    try writer.print("f {d} {d} {d}\n", .{ b + 1, b + 6, b + 5 });

    vertex_index.* += 8;
}
