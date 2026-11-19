// ==============================================================================
// 👑 LIPI BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.lp)
// ⚡ Pure Native Silicon ALU & CPU Hardware Performance
// ==============================================================================

fn bench_loop n
    total = 0
    i = 1
    while i <= n
        total = total + (i % 7)
        i = i + 1
    return total

say "Lipi 10,000,000 Loop Benchmark Result:"
say bench_loop 10000000
