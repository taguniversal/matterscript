// Builds an executable rule set from a parsed Definition and runs it to
// a fixed point, per Fant's completeness semantics (network.zig's own
// header comment): a destination place is null until something resolves
// it; nothing forces completion; a place with no available resolving
// rule stays null indefinitely — reported, not treated as an error.
//
// Scope (per the IPL Reference Runtime ticket): ordinary fills (literals
// and $name references) and value transform rules only. No .invoke, no
// ROM lookup tables, no @generate.

const std = @import("std");
const network = @import("../network.zig");
const value_transform = @import("../value_transform.zig");
const environment = @import("environment.zig");

pub const Environment = environment.Environment;
pub const PlaceState = environment.PlaceState;

pub const RuleAction = union(enum) {
    literal: u64,
    copy_from: []const u8,
    assert_symbol: []const u8,
};

pub const ExecutableRule = struct {
    inputs: []const []const u8, // all must be valid for this rule to fire
    dest: []const u8,
    action: RuleAction,
};

pub fn buildRules(allocator: std.mem.Allocator, def: network.Definition) ![]const ExecutableRule {
    var rules: std.ArrayListUnmanaged(ExecutableRule) = .empty;

    // Value transform rules — reusing the exact same parsing/grouping/
    // validation the VHDL emitter and validate.zig share, so there is
    // only ever one implementation of "what is a value transform rule."
    const vt_rules = try value_transform.collectValueTransformRules(allocator, def);

    var non_dest_ports_def = def;
    non_dest_ports_def.destinations = &.{};
    try value_transform.assertNoTransformRuleSymbolCollidesWithPort(non_dest_ports_def, vt_rules);

    const rule_groups = try value_transform.groupRulesByTarget(allocator, vt_rules);
    for (rule_groups) |group| {
        for (group.contributing_inputs.items) |inputs| {
            // Always assert the joint match's own target as a genuine
            // place, regardless of whether a same-named contained
            // definition also exists downstream. A $-reference fill
            // further down (Z0[OUT<$Z0>]) needs something real to copy
            // from — skipping this assertion (as this function
            // previously did whenever a same-named contained child
            // existed) left copy_from chasing a place that could never
            // become valid, which the fixed-point loop couldn't
            // distinguish from real progress: the rule kept re-firing,
            // no-op'ing, and reporting "changed" forever.
            try rules.append(allocator, .{
                .inputs = inputs,
                .dest = group.target,
                .action = .{ .assert_symbol = group.target },
            });
        }
    }

    // Fill-shaped children of def.contained (Z0[OUT<$Z0>],
    // RXN[WATER<w1>]) are a separate, one-input hop off whatever place
    // the joint match above just asserted — gated on the target name
    // alone, not the raw joint-match inputs. This is what lets several
    // rules share one target cleanly (RXN having two WATER-producing
    // children) without multiplying rules across every contributing
    // input combination.
    for (def.contained) |contained| {
        if (contained.sources.len != 0 or contained.destinations.len != 0) continue;
        for (contained.resolution) |stmt| {
            if (stmt != .fill) continue;
            const f = stmt.fill;
            const expr = std.mem.trim(u8, f.expr, " \t\r\n");

            const inputs = try allocator.alloc([]const u8, 1);
            inputs[0] = contained.name;

            const action: RuleAction = if (expr.len > 0 and expr[0] == '$')
                .{ .copy_from = expr[1..] }
            else
                .{ .assert_symbol = expr };

            try rules.append(allocator, .{ .inputs = inputs, .dest = f.dest_name, .action = action });
        }
    }

    // Ordinary fills — a literal is a zero-input rule (fires
    // immediately); "$name" is a one-input rule copying that place's
    // value once valid.
    for (def.resolution) |stmt| {
        if (stmt != .fill) continue;
        const f = stmt.fill;
        const expr = std.mem.trim(u8, f.expr, " \t\r\n");

        if (expr.len > 0 and expr[0] == '$') {
            const ref = expr[1..];
            const inputs = try allocator.alloc([]const u8, 1);
            inputs[0] = ref;
            try rules.append(allocator, .{ .inputs = inputs, .dest = f.dest_name, .action = .{ .copy_from = ref } });
        } else {
            try rules.append(allocator, .{ .inputs = &.{}, .dest = f.dest_name, .action = .{ .assert_symbol = expr } });
        }
    }

    return rules.toOwnedSlice(allocator);
}

pub const StuckPlace = struct {
    place: []const u8,
    /// Unresolved inputs of whichever rule(s) target this place — one
    /// level deep, not a transitive trace back to the ultimate cause.
    /// If "L" shows up here because it's itself waiting on something
    /// else, that's a natural next enhancement, not attempted yet.
    waiting_on: []const []const u8,
};

pub const CompletionReport = struct {
    complete: bool,
    stuck: []const StuckPlace, // empty when complete
};

pub fn run(
    allocator: std.mem.Allocator,
    env: *Environment,
    def: network.Definition,
    rules: []const ExecutableRule,
) !CompletionReport {
    var changed = true;
    while (changed) {
        changed = false;
        for (rules) |rule| {
            if (env.isValid(rule.dest)) continue;
            if (!env.allValid(rule.inputs)) continue;

            switch (rule.action) {
                .literal => |v| try env.assertLiteral(rule.dest, v),
                .copy_from => |src| try env.copyFrom(rule.dest, src),
                .assert_symbol => |sym| try env.assertSymbol(rule.dest, sym),
            }
            // Only a real state transition counts as progress. A
            // copy_from whose source turns out not to be valid yet
            // no-ops — that must not read as "changed", or a rule whose
            // source can never become valid spins the fixed-point loop
            // forever instead of correctly settling into a stuck report.
            if (env.isValid(rule.dest)) changed = true;
        }
    }

    var stuck: std.ArrayListUnmanaged(StuckPlace) = .empty;
    for (def.destinations) |dest| {
        if (env.isValid(dest.name)) continue;

        var waiting: std.ArrayListUnmanaged([]const u8) = .empty;
        for (rules) |rule| {
            if (!std.mem.eql(u8, rule.dest, dest.name)) continue;
            for (rule.inputs) |input| {
                if (env.isValid(input)) continue;
                var already_listed = false;
                for (waiting.items) |w| {
                    if (std.mem.eql(u8, w, input)) {
                        already_listed = true;
                        break;
                    }
                }
                if (!already_listed) try waiting.append(allocator, input);
            }
        }
        try stuck.append(allocator, .{ .place = dest.name, .waiting_on = try waiting.toOwnedSlice(allocator) });
    }

    return .{ .complete = stuck.items.len == 0, .stuck = try stuck.toOwnedSlice(allocator) };
}