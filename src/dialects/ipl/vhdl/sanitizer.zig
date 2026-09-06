// Responsibility: Bridges case-sensitive IPL names
// with case-insensitive VHDL identifiers, handles
// keyword clashes, and rewrites dollar references.
const std = @import("std");
const network = @import("../network.zig");

const IdentifierEntry = struct {
    raw: []const u8,
    emitted: []const u8,
};

/// Maps IPL identifiers to identifiers that are legal and unique in one VHDL
/// definition scope.  IPL compares spellings exactly; VHDL does not compare
/// case, so `a` and `A` must receive different generated names.
const IdentifierMap = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(IdentifierEntry) = .empty,

    fn resolve(map: *IdentifierMap, raw: []const u8) ![]const u8 {
        for (map.entries.items) |entry| {
            if (std.mem.eql(u8, entry.raw, raw)) return entry.emitted;
        }

        const base = try sanitizeName(map.allocator, raw);
        defer map.allocator.free(base);
        var suffix: usize = 0;
        while (true) : (suffix += 1) {
            const candidate = if (suffix == 0)
                try map.allocator.dupe(u8, base)
            else
                try std.fmt.allocPrint(map.allocator, "{s}_{d}", .{ base, suffix });
            var used = false;
            for (map.entries.items) |entry| {
                if (std.mem.eql(u8, entry.emitted, candidate)) {
                    used = true;
                    break;
                }
            }
            if (!used) {
                const raw_copy = try map.allocator.dupe(u8, raw);
                try map.entries.append(map.allocator, .{ .raw = raw_copy, .emitted = candidate });
                return candidate;
            }
            map.allocator.free(candidate);
        }
    }
};

pub fn sanitizeName(allocator: std.mem.Allocator, composed: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(allocator);
    for (composed) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '_') {
            // VHDL identifiers can't contain consecutive underscores —
            // collapse runs of '_' to a single one instead of copying
            // them verbatim.
            if (c == '_' and buf.items.len > 0 and buf.items[buf.items.len - 1] == '_') continue;
            try buf.append(allocator, std.ascii.toLower(c));
        }
    }
    // VHDL identifiers also can't start or end with an underscore.
    // Trim both before deciding whether a reserved-word/digit-start
    // prefix is needed, so a name like "__anon_11" doesn't reintroduce
    // a double underscore when "ms_" gets prepended below.
    const trimmed = std.mem.trim(u8, buf.items, "_");

    const needs_prefix = isVhdlReserved(trimmed) or
        (trimmed.len > 0 and std.ascii.isDigit(trimmed[0]));
    if (needs_prefix) {
        var prefixed: std.ArrayListUnmanaged(u8) = .empty;
        try prefixed.appendSlice(allocator, "ms_");
        try prefixed.appendSlice(allocator, trimmed);
        return prefixed.toOwnedSlice(allocator);
    }
    return allocator.dupe(u8, trimmed);
}

fn isVhdlReserved(name: []const u8) bool {
    const reserved = [_][]const u8{
        "abs",     "access",  "after",     "alias",  "all",        "and",    "architecture", "array",         "assert",    "attribute",
        "begin",   "block",   "body",      "buffer", "bus",        "case",   "component",    "configuration", "constant",  "disconnect",
        "else",    "elsif",   "end",       "entity", "exit",       "file",   "for",          "function",      "generate",  "generic",
        "group",   "guarded", "if",        "impure", "in",         "inout",  "is",           "label",         "library",   "linkage",
        "literal", "loop",    "map",       "mod",    "nand",       "new",    "next",         "nor",           "not",       "null",
        "of",      "on",      "open",      "or",     "others",     "out",    "package",      "port",          "postponed", "procedure",
        "process", "pure",    "range",     "record", "register",   "reject", "rem",          "report",        "return",    "rol",
        "ror",     "select",  "severity",  "signal", "shared",     "sla",    "sll",          "sra",           "srl",       "subtype",
        "then",    "to",      "transport", "type",   "unaffected", "units",  "until",        "use",           "variable",  "wait",
        "when",    "while",   "with",      "xnor",   "xor",
    };
    for (reserved) |keyword| {
        if (std.ascii.eqlIgnoreCase(name, keyword)) return true;
    }
    return false;
}

