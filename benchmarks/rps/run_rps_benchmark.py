#!/usr/bin/env python3
# ==============================================================================
# 👑 EMPIRICAL MULTI-LANGUAGE RPS BENCHMARK HARNESS
# Targets: C, C++, Rust, Go, Zig vs LiPi Sovereign Engine
# Client: wrk (4 threads, 100 concurrent connections, 10s benchmark duration)
# ==============================================================================

import subprocess
import time
import os
import signal
import json
import re

BENCH_DIR = "/home/shafiullah/Documents/file/work/lipi/benchmarks/rps"
WRK_BIN = "/tmp/bench/wrk"

SERVERS = [
    {
        "name": "C (GCC 13.3 -O3)",
        "binary": f"{BENCH_DIR}/bin_c",
        "port": 8001,
        "lang": "C"
    },
    {
        "name": "C++ (G++ 13.3 -O3)",
        "binary": f"{BENCH_DIR}/bin_cpp",
        "port": 8002,
        "lang": "C++"
    },
    {
        "name": "Rust (rustc 1.97 -O3)",
        "binary": f"{BENCH_DIR}/bin_rust",
        "port": 8003,
        "lang": "Rust"
    },
    {
        "name": "Go (go 1.22.5 std net/http)",
        "binary": f"{BENCH_DIR}/bin_go",
        "port": 8004,
        "lang": "Go"
    },
    {
        "name": "Zig (zig 0.13 -O ReleaseFast)",
        "binary": f"{BENCH_DIR}/bin_zig",
        "port": 8005,
        "lang": "Zig"
    },
    {
        "name": "LiPi (First 1.0.0 100% Sovereign)",
        "binary": f"{BENCH_DIR}/bin_lipi",
        "port": 8006,
        "lang": "LiPi"
    }
]

def get_process_memory_rss(pid):
    # Returns RSS memory in KB
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except Exception:
        pass
    return 0

def parse_wrk_output(output):
    rps = 0.0
    latency_avg = "N/A"
    latency_p99 = "N/A"
    transfer = "N/A"

    for line in output.splitlines():
        line = line.strip()
        if "Requests/sec:" in line:
            parts = line.split()
            rps = float(parts[1])
        elif "Transfer/sec:" in line:
            parts = line.split()
            transfer = parts[1]
        elif line.startswith("Latency") and not "Distribution" in line:
            parts = line.split()
            if len(parts) >= 4:
                latency_avg = parts[1]
        elif "99%" in line:
            parts = line.split()
            latency_p99 = parts[1]

    return {
        "rps": rps,
        "latency_avg": latency_avg,
        "latency_p99": latency_p99,
        "transfer_sec": transfer
    }

def run_bench():
    results = []
    print("=" * 80)
    print("🚀 LAUNCHING MULTI-LANGUAGE RPS BENCHMARK (wrk -t4 -c100 -d10s)")
    print("=" * 80)

    for s in SERVERS:
        name = s["name"]
        binary = s["binary"]
        port = s["port"]
        url = f"http://127.0.0.1:{port}/"

        print(f"\n▶ Benchmarking {name} on port {port}...")

        # Binary file size
        bin_size_kb = round(os.path.getsize(binary) / 1024.0, 2)

        # Launch server
        proc = subprocess.Popen([binary], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=os.setsid)
        time.sleep(0.6)

        # Verify server is listening and responding
        curl_check = subprocess.run(["curl", "-s", "-m", "2", url], capture_output=True, text=True)
        if curl_check.returncode != 0 or "Hello, World!" not in curl_check.stdout:
            print(f"❌ Server {name} failed health check! Output: {curl_check.stdout}")
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            continue

        # Measure memory before and during load
        mem_rss_kb = get_process_memory_rss(proc.pid)

        # Run wrk benchmark
        print(f"  ⚡ Running wrk against {url} for 10s with 100 concurrent connections...")
        wrk_cmd = [WRK_BIN, "-t4", "-c100", "-d10s", "--latency", url]
        wrk_res = subprocess.run(wrk_cmd, capture_output=True, text=True)

        # Memory under load
        mem_load_kb = get_process_memory_rss(proc.pid)
        final_mem_kb = max(mem_rss_kb, mem_load_kb)

        # Kill server process group cleanly
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except Exception:
            pass
        time.sleep(0.3)

        parsed = parse_wrk_output(wrk_res.stdout)
        parsed["name"] = name
        parsed["lang"] = s["lang"]
        parsed["binary_size_kb"] = bin_size_kb
        parsed["ram_rss_kb"] = final_mem_kb
        parsed["raw_output"] = wrk_res.stdout

        print(f"  ✔ Requests/Sec: {parsed['rps']:,.2f} req/s")
        print(f"  ✔ Latency (Avg): {parsed['latency_avg']}, p99: {parsed['latency_p99']}")
        print(f"  ✔ RAM Footprint: {final_mem_kb} KB | Binary Size: {bin_size_kb} KB")

        results.append(parsed)

    # Save to JSON
    with open(f"{BENCH_DIR}/rps_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print("\n" + "=" * 80)
    print("🏆 FINAL RPS BENCHMARK SUMMARY")
    print("=" * 80)
    print(f"{'Language':<20} | {'Req/Sec (RPS)':<16} | {'Avg Latency':<12} | {'Binary Size':<14} | {'RAM (RSS)':<10}")
    print("-" * 80)
    # Sort by RPS descending
    for r in sorted(results, key=lambda x: x["rps"], reverse=True):
        print(f"{r['lang']:<20} | {r['rps']:>13,.2f}  | {r['latency_avg']:>10}  | {str(r['binary_size_kb']) + ' KB':>12} | {str(r['ram_rss_kb']) + ' KB':>8}")
    print("=" * 80)

if __name__ == "__main__":
    run_bench()
