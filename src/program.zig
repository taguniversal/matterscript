pub const Program = struct {
    namespace: []const u8 = "",
    seed: []const u8 = "",

    ca_rule: u8 = 0,
    ca_width: usize = 0,
    ca_steps: usize = 0,

    height_scale: f32 = 1.0,

    export_format: []const u8 = "",
    export_path: []const u8 = "",
};