pub fn normalizeDefinitionIdentifiers(allocator: std.mem.Allocator, raw_def: network.Definition) !network.Definition {
    var names = IdentifierMap{ .allocator = allocator };
    var def = raw_def;
    def.sources = try normalizePlaces(allocator, &names, raw_def.sources);
    def.destinations = try normalizePlaces(allocator, &names, raw_def.destinations);
    def.resolution = try normalizeStatements(allocator, &names, raw_def.resolution);
    def.constants = try normalizeConstants(allocator, &names, raw_def.constants);
    return def;
}

fn normalizePlaces(
    allocator: std.mem.Allocator,
    names: *IdentifierMap,
    places: []const network.Arg,
) ![]const network.Arg {
    var list: std.ArrayListUnmanaged(network.Arg) = .empty;
    for (places) |arg| {
        try list.append(allocator, try normalizeArg(allocator, names, arg));
    }
    return list.toOwnedSlice(allocator);
}

fn normalizeArg(
    allocator: std.mem.Allocator,
    names: *IdentifierMap,
    arg: network.Arg,
) !network.Arg {
    var out = arg;
    if (arg.name.len > 0) {
        out.name = try names.resolve(arg.name);
    }
    if (arg.group) |grp| {
        var nested_places: std.ArrayListUnmanaged(network.Arg) = .empty;
        for (grp.places) |child| {
            try nested_places.append(allocator, try normalizeArg(allocator, names, child));
        }
        const new_grp = try allocator.create(network.PlaceGroup);
        new_grp.* = .{
            .kind = grp.kind,
            .places = try nested_places.toOwnedSlice(allocator),
        };
        out.group = new_grp;
    }
    return out;
}

fn normalizeStatements(
    allocator: std.mem.Allocator,
    names: *IdentifierMap,
    statements: []const network.Statement,
) ![]const network.Statement {
    var normalized: std.ArrayListUnmanaged(network.Statement) = .empty;
    for (statements) |statement| {
        switch (statement) {
            .fill => |raw_fill| {
                var fill = raw_fill;
                if (fill.dest_name.len != 0) fill.dest_name = try names.resolve(fill.dest_name);
                fill.expr = try rewriteDollarReferences(allocator, names, fill.expr);
                try normalized.append(allocator, .{ .fill = fill });
            },
            .invoke => |raw_invocation| {
                var invocation = raw_invocation;
                var sources: std.ArrayListUnmanaged(network.Arg) = .empty;
                for (raw_invocation.sources) |arg| {
                    var updated_arg = arg;
                    if (arg.kind != .group and arg.text.len > 0) {
                        updated_arg.text = try rewriteDollarReferences(allocator, names, arg.text);
                    }
                    try sources.append(allocator, updated_arg);
                }
                invocation.sources = try sources.toOwnedSlice(allocator);
                invocation.destinations = try normalizePlaces(allocator, names, raw_invocation.destinations);
                try normalized.append(allocator, .{ .invoke = invocation });
            },
            .pure_value => |expression| try normalized.append(allocator, .{ .pure_value = try rewriteDollarReferences(allocator, names, expression) }),
            .directive => {
                // TODO try writer.print("  -- @{s}({s}) (directive not yet interpreted)\n", .{ d.name, d.args });
            },
        }
    }
    return normalized.toOwnedSlice(allocator);
}

fn normalizeConstants(
    allocator: std.mem.Allocator,
    names: *IdentifierMap,
    constants: []const network.TableDef,
) ![]const network.TableDef {
    var normalized: std.ArrayListUnmanaged(network.TableDef) = .empty;
    for (constants) |raw_table| {
        var table = raw_table;
        table.composed_name = try rewriteDollarReferences(allocator, names, raw_table.composed_name);
        try normalized.append(allocator, table);
    }
    return normalized.toOwnedSlice(allocator);
}

/// Rewrites only `$identifier` segments; literal values and punctuation keep
/// their source spelling.  This covers source fills, invocation arguments,
/// lookup keys, and pure value expressions without changing IPL semantics.
fn rewriteDollarReferences(allocator: std.mem.Allocator, names: *IdentifierMap, text: []const u8) ![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] != '$') {
            try out.append(allocator, text[i]);
            i += 1;
            continue;
        }
        try out.append(allocator, '$');
        i += 1;
        const start = i;
        while (i < text.len and (std.ascii.isAlphanumeric(text[i]) or text[i] == '_')) i += 1;
        if (i == start) continue;
        try out.appendSlice(allocator, try names.resolve(text[start..i]));
    }
    return out.toOwnedSlice(allocator);
}


