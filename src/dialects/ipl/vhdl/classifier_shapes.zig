//! TAG-229: Consolidate the three rule-emission paths behind a single shape classifier.
//!
//! A definition's shape is the answer to one question: WHERE DOES THE OUTPUT
//! COME FROM? There are four answers; each determines how the emitter must
//! elaborate it:
//!
//!   - contained_lookup : output is a table indexed by the inputs (contained
//!                        rows, or a composed key over a single destination).
//!                        One case block per destination.
//!   - lowered_rules    : same idea, but the rules lower cleanly to a case
//!                        block over def.sources (single destination, no
//!                        contained-row ambiguity). Handled by lowerRules.
//!   - transform_rules  : output is an OR-of-ANDs validity formula over the
//!                        inputs (multi-destination / non-lowerable shape).
//!   - invocations_only : output is whatever sub-invocations produce; no
//!                        rule emission, only component instantiation.
//!   - none             : no rule emission needed (empty resolution, pure
//!                        geometry, constant, or a shape the emitter does not
//!                        yet route).
//!
//! The shapes are MUTUALLY EXCLUSIVE. The classifier returns exactly one.
//! That is the whole point of TAG-229: "two paths both fire" / "no path fires"
//! becomes structurally impossible.

const std = @import("std");
const network = @import("../network.zig");
const rules = @import("../runtime/rules.zig");
const value_transform_export = @import("export/value_transform.zig");

/// The classifier's answer. Exactly one per definition.
pub const EmissionShape = enum {
    /// Composed-key lookup with contained rows; either a `.fill` composition
    /// (TAG-143, TAG-160) or a `.pure_value` composition driven by invocations
    /// (TAG-163). One case block per destination.
    contained_lookup,
    /// Rules directly expressible as a case block over def.sources.
    /// Handled by lowerRules.
    lowered_rules,
    /// No anonymous contained rows; rules must be emitted as validity-gated
    /// boolean formulas (older shape).
    transform_rules,
    /// Resolution is entirely .invoke statements; no lookup or formula
    /// emission, only component instantiation.
    invocations_only,
    /// No rule emission needed (empty resolution, pure geometry, constant,
    /// or a shape the emitter does not yet route).
    none,
};

/// Distinguishes the two ways a lookup can be keyed, for the sub-emitter.
/// This is a REFINEMENT within `.contained_lookup`, not a separate shape.
pub const LookupKey = enum { contained_rows, composed_fill, composed_pure_value };

/// Pure function: no I/O. `allocator` is kept for parity with the ticket's
/// proposed signature and so future sub-classification can allocate; the
/// current implementation does not need it.
pub fn classifyEmissionShape(
    allocator: std.mem.Allocator,
    def: network.Definition,
) !EmissionShape {

    // 1. No destinations / pure geometry / constant-with-no-emission -> none.
    //    (MYGATE, MYCONST, ca2d, ca100, rule30, Arbiter all land here per the
    //    verify log.)
    if (def.destinations.len == 0) return .none;

    const has_invoke = hasInvoke(def.resolution);
    const has_fill_or_pure = hasFillOrPure(def.resolution);

    // 2. Resolution is entirely invocations, no fills/rules to emit ->
    //    invocations_only. (CODE, FULLADD(129), WRAP, bus, 4BITADD, OR151,
    //    AND3.)
    if (has_invoke and !has_fill_or_pure and def.contained.len == 0) {
        return .invocations_only;
    }

    // 3. No rules to emit and no contained rows -> nothing to do here.
    if (def.contained.len == 0 and !has_fill_or_pure) {
        return .none;
    }


// 4. Lowerable shape? Decompose and ask the *same* function the old
//    dispatch used. This is the only way to reproduce the log's verdict;
//    a Definition-level reimplementation diverges (CODE, NOT).
if (def.destinations.len == 1 and def.contained.len > 0) {
    if (try rules.decomposeRules(allocator, def)) |rule_set| {
        if (value_transform_export.isLowerableShape(rule_set)) {
            return .lowered_rules;
        }
    }
}

    // 5. Composed-key lookup ...

    // 5. Composed-key lookup with contained rows? writeContainedLookupTable's
    //    shape. Fires for BOTH .fill and .pure_value composed keys, as long as
    //    the contained rows are anonymous.
    if (allContainedAnonymous(def.contained) and
        composedKeyPresent(def.resolution) and
        def.contained.len > 0)
    {
        // Guard from the log: a group destination with a .pure_value
        // composition (fanout) must NOT route here -- it produced an
        // empty-destination case block in TAG-163's follow-up. Treat it as
        // .none for now; it is a known refinement gap (see ticket "Shapes the
        // classifier's enum needs to cover").
        if (def.destinations[0].kind == .group) return .none;
        return .contained_lookup;
    }

    // 6. Fallback: validity-gated formulas. (FULLADD 177/198, REACTION, AND2.)
    if (def.contained.len > 0 or has_fill_or_pure) {
        return .transform_rules;
    }

    return .none;
}

// ---------------------------------------------------------------------------
// helpers (real AST)
// ---------------------------------------------------------------------------

fn hasInvoke(res: []const network.Statement) bool {
    for (res) |stmt| switch (stmt) {
        .invoke => return true,
        else => {},
    };
    return false;
}

fn hasFillOrPure(res: []const network.Statement) bool {
    for (res) |stmt| switch (stmt) {
        .fill, .pure_value => return true,
        else => {},
    };
    return false;
}

/// A "contained row" in the real AST is a nested Definition with an empty
/// name and a resolution of one pure_value. `allContainedAnonymous` in the
/// stub conflated this with "has sources/destinations"; here the real
/// condition is just "every contained entry is a lookup row, not a nested
/// sub-network with its own I/O".
fn allContainedAnonymous(contained: []const network.Definition) bool {
    for (contained) |row| {
        if (row.sources.len != 0) return false;
        if (row.destinations.len != 0) return false;
    }
    return true;
}

fn composedKeyPresent(res: []const network.Statement) bool {
    return hasFillOrPure(res);
}

/// Replicates isLowerableShape's verdict from value_transform.zig.
///
/// Single destination place, non-empty contained rows, and every .fill in
/// resolution targets that same destination. This reproduces the log's
/// "dest mismatch X vs Y" rejections:
///   fanout (TAG-147/180): fills target out1 vs out2  -> reject
///   test   (TAG-185):     fills target 0 vs 1         -> reject
fn isLowerableShape(def: network.Definition) bool {
    if (def.destinations.len != 1) return false;
    if (def.contained.len == 0) return false;

    const want = def.destinations[0].name;

    for (def.resolution) |stmt| switch (stmt) {
        .fill => |f| {
            if (!std.mem.eql(u8, f.dest_name, want)) return false;
        },
        else => {},
    };

    return true;
}
