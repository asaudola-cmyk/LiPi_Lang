// ==============================================================================
// 👑 LIPI HARDWARE REGISTER LOOP BENCHMARK: 10,000,000 ITERATIONS
// ⚡ Direct Callee-Saved AMD64 Silicon Register Execution (%r12, %r13)
// ==============================================================================

fn bench_loop_reg n
    reg total = 0
    reg i = 1
    while i <= n
        total += (i % 7)
        i += 1
    return total

start_c = cpu_clock()
total = bench_loop_reg 10000000
end_c = cpu_clock()

say "Lipi Register-Allocated 10,000,000 Loop Complete!"
say "Sum: " + str(total)
say "CPU Cycles: " + str(end_c - start_c)
