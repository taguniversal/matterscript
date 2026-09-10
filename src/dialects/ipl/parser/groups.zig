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
        // Bundle-brackets (§12.6) — same semantics as <>, matching
        // the mapping already used by parseArgSequence.
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

    var places: std.ArrayListUnmanaged(network.Arg) = .empty;

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

/// Definition first list: (name<> ...) — source places, tokens flow IN
fn parseDefSourceList() ![]const network.Arg {
    return arguments.parseArgList(')');
}

/// Definition second list: ($name ...) — destination places, tokens flow OUT
fn parseDefDestinationList() ![]const network.Arg {
    return arguments.parseArgList(')');
}

/// Invocation second list: (name<> ...) — outputs returned to caller
fn parseInvOutputList() ![]const network.Place {
    return arguments.parsePlaceList(')');
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
    while (true) {
        const save = p.pos;
        p.skipWhitespaceAndComments();
        if (p.peek() != ',') {
            p.pos = save;
            break;
        }
        _ = p.advance(); // consume ','
        p.skipWhitespaceAndComments();
        _ = p.readName() catch {
            p.pos = save;
            break;
        };
    }
    return p.src[start..p.pos];
}
