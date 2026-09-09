// ==============================================================================
// ⚡ ZIG BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.zig)
// ==============================================================================

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const start = std.time.nanoTimestamp();

    var total: u64 = 0;
    var i: u64 = 1;
    while (i <= 10_000_000) : (i += 1) {
        total += (i % 7);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = end - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

    try stdout.print("Zig Loop 10,000,000 Iterations Complete!\n", .{});
    try stdout.print("Sum: {d}\n", .{total});
    try stdout.print("Elapsed Time: {d:.2} ms\n", .{elapsed_ms});
}
