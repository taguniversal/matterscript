const std = @import("std");
const testing = std.testing;

const matterscript = @import("matterscript");
const network = matterscript.network;
const evaluator = matterscript.evaluator;

// ============================================================================
// 1. AST Expression Evaluation (`evalExpr`)
// ============================================================================

test "evalExpr: literal integers and binary arithmetic" {
    var var_map = std.StringHashMap(i64).init(testing.allocator);
    defer var_map.deinit();
    const const_map = std.StringHashMap(i64).init(testing.allocator);

    // Literal integer: 42
    var int_expr = network.Expr{ .kind = .integer, .int_val = 42 };
    try testing.expectEqual(@as(i64, 42), try evaluator.evalExpr(&int_expr, var_map, const_map));

    // Binary Addition: 10 + 32
    var left_expr = network.Expr{ .kind = .integer, .int_val = 10 };
    var right_expr = network.Expr{ .kind = .integer, .int_val = 32 };
    var add_expr = network.Expr{
        .kind = .binary,
        .op = .add,
        .left = &left_expr,
        .right = &right_expr,
    };
    try testing.expectEqual(@as(i64, 42), try evaluator.evalExpr(&add_expr, var_map, const_map));
}

test "evalExpr: variable and constant lookups" {
    var var_map = std.StringHashMap(i64).init(testing.allocator);
    defer var_map.deinit();
    try var_map.put("x", 15);

    var const_map = std.StringHashMap(i64).init(testing.allocator);
    defer const_map.deinit();
    try const_map.put("OFFSET", 5);

    // Variable lookup ($x)
    var var_expr = network.Expr{ .kind = .variable, .name = "x" };
    try testing.expectEqual(@as(i64, 15), try evaluator.evalExpr(&var_expr, var_map, const_map));

    // Constant lookup (OFFSET)
    var const_expr = network.Expr{ .kind = .constant, .name = "OFFSET" };
    try testing.expectEqual(@as(i64, 5), try evaluator.evalExpr(&const_expr, var_map, const_map));

    // Compound: x - OFFSET
    var sub_expr = network.Expr{
        .kind = .binary,
        .op = .sub,
        .left = &var_expr,
        .right = &const_expr,
    };
    try testing.expectEqual(@as(i64, 10), try evaluator.evalExpr(&sub_expr, var_map, const_map));
}

test "evalExpr: division by zero safety" {
    var var_map = std.StringHashMap(i64).init(testing.allocator);
    defer var_map.deinit();
    const const_map = std.StringHashMap(i64).init(testing.allocator);

    var numerator = network.Expr{ .kind = .integer, .int_val = 10 };
    var denominator = network.Expr{ .kind = .integer, .int_val = 0 };
    var div_expr = network.Expr{
        .kind = .binary,
        .op = .div,
        .left = &numerator,
        .right = &denominator,
    };

    // Division by 0 should safely fall back to 0 without crashing
    try testing.expectEqual(@as(i64, 0), try evaluator.evalExpr(&div_expr, var_map, const_map));
}

test "evalExpr: built-in function call 'clamp'" {
    var var_map = std.StringHashMap(i64).init(testing.allocator);
    defer var_map.deinit();
    const const_map = std.StringHashMap(i64).init(testing.allocator);

    // clamp(val=150, min=0, max=100) -> should clamp to 100
    var val_expr = network.Expr{ .kind = .integer, .int_val = 150 };
    var min_expr = network.Expr{ .kind = .integer, .int_val = 0 };
    var max_expr = network.Expr{ .kind = .integer, .int_val = 100 };
    var args = [_]*network.Expr{ &val_expr, &min_expr, &max_expr };

    var clamp_call = network.Expr{
        .kind = .call,
        .func = "clamp",
        .args = &args,
    };

    try testing.expectEqual(@as(i64, 100), try evaluator.evalExpr(&clamp_call, var_map, const_map));
}

