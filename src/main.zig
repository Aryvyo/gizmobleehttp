const std = @import("std");
const gizmobleehttp = @import("gizmobleehttp");
const posix = std.posix;

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const coreCount = try std.Thread.getCpuCount();

    const threads = try gpa.alloc(std.Thread, coreCount);
    defer gpa.free(threads);

    std.debug.print("spawning {d} threads\n", .{coreCount});

    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, workerFn, .{});
    }

    for (threads) |*thread| {
        thread.*.join();
    }
}

fn workerFn() !void {
    std.debug.print("spawning thread\n", .{});
    const f = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, posix.IPPROTO.TCP);
    defer posix.close(f);

    var cone: c_int = 1;
    try posix.setsockopt(f, posix.SOL.SOCKET, posix.SO.REUSEADDR, @as([*]const u8, @ptrCast(&cone))[0..@sizeOf(c_int)]);
    try posix.setsockopt(f, posix.SOL.SOCKET, posix.SO.REUSEPORT, @as([*]const u8, @ptrCast(&cone))[0..@sizeOf(c_int)]);

    const tcpqueue: c_int = 32;
    _ = posix.setsockopt(f, posix.IPPROTO.TCP, posix.TCP.FASTOPEN, @as([*]const u8, @ptrCast(&tcpqueue))[0..@sizeOf(c_int)]) catch {};
    _ = posix.setsockopt(f, posix.IPPROTO.TCP, 9, @as([*]const u8, @ptrCast(&cone))[0..@sizeOf(c_int)]) catch {};

    var address = try std.net.Address.parseIp4("127.0.0.1", 8080);
    try posix.bind(f, &address.any, address.getOsSockLen());
    try posix.listen(f, 8192);

    const epoll = try posix.epoll_create1(posix.system.EPOLL.CLOEXEC);
    defer posix.close(epoll);

    var listenevent = posix.system.epoll_event{ .events = posix.system.EPOLL.IN | posix.system.EPOLL.ET, .data = .{ .fd = f } };
    try posix.epoll_ctl(epoll, posix.system.EPOLL.CTL_ADD, f, &listenevent);

    const httpheader =
        "HTTP/1.1 200 OK\r\n" ++ "Content-Type: text/html; charset=utf-8\r\n" ++ "Content-Length: 49\r\n" ++ "Connection: close\r\n" ++ "\r\n" ++ "<html><body><h1>CORE CHALLENGE</h1></body></html>";

    while (true) {
        const client = posix.accept(f, null, null, posix.SOCK.CLOEXEC) catch |e| switch (e) {
            else => return e,
        };

        _ = try posix.write(client, httpheader);

        _ = posix.close(client);
    }
}
