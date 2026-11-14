const std = @import("std");
const core = @import("core.zig");
const network: type = @import("../network.zig");
const groups = @import("groups.zig");

pub fn parseArg(p: *core.Parser) anyerror!network.Arg {
    p.skipWhitespaceAndComments();
    const start_pos = p.pos;
    const ch = p.peek() orelse return error.UnexpectedEof;

    // 1. Check if argument begins with a group selector ({, [, or standalone parentheses)
    if (ch == '{' or ch == '(' or ch == '[') {
        const grp = try groups.parseGroup(p);
        return network.Arg{
            .kind = .group,
            .group = grp,
            .text = p.src[start_pos..p.pos],
        };
    }

    // 2. Check for '$' prefix (destination places / expressions prefixed with $)
    if (ch == '$') {
        p.pos += 1; // consume '$'
        const name_start = p.pos;
        _ = try p.readName();
        p.extendMemberAccess();
        const name = p.src[name_start..p.pos];
        return network.Arg{
            .kind = .place,
            .name = name,
            .text = p.src[start_pos..p.pos],
            .direction = .destination,
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
                .direction = .source,
            };
        }
        // Non-empty bare <...>: restore to the '<' itself and let
        // parseGroup parse it properly (it wasn't actually attempted
        // here before — this branch used to fall through with no
        // group parsed at all, then fail in readName below).
        p.pos = lt_pos;
        const grp = try groups.parseGroup(p);
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
    const name_start = p.pos;
    _ = try p.readName();
    p.extendMemberAccess();
    const name = p.src[name_start..p.pos];
    p.skipWhitespaceAndComments();

    // A name immediately followed by '(' is a call/function expression
    if (p.peek() == '(') {
        _ = try groups.consumeBalanced(p, '(', ')');
        return network.Arg{
            .kind = .expression,
            .name = name,
            .text = p.src[start_pos..p.pos],
        };
    }

    // 5. Postfix '<' — source-place decorator. Two forms:
//    name<>        source place with no initial content
//    name<token>   source place with initial content (token is any
//                  single readName-able sequence, same grammar as
//                  insert-content elsewhere)
// There is no group interpretation of name<...> — groups have their
// own delimiters and never appear immediately after a bare name.
if (p.peek() == '<') {
    p.pos += 1; // consume '<'
    p.skipWhitespaceAndComments();

    if (p.peek() == '>') {
        // Empty <>: source place, no content.
        p.pos += 1;
        return network.Arg{
            .kind = .place,
            .name = name,
            .text = p.src[start_pos..p.pos],
            .direction = .source,
        };
    }

    // Non-empty <token>: source place with initial content.
    const content = p.readName() catch {
        return core.ParseError.ExpectedName;
    };
    p.skipWhitespaceAndComments();
    try p.expect('>');
    return network.Arg{
        .kind = .place,
        .name = name,
        .text = p.src[start_pos..p.pos],
        .direction = .source,
        .content = content,
    };
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
