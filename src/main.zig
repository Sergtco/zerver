const std = @import("std");
const http = @import("server.zig");
const handlers = @import("handlers.zig");
const Handler = @import("server.zig").Handler;
const Check = std.heap.Check;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaks = gpa.deinit();
        if (leaks == Check.leak) {
            std.log.warn("Leak appeared", .{});
        }
    }
    var paths = [_]Handler{Handler{ .path = "/", .handler_func = handlers.index }};
    var server = try http.Server.init(allocator, [4]u8{ 127, 0, 0, 1 }, 6969, &paths);
    try server.serve();
}
