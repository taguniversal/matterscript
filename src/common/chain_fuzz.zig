const std = @import("std");
const mkrand = @import("mkrand");

pub const ChainSeed = struct {
    height: u64,
    seed: mkrand.Seg = mkrand.seedUnit,
};

pub const Stream = struct {
    state: mkrand.Seg,
    counter: u64 = 0,

    pub fn init(seed: []const u8) Stream {
        return .{
            .state = mkrand.seedFromString(seed),
            .counter = 0,
        };
    }

    pub fn nextSeg(self: *Stream) mkrand.Seg {
        self.state = mkrand.next(self.state);
        self.counter += 1;
        return self.state;
    }

    pub fn nextU64(self: *Stream) u64 {
        const seg = self.nextSeg();
        return @truncate(seg);
    }

    pub fn nextBool(self: *Stream) bool {
        return (self.nextU64() & 1) == 1;
    }

    pub fn nextIndex(self: *Stream, len: usize) usize {
        if (len == 0) return 0;
        return @intCast(self.nextU64() % len);
    }

    pub fn nextRange(self: *Stream, min: u64, max: u64) u64 {
        if (max <= min) return min;
        return min + (self.nextU64() % (max - min));
    }
};


fn hexNibble(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHex,
    };
}

pub fn makeChainSeed(
    height: u64,
) !ChainSeed {
    return .{
        .height = height,
        .seed =  mkrand.seedFromString("fuzz"),
    };
}


test "chain_fuzz advances mkrand stream" {
    const seed = "fuzzyseed";

    var stream = Stream.init(seed);

    const a = stream.nextSeg();
    const b = stream.nextSeg();
    const c = stream.nextSeg();

    // stream should advance
    try std.testing.expect(a != b);
    try std.testing.expect(b != c);
    try std.testing.expect(a != c);

    // counter should track calls
    try std.testing.expectEqual(@as(u64, 3), stream.counter);
}
