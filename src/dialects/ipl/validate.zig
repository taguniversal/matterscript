
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
};

fn validateDefinition(allocator: std.mem.Allocator, def: network.Definition) !void {
    const rules = try value_transform.collectValueTransformRules(allocator, def);
    try value_transform.assertNoTransformRuleSymbolCollidesWithPort(def, rules);

    for (def.contained) |contained| {
        try validateDefinition(allocator, contained); // nested definitions have their own scope to check too
    }
}

pub fn validate(allocator: std.mem.Allocator, net: network.Network) !void {
    for (net.definitions) |def| try validateDefinition(allocator, def);
}