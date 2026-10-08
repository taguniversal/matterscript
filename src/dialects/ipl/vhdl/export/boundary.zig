// Responsibility: Handles all boundary counting, port generation (writeBoundaryPorts), 
// valid declarations, assignments, and validation expressions

const std = @import("std");
const network = @import("../../network.zig");
const sanitizer = @import("../sanitizer.zig");
const sanitizeName = sanitizer.sanitizeName;

pub fn normalizeReturnDestinations(
    allocator: std.mem.Allocator,
    raw_def: network.Definition,
) !network.Definition {
    if (raw_def.destinations.len != 0) return raw_def;

    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(allocator);
    var normalized: std.ArrayListUnmanaged(network.Statement) = .empty;

    for (raw_def.resolution) |stmt| {
        switch (stmt) {
            .fill => |raw_f| {
                var f = raw_f;
                if (f.dest_name.len == 0) f.dest_name = "ms_result";
                var have = false;
                for (names.items) |n| {
                    if (std.mem.eql(u8, n, f.dest_name)) {
                        have = true;
                        break;
                    }
                }
                if (!have) try names.append(allocator, f.dest_name);
                try normalized.append(allocator, .{ .fill = f });
            },
            else => try normalized.append(allocator, stmt),
        }
    }

    if (names.items.len > 0) {
        var dests: std.ArrayListUnmanaged(network.Arg) = .empty;
        for (names.items) |n| try dests.append(allocator, .{ .kind = .place, .name = n });

        var def = raw_def;
        def.destinations = try dests.toOwnedSlice(allocator);
        def.resolution = try normalized.toOwnedSlice(allocator);
        return def;
    }
    return raw_def;
}


pub fn argContainsName(arg: network.Arg, name: []const u8) bool {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                if (argContainsName(child, name)) return true;
            }
        },
        .place => return std.mem.eql(u8, arg.name, name),
        else => {},
    }
    return false;
}

pub fn isBoundaryPort(
    allocator: std.mem.Allocator,
    def: network.Definition,
    name: []const u8,
) bool {
    // Compare on sanitized forms: an IPL port named "$0" becomes VHDL
    // "ms_0", and a rule fill value "0" also sanitizes to "ms_0" — they
    // refer to the same VHDL identifier, so a raw-string comparison
    // misses the match and the emitter wrongly synthesizes an
    // intermediate signal that collides with the port.
    const sanitized = sanitizeName(allocator, name) catch return false;
    defer allocator.free(sanitized);
    for (def.sources) |src| {
        if (argContainsSanitizedName(allocator, src, sanitized)) return true;
    }
    for (def.destinations) |dest| {
        if (argContainsSanitizedName(allocator, dest, sanitized)) return true;
    }
    return false;
}

fn argContainsSanitizedName(
    allocator: std.mem.Allocator,
    arg: network.Arg,
    sanitized: []const u8,
) bool {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                if (argContainsSanitizedName(allocator, child, sanitized)) return true;
            }
        },
        .place => {
            const arg_id = sanitizeName(allocator, arg.name) catch return false;
            defer allocator.free(arg_id);
            if (std.ascii.eqlIgnoreCase(arg_id, sanitized)) return true;
        },
        else => {},
    }
    return false;
}

/// Recursively counts the total number of individual scalar or port places
/// contained within a slice of definition arguments or groups.
pub fn boundaryCount(args: []const network.Arg) usize {
    // Deliberately mirrors writeBoundaryPorts' own switch exactly
    // (group → recurse, place → +1, anything else → +0), rather than
    // counting every non-group kind, so this can never again disagree
    // with what actually gets printed — see the parseArg fix for
    // '$name' destinations for what happens when it does.
    var count: usize = 0;
    for (args) |arg| {
        switch (arg.kind) {
            .group => if (arg.group) |grp| {
                count += boundaryCount(grp.places);
            },
            .place => count += 1,
            else => {},
        }
    }
    return count;
}

pub fn placeBoundaryCount(place: network.Place) usize {
    const group = place.group orelse return 1;
    if (group.kind == .bundle) return 1;
    return boundaryCount(group.places);
}

