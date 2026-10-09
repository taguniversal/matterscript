// Builds an executable rule set from a parsed Definition and runs it to
// a fixed point, per Fant's completeness semantics (network.zig's own
// header comment): a destination place is null until something resolves
// it; nothing forces completion; a place with no available resolving
// rule stays null indefinitely — reported, not treated as an error.
//
// Scope (per the IPL Reference Runtime ticket): ordinary fills (literals
// and $name references) and value transform rules only.
// No ROM lookup tables, no @generate.
const build_options = @import("build_options");
const std = @import("std");
const network = @import("../network.zig");
const value_transform = @import("../value_transform.zig");
const environment = @import("environment.zig");

const max_invocation_depth = 32;

pub const Environment = environment.Environment;
pub const PlaceState = environment.PlaceState;

pub const SelectAction = union(enum) {
    symbol: []const u8,
    copy_from: []const u8,
};

pub const SelectEntry = struct { key: []const u8, action: SelectAction };

pub const RuleAction = union(enum) {
    literal: u64,
    copy_from: []const u8,
    assert_symbol: []const u8,
    /// Conditional invocation `$a$b()`. The current VALUES of rule.inputs
    /// (in order) are joined with "," to form a name; the contained
    /// pure-value definition with that name supplies the symbol asserted
    /// into dest. No matching entry leaves dest null (missing entries
    /// stay NULL, per network.zig's completeness note).
    select: []const SelectEntry,
};

pub const ExecutableRule = struct {
    inputs: []const []const u8, // all must be valid for this rule to fire
    dest: []const u8,
    action: RuleAction,
};

fn findComposedDispatchHeader(allocator: std.mem.Allocator, def: network.Definition) !?[]const []const u8 {
    for (def.resolution) |stmt| {
        if (stmt != .pure_value) continue;
        if (try parseInvocationArgs(allocator, stmt.pure_value)) |args| return args;
    }
    return null;
}

/// "$a$b$c()", "$select( )" -> ["a","b","c"]; null for anything that
/// isn't exactly this shape (a $-joined name chain followed by empty
/// parens). The parens are always empty — "()" is the marker, not an
/// arg list. Whitespace is tolerated around the whole expression and
/// inside the parens, but NOT inside the name chain itself: "$a $b()"
/// is rejected, because every name after the first must be introduced
/// by its own '$', not a space.
fn parseInvocationArgs(allocator: std.mem.Allocator, expr: []const u8) !?[]const []const u8 {
    const trimmed = std.mem.trim(u8, expr, " \t\r\n");
    if (trimmed.len < 2 or trimmed[trimmed.len - 1] != ')') return null;
    const open = std.mem.lastIndexOfScalar(u8, trimmed, '(') orelse return null;
    const inside = std.mem.trim(u8, trimmed[open + 1 .. trimmed.len - 1], " \t");
    if (inside.len != 0) return null; // only ever empty — "()" is the marker, not an arg list
    const body = std.mem.trim(u8, trimmed[0..open], " \t");
    if (body.len < 2 or body[0] != '$') return null;
    var args: std.ArrayListUnmanaged([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, body[1..], '$');
    while (it.next()) |raw| {
        // A name must be a bare identifier run: no internal whitespace,
        // no empty segments. "$a $b" -> raw "a " fails here, so the
        // space-separated form is rejected rather than silently accepted.
        const name = raw;
        if (name.len == 0) return null;
        if (std.mem.indexOfAny(u8, name, " \t") != null) return null;
        try args.append(allocator, name);
    }
    return try args.toOwnedSlice(allocator);
}

/// Contained pure-value definitions (0,0[0] etc.): name -> value.
fn buildSelectTable(allocator: std.mem.Allocator, def: network.Definition) ![]const SelectEntry {
    var entries: std.ArrayListUnmanaged(SelectEntry) = .empty;
    for (def.contained) |c| {
        if (c.sources.len != 0 or c.destinations.len != 0) continue;
        for (c.resolution) |stmt| {
            switch (stmt) {
                .pure_value => |val| try entries.append(allocator, .{
                    .key = c.name,
                    .action = .{ .symbol = std.mem.trim(u8, val, " \t\r\n") },
                }),
                else => {},
            }
        }
    }
    return entries.toOwnedSlice(allocator);
}

// Build Rules Helpers
const Binding = struct { callee: []const u8, caller: []const u8 };

fn findDefinition(defs: []const network.Definition, name: []const u8) ?network.Definition {
    for (defs) |d| if (std.mem.eql(u8, d.name, name)) return d;
    return null;
}

/// Slice 1: plain named places only. Bundles are Ticket 2.
fn scalarPlace(arg: network.Arg) ![]const u8 {
    if (arg.kind == .group) return error.BundleInvocationNotSupported;
    if (arg.kind != .place or arg.name.len == 0) return error.UnsupportedInvocationArgument;
    return arg.name;
}

fn mapName(allocator: std.mem.Allocator, prefix: []const u8, bindings: []const Binding, name: []const u8) ![]const u8 {
    for (bindings) |b| if (std.mem.eql(u8, b.callee, name)) return b.caller;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, name });
}

