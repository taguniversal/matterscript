const machine = @import("machine.zig");

pub const Program = struct {
    namespace: []const u8 = "",
    machine: machine.Machine,
    export_path: []const u8 = "",
};
