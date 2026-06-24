const std = @import("std");

pub fn namespaceDir(
    allocator: std.mem.Allocator,
    program: anytype,
) ![]const u8 {
    return try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}",
        .{program.namespace},
    );
}

pub fn artifactPath(
    allocator: std.mem.Allocator,
    program: anytype,
    filename: []const u8,
) ![]const u8 {
    return try std.fmt.allocPrint(
        allocator,
        "../workspace/{s}/{s}",
        .{ program.namespace, filename },
    );
}

pub fn ensureNamespace(
    io: std.Io,
    program: anytype,
) !void {
    var buffer: [512]u8 = undefined;

    const path = try std.fmt.bufPrint(
        &buffer,
        "../workspace/{s}",
        .{program.namespace},
    );

    try std.Io.Dir.cwd().createDirPath(io, path);
}
