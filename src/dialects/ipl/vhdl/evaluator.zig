const std = @import("std");
const network = @import("../network.zig");

const GeneratedEntry = struct {
    pattern: []const []const u8, // e.g. ["DE", "AK", "JD"] or ["2", "1", "5"]
    target_state: []const u8, // e.g. "JC" or "4"
};



fn enumerateGenerate(
    allocator: std.mem.Allocator,
    gen: network.GenerateBlock,
) ![]const GeneratedEntry {
    var entries: std.ArrayListUnmanaged(GeneratedEntry) = .empty;
    errdefer entries.deinit(allocator);

    for (gen.rules) |rule| {
        // Store symbolic pattern strings directly
        var pattern_tokens: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer pattern_tokens.deinit(allocator);

        for (rule.pattern) |tok| {
            try pattern_tokens.append(allocator, tok);
        }

        try entries.append(allocator, .{
            .pattern = try pattern_tokens.toOwnedSlice(allocator),
            .target_state = rule.value,
        });
    }

    return entries.toOwnedSlice(allocator);
}

fn enumerateRecursive(
    allocator: std.mem.Allocator,
    gen: network.GenerateBlock,
    inputs: []const network.InputDecl,
    current_vals: []i64,
    depth: usize,
    var_map: *std.StringHashMap(i64),
    const_map: std.StringHashMap(i64),
    entries: *std.ArrayListUnmanaged(GeneratedEntry),
) !void {
    if (depth == inputs.len) {
        const result = try evalExpr(gen.expr, var_map.*, const_map);
        const clamped = @max(gen.output_min, @min(gen.output_max, result));
        const vals_copy = try allocator.dupe(i64, current_vals);
        try entries.append(allocator, .{
            .input_values = vals_copy,
            .output_value = clamped,
        });
        return;
    }
    const inp = inputs[depth];
    var v = inp.min;
    while (v <= inp.max) : (v += 1) {
        current_vals[depth] = v;
        try var_map.put(inp.name, v);
        try enumerateRecursive(allocator, gen, inputs, current_vals, depth + 1, var_map, const_map, entries);
    }
}

fn evalExpr(
    expr: *const network.Expr,
    variables: std.StringHashMap(i64),
    constants: std.StringHashMap(i64),
) !i64 {
    return switch (expr.kind) {
        .integer => expr.int_val,
        .variable => variables.get(expr.name) orelse 0,
        .constant => constants.get(expr.name) orelse 0,
        .binary => {
            const l = try evalExpr(expr.left.?, variables, constants);
            const r = try evalExpr(expr.right.?, variables, constants);
            return switch (expr.op) {
                .add => l + r,
                .sub => l - r,
                .mul => l * r,
                .div => if (r == 0) 0 else @divTrunc(l, r),
            };
        },
        .call => {
            if (std.mem.eql(u8, expr.func, "clamp")) {
                const val = try evalExpr(expr.args[0], variables, constants);
                const lo = try evalExpr(expr.args[1], variables, constants);
                const hi = try evalExpr(expr.args[2], variables, constants);
                return @max(lo, @min(hi, val));
            }
            if (std.mem.eql(u8, expr.func, "avg")) {
                var sum: i64 = 0;
                for (expr.args) |arg|
                    sum += try evalExpr(arg, variables, constants);
                return if (expr.args.len == 0) 0 else @divTrunc(sum, @as(i64, @intCast(expr.args.len)));
            }
            return 0;
        },
    };
}