fn isSourcePort(callee: network.Definition, name: []const u8) bool {
    return argListHasPlace(callee.sources, name);
}

fn argListHasPlace(args: []const network.Arg, name: []const u8) bool {
    for (args) |arg| {
        if (arg.kind == .group) {
            if (arg.group) |g| if (argListHasPlace(g.places, name)) return true;
            continue;
        }
        if (std.mem.eql(u8, arg.name, name)) return true;
    }
    return false;
}

fn producedBy(rules: []const ExecutableRule, name: []const u8) bool {
    for (rules) |r| if (std.mem.eql(u8, r.dest, name)) return true;
    return false;
}

/// A place that is neither a port nor produced by any rule can only be
/// made valid by the environment seeding a token of that name. Inside an
/// inlined callee nothing seeds it, so it would silently stall. Fail
/// loudly instead. (This is the FULLADD case: S,U,W[K,M] and friends.)
fn checkInvocable(callee: network.Definition, rules: []const ExecutableRule, name: []const u8) !void {
    if (isSourcePort(callee, name) or producedBy(rules, name)) return;

    if (build_options.verbose_dumps) {
        std.debug.print("checkInvocable({s}) failed on name='{s}'\n", .{ callee.name, name });
        std.debug.print("  callee sources: ", .{});
        for (callee.sources) |s| std.debug.print("'{s}' ", .{s.name});
        std.debug.print("\n  rule dests: ", .{});
        for (rules) |r| std.debug.print("'{s}' ", .{r.dest});
        std.debug.print("\n", .{});
    }
    return error.ValueKeyedInvocationNotSupported;
}

/// Binds one caller argument to one callee port. A plain place binds
/// 1:1. A group argument — explicit bracket syntax at the call site,
/// e.g. {$Q1 $Q2 $Q3 $Q4} — requires the callee's own declared port in
/// that position to ALSO be a group with the same member count, and
/// binds each member positionally. This is TAG-213 slice 2a: explicit,
/// fully-spelled-out groups only. A bare name aliasing a callee's group
/// port with no brackets at the call site (4BITADD($A $B $CARRYIN)) is
/// the harder, separate mechanism — still falls through to scalarPlace
/// below and fails loudly rather than silently binding wrong.
fn bindArgument(
    allocator: std.mem.Allocator,
    bindings: *std.ArrayListUnmanaged(Binding),
    formal: network.Arg,
    actual: network.Arg,
) !void {
    if (formal.kind == .group and actual.kind == .group) {
        const formal_group = formal.group orelse return error.InvocationArityMismatch;
        const actual_group = actual.group orelse return error.InvocationArityMismatch;
        if (formal_group.places.len != actual_group.places.len) return error.InvocationArityMismatch;
        for (formal_group.places, actual_group.places) |fp, ap| {
            try bindings.append(allocator, .{ .callee = try scalarPlace(fp), .caller = try scalarPlace(ap) });
        }
        return;
    }
    try bindings.append(allocator, .{ .callee = try scalarPlace(formal), .caller = try scalarPlace(actual) });
}

