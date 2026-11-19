// ==============================================================================
// 🇨 C++ BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.cpp)
// ==============================================================================

#include <iostream>
#include <chrono>
#include <cstdint>

int main() {
    auto start = std::chrono::high_resolution_clock::now();

    uint64_t total = 0;
    for (uint64_t i = 1; i <= 10000000ULL; ++i) {
        total += (i % 7);
    }

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed = end - start;

    std::cout << "C++ Loop 10,000,000 Iterations Complete!\n";
    std::cout << "Sum: " << total << "\n";
    std::cout << "Elapsed Time: " << elapsed.count() << " ms\n";
    return 0;
}
