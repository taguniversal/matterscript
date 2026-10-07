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
//   @vectors(IN,IN,... : OUT,OUT,...)   column names; must precede rows
//   @mode(wavefront)                    only mode supported so far
//   v,v,... : v,v,...                   one row = one wavefront
//   v,v,... : !stall                    wavefront must NOT complete
//   `-` in an output cell               don't care
//
// Cells are raw tokens: the token driven on an input place, or the token
// expected on an output place. No value<->symbol mapping is provided or
// needed; the meaning of a token is the DUT author's convention.
//
// Each row runs in its own Testbench (one token per input port), because
// Testbench.run stops at the first stuck wavefront and a `!stall` row
// would otherwise hide every row after it.
//
// Allocations are never freed here: pass an arena (verify already does).

const std = @import("std");
const network = @import("../network.zig");
const testbench = @import("testbench.zig");
const boundary = @import("../vhdl/export/boundary.zig");

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

const RawRow = struct {
    line: usize,
    inputs: []const []const u8,
    outputs: []const []const u8, // empty when `stall`
    stall: bool,
};

const Carry = struct { in: []const u8, out: []const u8 };

pub const Vectors = struct {
    dut: ?[]const u8 = null,
    mode_stream: bool = false,
    // TAG-217 carries - The real fix: let _ name which output it carries from, when it isn't the same name
    carries: []const Carry = &.{},
    in_cols: []const []const u8 = &.{},
    out_cols: []const []const u8 = &.{},
    rows: []const RawRow = &.{},
};

pub const Diag = struct {
    line: usize = 0, // 0 = not tied to a line
    msg: []const u8 = "",
};

const ParseError = error{ MalformedTestbench, OutOfMemory };

fn carryTarget(v: Vectors, in_name: []const u8) []const u8 {
    for (v.carries) |c| if (std.mem.eql(u8, c.in, in_name)) return c.out;
    return in_name; // default: same name, unchanged behavior when no @carry is given
}

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
    var rows: std.ArrayListUnmanaged(RawRow) = .empty;
    var have_vectors = false;
    var line_no: usize = 0;
    var carries_list: std.ArrayListUnmanaged(Carry) = .empty;

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
            } else if (std.mem.eql(u8, name, "stream")) {
                if (args.len != 0) return bad(a, diag, line_no, "@stream takes no arguments", .{});
                v.mode_stream = true;
            } else if (std.mem.eql(u8, name, "vectors")) {
                if (have_vectors) return bad(a, diag, line_no, "only one @vectors block is supported", .{});
                const colon = std.mem.indexOfScalar(u8, args, ':') orelse
                    return bad(a, diag, line_no, "@vectors needs 'IN,... : OUT,...'", .{});
                v.in_cols = try splitList(a, args[0..colon]);
                v.out_cols = try splitList(a, args[colon + 1 ..]);
                if (!allIdents(v.in_cols) or !allIdents(v.out_cols))
                    return bad(a, diag, line_no, "bad column name in @vectors", .{});
                have_vectors = true;
            } else if (std.mem.eql(u8, name, "carry")) {
                const eq = std.mem.indexOfScalar(u8, args, '=') orelse
                    return bad(a, diag, line_no, "@carry needs 'input=output'", .{});
                const in_name = std.mem.trim(u8, args[0..eq], " \t");
                const out_name = std.mem.trim(u8, args[eq + 1 ..], " \t");
                if (rows.items.len != 0)
                    return bad(a, diag, line_no, "@carry must appear before vector rows", .{});
                for (carries_list.items) |existing| {
                    if (std.mem.eql(u8, existing.in, in_name))
                        return bad(a, diag, line_no, "duplicate @carry for '{s}'", .{in_name});
                }
                if (!isIdent(in_name) or !isIdent(out_name))
                    return bad(a, diag, line_no, "bad @carry mapping", .{});
                try carries_list.append(a, .{ .in = in_name, .out = out_name });
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
        for (ins, 0..) |c, j| {
            if (c.len == 0) return bad(a, diag, line_no, "empty input cell", .{});
            if (std.mem.eql(u8, c, "_")) {
                if (!v.mode_stream) return bad(a, diag, line_no, "'_' requires @stream", .{});
                if (rows.items.len == 0) return bad(a, diag, line_no, "'_' on the first row has nothing to carry", .{});
                const col = v.in_cols[j];
                var carried = false;
                for (carries_list.items) |cc| if (std.mem.eql(u8, cc.in, col)) {
                    carried = true;
                    break;
                };
                if (!carried)
                    return bad(a, diag, line_no, "'_' in column '{s}' but no @carry writes to it", .{col});
            }
        }

        if (v.mode_stream and stall)
            return bad(a, diag, line_no, "'!stall' is not supported with @stream", .{});

        if (!stall and outs.len != v.out_cols.len)
            return bad(a, diag, line_no, "expected {d} output cells, got {d}", .{ v.out_cols.len, outs.len });

        for (outs) |c| if (c.len == 0) return bad(a, diag, line_no, "empty output cell", .{});

        try rows.append(a, .{ .line = line_no, .inputs = ins, .outputs = outs, .stall = stall });
    }

    if (!have_vectors) return bad(a, diag, line_no, "missing @vectors", .{});
    if (rows.items.len == 0) return bad(a, diag, line_no, "no vector rows", .{});

    v.rows = try rows.toOwnedSlice(a);
    v.carries = try carries_list.toOwnedSlice(a);
    return v;
}

