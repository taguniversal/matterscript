const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;

// TAG-181: Controlled Fan-out Expression — parser diagnostic suite.
//
// Goal: find out which specific construct the parser can't handle,
// rather than staring at one "BAD TB" on the full expression. Each test
// below isolates one piece, building up to the full original. A test
// that fails to parse prints nothing (the parse itself errors out) — run
// with `zig build test` and read which test name failed; that pins the
// construct. A test that parses successfully prints its structure so we
// can compare against what we *expected* the parser to produce, since
// "it parsed" isn't the same as "it parsed the way the runtime needs."
//
// Constructs under suspicion, isolated one at a time:
//   1. Ordinary single-input destination-per-branch fill (baseline sanity)
//   2. Braced destination-group syntax: ({$out1 $out2 $out3 $out4})
//   3. Boundary entry using the same brace syntax: ({output1<> ...})
//   4. The "$select( )" resolution head — space + empty parens
//   5. Inline fill inside a fan-out branch: A[out1< $in >]
//   6. The full original expression

fn dump(label: []const u8, def: network.Definition) void {
    std.debug.print("--- {s} ---\n", .{label});
    std.debug.print("def '{s}'\n", .{def.name});
    for (def.sources) |s| std.debug.print("  source: '{s}'\n", .{s.name});
    for (def.destinations) |d| std.debug.print("  dest:   '{s}'\n", .{d.name});
    for (def.resolution, 0..) |st, i| std.debug.print("  resolution[{d}]: {s}\n", .{ i, @tagName(st) });
    for (def.contained) |c| {
        std.debug.print("  contained '{s}': {d} source(s), {d} dest(s), {d} resolution stmt(s)\n", .{
            c.name, c.sources.len, c.destinations.len, c.resolution.len,
        });
        for (c.resolution, 0..) |st, i| std.debug.print("    resolution[{d}]: {s}\n", .{ i, @tagName(st) });
    }
    std.debug.print("\n", .{});
}



// --- 4. The "$select( ) :" resolution head on its own ---
// This is the piece with no precedent in TAG-142 ($X$Y(), no space, no
// trailing colon before a table) or TAG-177/198 ($X $Y $CI :, no
// parens). If this specific test fails while step 3 passes, the head
// syntax is the culprit.
test "TAG-181 step 4: resolution head accepts space+empty-parens" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\pick($select)($out)
        \\pick[(select<>)($out)
        \\  $select( ) : A[out<1>]
        \\               B[out<0>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 4 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    dump("step 4", net.definitions[0]);
}


// --- 6. Full original TAG-181 expression, verbatim ---
test "TAG-181 step 6: full original expression" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\fanout($select $input)({output1< > output2< > output3< > output4< >})
        \\
        \\fanout[(select< > in< >)({$out1 $out2 $out3 $out4})
        \\     $select( ) : A[out1< $in >]
        \\                  B[out2< $in >]
        \\                  C[out3< $in >]
        \\                  D[out4< $in>]
        \\]
    ;
    const net = parser.parse(a, src) catch |err| {
        std.debug.print("step 6 FAILED TO PARSE: {s}\n", .{@errorName(err)});
        return err;
    };
    dump("step 6", net.definitions[0]);
}

test "TAG-181 step 7: inspect the anonymous destination's full shape" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\fanout($select $input)({output1< > output2< > output3< > output4< >})
        \\
        \\fanout[(select< > in< >)({$out1 $out2 $out3 $out4})
        \\     $select( ) : A[out1< $in >]
        \\                  B[out2< $in >]
        \\                  C[out3< $in >]
        \\                  D[out4< $in>]
        \\]
    ;
    const net = try parser.parse(a, src);
    const def = net.definitions[0];

    std.debug.print("destinations.len = {d}\n", .{def.destinations.len});
    for (def.destinations, 0..) |d, i| {
        std.debug.print("dest[{d}] = {any}\n", .{ i, d });
    }

    for (def.contained) |c| {
        for (c.resolution) |st| {
            switch (st) {
                .fill => |f| std.debug.print("contained '{s}' fill.dest_name = '{s}', fill.expr = '{s}'\n", .{ c.name, f.dest_name, f.expr }),
                else => {},
            }
        }
    }
}