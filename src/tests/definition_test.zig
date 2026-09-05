const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const parser = matterscript.ipl_parser;

test "parseTruthTableRow parses shorthand truth-table rows correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 1. Initialize the Parser with the source string
    const source = "S,U,W[SUM<S>, CO<W>]";
    var p = parser.core.Parser.init(allocator, source);
    
    // 2. Pass the parser pointer to parseTruthTableRow
    const def = parser.definitions.parseTruthTableRow(&p) catch |err| {
        std.debug.print("Error parsing truth table row: {}\n", .{err});
        return err;
    };

    // 3. Verify definition name is empty for anonymous truth table rows
    try testing.expectEqualStrings("", def.name);

    // 4. Verify sources (S, U, W)
    try testing.expectEqual(@as(usize, 3), def.sources.len);
    try testing.expectEqualStrings("S", def.sources[0].name);
    try testing.expectEqualStrings("U", def.sources[1].name);
    try testing.expectEqualStrings("W", def.sources[2].name);
    try testing.expectEqual(.place, def.sources[0].kind);

    // 5. Verify destinations (SUM<S> and CO<W>)
    try testing.expectEqual(@as(usize, 2), def.destinations.len);

    // First destination: SUM<S>
    std.debug.print("SUM: {s}\n", .{def.destinations[0].name});
    try testing.expectEqualStrings("SUM", def.destinations[0].name);
    try testing.expectEqual(.group, def.destinations[0].kind);

    // Second destination: CO<W>
    try testing.expectEqualStrings("CO", def.destinations[1].name);
    try testing.expectEqual(.group, def.destinations[1].kind);

    // 6. Verify structural fields default to empty
    try testing.expectEqual(@as(usize, 0), def.resolution.len);
    try testing.expectEqual(@as(usize, 0), def.constants.len);
    try testing.expectEqual(@as(usize, 0), def.contained.len);
}
