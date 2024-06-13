const std = @import("std");
const http = @import("server.zig");
const handlers = @import("handlers.zig");
const Check = std.heap.Check;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    var tsa = std.heap.ThreadSafeAllocator{ .child_allocator = gpa_alloc };
    const allocator = tsa.allocator();
    defer {
        const leaks = gpa.deinit();
        if (leaks == Check.leak) {
            std.log.warn("Leak appeared", .{});
        }
    }
    var server = try http.Server.init(allocator, [4]u8{ 127, 0, 0, 1 }, 6969);
    try server.serve();
}
