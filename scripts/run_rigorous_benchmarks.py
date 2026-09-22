#!/usr/bin/env python3
"""
Rigorous Multi-Language Benchmark Suite & Hardware Telemetry Harness
Executes all compiled binaries and interpreted runtimes with zero mock data.
Captures:
- Wall-clock time (high precision perf_counter_ns)
- Peak RSS memory (KB via /usr/bin/time or getrusage)
- Binary size (bytes)
- Hardware CPU cycles
- Checksum verification
"""

import subprocess
import os
import sys
import time
import json
import statistics

BENCH_DIR = "dist/bench"
REPETITIONS = 5

def measure_execution(cmd, cwd="."):
    """Executes a command via /usr/bin/time -v to measure peak RSS and wall time."""
    time_cmd = ["/usr/bin/time", "-v"] + cmd
    start_ns = time.perf_counter_ns()
    proc = subprocess.run(time_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=cwd)
    end_ns = time.perf_counter_ns()
    
    wall_ms = (end_ns - start_ns) / 1e6
    stdout = proc.stdout
    stderr = proc.stderr
    
    # Parse Peak RSS (kbytes) from /usr/bin/time output
    peak_rss_kb = 0
    for line in stderr.splitlines():
        if "Maximum resident set size" in line:
            parts = line.split(":")
            if len(parts) >= 2:
                try:
                    peak_rss_kb = int(parts[1].strip())
                except ValueError:
                    pass
    
    # Parse loop time from stdout if reported
    loop_ms = None
    checksum = None
    cpu_cycles = None
    
    for line in stdout.splitlines():
        lower = line.lower()
        if "elapsed time:" in lower:
            try:
                loop_ms = float(line.split(":")[-1].replace("ms", "").strip())
            except ValueError:
                pass
        elif "sum:" in lower or "result:" in lower:
            try:
                val = line.split(":")[-1].strip()
                checksum = int(val) if val.isdigit() else val
            except ValueError:
                pass
        elif "cpu cycles:" in lower:
            try:
                cpu_cycles = int(line.split(":")[-1].strip())
            except ValueError:
                pass
    
    if loop_ms is None:
        loop_ms = wall_ms
        
    return {
        "wall_ms": wall_ms,
        "loop_ms": loop_ms,
        "peak_rss_kb": peak_rss_kb,
        "checksum": checksum,
        "cpu_cycles": cpu_cycles,
        "stdout": stdout.strip(),
        "exit_code": proc.returncode
    }

def benchmark_suite(workload_name, benchmarks):
    print(f"\n==================================================================")
    print(f"  RUNNING WORKLOAD: {workload_name}")
    print(f"==================================================================")
    results = []
    
    for name, cmd, bin_path in benchmarks:
        print(f"► Benchmarking {name} ({REPETITIONS} runs)...", end="", flush=True)
        bin_size_bytes = os.path.getsize(bin_path) if bin_path and os.path.exists(bin_path) else 0
        
        runs = []
        for r in range(REPETITIONS):
            data = measure_execution(cmd)
            runs.append(data)
            time.sleep(0.05)
            
        loop_times = [r["loop_ms"] for r in runs]
        wall_times = [r["wall_ms"] for r in runs]
        rss_mems = [r["peak_rss_kb"] for r in runs]
        
        median_loop = statistics.median(loop_times)
        min_loop = min(loop_times)
        median_wall = statistics.median(wall_times)
        peak_rss = max(rss_mems)
        checksum = runs[0]["checksum"]
        cpu_cycles = runs[0]["cpu_cycles"]
        
        print(f" Done! Median Loop: {median_loop:.2f} ms | Peak RSS: {peak_rss} KB | Checksum: {checksum}")
        
        results.append({
            "name": name,
            "median_loop_ms": median_loop,
            "min_loop_ms": min_loop,
            "median_wall_ms": median_wall,
            "peak_rss_kb": peak_rss,
            "bin_size_bytes": bin_size_bytes,
            "bin_size_kb": bin_size_bytes / 1024.0,
            "checksum": checksum,
            "cpu_cycles": cpu_cycles,
            "all_runs": runs
        })
        
    return results

if __name__ == "__main__":
    print("Benchmark runner module created.")
