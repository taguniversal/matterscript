/// Responsibility: Pure association rules (Karl Fant §12.8.8), string parsing, 
/// symbol validation, and rule target grouping.

const std = @import("std");
const network = @import("../../network.zig");
const lookup = @import("../lookup.zig");
const sanitize = @import("../sanitizer.zig");

pub const ValueTransformRule = struct {
    inputs: []const []const u8,
    targets: []const []const u8,
};

/// Groups rules by shared target, in first-seen order (not hashmap
/// iteration order — this keeps generated VHDL deterministic and
/// diffable, matching the golden-file testing approach used elsewhere).
/// A target asserted by several rules (e.g. "S" from both G,I[S] and
/// H,I[S]) collects every contributing rule's input list here, so the
/// emitter can combine them into one assignment instead of several
/// independent drivers on the same signal.
pub const RuleGroup = struct {
    target: []const u8,
    contributing_inputs: std.ArrayListUnmanaged([]const []const u8),
};

/// A "value transform rule" (Fant §12.8.8, e.g. `A[g,k,o]`, `G,I[S]`) is a
/// contained definition with no sources/destinations of its own, whose
/// entire content is a single pure_value target list. Its NAME is itself
/// a comma-separated list of the input symbols that must be simultaneously
/// present for the rule to fire; its bracket content is the comma-
/// separated list of symbols the rule asserts when it does.
///
/// The digit-prefix exclusion mirrors the filter in the "write children"
/// loop below: numeric lookup-table rows ("0", "1", "0,0") share this
/// exact AST shape but mean something entirely different — a stored
/// constant — and are already handled by writeContainedLookupTable's own,
/// more rigorous, source-arity-based disambiguation. This is a practical,
/// currently-sufficient heuristic, not a fully general one.
pub fn isValueTransformRule(def: network.Definition) bool {
    if (def.name.len == 0 or std.ascii.isDigit(def.name[0])) return false;
    if (def.sources.len != 0 or def.destinations.len != 0) return false;
    if (def.resolution.len != 1) return false;
    return def.resolution[0] == .pure_value;
}

/// Splits a comma-separated symbol list ("g,k,o" or "G,I") into its
/// individual names, trimming whitespace around each. A single symbol
/// with no comma ("A", "S") degenerates to a one-element list.
pub fn splitSymbolList(allocator: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, ',');
    while (it.next()) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len > 0) try names.append(allocator, trimmed);
    }
    return names.toOwnedSlice(allocator);
}

pub fn collectValueTransformRules(
    allocator: std.mem.Allocator,
    def: network.Definition,
) ![]const ValueTransformRule {
    var rules: std.ArrayListUnmanaged(ValueTransformRule) = .empty;
    for (def.contained) |contained| {
        if (!isValueTransformRule(contained)) continue;
        try rules.append(allocator, .{
            .inputs = try splitSymbolList(allocator, contained.name),
            .targets = try splitSymbolList(allocator, contained.resolution[0].pure_value),
        });
    }
    return rules.toOwnedSlice(allocator);
}

pub fn checkNoTransformRuleSymbolCollidesWithPort(def: network.Definition, name: []const u8) !void {
    for (def.sources) |arg| {
        if (std.ascii.eqlIgnoreCase(arg.name, name)) return error.SymbolCollidesWithBoundaryPort;
    }
    for (def.destinations) |arg| {
        if (std.ascii.eqlIgnoreCase(arg.name, name)) return error.SymbolCollidesWithBoundaryPort;
    }
}

pub fn assertNoTransformRuleSymbolCollidesWithPort(
    def: network.Definition,
    rules: []const ValueTransformRule,
) !void {
    for (rules) |rule| {
        for (rule.inputs) |name| try checkNoTransformRuleSymbolCollidesWithPort(def, name);
        for (rule.targets) |name| try checkNoTransformRuleSymbolCollidesWithPort(def, name);
    }
}



pub fn groupRulesByTarget(
    allocator: std.mem.Allocator,
    rules: []const ValueTransformRule,
) ![]const RuleGroup {
    var order: std.ArrayListUnmanaged(RuleGroup) = .empty;
    var index_of: std.StringHashMapUnmanaged(usize) = .empty;

    for (rules) |rule| {
        for (rule.targets) |target| {
            const gop = try index_of.getOrPut(allocator, target);
            if (!gop.found_existing) {
                gop.value_ptr.* = order.items.len;
                try order.append(allocator, .{ .target = target, .contributing_inputs = .empty });
            }
            try order.items[gop.value_ptr.*].contributing_inputs.append(allocator, rule.inputs);
        }
    }
    return order.toOwnedSlice(allocator);
}

// value transform rules (Fant §12.8.8): each rule fires when all
// of its input symbols are simultaneously valid, asserting its
// target(s) with a freshly assigned identity. A target shared by
// multiple rules (e.g. S from both G,I and H,I) is combined into
// one OR-of-ANDs assignment rather than several independent
// drivers on the same signal.
pub fn writeTransformRules(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
) !void {
    const rules = try collectValueTransformRules(allocator, def);
    try assertNoTransformRuleSymbolCollidesWithPort(def, rules);

    try writer.print("\n  -- value transform rules\n", .{});
    var transform_symbols: std.ArrayListUnmanaged([]const u8) = .empty;
    const rule_groups = try groupRulesByTarget(allocator, rules);
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
