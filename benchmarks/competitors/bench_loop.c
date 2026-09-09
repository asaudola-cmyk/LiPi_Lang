// ==============================================================================
// 🇨 C BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.c)
// ==============================================================================

#include <stdio.h>
#include <stdint.h>
#include <time.h>

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    uint64_t total = 0;
    for (uint64_t i = 1; i <= 10000000ULL; i++) {
        total += (i % 7);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double elapsed_ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("C Loop 10,000,000 Iterations Complete!\n");
    printf("Sum: %llu\n", (unsigned long long)total);
    printf("Elapsed Time: %.2f ms\n", elapsed_ms);
    return 0;
}
