const std = @import("std");
const Program = @import("program.zig").Program;
const ca1d = @import("ca1d.zig");
const workspace = @import("../../common/workspace.zig");

pub fn writeObjHeightmap(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Program,
) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;
    const scale = program.height_scale;
    const base = program.solid_base;

    try workspace.ensureNamespace(io, program);

    const output_path = try workspace.artifactPath(
        allocator,
        program,
        program.export_path,
    );

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);

    try writer.interface.print("# MatterScript OBJ solid heightmap\n", .{});
    try writer.interface.print("# namespace: {s}\n", .{program.namespace});
    try writer.interface.print("# rule: {d}\n", .{program.ca_rule});
    try writer.interface.print("# width: {d}\n", .{width});
    try writer.interface.print("# steps: {d}\n", .{steps});
    try writer.interface.print("# height_scale: {d}\n", .{scale});
    try writer.interface.print("# solid_base: {d}\n\n", .{base});

    const cell_count = width * steps;

    var heights = try allocator.alloc(f32, cell_count);
    defer allocator.free(heights);

    var current = try allocator.alloc(u8, width);
    defer allocator.free(current);

    const next = try allocator.alloc(u8, width);
    defer allocator.free(next);

    @memset(current, 0);
    @memset(next, 0);

    current[width / 2] = 1;

    var row: usize = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;

        while (col < width) : (col += 1) {
            heights[row * width + col] =
                if (current[col] == 1) scale else 0.0;
        }

        ca1d.step(current, next);
    }

    // Top vertices.
    row = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;

        while (col < width) : (col += 1) {
            const z = heights[row * width + col];

            try writer.interface.print(
                "v {d} {d} {d}\n",
                .{
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    z,
                },
            );
        }
    }

    // Bottom vertices.
    row = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;

        while (col < width) : (col += 1) {
            try writer.interface.print(
                "v {d} {d} {d}\n",
                .{
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    -base,
                },
            );
        }
    }

    try writer.interface.print("\n", .{});

    // Top surface faces.
    var y: usize = 0;
    while (y < steps - 1) : (y += 1) {
        var x: usize = 0;

        while (x < width - 1) : (x += 1) {
            const v1 = y * width + x + 1;
            const v2 = y * width + x + 2;
            const v3 = (y + 1) * width + x + 1;
            const v4 = (y + 1) * width + x + 2;

            try writer.interface.print("f {d} {d} {d}\n", .{ v1, v2, v3 });
            try writer.interface.print("f {d} {d} {d}\n", .{ v2, v4, v3 });
        }
    }

    // Bottom surface faces.
    const bottom_offset = cell_count;

    y = 0;
    while (y < steps - 1) : (y += 1) {
        var x: usize = 0;

        while (x < width - 1) : (x += 1) {
            const v1 = bottom_offset + y * width + x + 1;
            const v2 = bottom_offset + y * width + x + 2;
            const v3 = bottom_offset + (y + 1) * width + x + 1;
            const v4 = bottom_offset + (y + 1) * width + x + 2;

            try writer.interface.print("f {d} {d} {d}\n", .{ v1, v3, v2 });
            try writer.interface.print("f {d} {d} {d}\n", .{ v2, v3, v4 });
        }
    }

    // Front and back walls.
    var x: usize = 0;
    while (x < width - 1) : (x += 1) {
        // front y = 0
        {
            const t1 = x + 1;
            const t2 = x + 2;
            const b1 = bottom_offset + x + 1;
            const b2 = bottom_offset + x + 2;

            try writer.interface.print("f {d} {d} {d}\n", .{ t1, b1, t2 });
            try writer.interface.print("f {d} {d} {d}\n", .{ t2, b1, b2 });
        }

        // back y = steps - 1
        {
            const top_row = (steps - 1) * width;
            const t1 = top_row + x + 1;
            const t2 = top_row + x + 2;
            const b1 = bottom_offset + top_row + x + 1;
            const b2 = bottom_offset + top_row + x + 2;

            try writer.interface.print("f {d} {d} {d}\n", .{ t1, t2, b1 });
            try writer.interface.print("f {d} {d} {d}\n", .{ t2, b2, b1 });
        }
    }

    // Left and right walls.
    y = 0;
    while (y < steps - 1) : (y += 1) {
        // left x = 0
        {
            const t1 = y * width + 1;
            const t2 = (y + 1) * width + 1;
            const b1 = bottom_offset + y * width + 1;
            const b2 = bottom_offset + (y + 1) * width + 1;

            try writer.interface.print("f {d} {d} {d}\n", .{ t1, t2, b1 });
            try writer.interface.print("f {d} {d} {d}\n", .{ t2, b2, b1 });
        }

        // right x = width - 1
        {
            const t1 = y * width + width;
            const t2 = (y + 1) * width + width;
            const b1 = bottom_offset + y * width + width;
            const b2 = bottom_offset + (y + 1) * width + width;

            try writer.interface.print("f {d} {d} {d}\n", .{ t1, b1, t2 });
            try writer.interface.print("f {d} {d} {d}\n", .{ t2, b1, b2 });
        }
    }

    try writer.interface.flush();
}
