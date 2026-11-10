// Intermediate signals & expression fills)

const std = @import("std");
const network = @import("../../network.zig");
const boundary = @import("boundary.zig");
const sanitizer = @import("../sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;
const lookup = @import("../lookup.zig");
const hierarchy = @import("../hierarchy.zig");
const runtime_rules = @import("../../runtime/rules.zig");

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
            if (boundary.isBoundaryPort(allocator, def, raw_name)) return;

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
    if (raw_name.len == 0) return;
    if (boundary.isBoundaryPort(allocator, def, raw_name)) return;
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
        // Accept `.digit+` as part of the name, so `$X.0` extracts
        // "X.0" (not "X") and the translation below maps it to "X0".
        while (i < expression.len and (std.ascii.isAlphanumeric(expression[i]) or expression[i] == '_')) i += 1;
        while (i < expression.len and expression[i] == '.') {
            const dot_save = i;
            i += 1;
            if (i >= expression.len or !std.ascii.isDigit(expression[i])) {
                i = dot_save;
                break;
            }
            while (i < expression.len and std.ascii.isDigit(expression[i])) i += 1;
        }
        if (i > start) {
            const raw = expression[start..i];
            const translated = try sanitizer.translateMemberRef(allocator, raw);
            defer allocator.free(translated);
            try writeIntermediateSignal(allocator, writer, def, names, translated);
        }
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
    // Translate member references before sanitizing: `X.0` → `X0` → `x0`.
    const translated_dest = try sanitizer.translateMemberRef(allocator, fill.dest_name);
    defer allocator.free(translated_dest);
    const dest_id = try sanitizeName(allocator, translated_dest);
    defer allocator.free(dest_id);

    if (expression.len > 1 and expression[0] == '$') {
        var end = expression.len;
        if (std.mem.indexOfScalar(u8, expression, '(')) |open| end = open;
        // Extend the source name past any `.digit` member access, so
        // `$X.0` extracts "X.0" and translates to "X0".
        var src_end = end;
        if (std.mem.indexOfScalarPos(u8, expression, 1, '.')) |dot| {
            if (dot + 1 < end and std.ascii.isDigit(expression[dot + 1])) {
                var j = dot + 1;
                while (j < end and std.ascii.isDigit(expression[j])) j += 1;
                src_end = j;
            }
        }
        const raw_source = expression[1..src_end];
        const translated_source = try sanitizer.translateMemberRef(allocator, raw_source);
        defer allocator.free(translated_source);
        const source_id = try sanitizeName(allocator, translated_source);
        defer allocator.free(source_id);
        try writer.print("  {s} <= {s};\n", .{ dest_id, source_id });
        return true;
    }

    if (std.mem.startsWith(u8, expression, "Equal(")) {
        const dollar = std.mem.indexOfScalar(u8, expression, '$') orelse return false;
        const comma = std.mem.indexOfScalarPos(u8, expression, dollar, ',') orelse return false;
        const raw_source = expression[dollar + 1 .. comma];
        const translated_source = try sanitizer.translateMemberRef(allocator, raw_source);
        defer allocator.free(translated_source);
        const source_id = try sanitizeName(allocator, translated_source);
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

pub fn writeDestinationFills(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    table: ?runtime_rules.SymbolTable,
) !void {
    try writer.print("\n  -- destination fills (outputs)\n", .{});

    // Contained-row ROM shapes (anonymous pure_value rows, structured fill
    // rows, the multi-destination FULLADD shape). Reached only for
    // .contained_lookup; .transform_rules and .lowered_rules are dispatched
    // by the classifier and never enter here.
    const tbl = table orelse return error.NoSymbolTable;
    if (try lookup.writeContainedLookupTable(allocator, writer, def, tbl.entries)) {
        return;
    }
    for (def.resolution) |stmt| {
        switch (stmt) {
            .fill => |f| {
                const literal = std.fmt.parseInt(u64, std.mem.trim(u8, f.expr, " \t\r\n"), 10) catch null;
                if (literal) |value| {
                    const translated_dest = try sanitizer.translateMemberRef(allocator, f.dest_name);
                    defer allocator.free(translated_dest);
                    const dest_id = try sanitizeName(allocator, translated_dest);
                    defer allocator.free(dest_id);

                    try writer.print("  {s} <= data_value({d});\n", .{ dest_id, value });
                } else if (!try writeExpressionFill(allocator, writer, f)) {
                    // Fallback: the fill wasn't a recognized expression;
                    // still emit an empty assignment so the destination
                    // is declared in the process. Translate the name.
                    const translated_dest = try sanitizer.translateMemberRef(allocator, f.dest_name);
                    defer allocator.free(translated_dest);
                    const dest_id = try sanitizeName(allocator, translated_dest);
                    defer allocator.free(dest_id);
                    try writer.print("  {s} <= null_value;\n", .{dest_id});
                }
            },
            .invoke => |inv| {
                _ = inv;
            },
            .pure_value => |v| {
                if (v.len == 0 or v[0] != '$') {
                    try writer.print("  -- TODO: pure value expression {s} (not a recognized lookup-table shape)\n", .{v});
                }
            },
            .directive => |d| {
                try writer.print("  -- @{s}({s}) (directive not yet interpreted)\n", .{ d.name, d.args });
            },
        }
    }
}