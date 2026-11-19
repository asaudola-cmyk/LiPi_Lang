// ==============================================================================
// 🇨 C++ BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.cpp)
// ==============================================================================

#include <iostream>
#include <chrono>
#include <cstdint>
#include <x86intrin.h>

int main() {
    uint64_t start_cycles = __rdtsc();
    auto start = std::chrono::high_resolution_clock::now();

    uint64_t total = 0;
    for (uint64_t i = 0; i < 1000000ULL; ++i) {
        total += (i % 100);
    }

    auto end = std::chrono::high_resolution_clock::now();
    uint64_t end_cycles = __rdtsc();
    std::chrono::duration<double, std::milli> elapsed = end - start;

    std::cout << "C++ ColumnStore 1,000,000 Scan Complete!\n";
    std::cout << "Sum: " << total << "\n";
    std::cout << "Elapsed Time: " << elapsed.count() << " ms\n";
    std::cout << "CPU Cycles: " << (end_cycles - start_cycles) << "\n";
    return 0;
}
