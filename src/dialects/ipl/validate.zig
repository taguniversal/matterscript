// Post-parse well-formedness checks for a fully-parsed IPL Network.
// These require seeing a Definition and its contained children as a
// whole, not a single grammar production in isolation, so they run once
// parsing has produced a complete AST rather than during parsing itself.
// A Network that fails validation is not well-formed for any backend.

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
    /// definition that does not exist in this network. Examples are
    /// self-contained: everything invoked must be defined in the same
    /// source, never resolved from another example.
    UndefinedInvocation,

    /// Two top-level definitions share a name, which would make callee
    /// resolution ambiguous.
    DuplicateDefinition,
};

const Scope = struct {
    def: network.Definition,
    parent: ?*const Scope,
};

/// Detail for the errors above, since a Zig error can't carry a payload.
/// Slices point into the network's own memory.
pub const Diagnostic = struct {
    /// The undefined callee, or the duplicated definition name.
    name: []const u8 = "",
    /// The definition containing the bad invocation; empty for entry lines.
    in: []const u8 = "",
};

pub fn validateDefinition(allocator: std.mem.Allocator, def: network.Definition) !void {
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

/// Innermost first: the caller's nested definitions, then each enclosing
/// definition's, then top-level. Any contained name counts, including
/// joint-match children like `0,0`. An invoke of one of those is a bug
/// this check won't catch, but rejecting a valid nested definition would
/// be worse.
fn resolves(top: []const network.Definition, scope: ?*const Scope, name: []const u8) bool {
    var s = scope;
    while (s) |sc| : (s = sc.parent) {
        if (isDefined(sc.def.contained, name)) return true;
    }
    return isDefined(top, name);
}

fn checkInvocations(
    top: []const network.Definition,
    def: network.Definition,
    parent: ?*const Scope,
    diag: *Diagnostic,
) ValidationError!void {
    const here = Scope{ .def = def, .parent = parent };
    for (def.resolution) |stmt| {
        if (stmt != .invoke) continue;
        const callee = stmt.invoke.name;
        if (!resolves(top, &here, callee)) {
            diag.* = .{ .name = callee, .in = def.name };
            return error.UndefinedInvocation;
        }
    }
    for (def.contained) |c| try checkInvocations(top, c, &here, diag);
}

/// Callees resolve against top-level definitions only. Contained
/// definitions (joint-match children like `0,0[0]`) are not invocable
/// by name. Definition order doesn't matter.
pub fn checkNames(net: network.Network, diag: *Diagnostic) ValidationError!void {
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

    for (net.definitions) |def| try checkInvocations(net.definitions, def, null, diag);
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
            else => {},
        }
        return err;
    };
}

pub fn stubDef(name: []const u8, resolution: []const network.Statement) network.Definition {
    return .{ .name = name, .sources = &.{}, .destinations = &.{}, .constants = &.{}, .resolution = resolution };
}

pub fn stubInvoke(callee: []const u8) network.Statement {
    return .{ .invoke = .{ .label = null, .name = callee, .sources = &.{}, .destinations = &.{} } };
}
