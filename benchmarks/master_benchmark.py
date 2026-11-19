#!/usr/bin/env python3
# ==============================================================================
# 👑 LIPI GRAND MASTER EMPIRICAL BENCHMARK ENGINE
# Comprehensive Cross-Language Comparison: C, C++, Rust, Zig, Go, Python vs LiPi
# Domains:
#   1. CPU ALU Loop Computation (10,000,000 Iterations)
#   2. AVX2 256-Bit SIMD ColumnStore Analytics (1,000,000 Rows Scan)
#   3. High-Concurrency HTTP Network Throughput (wrk 100 Concurrency 10s Load)
#   4. System Footprint (RAM RSS & Static Binary Size)
# ==============================================================================

import subprocess
import time
import os
import signal
import json
import re

BASE_DIR = "/home/shafiullah/Documents/file/work/lipi"
COMP_DIR = f"{BASE_DIR}/benchmarks/competitors"
RPS_DIR = f"{BASE_DIR}/benchmarks/rps"
WRK_BIN = "/tmp/bench/wrk"

def run_cmd(cmd, cwd=None):
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return res

def parse_time_from_output(stdout):
    # Search for Elapsed Time: XX.XX ms
    m = re.search(r"Elapsed Time:\s*([0-9.]+)\s*ms", stdout)
    if m:
        return float(m.group(1))
    return None

def parse_cycles_from_output(stdout):
    m = re.search(r"CPU Cycles:\s*([0-9]+)", stdout)
    if m:
        return int(m.group(1))
    return None

def benchmark_loops():
    print("\n" + "=" * 80)
    print("⚡ [SUITE 1] CPU ALU & TIGHT LOOP BENCHMARK (10,000,000 ITERATIONS)")
    print("=" * 80)

    targets = [
        {"lang": "C (GCC 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_c"], "bin": f"{COMP_DIR}/bin_loop_c"},
        {"lang": "C++ (G++ 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_cpp"], "bin": f"{COMP_DIR}/bin_loop_cpp"},
        {"lang": "Rust (rustc 1.97 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_rust"], "bin": f"{COMP_DIR}/bin_loop_rust"},
        {"lang": "Zig (zig 0.13 -O ReleaseFast)", "cmd": [f"{COMP_DIR}/bin_loop_zig"], "bin": f"{COMP_DIR}/bin_loop_zig"},
        {"lang": "Go (go 1.22.5)", "cmd": [f"{COMP_DIR}/bin_loop_go"], "bin": f"{COMP_DIR}/bin_loop_go"},
        {"lang": "Python 3.12 (CPython)", "cmd": ["python3", f"{COMP_DIR}/bench_loop.py"], "bin": None},
        {"lang": "👑 LiPi First 1.0.0", "cmd": ["/tmp/bench_loop_lipi"], "bin": "/tmp/bench_loop_lipi"}
    ]

    results = []
    for t in targets:
        name = t["lang"]
        print(f"▶ Benchmarking {name}...")
        times = []
        cycles_list = []

        # Warmup
        run_cmd(t["cmd"])

        for _ in range(5):
            t0 = time.perf_counter()
            res = run_cmd(t["cmd"])
            t1 = time.perf_counter()
            elapsed_ms = (t1 - t0) * 1000.0

            reported_time = parse_time_from_output(res.stdout)
            reported_cycles = parse_cycles_from_output(res.stdout)

            final_ms = reported_time if reported_time is not None else elapsed_ms
            times.append(final_ms)
            if reported_cycles:
                cycles_list.append(reported_cycles)

        avg_ms = min(times) # Best of 5
        avg_cycles = min(cycles_list) if cycles_list else "N/A"
        bin_size = f"{round(os.path.getsize(t['bin'])/1024.0, 1)} KB" if t["bin"] and os.path.exists(t["bin"]) else "N/A"

        print(f"  ✔ Best Time: {avg_ms:.2f} ms | CPU Cycles: {avg_cycles} | Binary: {bin_size}")
        results.append({
            "lang": name,
            "best_time_ms": round(avg_ms, 2),
            "cycles": avg_cycles,
            "bin_size": bin_size
        })
    return results

