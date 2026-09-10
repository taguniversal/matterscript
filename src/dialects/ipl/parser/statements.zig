const std = @import("std");
const network = @import("../network.zig");
const core = @import("core.zig");
const arguments = @import("arguments.zig");
const expressions = @import("expressions.zig");

// ----------------------------------------------------------------
// Statement Handlers
// ----------------------------------------------------------------

pub fn parseSourceFill(p: *core.Parser, name: []const u8) !network.Statement {
    _ = p.advance(); // consume <
    const expr = try expressions.parseILExpr(p);
    try p.expect('>');
    return network.Statement{ .fill = .{
        .dest_name = name,
        .expr = expr,
        .parsed_expr = p.last_expr,
    } };
}

pub fn parseInvocation(p: *core.Parser, label: ?[]const u8, name: []const u8) !network.Statement {
    // Captured before parsing sources so the full "name(args)"
    // span is available if this turns out to be a pure-value
    // expression rather than a real invocation (see below). name
    // is itself a slice into p.src (from readName), so its start
    // offset within p.src locates where this statement began.
    const name_start = @intFromPtr(name.ptr) - @intFromPtr(p.src.ptr);

    const sources = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{};

    // Record the position right after parsing sources,
    // before skipping any trailing whitespace or comments.
    const end_pos = p.pos;

    p.skipWhitespaceAndComments();

    const destinations: []const network.Arg = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{}; // §12.3.4 — destination list omitted, implicit single unnamed return

    // An UNLABELED "name(args)" with no destinations list isn't a
    // real component invocation — it's syntactically identical to
    // the "$name(args)" pure-value pattern (e.g. dualfanin's
    // "$steer()"), just naming a primitive function ("LT",
    // "Equal") instead of a plain variable reference, and needs
    // the same implicit-unnamed-result treatment. Without this,
    // codegen tries to instantiate a nonexistent component for it
    // (ghdl: "unit ..._lt not found in library work").
    //
    // A LABELED invocation with empty destinations is different
    // and must stay a real .invoke: TAG-192's whole point is
    // exactly this shape ("U1: AND($A $B)") — the label supplies
    // a hygienic temporary name for the implicit result, which
    // pure_value's "resolution deferred" semantics can't carry.
    if (label == null and destinations.len == 0) {
        return network.Statement{ .pure_value = p.src[name_start..end_pos] };
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
    const destinations: []const network.Arg = if (p.peek() == '(')
        try arguments.parseArgList(p, ')')
    else
        &.{}; // §12.3.4 — destination list omitted, implicit single unnamed return

    return network.EntryInvocation{
        .label = label,
        .name = name,
        .sources = sources,
        .destinations = destinations,
    };
}
