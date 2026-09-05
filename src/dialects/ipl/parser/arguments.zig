const std = @import("std");
const core = @import("core.zig");
const network: type = @import("../network.zig");

/// Parses a sequence of arguments/places until `close_char` is encountered.
fn parseArgSequence(p: *core.Parser, close_char: u8) ![]const network.Arg {
    var args: std.ArrayListUnmanaged(network.Arg) = .empty;
    p.skipWhitespaceAndComments();

    while (p.peek() != close_char and p.peek() != null) {
        p.skipWhitespaceAndComments();
        const c = p.peek().?;

        if (c == '{' or c == '[') {
            const is_arb = (c == '{' and p.pos + 1 < p.src.len and p.src[p.pos + 1] == '{');

            if (is_arb) {
                _ = p.advance();
                _ = p.advance();
                const nested = try p.parseArgSequence('}');
                try p.expect('}');
                try p.expect('}');

                const group = try p.allocator.create(network.PlaceGroup);
                group.* = .{ .kind = .arbitration, .places = nested };
                try args.append(p.allocator, .{ .kind = .group, .group = group });
            } else {
                const closing: u8 = if (c == '{') '}' else ']';
                const group_kind: network.PlaceGroupKind = if (c == '{') .mutex else .bundle;
                _ = p.advance();

                const nested = try p.parseArgSequence(closing);
                try p.expect(closing);

                const group = try p.allocator.create(network.PlaceGroup);
                group.* = .{ .kind = group_kind, .places = nested };
                try args.append(p.allocator, .{ .kind = .group, .group = group });
            }
        } else if (c == '$') {
            const expr = try p.parseILExpr();
            try args.append(p.allocator, .{ .kind = .expression, .text = expr });
        } else if (std.ascii.isDigit(c) or c == '-') {
            const lit = try p.readNumericLiteral();
            try args.append(p.allocator, .{ .kind = .literal, .text = lit });
        } else {
            const name = try p.readName();
            try args.append(p.allocator, .{ .kind = .place, .name = name });
        }

        p.skipWhitespaceAndComments();
        _ = p.tryConsume(',');
        p.skipWhitespaceAndComments();
    }

    return args.toOwnedSlice(p.allocator);
}

pub fn parseArg(p: *core.Parser) anyerror!network.Arg {
    p.skipWhitespaceAndComments();
    const start_pos = p.pos;
    const ch = p.peek() orelse return error.UnexpectedEof;

    // Check if argument begins directly with a group modifier
    // (<...>, {...}, {{...}}, [...], or a bare (...) sub-group)
    if (ch == '<' or ch == '{' or ch == '(' or ch == '[') {
        const grp = try p.parseGroup();
        return network.Arg{
            .kind = .group,
            .group = grp,
        };
    }

    // Standard place identifier
    const name = try p.readName();
    p.skipWhitespaceAndComments();

    // A name immediately followed by '(' is a call/function
    // expression (topology helpers like "face(loop(edge($p0,
    // $p1), ...)))"), not a place with an attached group modifier.
    // Capture it as raw text, same as $-composition expressions.
    if (p.peek() == '(') {
        _ = try p.consumeBalanced('(', ')');
        return network.Arg{
            .kind = .expression,
            .name = name,
            .text = p.src[start_pos..p.pos],
        };
    }

    // Check for attached place group modifier like 'a<>'
    if (p.peek()) |next_ch| {
        if (next_ch == '<' or next_ch == '{') {
            const grp = try p.parseGroup();
            return network.Arg{
                .kind = .group,
                .name = name,
                .text = p.src[start_pos..p.pos],
                .group = grp,
            };
        }
    }

    return network.Arg{
        .kind = .place,
        .name = name,
        .text = name,
    };
}

pub fn parseArgList(p: *core.Parser, close_delim: u8) anyerror![]const network.Arg {
    p.skipWhitespaceAndComments();
    if (p.peek() == '(') {
        p.pos += 1;
    }
    var list: std.ArrayListUnmanaged(network.Arg) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        if (p.peek() == close_delim) {
            p.pos += 1;
            break;
        }

        const arg = try parseArg(p);
        try list.append(p.allocator, arg);

        p.skipWhitespaceAndComments();
        if (p.peek() == ',') {
            p.pos += 1;
        } else if (p.peek() == close_delim) {
            p.pos += 1;
            break;
        }
        // If there is whitespace separating arguments (like '$select $input'),
        // we simply continue the loop instead of breaking or failing.
    }

    return list.toOwnedSlice(p.allocator);
}