fn inlineInvocation(
    allocator: std.mem.Allocator,
    out: *std.ArrayListUnmanaged(ExecutableRule),
    inv: network.Invocation,
    index: usize,
    definitions: []const network.Definition,
    depth: usize,
) anyerror!void {
    const callee = findDefinition(definitions, inv.name) orelse return error.UnknownCallee;
    if (inv.sources.len != callee.sources.len or inv.destinations.len != callee.destinations.len)
        return error.InvocationArityMismatch;

    var bindings: std.ArrayListUnmanaged(Binding) = .empty;
    for (inv.sources, callee.sources) |actual, formal| try bindArgument(allocator, &bindings, formal, actual);
    for (inv.destinations, callee.destinations) |actual, formal| try bindArgument(allocator, &bindings, formal, actual);

    const callee_rules = try buildRulesAtDepth(allocator, callee, definitions, depth + 1);
    if (build_options.verbose_dumps) {
        std.debug.print("\n--- rules for {s} ---\n", .{callee.name});
        for (callee_rules, 0..) |r, i| {
            std.debug.print("rule[{d}] inputs=[", .{i});
            for (r.inputs, 0..) |inp, j| {
                if (j > 0) std.debug.print(",", .{});
                std.debug.print("{s}", .{inp});
            }
            std.debug.print("] dest={s} action={s}\n", .{ r.dest, @tagName(r.action) });
        }
    }
    for (callee_rules) |r| {
        for (r.inputs) |input| try checkInvocable(callee, callee_rules, input);
        switch (r.action) {
            .copy_from => |src| try checkInvocable(callee, callee_rules, src),
            .select => |entries| for (entries) |e| {
                if (e.action == .copy_from) try checkInvocable(callee, callee_rules, e.action.copy_from);
            },
            else => {},
        }
    }

    // Local index, not a global counter: nested prefixes compose
    // ("AND3#1.AND#0.") and stay unique. `inv.label` is ignored for now.
    const prefix = try std.fmt.allocPrint(allocator, "{s}#{d}.", .{ callee.name, index });

    for (callee_rules) |r| {
        const inputs = try allocator.alloc([]const u8, r.inputs.len);
        for (r.inputs, 0..) |input, k| inputs[k] = try mapName(allocator, prefix, bindings.items, input);

        const action: RuleAction = switch (r.action) {
            .literal => |v| .{ .literal = v },
            .assert_symbol => |s| .{ .assert_symbol = s }, // a VALUE, not a place
            .copy_from => |src| .{ .copy_from = try mapName(allocator, prefix, bindings.items, src) },
            .select => |entries| blk: {
                const mapped = try allocator.alloc(SelectEntry, entries.len);
                for (entries, 0..) |e, i| {
                    mapped[i] = .{
                        .key = e.key, // a VALUE — never renamed
                        .action = switch (e.action) {
                            .symbol => |s| .{ .symbol = s },
                            .copy_from => |src| .{ .copy_from = try mapName(allocator, prefix, bindings.items, src) },
                        },
                    };
                }
                break :blk .{ .select = mapped };
            },
        };

        try out.append(allocator, .{
            .inputs = inputs,
            .dest = try mapName(allocator, prefix, bindings.items, r.dest),
            .action = action,
        });
    }
}

pub fn buildRules(allocator: std.mem.Allocator, def: network.Definition) ![]const ExecutableRule {
    return buildRulesInNetwork(allocator, def, &.{});
}

