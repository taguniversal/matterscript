/// Responsibility: VHDL emission for value transform rules (Karl Fant §12.8.8).
/// Parsing, symbol validation, and rule grouping now live in the shared,
/// backend-agnostic module at src/dialects/ipl/value_transform.zig — this
/// file only turns already-collected, already-validated rules into VHDL text.

const std = @import("std");
const value_transform = @import("../../value_transform.zig");
const lookup = @import("../lookup.zig");
const sanitize = @import("../sanitizer.zig");
const network = @import("../../network.zig");
const runtime_rules = @import("../../runtime/rules.zig");
const constants = @import("../constants.zig");

// value transform rules (Fant §12.8.8): each rule fires when all of its
// input symbols are simultaneously valid, asserting its target(s) with a
// freshly assigned identity. A target shared by multiple rules (e.g. S
// from both G,I and H,I) is combined into one OR-of-ANDs assignment
// rather than several independent drivers on the same signal.
//
// The boundary-port-collision check is no longer performed here —
// validate.zig already enforces it at parse time via the shared
// value_transform module, so any Network reaching emission is guaranteed
// collision-free. Re-checking here would just duplicate that guarantee.
pub fn writeTransformRules(
    allocator: std.mem.Allocator,
    writer: anytype,
    rules: []const value_transform.ValueTransformRule,
) !void {
    try writer.print("\n  -- value transform rules\n", .{});
    var transform_symbols: std.ArrayListUnmanaged([]const u8) = .empty;
    const rule_groups = try value_transform.groupRulesByTarget(allocator, rules);
    for (rule_groups) |group| {
        const target_idx = try lookup.internSymbol(&transform_symbols, allocator, group.target);
        const target_id = try sanitize.sanitizeName(allocator, group.target);
        defer allocator.free(target_id);

        try writer.print("  {s} <= data_value({d}) when (", .{ target_id, target_idx });
        for (group.contributing_inputs.items, 0..) |inputs, i| {
            if (i > 0) try writer.print(") or (", .{});
            for (inputs, 0..) |input, j| {
                if (j > 0) try writer.print(" and ", .{});
                const input_id = try sanitize.sanitizeName(allocator, input);
                defer allocator.free(input_id);
                try writer.print("valid_of({s}) = '1'", .{input_id});
            }
        }
        try writer.print(") else null_value;\n", .{});
    }
}


/// Emit VHDL for a definition's rule set, consuming the neutral
/// `RuleSet` and `SymbolTable` produced by `decomposeRules` and
/// `buildSymbolTable`.
///
/// Currently handles the single-destination case: every rule writes
/// the same destination place, and the destination is either a port
/// on the entity or a port-name that will be declared by the caller
/// as an intermediate signal. The rules are lowered to a case
/// statement keyed on the concatenation of the source places'
/// payloads, with one branch per rule.
///
/// The symbol-encoding comment is written first, walking the symbol
/// table in interning order, so a reader can map `data_value(N)`
/// back to the token name.
///
/// Not yet handled:
///   - multiple destinations in one rule set (FULLADD's shape)
///   - `.tokens` outputs (compositions on the RHS)
///   - non-fill outputs whose token names a place other than the
///     definition's own destination
pub fn lowerRules(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    rule_set: runtime_rules.RuleSet,
    table: runtime_rules.SymbolTable,
) !void {
    if (rule_set.rules.len == 0) return;

    // 1. Symbol encoding comment, in interning order.
    if (table.entries.len > 0) {
        try writer.print("\n  -- symbol encoding: ", .{});
        for (table.entries, 0..) |name, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("{s}={d}", .{ name, i });
        }
        try writer.print("\n", .{});
    }

    // 2. Determine the destination. For `.fill` outputs, the dest is
    //    named explicitly. For `.token` outputs, the token name is
    //    the destination place (FULLADD's SUM0, SUM1, CO1 shape).
    //    For this pilot, require all rules to agree on the same
    //    destination; multi-destination grouping is a later pass.
    const dest_name = try singleDestination(allocator, rule_set);
    defer allocator.free(dest_name);
    const dest_id = try sanitize.sanitizeName(allocator, dest_name);
    defer allocator.free(dest_id);

    const width = constants.DATA_WIDTH;

    // 3. Case statement.
    try writer.print("\n  -- rule lookup for {s}\n", .{dest_name});
    try writer.print("  process(", .{});
    for (def.sources, 0..) |source, i| {
        if (i > 0) try writer.print(", ", .{});
        const src_id = try sanitize.sanitizeName(allocator, source.name);
        defer allocator.free(src_id);
        try writer.print("{s}", .{src_id});
    }
    try writer.print(", complete) begin\n", .{});
    try writer.print("    {s} <= null_value;\n", .{dest_id});
    try writer.print("    if complete = '1' then\n", .{});
    try writer.print("      case ", .{});

    // Case key: concatenation of source payloads. The payload is
    // data[width-1 .. 1] in the ncl_signal encoding, i.e. the bits
    // above the valid flag.
    for (def.sources, 0..) |source, i| {
        if (i > 0) try writer.print(" & ", .{});
        const src_id = try sanitize.sanitizeName(allocator, source.name);
        defer allocator.free(src_id);
        try writer.print("{s}({d} downto 1)", .{ src_id, width });
    }
    try writer.print(" is\n", .{});

    // Case branches, one per rule.
    for (rule_set.rules) |rule| {
        const key = try caseLabel(allocator, rule.pattern, table, width);
        defer allocator.free(key);

        const out_id =  outputTokenId(rule.output, table);
        const out_sanitized = try sanitize.sanitizeName(allocator, outputTokenName(rule.output));
        defer allocator.free(out_sanitized);

        try writer.print("        when {s} => {s} <= data_value({d});\n", .{
            key, dest_id, out_id,
        });
    }

    try writer.print("        when others => null;\n", .{});
    try writer.print("      end case;\n", .{});
    try writer.print("    end if;\n", .{});
    try writer.print("  end process;\n", .{});
}

