// ==============================================================================
// 👑 ZIG HIGH-THROUGHPUT HTTP BENCHMARK SERVER
// Architecture: std.net.Address + std.Thread Worker Pool + Keep-Alive HTTP/1.1
// ==============================================================================

const std = @import("std");

const port: u16 = 8005;
const num_workers: usize = 4;
const http_resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\nConnection: keep-alive\r\n\r\nHello, World!";

// WHY: Multi-threaded worker loop in Zig. Accepts connections and handles keep-alive requests.
fn workerLoop(server: *std.net.Server) void {
    var buf: [2048]u8 = undefined;
    while (true) {
        var conn = server.accept() catch continue;
        defer conn.stream.close();

        while (true) {
            const n = conn.stream.read(&buf) catch break;
            if (n == 0) break;
            conn.stream.writeAll(http_resp) catch break;
        }
    }
}

pub fn main() !void {
    const address = try std.net.Address.parseIp4("0.0.0.0", port);
    var server = try address.listen(.{ .reuse_address = true, .reuse_port = true });
    defer server.deinit();

    std.debug.print("[Zig] Server listening on 0.0.0.0:{} with {} worker threads\n", .{ port, num_workers });

    var threads: [num_workers]std.Thread = undefined;
    for (0..num_workers) |i| {
        threads[i] = try std.Thread.spawn(.{}, workerLoop, .{&server});
    }

    for (threads) |t| {
        t.join();
    }
}
