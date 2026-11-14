const std = @import("std");
const network = @import("../network.zig");

/// Direction rule for a single argument list in the grammar. The names
/// are stated from the point of view of the *scope the list belongs
/// to*, matching the AST's field names:
///
///   - A definition's source list and an invocation's destination
///     list both contain `name<>` place declarations (values flowing
///     OUT of the local scope toward the caller/callee).
///   - A definition's destination list and an invocation's source
///     list both contain `$name` place references (values flowing
///     IN from outside), with literals additionally permitted in an
///     invocation's source list as a convenience for constant
///     arguments.
///
/// Recurse into groups: all members share their containing list's
/// direction. This is checked structurally; a bundle's members are
/// not exempt.
pub const Direction = enum {
    definition_source,
    definition_destination,
    invocation_source,
    invocation_destination,
};

pub const Context = struct {
    description: []const u8,
    direction: Direction,
};

pub fn validateArgList(args: []const network.Arg, ctx: Context) !void {
    for (args, 0..) |arg, i| {
        validateArg(arg, ctx) catch |err| {
            std.debug.print(
                "[validate_args] {s}: entry {d} ('{s}'): {s}\n",
                .{ ctx.description, i, arg.text, @errorName(err) },
            );
            return err;
        };
    }
}

fn validateArg(arg: network.Arg, ctx: Context) !void {
    switch (arg.kind) {
        .group => if (arg.group) |g| {
            for (g.places) |member| try validateArg(member, ctx);
        },
        .place => {
            // Synthesized entries (ms_result, dest_override) have
            // empty .text — they are correct by construction and
            // skipped. Only the parser produces these.
            if (arg.text.len == 0) return;

            const dir = arg.direction orelse return error.UnmarkedPlaceInArgList;

            switch (ctx.direction) {
                .definition_source, .invocation_destination => {
                    if (dir != .source) return error.DestinationInSourcePosition;
                },
                .definition_destination, .invocation_source => {
                    if (dir != .destination) return error.SourceInDestinationPosition;
                },
            }
        },
        .literal => switch (ctx.direction) {
            .invocation_source => {},
            else => return error.LiteralInNonSourcePosition,
        },
        .expression => return error.ExpressionInArgList,
    }
}
