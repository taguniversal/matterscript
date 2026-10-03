const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const core = matterscript.core;
const network = matterscript.network;
const statements = matterscript.statements;
const tb_vectors = matterscript.runtime.tb_vectors;
const parser = matterscript.ipl_parser;

const and2_ipl =
    \\ AND2[(A B)($OUT)
    \\   $A $B :
    \\   p,r[Z0] p,s[Z0] q,r[Z0] q,s[Z1]
    \\   Z0[OUT<0>] Z1[OUT<1>]
    \\ ]
;

const parity_ipl = 
  \\ // Linear : TAG-217 @stream testbench directive
  \\ PARITY[(state<> bit<>)($next)
  \\  $state$bit() :
  \\  E,0[next<E>]
  \\  E,1[next<O>]
  \\  O,0[next<O>]
  \\  O,1[next<E>]
  \\ ]
;

// ---- helpers ---------------------------------------------------------------

fn mkPlace(_: std.mem.Allocator, name: []const u8) !network.Arg {
    return .{ .kind = .place, .name = name, .group = null };
}

fn mkNetwork(_: std.mem.Allocator, defs: []const network.Definition) !network.Network {
    return .{ .definitions = defs };
}

/// Minimal AND2: sources A, B; destinations OUT. No group nesting.
fn mkAnd2(a: std.mem.Allocator) !network.Definition {
    const sources = try a.alloc(network.Arg, 2);
    sources[0] = try mkPlace(a, "A");
    sources[1] = try mkPlace(a, "B");
    const dests = try a.alloc(network.Arg, 1);
    dests[0] = try mkPlace(a, "OUT");
    return .{
        .name = "AND2",
        .sources = sources,
        .destinations = dests,
        // whatever else Definition requires; zero-init if all defaulted
    };
}


test "parse: full adder vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\ @dut(AND2)
        \\ @vectors(A, B : OUT)
        \\ @mode(wavefront)
        \\
        \\ p, r : Z0
        \\ p, s : Z0
        \\ q, r : Z0
        \\ q, s : Z1
    ;
    var diag: tb_vectors.Diag = .{};
    const v = try tb_vectors.parse(a, src, &diag);
    try std.testing.expectEqualStrings("AND2", v.dut.?);
    try std.testing.expectEqual(@as(usize, 2), v.in_cols.len);
    try std.testing.expectEqual(@as(usize, 4), v.rows.len);
}

test "parse: row before @vectors is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var diag: tb_vectors.Diag = .{};
    try std.testing.expectError(error.MalformedTestbench, tb_vectors.parse(arena.allocator(), "0,0 : 1\n", &diag));
    try std.testing.expectEqual(@as(usize, 1), diag.line);
}

test "TAG-217: PARITY @stream with @carry runs 4/4" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : E
        \\ _,0 : E
        \\ _,1 : O
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.present);
    try testing.expect(!out.malformed);
    try testing.expectEqual(@as(usize, 4), out.total);
    try testing.expectEqual(@as(usize, 4), out.passed);
    try testing.expect(out.ok());
    try testing.expect(out.err_msg == null);
}

test "TAG-217: _ without a matching @carry is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    // @carry writes to `bit`, not `state`, so `_` in the `state` column
    // has nothing to pull from.
    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(bit=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : E
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.present);
    try testing.expect(out.malformed);
    try testing.expect(!out.ok());
    try testing.expect(out.err_msg != null);
    try testing.expect(std.mem.indexOf(u8, out.err_msg.?, "no @carry writes to it") != null);
}

test "TAG-217: @carry target must be an output column" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=nexxt)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : E
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.malformed);
    try testing.expect(out.err_msg != null);
    try testing.expect(std.mem.indexOf(u8, out.err_msg.?, "not an output column") != null);
}

test "TAG-217: @carry after a vector row is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ @carry(state=next)
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.malformed);
    try testing.expect(out.err_msg != null);
    try testing.expect(std.mem.indexOf(u8, out.err_msg.?, "must appear before vector rows") != null);
}

