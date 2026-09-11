#!/usr/bin/env python3
# ==============================================================================
# 👑 LIPI SOVEREIGN BENCHMARK HARNESS (scripts/full_benchmark_harness.py)
# ⚡ 100% Empirical Silicon Telemetry | Zero Mock Data | Real System Measurements
# ==============================================================================

import subprocess
import os
import sys
import time
import json
import statistics
import urllib.request
import socket

# Machine Specs
def get_cpu_info():
    model = "AMD Ryzen 5 8400F 6-Core Processor"
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line:
                    model = line.split(":", 1)[1].strip()
                    break
    except Exception:
        pass
    return model

CPU_MODEL = get_cpu_info()
N_RUNS = 5

def run_cmd_metrics(cmd, cwd="."):
    """Runs command wrapped in /usr/bin/time -v to measure peak RSS and precise wall clock."""
    wrapped = ["/usr/bin/time", "-v"] + cmd
    t0 = time.perf_counter_ns()
    proc = subprocess.run(wrapped, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=cwd)
    t1 = time.perf_counter_ns()
    
    wall_ms = (t1 - t0) / 1e6
    stdout = proc.stdout
    stderr = proc.stderr
    
    peak_rss_kb = 0
    for line in stderr.splitlines():
        if "Maximum resident set size (kbytes):" in line:
            try:
                peak_rss_kb = int(line.split(":")[-1].strip())
            except ValueError:
                pass
                
    loop_ms = None
    checksum = None
    cpu_cycles = None
    
    for line in stdout.splitlines():
        l = line.strip()
        lower = l.lower()
        if "elapsed time:" in lower:
            try:
                loop_ms = float(lower.split("elapsed time:")[-1].replace("ms", "").strip())
            except ValueError:
                pass
        elif "sum:" in lower:
            try:
                val = l.split(":")[-1].strip()
                checksum = int(val) if val.isdigit() else val
            except ValueError:
                pass
        elif "cpu cycles:" in lower:
            try:
                cpu_cycles = int(l.split(":")[-1].strip())
            except ValueError:
                pass
        # Fallback for Lipi direct output
        elif checksum is None and l.isdigit():
            checksum = int(l)

    if loop_ms is None:
        loop_ms = wall_ms

    return {
        "wall_ms": wall_ms,
        "loop_ms": loop_ms,
        "peak_rss_kb": peak_rss_kb,
        "checksum": checksum,
        "cpu_cycles": cpu_cycles,
        "exit_code": proc.returncode
    }

def benchmark_category(title, targets):
    print(f"\n================================================================================")
    print(f"  👑 {title}")
    print(f"================================================================================")
    rows = []
    
    for label, cmd, bin_file in targets:
        print(f"► Running {label:<36} ... ", end="", flush=True)
        bin_size_kb = (os.path.getsize(bin_file) / 1024.0) if bin_file and os.path.exists(bin_file) else 0.0
        
        runs = []
        for i in range(N_RUNS):
            res = run_cmd_metrics(cmd)
            runs.append(res)
            time.sleep(0.02)
            
        loop_times = [r["loop_ms"] for r in runs]
        wall_times = [r["wall_ms"] for r in runs]
        rss_mems = [r["peak_rss_kb"] for r in runs]
        
        med_loop = statistics.median(loop_times)
        min_loop = min(loop_times)
        med_wall = statistics.median(wall_times)
        peak_rss = max(rss_mems)
        checksum = runs[0]["checksum"]
        cpu_cycles = runs[0]["cpu_cycles"]
        
        print(f"Done! Loop: {med_loop:6.2f} ms | Wall: {med_wall:6.2f} ms | RSS: {peak_rss:6} KB | Sum: {checksum}")
        
        rows.append({
            "label": label,
            "med_loop_ms": med_loop,
            "min_loop_ms": min_loop,
            "med_wall_ms": med_wall,
            "peak_rss_kb": peak_rss,
            "bin_size_kb": bin_size_kb,
            "checksum": checksum,
            "cpu_cycles": cpu_cycles
        })
        
    return rows

