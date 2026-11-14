const std = @import("std");
const network = @import("../network.zig");
const core = @import("core.zig");
const arguments = @import("arguments.zig");

// ----------------------------------------------------------------
// Definition list parsers (corrected Fant order)
// ----------------------------------------------------------------
/// Shared helper for parsing symmetric source/destination lists
pub fn parseGroup(p: *core.Parser) anyerror!*const network.PlaceGroup {
    p.skipWhitespaceAndComments();

    var kind: network.PlaceGroupKind = .bundle;
    var close_delim: u8 = '>';

    if (p.peek() == '<') {
        kind = .bundle;
        close_delim = '>';
        p.pos += 1;
    } else if (p.peek() == '(') {
        // Bare parenthesized sub-group — parens are used the same
        // way <> wraps a bundle elsewhere in the grammar (e.g. a
        // second arg tacked directly onto an arbitration group:
        // "{{$a $b}}(next<>)").
        kind = .bundle;
        close_delim = ')';
        p.pos += 1;
    } else if (p.peek() == '[') {
        kind = .bundle;
        close_delim = ']';
        p.pos += 1;
    } else if (p.peek() == '{') {
        p.pos += 1;
        if (p.peek() == '{') {
            kind = .arbitration;
            close_delim = '}'; // Will consume the second '}' on loop exit
            p.pos += 1;
        } else {
            kind = .mutex;
            close_delim = '}';
        }
    } else {
        return error.InvalidGroupDelimiter;
    }
    // Range form: [X<> 0..64] (source) or [$X 0..64] (destination),
    // same for {...} and {{...}}. Opening bracket has been consumed
    // by the branch above; parseRangeGroup peeks for `$` or a name.
    if (try parseRangeGroup(p, kind, close_delim)) |range_group| {
        return range_group;
    }
    var places: std.ArrayListUnmanaged(network.Arg) = .empty;
    errdefer places.deinit(p.allocator); // <--- Add errdefer to cleanup on error

    while (true) {
        p.skipWhitespaceAndComments();
        const ch = p.peek() orelse return error.UnexpectedEof;

        if (ch == close_delim) {
            p.pos += 1;
            // Handle secondary closing brace for double-curly arbitration {{ ... }}
            if (kind == .arbitration) {
                p.skipWhitespaceAndComments();
                if (p.peek() == '}') {
                    p.pos += 1;
                } else {
                    return error.ExpectedClosingBrace;
                }
            }
            break;
        }

        const child_arg = try arguments.parseArg(p);
        try places.append(p.allocator, child_arg);

        p.skipWhitespaceAndComments();
        if (p.peek() == ',') {
            p.pos += 1;
        } else if (p.peek() == close_delim) {
            // Loop continue will consume close_delim and perform arbitration check
            continue;
        }
    }

    const group_ptr = try p.allocator.create(network.PlaceGroup);
    group_ptr.* = network.PlaceGroup{
        .kind = kind,
        .places = try places.toOwnedSlice(p.allocator),
    };

    return group_ptr;
}