test "evalExpr: built-in function call 'avg'" {
    var var_map = std.StringHashMap(i64).init(testing.allocator);
    defer var_map.deinit();
    const const_map = std.StringHashMap(i64).init(testing.allocator);

    // avg(10, 20, 30) -> 20
    var e1 = network.Expr{ .kind = .integer, .int_val = 10 };
    var e2 = network.Expr{ .kind = .integer, .int_val = 20 };
    var e3 = network.Expr{ .kind = .integer, .int_val = 30 };
    var args = [_]*network.Expr{ &e1, &e2, &e3 };

    var avg_call = network.Expr{
        .kind = .call,
        .func = "avg",
        .args = &args,
    };

    try testing.expectEqual(@as(i64, 20), try evaluator.evalExpr(&avg_call, var_map, const_map));
}

// ============================================================================
// 2. Symbolic Rules Enumeration (`enumerateGenerate`)
// ============================================================================

test "enumerateGenerate: converts rule pattern tokens into entries" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pattern1 = [_][]const u8{ "DE", "AK" };
    const pattern2 = [_][]const u8{ "1", "0" };

    const gen_block = network.GenerateBlock{
        .rules = &.{
            .{ .pattern = &pattern1, .value = "JC" },
            .{ .pattern = &pattern2, .value = "HIGH" },
        },
        .expr = null,
        .domain = null,
    };

    const entries = try evaluator.enumerateGenerate(allocator, gen_block);

    try testing.expectEqual(@as(usize, 2), entries.len);

    // Rule 0
    try testing.expectEqualSlices([]const u8, &pattern1, entries[0].pattern);
    try testing.expectEqualStrings("JC", entries[0].target_state);

    // Rule 1
    try testing.expectEqualSlices([]const u8, &pattern2, entries[1].pattern);
    try testing.expectEqualStrings("HIGH", entries[1].target_state);
}

// ============================================================================
// 3. State-Space Exploration (`enumerateRecursive`)
// ============================================================================

test "enumerateRecursive: Cartesian product traversal over input ranges" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Inputs: a in [0..1], b in [0..1] -> 4 total combinations
    const inputs = [_]network.InputDecl{
        .{ .name = "a", .min = 0, .max = 1 },
        .{ .name = "b", .min = 0, .max = 1 },
    };

    // Generate Expression: a + b
    var var_a = network.Expr{ .kind = .variable, .name = "a" };
    var var_b = network.Expr{ .kind = .variable, .name = "b" };
    var add_expr = network.Expr{
        .kind = .binary,
        .op = .add,
        .left = &var_a,
        .right = &var_b,
    };

    const gen_block = network.GenerateBlock{
        .rules = &.{},
        .expr = &add_expr,
        .domain = null,
    };

    const current_vals = try allocator.alloc(i64, inputs.len);
    var var_map = std.StringHashMap(i64).init(allocator);
    const const_map = std.StringHashMap(i64).init(allocator);

    var entries = std.ArrayListUnmanaged(evaluator.GeneratedEntry).empty;

    try evaluator.enumerateRecursive(
        allocator,
        gen_block,
        &inputs,
        current_vals,
        0,
        &var_map,
        const_map,
        &entries,
    );

    // Expected combinations: (0,0)->"0", (0,1)->"1", (1,0)->"1", (1,1)->"2"
    try testing.expectEqual(@as(usize, 4), entries.items.len);

    // Combination (0, 0) => "0"
    try testing.expectEqual(@as(usize, 2), entries.items[0].pattern.len);
    try testing.expectEqualStrings("0", entries.items[0].pattern[0]);
    try testing.expectEqualStrings("0", entries.items[0].pattern[1]);
    try testing.expectEqualStrings("0", entries.items[0].target_state);

    // Combination (1, 1) => "2"
    try testing.expectEqual(@as(usize, 2), entries.items[3].pattern.len);
    try testing.expectEqualStrings("1", entries.items[3].pattern[0]);
    try testing.expectEqualStrings("1", entries.items[3].pattern[1]);
    try testing.expectEqualStrings("2", entries.items[3].target_state);
}
