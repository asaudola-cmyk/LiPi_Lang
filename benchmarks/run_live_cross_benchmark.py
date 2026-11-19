#!/usr/bin/env python3
# ==============================================================================
# 👑 LIPI GRAND CROSS-LANGUAGE EMPIRICAL BENCHMARK ENGINE
# ⚡ Measures Lipi vs Clang, GCC, G++, Rust, Bun, Node.js, and Python on Live Silicon
# ==============================================================================

import subprocess
import time
import os
import re
import json

BASE_DIR = "/home/shafiullah/Documents/file/work/lipi"
COMP_DIR = f"{BASE_DIR}/benchmarks/competitors"

# Ensure PATH includes rust, node, bun
os.environ["PATH"] = f"/home/shafiullah/.cargo/bin:/home/shafiullah/.local/bin:/home/shafiullah/.bun/bin:{os.environ.get('PATH', '')}"

def run_cmd(cmd):
    # Run command with /usr/bin/time -v to capture peak RSS and wall clock
    time_cmd = ["/usr/bin/time", "-v"] + cmd
    res = subprocess.run(time_cmd, cwd=BASE_DIR, capture_output=True, text=True)
    return res

def parse_metrics(output, stderr):
    # Parse Elapsed Time from program output
    # e.g., Elapsed Time: 7.24 ms
    m_time = re.search(r"Elapsed Time:\s*([0-9.]+)\s*ms", output)
    elapsed_ms = float(m_time.group(1)) if m_time else None

    # Parse CPU Cycles
    m_cyc = re.search(r"CPU Cycles:\s*([0-9]+)", output)
    cycles = int(m_cyc.group(1)) if m_cyc else None

    # Parse Checksum
    m_sum = re.search(r"Sum:\s*([0-9]+)", output)
    checksum = int(m_sum.group(1)) if m_sum else None

    # Parse Peak RSS (kbytes) from /usr/bin/time output in stderr
    m_rss = re.search(r"Maximum resident set size \(kbytes\):\s*([0-9]+)", stderr)
    rss_kb = int(m_rss.group(1)) if m_rss else None

    # Parse wall time from time -v if internal time is missing
    if elapsed_ms is None:
        m_wall = re.search(r"Elapsed \(wall clock\) time \(h:mm:ss or m:ss\):\s*([0-9:.]+)", stderr)
        if m_wall:
            parts = m_wall.group(1).split(":")
            if len(parts) == 2:
                elapsed_ms = (float(parts[0]) * 60 + float(parts[1])) * 1000.0

    return elapsed_ms, cycles, checksum, rss_kb

def get_ldd_count(bin_path):
    if not bin_path or not os.path.exists(bin_path):
        return "N/A"
    res = subprocess.run(["ldd", bin_path], capture_output=True, text=True)
    if "not a dynamic executable" in res.stderr or "not a dynamic executable" in res.stdout:
        return 0
    lines = [l for l in res.stdout.strip().split("\n") if "=>" in l or "ld-linux" in l]
    return len(lines)

def get_bin_size_kb(bin_path):
    if bin_path and os.path.exists(bin_path):
        return round(os.path.getsize(bin_path) / 1024.0, 1)
    return "N/A"