def benchmark_web_engine():
    print(f"\n================================================================================")
    print(f"  👑 BENCHMARK 3: LIPI SOVEREIGN WEB ENGINE (apps/website/server.lp)")
    print(f"================================================================================")
    
    port = 8999
    server_bin = "dist/server/server"
    if not os.path.exists(server_bin):
        print("Compiling server...")
        subprocess.run(["./bin/lipc", "apps/website/server.lp", "-o", server_bin], check=True)
        
    server_size_kb = os.path.getsize(server_bin) / 1024.0
    
    # Start server
    proc = subprocess.Popen([f"./{server_bin}", str(port)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(1)
    
    # Get server PID
    pid = proc.pid
    
    def get_proc_rss_kb(p):
        try:
            with open(f"/proc/{p}/statm") as f:
                parts = f.read().split()
                resident_pages = int(parts[1])
                return resident_pages * 4  # 4KB per page
        except Exception:
            return 0

    initial_rss = get_proc_rss_kb(pid)
    print(f"  • Server Online on Port {port} (PID {pid})")
    print(f"  • Standalone Server Binary Size: {server_size_kb:.2f} KB (100% Statically Linked ELF64)")
    print(f"  • Initial RSS Memory: {initial_rss} KB")
    
    endpoints = [
        ("/api/status", "JSON Telemetry API", 500),
        ("/api/db/items", "Binary Database Scan", 300),
        ("/", "Static HTML Asset", 200)
    ]
    
    all_latencies_ms = []
    endpoint_stats = {}
    
    for ep, desc, count in endpoints:
        print(f"  ► Benchmarking {desc} ({ep}) with {count} requests ... ", end="", flush=True)
        url = f"http://127.0.0.1:{port}{ep}"
        latencies = []
        
        # Warmup 10
        for _ in range(10):
            try:
                urllib.request.urlopen(url, timeout=2).read()
            except Exception:
                pass
                
        t_start = time.perf_counter()
        for _ in range(count):
            req_t0 = time.perf_counter_ns()
            resp = urllib.request.urlopen(url, timeout=2)
            _ = resp.read()
            req_t1 = time.perf_counter_ns()
            lat_ms = (req_t1 - req_t0) / 1e6
            latencies.append(lat_ms)
            all_latencies_ms.append(lat_ms)
        t_end = time.perf_counter()
        
        ep_duration = t_end - t_start
        rps = count / ep_duration
        lat_min = min(latencies)
        lat_med = statistics.median(latencies)
        lat_mean = statistics.mean(latencies)
        lat_p95 = statistics.quantiles(latencies, n=20)[18] if len(latencies) >= 20 else max(latencies)
        lat_max = max(latencies)
        
        print(f"Done! Median: {lat_med:.3f} ms | P95: {lat_p95:.3f} ms | {rps:.0f} req/s")
        endpoint_stats[ep] = {
            "desc": desc,
            "requests": count,
            "duration_s": ep_duration,
            "rps": rps,
            "min_ms": lat_min,
            "median_ms": lat_med,
            "mean_ms": lat_mean,
            "p95_ms": lat_p95,
            "max_ms": lat_max
        }
        
    post_rss = get_proc_rss_kb(pid)
    print(f"  • Post-Load RSS Memory: {post_rss} KB")
    
    # Terminate server
    proc.terminate()
    proc.wait()
    
    tot_requests = len(all_latencies_ms)
    tot_med = statistics.median(all_latencies_ms)
    tot_mean = statistics.mean(all_latencies_ms)
    tot_p95 = statistics.quantiles(all_latencies_ms, n=20)[18]
    tot_max = max(all_latencies_ms)
    
    return {
        "server_size_kb": server_size_kb,
        "initial_rss_kb": initial_rss,
        "post_rss_kb": post_rss,
        "total_requests": tot_requests,
        "overall_median_ms": tot_med,
        "overall_mean_ms": tot_mean,
        "overall_p95_ms": tot_p95,
        "overall_max_ms": tot_max,
        "endpoint_stats": endpoint_stats
    }

def main():
    print(f"👑 LIPI SOVEREIGN EMPIRICAL BENCHMARK SUITE")
    print(f"Host Processor: {CPU_MODEL}")
    print(f"OS: Linux x86_64 | Python: 3.12 | Rust: 1.97 | Zig: 0.13 | Go: 1.22 | Node: 24.19 | Bun: 1.3")
    
    # 1. 10M Loop Modulo
    loop_targets = [
        ("Zig 0.13.0 (ReleaseFast)", ["./dist/bench/bench_loop_zig"], "dist/bench/bench_loop_zig"),
        ("C (GCC -O3)", ["./dist/bench/bench_loop_c"], "dist/bench/bench_loop_c"),
        ("C++ (G++ -O3)", ["./dist/bench/bench_loop_cpp"], "dist/bench/bench_loop_cpp"),
        ("Rust 1.97 (rustc -O)", ["./dist/bench/bench_loop_rust"], "dist/bench/bench_loop_rust"),
        ("Go 1.22.5 (go build -s -w)", ["./dist/bench/bench_loop_go"], "dist/bench/bench_loop_go"),
        ("Node.js 24.19 (V8 JIT)", ["node", "benchmarks/competitors/bench_loop.js"], None),
        ("Bun 1.3 (JavaScriptCore)", ["bun", "benchmarks/competitors/bench_loop.ts"], None),
        ("Lipi (Native Silicon - Pure ALU)", ["./dist/bench/bench_loop_pure"], "dist/bench/bench_loop_pure"),
        ("Lipi (bench_loop.lp standard)", ["./dist/bench/bench_loop"], "dist/bench/bench_loop"),
        ("Python 3.12 (CPython)", ["python3", "benchmarks/competitors/bench_loop.py"], None),
    ]
    loop_results = benchmark_category("BENCHMARK 1: 10,000,000 ARITHMETIC MODULO LOOP (`total += i % 7`)", loop_targets)
    
    # 2. 1M ColumnStore Scan
    col_targets = [
        ("Zig 0.13.0 (ReleaseFast)", ["./dist/bench/bench_col_zig"], "dist/bench/bench_col_zig"),
        ("C (GCC -O3)", ["./dist/bench/bench_col_c"], "dist/bench/bench_col_c"),
        ("C++ (G++ -O3)", ["./dist/bench/bench_col_cpp"], "dist/bench/bench_col_cpp"),
        ("Rust 1.97 (rustc -O)", ["./dist/bench/bench_col_rust"], "dist/bench/bench_col_rust"),
        ("Go 1.22.5 (go build -s -w)", ["./dist/bench/bench_col_go"], "dist/bench/bench_col_go"),
        ("Node.js 24.19 (V8 JIT)", ["node", "benchmarks/competitors/bench_columnstore.js"], None),
        ("Bun 1.3 (JavaScriptCore)", ["bun", "benchmarks/competitors/bench_columnstore.ts"], None),
        ("Lipi (Native Silicon ELF)", ["./dist/bench/bench_col_lipi"], "dist/bench/bench_col_lipi"),
        ("Python 3.12 (CPython)", ["python3", "benchmarks/competitors/bench_columnstore.py"], None),
    ]
    col_results = benchmark_category("BENCHMARK 2: 1,000,000 ROW COLUMNSTORE SCAN (`total += i % 100`)", col_targets)
    
    # 3. Web Engine
    web_results = benchmark_web_engine()
    
    # Save full empirical dataset
    output_data = {
        "cpu_model": CPU_MODEL,
        "loop_benchmark_10m": loop_results,
        "columnstore_benchmark_1m": col_results,
        "web_engine_benchmark": web_results
    }
    
    with open("benchmarks/EMPIRICAL_BENCHMARK_DATA.json", "w") as f:
        json.dump(output_data, f, indent=2)
        
    print("\n✔ Empirical benchmarks completed! Data stored in benchmarks/EMPIRICAL_BENCHMARK_DATA.json")

if __name__ == "__main__":
    main()
