const std = @import("std");
const matterscript = @import("matterscript");

const lookup = matterscript.lookup;
const evaluator = matterscript.evaluator;
const network = matterscript.network;

test "binStr generates exact binary representation with given width" {
    var buf: [64]u8 = undefined;

    const b1 = lookup.binStr(&buf, 5, 4);
    try std.testing.expectEqualSlices(u8, "0101", b1);

    const b2 = lookup.binStr(&buf, 0, 3);
    try std.testing.expectEqualSlices(u8, "000", b2);

    const b3 = lookup.binStr(&buf, 3, 2);
    try std.testing.expectEqualSlices(u8, "11", b3);
}

test "countSources counts dollar signs correctly" {
    try std.testing.expectEqual(@as(usize, 0), lookup.countSources("signal_a"));
    try std.testing.expectEqual(@as(usize, 1), lookup.countSources("signal$a"));
    try std.testing.expectEqual(@as(usize, 3), lookup.countSources("a$b$c$d"));
}

test "writeContainedLookupTable handles anonymous pure-value definitions" {
    const allocator = std.testing.allocator;

    const sources = [_]network.Arg{
        .{ .name = "A", .kind = network.ArgKind.place },
        .{ .name = "B", .kind = network.ArgKind.place },
    };

    const row1_res = [_]network.Statement{
        .{ .pure_value = "0" },
    };
    const row2_res = [_]network.Statement{
        .{ .pure_value = "1" },
    };

    const contained = [_]network.Definition{
        .{
            .name = "0,0",
            .sources = &[_]network.Arg{},
            .destinations = &[_]network.Arg{},
            .constants = &[_]network.TableDef{},
            .resolution = &row1_res,
        },
        .{
            .name = "0,1",
            .sources = &[_]network.Arg{},
            .destinations = &[_]network.Arg{},
            .constants = &[_]network.TableDef{},
            .resolution = &row2_res,
        },
    };

    const outer_res = [_]network.Statement{
        .{
            .fill = .{
                .dest_name = "RESULT",
                .expr = "A B",
            },
        },
    };

    const def = network.Definition{
        .name = "AND_LUT",
        .sources = &sources,
        .destinations = &[_]network.Arg{},
        .constants = &[_]network.TableDef{},
        .contained = &contained,
        .resolution = &outer_res,
    };

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const handled = try lookup.writeContainedLookupTable(allocator, &aw.writer, def);
    try std.testing.expect(handled);

    const vhdl = aw.written();
    std.debug.print("\n---VHDL OUTPUT---\n{s}\n---END---\n", .{vhdl});

    // Verify symbol encoding header
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "-- symbol encoding: 0=0, 1=1") != null);

    // Verify lookup block generation for RESULT
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "-- lookup for RESULT") != null);
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "when \"0000\" => result <= data_value(0);") != null);
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "when \"0001\" => result <= data_value(1);") != null);
    
   }

test "writeContainedLookupTable handles structured named-fill definitions" {
    const allocator = std.testing.allocator;

    const sources = [_]network.Arg{
        .{ .name = "S0", .kind = network.ArgKind.place },
    };

    const row1_res = [_]network.Statement{
        .{
            .fill = .{
                .dest_name = "STATE_OUT",
                .expr = "S1",
            },
        },
    };

    const contained = [_]network.Definition{
        .{
            .name = "S0",
            .sources = &[_]network.Arg{},
            .destinations = &[_]network.Arg{},
            .constants = &[_]network.TableDef{},
            .resolution = &row1_res,
        },
    };

    const def = network.Definition{
        .name = "FSM_LUT",
        .sources = &sources,
        .destinations = &[_]network.Arg{},
        .constants = &[_]network.TableDef{},
        .contained = &contained,
        .resolution = &[_]network.Statement{},
    };

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const handled = try lookup.writeContainedLookupTable(allocator, &aw.writer, def);
    try std.testing.expect(handled);

    const vhdl = aw.written();

    try std.testing.expect(std.mem.indexOf(u8, vhdl, "-- symbol encoding: S0=0, S1=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "-- lookup for STATE_OUT") != null);
    try std.testing.expect(std.mem.indexOf(u8, vhdl, "state_out <= data_value(1);") != null);
}