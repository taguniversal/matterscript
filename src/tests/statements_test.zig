const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const core = matterscript.core;
const network = matterscript.network;
const statements = matterscript.statements;

// Helper to construct a parser pre-loaded with source text
fn initParser(allocator: std.mem.Allocator, src: []const u8) core.Parser {
    return core.Parser.init(allocator, src);
}

// ----------------------------------------------------------------
// parseSourceFill Tests
// ----------------------------------------------------------------
test "parseSourceFill - valid source fill statement" {
    const allocator = testing.allocator;
    const src = "<$a>";
    var p = initParser(allocator, src);

    const stmt = try statements.parseSourceFill(&p, "dest_var");

    try testing.expectEqual(std.meta.Tag(network.Statement).fill, std.meta.activeTag(stmt));
    try testing.expectEqualStrings("dest_var", stmt.fill.dest_name);
    try testing.expectEqualStrings("", p.src[p.pos..]);
}

test "parseSourceFill - missing closing bracket" {
    const allocator = testing.allocator;
    const src = "<$a";
    var p = initParser(allocator, src);

    try testing.expectError(error.ExpectedToken, statements.parseSourceFill(&p, "dest_var"));
}

// ----------------------------------------------------------------
// parseInvocation Tests
// ----------------------------------------------------------------

test "parseInvocation - unlabeled without destinations produces pure_value" {
    const allocator = testing.allocator;
    const src = "LT($a, $b)";
    var p = initParser(allocator, src);

    const name = try p.readName(); // consumes "LT"
    const stmt = try statements.parseInvocation(&p, null, name);

    try testing.expectEqual(std.meta.Tag(network.Statement).pure_value, std.meta.activeTag(stmt));
    try testing.expectEqualStrings("LT($a, $b)", stmt.pure_value);
}

test "parseInvocation - labeled without destinations stays invoke" {
    const allocator = testing.allocator;
    const src = "AND($a, $b)";
    var p = initParser(allocator, src);

    const name = try p.readName();
    const stmt = try statements.parseInvocation(&p, "U1", name);
    defer allocator.free(stmt.invoke.sources);
    defer allocator.free(stmt.invoke.destinations);

    try testing.expectEqual(std.meta.Tag(network.Statement).invoke, std.meta.activeTag(stmt));
    try testing.expectEqualStrings("AND", stmt.invoke.name);
    try testing.expectEqualStrings("U1", stmt.invoke.label.?);
    try testing.expectEqual(@as(usize, 2), stmt.invoke.sources.len);
    try testing.expectEqual(@as(usize, 0), stmt.invoke.destinations.len);
}

test "parseInvocation - full invocation with sources and destinations" {
    const allocator = testing.allocator;
    const src = "ADD($a, $b)($sum, $carry)";
    var p = initParser(allocator, src);

    const name = try p.readName();
    const stmt = try statements.parseInvocation(&p, "U2", name);
    defer allocator.free(stmt.invoke.sources);
    defer allocator.free(stmt.invoke.destinations);

    try testing.expectEqual(std.meta.Tag(network.Statement).invoke, std.meta.activeTag(stmt));
    try testing.expectEqualStrings("ADD", stmt.invoke.name);
    try testing.expectEqualStrings("U2", stmt.invoke.label.?);
    try testing.expectEqual(@as(usize, 2), stmt.invoke.sources.len);
    try testing.expectEqual(@as(usize, 2), stmt.invoke.destinations.len);
}

test "parseInvocation - invocation with no source list" {
    const allocator = testing.allocator;
    const src = "()($out)"; // Explicit empty source list, followed by destination list
    var p = initParser(allocator, src);

    const stmt = try statements.parseInvocation(&p, "U3", "GEN");
    defer allocator.free(stmt.invoke.sources);
    defer allocator.free(stmt.invoke.destinations);

    try testing.expectEqual(std.meta.Tag(network.Statement).invoke, std.meta.activeTag(stmt));
    try testing.expectEqualStrings("GEN", stmt.invoke.name);
    try testing.expectEqual(@as(usize, 0), stmt.invoke.sources.len);
    try testing.expectEqual(@as(usize, 1), stmt.invoke.destinations.len);
}

test "parseEntryInvocation - explicit sources and destinations" {
    const allocator = testing.allocator;
    const src = "($a, $b)(out<>)";
    var p = initParser(allocator, src);

    const entry = try statements.parseEntryInvocation(&p, "E1", "MyEntry");
    defer allocator.free(entry.sources);
    defer allocator.free(entry.destinations);

    try testing.expectEqualStrings("MyEntry", entry.name);
    try testing.expectEqualStrings("E1", entry.label.?);
    try testing.expectEqual(@as(usize, 2), entry.sources.len);
    try testing.expectEqual(@as(usize, 1), entry.destinations.len);
}

test "parseEntryInvocation - omitted destinations defaults to empty list" {
    const allocator = testing.allocator;
    const src = "($a, $b)";
    var p = initParser(allocator, src);

    const entry = try statements.parseEntryInvocation(&p, null, "MyEntry");
    defer allocator.free(entry.sources);
    defer allocator.free(entry.destinations);

    try testing.expect(entry.label == null);
    try testing.expectEqualStrings("MyEntry", entry.name);
    try testing.expectEqual(@as(usize, 2), entry.sources.len);
    try testing.expectEqual(@as(usize, 0), entry.destinations.len);
}