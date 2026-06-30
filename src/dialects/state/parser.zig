const std = @import("std");
const machine = @import("machine.zig");

const ParseError = error{
    MissingMachineName,
    MissingStateName,
    MissingEventName,
    MissingTransitionFields,
    UnexpectedKeyword,
    OutOfMemory,
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !machine.Machine {
    var name: []const u8 = "";
    var states: std.ArrayListUnmanaged(machine.State)      = .empty;
    var events: std.ArrayListUnmanaged(machine.Event)      = .empty;
    var transitions: std.ArrayListUnmanaged(machine.Transition) = .empty;

    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "--")) continue;

        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const keyword = tokens.next() orelse continue;

        if (std.mem.eql(u8, keyword, "machine")) {
            name = tokens.next() orelse return ParseError.MissingMachineName;
        } else if (std.mem.eql(u8, keyword, "state")) {
            const state_name = tokens.next() orelse return ParseError.MissingStateName;
            try states.append(allocator, .{ .name = state_name });
        } else if (std.mem.eql(u8, keyword, "event")) {
            const event_name = tokens.next() orelse return ParseError.MissingEventName;
            try events.append(allocator, .{ .name = event_name });
        } else if (std.mem.eql(u8, keyword, "transition")) {
            const from = tokens.next() orelse return ParseError.MissingTransitionFields;
            const to   = tokens.next() orelse return ParseError.MissingTransitionFields;
            const on   = tokens.next() orelse return ParseError.MissingTransitionFields;
            try transitions.append(allocator, .{ .from = from, .to = to, .on = on });
        } else {
            continue;
        }
    }

    return machine.Machine{
        .name        = name,
        .states      = try states.toOwnedSlice(allocator),
        .events      = try events.toOwnedSlice(allocator),
        .transitions = try transitions.toOwnedSlice(allocator),
    };
}
