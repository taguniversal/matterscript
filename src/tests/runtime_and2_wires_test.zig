const std = @import("std");
const matterscript = @import("matterscript");
const network = matterscript.network;
const runtime = matterscript.ipl_runtime;

// AND2[(A<> B<>)($OUT)
//     $A $B :
//   p,r[Z0]   // A=0(p), B=0(r) -> Z0 (OUT=0)
//   p,s[Z0]   // A=0(p), B=1(s) -> Z0 (OUT=0)
//   q,r[Z0]   // A=1(q), B=0(r) -> Z0 (OUT=0)
//   q,s[Z1]   // A=1(q), B=1(s) -> Z1 (OUT=1)
//   Z0[OUT<0>]
//   Z1[OUT<1>]
// ]
//
// p, q (wire A's two symbols) and r, s (wire B's two symbols) are seeded
// directly by the test, standing in for whatever upstream mechanism
// would normally assert them from A/B — the same simplification as the
// original AND2 fixture, kept deliberate rather than solved here.

const and2_sources = [_]network.Arg{
    .{ .name = "A", .kind = .place },
    .{ .name = "B", .kind = .place },
};
const and2_destinations = [_]network.Arg{
    .{ .name = "OUT", .kind = .place },
};
const and2_contained = [_]network.Definition{
    .{ .name = "p,r", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "Z0" }} },
    .{ .name = "p,s", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "Z0" }} },
    .{ .name = "q,r", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "Z0" }} },
    .{ .name = "q,s", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "Z1" }} },
    .{ .name = "Z0", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .fill = .{ .dest_name = "OUT", .expr = "0" } }} },
    .{ .name = "Z1", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .fill = .{ .dest_name = "OUT", .expr = "1" } }} },
};

fn testDef() network.Definition {
    return .{
        .name = "AND2",
        .sources = &and2_sources,
        .destinations = &and2_destinations,
        .resolution = &.{},
        .constants = &.{},
        .contained = &and2_contained,
    };
}

const Case = struct {
    a_symbol: []const u8,
    b_symbol: []const u8,
    expected_out_symbol: []const u8,
};

const cases = [_]Case{
    .{ .a_symbol = "p", .b_symbol = "r", .expected_out_symbol = "0" }, // 0,0 -> 0
    .{ .a_symbol = "p", .b_symbol = "s", .expected_out_symbol = "0" }, // 0,1 -> 0
    .{ .a_symbol = "q", .b_symbol = "r", .expected_out_symbol = "0" }, // 1,0 -> 0
    .{ .a_symbol = "q", .b_symbol = "s", .expected_out_symbol = "1" }, // 1,1 -> 1
};

test "AND2 truth table via wire-segregated symbols" {
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const a = arena.allocator();

        const def = testDef();
        const rules = try runtime.rules.buildRules(a, def);

        var env = runtime.Environment{ .allocator = a };
        defer env.deinit();
        try env.seed(case.a_symbol, case.a_symbol); // place name == symbol name for these seeded wire states
        try env.seed(case.b_symbol, case.b_symbol);

        const report = try runtime.rules.run(a, &env, def, rules);
        try std.testing.expect(report.complete);

        const out = env.get("OUT");
        try std.testing.expect(out == .valid);
        try std.testing.expectEqualStrings(case.expected_out_symbol, env.symbols.items[out.valid]);
    }
}