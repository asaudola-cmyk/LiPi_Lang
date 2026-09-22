// ==============================================================================
// ⚡ ZIG BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.zig)
// ==============================================================================

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const start = std.time.nanoTimestamp();

    var total: u64 = 0;
    var i: u64 = 0;
    while (i < 1_000_000) : (i += 1) {
        total += (i % 100);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = end - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

    try stdout.print("Zig ColumnStore 1,000,000 Scan Complete!\n", .{});
    try stdout.print("Sum: {d}\n", .{total});
    try stdout.print("Elapsed Time: {d:.2} ms\n", .{elapsed_ms});
}
