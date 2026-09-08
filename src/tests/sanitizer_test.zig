const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const network = matterscript.network;
const sanitizer = matterscript.ipl_export_vhdl.sanitizer;

test "sanitizeName collapses a multi-variable composed name into one identifier" {
    // This is the exact shape writeExpressionFill hands it for a
    // composed expression like "$A$B()" (see the TAG-190/TAG-160
    // "no declaration for ab" bug, tracked at the call site in
    // src/tests/export_vhdl_test.zig): sanitizeName's own contract —
    // strip non-identifier characters from ONE string — is being met
    // correctly here. The bug is the caller treating a two-variable
    // composed key as if it were a single variable name before this
    // function ever sees it.
    const allocator = testing.allocator;
    const collapsed = try sanitizer.sanitizeName(allocator, "A$B");
    defer allocator.free(collapsed);
    try testing.expectEqualStrings("ab", collapsed);
}

test "normalizeDefinitionIdentifiers fans a single fill out to every destination sharing its raw name" {
    // Regression test for TAG-138's EQ0: "($condition $condition)"
    // declares the same raw destination name twice — Fant's "same
    // value delivered to two output slots" pattern (confirmed by
    // tracing the invocation site, which relabels the two slots
    // "incondition"/"outcondition" for two different steering points
    // in a feedback ring). VHDL forbids two ports sharing an
    // identifier, so the second occurrence needs its own distinct
    // name, and the one fill statement targeting "condition" needs
    // to reach both.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const raw_def = network.Definition{
        .name = "EQ0",
        .sources = &.{},
        .destinations = &.{
            .{ .kind = .place, .name = "condition", .text = "condition" },
            .{ .kind = .place, .name = "condition", .text = "condition" },
        },
        .resolution = &.{
            .{ .fill = .{ .dest_name = "condition", .expr = "1" } },
        },
        .constants = &.{},
    };

    const def = try sanitizer.normalizeDefinitionIdentifiers(allocator, raw_def);

    try testing.expectEqual(@as(usize, 2), def.destinations.len);
    try testing.expectEqualStrings("condition", def.destinations[0].name);
    try testing.expectEqualStrings("condition_1", def.destinations[1].name);

    try testing.expectEqual(@as(usize, 2), def.resolution.len);
    try testing.expectEqualStrings("condition", def.resolution[0].fill.dest_name);
    try testing.expectEqualStrings("1", def.resolution[0].fill.expr);
    try testing.expectEqualStrings("condition_1", def.resolution[1].fill.dest_name);
    try testing.expectEqualStrings("1", def.resolution[1].fill.expr);
}

test "normalizeDefinitionIdentifiers leaves non-duplicated destinations untouched" {
    // The alias map records every destination (not just duplicates),
    // so this confirms that path stays a no-op for the ordinary case.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const raw_def = network.Definition{
        .name = "FULLADD",
        .sources = &.{},
        .destinations = &.{
            .{ .kind = .place, .name = "SUM", .text = "SUM" },
            .{ .kind = .place, .name = "CARRY", .text = "CARRY" },
        },
        .resolution = &.{
            .{ .fill = .{ .dest_name = "SUM", .expr = "1" } },
            .{ .fill = .{ .dest_name = "CARRY", .expr = "0" } },
        },
        .constants = &.{},
    };

    const def = try sanitizer.normalizeDefinitionIdentifiers(allocator, raw_def);

    try testing.expectEqual(@as(usize, 2), def.destinations.len);
    try testing.expectEqualStrings("sum", def.destinations[0].name);
    try testing.expectEqualStrings("carry", def.destinations[1].name);
    try testing.expectEqual(@as(usize, 2), def.resolution.len);
}

test "sanitizeName never produces consecutive, leading, or trailing underscores" {
    // Regression test: canonicalizeDefNames (parser.zig) used to name
    // anonymous contained definitions "__anon_N" (leading double
    // underscore). scopedDefinitionName joins scope and name with a
    // single "_", so "code" + "_" + "__anon_11" produced
    // "code___anon_11" — three consecutive underscores, which ghdl
    // rejects outright ("two underscores can't be consecutive"). That
    // specific name is now "anon_N" instead, but sanitizeName is
    // hardened here too, since any raw IPL name containing "__", or
    // starting/ending with "_", would trip the same VHDL rule.
    const allocator = testing.allocator;

    const leading = try sanitizer.sanitizeName(allocator, "__anon_11");
    defer allocator.free(leading);
    try testing.expectEqualStrings("anon_11", leading);
    try testing.expect(std.mem.indexOf(u8, leading, "__") == null);

    const joined = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ "code", leading });
    defer allocator.free(joined);
    try testing.expect(std.mem.indexOf(u8, joined, "__") == null);

    const internal = try sanitizer.sanitizeName(allocator, "A__B");
    defer allocator.free(internal);
    try testing.expectEqualStrings("a_b", internal);

    const trailing = try sanitizer.sanitizeName(allocator, "FOO_");
    defer allocator.free(trailing);
    try testing.expectEqualStrings("foo", trailing);
}