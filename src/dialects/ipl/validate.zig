const std = @import("std");
const network = @import("network.zig");
const value_transform = @import("value_transform.zig");

pub const ValidationError = error{
    /// A value transform rule (Fant §12.8.8, e.g. A[g,k,o], G,I[S])
    /// introduced a symbol name identical to one of its containing
    /// definition's own boundary port names. This must be fixed at the
    /// source by renaming the colliding symbol — never silently
    /// disambiguated by the compiler.
    TransformRuleSymbolCollidesWithBoundaryPort,

    /// An invocation (an entry line or a `.invoke` statement) names a
    /// definition that does not exist in this network. Definitions are
    /// flat: every callee must be a top-level definition in the same
    /// source, never resolved from another example or from nesting.
    UndefinedInvocation,

    /// Two top-level definitions share a name, which would make callee
    /// resolution ambiguous.
    DuplicateDefinition,

    /// A `def.contained` entry has its own port interface (sources
    /// and/or destinations) or an `.invoke` statement of its own — i.e.
    /// it is a genuine, separately-invocable definition, not a lookup
    /// table row. MatterScript enforces a flat definition space: every
    /// real definition lives at the top level and is connected to
    /// others only via a `.invoke` statement in a top-level
    /// definition's own resolution, never by nesting one definition's
    /// body inside another's.
    NestedDefinitionNotAllowed,
};

/// Detail for the errors above, since a Zig error can't carry a payload.
/// Slices point into the network's own memory.
pub const Diagnostic = struct {
    /// The undefined callee, the duplicated definition name, or the
    /// improperly nested definition's name.
    name: []const u8 = "",
    /// The definition containing the problem; empty for entry lines.
    in: []const u8 = "",
};

fn validateDefinition(allocator: std.mem.Allocator, def: network.Definition) !void {
    const rules = try value_transform.collectValueTransformRules(allocator, def);
    try value_transform.assertNoTransformRuleSymbolCollidesWithPort(def, rules);

    for (def.contained) |contained| {
        try validateDefinition(allocator, contained); // nested definitions have their own scope to check too
    }
}

fn isDefined(defs: []const network.Definition, name: []const u8) bool {
    for (defs) |d| if (std.mem.eql(u8, d.name, name)) return true;
    return false;
}

/// A legitimate `def.contained` entry is a lookup/table row: no port
/// interface of its own, and a resolution made up only of `.fill` or
/// `.pure_value` statements (the two shapes every real example uses —
/// value-transform fan-out symbols, fill-shaped children, and pure-value
/// dispatch-table entries). Anything else — a declared source or
/// destination, or an `.invoke` of its own — means someone nested a real
/// definition instead of putting it at the top level.
fn isLookupEntry(contained: network.Definition) bool {
    if (contained.sources.len != 0 or contained.destinations.len != 0) return false;
    for (contained.resolution) |stmt| {
        switch (stmt) {
            .fill, .pure_value => {},
            .invoke, .directive => return false,
        }
    }
    return true;
}

fn checkNoNestedDefinitions(def: network.Definition, diag: *Diagnostic) ValidationError!void {
    for (def.contained) |contained| {
        if (!isLookupEntry(contained)) {
            diag.* = .{ .name = contained.name, .in = def.name };
            return error.NestedDefinitionNotAllowed;
        }
        try checkNoNestedDefinitions(contained, diag); // catch accidental multi-level nesting too
    }
}

fn checkInvocations(
    defs: []const network.Definition,
    def: network.Definition,
    diag: *Diagnostic,
) ValidationError!void {
    for (def.resolution) |stmt| {
        if (stmt != .invoke) continue;
        const callee = stmt.invoke.name;
        if (!isDefined(defs, callee)) {
            diag.* = .{ .name = callee, .in = def.name };
            return error.UndefinedInvocation;
        }
    }
}

fn checkNames(net: network.Network, diag: *Diagnostic) ValidationError!void {
    for (net.definitions, 0..) |def, i| {
        if (def.name.len == 0) continue;
        for (net.definitions[0..i]) |earlier| {
            if (std.mem.eql(u8, earlier.name, def.name)) {
                diag.* = .{ .name = def.name };
                return error.DuplicateDefinition;
            }
        }
    }

    for (net.entries) |e| {
        if (!isDefined(net.definitions, e.name)) {
            diag.* = .{ .name = e.name };
            return error.UndefinedInvocation;
        }
    }

    for (net.definitions) |def| {
        try checkNoNestedDefinitions(def, diag);
        try checkInvocations(net.definitions, def, diag);
    }
}

pub fn validateWithDiagnostic(
    allocator: std.mem.Allocator,
    net: network.Network,
    diag: *Diagnostic,
) !void {
    for (net.definitions) |def| try validateDefinition(allocator, def);
    try checkNames(net, diag);
}

pub fn validate(allocator: std.mem.Allocator, net: network.Network) !void {
    var diag: Diagnostic = .{};
    validateWithDiagnostic(allocator, net, &diag) catch |err| {
        switch (err) {
            error.UndefinedInvocation => if (diag.in.len > 0)
                std.debug.print("validation error: definition '{s}' invokes '{s}', which is not defined in this network\n", .{ diag.in, diag.name })
            else
                std.debug.print("validation error: entry invokes '{s}', which is not defined in this network\n", .{diag.name}),
            error.DuplicateDefinition => std.debug.print("validation error: definition '{s}' is defined more than once\n", .{diag.name}),
            error.NestedDefinitionNotAllowed => std.debug.print("validation error: '{s}' is nested inside '{s}'; MatterScript requires a flat definition space — move '{s}' to the top level and invoke it by name\n", .{ diag.name, diag.in, diag.name }),
            else => {},
        }
        return err;
    };
}

pub fn stubDef(name: []const u8, resolution: []const network.Statement) network.Definition {
    return .{ .name = name, .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = resolution };
}

pub fn stubDefWithPorts(
    name: []const u8,
    sources: []const network.Arg,
    resolution: []const network.Statement,
) network.Definition {
    return .{ .name = name, .sources = sources, .destinations = &.{}, .constants = &.{}, .resolution = resolution };
}

pub fn stubDefIn(name: []const u8, resolution: []const network.Statement, contained: []const network.Definition) network.Definition {
    return .{ .name = name, .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = resolution, .contained = contained };
}

pub fn stubInvoke(callee: []const u8) network.Statement {
    return .{ .invoke = .{ .label = null, .name = callee, .sources = &.{}, .destinations = &.{} } };
}

pub fn stubFill(dest_name: []const u8, expr: []const u8) network.Statement {
    return .{ .fill = .{ .dest_name = dest_name, .expr = expr } };
}
