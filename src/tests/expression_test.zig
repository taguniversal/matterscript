const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const core = parser.core;
const expressions = parser.expressions;

test "parseILExpr parses composition refs and function calls" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var p = core.Parser.init(allocator, "foo($a, $b)");
    const slice = try expressions.parseILExpr(&p);
    try testing.expectEqualStrings("foo($a, $b)", slice);
    
    // Verify AST expression attachment
    try testing.expect(p.last_expr != null);
    try testing.expectEqual(matterscript.network.ExprKind.call, p.last_expr.?.kind);
    try testing.expectEqualStrings("foo", p.last_expr.?.func);
    try testing.expectEqual(@as(usize, 2), p.last_expr.?.args.len);
}

test "parseILExpr handles $-composition refs and empty fills" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var p = core.Parser.init(allocator, "$A$B()");
    const slice = try expressions.parseILExpr(&p);
    try testing.expectEqualStrings("$A$B()", slice);

    var p_empty = core.Parser.init(allocator, "<>");
    const slice_empty = try expressions.parseILExpr(&p_empty);
    try testing.expectEqualStrings("", slice_empty);
}

test "parseILCallArgument parses nested call arguments and variables" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var p = core.Parser.init(allocator, "loop(edge($p0, $p1), 42)");
    const expr = try expressions.parseILCallArgument(&p);

    try testing.expectEqual(matterscript.network.ExprKind.call, expr.kind);
    try testing.expectEqualStrings("loop", expr.func);
    try testing.expectEqual(@as(usize, 2), expr.args.len);

    // First argument should be a nested call to 'edge'
    try testing.expectEqual(matterscript.network.ExprKind.call, expr.args[0].kind);
    try testing.expectEqualStrings("edge", expr.args[0].func);
    try testing.expectEqual(@as(usize, 2), expr.args[0].args.len);

    // Inside edge: $p0 and $p1 variables
    try testing.expectEqual(matterscript.network.ExprKind.variable, expr.args[0].args[0].kind);
    try testing.expectEqualStrings("p0", expr.args[0].args[0].name);

    // Second argument should be a constant/numeric value literal
    try testing.expectEqual(matterscript.network.ExprKind.constant, expr.args[1].kind);
    try testing.expectEqualStrings("42", expr.args[1].name);
}