// tb_vectors.zig  (place at src/runtime/tb_vectors.zig)
//
// Runtime testbench vectors for the verify stage. A sibling
// `<stem>.tb.vec` next to `<stem>.ms.ipl` is parsed here (deliberately NOT
// with the IPL parser) and each row is driven through the runtime
// Testbench as one wavefront.
//
// Grammar (line-oriented, `//` comments):
//
//   @dut(NAME)                          optional, defaults to definitions[0]
//   @encoding(PORT: 0=A, 1=B)           logical value -> rail symbol
//   @vectors(IN,IN,... : OUT,OUT,...)   column names; must precede rows
//   @mode(wavefront)                    only mode supported so far
//   v,v,... : v,v,...                   one row = one wavefront
//   v,v,... : !stall                    wavefront must NOT complete
//   `-` in an output cell               don't care
//
// A port without @encoding takes raw symbols in its cells.
//
// Each row runs in its own Testbench (one token per input port), because
// Testbench.run stops at the first stuck wavefront and a `!stall` row
// would otherwise hide every row after it.
//
// Allocations are never freed here: pass an arena (verify already does).

const std = @import("std");
const network = @import("../network.zig");
const testbench = @import("testbench.zig");

pub const Outcome = struct {
    present: bool = false,
    malformed: bool = false,
    passed: usize = 0,
    total: usize = 0,
    /// Per-row diagnostics (newline separated) or a BAD TB message.
    err_msg: ?[]const u8 = null,

    pub fn ok(self: Outcome) bool {
        return !self.present or (!self.malformed and self.passed == self.total);
    }
};

const Mapping = struct { value: []const u8, symbol: []const u8 };
const Encoding = struct { port: []const u8, map: []const Mapping };

const RawRow = struct {
    line: usize,
    inputs: []const []const u8,
    outputs: []const []const u8, // empty when `stall`
    stall: bool,
};

pub const Vectors = struct {
    dut: ?[]const u8 = null,
    encodings: []const Encoding = &.{},
    in_cols: []const []const u8 = &.{},
    out_cols: []const []const u8 = &.{},
    rows: []const RawRow = &.{},
};

pub const Diag = struct {
    line: usize = 0, // 0 = not tied to a line
    msg: []const u8 = "",
};

const ParseError = error{ MalformedTestbench, OutOfMemory };

fn bad(a: std.mem.Allocator, d: *Diag, line: usize, comptime fmt: []const u8, args: anytype) ParseError {
    d.line = line;
    d.msg = std.fmt.allocPrint(a, fmt, args) catch "malformed testbench";
    return error.MalformedTestbench;
}

fn isIdent(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_' or c == '$')) return false;
    }
    return true;
}

