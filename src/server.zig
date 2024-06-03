const std = @import("std");
const http = std.http;
const net = std.net;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub const ConnectionErr = error{UnregisteredPath};

pub const HandlerFunc = fn (Allocator, *http.Server.Request) anyerror!void;
pub const Handler = struct { path: []const u8, handler_func: *const HandlerFunc };

pub const Server = struct {
    addr: net.Address,
    config: ServerConfig = undefined,
    router: Router,
    pub fn init(allocator: Allocator, address: [4]u8, port: u16, paths: []Handler) !Server {
        return Server{ .addr = net.Address.initIp4(address, port), .router = try Router.init(allocator, paths) };
    }

    pub fn serve(self: *Server) !void {
        var listener = try self.addr.listen(.{ .reuse_address = true });
        defer listener.deinit();
        while (true) {
            const conn = try listener.accept();
            defer conn.stream.close();
            self.router.handle(conn) catch |err| switch (err) {
                else => |e| std.log.warn("Error: {}", .{e}),
            };
        }
    }
};

pub const ServerConfig = struct {};

pub const Router = struct {
    paths: []Handler,
    allocator: Allocator,
    pub fn init(allocator: Allocator, paths: []Handler) !Router {
        return Router{ .allocator = allocator, .paths = paths };
    }
    pub fn handle(self: *Router, conn: net.Server.Connection) !void {
        var server_buffer: [1024 * 8]u8 = undefined;
        var server = http.Server.init(conn, &server_buffer);
        var request = try server.receiveHead();
        const handler = for (self.paths) |path| {
            if (std.mem.eql(u8, path.path, request.head.target)) break path.handler_func;
        } else {
            try request.respond("Error 404.", .{ .status = http.Status.not_found });
            return ConnectionErr.UnregisteredPath;
        };
        try handler(self.allocator, &request);
        std.log.info("{} {s}", .{ request.head.method, request.head.target });
    }
};

pub fn worker(allocator: Allocator, handler: *const HandlerFunc, request: http.Server.Request) !void {
    try handler(allocator, request);
}
