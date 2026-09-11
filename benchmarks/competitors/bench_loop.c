// ==============================================================================
// 🇨 C BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/competitors/bench_loop.c)
// ⚡ Direct Hardware Silicon Performance | GCC -O3
// ==============================================================================

#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <x86intrin.h>

int main(void) {
    // WHY: Read hardware RDTSC cycle counter and POSIX monotonic clock before loop
    uint64_t start_cycles = __rdtsc();
    struct timespec ts_start, ts_end;
    clock_gettime(CLOCK_MONOTONIC, &ts_start);

    uint64_t total = 0;
    for (uint64_t i = 1; i <= 10000000ULL; ++i) {
        total += (i % 7);
    }

    clock_gettime(CLOCK_MONOTONIC, &ts_end);
    uint64_t end_cycles = __rdtsc();

    double elapsed_ms = (ts_end.tv_sec - ts_start.tv_sec) * 1000.0 +
                        (ts_end.tv_nsec - ts_start.tv_nsec) / 1000000.0;
    uint64_t delta_cycles = end_cycles - start_cycles;

    printf("C Loop 10,000,000 Iterations Complete!\n");
    printf("Sum: %llu\n", (unsigned long long)total);
    printf("Elapsed Time: %.2f ms\n", elapsed_ms);
    printf("CPU Cycles: %llu\n", (unsigned long long)delta_cycles);

    return 0;
}