/// Confirm every rule writes the same destination; return its name.
/// Pilot-only: multi-destination rule sets fail loudly.
fn singleDestination(
    allocator: std.mem.Allocator,
    rule_set: runtime_rules.RuleSet,
) ![]const u8 {
    var seen: ?[]const u8 = null;
    for (rule_set.rules) |rule| {
        const name = destinationName(rule.output);
        if (seen) |prev| {
            if (!std.mem.eql(u8, prev, name)) {
                return error.MultipleDestinationsNotYetSupported;
            }
        } else {
            seen = name;
        }
    }
    return allocator.dupe(u8, seen.?);
}

/// Extract the destination place name from a rule's output.
/// `.fill` names it explicitly; `.token` and `.tokens` use the
/// token name as the destination place name (the FULLADD shape).
fn destinationName(output: runtime_rules.Output) []const u8 {
    return switch (output) {
        .fill => |f| f.dest,
        .token => |s| s,
        .tokens => |syms| syms[0],
    };
}

/// Extract the token name that the rule asserts.
fn outputTokenName(output: runtime_rules.Output) []const u8 {
    return switch (output) {
        .fill => |f| switch (f.content) {
            .token => |s| s,
            .tokens => |syms| syms[0],
        },
        .token => |s| s,
        .tokens => |syms| syms[0],
    };
}

/// Look up the interned id of the token the rule asserts.
fn outputTokenId(output: runtime_rules.Output, table: runtime_rules.SymbolTable) u64 {
    const name = outputTokenName(output);
    return table.lookup(name) orelse unreachable;
}

/// Format one rule's pattern as a VHDL case label: each token name
/// is interned, then rendered as a DATA_WIDTH-wide binary string,
/// and the strings are concatenated with `&`.
fn caseLabel(
    allocator: std.mem.Allocator,
    pattern: runtime_rules.Pattern,
    table: runtime_rules.SymbolTable,
    width: usize,
) ![]const u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    var written: usize = 0;
    for (pattern.symbols, 0..) |sym, i| {
        if (i > 0) try buf.appendSlice(allocator, " & ");
        const id = table.lookup(sym) orelse unreachable;
        var bits: [64]u8 = undefined;
        const s = lookup.binStr(&bits, id, width);
        try buf.appendSlice(allocator, "\"");
        try buf.appendSlice(allocator, s);
        try buf.appendSlice(allocator, "\"");
        written += 1;
    }

    return buf.toOwnedSlice(allocator);
}