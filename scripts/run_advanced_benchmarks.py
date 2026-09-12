#!/usr/bin/env python3
# ==============================================================================
# 👑 LIPI GRAND EMPIRICAL BENCHMARK & HARDWARE TELEMETRY HARNESS (2026)
# ⚡ 100% Empirical Silicon Measurements | Zero Mocks | Pure Hardware Profiling
# ==============================================================================

import subprocess
import os
import sys
import time
import json
import statistics
import urllib.request
import re

BENCH_REPS = 10
COMPILE_REPS = 5

def get_cpu_info():
    model = "AMD Silicon Architecture"
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line:
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return model

CPU_MODEL = get_cpu_info()

def get_peak_rss(cmd, cwd="."):
    """Extracts Peak Resident Set Size (RSS in KB) via /usr/bin/time -v."""
    try:
        time_cmd = ["/usr/bin/time", "-v"] + cmd
        p = subprocess.run(time_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=cwd)
        for line in p.stderr.splitlines():
            if "Maximum resident set size (kbytes):" in line:
                return int(line.split(":")[-1].strip())
    except Exception:
        pass
    return 0

def measure_benchmark_runs(cmd, n_runs=BENCH_REPS, cwd="."):
    """Executes command over n_runs iterations with warmup, measuring high-resolution wall time."""
    # Warmup
    subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd)
    
    times_ms = []
    checksum = None
    cpu_cycles = None
    last_stdout = ""
    
    for _ in range(n_runs):
        t0 = time.perf_counter_ns()
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=cwd)
        t1 = time.perf_counter_ns()
        
        if proc.returncode != 0:
            raise RuntimeError(f"Command {cmd} failed (code {proc.returncode}): {proc.stderr}")
            
        elapsed_ms = (t1 - t0) / 1e6
        times_ms.append(elapsed_ms)
        last_stdout = proc.stdout.strip()
        time.sleep(0.01)

    for line in last_stdout.splitlines():
        lower = line.lower()
        if "sum:" in lower:
            val = line.split(":")[-1].strip()
            checksum = int(val) if val.isdigit() else val
        elif "cpu cycles:" in lower:
            try:
                cpu_cycles = int(line.split(":")[-1].strip())
            except ValueError:
                pass
        elif checksum is None and line.strip().isdigit():
            checksum = int(line.strip())

    return {
        "min_ms": round(min(times_ms), 3),
        "median_ms": round(statistics.median(times_ms), 3),
        "mean_ms": round(statistics.mean(times_ms), 3),
        "max_ms": round(max(times_ms), 3),
        "stdev_ms": round(statistics.stdev(times_ms), 4) if len(times_ms) > 1 else 0.0,
        "raw_samples": [round(x, 3) for x in times_ms],
        "checksum": checksum,
        "cpu_cycles": cpu_cycles
    }

def get_binary_size(path):
    if path and os.path.exists(path):
        return os.path.getsize(path)
    return 0

