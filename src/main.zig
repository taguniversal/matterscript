const std = @import("std");

const Io = std.Io;

const Program = struct {
    namespace: []const u8 = "",
    seed: []const u8 = "",

    ca_rule: u8 = 0,
    ca_width: usize = 0,

    ca_steps: usize = 0,
    height_scale: f32 = 1.0,

    export_format: []const u8 = "",
    export_path: []const u8 = "",
};

fn tokenize(writer: anytype, source: []const u8) !void {
    var line_iter = std.mem.splitScalar(u8, source, '\n');
    var line_number: usize = 1;

    while (line_iter.next()) |raw_line| : (line_number += 1) {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");

        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "#")) continue;

        try writer.print("line {d}: ", .{line_number});

        var token_iter = std.mem.tokenizeAny(u8, line, " \t\r\n");
        var first = true;

        while (token_iter.next()) |token| {
            if (!first) {
                try writer.print(" | ", .{});
            }

            try writer.print("{s}", .{token});
            first = false;
        }

        try writer.print("\n", .{});
    }
}

fn parseProgram(source: []const u8) !Program {
    var program = Program{};

    var line_iter = std.mem.splitScalar(u8, source, '\n');

    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");

        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "#")) continue;

        var tokens = std.mem.tokenizeAny(u8, line, " \t\r\n");

        const first = tokens.next() orelse continue;

        if (std.mem.eql(u8, first, "namespace")) {
            program.namespace = tokens.next() orelse return error.MissingNamespace;
            continue;
        }

        if (std.mem.eql(u8, first, "seed")) {
            program.seed = tokens.next() orelse return error.MissingSeed;
            continue;
        }

        if (std.mem.eql(u8, first, "ca1d")) {
            while (tokens.next()) |key| {
                const value = tokens.next() orelse return error.MissingCaValue;

                if (std.mem.eql(u8, key, "rule")) {
                    program.ca_rule = try std.fmt.parseInt(u8, value, 10);
                } else if (std.mem.eql(u8, key, "width")) {
                    program.ca_width = try std.fmt.parseInt(usize, value, 10);
                } else if (std.mem.eql(u8, key, "steps")) {
                    program.ca_steps = try std.fmt.parseInt(usize, value, 10);
                } else {
                    return error.UnknownCaKey;
                }
            }

            continue;
        }

        if (std.mem.eql(u8, first, "height")) {
            const key = tokens.next() orelse return error.MissingHeightKey;
            const value = tokens.next() orelse return error.MissingHeightValue;

            if (std.mem.eql(u8, key, "scale")) {
                program.height_scale = try std.fmt.parseFloat(f32, value);
            } else {
                return error.UnknownHeightKey;
            }

            continue;
        }

        if (std.mem.eql(u8, first, "export")) {
            program.export_format = tokens.next() orelse return error.MissingExportFormat;
            program.export_path = tokens.next() orelse return error.MissingExportPath;
            continue;
        }

        return error.UnknownStatement;
    }

    return program;
}

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

fn writeCaStateJsonl(io: std.Io, allocator: std.mem.Allocator, program: Program) !void {
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

fn writeHeightmapPgm(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Program,
) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;

    const output_dir = try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}",
        .{program.namespace},
    );

    const output_path = try std.fmt.allocPrint(
        allocator,
        "{s}/heightmap.pgm",
        .{output_dir},
    );

    try std.Io.Dir.cwd().createDirPath(io, output_dir);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);

    try writer.interface.print("P2\n{d} {d}\n255\n", .{ width, steps });

    var current = try allocator.alloc(u8, width);
    var next = try allocator.alloc(u8, width);

    @memset(current, 0);
    @memset(next, 0);

    current[width / 2] = 1;

    var step: usize = 0;
    while (step < steps) : (step += 1) {
        for (current) |cell| {
            const value: u8 = if (cell == 1) 0 else 255;
            try writer.interface.print("{d} ", .{value});
        }

        try writer.interface.print("\n", .{});

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

fn writeObjHeightmap(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Program,
) !void {
    const width = program.ca_width;
    const steps = program.ca_steps;
    const scale = program.height_scale;

    const output_dir = try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}",
        .{program.namespace},
    );

    const output_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ output_dir, program.export_path },
    );

    try std.Io.Dir.cwd().createDirPath(io, output_dir);

    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close(io);

    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);

    try writer.interface.print("# MatterScript OBJ heightmap\n", .{});
    try writer.interface.print("# namespace: {s}\n", .{program.namespace});
    try writer.interface.print("# rule: {d}\n", .{program.ca_rule});
    try writer.interface.print("# width: {d}\n", .{width});
    try writer.interface.print("# steps: {d}\n", .{steps});
    try writer.interface.print("# height_scale: {d}\n\n", .{scale});

    var current = try allocator.alloc(u8, width);
    const next = try allocator.alloc(u8, width);

    @memset(current, 0);
    @memset(next, 0);

    current[width / 2] = 1;

    var row: usize = 0;
    while (row < steps) : (row += 1) {
        var col: usize = 0;

        while (col < width) : (col += 1) {
            const z: f32 = if (current[col] == 1) scale else 0.0;

            try writer.interface.print(
                "v {d} {d} {d}\n",
                .{
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    z,
                },
            );
        }

        stepCa1d(current, next);
    }

    try writer.interface.print("\n", .{});

    var y: usize = 0;
    while (y < steps - 1) : (y += 1) {
        var x: usize = 0;

        while (x < width - 1) : (x += 1) {
            const v1 = y * width + x + 1;
            const v2 = y * width + x + 2;
            const v3 = (y + 1) * width + x + 1;
            const v4 = (y + 1) * width + x + 2;

            try writer.interface.print("f {d} {d} {d}\n", .{ v1, v2, v3 });
            try writer.interface.print("f {d} {d} {d}\n", .{ v2, v4, v3 });
        }
    }

    try writer.interface.flush();
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
    try tokenize(stdout_writer, source);

    try stdout_writer.print("\nParsed Program:\n", .{});

    const program = try parseProgram(source);

    try stdout_writer.print("namespace: {s}\n", .{program.namespace});
    try stdout_writer.print("seed: {s}\n", .{program.seed});
    try stdout_writer.print("ca1d rule: {d}\n", .{program.ca_rule});
    try stdout_writer.print("ca1d width: {d}\n", .{program.ca_width});
    try stdout_writer.print("ca1d steps: {d}\n", .{program.ca_steps});
    try stdout_writer.print("height scale: {d}\n", .{program.height_scale});
    try stdout_writer.print("export: {s} {s}\n", .{ program.export_format, program.export_path });

    try stdout_writer.print("\nRule 30 Output:\n\n", .{});
    try runCa1d(stdout_writer, program);
    try writeCaStateJsonl(io, arena, program);
    try stdout_writer.print("\nWrote state.jsonl\n", .{});
    try writeHeightmapPgm(io, arena, program);
    try writeObjHeightmap(io, arena, program);
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
