const std = @import("std");
const Mutex = std.Thread.Mutex;
const List = std.DoublyLinkedList;
const Allocator = std.mem.Allocator;

pub fn Channel(comptime T: type) type {
    return struct {
        const Self = @This();
        mutex: Mutex,
        data: *List(T),
        allocator: Allocator,
        pub fn init(allocator: Allocator) !Self {
            const list = try allocator.create(List(T));
            list.* = List(T){};
            return Self{
                .mutex = .{},
                .data = list,
                .allocator = allocator,
            };
        }
        pub fn get(self: *Self) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            const node = self.data.popFirst() orelse return null;
            defer self.allocator.destroy(node);
            return node.data;
        }
        pub fn set(self: *Self, val: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const newNode = try self.allocator.create(List(T).Node);
            newNode.* = List(T).Node{ .data = val };
            self.data.append(newNode);
        }
        pub fn deinit(self: *Self) void {
            var node = self.data.pop();
            while (node != null) : (node = self.data.pop()) {
                self.allocator.destroy(node);
            }
            self.allocator.destroy(self.data);
        }
    };
}
