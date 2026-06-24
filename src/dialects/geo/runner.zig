const std = @import("std");
const GeoProgram = @import("program.zig").Program;

pub fn runCa1d(writer: anytype, program: GeoProgram) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;

    var allocator = std.heap.page_allocator;

    var current = try allocator.alloc(u8, width);
    defer allocator.free(current);

    var next = try allocator.alloc(u8, width);
    defer allocator.free(next);

    @memset(current, 0);
    @memset(next, 0);

    // single live cell in center
    current[width / 2] = 1;

    var step: usize = 0;
    while (step < steps) : (step += 1) {

        // render current row
        for (current) |cell| {
            if (cell == 1) {
                try writer.print("#", .{});
            } else {
                try writer.print(".", .{});
            }
        }

        try writer.print("\n", .{});

        // generate next row
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const left =
                if (x == 0)
                    current[width - 1]
                else
                    current[x - 1];

            const center = current[x];

            const right =
                if (x == width - 1)
                    current[0]
                else
                    current[x + 1];

            const pattern: u8 =
                (left << 2) |
                (center << 1) |
                right;

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
}

fn stepCa1d(current: []u8, next: []u8) void {
    const width = current.len;

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
