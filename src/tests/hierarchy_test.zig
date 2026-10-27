const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const hierarchy = matterscript.hierarchy;
const parser = matterscript.ipl_parser;
const network = matterscript.network;
const runtime_rules = matterscript.runtime.rules;

/// Helper: find a symbol's id in a table, or null if absent.
fn lookup(table: runtime_rules.SymbolTable, name: []const u8) ?u64 {
    return table.lookup(name);
}

// ---------------------------------------------------------------------
// Standalone definitions get their own table
// ---------------------------------------------------------------------

test "hierarchy: single standalone definition gets its own table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND2[(A<> B<>)(Y<>)
        \\  $A$B() : 0,0[Y<0>] 0,1[Y<0>] 1,0[Y<0>] 1,1[Y<1>]
        \\]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    try testing.expectEqual(@as(usize, 1), tables.by_name.count());
    const t = tables.get("AND2") orelse return error.NoTable;
    // A 2-symbol-key table interns the four key segments and the two
    // values (0 and 1) — 0, 1 present; the F/T symbols are the values.
    try testing.expect(lookup(t, "0") != null);
    try testing.expect(lookup(t, "1") != null);
}

// ---------------------------------------------------------------------
// Two definitions, no invocation between them: separate tables
// ---------------------------------------------------------------------

test "hierarchy: two independent definitions get separate tables" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\AND2[(A<> B<>)(Y<>)
        \\  $A$B() : 0,0[Y<0>] 0,1[Y<0>] 1,0[Y<0>] 1,1[Y<1>]
        \\]
        \\OR2[(A<> B<>)(Y<>)
        \\  $A$B() : 0,0[Y<0>] 0,1[Y<1>] 1,0[Y<1>] 1,1[Y<1>]
        \\]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    try testing.expectEqual(@as(usize, 2), tables.by_name.count());

    const ta = tables.get("AND2") orelse return error.NoTable;
    const tb = tables.get("OR2") orelse return error.NoTable;

    // Both tables have "0" and "1" — but they're separate tables. The
    // ids may or may not align (in this case they will because both
    // intern in the same order), so the check is that we get
    // *independent* SymbolTable values, not that ids differ.
    // What we can verify: each table has its own entries slice.
    try testing.expect(lookup(ta, "0") != null);
    try testing.expect(lookup(tb, "0") != null);
}

// ---------------------------------------------------------------------
// Two definitions, one invokes the other: same table
// ---------------------------------------------------------------------

test "hierarchy: caller and callee share one table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\TOP[(A<> B<>)(Y<>)
        \\  INV($A $B)(T<>)
        \\  $T() : 0[T<1>] 1[T<0>]
        \\]
        \\INV[(X<>)(Z<>)
        \\  $X() : 0[Z<1>] 1[Z<0>]
        \\]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    const t_top = tables.get("TOP") orelse return error.NoTable;
    const t_inv = tables.get("INV") orelse return error.NoTable;

    // Same entries slice means same table.
    try testing.expectEqual(@intFromPtr(t_top.entries.ptr), @intFromPtr(t_inv.entries.ptr));
    try testing.expectEqual(t_top.entries.len, t_inv.entries.len);

    // Every symbol in either table is in the shared one.
    try testing.expect(lookup(t_top, "0") != null);
    try testing.expect(lookup(t_top, "1") != null);
}

// ---------------------------------------------------------------------
// Chain: A invokes B, B invokes C. All three share a table.
// ---------------------------------------------------------------------

test "hierarchy: transitive invocation chain shares one table" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\A[(X<>)(Y<>) B($X)(T<>) $T() : 0[T<1>] 1[T<0>] ]
        \\B[(X<>)(Y<>) C($X)(T<>) $T() : 0[T<1>] 1[T<0>] ]
        \\C[(X<>)(Y<>) $X() : 0[Y<1>] 1[Y<0>] ]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    const ta = tables.get("A") orelse return error.NoTable;
    const tb = tables.get("B") orelse return error.NoTable;
    const tc = tables.get("C") orelse return error.NoTable;

    try testing.expectEqual(@intFromPtr(ta.entries.ptr), @intFromPtr(tc.entries.ptr));
    try testing.expectEqual(@intFromPtr(tb.entries.ptr), @intFromPtr(tc.entries.ptr));
}

