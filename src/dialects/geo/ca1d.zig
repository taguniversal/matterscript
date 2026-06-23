const std = @import("std");

pub fn step(current: []u8, next: []u8) void {
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
