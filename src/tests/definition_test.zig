const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const parser = matterscript.ipl_parser;

test "a comma-separated contained-row key parses as a composed key, not fresh source names" {
    // Historical note: this test used to call parseTruthTableRow
    // directly, asserting that "S,U,W" became three source-place Args
    // and "SUM<S> CO<W>" became two destination Args. That was
    // establishing the wrong shape — S, U, W carry no $ or <>
    // designators, so there's nothing marking them as source or
    // destination declarations; they're tokens in a composed lookup
    // key, exactly like "0,0" in "0,0[0]". parseTruthTableRow has
    // been removed: parseContainedSection now routes every
    // contained-row header (comma-separated or not) through the same
    // parseDefinition path, so "S,U,W[SUM<S> CO<W>]" is just an
    // ordinary Definition whose name is the composed key and whose
    // resolution holds fills against the ENCLOSING definition's own
    // destinations (SUM, CO) — not sources/destinations of its own.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source = "S,U,W[SUM<S> CO<W>]";
    var p = parser.core.Parser.init(allocator, source);

    const def = try parser.definitions.parseDefinition(&p);

    try testing.expectEqualStrings("S,U,W", def.name);
    try testing.expectEqual(@as(usize, 0), def.sources.len);
    try testing.expectEqual(@as(usize, 0), def.destinations.len);

    try testing.expectEqual(@as(usize, 2), def.resolution.len);
    try testing.expectEqualStrings("SUM", def.resolution[0].fill.dest_name);
    try testing.expectEqualStrings("S", def.resolution[0].fill.expr);
    try testing.expectEqualStrings("CO", def.resolution[1].fill.dest_name);
    try testing.expectEqualStrings("W", def.resolution[1].fill.expr);

    try testing.expectEqual(@as(usize, 0), def.constants.len);
    try testing.expectEqual(@as(usize, 0), def.contained.len);
}