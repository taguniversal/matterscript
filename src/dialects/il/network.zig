// network.zig
// Abstract Syntax Tree for the MatterScript Invocation Language
// Based on Karl Fant's Invocation Language from Computer Science Reconsidered
//
// Core concepts:
//   Theng      - something with a location that asserts a value (wire, cell, token)
//   Place      - a named location in the network (source or destination)
//   Definition - a named, flat network fragment with inputs, outputs,
//                a resolution area, and optional constant tables
//   Invocation - the application of a definition to actual tokens
//   TableDef   - a constant lookup table; name composition resolves to a value
//
// Completeness semantics:
//   A source place <> is incomplete (NULL) until filled.
//   An invocation cannot complete until all its source places are filled.
//   A definition cannot emit until its resolution area is complete.
//   Missing table entries remain NULL indefinitely — no error, no completion.
//
// Definitions are flat — no nesting. All definitions live at the top level
// of the network and reference each other by name. Nesting is purely syntactic
// sugar that a pre-processor can flatten before parsing.

/// A named location in the network.
/// Destinations receive tokens ($name — prefix).
/// Sources emit tokens once complete (name<> — suffix).
pub const Place = struct {
    name: []const u8,
    kind: PlaceKind,
};

pub const PlaceKind = enum {
    /// $name — receives a token from the outer context
    destination,
    /// name<> — emits a token to the outer context once filled
    source,
};

/// A single entry in a constant lookup table.
/// key   — the composed name string (e.g. "13" from $a=1, $b=3)
/// value — the token value that flows back when the key matches
pub const TableEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// A constant lookup table associated with a name-composition invocation.
/// composed_name — the template (e.g. "$a$b") whose vars are substituted
///                 at runtime to form the lookup key
/// entries        — ordered list of key:value pairs
/// Unmatched keys produce no output and remain NULL indefinitely.
pub const TableDef = struct {
    composed_name: []const u8,
    entries: []const TableEntry,
};

/// A source fill statement in the resolution area.
/// Corresponds to: result<$expr>
/// Pushes the value of expr into the named source place.
pub const SourceFill = struct {
    /// The source place being filled (e.g. "result")
    source_name: []const u8,
    /// The expression whose value fills the place.
    /// Either a destination reference ("$a"), a composition ("$a$b"),
    /// or an invocation output reference.
    expr: []const u8,
};

/// A single invocation in the resolution area.
/// Corresponds to: name(($a $b)(out<>))
/// All invocations are flat references to top-level definitions by name.
pub const Invocation = struct {
    /// The definition being invoked
    name: []const u8,
    /// Destination places passed as arguments — bound to the definition's
    /// destination list in order
    args: []const []const u8,
    /// Source places declared at this site to receive the definition's outputs
    outputs: []const Place,
};

/// A statement in the resolution area — either a source fill or an invocation.
pub const Statement = union(enum) {
    fill: SourceFill,
    invoke: Invocation,
};

/// A complete definition — the fundamental unit of the IL.
/// Corresponds to Fant's definition form:
///   name[($dest ...)(source<> ...)
///     resolution area
///   |
///     constant definitions
///   ]
///
/// Definitions are always flat — they reference other definitions by name only.
pub const Definition = struct {
    name: []const u8,
    /// Input places — tokens flow in from the outer context
    destinations: []const Place,
    /// Output places — tokens flow out once resolution is complete
    sources: []const Place,
    /// Statements in the resolution area — fills and invocations
    resolution: []const Statement,
    /// Constant lookup tables (defined after the | separator)
    constants: []const TableDef,
};

/// The top-level entry invocation that starts token flow into the network.
/// Corresponds to: name((arg ...)(output<> ...))
pub const EntryInvocation = struct {
    name: []const u8,
    /// Literal token values passed as arguments
    args: []const []const u8,
    /// Source places in the outer (top-level) context to receive outputs
    outputs: []const Place,
};

/// A complete IL network — the root AST node produced by the parser.
/// All definitions are flat and live at the top level.
/// The entry invocation is optional — a file with only definitions is a library.
pub const Network = struct {
    definitions: []const Definition,
    entry: ?EntryInvocation,
};