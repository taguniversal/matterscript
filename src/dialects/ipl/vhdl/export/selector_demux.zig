/// Responsibility: VHDL emission for selector-gated demultiplex shapes.
///
/// A `.selector_demux` definition (TAG-180 Example 12.11's `fanout`) is a
/// case block over a selector source that routes one routed source value to
/// one of N group-member destinations per arm. This module emits that case
/// block directly from the definition's contained rows; it does NOT go
/// through `decomposeRules` or `isLowerableShape`, because the shape is not a
/// lowering shape (its destinations are a group, not a single place).
///
/// Structural analogue: `value_transform_export.lowerRules` emits a case
/// block for the single-destination multiplex shape (`fanin`). This module is
/// the demultiplex counterpart. The two are deliberately separate: `fanin`'s
/// lowering goes through `decomposeRules`, which produces a `RuleSet` keyed
/// on the sources; `fanout`'s shape reads the contained rows' fills directly,
/// keyed on the row names. The case-block *emission* is structurally
/// identical; the path to the rule data is not.

const std = @import("std");
const network = @import("../../network.zig");
const sanitize = @import("../sanitizer.zig");
const constants = @import("../constants.zig");
const runtime_rules = @import("../../runtime/rules.zig");

/// Emit VHDL for a `.selector_demux` definition: a case block over the
/// selector source, with one arm per contained row, each arm filling one
/// group-member destination from the routed source.
///
/// Precondition (guaranteed by the classifier's step 4b guard and
/// `containedRowsAreSelectorGated`): the definition has exactly one group
/// destination, every contained row is anonymous with a single-token name and
/// a single `.fill` body, and exactly one source is unreferenced in the row
/// bodies (the selector).
///
/// `table` is the symbol table used for `data_value(N)` encoding of the
/// routed source's token. If the routed source's value is a symbol that has
/// not been interned, `data_value(N)` falls back to `data_value(0)` and a
/// debug warning is printed — the routed source is presumed to be a
/// symbol-valued place, and `lowerRules`'s `data_value(N)` convention applies.
pub fn writeSelectorDemux(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    table: runtime_rules.SymbolTable,
) !void {
    // 1. Find the selector: the one source not referenced in any row body.
    const selector = try findSelector(allocator, def);
    defer allocator.free(selector);

    // 2. Sanitize the selector's identifier for the sensitivity list and
    //    case key.
    const selector_id = try sanitize.sanitizeName(allocator, selector);
    defer allocator.free(selector_id);

    // 3. Group-member destinations, in source order, for the null-value
    //    prelude. `def.destinations[0]` is the group; its `.group.places`
    //    hold the members.
    const group = def.destinations[0].group orelse
        return error.SelectorDemuxRequiresGroupDestination;

    // 4. Null-value prelude: declare every group member to null_value at
    //    process entry, so unselected members stay incomplete per the
    //    completeness convention.
    try writer.print("\n  -- selector demux for {s}\n", .{selector});
    try writer.print("  process({s}, complete) begin\n", .{selector_id});
    for (group.places) |member| {
        const member_id = try sanitize.sanitizeName(allocator, member.name);
        defer allocator.free(member_id);
        try writer.print("    {s} <= null_value;\n", .{member_id});
    }
    try writer.print("    if complete = '1' then\n", .{});
    try writer.print("      case {s}({d} downto 1) is\n", .{ selector_id, constants.DATA_WIDTH });

    // 5. One arm per contained row: the case label is the row name
    //    (symbol-encoded via the symbol table, same as lowerRules's
    //    caseLabel), the body is the row's `.fill`: `dest <= src`.
    for (def.contained) |row| {
        const stmt = row.resolution[0];
        if (stmt != .fill) return error.SelectorDemuxRowMissingFill;
        const dest_name = stmt.fill.dest_name;
        const src_expr = std.mem.trim(u8, stmt.fill.expr, " \t\r\n");

        // The routed source expression is "$src" — strip the `$` and
        // sanitize the bare name. If the expr is more complex than a single
        // `$name` reference, that's not a shape this emitter handles.
        const src_name = stripDollar(src_expr) orelse
            return error.SelectorDemuxUnsupportedSourceExpr;
        const src_id = try sanitize.sanitizeName(allocator, src_name);
        defer allocator.free(src_id);
        const dest_id = try sanitize.sanitizeName(allocator, dest_name);
        defer allocator.free(dest_id);

        // Case label: the row name as a symbol-encoded literal.
        const label = try symbolCaseLabel(allocator, row.name, table);
        defer allocator.free(label);

        try writer.print("        when {s} => {s} <= {s};\n", .{ label, dest_id, src_id });
    }

    try writer.print("        when others => null;\n", .{});
    try writer.print("      end case;\n", .{});
    try writer.print("    end if;\n", .{});
    try writer.print("  end process;\n", .{});
}

/// Scan the row bodies' `.fill` expressions for `$`-references, count which
/// sources are referenced, and return the one source that is NOT referenced
/// (the selector). The classifier's `containedRowsAreSelectorGated` has
/// already verified that exactly one source is unreferenced and at least one
/// is referenced; this helper re-finds it deterministically.
fn findSelector(allocator: std.mem.Allocator, def: network.Definition) ![]const u8 {
    var referenced = std.StringHashMapUnmanaged(void).empty;
    defer referenced.deinit(allocator);

    for (def.contained) |row| {
        if (row.resolution.len != 1) continue;
        const stmt = row.resolution[0];
        if (stmt != .fill) continue;
        const expr = stmt.fill.expr;
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
                try referenced.put(allocator, expr[start..i], {});
            }
        }
    }

    for (def.sources) |src| {
        if (!referenced.contains(src.name)) {
            return allocator.dupe(u8, src.name);
        }
    }
    return error.SelectorDemuxNoSelector;
}

/// Return the bare name from a `$name` expression, or null if the expression
/// is anything other than a single `$`-prefixed identifier. Trailing
/// whitespace is presumed trimmed by the caller.
fn stripDollar(expr: []const u8) ?[]const u8 {
    if (expr.len < 2) return null;
    if (expr[0] != '$') return null;
    const name = expr[1..];
    for (name) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_')) return null;
    }
    return name;
}

/// Format a symbol name as a VHDL case label: intern it, encode it as a
/// DATA_WIDTH-wide binary string. Mirrors `value_transform.caseLabel` for the
/// single-symbol case; the multi-symbol concatenation form is not needed here
/// (row names are single tokens).
fn symbolCaseLabel(
    allocator: std.mem.Allocator,
    name: []const u8,
    table: runtime_rules.SymbolTable,
) ![]const u8 {
    const id = table.lookup(name) orelse {
        // Symbol not interned: emit the name as a bare string literal. This
        // matches the case-block convention when the selector's value space
        // is the row names themselves, and a symbol table is not available
        // for them (which is the common case for `.selector_demux` — the
        // selector is not part of the routed source's symbol encoding).
        return std.fmt.allocPrint(allocator, "\"{s}\"", .{name});
    };
    const width = constants.DATA_WIDTH;
    var bits: [64]u8 = undefined;
    const s = @import("../lookup.zig").binStr(&bits, id, width);
    return std.fmt.allocPrint(allocator, "\"{s}\"", .{s});
}