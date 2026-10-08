const std =@import("std");

/// True if the expression is a bare key-composition header — a
/// `$`-joined chain of names ending in empty parens, e.g. "$X$Y()",
/// "$newbit$currentstate()". Matches the same shape
/// findComposedDispatchHeader looks for, but at the boundary layer so
/// it can be checked before any emitter modules are imported.
pub fn isKeyCompositionHeader(allocator: std.mem.Allocator, expr: []const u8) bool {
    _ = allocator;
    const trimmed = std.mem.trim(u8, expr, " \t\r\n");
    if (trimmed.len < 4) return false; // "$a()" is the shortest valid form
    if (trimmed[0] != '$') return false;
    if (trimmed[trimmed.len - 1] != ')') return false;
    const open = std.mem.lastIndexOfScalar(u8, trimmed, '(') orelse return false;
    const inside = std.mem.trim(u8, trimmed[open + 1 .. trimmed.len - 1], " \t");
    if (inside.len != 0) return false; // parens are always empty
    const body = std.mem.trim(u8, trimmed[0..open], " \t");
    if (body.len < 2 or body[0] != '$') return false;
    // Every name after the first must be introduced by its own '$'.
    var it = std.mem.splitScalar(u8, body[1..], '$');
    while (it.next()) |name| {
        if (name.len == 0) return false;
        if (std.mem.indexOfAny(u8, name, " \t") != null) return false;
    }
    return true;
}