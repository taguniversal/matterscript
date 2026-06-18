const std = @import("std");
const program_mod = @import("program.zig");

const Program = program_mod.Program;


pub fn tokenize(writer: anytype, source: []const u8) !void {
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

pub fn parseProgram(source: []const u8) !Program {
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

