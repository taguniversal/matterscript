// A generic testbench driving any parsed IPL Definition against
// per-port streams of NULL-delimited tokens, built on Environment/
// rules.run — Fant's single-valued, persistent-place completeness
// model, which is exactly what an ordinary definition's fixed port list
// needs (unlike bag.zig's multiset model, built for a different thing).
//
// Scope (TAG-202, "Coordinating Boundaries"): this is a first-pass
// approximation of Fant's registration-stage/domain-inversion
// coordination cycle (Figure 7.13), not the full mechanism. The real
// cycle is a strict two-phase handshake: present data, wait for full
// output completeness, present NULL, wait for full output
// nullification, THEN allow the next data wavefront. This version
// instead starts a fresh Environment for each wavefront — which gets
// the same functional effect (no stale state leaks into the next
// presentation) without modeling the NULL phase as its own explicit,
// observable step or enforcing strict alternation. Revisit once this is
// working end to end.

const std = @import("std");
const network = @import("../network.zig");
const rules_mod = @import("rules.zig");
const environment = @import("environment.zig");

pub const Environment = environment.Environment;
pub const ExecutableRule = rules_mod.ExecutableRule;

/// One NULL-delimited stream of tokens for a single source port. A
/// stream is exhausted when `index` reaches `tokens.len` — an exhausted
/// port simply never becomes valid again for the rest of the run.
pub const PortStream = struct {
    port: []const u8,
    tokens: []const []const u8,
    index: usize = 0,

    fn exhausted(self: *const PortStream) bool {
        return self.index >= self.tokens.len;
    }

    fn current(self: *const PortStream) ?[]const u8 {
        if (self.exhausted()) return null;
        return self.tokens[self.index];
    }

    fn advance(self: *PortStream) void {
        if (!self.exhausted()) self.index += 1;
    }
};

pub const Presentation = struct {
    /// Captured destination values for one completed data wavefront, by
    /// destination name, resolved to the actual symbol name string —
    /// NOT left as a raw interned index, since each wavefront gets its
    /// own fresh Environment with its own fresh symbol table, discarded
    /// once the wavefront completes. An index captured from one
    /// wavefront's env would be meaningless (or silently wrong) looked
    /// up against a different wavefront's table.
    outputs: std.StringHashMapUnmanaged([]const u8),
};

pub const Testbench = struct {
    allocator: std.mem.Allocator,
    def: network.Definition,
    rules: []const ExecutableRule,
    streams: []PortStream,

    pub fn init(
        allocator: std.mem.Allocator,
        def: network.Definition,
        streams: []PortStream,
    ) !Testbench {
        const rules = try rules_mod.buildRules(allocator, def);
        return .{ .allocator = allocator, .def = def, .rules = rules, .streams = streams };
    }

    /// Runs every queued token to completion, one data wavefront per
    /// captured Presentation, stopping once no further wavefront can
    /// complete (streams exhausted, or a genuinely stuck combination).
    pub fn run(self: *Testbench) ![]const Presentation {
        var presentations: std.ArrayListUnmanaged(Presentation) = .empty;

        outer: while (true) {
            var env = Environment{ .allocator = self.allocator };
            const fed_this_wavefront = try self.allocator.alloc(bool, self.streams.len);
            @memset(fed_this_wavefront, false);

            var report = try rules_mod.run(self.allocator, &env, self.def, self.rules);

            while (!report.complete) {
                var fed_any = false;
                for (self.streams, 0..) |*stream, i| {
                    if (fed_this_wavefront[i]) continue;
                    const tok = stream.current() orelse continue;
                    // Two conventions coexist in real IPL sources: ordinary
                    // $portname references (Fant's standard model — see
                    // FULLADD's $X/$Y/$CI, and this example's $thenname/
                    // $elsename) need a place named after the PORT; joint-
                    // match / discriminator rules keyed on the arriving
                    // VALUE itself (AND2's p/q/r/s, this example's TRUE/
                    // FALSE) need a place named after the TOKEN. Seed both
                    // — harmless when only one is ever referenced (AND2's
                    // port-name places are simply never read), necessary
                    // when a single definition genuinely needs both, as
                    // this one does.
                    try env.seed(stream.port, tok);
                    try env.seed(tok, tok);
                    stream.advance();
                    fed_this_wavefront[i] = true;
                    fed_any = true;
                }
                if (!fed_any) break :outer;
                report = try rules_mod.run(self.allocator, &env, self.def, self.rules);
            }

            var outputs: std.StringHashMapUnmanaged([]const u8) = .empty;
            for (self.def.destinations) |dest| {
                switch (env.get(dest.name)) {
                    .valid => |v| try outputs.put(self.allocator, dest.name, env.symbols.items[v]),
                    .null_value => {},
                }
            }
            try presentations.append(self.allocator, .{ .outputs = outputs });
        }

        return presentations.toOwnedSlice(self.allocator);
    }
};
