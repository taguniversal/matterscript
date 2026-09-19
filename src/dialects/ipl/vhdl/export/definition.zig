const std = @import("std");
const network = @import("../../network.zig");
const value_transform = @import("value_transform.zig");
const boundary = @import("boundary.zig");
const sanitizer = @import("../sanitizer.zig");
const invocation = @import("invocation.zig");
const definition = @import("definition.zig");
const rom_lookup = @import("rom_lookup.zig");

/// Returns true if this is a spatial geometry-only definition that should be skipped for VHDL emission.
fn shouldSkipSpatialGeometry(def: network.Definition) bool {
    if (def.generateBlock == null) {
        if (def.domain_spec) |spec| {
            switch (spec.kind) {
                .spatial2d, .spatial3d => return true,
                .spatial1d => {},
            }
        }
    }
    return false;
}

pub fn writeDefinition(
    allocator: std.mem.Allocator,
    writer: anytype,
    raw_def: network.Definition,
    scope: []const u8,
) !void {
    if (value_transform.isValueTransformRule(raw_def)) return;
    if (shouldSkipSpatialGeometry(raw_def)) return;

    var def = try boundary.normalizeReturnDestinations(allocator, raw_def);
    def = try sanitizer.normalizeDefinitionIdentifiers(allocator, def);

    const def_id = try invocation.scopedDefinitionName(allocator, scope, def.name);
    defer allocator.free(def_id);

    // 1. Emit Header & Entity Ports
    try definition.writeEntityHeader(allocator, writer, def, def_id);

    // 2. Process Nested Contained Definitions
    try definition.writeContainedDefinitions(allocator, writer, def, def_id);

    // 3. Architecture Declarations (Signals, Components)
    try writer.print("architecture rtl of {s} is\n", .{def_id});
    try definition.writeArchitectureDeclarations(allocator, writer, def, scope);

    // 4. Architecture Body
    try writer.print("begin\n\n", .{});
    try invocation.writeInvocations(allocator, writer, def, scope);
    try boundary.writeCompletenessLogic(allocator, writer, def);
    try rom_lookup.writeRomTableProcesses(allocator, writer, def);
    try value_transform.writeTransformRules(allocator, writer, def);
    try boundary.writeDestinationFills(allocator, writer, def);

    try writer.print("\nend rtl;\n", .{});
}