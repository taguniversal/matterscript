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
    const expr = try expressions.parseILExpr(p);

    p.skipWhitespaceAndComments();
    try p.expect('>'); // expect() validates p.peek() == '>' AND advances p.pos

    return network.Statement{ .fill = .{
        .dest_name = name,
        .expr = expr,
        .parsed_expr = p.last_expr,
    } };
}

pub fn parseInvocation(p: *core.Parser, label: ?[]const u8, name: []const u8) !network.Statement {
    const name_start = @intFromPtr(name.ptr) - @intFromPtr(p.src.ptr);

    var sources: []const network.Arg = &.{};
    var destinations: []const network.Arg = &.{};

    p.skipWhitespaceAndComments();

    if (p.peek() == '(') {
        const first_list = try arguments.parseArgList(p, ')');
        const end_pos_args = p.pos;

        p.skipWhitespaceAndComments();

        if (p.peek() == '(') {
            // Two lists present: first is sources, second is destinations
            sources = first_list;
            destinations = try arguments.parseArgList(p, ')');
            p.skipWhitespaceAndComments();
        } else {
            // One list present
            if (label == null) {
                // Unlabeled with one list decays to pure_value
                if (first_list.len > 0) {
                    p.allocator.free(first_list);
                }
                return network.Statement{ .pure_value = p.src[name_start..end_pos_args] };
            } else {
                // Labeled with one list: single list is sources
                sources = first_list;
            }
        }
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
    // implicit return. Synthesize a place named "result" here so that
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
