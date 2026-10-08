const std = @import("std");
const network = @import("matterscript").network;
const boundary = @import("matterscript").vhdl.boundary;

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

test "boundaryCount calculates correct number of ports" {
    var ports = [_]network.Arg{
        .{ .kind = .place, .name = "a" },
        .{ .kind = .place, .name = "b" },
        .{ .kind = .place, .name = "c" },
    };

    try std.testing.expectEqual(@as(usize, 3), boundary.boundaryCount(&ports));
    try std.testing.expectEqual(@as(usize, 0), boundary.boundaryCount(&[_]network.Arg{}));
}
