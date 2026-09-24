// The single place that reads a Definition's @runtime tag (or its
// absence) and decides which execution model applies — Environment/
// testbench.Testbench for the ordinary, persistent-signal default,
// Bag/shake for @runtime(consumable). Callers pass the input shape that
// matches what they already know their definition models; a mismatch
// against the definition's actual tag is a caught error
// (error.RuntimeKindMismatch), not silently ignored parameters.

const std = @import("std");
const network = @import("../network.zig");
const rules_mod = @import("rules.zig");
const bag_mod = @import("bag.zig");
const testbench_mod = @import("testbench.zig");

pub const RunInput = union(enum) {
    digital: []testbench_mod.PortStream,
    consumable: []const []const []const u8, // one slice of token names per shake step
};

/// One entry per input step, in order — mirrors testbench.Presentation's
/// one-entry-per-wavefront shape, so intermediate state (e.g. "still 0
/// after the first step") stays inspectable, not just the final result.
pub const ConsumableStep = struct {
    outputs: std.StringHashMapUnmanaged(usize), // emission counts as of this step
};

pub const RunResult = union(enum) {
    digital: []const testbench_mod.Presentation,
    consumable: []const ConsumableStep,
};

pub fn run(allocator: std.mem.Allocator, def: network.Definition, input: RunInput) !RunResult {
    const wants_consumable = if (def.runtime_kind) |k| k == .consumable else false;

    switch (input) {
        .digital => |streams| {
            if (wants_consumable) return error.RuntimeKindMismatch;
            var bench = try testbench_mod.Testbench.init(allocator, def, streams);
            return .{ .digital = try bench.run() };
        },
        .consumable => |steps| {
            if (!wants_consumable) return error.RuntimeKindMismatch;
            var bag = bag_mod.Bag{ .allocator = allocator };
            const rules = try rules_mod.buildRules(allocator, def);

            var results: std.ArrayListUnmanaged(ConsumableStep) = .empty;
            for (steps) |names| {
                for (names) |name| try bag.add(name);
                try bag_mod.shake(&bag, rules);

                var snapshot: std.StringHashMapUnmanaged(usize) = .empty;
                var it = bag.emitted.iterator();
                while (it.next()) |entry| {
                    try snapshot.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
                }
                try results.append(allocator, .{ .outputs = snapshot });
            }
            return .{ .consumable = try results.toOwnedSlice(allocator) };
        },
    }
}