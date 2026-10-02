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
