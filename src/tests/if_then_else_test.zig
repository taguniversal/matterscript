const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const runtime = matterscript.runtime;
const testbench = runtime.testbench; // or wherever Testbench / PortStream is exposed

// Linear: TAG-207 - Example 12.35 IF-THEN-ELSE expression conventions
// IF[(logical<> thenname<> elsename<>)($name)
//   $logical() :
//     TRUE[ name<$thenname>]
//     FALSE[ name<$elsename>]]

test "TAG-207 Example 12.35 - IF-THEN-ELSE execution (TRUE branch)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const snippet =
        \\IF[(logical<> thenname<> elsename<>)($name)
        \\  $logical() :
        \\    TRUE[ name<$thenname>]
        \\    FALSE[ name<$elsename>]]
    ;

    const net = try parser.parse(allocator, snippet);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    // Prepare streams for one data wavefront:
    // logical = "TRUE", thenname = "A", elsename = "B"
    var streams = [_]testbench.PortStream{
        .{ .port = "logical", .tokens = &.{ "TRUE" } },
        .{ .port = "thenname", .tokens = &.{ "A" } },
        .{ .port = "elsename", .tokens = &.{ "B" } },
    };

    var tb = try testbench.Testbench.init(allocator, def, &streams);
    const presentations = try tb.run();

    try testing.expectEqual(@as(usize, 1), presentations.len);

    // Verify $name destination evaluated to "A" (the thenname branch)
    const result = presentations[0].outputs.get("name");
    try testing.expect(result != null);
    try testing.expectEqualStrings("A", result.?);
}

test "TAG-207 Example 12.35 - IF-THEN-ELSE execution (FALSE branch)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const snippet =
        \\IF[(logical<> thenname<> elsename<>)($name)
        \\  $logical() :
        \\    TRUE[ name<$thenname>]
        \\    FALSE[ name<$elsename>]]
    ;

    const net = try parser.parse(allocator, snippet);
    try testing.expectEqual(@as(usize, 1), net.definitions.len);
    const def = net.definitions[0];

    // Prepare streams for one data wavefront:
    // logical = "FALSE", thenname = "A", elsename = "B"
    var streams = [_]testbench.PortStream{
        .{ .port = "logical", .tokens = &.{ "FALSE" } },
        .{ .port = "thenname", .tokens = &.{ "A" } },
        .{ .port = "elsename", .tokens = &.{ "B" } },
    };

    var tb = try testbench.Testbench.init(allocator, def, &streams);
    const presentations = try tb.run();

    try testing.expectEqual(@as(usize, 1), presentations.len);

    // Verify $name destination evaluated to "B" (the elsename branch)
    const result = presentations[0].outputs.get("name");
    try testing.expect(result != null);
    try testing.expectEqualStrings("B", result.?);
}

test "TAG-207 Example 12.35 - Sequential two-wavefront execution (TRUE then FALSE)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const snippet =
        \\IF[(logical<> thenname<> elsename<>)($name)
        \\  $logical() :
        \\    TRUE[ name<$thenname>]
        \\    FALSE[ name<$elsename>]]
    ;

    const net = try parser.parse(allocator, snippet);
    const def = net.definitions[0];

    // Feed two consecutive tokens per port (Wavefront 1: TRUE, Wavefront 2: FALSE)
    var streams = [_]testbench.PortStream{
        .{ .port = "logical", .tokens = &.{ "TRUE", "FALSE" } },
        .{ .port = "thenname", .tokens = &.{ "X", "P" } },
        .{ .port = "elsename", .tokens = &.{ "Y", "Q" } },
    };

    var tb = try testbench.Testbench.init(allocator, def, &streams);
    const presentations = try tb.run();

    // Verify both wavefronts completed
    try testing.expectEqual(@as(usize, 2), presentations.len);

    // Wavefront 1 (TRUE -> thenname) => "X"
    const wf1_result = presentations[0].outputs.get("name");
    try testing.expect(wf1_result != null);
    try testing.expectEqualStrings("X", wf1_result.?);

    // Wavefront 2 (FALSE -> elsename) => "Q"
    const wf2_result = presentations[1].outputs.get("name");
    try testing.expect(wf2_result != null);
    try testing.expectEqualStrings("Q", wf2_result.?);
}