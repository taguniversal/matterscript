// src/tests/export_vhdl_test.zig
//
// API-level tests for the VHDL exporter: parse real IPL source
// through ipl_parser, feed the resulting Network into
// ipl_export_vhdl.write(), and assert on the generated text — no
// filesystem, no ghdl. This is the fast inner loop underneath the
// existing ghdl-based verify_examples acceptance suite: it can't
// prove the VHDL simulates correctly, but it isolates codegen bugs
// from parser bugs and from ghdl/toolchain issues, and it runs in
// milliseconds instead of a full build+ghdl round trip.
//
// Private-function tests (sanitizeName, etc.) live inside
// export_vhdl.zig itself instead of here — see the note near the
// bottom of that file for why.

const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const parser = matterscript.ipl_parser;
const exporter = matterscript.ipl_export_vhdl;

/// Parses `src` and exports it to a string. Caller's arena owns the
/// result along with everything the parser/exporter allocated.
fn exportToString(allocator: std.mem.Allocator, src: []const u8) ![]const u8 {
    const net = try parser.parse(allocator, src);
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try exporter.write(allocator, &aw.writer, net);
    return try allocator.dupe(u8, aw.written());
}

test "a definition with an explicit named destination list still emits an entity" {
    // Regression test for a bug where writeDefinition's entity and
    // architecture emission were accidentally nested entirely inside
    // `if (def.destinations.len == 0)`. Any definition using an
    // explicit destination list — like FULLADD's ($SUM $CARRY) —
    // silently produced no VHDL at all as a result. That's what made
    // ghdl report `unit "fulladd" not found in library "work"`: the
    // entity was simply never written.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\MYGATE[(a<> b<>) ($q)
        \\  q<1>
        \\]
    ;

    const vhdl = try exportToString(allocator, src);
    try testing.expect(std.mem.indexOf(u8, vhdl, "entity mygate is") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "architecture rtl of mygate is") != null);
}

test "a definition with no destination list still uses the synthesized 'result' output" {
    // Companion to the test above: makes sure fixing the brace bug
    // didn't disturb the §12.3.4 implicit-single-return path that
    // was already working (TAG-163/TAG-187's shape).
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "MYCONST[()<1>]";

    const vhdl = try exportToString(allocator, src);
    try testing.expect(std.mem.indexOf(u8, vhdl, "entity myconst is") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "result") != null);
}

test "composed two-variable lookup with comma-separated keys resolves to a case statement" {
    // Correction from two passes ago: I'd claimed this worked, then
    // found it didn't (comma rows were routed to a since-deleted
    // parseTruthTableRow, producing a row shape writeContainedLookupTable
    // rejected, falling through to the same undeclared "ab" signal bug
    // as the concatenated-key case). Now that parseContainedSection
    // routes every row through parseDefinition uniformly, it actually
    // does resolve to a real case-select ROM.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\OR[(A<>B<>)
        \\  <$A$B()>
        \\  :
        \\   0,0[0]
        \\   0,1[1]
        \\   1,0[1]
        \\   1,1[1] ]
    ;

    const vhdl = try exportToString(allocator, src);
    try testing.expect(std.mem.indexOf(u8, vhdl, "case ") != null);
    try testing.expect(std.mem.indexOf(u8, vhdl, "<= ab;") == null);
}

test "a comma-keyed contained definition never produces consecutive underscores when scoped" {
    // Softer claim than an earlier pass made here: this input no
    // longer exercises the anonymous-naming mechanism at all (no
    // parser path leaves Definition.name empty any more — see
    // parser_test.zig's canonicalizeNames unit test for that), since
    // "X,Y[SUM<X>]" now parses with the real name "X,Y". This is now
    // just a general safety-net check that sanitizeName's
    // underscore-collapsing holds up end-to-end for a comma-bearing
    // identifier, not a reproduction of the original bug report.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const src =
        \\CODE[(X<> Y<>)($OUT)
        \\  OUT<$X$Y()>
        \\: X,Y[SUM<X>]
        \\]
    ;

    const vhdl = try exportToString(allocator, src);
    try testing.expect(std.mem.indexOf(u8, vhdl, "__") == null);
}