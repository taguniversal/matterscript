const std = @import("std");
const testing = std.testing;
const network = @import("../network.zig");
const v = @import("validate_args.zig");

fn src(name: []const u8) network.Arg {
    return .{ .kind = .place, .name = name, .text = name ++ "<>", .direction = .source };
}
fn dst(name: []const u8) network.Arg {
    return .{ .kind = .place, .name = name, .text = "$" ++ name, .direction = .destination };
}
fn lit(text: []const u8) network.Arg {
    return .{ .kind = .literal, .text = text };
}

test "definition source accepts name<> places" {
    const args = [_]network.Arg{ src("a"), src("b") };
    try v.validateArgList(&args, .{ .description = "test", .direction = .definition_source });
}

test "definition source rejects $name" {
    const args = [_]network.Arg{dst("a")};
    try testing.expectError(
        error.DestinationInSourcePosition,
        v.validateArgList(&args, .{ .description = "test", .direction = .definition_source }),
    );
}

test "definition destination accepts $name places" {
    const args = [_]network.Arg{ dst("x"), dst("y") };
    try v.validateArgList(&args, .{ .description = "test", .direction = .definition_destination });
}

test "definition destination rejects name<>" {
    const args = [_]network.Arg{src("x")};
    try testing.expectError(
        error.SourceInDestinationPosition,
        v.validateArgList(&args, .{ .description = "test", .direction = .definition_destination }),
    );
}

test "invocation source accepts $name and literals" {
    const args = [_]network.Arg{ dst("a"), lit("0"), dst("b") };
    try v.validateArgList(&args, .{ .description = "test", .direction = .invocation_source });
}

test "invocation source rejects name<>" {
    const args = [_]network.Arg{src("a")};
    try testing.expectError(
        error.SourceInDestinationPosition,
        v.validateArgList(&args, .{ .description = "test", .direction = .invocation_source }),
    );
}

test "invocation destination accepts name<>" {
    const args = [_]network.Arg{ src("out"), src("cout") };
    try v.validateArgList(&args, .{ .description = "test", .direction = .invocation_destination });
}

test "invocation destination rejects literals" {
    const args = [_]network.Arg{lit("0")};
    try testing.expectError(
        error.LiteralInNonSourcePosition,
        v.validateArgList(&args, .{ .description = "test", .direction = .invocation_destination }),
    );
}

test "group recurses with same direction" {
    var members = [_]network.Arg{ src("a"), src("b") };
    const grp = network.PlaceGroup{ .kind = .bundle, .places = &members };
    const args = [_]network.Arg{.{ .kind = .group, .group = &grp }};
    try v.validateArgList(&args, .{ .description = "test", .direction = .definition_source });
}

test "group recursion catches wrong-direction member" {
    var members = [_]network.Arg{ src("a"), dst("b") };
    const grp = network.PlaceGroup{ .kind = .bundle, .places = &members };
    const args = [_]network.Arg{.{ .kind = .group, .group = &grp }};
    try testing.expectError(
        error.DestinationInSourcePosition,
        v.validateArgList(&args, .{ .description = "test", .direction = .definition_source }),
    );
}

test "synthesized entries (empty text) are skipped" {
    const args = [_]network.Arg{.{ .kind = .place, .name = "ms_result" }};
    try v.validateArgList(&args, .{ .description = "test", .direction = .invocation_destination });
}

test "unmarked place is rejected everywhere" {
    const args = [_]network.Arg{.{ .kind = .place, .name = "bare" }};
    try testing.expectError(
        error.UnmarkedPlaceInArgList,
        v.validateArgList(&args, .{ .description = "test", .direction = .definition_source }),
    );
}