test "TAG-217: carry threading is actually exercised (wrong carry produces failures)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    // Same as the acceptance test, but the @carry pulls from the wrong
    // source: `state` carries from `bit` instead of `next`. `bit` never
    // becomes an output, so this fails at row 2. If @carry were a no-op
    // (the earlier bug), this would accidentally pass because carryTarget
    // would default to `state` and `last_output.get("state")` would be
    // null too — so this test alone doesn't distinguish. Pair it with a
    // test where the default *would* work to make the distinction sharp.
    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=bit)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : E
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(!out.ok());
}

test "TAG-136: code detector stream carries state and fires yes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const code_ipl = 
      \\// linear: TAG-136 Code detector state machine
      \\// Detects sequence 001011 in a continuous stream of bits.
      \\code[(currentstate< > newbit< >)($state $detect) 
      \\$newbit$currentstate() :
      \\0,S0[detect< no > state<S1>]
      \\0,S1[detect< no > state<S2>]
      \\0,S2[detect< no > state<S2>]
      \\0,S3[detect< no > state<S4>]
      \\0,S4[detect< no > state<S2>]
      \\0,S5[detect< no > state<S1>]
      \\0,S6[detect< no > state<S1>]
      \\1,S0[detect< no > state<S0>]
      \\1,S1[detect< no > state<S0>]
      \\1,S2[detect< no > state<S3>]
      \\1,S3[detect< no > state<S0>]
      \\1,S4[detect< no > state<S5>]
      \\1,S5[detect< no > state<S6>] 
      \\1,S6[detect< yes > state<S0>] 
      \\] 
      ;

    const net = try parser.parse(a, code_ipl);

    const vec =
        \\ @dut(code)
        \\ @vectors(currentstate,newbit : detect,state)
        \\ @carry(currentstate=state)
        \\ @stream()
        \\
        \\ S0,0 : no,S1
        \\ _,0  : no,S2
        \\ _,1  : no,S3
        \\ _,0  : no,S4
        \\ _,1  : no,S5
        \\ _,1  : no,S6
        \\ _,1  : yes,S0
    ;


    const out = try tb_vectors.runVectors(a, "code.tb.vec", vec, net);
    try testing.expect(out.present);
    try testing.expect(!out.malformed);
    try testing.expectEqual(@as(usize, 7), out.total);
    try testing.expectEqual(@as(usize, 7), out.passed);
    try testing.expect(out.ok());
    try testing.expect(out.err_msg == null);
}

test "TAG-217: '-' output still carries forward to the next row" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    // Row 1: literal seed, checks next=O.
    // Row 2: `-` for next — don't check it, but it still produced E and
    //        must carry to row 3. If the carry update were skipped on a
    //        don't-check row, row 3 would fail.
    // Row 3: `_` for state must resolve to E (row 2's real next), and
    //        driving bit=0 from E produces E, which we do check.
    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : -
        \\ _,0 : E
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.present);
    try testing.expect(!out.malformed);
    try testing.expectEqual(@as(usize, 3), out.total);
    try testing.expectEqual(@as(usize, 3), out.passed);
    try testing.expect(out.ok());
}

test "TAG-217: carry vocabulary mismatch fails loudly, not silently" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    // Carry `bit` from `next`. PARITY's `bit` expects 0/1; `next`
    // produces E/O. Row 2 drives bit=E (or O) into a port that only
    // resolves 0/1 — the wavefront should not produce a valid
    // presentation, so row 2 fails.
    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(bit=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ E,_ : O
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.present);
    try testing.expect(!out.malformed);
    try testing.expect(!out.ok());
    try testing.expect(out.err_msg != null);
}

test "TAG-217: duplicate @carry for the same input column is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=next)
        \\ @carry(state=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : E
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.malformed);
    try testing.expect(out.err_msg != null);
    try testing.expect(std.mem.indexOf(u8, out.err_msg.?, "duplicate @carry") != null);
}

test "TAG-217: !stall under @stream is rejected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const net = try parser.parse(a, parity_ipl);

    const vec =
        \\ @dut(PARITY)
        \\ @vectors(state,bit : next)
        \\ @carry(state=next)
        \\ @stream()
        \\
        \\ E,1 : O
        \\ _,1 : !stall
    ;

    const out = try tb_vectors.runVectors(a, "parity.tb.vec", vec, net);
    try testing.expect(out.malformed);
    try testing.expect(std.mem.indexOf(u8, out.err_msg.?, "not supported with @stream") != null);
}