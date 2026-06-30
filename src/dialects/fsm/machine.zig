pub const State = struct {
    name: []const u8,
};

pub const Event = struct {
    name: []const u8,
};

pub const Transition = struct {
    from: []const u8,
    to: []const u8,
    on: []const u8,
};

pub const Machine = struct {
    name: []const u8,
    states: [] const State,
    events: [] const Event,
    transitions: [] const Transition,
};
