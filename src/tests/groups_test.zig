const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const groups = matterscript.groups;
const network = matterscript.network;
const core = matterscript.core;

// Helper to clean up allocated PlaceGroup structures recursively
fn freePlaceGroup(allocator: std.mem.Allocator, group: *const network.PlaceGroup) void {
    allocator.free(group.places);
    allocator.destroy(group);
}

// ----------------------------------------------------------------
// parseGroup Tests
// ----------------------------------------------------------------

test "parseGroup - bundle delimiters < >, ( ), [ ]" {
    const allocator = testing.allocator;

    const test_cases = [_]struct {
        src: []const u8,
        expected_places_len: usize,
    }{
        .{ .src = "<$a, $b>", .expected_places_len = 2 },
        .{ .src = "($a $b)", .expected_places_len = 2 },
        .{ .src = "[$a, $b, $c]", .expected_places_len = 3 },
    };

    for (test_cases) |tc| {
        var p = core.Parser.init(allocator, tc.src);
        const group = try groups.parseGroup(&p);
        defer freePlaceGroup(allocator, group);

        try testing.expectEqual(network.PlaceGroupKind.bundle, group.kind);
        try testing.expectEqual(tc.expected_places_len, group.places.len);
    }
}

test "parseGroup - mutex delimiter { }" {
    const allocator = testing.allocator;
    const src = "{$a, $b}";

    var p = core.Parser.init(allocator, src);
    const group = try groups.parseGroup(&p);
    defer freePlaceGroup(allocator, group);

    try testing.expectEqual(network.PlaceGroupKind.mutex, group.kind);
    try testing.expectEqual(@as(usize, 2), group.places.len);
}

test "parseGroup - arbitration delimiter {{ }}" {
    const allocator = testing.allocator;
    const src = "{{$a $b}}";

    var p = core.Parser.init(allocator, src);
    const group = try groups.parseGroup(&p);
    defer freePlaceGroup(allocator, group);

    try testing.expectEqual(network.PlaceGroupKind.arbitration, group.kind);
    try testing.expectEqual(@as(usize, 2), group.places.len);
}

test "parseGroup - error handling" {
    const allocator = testing.allocator;

    // Invalid opening delimiter
    {
        var p = core.Parser.init(allocator, "invalid_start");
        try testing.expectError(error.InvalidGroupDelimiter, groups.parseGroup(&p));
    }

    // Arbitration missing second closing brace
    {
        var p = core.Parser.init(allocator, "{{$a $b}");
        try testing.expectError(error.ExpectedClosingBrace, groups.parseGroup(&p));
    }

    // Unexpected EOF before closing delimiter
    {
        var p = core.Parser.init(allocator, "<$a $b");
        try testing.expectError(error.UnexpectedEof, groups.parseGroup(&p));
    }
}

// ----------------------------------------------------------------
// consumeBalanced Tests
// ----------------------------------------------------------------

test "consumeBalanced - simple and nested spans" {
    const allocator = testing.allocator;

    // Simple braces
    {
        const src = "{ simple content } trailing";
        var p = core.Parser.init(allocator, src);
        const res = try groups.consumeBalanced(&p, '{', '}');
        try testing.expectEqualStrings("{ simple content }", res);
        try testing.expectEqualStrings(" trailing", p.src[p.pos..]);
    }

    // Nested depth
    {
        const src = "[[a, b], [c, [d]]] tail";
        var p = core.Parser.init(allocator, src);
        const res = try groups.consumeBalanced(&p, '[', ']');
        try testing.expectEqualStrings("[[a, b], [c, [d]]]", res);
    }
}

test "consumeBalanced - transparently handles inner different delimiters" {
    const allocator = testing.allocator;
    const src = "[foo {bar, baz} qux] extra";

    var p = core.Parser.init(allocator, src);
    const res = try groups.consumeBalanced(&p, '[', ']');
    try testing.expectEqualStrings("[foo {bar, baz} qux]", res);
}

test "consumeBalanced - unexpected end error" {
    const allocator = testing.allocator;
    const src = "{ unclosed brace";

    var p = core.Parser.init(allocator, src);
    try testing.expectError(core.ParseError.UnexpectedEnd, groups.consumeBalanced(&p, '{', '}'));
}

// ----------------------------------------------------------------
// readCommaSeparatedName Tests
// ----------------------------------------------------------------

test "readCommaSeparatedName - single vs comma-separated segments" {
    const allocator = testing.allocator;

    // Single name segment
    {
        const src = "segment1 next_token";
        var p = core.Parser.init(allocator, src);
        const res = try groups.readCommaSeparatedName(&p);
        try testing.expectEqualStrings("segment1", res);
    }

    // Comma separated with mixed whitespace
    {
        const src = "0, S0,S1  rest_of_code";
        var p = core.Parser.init(allocator, src);
        const res = try groups.readCommaSeparatedName(&p);
        try testing.expectEqualStrings("0, S0,S1", res);
    }
}

test "readCommaSeparatedName - trailing comma safely restores parser position" {
    const allocator = testing.allocator;
    const src = "valid_name, )"; // ')' cannot be part of a name, causing readName() to fail

    var p = core.Parser.init(allocator, src);
    const res = try groups.readCommaSeparatedName(&p);

    try testing.expectEqualStrings("valid_name", res);
    try testing.expectEqualStrings(", )", p.src[p.pos..]);
}