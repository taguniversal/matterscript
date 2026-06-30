const std = @import("std");
const Io = std.Io;
const ca1d = @import("dialects/geo/ca1d.zig");

const geo_parser = @import("dialects/geo/parser.zig");
const state_parser = @import("dialects/state/parser.zig");
const state_export_zig = @import("dialects/state/export_zig.zig");
const GeoProgram = @import("dialects/geo/program.zig").Program;
const geo_build = @import("dialects/geo/geo_build.zig");
const StateProgram = @import("dialects/state/program.zig").Program;
const cell_runner = @import("dialects/geo/runner.zig");
const state_export_test = @import("dialects/state/export_test.zig");

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
    try geo_parser.tokenize(stdout_writer, source);

    try stdout_writer.print("\nParsed Program:\n", .{});

    if (std.mem.endsWith(u8, script_path, ".ms.state")) {
        const machine = try state_parser.parse(arena, source);
        const state_program = StateProgram{
            .namespace = "coffee",
            .machine = machine,
            .export_path = "",
        };

        try state_export_zig.writeZigMachine(
            io,
            arena,
            state_program,
            "machine.zig",
        );

        try state_export_test.writeZigTests(
            io,
            arena,
            state_program,
            "machine_test.zig",
        );

        try stdout_writer.flush();

        return;
    }

    const program = try geo_parser.parseProgram(source);

    try stdout_writer.print("namespace: {s}\n", .{program.namespace});
    try stdout_writer.print("seed: {s}\n", .{program.seed});
    try stdout_writer.print("ca1d rule: {d}\n", .{program.ca_rule});
    try stdout_writer.print("ca1d width: {d}\n", .{program.ca_width});
    try stdout_writer.print("ca1d steps: {d}\n", .{program.ca_steps});
    try stdout_writer.print("height scale: {d}\n", .{program.height_scale});
    try stdout_writer.print("export: {s} {s}\n", .{ program.export_format, program.export_path });

    try stdout_writer.print("\nRule 30 Output:\n\n", .{});
    try cell_runner.runCa1d(stdout_writer, program);
    try geo_build.build(io, arena, source);
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
