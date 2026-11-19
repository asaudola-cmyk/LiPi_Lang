#include <iostream>
#include <chrono>
#include <x86intrin.h>

static uint64_t fib(uint64_t n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    uint64_t start_cycles = __rdtsc();
    auto start = std::chrono::high_resolution_clock::now();

    uint64_t res = fib(35);

    auto end = std::chrono::high_resolution_clock::now();
    uint64_t end_cycles = __rdtsc();

    std::chrono::duration<double, std::milli> elapsed = end - start;
    uint64_t delta_cycles = end_cycles - start_cycles;

    std::cout << "C++ Fibonacci (35) Complete!\n";
    std::cout << "Sum: " << res << "\n";
    std::cout << "Elapsed Time: " << elapsed.count() << " ms\n";
    std::cout << "CPU Cycles: " << delta_cycles << "\n";

    return 0;
}
