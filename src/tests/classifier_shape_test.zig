const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const classifier_shapes = matterscript.classifier_shapes;
const network = matterscript.network;
const parser = matterscript.ipl_parser;
const value_transform_analysis = matterscript.value_transform_analysis;
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
    .{ .tag = "TAG-147", .def_name = "fanin", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=false" },
    .{ .tag = "TAG-163", .def_name = "BINEQ", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "BIGT", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "LAND", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "LNOT", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-192", .def_name = "AND", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-207", .def_name = "IF", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=false" },
    .{ .tag = "TAG-217", .def_name = "PARITY", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-218", .def_name = "INNER", .expected = .lowered_rules, .note = "lowered=true transform_rules=0 lookup_shape=true" },

    // --- contained_lookup: lookup_shape=true, transform_rules=0 ---
    .{ .tag = "TAG-130", .def_name = "FULLADD130", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-163", .def_name = "TAG163_TOP", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },
    .{ .tag = "TAG-184", .def_name = "FULLADD184", .expected = .contained_lookup, .note = "lowered=false transform_rules=0 lookup_shape=true" },

    // --- OVERLAP: lookup_shape=true AND transform_rules>0.
    //     Classifier picks ONE. Per the [wclt] logs the contained-lookup path
    //     does the real work and GHDL passes with its case block, so we pick
    //     contained_lookup. This is the "shed redundant drivers" case from the
    //     amended acceptance criterion.
    .{ .tag = "TAG-129", .def_name = "NOT129", .expected = .contained_lookup, .note = "OVERLAP: tr=2 ls=true -> pick wclt (log shows wclt emitting)" },
    .{ .tag = "TAG-129", .def_name = "OR129", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-137", .def_name = "fourstate", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-142", .def_name = "AND142", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-143", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-149", .def_name = "OR149", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-160", .def_name = "OR180", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-185", .def_name = "test", .expected = .contained_lookup, .note = "OVERLAP: tr=2 ls=true; isLowerableShape rejects dest mismatch -> wclt" },
    .{ .tag = "TAG-190", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },
    .{ .tag = "TAG-212", .def_name = "AND", .expected = .contained_lookup, .note = "OVERLAP: tr=4 ls=true -> pick wclt" },

    // --- transform_rules: lookup_shape=false, transform_rules>0 ---
    .{ .tag = "TAG-177", .def_name = "FULLADD177", .expected = .contained_lookup, .note = "lowered=false tr=42 ls=false" },
    .{ .tag = "TAG-198", .def_name = "FULLADD198", .expected = .contained_lookup, .note = "lowered=false tr=8 ls=false" },
    .{ .tag = "TAG-200", .def_name = "AND2", .expected = .contained_lookup, .note = "dual-rail; classifier picks contained_lookup; verify passes 4/4" },
    .{ .tag = "TAG-201", .def_name = "REACTION", .expected = .contained_lookup, .note = "Multi-emission fills; classifier picks contained_lookup, verify passes GHDL+runtime" },

    // --- invocations_only: all false, has invokes ---
    .{ .tag = "TAG-129", .def_name = "FULLADD129", .expected = .invocations_only, .note = "lowered=false tr=0 ls=false; invocations drive it" },
    .{ .tag = "TAG-151", .def_name = "OR151", .expected = .invocations_only, .note = "invokes 3of6, 2of2" },
    .{ .tag = "TAG-180", .def_name = "bus", .expected = .invocations_only, .note = "invokes fanin+fanout" },
    .{ .tag = "TAG-211", .def_name = "4BITADD", .expected = .invocations_only, .note = "invokes FULLADD x4" },
    .{ .tag = "TAG-212", .def_name = "AND3", .expected = .invocations_only, .note = "invokes AND x2" },
    .{ .tag = "TAG-218", .def_name = "WRAP", .expected = .invocations_only, .note = "lowered=false tr=0 ls=false" },

    // --- none: all false, no invokes (constant/geometry/unknown) ---
    .{ .tag = "TAG-147", .def_name = "fanout", .expected = .none, .note = "lookup-shaped but group dest; rejects lowered; falls through (refinement gap)" },
    .{ .tag = "TAG-180", .def_name = "fanout", .expected = .none, .note = "same refinement gap" },
    .{ .tag = "TAG-189", .def_name = "Arbiter", .expected = .none, .note = "constant_or_fill, no emission" },
    .{ .tag = "TAG-210", .def_name = "rule30", .expected = .none, .note = "unknown, no emission" },
};

fn loadNetworkForTag(allocator: std.mem.Allocator, tag: []const u8) !network.Network {
    const io = std.testing.io;
    const root = repoRoot();

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/examples/docs/{s}", .{root,tag});

    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
    std.debug.print("loadNetworkForTag: openDir('{s}') failed: {s}\n", .{ dir_path, @errorName(err) });
    return err;
};
    defer dir.close(io);

    var it = dir.iterate();
    var ipl_name: ?[]u8 = null;
    errdefer if (ipl_name) |n| allocator.free(n);
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".ms.ipl")) continue;
        if (ipl_name != null) return error.MultipleIplFilesInExample;
        ipl_name = try allocator.dupe(u8, entry.name);
    }
    const name = ipl_name orelse return error.NoIplFileInExample;
    defer allocator.free(name);

    // KEY: src is allocated in the arena, not the raw allocator. No free
    // here -- the arena outlives the returned Network's slices.
    const src = try dir.readFileAlloc(io, name, allocator, .limited(1 << 20));

    return try parser.parse(allocator, src);
}

