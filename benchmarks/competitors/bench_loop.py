#!/usr/bin/env python3
# ==============================================================================
# 🐍 PYTHON BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.py)
# ==============================================================================

import time

start = time.perf_counter()
total = 0
i = 1
while i <= 10000000:
    total += i % 7
    i += 1

elapsed_ms = (time.perf_counter() - start) * 1000.0
print("Python Loop 10,000,000 Iterations Complete!")
print(f"Sum: {total}")
print(f"Elapsed Time: {elapsed_ms:.2f} ms")
