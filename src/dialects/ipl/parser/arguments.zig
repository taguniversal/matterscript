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
