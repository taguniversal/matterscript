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

pub fn parseDomainDirective(p: *core.Parser) !network.DomainSpec {
    try p.consumeKeyword("@domain");
    try p.expect('(');
    p.skipWhitespaceAndComments();

    // Parse domain kind (e.g. "spatial2d")
    const kind_str = try p.readName();
    const kind: network.SpatialDomainKind = if (std.mem.eql(u8, kind_str, "spatial2d"))
        .spatial2d
    else
        return error.UnknownDomainKind;

    p.skipWhitespaceAndComments();
    try p.expect(',');
    p.skipWhitespaceAndComments();

    // Parse "size:" parameter
    try p.consumeKeyword("size");
    
    p.skipWhitespaceAndComments();

    // Parse bounds array [width, height]
    try p.expect('[');
    const size_x: usize = @intCast(try p.readInteger());
    p.skipWhitespaceAndComments();
    try p.expect(',');
    p.skipWhitespaceAndComments();
    const size_y: usize = @intCast(try p.readInteger());
    p.skipWhitespaceAndComments();
    try p.expect(']');

    p.skipWhitespaceAndComments();
    try p.expect(')');

    return network.DomainSpec{
        .kind = kind,
        .size_x = size_x,
        .size_y = size_y,
        .size_z = 0,  
    };
}
