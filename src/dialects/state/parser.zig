const std = @import("std");
const machine = @import("machine.zig");

pub fn parse(source: []const u8) !machine.Machine {
    _ = source;

    // temporary: same demo output, but now main.zig can call parse(source)
    return .{
        .name = "CoffeeShop",
        .states = &.{
            .{ .name = "Greeting" },
            .{ .name = "TakeOrder" },
            .{ .name = "Payment" },
            .{ .name = "PrepareDrink" },
            .{ .name = "Complete" },
        },
        .events = &.{
            .{ .name = "CustomerArrived" },
            .{ .name = "OrderPlaced" },
            .{ .name = "PaymentApproved" },
            .{ .name = "DrinkReady" },
        },
        .transitions = &.{
            .{ .from = "Greeting", .to = "TakeOrder", .on = "CustomerArrived" },
            .{ .from = "TakeOrder", .to = "Payment", .on = "OrderPlaced" },
            .{ .from = "Payment", .to = "PrepareDrink", .on = "PaymentApproved" },
            .{ .from = "PrepareDrink", .to = "Complete", .on = "DrinkReady" },
        },
    };
}
