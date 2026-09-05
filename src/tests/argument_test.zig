const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const parser = matterscript.ipl_parser;
const network = matterscript.network;

test "readNumericLiteral parsing and errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 1. Test valid integers and decimals (positive and negative)
    {
        var p = parser.core.Parser.init(allocator, "-123.456 remainder");
        const lit = try parser.arguments.readNumericLiteral(&p);
        try testing.expectEqualStrings("-123.456", lit);
        try testing.expectEqual(@as(usize, 8), p.pos); // consumed up to the space
    }

    {
        var p = parser.core.Parser.init(allocator, "42");
        const lit = try parser.arguments.readNumericLiteral(&p);
        try testing.expectEqualStrings("42", lit);
    }

    // 2. Test integer with trailing decimal point
    {
        var p = parser.core.Parser.init(allocator, "3.abc");
        const lit = try parser.arguments.readNumericLiteral(&p);
        try testing.expectEqualStrings("3.", lit);
    }

    // 3. Test failure case: non-numeric string returns ExpectedName error
    {
        var p = parser.core.Parser.init(allocator, "not_a_number");
        try testing.expectError(parser.core.ParseError.ExpectedName, parser.arguments.readNumericLiteral(&p));
    }
}

test "parseArgList parses mixed argument lists" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Test list with commas and whitespace separation enclosed in parentheses
    var p = parser.core.Parser.init(allocator, "(a, $b, 42)");
    const args = try parser.arguments.parseArgList(&p, ')');

    try testing.expectEqual(@as(usize, 3), args.len);

    // First argument: literal "a"
    try testing.expectEqual(.literal, args[0].kind);
    try testing.expectEqualStrings("a", args[0].name);

    // Second argument: variable "$b"
    try testing.expectEqual(.expression, args[1].kind);
    try testing.expectEqualStrings("b", args[1].name);

    // Third argument: literal "42"
    try testing.expectEqual(.literal, args[2].kind);
    try testing.expectEqualStrings("42", args[2].text);
}

test "parseArg handles places, expressions, and group modifiers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 1. Test standard place identifier
    {
        var p = parser.core.Parser.init(allocator, "my_string");
        const arg = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.literal, arg.kind);
        try testing.expectEqualStrings("my_string", arg.name);
    }

    // 2. Test function expression (name followed by balanced parentheses)
    {
        var p = parser.core.Parser.init(allocator, "face(loop($p0))");
        const arg = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.expression, arg.kind);
        try testing.expectEqualStrings("face", arg.name);
        try testing.expectEqualStrings("face(loop($p0))", arg.text);
    }

    // Test separate sequence: a standard argument followed by a group argument
    {
        var p = parser.core.Parser.init(allocator, "signal_a [sub1, sub2]");

        // First argument is the literal/place name
        const arg1 = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.literal, arg1.kind); // or whatever enum variant you use for plain names
        try testing.expectEqualStrings("signal_a", arg1.name);

        p.skipWhitespaceAndComments();

        // Second argument is the group
        const arg2 = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.group, arg2.kind);
        try testing.expectEqual(network.PlaceGroupKind.bundle, arg2.group.?.kind);
    }

    // 5. Test place with an attached arbitration group modifier (e.g., 'signal_c{{sub1, sub2}}')
    {
        var p = parser.core.Parser.init(allocator, "signal_c {{sub1, sub2}}");
        const arg = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.literal, arg.kind);
        try testing.expectEqualStrings("signal_c", arg.name);

        p.skipWhitespaceAndComments();
        // Second argument is the group
        const arg2 = try parser.arguments.parseArg(&p);
        try testing.expectEqual(.group, arg2.kind);
        try testing.expectEqual(network.PlaceGroupKind.arbitration, arg2.group.?.kind);
    }
}
