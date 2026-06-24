const std = @import("std");
const workspace = @import("../../common/workspace.zig");
const StateProgram = @import("program.zig").Program;

pub fn writeZigTests(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: StateProgram,
    output_name: []const u8,
) !void {
    try workspace.ensureNamespace(io, program);

    const output_path = try workspace.artifactPath(
        allocator,
        program,
        output_name,
    );
    defer allocator.free(output_path);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer file.close(io);

    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);

    try write(&writer.interface, program);
    try writer.interface.flush();
}

pub fn write(writer: anytype, program: StateProgram) !void {
    const m = program.machine;

    try writer.writeAll(
        \\const std = @import("std");
        \\const sm = @import("machine.zig");
        \\
        \\test "happy path reaches final state" {
        \\
    );

    if (m.states.len > 0) {
        try writer.print("    var state = sm.State.{s};\n\n", .{m.states[0].name});
    }

    for (m.transitions) |t| {
        try writer.print(
            "    state = sm.next(state, .{s}).?;\n",
            .{t.on},
        );
    }

    if (m.states.len > 0) {
        try writer.print(
            "\n    try std.testing.expectEqual(sm.State.{s}, state);\n",
            .{m.states[m.states.len - 1].name},
        );
    }

    try writer.writeAll(
        \\}
        \\
        \\test "unexpected event returns null" {
        \\
    );

    if (m.states.len > 0 and m.events.len > 0) {
        try writer.print(
            "    const result = sm.next(.{s}, .{s});\n",
            .{ m.states[0].name, m.events[m.events.len - 1].name },
        );
        try writer.writeAll(
            \\    try std.testing.expect(result == null);
            \\
        );
    }

    try writer.writeAll(
        \\}
        \\
    );
}
