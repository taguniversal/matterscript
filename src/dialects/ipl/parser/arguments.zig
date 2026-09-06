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

    // 1. Check if argument begins with a group selector ({, [, or standalone parentheses)
    if (ch == '{' or ch == '(' or ch == '[') {
        const grp = try p.parseGroup();
        return network.Arg{
            .kind = .group,
            .group = grp,
            .text = p.src[start_pos..p.pos],
        };
    }

    // 2. Check for '$' prefix (destination places / expressions prefixed with $)
    if (ch == '$') {
        p.pos += 1; // consume '$'
        const name = try p.readName();
        return network.Arg{
            // A bare $name is a boundary place reference (Fant's
            // destination syntax, "$SUM"), not a computed expression —
            // writeBoundaryPorts/boundaryCount in export_vhdl.zig only
            // treat .place (and .group) as real ports, so classifying
            // this as .expression made it silently vanish from the
            // emitted port list while still being counted toward the
            // total, throwing off the "is this the last port" check
            // and producing an illegal trailing ';' in every entity
            // that uses a $name destination — i.e. nearly all of them.
            .kind = .place,
            .name = name,
            .text = p.src[start_pos..p.pos],
        };
    }

    // Handle bare source brackets like '<>' or '< >'
    if (ch == '<') {
        const lt_pos = p.pos;
        p.pos += 1; // consume '<'
        p.skipWhitespaceAndComments();
        if (p.peek() == '>') {
            p.pos += 1; // consume '>'
            return network.Arg{
                .kind = .place,
                .name = "", // Unnamed source
                .text = p.src[start_pos..p.pos],
            };
        }
        // Non-empty bare <...>: restore to the '<' itself and let
        // parseGroup parse it properly (it wasn't actually attempted
        // here before — this branch used to fall through with no
        // group parsed at all, then fail in readName below).
        p.pos = lt_pos;
        const grp = try p.parseGroup();
        return network.Arg{
            .kind = .group,
            .group = grp,
            .text = p.src[start_pos..p.pos],
        };
    }

    // 3. Check for numeric literals (delegating directly to readNumericLiteral which handles signs/digits)
    if (ch == '-' or std.ascii.isDigit(ch)) {
        const lit = try readNumericLiteral(p);
        return network.Arg{
            .kind = .literal,
            .text = lit,
        };
    }

    // 4. Standard identifier (place, function expression, or place with postfix <>)
    const name = try p.readName();
    p.skipWhitespaceAndComments();

    // A name immediately followed by '(' is a call/function expression
    if (p.peek() == '(') {
        _ = try p.consumeBalanced('(', ')');
        return network.Arg{
            .kind = .expression,
            .name = name,
            .text = p.src[start_pos..p.pos],
        };
    }

    // 5. Check for postfix '<>' or '< >' indicating source places / group modifiers
    if (p.peek() == '<') {
        const lt_pos = p.pos;
        p.pos += 1; // consume '<'
        p.skipWhitespaceAndComments();
        if (p.peek() == '>') {
            p.pos += 1;
            return network.Arg{
                .kind = .place, // or source place classification
                .name = name,
                .text = p.src[start_pos..p.pos],
            };
        } else {
            // If it's a generic group modifier like <sub1, sub2>
            p.pos = lt_pos; // restore to '<' for generic group parsing
            const grp = try p.parseGroup();
            return network.Arg{
                .kind = .group,
                .name = name,
                .text = p.src[start_pos..p.pos],
                .group = grp,
            };
        }
    }

    // 6. Default standard literal
    return network.Arg{
        .kind = .literal,
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

pub fn readNumericLiteral(p: *core.Parser) ![]const u8 {
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