// src/tests/parser_test.zig
const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");


// Import the module relative to this test file
const parser = matterscript.ipl_parser;
pub const network = matterscript.network;

test "parse 2D cellular automaton generate block and domain" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\ca2d[()()
        \\  @domain(spatial2d, size: [300, 500])
        \\  @generate {
        \\    [2, 1, 5]: 4
        \\    [3, 2, 4]: 6
        \\    [4, 4, 6]: 4
        \\  }
        \\  :
        \\]
    ;

    const net = try parser.parse(allocator, src);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);

    const def = net.definitions[0];

    // Access the newly assigned generateBlock field directly
    const gen = def.generateBlock.?;

    // Assert domain bounds (from gen.domain or def.domain_spec)
    if (gen.domain) |domain| {
        try testing.expectEqual(parser.network.SpatialDomainKind.spatial2d, domain.kind);
        try testing.expectEqual(@as(usize, 300), domain.size_x);
        try testing.expectEqual(@as(usize, 500), domain.size_y);
    } else {
        return error.MissingDomainSpec;
    }

    // Assert rules
    try testing.expectEqual(@as(usize, 3), gen.rules.len);
    try testing.expectEqualStrings("2", gen.rules[0].pattern[0]);
    try testing.expectEqualStrings("1", gen.rules[0].pattern[1]);
    try testing.expectEqualStrings("5", gen.rules[0].pattern[2]);
    try testing.expectEqualStrings("4", gen.rules[0].value);
}