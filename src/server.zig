const std = @import("std");
const http = std.http;
const net = std.net;
const Handlers = @import("handlers.zig");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Chan = @import("channel.zig").Channel(net.Server.Connection);

pub const ConnectionErr = error{UnregisteredPath};

pub const Server = struct {
    addr: net.Address,
    config: ServerConfig = undefined,
    allocator: Allocator,
    pool: [20]Thread = undefined,
    pub fn init(allocator: Allocator, address: [4]u8, port: u16) !Server {
        return Server{ .allocator = allocator, .addr = net.Address.initIp4(address, port) };
    }

    pub fn serve(self: *Server) !void {
        var chan = try Chan.init(self.allocator);
        for (0..20) |i| {
            self.pool[i] = try Thread.spawn(.{ .allocator = self.allocator }, worker, .{ self.allocator, &chan });
            self.pool[i].detach();
        }

        var listener = try self.addr.listen(.{ .reuse_address = true });
        defer listener.deinit();
        while (true) {
            const conn = try listener.accept();
            try chan.set(conn);
        }
    }
};

pub const ServerConfig = struct {};

pub fn worker(allocator: Allocator, chan: *Chan) !void {
    while (true) {
        const conn = chan.get() orelse continue;
        defer conn.stream.close();
        var data: [1024 * 8]u8 = undefined;
        var server = http.Server.init(conn, &data);
        var request = try server.receiveHead();
        try Handlers.index(allocator, &request);
    }
}
