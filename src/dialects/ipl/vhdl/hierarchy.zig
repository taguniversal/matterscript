// Per-hierarchy symbol tables. A "hierarchy" is a connected component
// of the invocation graph: definitions that invoke each other
// (directly or transitively) share one symbol table, so a token like
// "TRUE" has the same id whether it's produced by BINEQ or consumed
// by TAG163_TOP. Standalone definitions get their own table.

const std = @import("std");
const network = @import("../network.zig");
const runtime_rules = @import("../runtime/rules.zig");

pub const Tables = struct {
    /// Map from definition name to its hierarchy's symbol table.
    /// Lookups are by name; the map is built once at the start of
    /// emission and never mutated.
    by_name: std.StringHashMapUnmanaged(runtime_rules.SymbolTable),

    pub fn get(self: Tables, name: []const u8) ?runtime_rules.SymbolTable {
        return self.by_name.get(name);
    }
};

fn unionSets(
    allocator: std.mem.Allocator,
    parent: *std.StringHashMapUnmanaged([]const u8),
    a: []const u8,
    b: []const u8,
) !void {
    const ra = find(parent, a);
    const rb = find(parent, b);
    if (std.mem.eql(u8, ra, rb)) return;
    if (std.mem.order(u8, ra, rb) == .lt) {
        try parent.put(allocator, rb, ra);
    } else {
        try parent.put(allocator, ra, rb);
    }
}

/// Build one symbol table per connected component of the invocation
/// graph. Deterministic: walks net.definitions in source order,
/// interning each definition's symbols into its component's table
/// the first time the component is encountered.
pub fn build(allocator: std.mem.Allocator, net: network.Network) !Tables {
    var out: Tables = .{ .by_name = .empty };

    // Union-find over definition names.
    var parent: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer parent.deinit(allocator);

    for (net.definitions) |def| {
        try parent.put(allocator, def.name, def.name);
    }

    for (net.definitions) |def| {
        for (def.resolution) |stmt| {
            if (stmt != .invoke) continue;
            if (!parent.contains(stmt.invoke.name)) continue;
            try unionSets(allocator, &parent, def.name, stmt.invoke.name);
        }
    }

    // For each component, intern symbols in net.definitions order.
    // Use a second map from root → ArrayListUnmanaged symbol buffer
    // while building; convert to SymbolTable at the end.
    var building: std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8)) = .empty;
    defer {
        var it = building.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit(allocator);
        building.deinit(allocator);
    }

    for (net.definitions) |def| {
        const root = find(&parent, def.name);
        const gop = try building.getOrPut(allocator, root);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        try internDefinitionSymbols(allocator, gop.value_ptr, def);
    }

    // Freeze each building buffer into a SymbolTable and populate
    // by_name.
    var it = building.iterator();
    while (it.next()) |entry| {
        const root = entry.key_ptr.*;
        const entries = try entry.value_ptr.toOwnedSlice(allocator);
        const table = runtime_rules.SymbolTable{ .entries = entries };
        // Assign the same table to every definition in the component.
        for (net.definitions) |def| {
            if (std.mem.eql(u8, find(&parent, def.name), root)) {
                try out.by_name.put(allocator, def.name, table);
            }
        }
    }

    return out;
}

fn find(parent: *std.StringHashMapUnmanaged([]const u8), name: []const u8) []const u8 {
    var cur = name;
    while (true) {
        const p = parent.get(cur) orelse return cur;
        if (std.mem.eql(u8, p, cur)) return cur;
        cur = p;
    }
}

pub fn internDefinitionSymbols(
    allocator: std.mem.Allocator,
    table: *std.ArrayListUnmanaged([]const u8),
    def: network.Definition,
) !void {
    for (def.contained) |row| {
        var it = std.mem.splitScalar(u8, row.name, ',');
        while (it.next()) |seg| {
            _ = try internSymbol(table, allocator, std.mem.trim(u8, seg, " \t\r\n"));
        }
        for (row.resolution) |stmt| {
            const value_text = switch (stmt) {
                .pure_value => |v| v,
                .fill => |f| f.expr,
                .invoke, .directive => continue,
            };
            var trimmed = std.mem.trim(u8, value_text, " \t\r\n");
            // Strip a leading '$' so the interned symbol matches what
            // runtime/rules.zig's parseContent produces for the same
            // fill expr. That function strips '$' from
            // "dest<$name>" -> content "name", and lowerRules's
            // outputTokenName looks up the stripped form. Interning
            // the raw "$name" here would produce a symbol table that
            // lowerRules can't find symbols in.
            if (trimmed.len > 0 and trimmed[0] == '$') {
                trimmed = trimmed[1..];
            }
            _ = try internSymbol(table, allocator, trimmed);
        }
    }
}

fn internSymbol(
    list: *std.ArrayListUnmanaged([]const u8),
    allocator: std.mem.Allocator,
    token: []const u8,
) !u64 {
    for (list.items, 0..) |existing, i| {
        if (std.mem.eql(u8, existing, token)) return @intCast(i);
    }
    try list.append(allocator, try allocator.dupe(u8, token));
    return @intCast(list.items.len - 1);
}

pub fn deinit(allocator: std.mem.Allocator, self: *Tables) !void {
    var seen: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer seen.deinit(allocator);

    var it = self.by_name.valueIterator();
    while (it.next()) |table_ptr| {
        const ptr = @intFromPtr(table_ptr.entries.ptr);
        const gop = try seen.getOrPut(allocator, ptr);
        if (gop.found_existing) continue;
        for (table_ptr.entries) |s| allocator.free(s);
        allocator.free(table_ptr.entries);
    }
    self.by_name.deinit(allocator);
}
