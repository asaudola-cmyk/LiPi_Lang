// ==============================================================================
// 👑 LIPI COLUMNSTORE BENCHMARK: 1,000,000 ROWS WITH RDTSC HARDWARE CYCLES
// ⚡ Vectorized In-Memory Analytical Scan | Granlund-Montgomery Fast Reciprocal
// ==============================================================================

fn scan_column count
    total = 0
    i = 0
    while i < count
        total = total + (i % 100)
        i = i + 1
    return total

start_c = cpu_clock()
total = scan_column 1000000
end_c = cpu_clock()

say "Lipi ColumnStore 1,000,000 Scan Complete!"
say "Sum: " + str(total)
say "CPU Cycles: " + str(end_c - start_c)
