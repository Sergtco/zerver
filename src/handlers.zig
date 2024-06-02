const Handler = @import("server.zig").Handler;
const std = @import("std");
const http = std.http;
const net = std.net;

pub fn index(request: *http.Server.Request) void {
    request.respond("Hello world", .{}) catch std.log.info("Err in response", .{});
    return;
}
