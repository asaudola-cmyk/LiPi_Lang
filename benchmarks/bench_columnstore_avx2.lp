// ==============================================================================
// 👑 LIPI AVX2 256-BIT SIMD COLUMNSTORE BENCHMARK: 1,000,000 ROWS
// ⚡ Parallel YMM Vector Execution | 4x 64-bit Elements Per CPU Cycle
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

fn malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

n = 1000000
buf = malloc(n * 8)

i = 0
while i < n
    sys_poke(buf + (i * 8), i % 100)
    i = i + 1

start_c = cpu_clock()
total = simd_avx2_sum(buf, n)
end_c = cpu_clock()

say "Lipi AVX2 256-Bit SIMD 1,000,000 Scan Complete!"
say "Sum: " + str(total)
say "CPU Cycles: " + str(end_c - start_c)

free(buf, n * 8)