def benchmark_suite(suite_name, targets, expected_checksum):
    print(f"\n{'='*85}")
    print(f"🚀 {suite_name}")
    print(f"{'='*85}")
    results = []

    for t in targets:
        name = t["name"]
        cmd = t["cmd"]
        bin_path = t.get("bin")
        print(f"▶ Benchmarking {name}...")

        # Warmup
        run_cmd(cmd)

        times = []
        cycles_list = []
        rss_list = []
        verified = False

        for _ in range(5):
            res = run_cmd(cmd)
            ems, cyc, csum, rkb = parse_metrics(res.stdout, res.stderr)
            if ems is not None:
                times.append(ems)
            if cyc is not None:
                cycles_list.append(cyc)
            if rkb is not None:
                rss_list.append(rkb)
            if csum == expected_checksum:
                verified = True

        best_time = min(times) if times else 0.0
        best_cyc = min(cycles_list) if cycles_list else "N/A"
        median_rss = sorted(rss_list)[len(rss_list)//2] if rss_list else 0
        bin_size = get_bin_size_kb(bin_path)
        dyn_libs = get_ldd_count(bin_path) if bin_path else "Runtime VM"

        print(f"  ✔ Best Time: {best_time:.2f} ms | Peak RSS: {median_rss} KB | Binary: {bin_size} KB | Libs: {dyn_libs} | Checksum: {verified}")

        results.append({
            "language": name,
            "best_time_ms": round(best_time, 2),
            "peak_rss_kb": median_rss,
            "cycles": best_cyc,
            "bin_size_kb": bin_size,
            "dyn_libs": dyn_libs,
            "checksum_verified": verified
        })
    return results

def main():
    print("╔═════════════════════════════════════════════════════════════════════════════════════╗")
    print("║  👑 LIPI VS COMPETITORS: GRAND LIVE SILICON BENCHMARK SHOWDOWN                       ║")
    print("║  Hardware: AMD Ryzen Zen 4 Silicon @ ~4.7 GHz | Linux x86_64 Ubuntu 24.04           ║")
    print("╚═════════════════════════════════════════════════════════════════════════════════════╝")

    # 1. 10,000,000 Arithmetic Loop
    loop_targets = [
        {"name": "👑 Lipi (O(1) Nanosecond Symbolic)", "cmd": [f"{BASE_DIR}/bin/bench_loop_nanosecond"], "bin": f"{BASE_DIR}/bin/bench_loop_nanosecond"},
        {"name": "👑 Lipi (Canonical for-loop)", "cmd": [f"{BASE_DIR}/bin/bench_loop_for"], "bin": f"{BASE_DIR}/bin/bench_loop_for"},
        {"name": "👑 Lipi (Canonical while-loop)", "cmd": [f"{BASE_DIR}/bin/bench_loop_canonical"], "bin": f"{BASE_DIR}/bin/bench_loop_canonical"},
        {"name": "Zig (0.13.0 ReleaseFast)", "cmd": [f"{COMP_DIR}/bin_loop_zig"], "bin": f"{COMP_DIR}/bin_loop_zig"},
        {"name": "C (Clang 18.1 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_clang"], "bin": f"{COMP_DIR}/bin_loop_clang"},
        {"name": "C (GCC 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_gcc"], "bin": f"{COMP_DIR}/bin_loop_gcc"},
        {"name": "C++ (G++ 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_cpp"], "bin": f"{COMP_DIR}/bin_loop_cpp"},
        {"name": "Rust (rustc 1.97 -O3)", "cmd": [f"{COMP_DIR}/bin_loop_rust"], "bin": f"{COMP_DIR}/bin_loop_rust"},
        {"name": "Bun (v1.3.14 JavaScriptCore)", "cmd": ["bun", f"{COMP_DIR}/bench_loop.js"], "bin": None},
        {"name": "Node.js (v24.19 V8 JIT)", "cmd": ["node", f"{COMP_DIR}/bench_loop.js"], "bin": None},
        {"name": "Python 3.12 (CPython)", "cmd": ["python3", f"{COMP_DIR}/bench_loop.py"], "bin": None},
    ]
    res_loop = benchmark_suite("SUITE 1: 10,000,000 Arithmetic Modulo Loop (total += i % 7)", loop_targets, 29999997)

    # 2. 1,000,000 Row ColumnStore Scan
    cs_targets = [
        {"name": "👑 Lipi (AVX2 256-Bit SIMD Vector)", "cmd": [f"{BASE_DIR}/bin/bench_columnstore_avx2"], "bin": f"{BASE_DIR}/bin/bench_columnstore_avx2"},
        {"name": "👑 Lipi (Canonical Pure ELF64)", "cmd": [f"{BASE_DIR}/bin/bench_columnstore_canonical"], "bin": f"{BASE_DIR}/bin/bench_columnstore_canonical"},
        {"name": "Zig (0.13.0 ReleaseFast)", "cmd": [f"{COMP_DIR}/bin_cs_zig"], "bin": f"{COMP_DIR}/bin_cs_zig"},
        {"name": "C (Clang 18.1 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_clang"], "bin": f"{COMP_DIR}/bin_cs_clang"},
        {"name": "C (GCC 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_gcc"], "bin": f"{COMP_DIR}/bin_cs_gcc"},
        {"name": "C++ (G++ 13.3 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_cpp"], "bin": f"{COMP_DIR}/bin_cs_cpp"},
        {"name": "Rust (rustc 1.97 -O3)", "cmd": [f"{COMP_DIR}/bin_cs_rust"], "bin": f"{COMP_DIR}/bin_cs_rust"},
        {"name": "Bun (v1.3.14 JavaScriptCore)", "cmd": ["bun", f"{COMP_DIR}/bench_columnstore.js"], "bin": None},
        {"name": "Node.js (v24.19 V8 JIT)", "cmd": ["node", f"{COMP_DIR}/bench_columnstore.js"], "bin": None},
        {"name": "Python 3.12 (CPython)", "cmd": ["python3", f"{COMP_DIR}/bench_columnstore.py"], "bin": None},
    ]
    res_cs = benchmark_suite("SUITE 2: 1,000,000 Row ColumnStore Analytical Scan (total += i % 100)", cs_targets, 49500000)

    # Save to JSON
    final_output = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "hardware": "AMD Ryzen 5 8400F 6-Core Processor (Zen 4) @ ~4.7 GHz",
        "os": "Linux x86_64 Ubuntu 24.04 LTS",
        "loop_10m": res_loop,
        "columnstore_1m": res_cs
    }
    with open(f"{BASE_DIR}/benchmarks/LIVE_CROSS_LANGUAGE_RESULTS.json", "w") as f:
        json.dump(final_output, f, indent=2)

    print("\n" + "═"*85)
    print("✅ LIVE CROSS-LANGUAGE BENCHMARK COMPLETED AND RECORDED!")
    print("═"*85)

if __name__ == "__main__":
    main()
