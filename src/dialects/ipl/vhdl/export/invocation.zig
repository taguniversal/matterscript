// Responsibility: Manages component declarations, argument mapping
const std = @import("std");
const network = @import("../../network.zig");
const boundary = @import("boundary.zig");
const sanitizer = @import("../sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;

/// Unwraps a network argument into its raw text representation, handling places,
/// literals, expressions, and group kinds.
pub fn argToText(arg: network.Arg) []const u8 {
    return switch (arg.kind) {
        .place => if (arg.name.len > 0) arg.name else arg.text,
        .literal, .expression => arg.text,
        .group => if (arg.group) |g| switch (g.kind) {
            .bundle => "[group]",
            .mutex => "{mutex}",
            .arbitration => "{{arbitration}}",
        } else "",
    };
}

pub fn placeName(allocator: std.mem.Allocator, arg: network.Arg) ![]const u8 {
    const raw_name = switch (arg.kind) {
        .place => if (arg.name.len > 0) arg.name else arg.text,
        .literal, .expression => arg.text,
        .group => arg.text,
    };
    return try sanitizeName(allocator, raw_name);
}

pub fn scopedDefinitionName(
    allocator: std.mem.Allocator,
    scope: []const u8,
    name: []const u8,
) ![]u8 {
    const local_name = try sanitizeName(allocator, name);
    defer allocator.free(local_name);

    if (scope.len == 0) {
        return allocator.dupe(u8, local_name);
    }

    const local_scope = try sanitizeName(allocator, scope);
    defer allocator.free(local_scope);

    // Prevent double-prefixing if the name already starts with the scope
    if (std.mem.startsWith(u8, local_name, local_scope)) {
        return allocator.dupe(u8, local_name);
    }

    return std.fmt.allocPrint(allocator, "{s}_{s}", .{ local_scope, local_name });
}

pub fn findContainedDefinition(def: network.Definition, name: []const u8) ?network.Definition {
    for (def.contained) |contained| {
        if (std.ascii.eqlIgnoreCase(contained.name, name)) return contained;
    }
    return null;
}

/// Flat definitions only (see README / validate.zig's NestedDefinitionNotAllowed):
/// callee resolution is always top-level, never through def.contained.
/// findContainedDefinition above still exists for genuine lookup-table
/// entries (value-transform rules), but is no longer consulted here.
pub fn findCallee(def: network.Definition, top: []const network.Definition, name: []const u8) ?network.Definition {
    _ = def;
    for (top) |t| {
        if (std.ascii.eqlIgnoreCase(t.name, name)) return t;
    }
    return null;
}

/// The form of a definition that is actually emitted. The entity
/// declaration and every port map derive port names from this one function.
pub fn emissionForm(allocator: std.mem.Allocator, raw: network.Definition) !network.Definition {
    const d = try boundary.normalizeReturnDestinations(allocator, raw);
    return sanitizer.normalizeDefinitionIdentifiers(allocator, d);
}

fn writeScalarArgument(
    allocator: std.mem.Allocator,
    writer: anytype,
    signal_name: []const u8,
    argument: network.Arg,
) !void {
    if (argument.kind == .place and argument.name.len > 0) {
        const id = try placeName(allocator, argument);
        defer allocator.free(id);
        try writer.print("  {s} <= {s};\n", .{ signal_name, id });
        return;
    }

    const text = argToText(argument);
    const trimmed = std.mem.trim(u8, text, " \t\r\n");

    if (trimmed.len > 1 and trimmed[0] == '$' and std.mem.indexOfScalar(u8, trimmed[1..], '$') == null) {
        const source_id = try sanitizeName(allocator, trimmed[1..]);
        defer allocator.free(source_id);
        try writer.print("  {s} <= {s};\n", .{ signal_name, source_id });
    } else if (std.fmt.parseInt(u64, trimmed, 10)) |value| {
        try writer.print("  {s} <= data_value({d});\n", .{ signal_name, value });
    } else |_| {
        try writer.print("  {s} <= null_value;\n", .{signal_name});
    }
}

fn writeInvocationArgumentMember(
    allocator: std.mem.Allocator,
    writer: anytype,
    invocation_index: usize,
    argument_index: usize,
    member_index: usize,
    member: network.Arg,
) !void {
    // A nested group-of-groups isn't exercised by any current example;
    // fail loudly rather than silently drive null_value if one shows up.
    if (member.kind == .group) return error.NestedGroupInvocationNotSupported;

    const signal_name = try std.fmt.allocPrint(allocator, "invocation_{d}_arg_{d}_{d}", .{ invocation_index, argument_index, member_index });
    defer allocator.free(signal_name);
    try writeScalarArgument(allocator, writer, signal_name, member);
}

pub fn writeInvocationArgument(
    allocator: std.mem.Allocator,
    writer: anytype,
    invocation_index: usize,
    argument_index: usize,
    argument: network.Arg,
) !void {
    if (argument.kind == .group) {
        if (argument.group) |group| {
            if (group.kind == .arbitration) {
                try writer.print("  -- Arbiter input competition group\n", .{});
            }
            for (group.places, 0..) |member, member_index| {
                try writeInvocationArgumentMember(allocator, writer, invocation_index, argument_index, member_index, member);
            }
        }
        return;
    }

    const signal_name = try std.fmt.allocPrint(allocator, "invocation_{d}_arg_{d}", .{ invocation_index, argument_index });
    defer allocator.free(signal_name);
    try writeScalarArgument(allocator, writer, signal_name, argument);
}

/// Calls `visit` once per synthetic output signal of `inv`. A synthetic
/// signal is one that the emitter has to declare itself, rather than a
/// real place already wired directly into the port map.
///
/// The rules, mirroring the loop that used to be duplicated in
/// writeInvocationSignals (declaration) and definition.zig's body loop
/// (initialization):
///
///   - non-group output with a name      → no synthetic signal (it's a port)
///   - non-group output without a name   → synthetic `invocation_N_output_M`
///   - group output, named member        → no synthetic signal
///   - group output, anonymous member    → synthetic `invocation_N_output_M_K`
///   - group output, nested-group member → synthetic `invocation_N_output_M_K`
///
/// The last two cases are the only ones that produce a signal, and the
/// signal name differs: group members get the extra `_K` suffix.
///
/// `visit` receives a stack-allocated name valid only for the duration
/// of the call. Callers that need to keep it must dupe.
pub fn forEachSyntheticOutputSignal(
    inv: network.Invocation,
    invocation_index: usize,
    context: anytype,
    comptime visit: fn (@TypeOf(context), name: []const u8) anyerror!void,
) !void {
    var buf: [64]u8 = undefined;

    for (inv.destinations, 0..) |output, output_index| {
        if (output.kind == .group) {
            if (output.group) |group| {
                for (group.places, 0..) |member, member_index| {
                    if (member.group == null and member.name.len != 0) continue;
                    const name = try std.fmt.bufPrint(
                        &buf,
                        "invocation_{d}_output_{d}_{d}",
                        .{ invocation_index, output_index, member_index },
                    );
                    try visit(context, name);
                }
            }
            continue;
        }
        if (output.group == null and output.name.len != 0) continue;
        const name = try std.fmt.bufPrint(
            &buf,
            "invocation_{d}_output_{d}",
            .{ invocation_index, output_index },
        );
        try visit(context, name);
    }
}

pub fn writeInvocationSignals(
    writer: anytype,
    def: network.Definition,
) !void {
    for (def.resolution, 0..) |stmt, invocation_index| {
        if (stmt != .invoke) continue;
        const inv = stmt.invoke;

        for (inv.sources, 0..) |source, argument_index| {
            if (source.kind == .group) {
                if (source.group) |group| {
                    for (group.places, 0..) |_, member_index| {
                        try writer.print("  signal invocation_{d}_arg_{d}_{d} : ncl_signal;\n", .{ invocation_index, argument_index, member_index });
                    }
                }
                continue;
            }
            try writer.print("  signal invocation_{d}_arg_{d} : ncl_signal;\n", .{ invocation_index, argument_index });
        }

        const Ctx = struct {
            w: @TypeOf(writer),
            fn visit(self: @This(), name: []const u8) anyerror!void {
                try self.w.print("  signal {s} : ncl_signal;\n", .{name});
            }
        };
        try forEachSyntheticOutputSignal(inv, invocation_index, Ctx{ .w = writer }, Ctx.visit);
    }
}

pub fn invocationDefinitionName(
    allocator: std.mem.Allocator,
    def: network.Definition,
    scope: []const u8,
    name: []const u8,
) ![]u8 {
    // Nested in the caller: declared as <scope>_<name>, the same rule
    // writeDefinition applies when it recurses into def.contained.
    for (def.contained) |contained| {
        if (std.ascii.eqlIgnoreCase(contained.name, name)) {
            return scopedDefinitionName(allocator, scope, name);
        }
    }
    // Not nested in the caller. Top-level definitions are declared with an
    // empty scope (writeDefinition's `scope` is "" at the top), so
    // instantiate them by that same unscoped name.
    return scopedDefinitionName(allocator, "", name);
}

pub fn writeInvocationInstance(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    scope: []const u8,
    top: []const network.Definition,
    inv: network.Invocation,
    invocation_index: usize,
) !void {
    const component_id = try invocationDefinitionName(allocator, def, scope, inv.name);
    defer allocator.free(component_id);

    // The port map's formal (left-hand) names must match what the
    // target entity actually declares. Look up the invoked definition
    // (flat/top-level only — see findCallee), run it through the same
    // normalization its own independent writeDefinition call will
    // apply, and use those names. Fall back to "arg_N"/"output_N" only
    // when the callee can't be found at all.
    var target_sources: []const []const u8 = &.{};
    var target_destinations: []const []const u8 = &.{};

    if (findCallee(def, top, inv.name)) |raw_target| {
        const target = try emissionForm(allocator, raw_target);
        target_sources = try boundary.collectBoundaryPortNames(allocator, target.sources);
        target_destinations = try boundary.collectBoundaryPortNames(allocator, target.destinations);
    }

    try writer.print("  invocation_{d} : entity work.{s} port map (", .{ invocation_index, component_id });

    var first = true;

    // formal_index tracks the callee's own flat port list position,
    // which is NOT the same as argument_index once a group argument
    // expands into several formal ports at once.
    var formal_index: usize = 0;
    for (inv.sources, 0..) |source, argument_index| {
        if (source.kind == .group) {
            if (source.group) |group| {
                for (group.places, 0..) |_, member_index| {
                    if (!first) try writer.print(", ", .{});
                    const member_signal = try std.fmt.allocPrint(allocator, "invocation_{d}_arg_{d}_{d}", .{ invocation_index, argument_index, member_index });
                    defer allocator.free(member_signal);
                    if (formal_index < target_sources.len) {
                        try writer.print("{s} => {s}", .{ target_sources[formal_index], member_signal });
                    } else {
                        try writer.print("arg_{d} => {s}", .{ formal_index, member_signal });
                    }
                    formal_index += 1;
                    first = false;
                }
            }
            continue;
        }
        if (!first) try writer.print(", ", .{});
        if (formal_index < target_sources.len) {
            try writer.print("{s} => invocation_{d}_arg_{d}", .{ target_sources[formal_index], invocation_index, argument_index });
        } else {
            try writer.print("arg_{d} => invocation_{d}_arg_{d}", .{ formal_index, invocation_index, argument_index });
        }
        formal_index += 1;
        first = false;
    }

    var formal_dest_index: usize = 0;
    for (inv.destinations, 0..) |output, output_index| {
        if (output.kind == .group) {
            if (output.group) |group| {
                for (group.places, 0..) |member, member_index| {
                    if (!first) try writer.print(", ", .{});
                    const formal = if (formal_dest_index < target_destinations.len)
                        target_destinations[formal_dest_index]
                    else
                        try std.fmt.allocPrint(allocator, "output_{d}", .{formal_dest_index});
                    if (member.group != null or member.name.len == 0) {
                        try writer.print("{s} => invocation_{d}_output_{d}_{d}", .{ formal, invocation_index, output_index, member_index });
                    } else {
                        const member_id = try placeName(allocator, member);
                        defer allocator.free(member_id);
                        try writer.print("{s} => {s}", .{ formal, member_id });
                    }
                    formal_dest_index += 1;
                    first = false;
                }
            }
            continue;
        }
        if (!first) try writer.print(", ", .{});
        const formal = if (formal_dest_index < target_destinations.len)
            target_destinations[formal_dest_index]
        else
            try std.fmt.allocPrint(allocator, "output_{d}", .{formal_dest_index});
        if (output.group != null or output.name.len == 0) {
            try writer.print("{s} => invocation_{d}_output_{d}", .{ formal, invocation_index, output_index });
        } else {
            const output_id = try placeName(allocator, output);
            defer allocator.free(output_id);
            try writer.print("{s} => {s}", .{ formal, output_id });
        }
        formal_dest_index += 1;
        first = false;
    }

    try writer.print(");\n", .{});
}
