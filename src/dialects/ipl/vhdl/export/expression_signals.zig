// Intermediate signals & expression fills)

const std = @import("std");
const network = @import("../../network.zig");
const boundary = @import("boundary.zig");
const sanitizer = @import("../sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;

fn argListContainsName(args: []const network.Arg, name: []const u8) bool {
    // Mirrors writeBoundaryPorts/boundaryCount's own recursion —
    // without it, any source/destination nested inside a bracket or
    // mutex group ("[{A0<> A1<>}]", "{$0 $1}", etc. — a very common
    // shape) is invisible here, so the fill/$-reference declaration
    // code below wrongly re-declares it as a fresh internal signal,
    // colliding with the port writeBoundaryPorts already emitted.
    for (args) |arg| {
        switch (arg.kind) {
            .group => if (arg.group) |grp| {
                if (argListContainsName(grp.places, name)) return true;
            },
            .place => if (std.ascii.eqlIgnoreCase(arg.name, name)) return true,
            else => {},
        }
    }
    return false;
}

fn isDefinitionPort(def: network.Definition, name: []const u8) bool {
    return argListContainsName(def.sources, name) or argListContainsName(def.destinations, name);
}

pub fn writeIntermediatePlaceSignal(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    intermediate_names: *std.ArrayListUnmanaged([]const u8),
    arg: network.Arg,
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                try writeIntermediatePlaceSignal(allocator, writer, def, intermediate_names, child);
            }
        },
        .place => {
            const raw_name = arg.name;
            if (raw_name.len == 0) return;

            // Avoid declaring signals for ports already declared on the boundary
            if (boundary.isBoundaryPort(def, raw_name)) return;

            // Avoid duplicate declarations
            for (intermediate_names.items) |existing| {
                if (std.mem.eql(u8, existing, raw_name)) return;
            }

            const signal_id = try sanitizeName(allocator, raw_name);
            defer allocator.free(signal_id);

            try intermediate_names.append(allocator, try allocator.dupe(u8, raw_name));
            // Same width fix as writeBoundaryPorts above — must match
            // ncl_signal, not a bare DATA_WIDTH vector.
            try writer.print("  signal {s} : ncl_signal;\n", .{signal_id});
            try writer.print("  signal {s}_valid : std_logic;\n", .{signal_id});
        },
        else => {},
    }
}

pub fn writeIntermediateSignal(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    names: *std.ArrayListUnmanaged([]const u8),
    raw_name: []const u8,
) !void {
    if (raw_name.len == 0 or isDefinitionPort(def, raw_name)) return;
    for (names.items) |name| if (std.ascii.eqlIgnoreCase(name, raw_name)) return;
    try names.append(allocator, try allocator.dupe(u8, raw_name));
    const id = try sanitizeName(allocator, raw_name);
    defer allocator.free(id);
    try writer.print("  signal {s} : ncl_signal;\n", .{id});
}

pub fn writeDollarReferenceSignals(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    names: *std.ArrayListUnmanaged([]const u8),
    expression: []const u8,
) !void {
    var i: usize = 0;
    while (i < expression.len) {
        if (expression[i] != '$') {
            i += 1;
            continue;
        }
        i += 1;
        const start = i;
        while (i < expression.len and (std.ascii.isAlphanumeric(expression[i]) or expression[i] == '_')) i += 1;
        if (i > start) try writeIntermediateSignal(allocator, writer, def, names, expression[start..i]);
    }
}


/// Attempts to evaluate and emit an expression fill (such as direct signal mapping
/// or equality checks against constants), returning `true` if successfully handled.
pub fn writeExpressionFill(
    allocator: std.mem.Allocator,
    writer: anytype,
    fill: network.SourceFill,
) !bool {
    const expression = std.mem.trim(u8, fill.expr, " \t\r\n");
    const dest_id = try sanitizeName(allocator, fill.dest_name);
    defer allocator.free(dest_id);

    if (expression.len > 1 and expression[0] == '$') {
        var end = expression.len;
        if (std.mem.indexOfScalar(u8, expression, '(')) |open| end = open;
        const source_id = try sanitizeName(allocator, expression[1..end]);
        defer allocator.free(source_id);
        try writer.print("  {s} <= {s};\n", .{ dest_id, source_id });
        return true;
    }

    if (std.mem.startsWith(u8, expression, "Equal(")) {
        const dollar = std.mem.indexOfScalar(u8, expression, '$') orelse return false;
        const comma = std.mem.indexOfScalarPos(u8, expression, dollar, ',') orelse return false;
        const source_id = try sanitizeName(allocator, expression[dollar + 1 .. comma]);
        defer allocator.free(source_id);
        const value_end = std.mem.indexOfScalarPos(u8, expression, comma + 1, ')') orelse return false;
        const value_text = std.mem.trim(u8, expression[comma + 1 .. value_end], " \t\r\n");
        const value = std.fmt.parseInt(u64, value_text, 10) catch return false;
        try writer.print("  process({s}) begin\n", .{source_id});
        try writer.print("    {s} <= null_value;\n", .{dest_id});
        try writer.print("    if is_data({s}) and payload({s}) = std_logic_vector(to_unsigned({d}, DATA_WIDTH)) then\n", .{ source_id, source_id, value });
        try writer.print("      {s} <= data_value(1);\n", .{dest_id});
        try writer.print("    elsif is_data({s}) then\n", .{source_id});
        try writer.print("      {s} <= data_value(0);\n", .{dest_id});
        try writer.print("    end if;\n  end process;\n", .{});
        return true;
    }

    return false;
}


