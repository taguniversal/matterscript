// parser.zig
// Recursive descent parser for the MatterScript Invocation Language
//
// Authoritative grammar (Fant 2007 p.203):
//
//   Invocation:  NAME($dest1 $dest2)(source1<> source2<>)
//   Definition:  NAME[(source1<> source2<>)($dest1 $dest2) resolution : tables ]
//
//   In a definition:
//     first list  = source places (name<>) — tokens flow IN from outside
//     second list = destination places ($name) — tokens flow OUT to outside
//
//   In an invocation:
//     first list  = destination args ($name or literal) — values passed to definition sources
//     second list = source places (name<>) — outputs returned to caller

const std = @import("std");
pub const core = @import("parser/core.zig");
pub const network = @import("network.zig");
pub const definitions = @import("parser/definitions.zig");



// ----------------------------------------------------------------
// Public API
// ----------------------------------------------------------------

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !network.Network {
    return parseWithTag(allocator, source, null);
}

pub fn parseWithTag(
    allocator: std.mem.Allocator,
    source: []const u8,
    tag: ?[]const u8,
) !network.Network {
    var p = core.Parser.init(allocator, source);
    return parseInner(&p, allocator) catch |err| {
        reportError(&p, err, tag);
        return err;
    };
}

fn canonicalizeDefNames(allocator: std.mem.Allocator, def: *network.Definition, anon_id: *usize) !void {
    if (def.name.len == 0) {
        // No leading underscore: scopedDefinitionName in export_vhdl.zig
        // joins scope and name with "_" (e.g. "code" + "_" + this),
        // and VHDL identifiers can't contain consecutive underscores —
        // a leading "__anon_N" here used to collide into "code___anon_N".
        def.name = try std.fmt.allocPrint(allocator, "anon_{d}", .{anon_id.*});
        anon_id.* += 1;
    }

    // Cast away const qualifier on slice elements to mutate nested definition names in-place
    const mutable_contained = @constCast(def.contained);
    for (mutable_contained) |*child| {
        try canonicalizeDefNames(allocator, child, anon_id);
    }
}

pub fn canonicalizeNames(allocator: std.mem.Allocator, inner_definitions: *std.ArrayListUnmanaged(network.Definition)) !void {
    var anon_id: usize = 0;
    for (inner_definitions.items) |*def| {
        try canonicalizeDefNames(allocator, def, &anon_id);
    }
}

fn parseInner(p: *core.Parser, allocator: std.mem.Allocator) !network.Network {
    var inner_definitions: std.ArrayListUnmanaged(network.Definition) = .empty;
    var entries: std.ArrayListUnmanaged(network.EntryInvocation) = .empty;
    var free_refs: std.ArrayListUnmanaged([]const u8) = .empty;

    while (true) {
        p.skipWhitespaceAndComments();
        if (p.pos >= p.src.len) break;

        if (p.peek() == ':') {
            _ = p.advance();
            continue;
        }

        // A bare $name at the top level is a free-floating "outlying
        // destination place" (§12.7) — not attached to any invocation
        // or definition structure. Zero or more may appear anywhere.
        if (p.peek() == '$') {
            _ = p.advance();
            const ref_name = try p.readName();
            try free_refs.append(allocator, ref_name);
            continue;
        }

        const name_start = p.pos;
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        const next = p.peek() orelse break;

        if (next == '[') {
            p.pos = name_start;
            const def = try definitions.parseDefinition(p);
            try inner_definitions.append(allocator, def);
        } else if (next == '(') {
            const parsed_entry = try p.parseEntryInvocation(name);
            try entries.append(allocator, parsed_entry);
        } else return error.UnexpectedChar;
    }

   // Run recursive canonicalization before freezing into immutable slices
    try canonicalizeNames(allocator, &inner_definitions);

    const net = network.Network{
        .definitions = try inner_definitions.toOwnedSlice(allocator),
        .entries = try entries.toOwnedSlice(allocator),
        .free_destinations = try free_refs.toOwnedSlice(allocator),
    };

    return net;
}

/// On parse failure, print the 1-indexed line/column and the offending
/// line's text. p.pos reflects wherever the deepest failing call left
/// it — Parser is threaded through every function by pointer and never
/// rewound except at a couple of controlled backtrack points — so this
/// works without touching any individual parse function.
///
/// Known gap: parseGenerateBlock spins up a *second*, independent
/// Parser over an extracted sub-string for generate-block expressions.
/// A failure inside that inner parser won't be reflected here — the
/// outer p.pos will just show wherever parseGenerateBlock was called
/// from, not the actual failure point within the expression.
fn reportError(p: *const core.Parser, err: anyerror, tag: ?[]const u8) void {
    var line: usize = 1;
    var col: usize = 1;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i < p.pos and i < p.src.len) : (i += 1) {
        if (p.src[i] == '\n') {
            line += 1;
            col = 1;
            line_start = i + 1;
        } else {
            col += 1;
        }
    }
    var line_end = line_start;
    while (line_end < p.src.len and p.src[line_end] != '\n') line_end += 1;
    const line_text = p.src[line_start..line_end];

    if (tag) |issue_tag| std.debug.print("  [{s}]\n", .{issue_tag});
    std.debug.print("  parse error: {s} at line {d}, column {d}\n", .{ @errorName(err), line, col });
    std.debug.print("    {s}\n", .{line_text});
    std.debug.print("    ", .{});
    var j: usize = 1;
    while (j < col) : (j += 1) std.debug.print(" ", .{});
    std.debug.print("^\n\n", .{});
}