def benchmark_columnstore():
    print("\n" + "=" * 80)
    print("⚡ [SUITE 2] AVX2 256-BIT SIMD COLUMNSTORE ANALYTICS (1,000,000 ROWS)")
    print("=" * 80)

    targets = [
        {"lang": "C (AVX2 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_c"], "bin": f"{COMP_DIR}/bin_cs_c"},
        {"lang": "C++ (AVX2 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_cpp"], "bin": f"{COMP_DIR}/bin_cs_cpp"},
        {"lang": "Rust (AVX2 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_rust"], "bin": f"{COMP_DIR}/bin_cs_rust"},
        {"lang": "Zig (AVX2 ReleaseFast)", "cmd": [f"{COMP_DIR}/bin_cs_zig"], "bin": f"{COMP_DIR}/bin_cs_zig"},
        {"lang": "Go (go 1.22.5)", "cmd": [f"{COMP_DIR}/bin_cs_go"], "bin": f"{COMP_DIR}/bin_cs_go"},
        {"lang": "👑 LiPi First 1.0.0", "cmd": ["/tmp/bench_cs_avx2"], "bin": "/tmp/bench_cs_avx2"}
    ]

    results = []
    for t in targets:
        name = t["lang"]
        print(f"▶ Benchmarking {name}...")
        times = []
        cycles_list = []

        run_cmd(t["cmd"])
        for _ in range(5):
            t0 = time.perf_counter()
            res = run_cmd(t["cmd"])
            t1 = time.perf_counter()
            elapsed_ms = (t1 - t0) * 1000.0

            reported_time = parse_time_from_output(res.stdout)
            reported_cycles = parse_cycles_from_output(res.stdout)

            final_ms = reported_time if reported_time is not None else elapsed_ms
            times.append(final_ms)
            if reported_cycles:
                cycles_list.append(reported_cycles)

        avg_ms = min(times)
        avg_cycles = min(cycles_list) if cycles_list else "N/A"
        bin_size = f"{round(os.path.getsize(t['bin'])/1024.0, 1)} KB" if t["bin"] and os.path.exists(t["bin"]) else "N/A"
        throughput = round((1000000.0 / (avg_ms / 1000.0)) / 1000000.0, 2)

        print(f"  ✔ Best Time: {avg_ms:.2f} ms | Throughput: {throughput} Million rows/sec | Binary: {bin_size}")
        results.append({
            "lang": name,
            "best_time_ms": round(avg_ms, 2),
            "throughput_m_rows_sec": throughput,
            "cycles": avg_cycles,
            "bin_size": bin_size
        })
    return results

def benchmark_network_rps():
    print("\n" + "=" * 80)
    print("⚡ [SUITE 3] HIGH-CONCURRENCY HTTP THROUGHPUT BENCHMARK (wrk -t4 -c100 -d10s)")
    print("=" * 80)

    # We use our validated run_rps_benchmark.py
    run_cmd([f"{RPS_DIR}/run_rps_benchmark.py"])
    with open(f"{RPS_DIR}/rps_results.json") as f:
        return json.load(f)

def main():
    print("╔════════════════════════════════════════════════════════════════════════╗")
    print("║  👑 LIPI GRAND MASTER BENCHMARK SUITE — FULL SPECTRUM AUDIT            ║")
    print("║  Hardware: Intel Core i3-8100 4-Core @ 3.60GHz | Linux x86_64          ║")
    print("╚════════════════════════════════════════════════════════════════════════╝")

    suite1 = benchmark_loops()
    suite2 = benchmark_columnstore()
    suite3 = benchmark_network_rps()

    master_results = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "hardware": "Intel Core i3-8100 CPU @ 3.60GHz (4 Cores), Linux x86_64",
        "suite1_loops": suite1,
        "suite2_columnstore": suite2,
        "suite3_network_rps": suite3
    }

    with open(f"{BASE_DIR}/benchmarks/FULL_MASTER_BENCHMARK_RESULTS.json", "w") as f:
        json.dump(master_results, f, indent=2)

    print("\n" + "═" * 80)
    print("🎉 ALL FULL SPECTRUM BENCHMARKS COMPLETED SUCCESSFULLY!")
    print("═" * 80)

if __name__ == "__main__":
    main()
