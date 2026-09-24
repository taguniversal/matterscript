// src/tests/runtime_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const network = matterscript.network;
const runtime = matterscript.runtime;
const parser = matterscript.ipl_parser;
const rules = matterscript.runtime.rules;
const environment = matterscript.runtime.environment;

// AND2[(A<> B<>)($OUT)
//     $A $B :
//   p[K]
//   q[L]
//   K,L[result]
//   result -> OUT
// ]
//
// NOTE: A and B are declared boundary ports but are NOT wired to p/q
// anywhere in this fixture — the same "how does a boundary value produce
// its dual-rail/joint-match symbols" gap we hit in FULLADD/Example 12.25
// is sidestepped here deliberately, not resolved. p and q are seeded
// directly by the test as already-valid places, standing in for whatever
// upstream mechanism would normally assert them from A/B. This fixture
// exists to exercise the joint-match + fill mechanism in isolation, not
// to model a complete, self-contained AND gate.
//
// Chain: p (seeded) -> K (asserted, single-input rule)
//        q (seeded) -> L (asserted, single-input rule)
//        K,L         -> result (asserted, joint-match rule)
//        result      -> OUT (ordinary $-reference fill)

const and2_sources = [_]network.Arg{
    .{ .name = "A", .kind = .place },
    .{ .name = "B", .kind = .place },
};
const and2_destinations = [_]network.Arg{
    .{ .name = "OUT", .kind = .place },
};
const and2_resolution = [_]network.Statement{
    .{ .fill = .{ .dest_name = "OUT", .expr = "$result" } },
};
const and2_contained = [_]network.Definition{
    .{ .name = "p", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "K" }} },
    .{ .name = "q", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "L" }} },
    .{ .name = "K,L", .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = &[_]network.Statement{.{ .pure_value = "result" }} },
};

fn testDef() network.Definition {
    return .{
        .name = "AND2",
        .sources = &and2_sources,
        .destinations = &and2_destinations,
        .resolution = &and2_resolution,
        .constants = &.{},
        .contained = &and2_contained,
    };
}

test "runtime reaches completion once joint inputs are both present" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const def = testDef();
    const test_rules = try runtime.rules.buildRules(a, def);

    var env = runtime.environment.Environment{ .allocator = a };
    defer env.deinit();
    try env.seed("p", "K");
    try env.seed("q", "L");

    const report = try runtime.rules.run(a, &env, def, test_rules);
    try std.testing.expect(report.complete);
    try std.testing.expect(env.isValid("OUT"));
}

test "runtime reports exactly which place is stuck and what it's waiting on" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const def = testDef();
    const test_rules = try runtime.rules.buildRules(a, def);

    var env = runtime.environment.Environment{ .allocator = a };
    defer env.deinit();
    try env.seed("p", "K"); // q never arrives

    const report = try runtime.rules.run(a, &env, def, test_rules);
    try std.testing.expect(!report.complete);
    try std.testing.expectEqual(@as(usize, 1), report.stuck.len);
    try std.testing.expectEqualStrings("result", report.stuck[0].waiting_on[0]); // one level deep: OUT is waiting on "result", not transitively on "L"
    try std.testing.expectEqualStrings("result", report.stuck[0].waiting_on[0]); // not "q" — one level deep only
}

test "TAG-143 debug: what does the runtime see?" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND($A $B)
        \\AND[(X<>Y<>)($R)
        \\R<$X$Y()>
        \\:
        \\   0,0[0]
        \\   0,1[0]
        \\   1,1[1]
        \\   1,0[0]
        \\]
    ;
    const net = try parser.parse(a, src);
    const def = net.definitions[0];

    std.debug.print("def '{s}'\n", .{def.name});
    for (def.sources) |s| std.debug.print("  source: '{s}'\n", .{s.name});
    for (def.destinations) |d| std.debug.print("  dest:   '{s}'\n", .{d.name});
    for (def.resolution) |st| std.debug.print("  resolution: {s}\n", .{@tagName(st)});
    for (def.contained) |c| std.debug.print("  contained: '{s}'\n", .{c.name});

    const test_rules = try runtime.rules.buildRules(a, def);
    var env = runtime.environment.Environment{ .allocator = a };
    defer env.deinit();
    for ([_][]const u8{ "X", "Y" }, [_][]const u8{ "1", "1" }) |port, tok| {
        try env.seed(port, tok);
        try env.seed(tok, tok);
    }
    const report = try runtime.rules.run(a, &env, def, test_rules);
    std.debug.print("complete: {}\n", .{report.complete});
    for ([_][]const u8{ "X", "Y", "R", "0", "1" }) |name| {
        std.debug.print("  {s}: {s}\n", .{ name, if (env.get(name) == .valid) "valid" else "null" });
    }
}

test "select: no matching table entry leaves dest stuck, not an error" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND($A $B)
        \\AND[(X<>Y<>)($R)
        \\R<$X$Y()>
        \\:
        \\   0,0[0]
        \\   1,1[1]
        \\]
    ;
    const net = try parser.parse(a, src);
    const def = net.definitions[0];
    const test_rules = try rules.buildRules(a, def);

    var env = runtime.environment.Environment{ .allocator = a };
    try env.seed("X", "1");
    try env.seed("Y", "0"); // no "1,0" entry
    const report = try runtime.rules.run(a, &env, def, test_rules);
    try std.testing.expect(!report.complete);
    try std.testing.expectEqual(@as(usize, 0), report.stuck[0].waiting_on.len);
}