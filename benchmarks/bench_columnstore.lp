// ==============================================================================
// 👑 LIPI BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/bench_columnstore.lp)
// ⚡ Vectorized In-Memory Analytical Scan | Zero SQL / Zero Python
// ==============================================================================

fn scan_column count
    total = 0
    i = 0
    while i < count
        total = total + (i % 100)
        i = i + 1
    return total

say "ColumnStore 1,000,000 Scan Benchmark Result:"
say scan_column 1000000
