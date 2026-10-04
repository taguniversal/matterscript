const std = @import("std");
const testing = std.testing;
const matterscript = @import("matterscript");
const parser = matterscript.ipl_parser;
const network = matterscript.network;

pub fn printIndent(depth: usize) void {
    var i: usize = 0;
    while (i < depth) : (i += 1) std.debug.print("  ", .{});
}

pub fn dumpArg(depth: usize, arg: network.Arg) void {
    printIndent(depth);
    std.debug.print("kind={s} name='{s}' text='{s}'\n", .{ @tagName(arg.kind), arg.name, arg.text });
    if (arg.group) |g| {
        printIndent(depth + 1);
        std.debug.print("group.kind={s}\n", .{@tagName(g.kind)});
        for (g.places) |p| dumpArg(depth + 2, p);
    }
}

pub fn dumpArgs(depth: usize, label: []const u8, args: []const network.Arg) void {
    printIndent(depth);
    std.debug.print("{s} ({d}):\n", .{ label, args.len });
    for (args) |arg| dumpArg(depth + 1, arg);
}

pub fn dumpStatement(depth: usize, i: usize, stmt: network.Statement) void {
    printIndent(depth);
    std.debug.print("resolution[{d}]: {s}\n", .{ i, @tagName(stmt) });
    switch (stmt) {
        .fill => |f| {
            printIndent(depth + 1);
            std.debug.print("dest_name='{s}' expr='{s}'\n", .{ f.dest_name, f.expr });
        },
        .invoke => |inv| {
            printIndent(depth + 1);
            std.debug.print("invoke name='{s}' label={?s}\n", .{ inv.name, inv.label });
            dumpArgs(depth + 1, "invoke.sources", inv.sources);
            dumpArgs(depth + 1, "invoke.destinations", inv.destinations);
        },
        .pure_value => |v| {
            printIndent(depth + 1);
            std.debug.print("pure_value='{s}'\n", .{v});
        },
        .directive => |d| {
            printIndent(depth + 1);
            std.debug.print("directive name='{s}' args='{s}'\n", .{ d.name, d.args });
        },
    }
}

pub fn dumpDef(label: []const u8, def: network.Definition) void {
    std.debug.print("--- {s}: def '{s}' ---\n", .{ label, def.name });
    dumpArgs(0, "sources", def.sources);
    dumpArgs(0, "destinations", def.destinations);
    for (def.resolution, 0..) |stmt, i| dumpStatement(0, i, stmt);
    for (def.contained) |c| std.debug.print("contained: '{s}'\n", .{c.name});
    std.debug.print("\n", .{});
}

pub fn dumpEntry(label: []const u8, e: network.EntryInvocation) void {
    std.debug.print("--- {s}: entry '{s}' ---\n", .{ label, e.name });
    dumpArgs(0, "sources", e.sources);
    dumpArgs(0, "destinations", e.destinations);
    std.debug.print("\n", .{});
}