/// `definitions` is the network's flat definition list, used to resolve
/// callee names for `.invoke` statements.
pub fn buildRulesInNetwork(
    allocator: std.mem.Allocator,
    def: network.Definition,
    definitions: []const network.Definition,
) ![]const ExecutableRule {
    return buildRulesAtDepth(allocator, def, definitions, 0);
}

fn buildRulesAtDepth(
    allocator: std.mem.Allocator,
    def: network.Definition,
    definitions: []const network.Definition,
    depth: usize,
) anyerror![]const ExecutableRule {
    if (depth > max_invocation_depth) return error.InvocationDepthExceeded;
    var rules: std.ArrayListUnmanaged(ExecutableRule) = .empty;

    // Value transform rules — reusing the exact same parsing/grouping/
    // validation the VHDL emitter and validate.zig share, so there is
    // only ever one implementation of "what is a value transform rule."
    const vt_rules = try value_transform.collectValueTransformRules(allocator, def);

    var non_dest_ports_def = def;
    non_dest_ports_def.destinations = &.{};
    try value_transform.assertNoTransformRuleSymbolCollidesWithPort(non_dest_ports_def, vt_rules);

    const rule_groups = try value_transform.groupRulesByTarget(allocator, vt_rules);
    for (rule_groups) |group| {
        for (group.contributing_inputs.items) |inputs| {
            try rules.append(allocator, .{
                .inputs = inputs,
                .dest = group.target,
                .action = .{ .assert_symbol = group.target },
            });
        }
    }
    std.debug.print("[build] after vt rules: {d} rules\n", .{rules.items.len});

    if (try findComposedDispatchHeader(allocator, def)) |dispatch_inputs| {
        std.debug.print("[build] {s}: dispatch_inputs.len = {d}\n", .{ def.name, dispatch_inputs.len });
        for (dispatch_inputs) |d| std.debug.print("  dispatch input: '{s}'\n", .{d});
        // Bare "$a$b$c()" header, no fill wrapper — e.g. fanin's
        // "$select( )" or FULLADD's "$X$Y$C()". Compiles to the same
        // .select mechanism a fill-embedded "$a$b()" already uses:
        // read the actual VALUES of dispatch_inputs, join with ","
        // match against each branch's own name.
        try appendSelectRules(allocator, &rules, dispatch_inputs, def);
        std.debug.print("[build] after dispatch header block: {d} rules\n", .{rules.items.len});
    } else if (def.sources.len > 0 and vt_rules.len == 0) {
        // Bare source clause ($A : or $A $B $CI :) with no value-transform
        // rules — the contained entries are token-named dispatch cases
        // (K[Y<K>], 0,S0[detect<no> state<S1>]) keyed by the VALUES of the
        // source places. Watch the source places, key the select entries
        // by the case name. Distinct from the composed-header path only
        // in where the input place names come from: there, from the
        // $a$b() header; here, from def.sources directly.
        var source_names: std.ArrayListUnmanaged([]const u8) = .empty;
        for (def.sources) |arg| {
            if (arg.kind == .place) try source_names.append(allocator, arg.name);
        }
        try appendSelectRules(allocator, &rules, source_names.items, def);
    } else {
        // Fill-shaped children of def.contained (Z0[OUT<$Z0>],
        // RXN[WATER<w1>]) are a separate, one-input hop off whatever place
        // the joint match above just asserted — gated on the target name
        // alone, not the raw joint-match inputs.
        for (def.contained) |contained| {
            if (contained.sources.len != 0 or contained.destinations.len != 0) continue;
            for (contained.resolution) |stmt| {
                if (stmt != .fill) continue;
                const f = stmt.fill;
                const expr = std.mem.trim(u8, f.expr, " \t\r\n");

                const inputs = try allocator.alloc([]const u8, 1);
                inputs[0] = contained.name;

                const action: RuleAction = if (expr.len > 0 and expr[0] == '$')
                    .{ .copy_from = expr[1..] }
                else
                    .{ .assert_symbol = expr };

                try rules.append(allocator, .{ .inputs = inputs, .dest = f.dest_name, .action = action });
            }
        }
    }
    std.debug.print("[build] after contained fill loop: {d} rules\n", .{rules.items.len});

    // Ordinary fills — a literal is a zero-input rule (fires
    // immediately); "$name" is a one-input rule copying that place's
    // value once valid.
    for (def.resolution) |stmt| {
        if (stmt != .fill) continue;
        const f = stmt.fill;
        const expr = std.mem.trim(u8, f.expr, " \t\r\n");

        if (try parseInvocationArgs(allocator, expr)) |args| {
            try rules.append(allocator, .{
                .inputs = args,
                .dest = f.dest_name,
                .action = .{ .select = try buildSelectTable(allocator, def) },
            });
            continue;
        }

        if (expr.len > 0 and expr[0] == '$') {
            const ref = expr[1..];
            const inputs = try allocator.alloc([]const u8, 1);
            inputs[0] = ref;
            try rules.append(allocator, .{ .inputs = inputs, .dest = f.dest_name, .action = .{ .copy_from = ref } });
        } else {
            try rules.append(allocator, .{ .inputs = &.{}, .dest = f.dest_name, .action = .{ .assert_symbol = expr } });
        }
    }
    std.debug.print("[build] after resolution fills: {d} rules\n", .{rules.items.len});

    var invoke_index: usize = 0;
    for (def.resolution) |stmt| {
        if (stmt != .invoke) continue;
        try inlineInvocation(allocator, &rules, stmt.invoke, invoke_index, definitions, depth);
        invoke_index += 1;
    }

    for (rules.items, 0..) |r, i| {
        std.debug.print("[build:{s}] rule[{d}] dest='{s}' inputs.len={d} action={s}\n", .{ def.name, i, r.dest, r.inputs.len, @tagName(r.action) });
    }

    return rules.toOwnedSlice(allocator);
}