fn findDefinition(net: network.Network, name: []const u8) ?network.Definition {
    for (net.definitions) |def| {
        if (std.mem.eql(u8, def.name, name)) return def;
    }
    return null;
}

fn repoRoot() []const u8 {
    // src/tests/classifier_shape_test.zig -> go up 3 to repo root
    const this_file = @src().file;
    const dir_of_test = std.fs.path.dirname(this_file) orelse ".";
    const src_dir = std.fs.path.dirname(dir_of_test) orelse ".";
    return std.fs.path.dirname(src_dir) orelse ".";
}

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
test "TAG-229 AC#2: classifier matches the table for every example" {
    for (example_table) |case| {
        var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();

        const net = try loadNetworkForTag(arena, case.tag);
        std.debug.print("TAG {s}: {d} top-level defs:", .{ case.tag, net.definitions.len });
        for (net.definitions) |d| std.debug.print(" '{s}'", .{d.name});
        std.debug.print("\n", .{});
        const def = findDefinition(net, case.def_name) orelse {
            std.debug.print(
                "example {s}: definition '{s}' not found in network\n",
                .{ case.tag, case.def_name },
            );
            return error.DefinitionNotFound;
        };

        const transform_rules = try value_transform_analysis.collectValueTransformRules(arena, def);
        const shape = try classifier_shapes.classifyEmissionShape(arena, def, transform_rules);
        if (shape != case.expected) {
            std.debug.print(
                "example {s} def '{s}': expected {s}, got {s}\n  note: {s}\n",
                .{ case.tag, case.def_name, @tagName(case.expected), @tagName(shape), case.note },
            );
        }

        if (shape != case.expected) {
            std.debug.print(
                "MISMATCH {s}/{s}\n" ++
                    "  dests.len={d} dest[0].name='{s}' kind={any}\n" ++
                    "  contained.len={d} res.len={d}\n" ++
                    "  allAnon={} hasFillOrPure={}\n",
                .{
                    case.tag,                                                           case.def_name,
                    def.destinations.len,                                               if (def.destinations.len > 0) def.destinations[0].name else "<none>",
                    if (def.destinations.len > 0) def.destinations[0].kind else .place, def.contained.len,
                    def.resolution.len,                                                 classifier_shapes.allContainedAnonymous(def.contained),
                    classifier_shapes.hasFillOrPure(def.resolution),
                },
            );
        }
        try std.testing.expectEqual(case.expected, shape);
    }
}
