// Linear: TAG-201
const std = @import("std");
const testing = std.testing;

// Import parser and runtime engine modules
const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const runtime = matterscript.runtime;

test "combustion stoichiometry via multi-token matching" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const source =
        \\// Combustion reaction: 2H2 + O2 -> 2H2O
        \\REACTION[(H2<> O2<>)($WATER)
        \\    @runtime(consumable)
        \\    $H2 $O2 :
        \\
        \\  // Rule: Fire reaction only when two H2 tokens and one O2 token collide
        \\  ha,hb,oa[RXN]
        \\
        \\  // Products: Transition state resolves into two water molecules
        \\  RXN[WATER<w1>]
        \\  RXN[WATER<w2>]
        \\]
    ;

    const network = try parser.parse(a, source);
    const def = network.definitions[0];

    const rules = try runtime.rules.buildRules(a, def);
    try testing.expectEqual(@as(usize, 3), rules.len);
    try testing.expectEqual(@as(usize, 3), rules[0].inputs.len);

    const result = try runtime.dispatch.run(a, def, .{ .consumable = &.{
        &.{ "ha", "hb" },
        &.{"oa"},
    } });

    try testing.expectEqual(@as(usize, 2), result.consumable.len);

    const after_ha_hb = result.consumable[0].outputs.get("WATER") orelse 0;
    try testing.expectEqual(@as(usize, 0), after_ha_hb);

    const after_oa = result.consumable[1].outputs.get("WATER") orelse 0;
    try testing.expectEqual(@as(usize, 2), after_oa);
}
