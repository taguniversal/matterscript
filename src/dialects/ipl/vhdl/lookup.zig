const std = @import("std");
const evaluator = @import("evaluator.zig");
const network = @import("../network.zig");
const sanitizer = @import("sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;
const constants =   @import("constants.zig");
const SIGNAL_WIDTH = constants.SIGNAL_WIDTH;
const DATA_WIDTH = constants.DATA_WIDTH;

// Responsibility: Generates VHDL lookup tables, handles symbol interning,
// constructs case-statement blocks, and emits VHDL for cellular automata networks.

fn containsString(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |item| {
        if (std.mem.eql(u8, item, needle)) return true;
    }
    return false;
}

fn getUniqueStateTokens(
    allocator: std.mem.Allocator,
    entries: []const evaluator.GeneratedEntry,
) ![]const []const u8 {
    var tokens: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer tokens.deinit(allocator);

    for (entries) |entry| {
        // Collect pattern tokens (e.g. "DE", "AK", "JD")
        for (entry.pattern) |tok| {
            if (!containsString(tokens.items, tok)) {
                try tokens.append(allocator, tok);
            }
        }
        // Collect target output state (e.g. "JC")
        if (!containsString(tokens.items, entry.target_state)) {
            try tokens.append(allocator, entry.target_state);
        }
    }

    return tokens.toOwnedSlice(allocator);
}

pub fn emitCellularAutomatonVHDL(
    allocator: std.mem.Allocator,
    writer: anytype,
    entries: []const evaluator.GeneratedEntry,
) !void {
    const states = try getUniqueStateTokens(allocator, entries);
    defer allocator.free(states);

    // 1. Emit VHDL Custom Type Definition for symbolic states
    try writer.writeAll("  -- Symbolic Cell State Enumeration\n");
    try writer.writeAll("  TYPE cell_state_t IS (");
    for (states, 0..) |st, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("ST_{s}", .{st});
    }
    try writer.writeAll(");\n\n");

    // 2. Emit Cell Combinatorial / Synchronous Next-State Logic
    try writer.writeAll("  -- Cell State Transition Process\n");
    try writer.writeAll("  process(clk, reset)\n");
    try writer.writeAll("  begin\n");
    try writer.writeAll("    if reset = '1' then\n");
    if (states.len > 0) {
        try writer.print("      current_state <= ST_{s};\n", .{states[0]});
    }
    try writer.writeAll("    elif rising_edge(clk) then\n");

    // Iterate rules to emit pattern matching branch logic
    for (entries, 0..) |entry, idx| {
        const branch_keyword = if (idx == 0) "      if" else "      elsif";

        // Assume standard 1D/2D neighborhood mapping: [0]=Left, [1]=Center/Self, [2]=Right
        if (entry.pattern.len >= 3) {
            try writer.print(
                "{s} (neighbor_L = ST_{s} AND current_state = ST_{s} AND neighbor_R = ST_{s}) then\n",
                .{ branch_keyword, entry.pattern[0], entry.pattern[1], entry.pattern[2] },
            );
            try writer.print("        next_state <= ST_{s};\n", .{entry.target_state});
        }
    }

    if (entries.len > 0) {
        try writer.writeAll("      else\n");
        try writer.writeAll("        next_state <= current_state; -- Default: retain state\n");
        try writer.writeAll("      end if;\n");
    }

    try writer.writeAll("    end if;\n");
    try writer.writeAll("  end process;\n");
}

