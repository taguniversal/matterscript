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

pub fn writeInvocationArgument(
    allocator: std.mem.Allocator,
    writer: anytype,
    invocation_index: usize,
    argument_index: usize,
    argument: network.Arg,
) !void {
    const signal_name = try std.fmt.allocPrint(allocator, "invocation_{d}_arg_{d}", .{ invocation_index, argument_index });
    defer allocator.free(signal_name);

    const text = argToText(argument);
    const trimmed = std.mem.trim(u8, text, " \t\r\n");

    if (argument.kind == .group) {
        if (argument.group) |group| {
            if (group.kind == .arbitration) {
                try writer.print("  -- Arbiter input competition group\n", .{});
            }
        }
        try writer.print("  {s} <= null_value;\n", .{signal_name});
    } else if (trimmed.len > 1 and trimmed[0] == '$' and std.mem.indexOfScalar(u8, trimmed[1..], '$') == null) {
        const source_id = try sanitizeName(allocator, trimmed[1..]);
        defer allocator.free(source_id);
        try writer.print("  {s} <= {s};\n", .{ signal_name, source_id });
    } else if (std.fmt.parseInt(u64, trimmed, 10)) |value| {
        try writer.print("  {s} <= data_value({d});\n", .{ signal_name, value });
    } else |_| {
        try writer.print("  {s} <= null_value;\n", .{signal_name});
    }
}


pub fn invocationDefinitionName(
    allocator: std.mem.Allocator,
    def: network.Definition,
    scope: []const u8,
    name: []const u8,
) ![]u8 {
    for (def.contained) |contained| {
        if (std.ascii.eqlIgnoreCase(contained.name, name)) {
            return scopedDefinitionName(allocator, scope, name);
        }
    }
    // Fall back to the scoped name using the current definition's scope prefix
    return scopedDefinitionName(allocator, scope, name);
}

pub fn writeInvocationInstance(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    scope: []const u8,
    inv: network.Invocation,
    invocation_index: usize,
) !void {
    const component_id = try invocationDefinitionName(allocator, def, scope, inv.name);
    defer allocator.free(component_id);

    // The port map's formal (left-hand) names must match what the
    // target entity actually declares — writeBoundaryPorts names each
    // port after its real, sanitized source/destination name, never
    // generic "arg_N"/"output_N" (that generic scheme is only valid
    // for the special testbench "_network" component wrapper, not for
    // an ordinary nested gate invocation like this). Look up the
    // invoked definition's own ports, run them through the SAME
    // normalization its own independent writeDefinition call will
    // apply (in particular, EQ0-style duplicate destination names
    // that fan out to "condition"/"condition_1" — see
    // normalizeDestinations), and use those names. Fall back to
    // "arg_N"/"output_N" only when no matching contained definition
    // is found at all, since then there's no real port list to
    // consult.
    var target_sources: []const []const u8 = &.{};
    var target_destinations: []const []const u8 = &.{};
    if (findContainedDefinition(def, inv.name)) |raw_target| {
        const target = try sanitizer.normalizeDefinitionIdentifiers(allocator, raw_target);
        target_sources = try boundary.collectBoundaryPortNames(allocator, target.sources);
        target_destinations = try boundary.collectBoundaryPortNames(allocator, target.destinations);
    }

    // Changed from component instance name to direct entity instantiation
    try writer.print("  invocation_{d} : entity work.{s} port map (", .{ invocation_index, component_id });

    var first = true;
    for (inv.sources, 0..) |_, argument_index| {
        if (!first) try writer.print(", ", .{});
        if (argument_index < target_sources.len) {
            try writer.print("{s} => invocation_{d}_arg_{d}", .{ target_sources[argument_index], invocation_index, argument_index });
        } else {
            try writer.print("arg_{d} => invocation_{d}_arg_{d}", .{ argument_index, invocation_index, argument_index });
        }
        first = false;
    }
    for (inv.destinations, 0..) |output, output_index| {
        if (!first) try writer.print(", ", .{});
        const formal = if (output_index < target_destinations.len)
            target_destinations[output_index]
        else
            try std.fmt.allocPrint(allocator, "output_{d}", .{output_index});
        if (output.group != null or output.name.len == 0) {
            try writer.print("{s} => invocation_{d}_output_{d}", .{ formal, invocation_index, output_index });
        } else {
            const output_id = try placeName(allocator, output);
            defer allocator.free(output_id);
            try writer.print("{s} => {s}", .{ formal, output_id });
        }
        first = false;
    }
    try writer.print(");\n", .{});
}