// ---------------------------------------------------------------------
// Two separate hierarchies in one file
// ---------------------------------------------------------------------

test "hierarchy: two separate invocation chains get separate tables" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\TOP1[(A<>)(Y<>) INV1($A)(T<>) $T() : 0[T<1>] 1[T<0>] ]
        \\INV1[(X<>)(Z<>) $X() : 0[Z<1>] 1[Z<0>] ]
        \\TOP2[(A<>)(Y<>) INV2($A)(T<>) $T() : 0[T<1>] 1[T<0>] ]
        \\INV2[(X<>)(Z<>) $X() : 0[Z<1>] 1[Z<0>] ]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    const t_top1 = tables.get("TOP1") orelse return error.NoTable;
    const t_inv1 = tables.get("INV1") orelse return error.NoTable;
    const t_top2 = tables.get("TOP2") orelse return error.NoTable;
    const t_inv2 = tables.get("INV2") orelse return error.NoTable;

    // Same pointer within a chain…
    try testing.expectEqual(@intFromPtr(t_top1.entries.ptr), @intFromPtr(t_inv1.entries.ptr));
    try testing.expectEqual(@intFromPtr(t_top2.entries.ptr), @intFromPtr(t_inv2.entries.ptr));

    // …and different pointers across chains.
    try testing.expect(@intFromPtr(t_top1.entries.ptr) != @intFromPtr(t_top2.entries.ptr));
}

// ---------------------------------------------------------------------
// Determinism: same input, same table across two builds
// ---------------------------------------------------------------------

test "hierarchy: build is deterministic" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\TOP[(A<> B<>)(Y<>)
        \\  INV($A $B)(T<>)
        \\  $T() : 0[T<1>] 1[T<0>]
        \\]
        \\INV[(X<>)(Z<>)
        \\  $X() : 0[Z<1>] 1[Z<0>]
        \\]
    ;

    const net1 = try parser.parse(a, src);
    const tables1 = try hierarchy.build(a, net1);
    const net2 = try parser.parse(a, src);
    const tables2 = try hierarchy.build(a, net2);

    const t1 = tables1.get("TOP") orelse return error.NoTable;
    const t2 = tables2.get("TOP") orelse return error.NoTable;

    // Same length and same symbol names in the same order.
    try testing.expectEqual(t1.entries.len, t2.entries.len);
    for (t1.entries, t2.entries) |s1, s2| {
        try testing.expectEqualStrings(s1, s2);
    }
}

// ---------------------------------------------------------------------
// Symbols interned in one definition are visible in another
// ---------------------------------------------------------------------

test "hierarchy: a symbol interned in the callee is visible to the caller" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // INV interns "TRUE" and "FALSE" in its own rules (its rows
    // mention them first). TOP's rows also mention them. With a
    // shared table, both definitions see the same id for "TRUE".
    const src =
        \\TOP[(A<>)(Y<>)
        \\  INV($A)(T<>)
        \\  $T() : TRUE[T<TRUE>] FALSE[T<FALSE>]
        \\]
        \\INV[(X<>)(Z<>)
        \\  $X() : 0[Z<TRUE>] 1[Z<FALSE>]
        \\]
    ;

    const net = try parser.parse(a, src);
    const tables = try hierarchy.build(a, net);

    const t_top = tables.get("TOP") orelse return error.NoTable;
    const t_inv = tables.get("INV") orelse return error.NoTable;

    const id_true_top = lookup(t_top, "TRUE") orelse return error.TrueNotInterned;
    const id_true_inv = lookup(t_inv, "TRUE") orelse return error.TrueNotInterned;
    try testing.expectEqual(id_true_top, id_true_inv);

    const id_false_top = lookup(t_top, "FALSE") orelse return error.FalseNotInterned;
    const id_false_inv = lookup(t_inv, "FALSE") orelse return error.FalseNotInterned;
    try testing.expectEqual(id_false_top, id_false_inv);
}