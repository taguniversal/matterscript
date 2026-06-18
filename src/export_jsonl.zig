const std = @import("std");
const Program = @import("program.zig").Program;
const ca1d = @import("ca1d.zig");


pub fn writeCaStateJsonl(io: std.Io, allocator: std.mem.Allocator, program: Program) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;

    var current = try allocator.alloc(u8, width);
    defer allocator.free(current);

    var next = try allocator.alloc(u8, width);
    defer allocator.free(next);

    @memset(current, 0);
    @memset(next, 0);

    current[width / 2] = 1;

    if (program.namespace.len == 0) {
        return error.MissingNamespace;
    }

    const output_dir = try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}",
        .{program.namespace},
    );

    const output_path = try std.fmt.allocPrint(
        allocator,
        "{s}/state.jsonl",
        .{output_dir},
    );

    try std.Io.Dir.cwd().createDirPath(io, output_dir);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(io, &buffer);

    var step: usize = 0;
    while (step < steps) : (step += 1) {
        try writer.interface.print(
            "{{\"step\":{d},\"row\":\"",
            .{step},
        );

        for (current) |cell| {
            const ch: u8 = if (cell == 1) '#' else '.';

            try writer.interface.print("{c}", .{ch});
        }

        try writer.interface.print("\"}}\n", .{});

        var x: usize = 0;
        while (x < width) : (x += 1) {
            const left = if (x == 0) current[width - 1] else current[x - 1];
            const center = current[x];
            const right = if (x == width - 1) current[0] else current[x + 1];

            const pattern: u8 = (left << 2) | (center << 1) | right;

            next[x] = switch (pattern) {
                0b111 => 0,
                0b110 => 0,
                0b101 => 0,
                0b100 => 1,
                0b011 => 1,
                0b010 => 1,
                0b001 => 1,
                0b000 => 0,
                else => 0,
            };
        }

        @memcpy(current, next);
    }

    try writer.interface.flush();
}