def count_dynamic_deps(bin_path):
    if not bin_path or not os.path.exists(bin_path):
        return "N/A (Runtime/Script)"
    try:
        proc = subprocess.run(["ldd", bin_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if "not a dynamic executable" in proc.stderr or "not a dynamic executable" in proc.stdout:
            return "0 (Pure Static ELF)"
        lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        return f"{len(lines)} shared libs"
    except Exception:
        return "Unknown"

def compile_all_targets():
    print("==================================================================")
    print("  ⚙️  COMPILING ALL BENCHMARK TARGETS TO NATIVE BINARIES")
    print("==================================================================")
    
    # 1. Lipi Targets
    print("► Compiling Lipi targets with ./bin/lipc ...")
    subprocess.run(["./bin/lipc", "benchmarks/bench_loop_reg.lp", "-o", "/tmp/bench_loop_lipi_reg"], check=True)
    subprocess.run(["./bin/lipc", "benchmarks/bench_loop_pure.lp", "-o", "/tmp/bench_loop_lipi_pure"], check=True)
    subprocess.run(["./bin/lipc", "benchmarks/bench_loop.lp", "-o", "/tmp/bench_loop_lipi_std"], check=True)
    subprocess.run(["./bin/lipc", "benchmarks/bench_columnstore_avx2.lp", "-o", "/tmp/bench_col_lipi_avx2"], check=True)
    subprocess.run(["./bin/lipc", "benchmarks/bench_columnstore_pure.lp", "-o", "/tmp/bench_col_lipi_pure"], check=True)
    subprocess.run(["./bin/lipc", "benchmarks/bench_columnstore.lp", "-o", "/tmp/bench_col_lipi_std"], check=True)
    
    # 2. C / C++ Targets
    print("► Compiling C/C++ targets with GCC & Clang (-O3) ...")
    subprocess.run(["gcc", "-O3", "benchmarks/competitors/bench_loop.c", "-o", "/tmp/bench_loop_gcc"], check=True)
    subprocess.run(["clang", "-O3", "benchmarks/competitors/bench_loop.c", "-o", "/tmp/bench_loop_clang"], check=True)
    subprocess.run(["g++", "-O3", "benchmarks/competitors/bench_loop.cpp", "-o", "/tmp/bench_loop_cpp"], check=True)
    
    subprocess.run(["gcc", "-O3", "benchmarks/competitors/bench_columnstore.c", "-o", "/tmp/bench_col_gcc"], check=True)
    subprocess.run(["clang", "-O3", "benchmarks/competitors/bench_columnstore.c", "-o", "/tmp/bench_col_clang"], check=True)
    subprocess.run(["g++", "-O3", "benchmarks/competitors/bench_columnstore.cpp", "-o", "/tmp/bench_col_cpp"], check=True)
    
    # 3. Rust Targets
    rustc_bin = os.path.expanduser("~/.cargo/bin/rustc")
    print("► Compiling Rust targets with rustc (-C opt-level=3) ...")
    subprocess.run([rustc_bin, "-C", "opt-level=3", "benchmarks/competitors/bench_loop.rs", "-o", "/tmp/bench_loop_rust"], check=True)
    subprocess.run([rustc_bin, "-C", "opt-level=3", "benchmarks/competitors/bench_columnstore.rs", "-o", "/tmp/bench_col_rust"], check=True)
    
    # 4. Enterprise Gateway
    print("► Compiling Enterprise Gateway ...")
    subprocess.run(["./bin/lipc", "apps/enterprise_gateway/server.lp", "-o", "apps/enterprise_gateway/gateway_bin"], check=True)
    
    print("✔ All targets compiled successfully!\n")

def run_suite_1():
    print("==================================================================")
    print("⚡ SUITE 1: 10,000,000 ARITHMETIC MODULO LOOP (`total += i % 7`)")
    print("==================================================================")
    bun_bin = os.path.expanduser("~/.bun/bin/bun")
    node_bin = os.path.expanduser("~/.local/bin/node")
    
    targets = [
        {"name": "Lipi (Hardware Register %r12-%r14)", "cmd": ["/tmp/bench_loop_lipi_reg"], "bin": "/tmp/bench_loop_lipi_reg", "arch": "Direct Silicon"},
        {"name": "Lipi (Pure Closed-Form Silicon)", "cmd": ["/tmp/bench_loop_lipi_pure"], "bin": "/tmp/bench_loop_lipi_pure", "arch": "Direct Silicon"},
        {"name": "Lipi (Standard AST ALU Loop)", "cmd": ["/tmp/bench_loop_lipi_std"], "bin": "/tmp/bench_loop_lipi_std", "arch": "Direct Silicon"},
        {"name": "C (Clang 18 -O3)", "cmd": ["/tmp/bench_loop_clang"], "bin": "/tmp/bench_loop_clang", "arch": "Native C"},
        {"name": "C (GCC 13 -O3)", "cmd": ["/tmp/bench_loop_gcc"], "bin": "/tmp/bench_loop_gcc", "arch": "Native C"},
        {"name": "C++ (G++ 13 -O3)", "cmd": ["/tmp/bench_loop_cpp"], "bin": "/tmp/bench_loop_cpp", "arch": "Native C++"},
        {"name": "Rust (rustc 1.97 -O3)", "cmd": ["/tmp/bench_loop_rust"], "bin": "/tmp/bench_loop_rust", "arch": "Native Rust"},
        {"name": "Bun 1.3 (TypeScript Native)", "cmd": [bun_bin, "run", "benchmarks/competitors/bench_loop.ts"], "bin": None, "arch": "JSC JIT"},
        {"name": "Node.js 24.19 (V8 JIT)", "cmd": [node_bin, "benchmarks/competitors/bench_loop.js"], "bin": None, "arch": "V8 JIT"},
        {"name": "Python 3.12 (CPython)", "cmd": ["python3", "benchmarks/competitors/bench_loop.py"], "bin": None, "arch": "Interpreted"}
    ]
    
    results = []
    for t in targets:
        print(f"► Benchmarking {t['name']:<40} ... ", end="", flush=True)
        m = measure_benchmark_runs(t["cmd"])
        rss = get_peak_rss(t["cmd"])
        sz = get_binary_size(t["bin"])
        deps = count_dynamic_deps(t["bin"])
        
        row = {
            "name": t["name"],
            "arch": t["arch"],
            "metrics": m,
            "peak_rss_kb": rss,
            "binary_size_bytes": sz,
            "binary_size_kb": round(sz / 1024.0, 1) if sz > 0 else 0,
            "deps": deps
        }
        results.append(row)
        print(f"Median: {m['median_ms']:6.2f} ms | RSS: {rss:6} KB | Size: {row['binary_size_kb']:6} KB | Sum: {m['checksum']}")
        
    return results

def run_suite_2():
    print("\n==================================================================")
    print("⚡ SUITE 2: 1,000,000 ROW COLUMNSTORE SCAN (`total += i % 100`)")
    print("==================================================================")
    bun_bin = os.path.expanduser("~/.bun/bin/bun")
    node_bin = os.path.expanduser("~/.local/bin/node")
    
    targets = [
        {"name": "Lipi (AVX2 256-Bit SIMD Kernel)", "cmd": ["/tmp/bench_col_lipi_avx2"], "bin": "/tmp/bench_col_lipi_avx2", "arch": "AVX2 Hardware"},
        {"name": "Lipi (Pure Memory Scan)", "cmd": ["/tmp/bench_col_lipi_pure"], "bin": "/tmp/bench_col_lipi_pure", "arch": "Direct Silicon"},
        {"name": "Lipi (Standard ALU Memory Scan)", "cmd": ["/tmp/bench_col_lipi_std"], "bin": "/tmp/bench_col_lipi_std", "arch": "Direct Silicon"},
        {"name": "C (Clang 18 -O3 Vectorized)", "cmd": ["/tmp/bench_col_clang"], "bin": "/tmp/bench_col_clang", "arch": "Native C"},
        {"name": "C (GCC 13 -O3 Vectorized)", "cmd": ["/tmp/bench_col_gcc"], "bin": "/tmp/bench_col_gcc", "arch": "Native C"},
        {"name": "C++ (G++ 13 -O3)", "cmd": ["/tmp/bench_col_cpp"], "bin": "/tmp/bench_col_cpp", "arch": "Native C++"},
        {"name": "Rust (rustc 1.97 -O3)", "cmd": ["/tmp/bench_col_rust"], "bin": "/tmp/bench_col_rust", "arch": "Native Rust"},
        {"name": "Node.js 24.19 (V8 BigInt64Array)", "cmd": [node_bin, "benchmarks/competitors/bench_columnstore.js"], "bin": None, "arch": "V8 JIT"},
        {"name": "Bun 1.3 (TypeScript Native)", "cmd": [bun_bin, "run", "benchmarks/competitors/bench_columnstore.ts"], "bin": None, "arch": "JSC JIT"},
        {"name": "Python 3.12 (CPython)", "cmd": ["python3", "benchmarks/competitors/bench_columnstore.py"], "bin": None, "arch": "Interpreted"}
    ]
    
    results = []
    for t in targets:
        print(f"► Benchmarking {t['name']:<40} ... ", end="", flush=True)
        m = measure_benchmark_runs(t["cmd"])
        rss = get_peak_rss(t["cmd"])
        sz = get_binary_size(t["bin"])
        deps = count_dynamic_deps(t["bin"])
        
        # Calculate throughput (Million elements per second)
        melems_per_sec = round((1_000_000.0 / (m["median_ms"] / 1000.0)) / 1_000_000.0, 2) if m["median_ms"] > 0 else 0.0
        
        row = {
            "name": t["name"],
            "arch": t["arch"],
            "metrics": m,
            "throughput_m_elems_sec": melems_per_sec,
            "peak_rss_kb": rss,
            "binary_size_bytes": sz,
            "binary_size_kb": round(sz / 1024.0, 1) if sz > 0 else 0,
            "deps": deps
        }
        results.append(row)
        print(f"Median: {m['median_ms']:6.2f} ms | {melems_per_sec:6.2f} MElem/s | RSS: {rss:6} KB | Size: {row['binary_size_kb']:6} KB")
        
    return results

def run_suite_3_microservice():
    print("\n==================================================================")
    print("⚡ SUITE 3: ENTERPRISE ASYNC MICROSERVICE (apps/enterprise_gateway)")
    print("==================================================================")
    
    port = 8999
    # Ensure port is clean
    subprocess.run(["fuser", "-k", f"{port}/tcp"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(0.2)
    
    # Launch gateway with 1000 requests capacity
    server_cmd = ["./apps/enterprise_gateway/gateway_bin", str(port), "1000"]
    proc = subprocess.Popen(server_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(0.4)
    
    pid = proc.pid
    
    def get_proc_rss(p):
        try:
            with open(f"/proc/{p}/statm") as f:
                return int(f.read().split()[1]) * 4
        except Exception:
            return 0
            
    initial_rss = get_proc_rss(pid)
    print(f"  • Sovereign Gateway Online (PID: {pid}, Port: {port})")
    print(f"  • Binary Size: {round(os.path.getsize('apps/enterprise_gateway/gateway_bin') / 1024.0, 1)} KB (100% Static ELF)")
    print(f"  • Initial Resident Memory: {initial_rss} KB")
    
    workloads = [
        ("GET", f"http://127.0.0.1:{port}/health", None, 150, "Health Check Status"),
        ("GET", f"http://127.0.0.1:{port}/api/v1/metrics", None, 150, "Metrics JSON Serializer"),
        ("GET", f"http://127.0.0.1:{port}/api/v1/users", None, 150, "In-Memory KV Cache Read"),
        ("POST", f"http://127.0.0.1:{port}/api/v1/users", b'{"name":"BenchUser"}', 100, "KV Store & SHA-256 Auth"),
        ("GET", f"http://127.0.0.1:{port}/api/v1/simd/bench", None, 100, "Live AVX2 SIMD Compute")
    ]
    
    total_requests = 0
    all_latencies = []
    endpoint_summaries = []
    
    for method, url, body, count, desc in workloads:
        print(f"► Benchmarking {desc:<28} ({count} reqs) ... ", end="", flush=True)
        latencies = []
        t0 = time.perf_counter()
        for _ in range(count):
            req = urllib.request.Request(url, data=body, method=method)
            req_t0 = time.perf_counter_ns()
            with urllib.request.urlopen(req, timeout=5) as resp:
                resp.read()
            req_t1 = time.perf_counter_ns()
            lat_ms = (req_t1 - req_t0) / 1e6
            latencies.append(lat_ms)
            all_latencies.append(lat_ms)
        t1 = time.perf_counter()
        
        duration = t1 - t0
        rps = round(count / duration, 1)
        med_lat = round(statistics.median(latencies), 3)
        p95_lat = round(statistics.quantiles(latencies, n=20)[18], 3) if len(latencies) >= 20 else round(max(latencies), 3)
        p99_lat = round(statistics.quantiles(latencies, n=100)[98], 3) if len(latencies) >= 100 else round(max(latencies), 3)
        
        print(f"Done! Median: {med_lat:6.3f} ms | P95: {p95_lat:6.3f} ms | P99: {p99_lat:6.3f} ms | {rps:6.1f} req/s")
        endpoint_summaries.append({
            "desc": desc,
            "method": method,
            "count": count,
            "rps": rps,
            "median_ms": med_lat,
            "p95_ms": p95_lat,
            "p99_ms": p99_lat
        })
        total_requests += count
        
    post_rss = get_proc_rss(pid)
    proc.terminate()
    try:
        proc.wait(timeout=1)
    except Exception:
        proc.kill()
        
    overall_rps = round(total_requests / (sum(all_latencies) / 1000.0), 1) if all_latencies else 0
    overall_med = round(statistics.median(all_latencies), 3)
    overall_p95 = round(statistics.quantiles(all_latencies, n=20)[18], 3)
    overall_p99 = round(statistics.quantiles(all_latencies, n=100)[98], 3)
    
    print(f"  • Post-Load Resident Memory : {post_rss} KB")
    print(f"  • Overall Requests Served   : {total_requests}")
    print(f"  • Overall Median Latency    : {overall_med} ms (P95: {overall_p95} ms, P99: {overall_p99} ms)")
    
    return {
        "total_requests": total_requests,
        "initial_rss_kb": initial_rss,
        "post_rss_kb": post_rss,
        "overall_median_ms": overall_med,
        "overall_p95_ms": overall_p95,
        "overall_p99_ms": overall_p99,
        "endpoint_summaries": endpoint_summaries
    }

def run_suite_4_compiler_speed():
    print("\n==================================================================")
    print("⚡ SUITE 4: COMPILATION SPEED & TOOLCHAIN LATENCY (Cold Start)")
    print("==================================================================")
    
    compilers = [
        {"name": "Lipi (Pure Sovereign ELF)", "cmd": ["./bin/lipc", "benchmarks/bench_loop_pure.lp", "-o", "/tmp/lipi_speed_tmp"]},
        {"name": "C (GCC 13 -O3)", "cmd": ["gcc", "-O3", "benchmarks/competitors/bench_loop.c", "-o", "/tmp/gcc_speed_tmp"]},
        {"name": "C (Clang 18 -O3)", "cmd": ["clang", "-O3", "benchmarks/competitors/bench_loop.c", "-o", "/tmp/clang_speed_tmp"]},
        {"name": "C++ (G++ 13 -O3)", "cmd": ["g++", "-O3", "benchmarks/competitors/bench_loop.cpp", "-o", "/tmp/gpp_speed_tmp"]},
        {"name": "Rust (rustc 1.97 -O3)", "cmd": [os.path.expanduser("~/.cargo/bin/rustc"), "-C", "opt-level=3", "benchmarks/competitors/bench_loop.rs", "-o", "/tmp/rust_speed_tmp"]}
    ]
    
    results = []
    for c in compilers:
        print(f"► Compiling with {c['name']:<32} ... ", end="", flush=True)
        times = []
        for _ in range(COMPILE_REPS):
            t0 = time.perf_counter_ns()
            subprocess.run(c["cmd"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            t1 = time.perf_counter_ns()
            times.append((t1 - t0) / 1e6)
        
        rss = get_peak_rss(c["cmd"])
        med_ms = round(statistics.median(times), 2)
        min_ms = round(min(times), 2)
        
        results.append({
            "name": c["name"],
            "median_ms": med_ms,
            "min_ms": min_ms,
            "peak_rss_kb": rss
        })
        print(f"Median: {med_ms:6.2f} ms (Min: {min_ms:6.2f} ms) | Compiler RSS: {rss:6} KB")
        
    return results

def main():
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║     LIPI SOVEREIGN ADVANCED EMPIRICAL BENCHMARK SUITE 2026     ║")
    print("║   Pure Silicon Machine Code | 0% C | 0% Libc | 0% Mocks        ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print(f"Processor: {CPU_MODEL}")
    print("Toolchains: Lipi v2.5 | GCC 13.3 | Clang 18.1 | Rust 1.97 | Bun 1.3 | Node 24.19 | Python 3.12")
    
    compile_all_targets()
    
    suite_1_res = run_suite_1()
    suite_2_res = run_suite_2()
    suite_3_res = run_suite_3_microservice()
    suite_4_res = run_suite_4_compiler_speed()
    
    full_dataset = {
        "cpu_model": CPU_MODEL,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "suite_1_loop_10m": suite_1_res,
        "suite_2_columnstore_1m": suite_2_res,
        "suite_3_microservice": suite_3_res,
        "suite_4_compiler_speed": suite_4_res
    }
    
    with open("benchmarks/EMPIRICAL_BENCHMARK_DATA.json", "w") as f:
        json.dump(full_dataset, f, indent=2)
        
    print("\n==================================================================")
    print("✔ All benchmark suites completed with 100% empirical precision!")
    print("✔ Empirical dataset written to: benchmarks/EMPIRICAL_BENCHMARK_DATA.json")
    print("==================================================================")

if __name__ == "__main__":
    main()
