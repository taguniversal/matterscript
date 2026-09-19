const std = @import("std");
const network = @import("matterscript").network;
const boundary = @import("matterscript").boundary;

test "shouldSkipSpatialGeometry returns true for spatial 2D/3D without generate block" {
    const def2d = network.Definition{
        .name = "geom2d",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
        .generateBlock = null,
        .domain_spec = .{ .kind = .spatial2d },
    };
    const def3d = network.Definition{
        .name = "geom3d",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
        .generateBlock = null,
        .domain_spec = .{ .kind = .spatial3d },
    };

    try std.testing.expect(boundary.shouldSkipSpatialGeometry(def2d));
    try std.testing.expect(boundary.shouldSkipSpatialGeometry(def3d));
}

test "shouldSkipSpatialGeometry returns false for spatial1d or when generateBlock exists" {
    // Spatial 1D is not skipped
    const def1d = network.Definition{
        .name = "geom1d",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
        .generateBlock = null,
        .domain_spec = .{ .kind = .spatial1d },
    };
    try std.testing.expect(!boundary.shouldSkipSpatialGeometry(def1d));

    // Spatial 2D with a generate block produces VHDL, so it is not skipped

    const def_gen = network.Definition{
        .name = "cellular_automaton",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &.{},
        .constants = &.{},
        .generateBlock = network.GenerateBlock{},
        .domain_spec = .{ .kind = .spatial2d },
    };
    try std.testing.expect(!boundary.shouldSkipSpatialGeometry(def_gen));
}

test "normalizeReturnDestinations synthesizes implicit return for empty destinations" {
    const allocator = std.testing.allocator;

    // A definition with resolution fills but no explicit destinations
    const fill_stmt = network.Statement{
        .fill = .{
            .dest_name = "", // Unnamed fill -> should synthesize "result"
            .expr = "42",
        },
    };
    var stmts = [_]network.Statement{fill_stmt};

    const raw_def = network.Definition{
        .name = "implicit_return",
        .sources = &.{},
        .destinations = &.{},
        .resolution = &stmts,
        .constants = &.{},
    };

    const normalized = try boundary.normalizeReturnDestinations(allocator, raw_def);
    defer allocator.free(normalized.destinations);
    defer allocator.free(normalized.resolution);

    // Verify destination synthesis (§12.3.4)
    try std.testing.expectEqual(@as(usize, 1), normalized.destinations.len);
    try std.testing.expectEqualStrings("result", normalized.destinations[0].name);

    // Verify fill destination was updated
    try std.testing.expectEqualStrings("result", normalized.resolution[0].fill.dest_name);
}

test "normalizeReturnDestinations passes through definitions with existing destinations" {
    const allocator = std.testing.allocator;

    var existing_dests = [_]network.Arg{.{ .kind = .place, .name = "out1" }};
    const raw_def = network.Definition{
        .name = "explicit_return",
        .sources = &.{},
        .destinations = &existing_dests,
        .resolution = &.{},
        .constants = &.{},
    };

    const normalized = try boundary.normalizeReturnDestinations(allocator, raw_def);

    try std.testing.expectEqual(@as(usize, 1), normalized.destinations.len);
    try std.testing.expectEqualStrings("out1", normalized.destinations[0].name);
}

test "boundaryCount calculates correct number of ports" {
    var ports = [_]network.Arg{
        .{ .kind = .place, .name = "a" },
        .{ .kind = .place, .name = "b" },
        .{ .kind = .place, .name = "c" },
    };

    try std.testing.expectEqual(@as(usize, 3), boundary.boundaryCount(&ports));
    try std.testing.expectEqual(@as(usize, 0), boundary.boundaryCount(&[_]network.Arg{}));
}