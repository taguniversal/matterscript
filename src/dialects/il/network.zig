// network.zig
// Abstract Syntax Tree for the MatterScript Invocation Language
// Based on Karl Fant's Invocation Language from Computer Science Reconsidered
//
// Authoritative grammar from Fant (2007) p.203:
//
//   Invocation:  NAME($place1 $place2)(placeA<> placeB<>)
//     - first list:  destination places — values flow IN from caller
//     - second list: source places — values flow OUT to caller
//
//   Definition:  NAME[(placeA<> placeB<>)($result1 $result2) ... : ... ]
//     - first list:  source places — values flow IN to the definition
//     - second list: destination places — values flow OUT of the definition
//
// This is the opposite order from a naive reading:
//   In a definition, source places RECEIVE tokens from the outside.
//   In a definition, destination places EMIT tokens to the outside.
//
// Completeness semantics:
//   A destination place is incomplete (NULL) until the resolving expression fills it.
//   A definition cannot emit until all its destination places are filled.
//   Missing table entries remain NULL indefinitely — no error, no completion.

const std = @import("std");

pub const PlaceKind = enum {
    /// source place: name<>
    /// In a definition: receives tokens from outside (input to the definition)
    /// In an invocation: receives tokens from the definition (output from invocation)
    source,
    /// destination place: $name
    /// In a definition: emits tokens to outside (output of the definition)
    /// In an invocation: provides tokens to the definition (input to invocation)
    destination,
};

pub const Place = struct {
    name: []const u8, // "" means unnamed — the abbreviated single-return
    // form (Fant §12.3.4), associates implicitly to
    // the invocation's own place
    kind: PlaceKind,
    content: ?[]const u8 = null, // literal content between < and >, if
    // present (e.g. state<S0>, value<0>)
};

/// A single entry in an explicit key:value constant table.
pub const TableEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// Input variable declaration in a generate block.
pub const InputDecl = struct {
    name: []const u8,
    min: i64,
    max: i64,
};

/// Named integer constant in a generate block.
pub const ConstDecl = struct {
    name: []const u8,
    value: i64,
};

pub const BinaryOp = enum { add, sub, mul, div };

pub const ExprKind = enum {
    integer,
    variable, // $name — references a source place value
    constant, // name  — references a const decl
    binary,
    call,
};

pub const Expr = struct {
    kind: ExprKind,
    int_val: i64 = 0,
    name: []const u8 = "",
    op: BinaryOp = .add,
    left: ?*Expr = null,
    right: ?*Expr = null,
    func: []const u8 = "",
    args: []const *Expr = &.{},
};

pub const GenerateBlock = struct {
    expr: *Expr,
    inputs: []const InputDecl,
    output_min: i64,
    output_max: i64,
    constants: []const ConstDecl,
};

pub const TableKind = union(enum) {
    explicit: []const TableEntry,
    generate: GenerateBlock,
};

pub const TableDef = struct {
    composed_name: []const u8,
    kind: TableKind,
};

pub const SourceFill = struct {
    /// The destination place being filled (output of definition)
    dest_name: []const u8,
    /// The expression whose value fills the place
    expr: []const u8,
};

pub const Invocation = struct {
    name: []const u8,
    /// Destination places — values provided by caller to the definition
    args: []const []const u8,
    /// Source places — values returned from the definition to the caller
    outputs: []const Place,
};

pub const Statement = union(enum) {
    fill: SourceFill,
    invoke: Invocation,
    pure_value: []const u8, // a bare name-composition or literal with no
    // explicit fill/invocation syntax — Fant's "Pure Value
    // Expression" and the abbreviated "Constant Definition" form
    // (e.g. the "1" inside "0[1]"). Semantics/resolution deferred.
};

pub const Definition = struct {
    name: []const u8,
    sources: []const Place,
    destinations: []const Place,
    resolution: []const Statement,
    constants: []const TableDef,
    contained: []const Definition = &.{}, // definitions nested inside
    // this one's brackets, after the resolution's ':' separator
    // (§12.3.2) — ranges from full sub-networks (FULLADD's nested
    // OR/AND/NOT) down to bare constant definitions (0[1], 1[2]).
    // Name resolution and VHDL emission are deliberately deferred.
};

/// Top-level entry invocation.
/// NAME($arg1 $arg2)(output1<> output2<>)
pub const EntryInvocation = struct {
    name: []const u8,
    /// Destination args — values passed in to the definition's sources
    args: []const []const u8,
    /// Source places — outputs returned to the top-level context
    outputs: []const Place,
};

pub const Network = struct {
    definitions: []const Definition,
    entries: []const EntryInvocation,
    free_destinations: []const []const u8 = &.{}, // bare $name references
    // appearing at the top level of the network, outside any
    // invocation or definition syntax — Fant's "outlying
    // destination places" (§12.7). Zero or more may appear,
    // anywhere in the string. Each participates through name
    // correspondence with a source place of the same name
    // elsewhere — including, in feedback cases like Example 12.41's
    // value<>/$value, the very invocation that precedes it.
    // Semantics/VHDL emission are deliberately deferred here —
    // this only captures the syntax.
};