/// Builds `.select` rules watching `inputs` (place names), one per
/// distinct destination place named in `def.contained`'s fills, with
/// select entries keyed by the contained row's name. Shared between
/// the composed-header path and the bare-source-clause path — the
/// only difference between them is where `inputs` comes from.
fn appendSelectRules(
    allocator: std.mem.Allocator,
    rules: *std.ArrayListUnmanaged(ExecutableRule),
    inputs: []const []const u8,
    def: network.Definition,
) !void {
    var by_dest: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(SelectEntry)) = .empty;
    for (def.contained) |contained| {
        if (contained.sources.len != 0 or contained.destinations.len != 0) continue;
        for (contained.resolution) |stmt| {
            if (stmt != .fill) continue;
            const f = stmt.fill;
            const expr = std.mem.trim(u8, f.expr, " \t\r\n");
            const action: SelectAction = if (expr.len > 0 and expr[0] == '$')
                .{ .copy_from = expr[1..] }
            else
                .{ .symbol = expr };

            const gop = try by_dest.getOrPut(allocator, f.dest_name);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(allocator, .{ .key = contained.name, .action = action });
        }
    }
    var it = by_dest.iterator();
    while (it.next()) |entry| {
        try rules.append(allocator, .{
            .inputs = inputs,
            .dest = entry.key_ptr.*,
            .action = .{ .select = try entry.value_ptr.toOwnedSlice(allocator) },
        });
    }
}

fn destinationSatisfied(env: *Environment, arg: network.Arg) bool {
    if (arg.kind == .group) {
        const g = arg.group orelse return false;
        return switch (g.kind) {
            .bundle => for (g.places) |p| {
                if (!destinationSatisfied(env, p)) break false;
            } else true,
            .mutex, .arbitration => for (g.places) |p| {
                if (destinationSatisfied(env, p)) break true;
            } else false,
        };
    }
  
    return env.isValid(arg.name);
}

