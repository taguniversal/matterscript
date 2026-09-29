const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const core = matterscript.core;
const network = matterscript.network;
const statements = matterscript.statements;
const validate = matterscript.validate;

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

// --- 

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

test "validate: a top-level callee, defined after its caller, is fine" {
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

test "validate: an ordinary lookup-table entry in contained is fine" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Shape of a real fill-shaped child, e.g. K[SUM<K>]: no ports, one
    // .fill statement.
    const net = network.Network{
        .definitions = &.{validate.stubDefIn("FULLADD", &.{}, &.{validate.stubDef("K", &.{validate.stubFill("SUM", "$K")})})},
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try validate.validateWithDiagnostic(arena.allocator(), net, &diag);
}

test "validate: a genuine definition nested in contained is rejected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // NOT[(A<>)($res) ...] nested inside FOO instead of being top-level.
    const not_sources = [_]network.Arg{.{ .kind = .place, .name = "A", .text = "A<>" }};
    const net = network.Network{
        .definitions = &.{validate.stubDefIn("FOO", &.{}, &.{validate.stubDefWithPorts("NOT", &not_sources, &.{})})},
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try std.testing.expectError(error.NestedDefinitionNotAllowed, validate.validateWithDiagnostic(arena.allocator(), net, &diag));
    try std.testing.expectEqualStrings("NOT", diag.name);
    try std.testing.expectEqualStrings("FOO", diag.in);
}

test "validate: an invoke tucked inside a contained entry is also rejected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Even with no declared ports, an .invoke inside a contained entry
    // is a smuggled call, not a lookup row.
    const net = network.Network{
        .definitions = &.{
            validate.stubDefIn("FOO", &.{}, &.{validate.stubDef("SNEAKY", &.{validate.stubInvoke("NOT")})}),
            validate.stubDef("NOT", &.{}),
        },
        .entries = &.{},
        .free_destinations = &.{},
    };
    var diag: validate.Diagnostic = .{};
    try std.testing.expectError(error.NestedDefinitionNotAllowed, validate.validateWithDiagnostic(arena.allocator(), net, &diag));
    try std.testing.expectEqualStrings("SNEAKY", diag.name);
    try std.testing.expectEqualStrings("FOO", diag.in);
}