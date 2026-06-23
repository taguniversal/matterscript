const std = @import("std");
const Io = std.Io;
const ca1d = @import("dialects/geo/ca1d.zig");
const program_mod = @import("common/program.zig");
const parser = @import("dialects/geo/parser.zig");
const export_jsonl = @import("dialects/geo/export_jsonl.zig");
const export_pgm = @import("dialects/geo/export_pgm.zig");
const export_obj = @import("dialects/geo/export_obj.zig");
const export_voxel = @import("dialects/geo/export_voxel_obj.zig");
const Program = program_mod.Program;

fn runCa1d(writer: anytype, program: Program) !void {
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

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    if (args.len != 2) {
        try usage(stdout_writer);
        try stdout_writer.flush();
        return;
    }

    const script_path = args[1];

    const source = try std.Io.Dir.cwd().readFileAlloc(
        io,
        script_path,
        arena,
        .limited(1024 * 1024),
    );

    try stdout_writer.print("MatterScript source: {s}\n\n", .{script_path});
    try stdout_writer.print("{s}\n", .{source});

    try stdout_writer.print("\nTokens:\n", .{});
    try parser.tokenize(stdout_writer, source);

    try stdout_writer.print("\nParsed Program:\n", .{});

    const program = try parser.parseProgram(source);

    try stdout_writer.print("namespace: {s}\n", .{program.namespace});
    try stdout_writer.print("seed: {s}\n", .{program.seed});
    try stdout_writer.print("ca1d rule: {d}\n", .{program.ca_rule});
    try stdout_writer.print("ca1d width: {d}\n", .{program.ca_width});
    try stdout_writer.print("ca1d steps: {d}\n", .{program.ca_steps});
    try stdout_writer.print("height scale: {d}\n", .{program.height_scale});
    try stdout_writer.print("export: {s} {s}\n", .{ program.export_format, program.export_path });

    try stdout_writer.print("\nRule 30 Output:\n\n", .{});
    try runCa1d(stdout_writer, program);
    try export_jsonl.writeCaStateJsonl(io, arena, program);
    try stdout_writer.print("\nWrote state.jsonl\n", .{});
    try export_pgm.writeHeightmapPgm(io, arena, program);
    if (std.mem.eql(u8, program.export_format, "obj")) {
        try export_obj.writeObjHeightmap(io, arena, program);
    }
    if (std.mem.eql(u8, program.export_format, "voxel")) {
    try export_voxel.writeObjVoxel(io, arena, program);
}
    try stdout_writer.print("solid base: {d}\n", .{program.solid_base});
    try stdout_writer.print("Wrote {s}\n", .{program.export_path});
    try stdout_writer.flush();
}

fn usage(writer: anytype) !void {
    try writer.print(
        \\Usage:
        \\  matterscript <script.ms>
        \\
        \\Example:
        \\  matterscript examples/hello.ms
        \\
    , .{});
}
