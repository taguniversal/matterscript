
// Backend-agnostic representation and parsing of value transform rules
// (Fant §12.8.8, e.g. `A[g,k,o]`, `G,I[S]`) — a contained definition with
// no sources/destinations of its own, whose entire content is a single
// pure_value target list. Its NAME is itself a comma-separated list of
// the input symbols that must be simultaneously present for the rule to
// fire; its bracket content is the comma-separated list of symbols the
// rule asserts when it does.
//
// This module has no VHDL (or any other backend) dependency — it's pure
// AST inspection, shared by parse-time validation (validate.zig) and
// every backend that consumes these rules (VHDL emission today; the
// reference runtime next).

const std = @import("std");
const network = @import("network.zig");

pub const ValueTransformRule = struct {
    inputs: []const []const u8,
    targets: []const []const u8,
};

/// Groups rules by shared target, in first-seen order (not hashmap
/// iteration order — keeps output deterministic and diffable). A target
/// asserted by several rules (e.g. "S" from both G,I[S] and H,I[S])
/// collects every contributing rule's input list here, so a consumer can
/// combine them instead of treating them as independent drivers.
pub const RuleGroup = struct {
    target: []const u8,
    contributing_inputs: std.ArrayListUnmanaged([]const []const u8),
};

/// The digit-prefix exclusion mirrors the filter used wherever contained
/// definitions are walked for VHDL entity emission: numeric lookup-table
/// rows ("0", "1", "0,0") share this exact AST shape but mean something
/// entirely different — a stored constant — and are handled by
/// writeContainedLookupTable's own, more rigorous, source-arity-based
/// disambiguation. This is a practical, currently-sufficient heuristic,
/// not a fully general one.
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

/// True if `name` matches (case-insensitively, mirroring VHDL's own
/// case-insensitivity — though this check itself has no VHDL dependency,
/// it's a property of the AST) one of `def`'s own boundary port names.
pub fn isBoundaryPortName(def: network.Definition, name: []const u8) bool {
    for (def.sources) |arg| if (std.ascii.eqlIgnoreCase(arg.name, name)) return true;
    for (def.destinations) |arg| if (std.ascii.eqlIgnoreCase(arg.name, name)) return true;
    return false;
}

/// The single canonical check for the TAG-177 collision: a boundary port
/// and an internally-formed value-transform-rule symbol are different
/// identities, and if they share a name there's no way to tell, at any
/// later reference, which one was meant. validate.zig calls this at
/// parse time, so it's enforced before any backend ever sees the network.
pub fn assertNoTransformRuleSymbolCollidesWithPort(
    def: network.Definition,
    rules: []const ValueTransformRule,
) !void {
    for (rules) |rule| {
        for (rule.inputs) |name| if (isBoundaryPortName(def, name)) return error.TransformRuleSymbolCollidesWithBoundaryPort;
        for (rule.targets) |name| if (isBoundaryPortName(def, name)) return error.TransformRuleSymbolCollidesWithBoundaryPort;
    }
}