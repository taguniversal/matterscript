const std = @import("std");
const machine = @import("machine.zig");
const StateProgram = @import("program.zig").Program;
const workspace = @import("../../common/workspace.zig");

pub fn writeZigMachine(
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

    try write(&writer.interface, program.machine);
    try writer.interface.flush();
}

pub fn write(writer: anytype, m: machine.Machine) !void {
    try writer.print("// generated MKULTRA state machine\n", .{});
    try writer.print("// machine: {s}\n\n", .{m.name});

    try writer.print("pub const State = enum {{\n", .{});
    for (m.states) |s| {
        try writer.print("    {s},\n", .{s.name});
    }
    try writer.print("}};\n\n", .{});

    try writer.print("pub const Event = enum {{\n", .{});
    for (m.events) |e| {
        try writer.print("    {s},\n", .{e.name});
    }
    try writer.print("}};\n\n", .{});

    try writer.writeAll(
        \\pub fn next(state: State, event: Event) ?State {
        \\    return switch (state) {
        \\
    );

    for (m.states) |s| {
        try writer.print("        .{s} => switch (event) {{\n", .{s.name});

        for (m.transitions) |t| {
            if (std.mem.eql(u8, t.from, s.name)) {
                try writer.print("            .{s} => .{s},\n", .{ t.on, t.to });
            }
        }

        try writer.print("            else => null,\n", .{});
        try writer.print("        }},\n", .{});
    }

    try writer.writeAll(
        \\    };
        \\}
        \\
    );
}
