const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const core = matterscript.core;
const network = matterscript.network;
const statements = matterscript.statements;
const validate = matterscript.validate;

test "validate: undefined callee is reported with caller and callee names" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const net = network.Network{
        .definitions = &.{validate.stubDef("CALLER", &.{validate.stubInvoke("GHOST")})},
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try std.testing.expectError(error.UndefinedInvocation, validate.validateWithDiagnostic(arena.allocator(), net, &diag));
    try std.testing.expectEqualStrings("GHOST", diag.name);
    try std.testing.expectEqualStrings("CALLER", diag.in);
}

test "validate: callee defined after its caller is fine" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const net = network.Network{
        .definitions = &.{ validate.stubDef("CALLER", &.{validate.stubInvoke("CALLEE")}), validate.stubDef("CALLEE", &.{}) },
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try validate.validateWithDiagnostic(arena.allocator(), net, &diag);
}

test "validate: duplicate top-level definition names are rejected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const net = network.Network{
        .definitions = &.{ validate.stubDef("FULLADD", &.{}), validate.stubDef("FULLADD", &.{}) },
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try std.testing.expectError(error.DuplicateDefinition, validate.validateWithDiagnostic(arena.allocator(), net, &diag));
    try std.testing.expectEqualStrings("FULLADD", diag.name);
}