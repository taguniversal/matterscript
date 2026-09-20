/// Responsibility: VHDL emission for value transform rules (Karl Fant §12.8.8).
/// Parsing, symbol validation, and rule grouping now live in the shared,
/// backend-agnostic module at src/dialects/ipl/value_transform.zig — this
/// file only turns already-collected, already-validated rules into VHDL text.

const std = @import("std");
const value_transform = @import("../../value_transform.zig");
const lookup = @import("../lookup.zig");
const sanitize = @import("../sanitizer.zig");

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