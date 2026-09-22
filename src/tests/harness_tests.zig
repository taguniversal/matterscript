const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");

const parser = matterscript.ipl_parser;
const testbench = matterscript.runtime.testbench;

// AND2[(A<> B<>)($OUT)
//     $A $B :
//   p,r[Z0]   // A=0(p), B=0(r) -> Z0 (OUT=0)
//   p,s[Z0]   // A=0(p), B=1(s) -> Z0 (OUT=0)
//   q,r[Z0]   // A=1(q), B=0(r) -> Z0 (OUT=0)
//   q,s[Z1]   // A=1(q), B=1(s) -> Z1 (OUT=1)
//   Z0[OUT<$Z0>]
//   Z1[OUT<$Z1>]
// ]
const and2_source =
    \\AND2[(A<> B<>)($OUT)
    \\    $A $B :
    \\  p,r[Z0]
    \\  p,s[Z0]
    \\  q,r[Z0]
    \\  q,s[Z1]
    \\  Z0[OUT<$Z0>]
    \\  Z1[OUT<$Z1>]
    \\]
;

test "testbench drives AND2's full truth table across four wavefronts" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, and2_source);
    const def = net.definitions[0];

    // (A, B) presented in order: (0,0) (1,1) (0,1) (1,0)
    const a_stream = testbench.PortStream{ .port = "A", .tokens = &.{ "p", "q", "p", "q" } };
    const b_stream = testbench.PortStream{ .port = "B", .tokens = &.{ "r", "s", "s", "r" } };
    var streams = [_]testbench.PortStream{ a_stream, b_stream };

    var bench = try testbench.Testbench.init(a, def, &streams);
    const presentations = try bench.run();

    try testing.expectEqual(@as(usize, 4), presentations.len);

    const expected_out = [_][]const u8{ "Z0", "Z1", "Z0", "Z0" };
    for (presentations, 0..) |p, i| {
        const out = p.outputs.get("OUT") orelse return error.MissingOutput;
        try testing.expectEqualStrings(expected_out[i], out);
    }
}