fn splitList(a: std.mem.Allocator, s: []const u8) ![]const []const u8 {
    var out: std.ArrayListUnmanaged([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, s, ',');
    while (it.next()) |part| try out.append(a, std.mem.trim(u8, part, " \t"));
    return out.toOwnedSlice(a);
}

fn allIdents(list: []const []const u8) bool {
    for (list) |s| if (!isIdent(s)) return false;
    return true;
}

pub fn parse(a: std.mem.Allocator, source: []const u8, diag: *Diag) ParseError!Vectors {
    var v: Vectors = .{};
    var encodings: std.ArrayListUnmanaged(Encoding) = .empty;
    var rows: std.ArrayListUnmanaged(RawRow) = .empty;
    var have_vectors = false;
    var line_no: usize = 0;

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw| {
        line_no += 1;
        var line = raw;
        if (std.mem.indexOf(u8, line, "//")) |i| line = line[0..i];
        line = std.mem.trim(u8, line, " \t\r");
        if (line.len == 0) continue;

        if (line[0] == '@') {
            const lp = std.mem.indexOfScalar(u8, line, '(') orelse
                return bad(a, diag, line_no, "directive needs '(...)'", .{});
            if (line[line.len - 1] != ')')
                return bad(a, diag, line_no, "directive must end with ')'", .{});
            const name = line[1..lp];
            const args = std.mem.trim(u8, line[lp + 1 .. line.len - 1], " \t");

            if (std.mem.eql(u8, name, "dut")) {
                if (!isIdent(args)) return bad(a, diag, line_no, "@dut needs a definition name", .{});
                v.dut = args;
            } else if (std.mem.eql(u8, name, "encoding")) {
                const colon = std.mem.indexOfScalar(u8, args, ':') orelse
                    return bad(a, diag, line_no, "@encoding needs 'PORT: value=symbol, ...'", .{});
                const port = std.mem.trim(u8, args[0..colon], " \t");
                if (!isIdent(port)) return bad(a, diag, line_no, "bad port name in @encoding", .{});
                for (encodings.items) |e| {
                    if (std.mem.eql(u8, e.port, port))
                        return bad(a, diag, line_no, "duplicate @encoding for '{s}'", .{port});
                }
                var maps: std.ArrayListUnmanaged(Mapping) = .empty;
                var it = std.mem.splitScalar(u8, args[colon + 1 ..], ',');
                while (it.next()) |part| {
                    const eq = std.mem.indexOfScalar(u8, part, '=') orelse
                        return bad(a, diag, line_no, "expected value=symbol, got '{s}'", .{std.mem.trim(u8, part, " \t")});
                    const val = std.mem.trim(u8, part[0..eq], " \t");
                    const sym = std.mem.trim(u8, part[eq + 1 ..], " \t");
                    if (!isIdent(val) or !isIdent(sym))
                        return bad(a, diag, line_no, "bad mapping '{s}'", .{std.mem.trim(u8, part, " \t")});
                    try maps.append(a, .{ .value = val, .symbol = sym });
                }
                try encodings.append(a, .{ .port = port, .map = try maps.toOwnedSlice(a) });
            } else if (std.mem.eql(u8, name, "vectors")) {
                if (have_vectors) return bad(a, diag, line_no, "only one @vectors block is supported", .{});
                const colon = std.mem.indexOfScalar(u8, args, ':') orelse
                    return bad(a, diag, line_no, "@vectors needs 'IN,... : OUT,...'", .{});
                v.in_cols = try splitList(a, args[0..colon]);
                v.out_cols = try splitList(a, args[colon + 1 ..]);
                if (!allIdents(v.in_cols) or !allIdents(v.out_cols))
                    return bad(a, diag, line_no, "bad column name in @vectors", .{});
                have_vectors = true;
            } else if (std.mem.eql(u8, name, "mode")) {
                if (!std.mem.eql(u8, args, "wavefront"))
                    return bad(a, diag, line_no, "@mode({s}) not supported yet (only 'wavefront')", .{args});
            } else {
                return bad(a, diag, line_no, "unknown directive '@{s}'", .{name});
            }
            continue;
        }

        // Vector row
        if (!have_vectors) return bad(a, diag, line_no, "row before @vectors", .{});
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse
            return bad(a, diag, line_no, "row needs 'inputs : outputs'", .{});
        const ins = try splitList(a, line[0..colon]);
        const rhs = std.mem.trim(u8, line[colon + 1 ..], " \t");
        const stall = std.mem.eql(u8, rhs, "!stall");
        const outs: []const []const u8 = if (stall) &.{} else try splitList(a, rhs);

        if (ins.len != v.in_cols.len)
            return bad(a, diag, line_no, "expected {d} input cells, got {d}", .{ v.in_cols.len, ins.len });
        if (!stall and outs.len != v.out_cols.len)
            return bad(a, diag, line_no, "expected {d} output cells, got {d}", .{ v.out_cols.len, outs.len });
        for (ins) |c| if (c.len == 0) return bad(a, diag, line_no, "empty input cell", .{});
        for (outs) |c| if (c.len == 0) return bad(a, diag, line_no, "empty output cell", .{});

        try rows.append(a, .{ .line = line_no, .inputs = ins, .outputs = outs, .stall = stall });
    }

    if (!have_vectors) return bad(a, diag, line_no, "missing @vectors", .{});
    if (rows.items.len == 0) return bad(a, diag, line_no, "no vector rows", .{});
    v.encodings = try encodings.toOwnedSlice(a);
    v.rows = try rows.toOwnedSlice(a);
    return v;
}

const Resolved = struct {
    line: usize,
    label: []const u8,
    in_syms: []const []const u8,
    out_syms: []const ?[]const u8, // null = don't care
    stall: bool,
};

fn hasArg(args: []const network.Arg, name: []const u8) bool {
    for (args) |arg| if (std.mem.eql(u8, arg.name, name)) return true;
    return false;
}

fn encodingFor(v: Vectors, port: []const u8) ?Encoding {
    for (v.encodings) |e| if (std.mem.eql(u8, e.port, port)) return e;
    return null;
}

/// With an @encoding the cell must be a mapped value; without one the
/// cell is taken as a raw symbol.
fn symbolFor(enc: ?Encoding, cell: []const u8) ?[]const u8 {
    const e = enc orelse return cell;
    for (e.map) |m| if (std.mem.eql(u8, m.value, cell)) return m.symbol;
    return null;
}

fn resolve(a: std.mem.Allocator, v: Vectors, def: network.Definition, diag: *Diag) ParseError![]const Resolved {
    for (v.in_cols) |c| {
        if (!hasArg(def.sources, c))
            return bad(a, diag, 0, "input column '{s}' is not a source place of {s}", .{ c, def.name });
    }
    for (v.out_cols) |c| {
        if (!hasArg(def.destinations, c))
            return bad(a, diag, 0, "output column '{s}' is not a destination place of {s}", .{ c, def.name });
    }
    for (v.encodings) |e| {
        if (!hasArg(def.sources, e.port) and !hasArg(def.destinations, e.port))
            return bad(a, diag, 0, "@encoding port '{s}' is not a port of {s}", .{ e.port, def.name });
    }

    var out: std.ArrayListUnmanaged(Resolved) = .empty;
    for (v.rows) |row| {
        const in_syms = try a.alloc([]const u8, row.inputs.len);
        for (row.inputs, 0..) |cell, j| {
            in_syms[j] = symbolFor(encodingFor(v, v.in_cols[j]), cell) orelse
                return bad(a, diag, row.line, "value '{s}' has no @encoding mapping for input '{s}'", .{ cell, v.in_cols[j] });
        }
        const out_syms = try a.alloc(?[]const u8, v.out_cols.len);
        for (out_syms, 0..) |*slot, k| {
            if (row.stall or std.mem.eql(u8, row.outputs[k], "-")) {
                slot.* = null;
                continue;
            }
            slot.* = symbolFor(encodingFor(v, v.out_cols[k]), row.outputs[k]) orelse
                return bad(a, diag, row.line, "value '{s}' has no @encoding mapping for output '{s}'", .{ row.outputs[k], v.out_cols[k] });
        }
        try out.append(a, .{
            .line = row.line,
            .label = try std.mem.join(a, ",", row.inputs),
            .in_syms = in_syms,
            .out_syms = out_syms,
            .stall = row.stall,
        });
    }
    return out.toOwnedSlice(a);
}

fn findDut(net: network.Network, name: ?[]const u8) ?network.Definition {
    if (name) |n| {
        for (net.definitions) |d| if (std.mem.eql(u8, d.name, n)) return d;
        return null;
    }
    if (net.definitions.len > 0) return net.definitions[0];
    return null;
}

fn badTb(a: std.mem.Allocator, label: []const u8, diag: Diag) Outcome {
    const msg = if (diag.line > 0)
        std.fmt.allocPrint(a, "{s}: BAD TB line {d}: {s}", .{ label, diag.line, diag.msg })
    else
        std.fmt.allocPrint(a, "{s}: BAD TB: {s}", .{ label, diag.msg });
    return .{ .present = true, .malformed = true, .err_msg = msg catch null };
}

fn runRow(a: std.mem.Allocator, def: network.Definition, streams: []testbench.PortStream) ![]const testbench.Presentation {
    var tb = try testbench.Testbench.init(a, def, streams);
    return tb.run();
}

/// Pure (no IO) so it can be unit-tested with a hand-built Network.
pub fn runVectors(
    a: std.mem.Allocator,
    label: []const u8,
    source: []const u8,
    net: network.Network,
) error{OutOfMemory}!Outcome {
    var diag: Diag = .{};

    const v = parse(a, source, &diag) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.MalformedTestbench => return badTb(a, label, diag),
    };

    const def = findDut(net, v.dut) orelse {
        diag = .{ .line = 0, .msg = "no matching definition for @dut" };
        return badTb(a, label, diag);
    };

    const rows = resolve(a, v, def, &diag) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.MalformedTestbench => return badTb(a, label, diag),
    };

    var failures: std.ArrayListUnmanaged([]const u8) = .empty;
    var passed: usize = 0;

    for (rows) |row| {
        const streams = try a.alloc(testbench.PortStream, v.in_cols.len);
        for (streams, 0..) |*s, j| {
            const toks = try a.alloc([]const u8, 1);
            toks[0] = row.in_syms[j];
            s.* = .{ .port = v.in_cols[j], .tokens = toks };
        }

        const pres = runRow(a, def, streams) catch |err| {
            try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): runtime error {s}", .{ row.line, row.label, @errorName(err) }));
            continue;
        };

        var row_ok = true;
        if (row.stall) {
            if (pres.len != 0) {
                row_ok = false;
                try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): expected stall, but the wavefront completed", .{ row.line, row.label }));
            }
        } else if (pres.len == 0) {
            // Coarse: "no wavefront completed". Refine once Testbench can
            // report which places were still waiting.
            row_ok = false;
            try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): stalled, the wavefront never completed", .{ row.line, row.label }));
        } else {
            for (v.out_cols, row.out_syms) |col, want| {
                const w = want orelse continue;
                if (pres[0].outputs.get(col)) |got| {
                    if (!std.mem.eql(u8, got, w)) {
                        row_ok = false;
                        try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): {s} got {s}, want {s}", .{ row.line, row.label, col, got, w }));
                    }
                } else {
                    row_ok = false;
                    try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): {s} never valid", .{ row.line, row.label, col }));
                }
            }
        }
        if (row_ok) passed += 1;
    }

    return .{
        .present = true,
        .passed = passed,
        .total = rows.len,
        .err_msg = if (failures.items.len > 0) try std.mem.join(a, "\n", failures.items) else null,
    };
}

