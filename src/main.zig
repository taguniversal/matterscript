const std = @import("std");
const Io = std.Io;

const geo_parser = @import("dialects/geo/parser.zig");
const state_parser = @import("dialects/fsm/parser.zig");
const state_export_vhdl = @import("dialects/fsm/export_vhdl.zig");
const state_export_tb = @import("dialects/fsm/export_tb.zig");
const GeoProgram = @import("dialects/geo/program.zig").Program;
const geo_build = @import("dialects/geo/geo_build.zig");
const StateProgram = @import("dialects/fsm/program.zig").Program;
const cell_runner = @import("dialects/geo/runner.zig");
const il_parser = @import("dialects/ipl/parser.zig");
const il_export_vhdl = @import("dialects/ipl/export_vhdl.zig");

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

    if (std.mem.endsWith(u8, script_path, ".ms.fsm")) {
        const m = try state_parser.parse(arena, source);
        const state_program = StateProgram{
            .namespace = "coffee",
            .machine = m,
            .export_path = "",
        };

        try stdout_writer.print("Parsed FSM: {s}\n", .{m.name});
        try stdout_writer.print("  states:      {d}\n", .{m.states.len});
        try stdout_writer.print("  events:      {d}\n", .{m.events.len});
        try stdout_writer.print("  transitions: {d}\n\n", .{m.transitions.len});

        try state_export_vhdl.writeVhdlMachine(io, arena, state_program, "machine.vhd");
        try state_export_tb.writeTbMachine(io, arena, state_program, "tb_machine.cpp");

        try stdout_writer.print("Wrote machine.vhd\n", .{});
        try stdout_writer.print("Wrote tb_machine.cpp\n", .{});
        try stdout_writer.flush();
        return;
    }

    // add this branch in main() alongside the .ms.fsm branch:
    if (std.mem.endsWith(u8, script_path, ".ms.il")) {
        const net = try il_parser.parse(arena, source);

        try stdout_writer.print("Parsed IL network\n", .{});
        try stdout_writer.print("  definitions: {d}\n", .{net.definitions.len});
        for (net.definitions) |def| {
            try stdout_writer.print("\ndef {s}\n", .{def.name});
            try stdout_writer.print("  destinations: {d}\n", .{def.destinations.len});
            try stdout_writer.print("  sources:      {d}\n", .{def.sources.len});
            try stdout_writer.print("  statements:   {d}\n", .{def.resolution.len});
            for (def.constants) |tbl| {
                switch (tbl.kind) {
                    .explicit => |entries| try stdout_writer.print("  table {s}: {d} entries (explicit)\n", .{ tbl.composed_name, entries.len }),
                    .generate => try stdout_writer.print("  table {s}: generate block\n", .{tbl.composed_name}),
                }
            }
        }
        for (net.entries) |e| {
            try stdout_writer.print("\nentry: {s} with {d} args\n", .{ e.name, e.args.len });
        }

        try il_export_vhdl.writeVhdlNetwork(
            io,
            arena,
            "add", // namespace — matches workspace/add/
            net,
            "add.vhd",
        );
        try stdout_writer.print("\nWrote add.vhd\n", .{});
        try stdout_writer.flush();
        return;
    }

    // geo dialect
    try stdout_writer.print("\nTokens:\n", .{});
    try geo_parser.tokenize(stdout_writer, source);

    try stdout_writer.print("\nParsed Program:\n", .{});
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
        \\Examples:
        \\  matterscript examples/coffee/coffee.ms.fsm
        \\  matterscript examples/terrain.ms.geo
        \\
    , .{});
}
