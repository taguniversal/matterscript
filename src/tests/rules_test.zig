const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const Environment = matterscript.runtime.environment.Environment;
const network = matterscript.network;
const rules = matterscript.runtime.rules;

test "resolveArbitrations: winner consumed, loser persists" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = Environment{ .allocator = allocator };
    try env.assertSymbol("place1", "K");
    try env.assertSymbol("place2", "L");

    const arb = network.Binding{
        .callee = "placeB",
        .caller = "arbiter0_placeB",
        .members = &.{ "place1", "place2" },
    };
    const arbitrations = [_]network.Binding{arb};
    try rules.resolveArbitrations(&env, &arbitrations);

    // Winner consumed, value propagated.
    try testing.expectEqual(.null_value, env.get("place1"));
    try testing.expect(env.isValid("arbiter0_placeB"));
    try testing.expectEqualStrings("K", env.symbols.items[env.get("arbiter0_placeB").valid]);

    // Loser persists.
    try testing.expect(env.isValid("place2"));
}

test "resolveArbitrations: sequential calls pick successive winners" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var env = Environment{ .allocator = allocator };
    try env.assertSymbol("place1", "K");
    try env.assertSymbol("place2", "L");

    const arbitrations = [_]network.Binding{.{
        .callee = "placeB",
        .caller = "arbiter0_placeB",
        .members = &.{ "place1", "place2" },
    }};

    // First arbitration: place1 wins (first in order).
    try rules.resolveArbitrations(&env, &arbitrations);
    try testing.expectEqual(.null_value, env.get("place1"));
    try testing.expect(env.isValid("place2"));

    // Clear the virtual wire to simulate the caller consuming it.
    try env.invalidate("arbiter0_placeB");

    // Second arbitration: place1 is empty, place2 wins.
    try rules.resolveArbitrations(&env, &arbitrations);
    try testing.expectEqual(.null_value, env.get("place2"));
    try testing.expect(env.isValid("arbiter0_placeB"));
}