/// Recognizes the bundle-range form inside a group: `NAME<> LO..HI`
/// (source) or `$NAME LO..HI` (destination), for any group kind. On
/// match, consumes through the closing bracket and returns a
/// `PlaceGroup` with `HI - LO + 1` members named `NAME<lo>` through
/// `NAME<hi>`, each carrying the source/destination decoration.
///
/// Returns null (restoring `p.pos`) if the pattern doesn't match, so
/// `parseGroup` falls through to the ordinary member-parsing loop.
/// The non-matching cases include the existing per-member form
/// (`[A0<> A1<>]`), which has no `..` after a name.
fn parseRangeGroup(
    p: *core.Parser,
    kind: network.PlaceGroupKind,
    close_delim: u8,
) !?*const network.PlaceGroup {
    const save = p.pos;

    // Optional destination decoration: `$` before the name.
    var is_destination = false;
    if (p.peek() == '$') {
        is_destination = true;
        p.pos += 1;
    }
    p.skipWhitespaceAndComments();

    // Read the prefix name.
    const name_start = p.pos;
    const name = p.readName() catch {
        p.pos = save;
        return null;
    };
    if (name.len == 0) {
        p.pos = save;
        return null;
    }
    _ = name_start;

    // Optional source decoration: `<>` immediately after the name.
    // Only checked if we didn't see `$` (a place is either a source
    // or a destination, not both).
    var is_source = false;
    if (!is_destination) {
        const before_decoration = p.pos;
        p.skipWhitespaceAndComments();
        if (p.peek() == '<') {
            p.pos += 1;
            p.skipWhitespaceAndComments();
            if (p.peek() == '>') {
                p.pos += 1;
                is_source = true;
            } else {
                p.pos = before_decoration;
            }
        }
    }

    p.skipWhitespaceAndComments();

    // Range: LO .. HI
    const lo_start = p.pos;
    if (p.peek() == null or !std.ascii.isDigit(p.peek().?)) {
        p.pos = save;
        return null;
    }
    while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) p.pos += 1;
    const lo = std.fmt.parseInt(usize, p.src[lo_start..p.pos], 10) catch {
        p.pos = save;
        return null;
    };

    if (p.pos + 1 >= p.src.len or p.src[p.pos] != '.' or p.src[p.pos + 1] != '.') {
        p.pos = save;
        return null;
    }
    p.pos += 2;

    p.skipWhitespaceAndComments();

    const hi_start = p.pos;
    if (p.peek() == null or !std.ascii.isDigit(p.peek().?)) {
        p.pos = save;
        return null;
    }
    while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) p.pos += 1;
    const hi = std.fmt.parseInt(usize, p.src[hi_start..p.pos], 10) catch {
        p.pos = save;
        return null;
    };

    if (lo > hi) return error.InvalidRangeBounds;

    // Consume the closing bracket.
    p.skipWhitespaceAndComments();
    if (p.peek() != close_delim) {
        p.pos = save;
        return null;
    }
    p.pos += 1;
    if (kind == .arbitration) {
        p.skipWhitespaceAndComments();
        if (p.peek() != '}') {
            p.pos = save;
            return null;
        }
        p.pos += 1;
    }

    // Generate members: NAME<lo> through NAME<hi>.
    var places: std.ArrayListUnmanaged(network.Arg) = .empty;
    errdefer places.deinit(p.allocator);
    var i: usize = lo;
    while (i <= hi) : (i += 1) {
        const member_name = try std.fmt.allocPrint(p.allocator, "{s}{d}", .{ name, i });
        const text = if (is_destination)
            try std.fmt.allocPrint(p.allocator, "${s}", .{member_name})
        else if (is_source)
            try std.fmt.allocPrint(p.allocator, "{s}<>", .{member_name})
        else
            member_name;

        try places.append(p.allocator, .{
            .kind = .place,
            .name = member_name,
            .text = text,
            .direction = if (is_destination) .destination
                 else if (is_source) .source
                 else null,
        });
    }

    const group_ptr = try p.allocator.create(network.PlaceGroup);
    group_ptr.* = .{
        .kind = kind,
        .places = try places.toOwnedSlice(p.allocator),
    };
    return group_ptr;
}

/// Consume a balanced-delimiter span starting at the current
/// position, returning the full text including both delimiters.
/// Used for brace groups ({...} — mutex/conditional completeness,
/// §12.5.2/12.5.3) and bundle brackets ([...] — bundling/
/// unbundling, §12.6). Each call only tracks its own delimiter's
/// depth, so the two kinds nest inside each other transparently —
/// a "[" span just copies through any "{"/"}" it encounters as
/// inert content, and vice versa.
pub fn consumeBalanced(p: *core.Parser, open: u8, close: u8) ![]const u8 {
    const start = p.pos;
    _ = p.advance();
    var depth: usize = 1;
    while (depth > 0) {
        const ch = p.advance() orelse return core.ParseError.UnexpectedEnd;
        if (ch == open) depth += 1;
        if (ch == close) depth -= 1;
    }
    return p.src[start..p.pos];
}


/// Reads a name that may be split into comma-separated segments
/// (§12.4 — the comma is a general, freely-insertable separator).
/// Used for contained-definition names formed by composition,
/// where a segment boundary would otherwise be ambiguous (e.g.
/// "0,S0" rather than the unsplittable "0S0"). Returns the
/// segments joined with a single comma, e.g. "0,S0" — downstream
/// consumers should split on ',' and trim each segment, to
/// tolerate incidental whitespace like "0, S0".
pub fn readCommaSeparatedName(p: *core.Parser) ![]const u8 {
    const start = p.pos;
    _ = try p.readName();
    p.extendMemberAccess();

    while (true) {
        const save = p.pos;
        p.skipWhitespaceAndComments();

        if (p.peek() != ',') {
            p.pos = save;
            break;
        }

        _ = p.advance(); // Consume ','
        p.skipWhitespaceAndComments();

        _ = p.readName() catch {
            p.pos = save;
            break;
        };
        p.extendMemberAccess();
    }

    return p.src[start..p.pos];
}