// ----------------------------------------------------------------
// Private-function tests. Kept colocated (rather than in
// src/tests/export_vhdl_test.zig) so they can exercise non-pub
// mechanics directly, per zig's normal same-file test visibility.
// API-level tests against write()/writeVhdlNetwork() live in
// src/tests/export_vhdl_test.zig instead, since those only need the
// pub surface and don't justify growing this already-large file.
// ----------------------------------------------------------------
const testing = std.testing;

test "sanitizeName lowercases, strips punctuation, and prefixes reserved/digit-led names" {
    const allocator = testing.allocator;

    const plain = try sanitizeName(allocator, "CARRYOUT");
    defer allocator.free(plain);
    try testing.expectEqualStrings("carryout", plain);

    // Reserved VHDL keyword needs an ms_ prefix to stay a legal identifier.
    const reserved = try sanitizeName(allocator, "Process");
    defer allocator.free(reserved);
    try testing.expectEqualStrings("ms_process", reserved);

    // A leading digit isn't a legal VHDL identifier start either.
    const digit_led = try sanitizeName(allocator, "0S0");
    defer allocator.free(digit_led);
    try testing.expectEqualStrings("ms_0s0", digit_led);
}


pub fn uniqueVhdlName(
    allocator: std.mem.Allocator,
    names: []const []const u8,
    base: []const u8,
) ![]u8 {
    var suffix: usize = 0;
    while (true) : (suffix += 1) {
        const candidate = if (suffix == 0)
            try allocator.dupe(u8, base)
        else
            try std.fmt.allocPrint(allocator, "{s}_{d}", .{ base, suffix });
        var collision = false;
        for (names) |name| {
            if (std.ascii.eqlIgnoreCase(name, candidate)) {
                collision = true;
                break;
            }
        }
        if (!collision) return candidate;
        allocator.free(candidate);
    }
}


test "sanitizeName collapses a multi-variable composed name into one identifier" {
    // This is the exact shape writeExpressionFill hands it for a
    // composed expression like "$A$B()" (see the TAG-190/TAG-160
    // "no declaration for ab" bug, tracked at the call site in
    // src/tests/export_vhdl_test.zig): sanitizeName's own contract —
    // strip non-identifier characters from ONE string — is being met
    // correctly here. The bug is the caller treating a two-variable
    // composed key as if it were a single variable name before this
    // function ever sees it.
    const allocator = testing.allocator;
    const collapsed = try sanitizeName(allocator, "A$B");
    defer allocator.free(collapsed);
    try testing.expectEqualStrings("ab", collapsed);
}

test "sanitizeName never produces consecutive, leading, or trailing underscores" {
    // Regression test: canonicalizeDefNames (parser.zig) used to name
    // anonymous contained definitions "__anon_N" (leading double
    // underscore). scopedDefinitionName joins scope and name with a
    // single "_", so "code" + "_" + "__anon_11" produced
    // "code___anon_11" — three consecutive underscores, which ghdl
    // rejects outright ("two underscores can't be consecutive"). That
    // specific name is now "anon_N" instead, but sanitizeName is
    // hardened here too, since any raw IPL name containing "__", or
    // starting/ending with "_", would trip the same VHDL rule.
    const allocator = testing.allocator;

    const leading = try sanitizeName(allocator, "__anon_11");
    defer allocator.free(leading);
    try testing.expectEqualStrings("anon_11", leading);
    try testing.expect(std.mem.indexOf(u8, leading, "__") == null);

    const joined = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ "code", leading });
    defer allocator.free(joined);
    try testing.expect(std.mem.indexOf(u8, joined, "__") == null);

    const internal = try sanitizeName(allocator, "A__B");
    defer allocator.free(internal);
    try testing.expectEqualStrings("a_b", internal);

    const trailing = try sanitizeName(allocator, "FOO_");
    defer allocator.free(trailing);
    try testing.expectEqualStrings("foo", trailing);
}