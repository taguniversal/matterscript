// A genuinely different execution model from environment.zig's
// Environment: instead of a single, persistent value per named place
// (Fant's completeness semantics for hardware-style signals), this
// models the "shaking bag" literally — a multiset of independently-named
// tokens that get CONSUMED by a matching rule and replaced by whatever
// that rule produces.
//
// Deliberately separate from Environment/rules.run: a hardware signal
// persists once asserted; a bag token is used up. Reusing one struct for
// both would leak "does this consume its inputs" into every consumer of
// the runtime, even the ones that never need it. Rule *extraction*
// (buildRules, in rules.zig) is fully shared — this module only supplies
// a different way to execute the same ExecutableRule list.

const std = @import("std");
const rules_mod = @import("rules.zig");

pub const ExecutableRule = rules_mod.ExecutableRule;

pub const Bag = struct {
    allocator: std.mem.Allocator,
    /// Currently unconsumed tokens, by name. Presence (count >= 1) is
    /// all matching needs — per the "each occurrence gets its own
    /// unique name" convention already established (h1/h2, not two
    /// tokens both named "H2"), no rule needs more than one of the same
    /// name.
    tokens: std.StringHashMapUnmanaged(usize) = .empty,
    /// How many tokens have ever been produced under each destination
    /// label (e.g. "WATER") — this is the count a caller actually
    /// wants, independent of whether the specific produced token (w1,
    /// w2, ...) is still sitting unconsumed or has itself been consumed
    /// by something else since.
    emitted: std.StringHashMapUnmanaged(usize) = .empty,

    pub fn deinit(self: *Bag) void {
        self.tokens.deinit(self.allocator);
        self.emitted.deinit(self.allocator);
    }

    pub fn add(self: *Bag, name: []const u8) !void {
        const gop = try self.tokens.getOrPut(self.allocator, name);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += 1;
    }

    pub fn count(self: *const Bag, name: []const u8) usize {
        return self.tokens.get(name) orelse 0;
    }

    pub fn present(self: *const Bag, name: []const u8) bool {
        return self.count(name) > 0;
    }

    fn consume(self: *Bag, name: []const u8) void {
        if (self.tokens.getPtr(name)) |c| {
            if (c.* > 0) c.* -= 1;
        }
    }

    fn recordEmission(self: *Bag, label: []const u8) !void {
        const gop = try self.emitted.getOrPut(self.allocator, label);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += 1;
    }

    pub fn outputCount(self: *const Bag, label: []const u8) usize {
        return self.emitted.get(label) orelse 0;
    }
};

fn allPresent(bag: *const Bag, names: []const []const u8) bool {
    for (names) |name| if (!bag.present(name)) return false;
    return true;
}

fn inputsEqual(a: []const []const u8, b: []const []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (!std.mem.eql(u8, x, y)) return false;
    return true;
}

const Reaction = struct {
    inputs: []const []const u8,
    rule_indices: std.ArrayListUnmanaged(usize),
};

/// Runs `rules` against `bag` until a full pass produces no change.
///
/// Rules sharing an identical input set are treated as one combined
/// reaction: `RXN[WATER<w1>]` and `RXN[WATER<w2>]` both gate on the same
/// ha,hb,oa condition — they're two simultaneous PRODUCTS of one
/// reaction event, not two independent consumers racing for the same
/// tokens. Firing them as separate, independently-consuming rules meant
/// whichever ran first in a pass consumed the shared inputs and starved
/// the other permanently — only one water molecule was ever produced.
/// Grouping by input set first means the shared inputs are consumed
/// exactly once, and every rule in the group fires together off that one
/// consumption.
pub fn shake(bag: *Bag, rules: []const ExecutableRule) !void {
    var groups: std.ArrayListUnmanaged(Reaction) = .empty;
    outer: for (rules, 0..) |rule, i| {
        for (groups.items) |*group| {
            if (inputsEqual(group.inputs, rule.inputs)) {
                try group.rule_indices.append(bag.allocator, i);
                continue :outer;
            }
        }
        var indices: std.ArrayListUnmanaged(usize) = .empty;
        try indices.append(bag.allocator, i);
        try groups.append(bag.allocator, .{ .inputs = rule.inputs, .rule_indices = indices });
    }

    var changed = true;
    while (changed) {
        changed = false;
        for (groups.items) |group| {
            if (!allPresent(bag, group.inputs)) continue;

            for (group.inputs) |input| bag.consume(input);

            for (group.rule_indices.items) |i| {
                const rule = rules[i];
                switch (rule.action) {
                    .literal => |v| {
                        const name = try std.fmt.allocPrint(bag.allocator, "{d}", .{v});
                        try bag.add(name);
                        try bag.recordEmission(rule.dest);
                    },
                    .copy_from => |src| {
                        try bag.add(src);
                        try bag.recordEmission(rule.dest);
                    },
                    .assert_symbol => |sym| {
                        try bag.add(sym);
                        try bag.recordEmission(rule.dest);
                    },
                    .select => {
                        // Conditional invocation ($a$b()) needs a
                        // consumable-runtime design of its own: bag.zig
                        // consumes tokens by literal identity, but
                        // select's rule.inputs are argument PLACE NAMES
                        // whose current VALUES form the lookup key — a
                        // dereference bag.zig's model has no equivalent
                        // for yet. Revisit when @runtime(consumable)
                        // needs conditional invocation; not exercised by
                        // any test today.
                        return error.SelectNotSupportedInConsumableRuntime;
                    },
                }
            }
            changed = true;
        }
    }
}
