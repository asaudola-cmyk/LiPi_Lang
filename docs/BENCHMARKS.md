# Lipi Benchmarks

This document describes Lipi's benchmark harness, methodology, and how to reproduce measurements locally.

## Methodology

Lipi's canonical benchmark suite (`benchmarks/sovereign_truth_bench.lp`, invoked via `./bin/lipi bench`) intentionally separates two distinct categories so compile-time optimizations are never conflated with runtime execution speed:

1. **Tier I — Compile-Time Algebraic Folding (`O(N)` → `O(1)`)**
   - Measures pure compile-time constant folding of closed-form arithmetic loops (for example, summing a deterministic 10M modulo loop at compile time).
   - Because the work is eliminated before execution, Tier I timings reflect startup/verification overhead rather than per-iteration loop throughput and should **not** be compared against compilers that execute the loop at runtime.

2. **Tier II — Runtime-Seeded Unfoldable Workloads**
   - Seeded dynamically at runtime (via RDTSC / clock entropy) so the compiler cannot constant-fold the loop or precompute results.
   - Measures real machine-code throughput, memory scan bandwidth, segregated slab allocator latency/leak delta, and branch execution.

## Reproducing Locally

```bash
# Build compiler and CLI if not already built
make

# Quick verification run (CI smoke benchmark)
./bin/lipi bench --quick

# Full benchmark run
./bin/lipi bench
```

## Sample Hardware Measurements

Measured via `./bin/lipi bench --quick` on Linux x86_64:

| Benchmark | Tier | Work | Observed Time | Throughput / Rate |
|---|---|---|---|---|
| Closed-Form 10M Modulo Loop Fold | Tier I (compile-time) | 10M folded to `O(1)` | `650 ns` | `84 cycles` |
| Dynamic Unfoldable Xorshift64\* | Tier II (compute) | 1,000,000 iters | `1,879 µs` | `531 M ops/s` (~7 cycles/op) |
| Dynamic 64 KiB Slab Scan | Tier II (memory) | 16 passes (1 MiB) | `205 µs` | `5,112 MB/s` |
| O(1) Slab Alloc/Free Recycler | Tier II (allocator) | 50,000 pairs | `352 µs` | `7 ns/pair`, `0 B` heap delta |
| Inline Integer Equality Branch | Tier II (branching) | 1,000,000 iters | `1,302 µs` | `767 M ops/s` |

## Additional Benchmark Sources

The `benchmarks/` directory also contains standalone benchmark programs and cross-language reference implementations:

- `benchmarks/sovereign_truth_bench.lp` — Canonical Tier I + Tier II benchmark executed by `lipi bench`
- `benchmarks/bench_loop*.lp`, `benchmarks/bench_fib.lp`, `benchmarks/bench_columnstore*.lp` — Micro-benchmarks
- `benchmarks/competitors/` — Equivalent C, C++, Rust, Go, Zig, TypeScript, JavaScript, Swift, and C# implementations for local apples-to-apples testing
- `benchmarks/rps/` — HTTP request-per-second server harnesses across Lipi, C, C++, Rust, Go, and Zig
- `benchmarks/security/` — Network and protocol robustness stress tests

When comparing against C/Rust/Go/Zig locally, compile both sides with identical inputs, runtime-seeded arguments (or volatile sinks) to prevent dead-code elimination, and report median wall time, peak RSS (`/usr/bin/time -v`), and binary size.
