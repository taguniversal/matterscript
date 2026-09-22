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

    // Two contained definitions both named "RXN" (RXN[WATER<w1>],
    // RXN[WATER<w2>]) each get matched against h1,h2,o1[RXN]'s target —
    // buildRules produces one ExecutableRule per fill, so 2 rules here,
    // not 1.
    try testing.expectEqual(@as(usize, 2), rules.len);
    try testing.expectEqual(@as(usize, 3), rules[0].inputs.len);

    var bag = runtime.bag.Bag{ .allocator = a };
    defer bag.deinit();
    try bag.add("ha");
    try bag.add("hb");

    try runtime.bag.shake(&bag, rules);
    try testing.expectEqual(@as(usize, 0), bag.outputCount("WATER"));

    try bag.add("oa");
    try runtime.bag.shake(&bag, rules);
    try testing.expectEqual(@as(usize, 2), bag.outputCount("WATER"));
}