/// Builds one symbol table shared across an ENTIRE contained-lookup
/// definition — every comma-separated key segment in every row's
/// name, and every row's own value (a bare pure_value, or each named
/// fill's expr), all interned into the same table. Sharing it across
/// the whole definition (not per-destination) matters for state
/// machines: "S1" must encode to the same integer whether it appears
/// in a key segment or a fill value, since a destination's output can
/// feed back as a future invocation's source.
fn buildSharedSymbolTable(
    allocator: std.mem.Allocator,
    contained: []const network.Definition,
) !std.ArrayListUnmanaged([]const u8) {
    var symbols: std.ArrayListUnmanaged([]const u8) = .empty;
    for (contained) |row| {
        var it = std.mem.splitScalar(u8, row.name, ',');
        while (it.next()) |seg| {
            _ = try internSymbol(&symbols, allocator, std.mem.trim(u8, seg, " \t\r\n"));
        }
        for (row.resolution) |stmt| {
            const value_text = switch (stmt) {
                .pure_value => |v| v,
                .fill => |f| f.expr,
                .invoke => continue,
                .directive => continue, // TODO
            };
            _ = try internSymbol(&symbols, allocator, std.mem.trim(u8, value_text, " \t\r\n"));
        }
    }
    return symbols;
}

/// Emits one ROM/case-select for a single outer destination.
/// `anonymous` selects how to read each row's value: true means every
/// row is a single bare pure_value (OR/AND/NOT's shape) and
/// `dest_name` is fixed externally (the triggering fill's own
/// destination); false means each row may carry a named fill for
/// `dest_name` specifically (TAG-136's shape) — a row missing a fill
/// for this destination is simply skipped, correctly leaving that
/// case to `others` per Fant's Occasional Output (§12.5.6).
fn writeLookupCaseBlock(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
    dest_name: []const u8,
    symbols: *std.ArrayListUnmanaged([]const u8),
    anonymous: bool,
) !void {
    const dest_id = try sanitizeName(allocator, dest_name);
    defer allocator.free(dest_id);

    try writer.print("\n  -- lookup for {s}\n", .{dest_name});
    try writer.print("  process(", .{});
    for (def.sources, 0..) |source, i| {
        if (i > 0) try writer.print(", ", .{});
        const source_id = try sanitizeName(allocator, source.name);
        defer allocator.free(source_id);
        try writer.print("{s}", .{source_id});
    }
    try writer.print(", complete) begin\n" ++
        "    {s} <= null_value;\n" ++
        "    if complete = '1' then\n" ++
        "      case ", .{dest_id});
    for (def.sources, 0..) |source, i| {
        const source_id = try sanitizeName(allocator, source.name);
        defer allocator.free(source_id);
        if (i > 0) try writer.print(" & ", .{});
        try writer.print("{s}({d} downto 1)", .{ source_id, SIGNAL_WIDTH - 1 });
    }
    try writer.print(" is\n", .{});

    for (def.contained) |row| {
        var value_text: ?[]const u8 = null;
        if (anonymous) {
            value_text = row.resolution[0].pure_value;
        } else {
            for (row.resolution) |stmt| {
                if (stmt == .fill and std.mem.eql(u8, stmt.fill.dest_name, dest_name)) {
                    value_text = stmt.fill.expr;
                    break;
                }
            }
        }
        const vt = value_text orelse continue;

        var key_buf: [128]u8 = undefined;
        var key_pos: usize = 0;
        var it = std.mem.splitScalar(u8, row.name, ',');
        while (it.next()) |seg| {
            const seg_value = try internSymbol(symbols, allocator, std.mem.trim(u8, seg, " \t\r\n"));
            const piece = binStr(key_buf[key_pos..], seg_value, DATA_WIDTH);
            key_pos += piece.len;
        }
        const key_str = key_buf[0..key_pos];

        const out_value = try internSymbol(symbols, allocator, std.mem.trim(u8, vt, " \t\r\n"));
        try writer.print("        when \"{s}\" => {s} <= data_value({d});\n", .{ key_str, dest_id, out_value });
    }

    try writer.print("        when others => null;\n" ++
        "      end case;\n" ++
        "    end if;\n" ++
        "  end process;\n", .{});
}

