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

    // 1. Parse source into AST
    const network = try parser.parse(a, source);
    const def = network.definitions[0];

    // 2. Build ExecutableRules via runtime.rules
    const rules = try runtime.rules.buildRules(a, def);

    // 3 rules now, not 2: buildRules always asserts a joint match's own
    // target as a real place (rules[0]: inputs=[ha,hb,oa] -> RXN), plus
    // one rule per fill-shaped contained child matching that target
    // (RXN -> WATER via w1, RXN -> WATER via w2).
    try testing.expectEqual(@as(usize, 3), rules.len);
    try testing.expectEqual(@as(usize, 3), rules[0].inputs.len);

    var bag = runtime.bag.Bag{ .allocator = a };
    defer bag.deinit();
    try bag.add("ha");
    try bag.add("hb");

    try runtime.bag.shake(&bag, rules);
    try testing.expectEqual(@as(usize, 0), bag.outputCount("WATER"));

    try bag.add("oa");
    try runtime.bag.shake(&bag, rules);
    // ha,hb,oa -> RXN fires once (one reaction event), and RXN -> WATER
    // fires via both w1 and w2 off that single RXN token — 2 water
    // molecules from one reaction, not 3.
    try testing.expectEqual(@as(usize, 2), bag.outputCount("WATER"));
}
