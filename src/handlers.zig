const Handler = @import("server.zig").Handler;
const std = @import("std");
const http = std.http;
const net = std.net;
const Allocator = std.mem.Allocator;
const json = std.json;

pub fn index(allocator: Allocator, request: *http.Server.Request) !void {
    const data = try allocator.alloc(u8, 1024 * 8);
    defer allocator.free(data);
    const body = .{
        .fuck = "Zig",
        .im = .{ "tired", "of", "this", "shit" },
    };
    const body_data = try json.stringifyAlloc(allocator, body, .{});
    defer allocator.free(body_data);

    var response = request.respondStreaming(.{ .send_buffer = data, .respond_options = .{ .extra_headers = &.{
        .{ .name = "Content-Type", .value = "application/json" },
    } } });
    defer {
        response.flush() catch |err| std.log.warn("{}", .{err});
    }
    try response.writeAll(body_data);
}
