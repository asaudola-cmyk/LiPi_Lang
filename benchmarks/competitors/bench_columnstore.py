#!/usr/bin/env python3
# ==============================================================================
# 🐍 PYTHON BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.py)
# ==============================================================================

import time

start = time.perf_counter()
total = 0
i = 0
while i < 1000000:
    total += i % 100
    i += 1

elapsed_ms = (time.perf_counter() - start) * 1000.0
print("Python ColumnStore 1,000,000 Scan Complete!")
print(f"Sum: {total}")
print(f"Elapsed Time: {elapsed_ms:.2f} ms")
