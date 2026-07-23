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
//   TableDef   - a constant lookup table; either explicit key:value pairs
//                or a generate block evaluated at compile time
//
// Completeness semantics:
//   A source place <> is incomplete (NULL) until filled.
//   An invocation cannot complete until all its source places are filled.
//   A definition cannot emit until its resolution area is complete.
//   Missing table entries remain NULL indefinitely — no error, no completion.
//
// Definitions are flat — no nesting. All definitions live at the top level
// of the network and reference each other by name.

const std = @import("std");

pub const Place = struct {
    name: []const u8,
    kind: PlaceKind,
};

pub const PlaceKind = enum {
    destination,
    source,
};

/// A single entry in an explicit key:value constant table.
pub const TableEntry = struct {
    key: []const u8,
    value: []const u8,
};

/// A single input variable declaration in a generate block.
pub const InputDecl = struct {
    name: []const u8,
    min: i64,
    max: i64,
};

/// A named integer constant in a generate block.
pub const ConstDecl = struct {
    name: []const u8,
    value: i64,
};

/// Expression AST node for the generate block evaluator.
pub const BinaryOp = enum { add, sub, mul, div };

pub const ExprKind = enum {
    integer,   // literal integer
    variable,  // $name
    constant,  // name (no $ — references a const decl)
    binary,    // left op right
    call,      // func(args...)
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

/// A generate block — expression + input ranges + output range + constants.
/// Evaluated at compile time to produce the full key:value table.
pub const GenerateBlock = struct {
    expr: *Expr,
    inputs: []const InputDecl,
    output_min: i64,
    output_max: i64,
    constants: []const ConstDecl,
};

/// The kind of constant table — explicit entries or a generate block.
pub const TableKind = union(enum) {
    explicit: []const TableEntry,
    generate: GenerateBlock,
};

/// A constant lookup table associated with a name-composition invocation.
pub const TableDef = struct {
    composed_name: []const u8,
    kind: TableKind,
};

pub const SourceFill = struct {
    source_name: []const u8,
    expr: []const u8,
};

pub const Invocation = struct {
    name: []const u8,
    args: []const []const u8,
    outputs: []const Place,
};

pub const Statement = union(enum) {
    fill: SourceFill,
    invoke: Invocation,
};

pub const Definition = struct {
    name: []const u8,
    destinations: []const Place,
    sources: []const Place,
    resolution: []const Statement,
    constants: []const TableDef,
};

pub const EntryInvocation = struct {
    name: []const u8,
    args: []const []const u8,
    outputs: []const Place,
};

pub const Network = struct {
    definitions: []const Definition,
    entry: ?EntryInvocation,
};