/// Detects which of the two contained-lookup shapes (if either)
/// applies to `def`, and dispatches to writeLookupCaseBlock
/// accordingly. See writeLookupCaseBlock's doc comment for the shapes.
pub fn writeContainedLookupTable(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
) !bool {
    if (def.sources.len == 0 or def.contained.len == 0) return false;

    for (def.contained) |row| {
        if (row.sources.len != 0 or row.destinations.len != 0) return false;
        var seg_count: usize = 1;
        for (row.name) |ch| {
            if (ch == ',') seg_count += 1;
        }
        if (seg_count != def.sources.len) return false;
        if (row.resolution.len == 0) return false;
    }

    var all_anonymous = true;
    var all_structured = true;
    for (def.contained) |row| {
        if (!(row.resolution.len == 1 and row.resolution[0] == .pure_value)) all_anonymous = false;
        for (row.resolution) |stmt| {
            if (stmt != .fill) all_structured = false;
        }
    }
    if (!all_anonymous and !all_structured) return false;

    var symbols = try buildSharedSymbolTable(allocator, def.contained);

    if (symbols.items.len > 0) {
        try writer.print("  -- symbol encoding: ", .{});
        for (symbols.items, 0..) |sym, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("{s}={d}", .{ sym, i });
        }
        try writer.print("\n", .{});
    }

    if (all_anonymous) {
        for (def.resolution) |stmt| {
            if (stmt != .fill) continue;
            const f = stmt.fill;
            var mentions_all = true;
            for (def.sources) |s| {
                if (std.mem.indexOf(u8, f.expr, s.name) == null) mentions_all = false;
            }
            if (!mentions_all) continue;
            try writeLookupCaseBlock(allocator, writer, def, f.dest_name, &symbols, true);
            return true;
        }
        return false;
    }

    var covered: std.ArrayListUnmanaged([]const u8) = .empty;
    for (def.contained) |row| {
        for (row.resolution) |stmt| {
            const dname = stmt.fill.dest_name;
            var have = false;
            for (covered.items) |c| {
                if (std.mem.eql(u8, c, dname)) {
                    have = true;
                    break;
                }
            }
            if (!have) try covered.append(allocator, dname);
        }
    }
    for (covered.items) |dest_name| {
        try writeLookupCaseBlock(allocator, writer, def, dest_name, &symbols, false);
    }
    return true;
}

fn internSymbol(list: *std.ArrayListUnmanaged([]const u8), allocator: std.mem.Allocator, token: []const u8) !u64 {
    if (std.fmt.parseInt(u64, token, 10)) |n| return n else |_| {}
    for (list.items, 0..) |existing, i| {
        if (std.mem.eql(u8, existing, token)) return @intCast(i);
    }
    try list.append(allocator, try allocator.dupe(u8, token));
    return @intCast(list.items.len - 1);
}

// count $ signs in composed name to determine key width
pub fn countSources(composed: []const u8) usize {
    var count: usize = 0;
    for (composed) |c| if (c == '$') {
        count += 1;
    };
    return count;
}

pub fn tableValueWidth(allocator: std.mem.Allocator, tbl: network.TableDef) !usize {
    var max_val: u64 = 0;
    switch (tbl.kind) {
        .explicit => |entries| {
            for (entries) |e| {
                const v = std.fmt.parseInt(u64, e.value, 10) catch 0;
                if (v > max_val) max_val = v;
            }
        },
        .generate => {
            _ = allocator;
            // TODO
        },
    }
    if (max_val == 0) return 1;
    var bits: usize = 0;
    var v = max_val;
    while (v > 0) : (v >>= 1) bits += 1;
    return bits;
}

pub fn binStr(buf: []u8, val: u64, width: usize) []u8 {
    var i: usize = 0;
    while (i < width) : (i += 1) {
        const bit = (val >> @intCast(width - 1 - i)) & 1;
        buf[i] = if (bit == 1) '1' else '0';
    }
    return buf[0..width];
}
