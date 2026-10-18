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
    // Sensitivity list: bare signal names, comma-separated.
    try writer.print("  process(", .{});
    for (rule_set.inputs.places, 0..) |place, i| {
        if (i > 0) try writer.print(", ", .{});
        const id = try sanitize.sanitizeName(allocator, place);
        defer allocator.free(id);
        try writer.print("{s}", .{id});
    }
    try writer.print(", complete) begin\n", .{});

    try writer.print("    {s} <= null_value;\n", .{dest_id});
    try writer.print("    if complete = '1' then\n", .{});
    try writer.print("      case ", .{});

    // Case key: payload slices of the same places, concatenated with &.
    for (rule_set.inputs.places, 0..) |place, i| {
        if (i > 0) try writer.print(" & ", .{});
        const id = try sanitize.sanitizeName(allocator, place);
        defer allocator.free(id);
        try writer.print("{s}({d} downto 1)", .{ id, width });
    }
    try writer.print(" is\n", .{});

    // Case branches, one per rule.
    for (rule_set.rules) |rule| {
        const key = try caseLabel(allocator, rule.pattern, table, width);
        defer allocator.free(key);

        const out_id = outputTokenId(rule.output, table);

        try writer.print("        when {s} => {s} <= data_value({d});\n", .{
            key, dest_id, out_id,
        });
    }

    // lowerRules currently emits one `dest <= null_value;` preamble
    // and one case branch per rule, all writing the same signal.
    // Rule sets whose rules don't all target the same destination
    // place (fanout/fanin write different members of a group;
    // FULLADD writes SUM and CARRY) need the multi-destination
    // emitter, which doesn't exist yet.

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

fn outputDestinationName(out: runtime_rules.Output) []const u8 {
    return switch (out) {
        .fill => |f| f.dest,
        .token => |t| t,
        .tokens => |ts| if (ts.len > 0) ts[0] else "",
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

pub fn isLowerableShape(rule_set: runtime_rules.RuleSet) bool {
    if (rule_set.rules.len == 0) return false;

    for (rule_set.rules) |rule| {
        // Pattern must have exactly one token per source place.
        if (rule.pattern.symbols.len != rule_set.inputs.places.len) return false;

        // Every token must be a plain name — no `$`, no `<...>`,
        // no parens. Anything decorated is a shape lowerRules
        // doesn't handle.
        for (rule.pattern.symbols) |sym| {
            if (sym.len == 0) return false;
            if (sym[0] == '$') return false;
            if (std.mem.indexOfAny(u8, sym, "<>()") != null) return false;
        }
        // Output must be `.fill` or `.token` / `.tokens`. If it's a
        // fill, its content must be a plain token.
        switch (rule.output) {
            .fill => |f| {
                if (f.dest.len == 0) return false;
                switch (f.content) {
                    .token => |s| if (s.len == 0) return false,
                    .tokens => return false, // not yet handled
                }
            },
            .token => {}, // handled
            .tokens => return false,
        }
    }

    const first_dest = outputDestinationName(rule_set.rules[0].output);
    for (rule_set.rules[1..]) |rule| {
        const d = outputDestinationName(rule.output);
        if (!std.mem.eql(u8, d, first_dest)) {
            std.debug.print("[isLowerableShape] reject: dest mismatch {s} vs {s}\n", .{ first_dest, d });
            return false;}
    }
    return true;
}
