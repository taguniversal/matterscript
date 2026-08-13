const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;
    _ = io;

    std.debug.print("Weaving documentation and visual assets...\n", .{});
    std.debug.print("  args: {d}\n", .{args.len});

    // Scan docs for directive-tagged fences, render figures, emit HTML/PDF
}