/// `foo.ms.ipl` -> `foo.tb.vec`
pub fn vectorPath(a: std.mem.Allocator, ex_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, ex_path, ".ms.ipl")) {
        return std.fmt.allocPrint(a, "{s}.tb.vec", .{ex_path[0 .. ex_path.len - 7]});
    }
    const dirname = std.fs.path.dirname(ex_path) orelse "";
    const basename = std.fs.path.basename(ex_path);
    const stem = if (std.mem.lastIndexOf(u8, basename, ".")) |idx| basename[0..idx] else basename;
    return std.fmt.allocPrint(a, "{s}/{s}.tb.vec", .{ dirname, stem });
}

const oom_outcome: Outcome = .{ .present = true, .malformed = true, .err_msg = "out of memory" };

/// Verify entry point: no `.tb.vec` file means `.{}` (present = false).
pub fn runIfPresent(a: std.mem.Allocator, io: std.Io, ex_path: []const u8, net: network.Network) Outcome {
    const path = vectorPath(a, ex_path) catch return oom_outcome;

    const source = std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => return .{
            .present = true,
            .malformed = true,
            .err_msg = std.fmt.allocPrint(a, "{s}: could not read ({s})", .{ path, @errorName(err) }) catch null,
        },
    };

    return runVectors(a, std.fs.path.basename(path), source, net) catch oom_outcome;
}

test "parse: full adder vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src =
        \\// full adder
        \\@dut(FULLADD)
        \\@encoding(X: 0=A, 1=B)
        \\@encoding(SUM: 0=s, 1=t)
        \\@vectors(X,Y : SUM)
        \\0,C : 0
        \\1,C : -
        \\1,D : !stall
    ;
    var diag: Diag = .{};
    const v = try parse(a, src, &diag);
    try std.testing.expectEqualStrings("FULLADD", v.dut.?);
    try std.testing.expectEqual(@as(usize, 2), v.in_cols.len);
    try std.testing.expectEqual(@as(usize, 3), v.rows.len);
    try std.testing.expect(v.rows[2].stall);
}

test "parse: row before @vectors is malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var diag: Diag = .{};
    try std.testing.expectError(error.MalformedTestbench, parse(arena.allocator(), "0,0 : 1\n", &diag));
    try std.testing.expectEqual(@as(usize, 1), diag.line);
}