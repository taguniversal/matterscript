const std = @import("std");
const network = @import("../network.zig");
const core = @import("core.zig");
const arguments = @import("arguments.zig");
const expressions = @import("expressions.zig");

// ----------------------------------------------------------------
// Statement Handlers
// ----------------------------------------------------------------

pub fn parseSourceFill(p: *core.Parser, name: []const u8) !network.Statement {
    _ = p.advance(); // consume '<'
    p.skipWhitespaceAndComments();

    // Invocation-fill form: `dest< InstName($arg1 $arg2 ...) >`. Peek
    // for an identifier followed by `(`; if found, parse as an
    // invocation with `name` as the destination. Otherwise fall
    // through to the ordinary source-fill path (place reference,
    // composed key, or simple expression).
    if (looksLikeInvocationFill(p)) {
        const save = p.pos;
        const maybe_name = p.readName() catch {
            p.pos = save;
            return parseSourceFillExpr(p, name);
        };
        p.skipWhitespaceAndComments();
        const inv = try parseInvocation(p, null, maybe_name, name);
        p.skipWhitespaceAndComments();
        try p.expect('>');
        return inv;
    }

    return parseSourceFillExpr(p, name);
}

/// The original body, factored out so both paths can fall back to it.
fn parseSourceFillExpr(p: *core.Parser, name: []const u8) !network.Statement {
    const expr = try expressions.parseILExpr(p);
    p.skipWhitespaceAndComments();
    try p.expect('>');
    return network.Statement{ .fill = .{
        .dest_name = name,
        .expr = expr,
        .parsed_expr = p.last_expr,
    } };
}

fn looksLikeInvocationFill(p: *core.Parser) bool {
    const save = p.pos;
    defer p.pos = save;

    const c = p.peek() orelse return false;
    if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;

    const name_start = p.pos;
    _ = p.readName() catch return false;
    const name_end = p.pos;
    p.skipWhitespaceAndComments();
    if (p.peek() != '(') return false;

    const name = p.src[name_start..name_end];
    // Geometry primitives (point/edge/loop/face) are supplied by the
    // @domain directive, not by user definitions. They must remain
    // .fill statements so the mesh exporter (which reads fill.expr
    // for coordinates) and validate.zig's geometry-aware handling
    // continue to see them unchanged. Only user-defined callees
    // trigger the invocation-fill classification.
    return !isGeometryPrimitive(name);
}

fn isGeometryPrimitive(name: []const u8) bool {
    return std.mem.eql(u8, name, "point")
        or std.mem.eql(u8, name, "edge")
        or std.mem.eql(u8, name, "loop")
        or std.mem.eql(u8, name, "face");
}

pub fn parseInvocation(
    p: *core.Parser,
    label: ?[]const u8,
    name: []const u8,
    dest_override: ?[]const u8,
) !network.Statement {
    const name_start = @intFromPtr(name.ptr) - @intFromPtr(p.src.ptr);

    var sources: []const network.Arg = &.{};
    var destinations: []const network.Arg = &.{};

    p.skipWhitespaceAndComments();

    if (p.peek() == '(') {
        const first_list = try arguments.parseArgList(p, ')');
        const end_pos_args = p.pos;

        p.skipWhitespaceAndComments();

        if (dest_override) |dest_name| {
            // Invocation-fill form: `dest< InstName(args) >`. The
            // args in the paren list are the sources; the destination
            // is named externally by the enclosing fill. Any second
            // paren group here would be a syntax the fill form
            // doesn't support — reject it so we don't silently
            // ignore a destination list.
            if (p.peek() == '(') {
                return error.UnexpectedDestinationListInFillInvocation;
            }
            sources = first_list;
            const dest_list = try p.allocator.alloc(network.Arg, 1);
            dest_list[0] = .{ .kind = .place, .name = dest_name };
            destinations = dest_list;
        } else if (p.peek() == '(') {
            // Two lists present: first is sources, second is destinations.
            sources = first_list;
            destinations = try arguments.parseArgList(p, ')');
            p.skipWhitespaceAndComments();
        } else {
            // One list present.
            if (label == null) {
                // Unlabeled with one list decays to pure_value.
                if (first_list.len > 0) {
                    p.allocator.free(first_list);
                }
                return network.Statement{ .pure_value = p.src[name_start..end_pos_args] };
            } else {
                // Labeled with one list: single list is sources.
                sources = first_list;
            }
        }
    } else if (dest_override != null) {
        // `dest< InstName >` with no arg list. Allowed by the grammar
        // (the callee might have zero sources), but only if the
        // callee exists.
    }

    return network.Statement{ .invoke = .{
        .name = name,
        .label = label,
        .sources = sources,
        .destinations = destinations,
    } };
}

pub fn parseEntryInvocation(p: *core.Parser, label: ?[]const u8, name: []const u8) !network.EntryInvocation {
    // Fant invocation order: sources first ($name/literal/groups), destinations second (name<>)
    const sources = try arguments.parseArgList(p, ')');
    p.skipWhitespaceAndComments();

    const raw_destinations: []const network.Arg = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{};

    // §12.3.4 — an omitted or empty destination list means a single
    // implicit return. Synthesize a place named "ms_result" here so that
    // every downstream consumer (emitter, runtime, testbench) sees a
    // named destination and never has to special-case the anonymous
    // form. This is the single producer for the entry-invocation side
    // of the anonymous-destination refactor; the emitter-side fallback
    // in network_entity.zig is now unreachable for this path.

    //  Why ms_result is the right name
    // It matches the prefix sanitizer.zig already uses for synthesized VHDL identifiers (ms_0s0, ms_process, etc. — visible in the sanitizer tests). That means:
    //
    // - The name is already "VHDL-safe by construction." No sanitizer pass needs to touch it.
    // - isBoundaryPortName and the various collision checks will treat it the same way they treat other ms_-prefixed names.
    // - A reader who sees ms_result in the AST or in emitted VHDL immediately knows "synthesized, not user-written."
    // - If a user writes ms_result as a destination name, the sanitizer's existing unique-name machinery is the place that would need to catch it (or the parser would reject it) — a separate, small policy question.
    const destinations: []const network.Arg = if (raw_destinations.len == 0) blk: {
        const synthesized = try p.allocator.alloc(network.Arg, 1);
        synthesized[0] = .{ .kind = .place, .name = "ms_result" };
        break :blk synthesized;
    } else raw_destinations;

    return network.EntryInvocation{
        .label = label,
        .name = name,
        .sources = sources,
        .destinations = destinations,
    };
}
