const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const exporter = matterscript.ipl_export_vhdl;
const network = matterscript.network;
const entity = matterscript.entity;

// Tests

test "boundaryCount calculates scalar and group places correctly" {
    //const allocator = std.testing.allocator;

    // Create mock network args to test boundary counting
    const arg_place = network.Arg{
        .kind = .place,
        .name = "input_a",
    };

    // Test a single place
    const single_args = [_]network.Arg{arg_place};
    try std.testing.expectEqual(@as(usize, 1), entity.boundaryCount(&single_args));

    // Test a group containing multiple places
    var group_places = [_]network.Arg{
        .{ .kind = .place, .name = "p1" },
        .{ .kind = .place, .name = "p2" },
    };

    const my_place_group = network.PlaceGroup{
        .kind = .bundle,
        .places = &group_places,
    };
    const group_arg = network.Arg{
        .kind = .group,
        .group = &my_place_group,
    };

    const group_args = [_]network.Arg{group_arg};
    try std.testing.expectEqual(@as(usize, 2), entity.boundaryCount(&group_args));
}

test "argToText extracts expected string representations" {
    // 1. Place with name
    const place_arg = network.Arg{
        .kind = .place,
        .name = "foo",
        .text = "",
    };
    try std.testing.expectEqualSlices(u8, "foo", entity.argToText(place_arg));

    // 2. Literal text
    const literal_arg = network.Arg{
        .kind = .literal,
        .name = "",
        .text = "42",
    };
    try std.testing.expectEqualSlices(u8, "42", entity.argToText(literal_arg));
}

test "argContainsName checks nested structures" {
    var group_places = [_]network.Arg{
        .{ .kind = .place, .name = "target_place" },
    };

    const my_place_group = network.PlaceGroup{
        .kind = .bundle,
        .places = &group_places,
    };

    const nested_group = network.Arg{
        .kind = .group,
        .group = &my_place_group,
    };

    // Should find the name nested inside the group
    try std.testing.expect(entity.argContainsName(nested_group, "target_place"));
    // Should return false for missing names
    try std.testing.expect(!entity.argContainsName(nested_group, "nonexistent"));
}