pub const StuckPlace = struct {
    place: []const u8,
    /// Unresolved inputs of whichever rule(s) target this place — one
    /// level deep, not a transitive trace back to the ultimate cause.
    /// If "L" shows up here because it's itself waiting on something
    /// else, that's a natural next enhancement, not attempted yet.
    waiting_on: []const []const u8,
};

pub const CompletionReport = struct {
    complete: bool,
    stuck: []const StuckPlace, // empty when complete
};

pub fn run(
    allocator: std.mem.Allocator,
    env: *Environment,
    def: network.Definition,
    rules: []const ExecutableRule,
) !CompletionReport {
    var changed = true;
    while (changed) {
        changed = false;
        for (rules) |rule| {
            if (env.isValid(rule.dest)) continue;
            if (!env.allValid(rule.inputs)) continue;
               std.debug.print("[rules.run] firing rule dest='{s}' inputs.len={d} action={s}\n",.{ rule.dest, rule.inputs.len, @tagName(rule.action) });
            switch (rule.action) {
                .literal => |v| try env.assertLiteral(rule.dest, v),
                .copy_from => |src| try env.copyFrom(rule.dest, src),
                .assert_symbol => |sym| try env.assertSymbol(rule.dest, sym),
                .select => |entries| {
                    const names = try allocator.alloc([]const u8, rule.inputs.len);
                    defer allocator.free(names);
                    for (rule.inputs, 0..) |input, i| {
                        names[i] = switch (env.get(input)) {
                            .valid => |v| env.symbols.items[v],
                            .null_value => unreachable, // allValid() gated this rule
                        };
                    }
                    const key = try std.mem.join(allocator, ",", names);
                    defer allocator.free(key);
                    for (entries) |e| {
                        if (std.mem.eql(u8, e.key, key)) {
                            switch (e.action) {
                                .symbol => |sym| try env.assertSymbol(rule.dest, sym),
                                .copy_from => |src| try env.copyFrom(rule.dest, src),
                            }
                            break;
                        }
                    }
                },
            }
            // Only a real state transition counts as progress. A
            // copy_from whose source turns out not to be valid yet
            // no-ops — that must not read as "changed", or a rule whose
            // source can never become valid spins the fixed-point loop
            // forever instead of correctly settling into a stuck report.
            if (env.isValid(rule.dest)) changed = true;
        }
    }

    var stuck: std.ArrayListUnmanaged(StuckPlace) = .empty;
    var incomplete = false;
    for (def.destinations) |dest| {
        std.debug.print("[rules.run] checking dest kind={s} name='{s}' satisfied={}\n", .{ @tagName(dest.kind), dest.name, destinationSatisfied(env, dest) });
        if (destinationSatisfied(env, dest)) continue;
        incomplete = true;

        if (dest.kind == .group) {
            // Coarse for now: names the group by its raw source text
            // rather than tracing which member(s) are still unresolved.
            // Refine once group-aware stuck diagnostics are needed.
            try stuck.append(allocator, .{ .place = dest.text, .waiting_on = &.{} });
            continue;
        }

        var waiting: std.ArrayListUnmanaged([]const u8) = .empty;
        for (rules) |rule| {
            if (!std.mem.eql(u8, rule.dest, dest.name)) continue;
            for (rule.inputs) |input| {
                if (env.isValid(input)) continue;
                var already_listed = false;
                for (waiting.items) |w| {
                    if (std.mem.eql(u8, w, input)) {
                        already_listed = true;
                        break;
                    }
                }
                if (!already_listed) try waiting.append(allocator, input);
            }
        }
        try stuck.append(allocator, .{ .place = dest.name, .waiting_on = try waiting.toOwnedSlice(allocator) });
    }

    return .{ .complete = !incomplete, .stuck = try stuck.toOwnedSlice(allocator) };
}
