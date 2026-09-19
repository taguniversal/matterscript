/// Responsibility: Handling constant ROM table lookups and key-signal generation.
// vhdl/export/rom_lookup.zig
const std = @import("std");
const network = @import("../../network.zig");
const sanitizer = @import("../sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;
const lookup = @import("../lookup.zig");
const constants = @import("../constants.zig");

pub fn writeKeyComposition(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
) !void {
    for (def.constants) |tbl| {
        const tbl_id = try sanitizeName(allocator, tbl.composed_name);
        defer allocator.free(tbl_id);

        try writer.print("\n  -- key composition for {s}\n", .{tbl.composed_name});
        try writer.print("  {s}_key <= ", .{tbl_id});

        var i: usize = 0;
        var first = true;
        const cn = tbl.composed_name;
        while (i < cn.len) {
            if (cn[i] == '$') {
                i += 1;
                const start = i;
                while (i < cn.len and cn[i] != '$' and cn[i] != '(') i += 1;
                const sname = cn[start..i];
                if (!first) try writer.print(" & ", .{});
                try writer.print("{s}(7 downto 1)", .{sname});
                first = false;
            } else i += 1;
        }
        try writer.print(";\n", .{});
    }
}
pub fn writeRomLookupProcess(
    allocator: std.mem.Allocator,
    writer: anytype,
    def: network.Definition,
) !void {
    for (def.constants) |tbl| {
        const tbl_id = try sanitizeName(allocator, tbl.composed_name);
        defer allocator.free(tbl_id);
        const val_bits = try lookup.tableValueWidth(allocator, tbl);

        try writer.print("\n  -- ROM lookup for {s}\n", .{tbl.composed_name});
        try writer.print("  process({s}_key, complete) begin\n", .{tbl_id});
        try writer.print("    {s}_data  <= (others => '0');\n", .{tbl_id});
        try writer.print("    {s}_valid <= '0';\n", .{tbl_id});
        try writer.print("    if complete = '1' then\n", .{});
        try writer.print("      case {s}_key is\n", .{tbl_id});

        switch (tbl.kind) {
            .explicit => |entries| {
                var key_buf: [128]u8 = undefined;
                var val_buf: [64]u8 = undefined;
                for (entries) |entry| {
                    var key_pos: usize = 0;
                    for (entry.key) |ch| {
                        const dv: u64 = ch - '0';
                        const seg = lookup.binStr(key_buf[key_pos..], dv, constants.DATA_WIDTH);
                        key_pos += seg.len;
                    }
                    const key_str = key_buf[0..key_pos];
                    const val_int = std.fmt.parseInt(u64, entry.value, 10) catch 0;
                    const val_str = lookup.binStr(&val_buf, val_int, val_bits);
                    try writer.print("        when \"{s}\" => {s}_data <= \"{s}\"; {s}_valid <= '1';\n", .{ key_str, tbl_id, val_str, tbl_id });
                }
            },
            .generate => {
                // TODO
            },
        }

        try writer.print("        when others => null;\n", .{});
        try writer.print("      end case;\n    end if;\n  end process;\n", .{});
    }
}
