// Responsibility: Handles block structures and configuration annotations.
const std = @import("std");
const core = @import("core.zig");
const network = @import("../network.zig");

pub fn parseNeighborhoodRulesBlock(p: *core.Parser) ![]const network.NeighborhoodRule {
    try p.expect('{');
    var rules: std.ArrayListUnmanaged(network.NeighborhoodRule) = .empty;
    while (true) {
        p.skipWhitespaceAndComments();
        const c = p.peek() orelse return core.ParseError.UnexpectedEnd;
        if (c == '}') break;
        if (c != '[') return core.ParseError.UnexpectedChar;
        _ = p.advance(); // consume '['

        var pattern: std.ArrayListUnmanaged([]const u8) = .empty;
        while (true) {
            p.skipWhitespaceAndComments();
            const pc = p.peek() orelse return core.ParseError.UnexpectedEnd;
            if (pc == '*') {
                _ = p.advance();
                try pattern.append(p.allocator, "*");
            } else {
                const tok = try p.readName();
                try pattern.append(p.allocator, tok);
            }
            p.skipWhitespaceAndComments();
            if (p.tryConsume(',')) continue;
            break;
        }
        try p.expect(']');
        try p.expect(':');
        p.skipWhitespaceAndComments();
        const value = try p.readName();
        try rules.append(p.allocator, .{
            .pattern = try pattern.toOwnedSlice(p.allocator),
            .value = value,
        });
        p.skipWhitespaceAndComments();
        _ = p.tryConsume(',');
    }
    try p.expect('}');
    return rules.toOwnedSlice(p.allocator);
}
