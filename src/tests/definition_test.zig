const std = @import("std");
const matterscript = @import("matterscript");
const directives = matterscript.directives;
const core = matterscript.core;
const network = matterscript.network;

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

// Note: parseDomainSpec expects the parser positioned right after the
// "domain" keyword (i.e. past the leading "@domain"), matching how
// definitions.zig's directive loop calls it — it consumes "@" and the
// directive name itself before dispatching here.

test "parseDomainSpec - valid spatial2d with size" {
    const allocator = std.testing.allocator;
    const src = "(spatial2d, size: [64, 32])";
    var p = core.Parser.init(allocator, src);

    const domain = try network.parseDomainSpec(&p);

    try std.testing.expectEqual(network.SpatialDomainKind.spatial2d, domain.kind);

    if (domain.size) |size| {
        try std.testing.expectEqual(@as(usize, 64), size[0]);
        try std.testing.expectEqual(@as(usize, 32), size[1]);
    } else {
        return error.MissingDomainSize;
    }
    try std.testing.expect(domain.value_bounds == null);
}

test "parseDomainSpec - spatial1d with range" {
    const allocator = std.testing.allocator;
    const src = "(spatial1d, range: [0, 15])";
    var p = core.Parser.init(allocator, src);

    const domain = try network.parseDomainSpec(&p);

    try std.testing.expectEqual(network.SpatialDomainKind.spatial1d, domain.kind);
    try std.testing.expect(domain.size == null);

    if (domain.value_bounds) |vb| {
        try std.testing.expectEqual(@as(i64, 0), vb.min);
        try std.testing.expectEqual(@as(i64, 15), vb.max);
    } else {
        return error.MissingValueBounds;
    }
}

test "parseDomainSpec - spatial3d with size and range together" {
    const allocator = std.testing.allocator;
    const src = "(spatial3d, size: [4, 4], range: [-1, 1])";
    var p = core.Parser.init(allocator, src);

    const domain = try network.parseDomainSpec(&p);

    try std.testing.expectEqual(network.SpatialDomainKind.spatial3d, domain.kind);
    try std.testing.expect(domain.size != null);
    try std.testing.expect(domain.value_bounds != null);
}

test "parseDomainSpec - unknown domain kind" {
    const allocator = std.testing.allocator;
    const src = "(hypercube, size: [10, 10])";
    var p = core.Parser.init(allocator, src);

    const result = network.parseDomainSpec(&p);
    try std.testing.expectError(error.UnknownDomainKind, result);
}

test "parseDomainSpec - unknown parameter name" {
    const allocator = std.testing.allocator;
    const src = "(spatial2d, bogus: [1, 2])";
    var p = core.Parser.init(allocator, src);

    const result = network.parseDomainSpec(&p);
    try std.testing.expectError(error.UnknownDomainParameter, result);
}