/// Recursively generates VHDL port definitions (`in` or `out`) for boundary sources
/// and destinations, mapping them to `ncl_signal` types.
pub fn writeBoundaryPorts(
    allocator: std.mem.Allocator,
    writer: anytype,
    arg: network.Arg,
    dir: []const u8,
    port_index: *usize,
    boundary_count: usize,
    port_names: *std.ArrayListUnmanaged([]const u8),
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                try writeBoundaryPorts(allocator, writer, child, dir, port_index, boundary_count, port_names);
            }
        },
        .place => {
            const port_id = try sanitizeName(allocator, arg.name);
            defer allocator.free(port_id);
            try port_names.append(allocator, try allocator.dupe(u8, port_id));

            port_index.* += 1;
            const is_last = (port_index.* == boundary_count);
            // ncl_signal (SIGNAL_WIDTH = DATA_WIDTH + 1 bits), not a
            // bare DATA_WIDTH-bit vector: every consumer downstream
            // (is_data/payload/null_value/data_value, and the
            // "x(7 downto 1)" case-key builders) already assumes the
            // 8-bit encoding with an embedded validity bit at index 0.
            // Declaring the port itself one bit narrower is what made
            // valid_of(x) unresolvable and produced the "value
            // constraints don't match target ones" / "left bound
            // incompatible with range" warnings on every assignment.
            try writer.print("    {s} : {s} ncl_signal{s}\n", .{
                port_id,
                dir,
                if (is_last) "" else ";",
            });
        },
        else => {},
    }
}

pub fn writeBoundaryValidDeclarations(
    allocator: std.mem.Allocator,
    writer: anytype,
    arg: network.Arg,
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                try writeBoundaryValidDeclarations(allocator, writer, child);
            }
        },
        .place => {
            const port_id = try sanitizeName(allocator, arg.name);
            defer allocator.free(port_id);
            try writer.print("  signal {s}_valid : std_logic;\n", .{port_id});
        },
        else => {},
    }
}

pub fn writeBoundaryValidAssignments(
    allocator: std.mem.Allocator,
    writer: anytype,
    arg: network.Arg,
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| {
                try writeBoundaryValidAssignments(allocator, writer, child);
            }
        },
        .place => {
            const port_id = try sanitizeName(allocator, arg.name);
            defer allocator.free(port_id);
            try writer.print("  {s}_valid <= valid_of({s});\n", .{ port_id, port_id });
        },
        else => {},
    }
}

pub fn writeBoundaryValidExpression(
    allocator: std.mem.Allocator,
    writer: anytype,
    arg: network.Arg,
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places, 0..) |child, i| {
                if (i > 0) try writer.print(" and ", .{});
                try writeBoundaryValidExpression(allocator, writer, child);
            }
        },
        .place => {
            const port_id = try sanitizeName(allocator, arg.name);
            defer allocator.free(port_id);
            try writer.print("{s}_valid", .{port_id});
        },
        else => {},
    }
}


/// Mirrors writeBoundaryPorts' own traversal (group -> recurse,
/// place -> sanitized name, anything else -> skipped) but collects
/// the resulting port identifiers in order instead of writing them,
/// so a port map's formal (left-hand) names can be built to match
/// exactly what the target entity actually declares.
pub fn collectBoundaryPortNames(allocator: std.mem.Allocator, args: []const network.Arg) ![]const []const u8 {
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    for (args) |arg| try collectBoundaryPortNamesInto(allocator, arg, &names);
    return names.toOwnedSlice(allocator);
}

pub fn collectBoundaryPortNamesInto(
    allocator: std.mem.Allocator,
    arg: network.Arg,
    out: *std.ArrayListUnmanaged([]const u8),
) !void {
    switch (arg.kind) {
        .group => if (arg.group) |grp| {
            for (grp.places) |child| try collectBoundaryPortNamesInto(allocator, child, out);
        },
        .place => try out.append(allocator, try sanitizeName(allocator, arg.name)),
        else => {},
    }
}

/// Geometry-only definitions (@domain(spatial2d|spatial3d) with no @generate block)
/// describe physical structure, not hardware — they are emitted as meshes by ipl_export_mesh,
/// never as VHDL. Skipping them before destination normalization avoids mistaking geometry
/// bindings (point/edge/loop/face fills with no real destinations) for an implicit hardware return value.
pub fn shouldSkipSpatialGeometry(def: network.Definition) bool {
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
