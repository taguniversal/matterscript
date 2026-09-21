
// Holds the current state of every named place during a single
// definition's fixed-point evaluation (see rules.zig for the driver). A
// place is either null (unresolved) or valid, carrying an interned
// symbol index — the same small-integer scheme the VHDL emitter uses
// (lookup.internSymbol / data_value(N)), so a value produced here and a
// value produced by the VHDL path are directly, numerically comparable.

const std = @import("std");

pub const PlaceState = union(enum) {
    null_value,
    valid: u64,
};

pub const Environment = struct {
    allocator: std.mem.Allocator,
    places: std.StringHashMapUnmanaged(PlaceState) = .empty,
    symbols: std.ArrayListUnmanaged([]const u8) = .empty, // interned table, index = payload value

    pub fn deinit(self: *Environment) void {
        self.places.deinit(self.allocator);
        self.symbols.deinit(self.allocator);
    }

    pub fn get(self: *const Environment, name: []const u8) PlaceState {
        return self.places.get(name) orelse .null_value;
    }

    pub fn isValid(self: *const Environment, name: []const u8) bool {
        return self.get(name) == .valid;
    }

    pub fn allValid(self: *const Environment, names: []const []const u8) bool {
        for (names) |name| if (!self.isValid(name)) return false;
        return true;
    }

    /// Interns `symbol` and marks `place` valid with that index. A place
    /// already valid is left untouched — first successful assertion
    /// wins, matching the define-once discipline from the spatial
    /// domain work.
    pub fn assertSymbol(self: *Environment, place: []const u8, symbol: []const u8) !void {
        if (self.isValid(place)) return;
        const idx = try internSymbol(&self.symbols, self.allocator, symbol);
        try self.places.put(self.allocator, place, .{ .valid = idx });
    }

    pub fn assertLiteral(self: *Environment, place: []const u8, value: u64) !void {
        if (self.isValid(place)) return;
        try self.places.put(self.allocator, place, .{ .valid = value });
    }

    /// Copies another place's current value onto `place` ("$name"
    /// fills). A no-op if the source isn't valid yet — the rule this
    /// belongs to shouldn't have fired in that case.
    pub fn copyFrom(self: *Environment, place: []const u8, source: []const u8) !void {
        if (self.isValid(place)) return;
        switch (self.get(source)) {
            .valid => |v| try self.places.put(self.allocator, place, .{ .valid = v }),
            .null_value => {},
        }
    }

    /// How a test or caller provides a definition's inputs before running.
    pub fn seed(self: *Environment, place: []const u8, symbol: []const u8) !void {
        try self.assertSymbol(place, symbol);
    }
};

fn internSymbol(list: *std.ArrayListUnmanaged([]const u8), allocator: std.mem.Allocator, token: []const u8) !u64 {
    for (list.items, 0..) |existing, i| {
        if (std.mem.eql(u8, existing, token)) return @intCast(i);
    }
    try list.append(allocator, token);
    return @intCast(list.items.len - 1);
}