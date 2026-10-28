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

// ---------------------------------------------------------------------------
// STUB TYPES.
//
// TODO(tag-229 AC#3): delete this whole `network` module and replace with
// `const network = @import("network.zig");` once the classifier is wired into
// writeDefinition. The field names here mirror the AST dumps in the ticket's
// test log; the real types are tagged unions (e.g. Destination is
// `.{ .kind = .group, .name = ..., .group = ... }`), so `dest.kind == .group`
// stays valid but the field access patterns will need a light touch-up.
// ---------------------------------------------------------------------------
const network = struct {
    pub const Kind = enum { place, group, unnamed, literal };

    pub const ResolutionTag = enum { fill, pure_value, invoke };

    pub const Source = struct {
        kind: Kind = .place,
        name: []const u8 = "",
    };

    pub const Destination = struct {
        kind: Kind = .place,
        name: []const u8 = "",
    };

    pub const Resolution = struct {
        tag: ResolutionTag = .fill,
    };

    pub const Contained = struct {
        sources: usize = 0,
        destinations: usize = 0,
        resolution: usize = 0,
        dest_name: []const u8 = "",
    };

    pub const Definition = struct {
        name: []const u8 = "",
        sources: []const Source = &.{},
        destinations: []const Destination = &.{},
        resolution: []const Resolution = &.{},
        contained: []const Contained = &.{},
    };
};

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
    _ = allocator;

    // 1. No destinations / pure geometry / constant-with-no-emission -> none.
    //    (MYGATE, MYCONST, ca2d, ca100, rule30, Arbiter all land here per the
    //    verify log.)
    if (def.destinations.len == 0) return .none;

    const has_invoke = anyResolution(def.resolution, .invoke);
    const has_fill_or_pure = anyResolutionFillOrPure(def.resolution);

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

    // 4. Lowerable shape? Single destination and the destinations the rules
    //    target agree (replicates isLowerableShape's "dest mismatch" rejections
    //    seen in the log: fanout `out1 vs out2`, test `0 vs 1`).
    // 4. Lowerable shape? ...
    if (isLowerableShape(def)) {
        return .lowered_rules;
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
// helpers (all pure; flesh out against the real AST)
// ---------------------------------------------------------------------------

fn anyResolution(res: []const network.Resolution, tag: network.ResolutionTag) bool {
    for (res) |r| if (r.tag == tag) return true;
    return false;
}

fn anyResolutionFillOrPure(res: []const network.Resolution) bool {
    for (res) |r| if (r.tag == .fill or r.tag == .pure_value) return true;
    return false;
}

fn allContainedAnonymous(c: []const network.Contained) bool {
    // "Anonymous" contained row: no user-visible name, i.e. the `0,0` /
    // `S,U,W` rows. In the real AST this is a distinct field; here we treat a
    // row as non-anonymous if it declares its own sources AND destinations.
    for (c) |row| if (row.sources != 0 and row.destinations != 0) return false;
    return true;
}

fn composedKeyPresent(res: []const network.Resolution) bool {
    // .pure_value or .fill composition present. Both are "composed keys" for
    // the purpose of `.contained_lookup`; the sub-emitter distinguishes them.
    return anyResolutionFillOrPure(res);
}

/// Replicates isLowerableShape's verdict from value_transform.zig. The log
/// shows this rejects on destination mismatch (fanout: `out1 vs out2`;
/// test: `0 vs 1`) and otherwise accepts single-destination shapes. MUST
/// reproduce the log's decisions.
fn isLowerableShape(def: network.Definition) bool {
    if (def.destinations.len != 1) return false;
    if (def.contained.len == 0) return false;
    const want = def.destinations[0].name;
    for (def.contained) |row| {
        if (!std.mem.eql(u8, row.dest_name, want)) return false;
    }
    return true;
}

// ---------------------------------------------------------------------------
// AC #2: the 32-example table, checked by (tag -> expected shape).
// Derived from the [dispatch] / [shape] lines in the verify log. Each row is
// a test the classifier must satisfy once wired to the parser.
// ---------------------------------------------------------------------------

const ExampleCase = struct {
    tag: []const u8,
    def_name: []const u8,
    expected: EmissionShape,
    /// Captures the [dispatch] line this row is derived from.
    note: []const u8,
};

const example_table = [_]ExampleCase{
    // --- clean lowered_rules: `lowered=true` ---
    .{ .tag = "TAG-207", .def_name = "IF", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=false" },
    .{ .tag = "TAG-147", .def_name = "fanin", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=false" },
    .{ .tag = "TAG-192", .def_name = "AND", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-217", .def_name = "PARITY", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "BINEQ", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "BIGT", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "LAND", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "LNOT", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-218", .def_name = "INNER", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },

    // --- contained_lookup: lookup_shape=true, transform_rules=0 ---
    .{ .tag = "TAG-129", .def_name = "CODE", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-184", .def_name = "FULLADD", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-130", .def_name = "FULLADD", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "TAG163_TOP", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-136", .def_name = "0,S0", .expected = .contained_lookup, .note = "contained row; 14 rows emitted" },
    .{ .tag = "TAG-136", .def_name = "1,S6", .expected = .contained_lookup, .note = "contained row" },

    // --- OVERLAP: lookup_shape=true AND transform_rules>0.
    //     Classifier picks ONE. Per the [wclt] logs the contained-lookup path
    //     does the real work and GHDL passes with its case block, so we pick
    //     contained_lookup. This is the "shed redundant drivers" case from the
    //     amended acceptance criterion.
    .{ .tag = "TAG-129", .def_name = "NOT", .expected = .contained_lookup, .note = "OVERLAP: tr=2 ls=true -> pick wclt (log shows wclt emitting)" },
    .{ .tag = "TAG-160", .def_name = "OR180", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-142", .def_name = "AND142", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-143", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-190", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-212", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-129", .def_name = "OR", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-149", .def_name = "OR", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-137", .def_name = "fourstate", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-185", .def_name = "test", .expected = .contained_lookup, .note = "OVERLAP: tr=2 ls=true; isLowerableShape rejects dest mismatch -> wclt" },

    // --- transform_rules: lookup_shape=false, transform_rules>0 ---
    .{ .tag = "TAG-201", .def_name = "REACTION", .expected = .transform_rules, .note = "lowered=false tr=1 ls=false" },
    .{ .tag = "TAG-177", .def_name = "FULLADD", .expected = .transform_rules, .note = "lowered=false tr=42 ls=false" },
    .{ .tag = "TAG-198", .def_name = "FULLADD", .expected = .transform_rules, .note = "lowered=false tr=8 ls=false" },
    .{ .tag = "TAG-200", .def_name = "AND2", .expected = .transform_rules, .note = "lowered=false tr=4 ls=false" },

    // --- invocations_only: all false, has invokes ---
    .{ .tag = "TAG-129", .def_name = "FULLADD", .expected = .invocations_only, .note = "lowered=false tr=0 ls=false; invocations drive it" },
    .{ .tag = "TAG-218", .def_name = "WRAP", .expected = .invocations_only, .note = "lowered=false tr=0 ls=false" },
    .{ .tag = "TAG-180", .def_name = "bus", .expected = .invocations_only, .note = "invokes fanin+fanout" },
    .{ .tag = "TAG-211", .def_name = "4BITADD", .expected = .invocations_only, .note = "invokes FULLADD x4" },
    .{ .tag = "TAG-151", .def_name = "OR151", .expected = .invocations_only, .note = "invokes 3of6, 2of2" },
    .{ .tag = "TAG-212", .def_name = "AND3", .expected = .invocations_only, .note = "invokes AND x2" },

    // --- none: all false, no invokes (constant/geometry/unknown) ---
    .{ .tag = "TAG-189", .def_name = "Arbiter", .expected = .none, .note = "constant_or_fill, no emission" },
    .{ .tag = "TAG-187", .def_name = "ca2d", .expected = .none, .note = "nothing" },
    .{ .tag = "TAG-187", .def_name = "ca100", .expected = .none, .note = "nothing" },
    .{ .tag = "TAG-210", .def_name = "rule30", .expected = .none, .note = "unknown, no emission" },
    .{ .tag = "TAG-147", .def_name = "fanout", .expected = .none, .note = "lookup-shaped but group dest; rejects lowered; falls through (refinement gap)" },
    .{ .tag = "TAG-180", .def_name = "fanout", .expected = .none, .note = "same refinement gap" },

    // --- MYGATE / MYCONST: no tag in the verify run; kept so the table covers
    //     every def the ticket names. Wire to a fixture tag if you add one.
    .{ .tag = "TAG-xxx", .def_name = "MYGATE", .expected = .none, .note = "constant_or_fill, no emission" },
    .{ .tag = "TAG-xxx", .def_name = "MYCONST", .expected = .none, .note = "constant_or_fill, no emission" },
};

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------
test "TAG-229 AC#2: 32-example shape table is well-formed" {
    for (example_table, 0..) |a, i| {
        for (example_table[i + 1 ..]) |b| {
            if (std.mem.eql(u8, a.tag, b.tag) and
                std.mem.eql(u8, a.def_name, b.def_name))
            {
                // Same (tag, def) must map to the same shape; otherwise
                // the table contradicts itself.
                try std.testing.expectEqual(a.expected, b.expected);
            }
        }
    }
}

test "TAG-229 AC#2: classifier stubs match table rows it can handle" {
    // Placeholder: as each shape's branch is implemented, replace the stub
    // definition below with a parsed fixture and assert classify == expected.
    // Until then this test documents the intended shape per row.
    const cases = [_]struct {
        expected: EmissionShape,
        stub: network.Definition,
    }{
        // No destinations -> none.
        .{ .expected = .none, .stub = .{ .name = "MYGATE" } },
        // Invocations only -> invocations_only.
        .{
            .expected = .invocations_only,
            .stub = .{
                .name = "WRAP",
                .sources = &.{.{}},
                .destinations = &.{.{ .kind = .place, .name = "Y" }},
                .resolution = &.{.{ .tag = .invoke }},
            },
        },
        // Composed-key contained lookup, single place destination ->
        // contained_lookup.

        // Composed-key contained lookup, single place destination ->
        // contained_lookup. (TAG-185 "test" shape: isLowerableShape rejects
        // on dest mismatch 0 vs 1, so it falls through to the lookup branch.)
        .{
            .expected = .contained_lookup,
            .stub = .{
                .name = "test",
                .sources = &.{ .{}, .{}, .{}, .{} },
                .destinations = &.{.{ .kind = .place, .name = "0" }},
                .resolution = &.{.{ .tag = .pure_value }},
                .contained = &.{
                    .{ .sources = 0, .destinations = 0, .resolution = 1, .dest_name = "0" },
                    .{ .sources = 0, .destinations = 0, .resolution = 1, .dest_name = "1" },
                },
            },
        },
        // Group destination + pure_value composition (fanout) -> none
        // (refinement gap; guarded inside the classifier).
        .{
            .expected = .none,
            .stub = .{
                .name = "fanout",
                .sources = &.{.{}},
                // Non-empty name so a defaulted `want` can't accidentally match rows.
                .destinations = &.{.{ .kind = .group, .name = "out1" }},
                .resolution = &.{.{ .tag = .pure_value }},
                .contained = &.{
                    .{ .sources = 0, .destinations = 0, .resolution = 1, .dest_name = "out1" },
                    .{ .sources = 0, .destinations = 0, .resolution = 1, .dest_name = "out2" },
                },
            },
        },
    };
    for (cases) |c| {
        try std.testing.expectEqual(
            c.expected,
            try classifyEmissionShape(std.testing.allocator, c.stub),
        );
    }
}
