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
//!   - selector_demux   : output is a case block over a selector source that
//!                        routes one source value to one of N group-member
//!                        destinations, or (future) N sources to one
//!                        destination. Handled by writeSelectorDemux.
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
const value_transform_analysis = @import("../value_transform.zig");

/// The classifier's answer. Exactly one per definition.
pub const EmissionShape = enum {
    /// Composed-key lookup with contained rows; either a `.fill` composition
    /// (TAG-143, TAG-160) or a `.pure_value` composition driven by invocations
    /// (TAG-163). One case block per destination.
    contained_lookup,
    /// Rules directly expressible as a case block over def.sources.
    /// Handled by lowerRules.
    lowered_rules,
    /// Selector-gated case block over a group destination (demultiplex,
    /// `fanout`'s shape) or, in a future refinement, a group source into a
    /// single destination (multiplex, `fanin`'s shape). Handled by
    /// writeSelectorDemux. The `fanin` multiplex direction is NOT routed
    /// through this shape today: `fanin` classifies as `.lowered_rules`,
    /// which is correct for its single-destination case block. The
    /// `containedRowsAreSelectorGated` predicate recognizes both directions
    /// so that a future multiplex shape which `.lowered_rules` cannot
    /// express can migrate without a classifier change. See the predicate's
    /// doc comment.
    selector_demux,
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

/// Direction of a selector-gated case block. REFINEMENT within
/// `.selector_demux`, not a separate shape. `demultiplex` is the shape routed
/// today (`fanout`: one source → N group-member destinations). `multiplex`
/// is `fanin`'s shape (N sources → one destination); it is recognized by
/// `containedRowsAreSelectorGated` but routed to `.lowered_rules`, not
/// `.selector_demux`, because `lowered_rules` already emits it correctly.
pub const SelectorDirection = enum { multiplex, demultiplex };

fn containedRowsHaveFills(contained: []const network.Definition) bool {
    for (contained) |row| {
        for (row.resolution) |stmt| switch (stmt) {
            .fill => return true,
            else => {},
        };
    }
    return false;
}

fn containedRowNamesAreComposedKeys(def: network.Definition) bool {
    if (def.contained.len == 0 or def.sources.len == 0) return false;
    for (def.contained) |row| {
        var segs: usize = 1;
        for (row.name) |c| if (c == ',') {
            segs += 1;
        };
        if (segs != def.sources.len) return false;
    }
    return true;
}

/// True when a definition's contained rows express a selector-gated case
/// block: every row is anonymous, every row name is a single token (a
/// symbolic selector value, not a composed key), every row has exactly one
/// `.fill` body, and exactly one of the definition's top-level sources is
/// unreferenced in the row bodies (that source is the selector).
///
/// This predicate recognizes the DEMULTIPLEX direction (`fanout`): one
/// routed top-level source, N group-member destinations. Row bodies
/// reference the routed source; the unreferenced source is the selector.
///
/// It does NOT recognize multiplex-with-group-source (`fanin`): there,
/// the routed values are group members, not top-level sources, so
/// `def.sources` contains a group whose members are referenced rather
/// than the group itself. `fanin` classifies as `.lowered_rules` at
/// step 4 of the classifier, before this predicate is consulted, so
/// the mismatch is harmless — but the predicate's contract is
/// top-level-source routing, not group-source routing.
pub fn containedRowsAreSelectorGated(def: network.Definition) bool {
    if (def.contained.len == 0) {
        return false;
    }
    if (def.sources.len < 2) {
        return false;
    }
    if (!allContainedAnonymous(def.contained)) {
        return false;
    }

    for (def.contained) |row| {
        if (std.mem.indexOfScalar(u8, row.name, ',') != null) {
            return false;
        }
        if (row.resolution.len != 1) {
            return false;
        }
        if (row.resolution[0] != .fill) {
            return false;
        }
    }

    var referenced = std.StringHashMapUnmanaged(void).empty;
    defer referenced.deinit(std.heap.page_allocator);
    for (def.contained) |row| {
        const expr = row.resolution[0].fill.expr;

        var i: usize = 0;
        while (i < expr.len) {
            if (expr[i] != '$') {
                i += 1;
                continue;
            }
            i += 1;
            const start = i;
            while (i < expr.len and (std.ascii.isAlphanumeric(expr[i]) or expr[i] == '_')) i += 1;
            if (i > start) {
                referenced.put(std.heap.page_allocator, expr[start..i], {}) catch return false;
            }
        }
    }

    var selector_count: usize = 0;
    for (def.sources) |src| {
        const in_map = referenced.contains(src.name);

        if (!in_map) selector_count += 1;
    }

    if (selector_count != 1) return false;
    if (referenced.count() == 0) return false;
    return true;
}

/// Pure function: no I/O. `allocator` is kept for parity with the ticket's
/// proposed signature and so future sub-classification can allocate; the
/// current implementation does not need it.
pub fn classifyEmissionShape(
    allocator: std.mem.Allocator,
    def: network.Definition,
    transform_rules: []const value_transform_analysis.ValueTransformRule,
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
    //
    //    `fanin` lands here: single destination (`out`), contained rows,
    //    `decomposeRules` succeeds, `isLowerableShape` accepts (all rules
    //    write `out`). Return `.lowered_rules` and never reach 4b.
    if (def.destinations.len == 1 and def.contained.len > 0) {
        if (try rules.decomposeRules(allocator, def)) |rule_set| {
            if (value_transform_export.isLowerableShape(rule_set)) {
                return .lowered_rules;
            }
        }
    }

    // 4b. Selector-gated group destination? `fanout`'s shape: single group
    //     destination, contained rows are single-token selector values, row
    //     bodies route one source to one group member each. `fanin` also
    //     satisfies `containedRowsAreSelectorGated`, but step 4 already
    //     returned `.lowered_rules` for it, so 4b is only reached by
    //     non-lowerable shapes. The `destinations[0].kind == .group` guard
    //     restricts 4b to the demultiplex direction; a future multiplex
    //     shape that `.lowered_rules` cannot express would need this guard
    //     relaxed (and `fanin` migrated alongside it).
    if (def.destinations.len == 1 and
        def.destinations[0].kind == .group and
        containedRowsAreSelectorGated(def))
    {
        return .selector_demux;
    }

    std.debug.print(
        "[classify] def='{s}' dest_kind={s} sources.len={d} rowNamesComposed={any}\n",
        .{ def.name, @tagName(def.destinations[0].kind), def.sources.len, containedRowNamesAreComposedKeys(def) },
    );

    // 5. Composed-key lookup with contained rows? writeContainedLookupTable's
    //    shape. Fires for BOTH .fill and .pure_value composed keys, as long as
    //    the contained rows are anonymous.
    if (allContainedAnonymous(def.contained) and
        composedKeyPresent(def.contained) and
        def.contained.len > 0)
    {
        // Group destination: routable per-member ONLY when the contained
        // rows' names are composed keys over def.sources (TAG-149's OR
        // shape: rows "A0,B0" against two source groups, one case block
        // per group member). When the row names are single tokens
        // (fanout's shape: rows A/B/C/D against two sources), the case
        // selector can't be built from them.
        //
        // NOTE: `fanout`-shaped definitions no longer reach this guard —
        // step 4b catches them as `.selector_demux`. This guard now fires
        // only for group-destination shapes that are genuinely unrouted
        // (neither lowerable, nor selector-gated, nor composed-key lookup).
        // The `.none` set is smaller by exactly `fanout`'s shape.
        if (def.destinations[0].kind == .group and !containedRowNamesAreComposedKeys(def)) {
            return .none;
        }
        return .contained_lookup;
    }

    // 6. Fallback: only if there are rules to emit. MYGATE / MYCONST /
    //    Arbiter have empty rule lists and therefore classify as .none,
    //    matching the log's "no emission".
    if (transform_rules.len > 0) return .transform_rules;

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

pub fn hasFillOrPure(res: []const network.Statement) bool {
    for (res) |stmt| switch (stmt) {
        .fill, .pure_value => return true,
        else => {},
    };
    return false;
}

fn containedRowsArePureValues(contained: []const network.Definition) bool {
    if (contained.len == 0) return false;
    for (contained) |row| {
        if (row.resolution.len != 1) return false;
        if (row.resolution[0] != .pure_value) return false;
    }
    return true;
}

/// A "contained row" in the real AST is a nested Definition with an empty
/// name and a resolution of one pure_value. `allContainedAnonymous` in the
/// stub conflated this with "has sources/destinations"; here the real
/// condition is just "every contained entry is a lookup row, not a nested
/// sub-network with its own I/O".
pub fn allContainedAnonymous(contained: []const network.Definition) bool {
    for (contained) |row| {
        if (row.sources.len != 0) return false;
        if (row.destinations.len != 0) return false;
    }
    return true;
}

fn composedKeyPresent(contained: []const network.Definition) bool {
    for (contained) |row| {
        for (row.resolution) |stmt| switch (stmt) {
            .fill, .pure_value => return true,
            else => {},
        };
    }
    return false;
}
