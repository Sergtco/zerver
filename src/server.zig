const std = @import("std");
const http = std.http;
const net = std.net;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub const ConnectionErr = error{UnregisteredPath};

pub const HandlerFunc = fn (*http.Server.Request) void;
pub const Handler = struct { path: []const u8, handler_func: *const HandlerFunc };

pub const Server = struct {
    addr: net.Address,
    config: ServerConfig = undefined,
    router: Router,
    alloc: Allocator,
    pool: Thread.Pool,
    pub fn init(allocator: Allocator, address: [4]u8, port: u16, paths: []Handler) !Server {
        var pool: Thread.Pool = undefined;
        try pool.init(.{ .allocator = allocator });
        return Server{ .addr = net.Address.initIp4(address, port), .alloc = allocator, .router = try Router.init(paths), .pool = pool };
    }

    pub fn serve(self: *Server) !void {
        var listener = try self.addr.listen(.{ .reuse_address = true });
        defer listener.deinit();
        while (true) {
            const conn = try listener.accept();
            self.router.handle(conn) catch |err| std.log.debug("some err{}", .{err});
        }
    }
};

pub const ServerConfig = struct {};

pub const Router = struct {
    paths: []Handler,
    pub fn init(paths: []Handler) !Router {
        return Router{ .paths = paths };
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
        handler(&request);
        defer request.server.connection.stream.close();
    }
};

pub fn worker(handler: *const HandlerFunc, request: *http.Server.Request) void {
    handler(request);
}
