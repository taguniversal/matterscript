const std = @import("std");
const matterscript = @import("matterscript");
const directives = matterscript.directives;
const core = matterscript.core;

test "parseNeighborhoodRulesBlock - valid rules" {
    const allocator = std.testing.allocator;
    const src = "{ [*]: default_state, [a, b]: active_state, }";
    var p = core.Parser.init(allocator, src);

    const rules = try directives.parseNeighborhoodRulesBlock(&p);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
        }
        allocator.free(rules);
    }

    try std.testing.expectEqual(@as(usize, 2), rules.len);
    try std.testing.expectEqualStrings("*", rules[0].pattern[0]);
    try std.testing.expectEqualStrings("default_state", rules[0].value);

    try std.testing.expectEqual(@as(usize, 2), rules[1].pattern.len);
    try std.testing.expectEqualStrings("a", rules[1].pattern[0]);
    try std.testing.expectEqualStrings("b", rules[1].pattern[1]);
    try std.testing.expectEqualStrings("active_state", rules[1].value);
}

test "parseDomainDirective - valid spatial2d" {
    const allocator = std.testing.allocator;
    const src = "@domain(spatial2d, size: [64, 32])";
    var p = core.Parser.init(allocator, src);

    const domain = try directives.parseDomainDirective(&p);

    try std.testing.expectEqual(domain.kind, .spatial2d);
    
    if (domain.size) |size| {
        try std.testing.expectEqual(size[0], 64);
        try std.testing.expectEqual(size[1], 32);
    } else {
        return error.MissingDomainSize;
    }
}

test "parseDomainDirective - unknown domain kind" {
    const allocator = std.testing.allocator;
    const src = "@domain(hypercube, size: [10, 10])";
    var p = core.Parser.init(allocator, src);

    const result = directives.parseDomainDirective(&p);
    try std.testing.expectError(error.UnknownDomainKind, result);
}