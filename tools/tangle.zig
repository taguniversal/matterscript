const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;
    _ = io; // will be used once tangle actually reads/writes files

    std.debug.print("Tangling documentation sources...\n", .{});
    std.debug.print("  args: {d}\n", .{args.len});

    // Parsing logic for extractable code blocks (e.g. ```zig ... ```)
    // Read input files, parse code fences, write extracted files to output dir
}