const InCell = union(enum) {
    literal: []const u8,
    carry_from: []const u8, // name of the output column to pull from
};

const Resolved = struct {
    line: usize,
    label: []const u8,
    in_cells: []const InCell, // was in_syms: []const []const u8
    out_syms: []const ?[]const u8,
    stall: bool,
};

// Group aware search
fn portExists(args: []const network.Arg, name: []const u8) bool {
    for (args) |arg| {
        if (arg.kind == .group) {
            if (arg.group) |g| {
                if (portExists(g.places, name)) return true;
            }
            continue;
        }
        if (std.mem.eql(u8, arg.name, name)) return true;
    }
    return false;
}

fn resolve(a: std.mem.Allocator, v: Vectors, def: network.Definition, diag: *Diag) ParseError![]const Resolved {
    for (v.in_cols) |c| {
        if (!portExists(def.sources, c))
            return bad(a, diag, 0, "input column '{s}' is not a source place of {s}", .{ c, def.name });
    }
    for (v.out_cols) |c| {
        if (!portExists(def.destinations, c))
            return bad(a, diag, 0, "output column '{s}' is not a destination place of {s}", .{ c, def.name });
    }
    for (v.carries) |c| {
        var in_ok = false;
        for (v.in_cols) |ic| if (std.mem.eql(u8, ic, c.in)) {
            in_ok = true;
            break;
        };
        if (!in_ok)
            return bad(a, diag, 0, "@carry input '{s}' is not an input column", .{c.in});
        var out_ok = false;
        for (v.out_cols) |oc| if (std.mem.eql(u8, oc, c.out)) {
            out_ok = true;
            break;
        };
        if (!out_ok)
            return bad(a, diag, 0, "@carry target '{s}' is not an output column", .{c.out});
    }
    var out: std.ArrayListUnmanaged(Resolved) = .empty;
    for (v.rows) |row| {
        const in_cells = try a.alloc(InCell, row.inputs.len);
        for (row.inputs, 0..) |cell, j| {
            in_cells[j] = if (std.mem.eql(u8, cell, "_"))
                .{ .carry_from = carryTarget(v, v.in_cols[j]) }
            else
                .{ .literal = cell };
        }
        const out_syms = try a.alloc(?[]const u8, v.out_cols.len);
        for (out_syms, 0..) |*slot, k| {
            if (row.stall or std.mem.eql(u8, row.outputs[k], "-")) {
                slot.* = null;
                continue;
            }
            slot.* = row.outputs[k];
        }
        try out.append(a, .{
            .line = row.line,
            .label = try std.mem.join(a, ",", row.inputs),
            .in_cells = in_cells,
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

fn runRow(a: std.mem.Allocator, def: network.Definition, definitions: []const network.Definition, streams: []testbench.PortStream) ![]const testbench.Presentation {
    std.debug.print("[runRow] initInNetwork\n", .{});
    var tb = try testbench.Testbench.initInNetwork(a, def, definitions, streams);
    std.debug.print("[runRow] run\n", .{});
    std.debug.print("--- rules for {s} ---\n", .{def.name});
    for (tb.rules, 0..) |r, i| {
        std.debug.print("rule[{d}]: dest='{s}' inputs=[", .{ i, r.dest });
        for (r.inputs, 0..) |inp, j| {
            if (j > 0) std.debug.print(",", .{});
            std.debug.print("{s}", .{inp});
        }
        std.debug.print("] action={s}\n", .{@tagName(r.action)});
    }
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
    std.debug.print("[runVectors] {s}\n", .{label});
    const v = parse(a, source, &diag) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.MalformedTestbench => return badTb(a, label, diag),
    };

    const raw_def = findDut(net, v.dut) orelse {
        diag = .{ .line = 0, .msg = "no matching definition for @dut" };
        return badTb(a, label, diag);
    };

    // Apply the same boundary normalization the emitter applies, so the
    // runtime sees the same destinations the emitted VHDL declares. Without
    // this, a definition with an implicit return value (no destination list,
    // key-composition header, contained value-transform rules) has zero
    // destinations at the runtime layer, and a `.tb.vec` that references the
    // synthesized `result` is rejected as "not a destination place".
    const def = boundary.normalizeReturnDestinations(a, raw_def) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };

    std.debug.print("[runVectors] {s}: about to resolve, dests={d}\n", .{ label, def.destinations.len });
    const rows = resolve(a, v, def, &diag) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.MalformedTestbench => return badTb(a, label, diag),
    };

    var failures: std.ArrayListUnmanaged([]const u8) = .empty;
    var passed: usize = 0;
    var last_output: std.StringHashMapUnmanaged([]const u8) = .empty;
    std.debug.print("[runVectors] {s}: about to run {d} rows\n", .{ label, rows.len });
    for (rows) |row| {
        const streams = try a.alloc(testbench.PortStream, v.in_cols.len);
        var row_had_carry_error = false;
        for (streams, 0..) |*s, j| {
            const resolved: []const u8 = switch (row.in_cells[j]) {
                .literal => |sym| sym,
                .carry_from => |out_name| last_output.get(out_name) orelse {
                    try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): '_' refers to '{s}', which was never produced by a prior row", .{ row.line, row.label, out_name }));
                    row_had_carry_error = true;
                    break;
                },
            };
            const toks = try a.alloc([]const u8, 1);
            toks[0] = resolved;
            s.* = .{ .port = v.in_cols[j], .tokens = toks };
        }
        if (row_had_carry_error) continue; // nothing valid to run this row with

        std.debug.print("[runVectors] {s}: about to runRow for row '{s}'\n", .{ label, row.label });

        const pres = runRow(a, def, net.definitions, streams) catch |err| {
            try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): runtime error {s}", .{ row.line, row.label, @errorName(err) }));
            continue;
        };

        std.debug.print("[runVectors] {s}: runRow returned {d} presentations\n", .{ label, pres.len });

        // A stall row must not overwrite last_output: carry state is defined to be
        // unchanged across a stall. Unreachable in @stream mode today (parser
        // forbids `!stall` there), but kept correct in case that restriction lifts.

        if (pres.len > 0) {
            for (v.out_cols) |col| {
                if (pres[0].outputs.get(col)) |val| try last_output.put(a, col, val);
            }
        }

        var row_ok = true;
        if (row.stall) {
            if (pres.len != 0) {
                row_ok = false;
                try failures.append(a, try std.fmt.allocPrint(a, "line {d} ({s}): expected stall, but the wavefront completed", .{ row.line, row.label }));
            }
        } else if (pres.len == 0) {
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
