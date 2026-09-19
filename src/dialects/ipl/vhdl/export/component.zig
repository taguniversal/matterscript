const network = @import("../../network.zig");


pub fn writeComponentDeclaration(
    writer: anytype,
    inv: network.Invocation,
    component_id: []const u8,
) !void {
    const port_count = inv.sources.len + inv.destinations.len;
    if (port_count == 0) {
        try writer.print("  component {s}\n  end component;\n\n", .{component_id});
        return;
    }

    try writer.print("  component {s}\n    port(\n", .{component_id});

    for (inv.sources, 0..) |_, i| {
        const last = (i + 1 == port_count);
        try writer.print("      arg_{d} : in ncl_signal{s}\n", .{ i, if (last) "" else ";" });
    }
    for (inv.destinations, 0..) |_, i| {
        const absolute_i = i + inv.sources.len;
        const last = (absolute_i + 1 == port_count);
        try writer.print("      output_{d} : out ncl_signal{s}\n", .{ i, if (last) "" else ";" });
    }
    try writer.print("    );\n  end component;\n\n", .{});
}