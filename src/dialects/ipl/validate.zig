// src/dialects/ipl/validate.zig
//
// Post-parse well-formedness checks for a fully-parsed IPL Network.
// These require seeing a Definition and its contained children as a
// whole, not a single grammar production in isolation, so they run once
// parsing has produced a complete AST rather than during parsing itself.
// A Network that fails validation is not well-formed for any backend.

const std = @import("std");
const network = @import("network.zig");

pub const ValidationError = error{
    /// A value transform rule (Fant §12.8.8, e.g. A[g,k,o], G,I[S])
    /// introduced a symbol name identical to one of its containing
    /// definition's own boundary port names. A boundary port and an
    /// internally-formed symbol are different identities; if they share
    /// a name, there's no way to tell, at any later reference, which one
    /// was meant. This must be fixed at the source by renaming the
    /// colliding symbol — never silently disambiguated by the compiler.
    TransformRuleSymbolCollidesWithBoundaryPort,
};

fn isValueTransformRule(def: network.Definition) bool {
    if (def.name.len == 0 or std.ascii.isDigit(def.name[0])) return false;
    if (def.sources.len != 0 or def.destinations.len != 0) return false;
    if (def.resolution.len != 1) return false;
    return def.resolution[0] == .pure_value;
}

fn splitSymbolList(allocator: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, ',');
    while (it.next()) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len > 0) try names.append(allocator, trimmed);
    }
    return names.toOwnedSlice(allocator);
}

fn isBoundaryPortName(def: network.Definition, name: []const u8) bool {
    for (def.sources) |arg| if (std.ascii.eqlIgnoreCase(arg.name, name)) return true;
    for (def.destinations) |arg| if (std.ascii.eqlIgnoreCase(arg.name, name)) return true;
    return false;
}

fn validateDefinition(allocator: std.mem.Allocator, def: network.Definition) !void {
    for (def.contained) |contained| {
        if (isValueTransformRule(contained)) {
            for (try splitSymbolList(allocator, contained.name)) |name| {
                if (isBoundaryPortName(def, name)) return ValidationError.TransformRuleSymbolCollidesWithBoundaryPort;
            }
            for (try splitSymbolList(allocator, contained.resolution[0].pure_value)) |name| {
                if (isBoundaryPortName(def, name)) return ValidationError.TransformRuleSymbolCollidesWithBoundaryPort;
            }
        }
        try validateDefinition(allocator, contained); // nested definitions have their own scope to check too
    }
}

pub fn validate(allocator: std.mem.Allocator, net: network.Network) !void {
    for (net.definitions) |def| try validateDefinition(allocator, def);
}