// ==============================================================================
// ⚡ ZIG BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS
// ==============================================================================

const std = @import("std");

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const start_c = rdtsc();
    const start = std.time.nanoTimestamp();

    var total: u64 = 0;
    var i: u64 = 1;
    while (i <= 10_000_000) : (i += 1) {
        total += (i % 7);
    }

    const end = std.time.nanoTimestamp();
    const end_c = rdtsc();

    const elapsed_ns = end - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const delta_cycles = end_c - start_c;

    try stdout.print("Zig Loop 10,000,000 Iterations Complete!\n", .{});
    try stdout.print("Sum: {d}\n", .{total});
    try stdout.print("Elapsed Time: {d:.2} ms\n", .{elapsed_ms});
    try stdout.print("CPU Cycles: {d}\n", .{delta_cycles});
}