fn readNumericLiteral(p: *core.Parser) ![]const u8 {
    const start = p.pos;
    if (p.peek() == '-') _ = p.advance();
    while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) p.pos += 1;
    if (p.peek() == '.') {
        _ = p.advance();
        while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) p.pos += 1;
    }
    if (p.pos == start) return core.ParseError.ExpectedName;
    return p.src[start..p.pos];
}

// Tests 
const testing = std.testing;


test "readNumericLiteral parsing and errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 1. Test valid integers and decimals (positive and negative)
    {
        var p = core.Parser.init(allocator, "-123.456 remainder");
        const lit = try readNumericLiteral(&p);
        try testing.expectEqualStrings("-123.456", lit);
        try testing.expectEqual(@as(usize, 8), p.pos); // consumed up to the space
    }

    {
        var p = core.Parser.init(allocator, "42");
        const lit = try readNumericLiteral(&p);
        try testing.expectEqualStrings("42", lit);
    }

    // 2. Test integer with trailing decimal point (stops before dot if no digits follow, or handles cleanly based on implementation)
    {
        var p = core.Parser.init(allocator, "3.abc");
        const lit = try readNumericLiteral(&p);
        try testing.expectEqualStrings("3.", lit);
    }

    // 3. Test failure case: non-numeric string returns ExpectedName error
    {
        var p = core.Parser.init(allocator, "not_a_number");
        try testing.expectError(core.ParseError.ExpectedName, readNumericLiteral(&p));
    }
}

test "parseArgList parses mixed argument lists" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Test list with commas and whitespace separation enclosed in parentheses
    var p = core.Parser.init(allocator, "(a, $b, 42)");
    const args = try parseArgList(&p, ')');

    try testing.expectEqual(@as(usize, 3), args.len);
    
    // First argument: place "a"
    try testing.expectEqual(.place, args[0].kind);
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
        var p = core.Parser.init(allocator, "my_place");
        const arg = try parseArg(&p);
        try testing.expectEqual(.place, arg.kind);
        try testing.expectEqualStrings("my_place", arg.name);
    }

    // 2. Test function expression (name followed by balanced parentheses)
    {
        var p = core.Parser.init(allocator, "face(loop($p0))");
        const arg = try parseArg(&p);
        try testing.expectEqual(.expression, arg.kind);
        try testing.expectEqualStrings("face", arg.name);
        try testing.expectEqualStrings("face(loop($p0))", arg.text);
    }

    // 3. Test place with an attached bundle group modifier (e.g., 'signal_a [...]')
    {
        var p = core.Parser.init(allocator, "signal_a [sub1, sub2]");
        const arg = try parseArg(&p);
        try testing.expectEqual(.group, arg.kind);
        try testing.expectEqualStrings("signal_a", arg.name);
        try testing.expectNotNil(arg.group);
        try testing.expectEqual(network.PlaceGroupKind.bundle, arg.group.?.kind);
    }

    // 4. Test place with an attached mutex group modifier (e.g., 'signal_b{sub1, sub2}')
    {
        var p = core.Parser.init(allocator, "signal_b {sub1, sub2}");
        const arg = try parseArg(&p);
        try testing.expectEqual(.group, arg.kind);
        try testing.expectEqualStrings("signal_b", arg.name);
        try testing.expectNotNil(arg.group);
        try testing.expectEqual(network.PlaceGroupKind.mutex, arg.group.?.kind);
    }

    // 5. Test place with an attached arbitration group modifier (e.g., 'signal_c{{sub1, sub2}}')
    {
        var p = core.Parser.init(allocator, "signal_c {{sub1, sub2}}");
        const arg = try parseArg(&p);
        try testing.expectEqual(.group, arg.kind);
        try testing.expectEqualStrings("signal_c", arg.name);
        try testing.expectNotNil(arg.group);
        try testing.expectEqual(network.PlaceGroupKind.arbitration, arg.group.?.kind);
    }
}

