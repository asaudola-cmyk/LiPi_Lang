#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <x86intrin.h>

static uint64_t fib(uint64_t n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    uint64_t start_cycles = __rdtsc();
    struct timespec ts_start, ts_end;
    clock_gettime(CLOCK_MONOTONIC, &ts_start);

    uint64_t res = fib(35);

    clock_gettime(CLOCK_MONOTONIC, &ts_end);
    uint64_t end_cycles = __rdtsc();

    double elapsed_ms = (ts_end.tv_sec - ts_start.tv_sec) * 1000.0 +
                        (ts_end.tv_nsec - ts_start.tv_nsec) / 1000000.0;
    uint64_t delta_cycles = end_cycles - start_cycles;

    printf("C Fibonacci (35) Complete!\n");
    printf("Sum: %llu\n", (unsigned long long)res);
    printf("Elapsed Time: %.2f ms\n", elapsed_ms);
    printf("CPU Cycles: %llu\n", (unsigned long long)delta_cycles);

    return 0;
}
