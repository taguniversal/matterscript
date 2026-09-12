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
