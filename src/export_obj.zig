const std = @import("std");
const Program = @import("program.zig").Program;
const ca1d = @import("ca1d.zig");


pub fn writeObjHeightmap(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Program,
) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;
    const scale = program.height_scale;

    const output_dir = try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}",
        .{program.namespace},
    );

    const output_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ output_dir, program.export_path },
    );

    try std.Io.Dir.cwd().createDirPath(io, output_dir);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);

    try writer.interface.print("# MatterScript OBJ heightmap\n", .{});
    try writer.interface.print("# namespace: {s}\n", .{program.namespace});
    try writer.interface.print("# rule: {d}\n", .{program.ca_rule});
    try writer.interface.print("# width: {d}\n", .{width});
    try writer.interface.print("# steps: {d}\n", .{steps});
    try writer.interface.print("# height_scale: {d}\n\n", .{scale});

    var current = try allocator.alloc(u8, width);
    const next = try allocator.alloc(u8, width);

    @memset(current, 0);
    @memset(next, 0);

    current[width / 2] = 1;

    var row: usize = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;

        while (col < width) : (col += 1) {
            const z: f32 = if (current[col] == 1) scale else 0.0;

            try writer.interface.print(
                "v {d} {d} {d}\n",
                .{
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    z,
                },
            );
        }

        ca1d.step(current, next);
    }

    try writer.interface.print("\n", .{});

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

    try writer.interface.flush();
}
