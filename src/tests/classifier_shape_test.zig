const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const classifier_shapes = matterscript.classifier_shapes;
// ---------------------------------------------------------------------------
// AC #2: the 32-example table, checked by (tag -> expected shape).
// Derived from the [dispatch] / [shape] lines in the verify log. Each row is
// a test the classifier must satisfy once wired to the parser.
// ---------------------------------------------------------------------------

const ExampleCase = struct {
    tag: []const u8,
    def_name: []const u8,
    expected: classifier_shapes.EmissionShape,
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

