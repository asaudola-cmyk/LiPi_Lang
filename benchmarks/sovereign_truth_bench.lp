// ==============================================================================
// LIPI SOVEREIGN TRUTH BENCHMARK (Tier I Compile-Time vs Tier II Dynamic Silicon)
// ==============================================================================
// Measures both:
//   Tier I : Compile-time closed-form algebraic loop reduction (O(N) -> O(1))
//   Tier II: Runtime-seeded, unfoldable dynamic O(N) bare-silicon workloads
//            using RDTSC + kernel CLOCK_MONOTONIC telemetry (0% external deps).

include "utso/io"
include "utso/string"

// WHY: Reads monotonic clock in nanoseconds using direct Linux SYS_clock_gettime(228, CLOCK_MONOTONIC=1).
fn bench_now_ns ts_buf
    rc = syscall(228, 1, ts_buf, 0, 0, 0, 0)
    if rc < 0
        return 0
    sec = mem_read(ts_buf, 0)
    nsec = mem_read(ts_buf, 8)
    return sec * 1000000000 + nsec

fn bench_get_runtime_seed ts_buf
    ns = bench_now_ns(ts_buf)
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    s = (ns ^ (pid << 17)) & 2147483647
    if s == 0
        s = 104729
    return s

fn run_tier1_algebraic_fold ts_buf
    t0 = bench_now_ns(ts_buf)
    c0 = cpu_clock()
    sum = 0
    for i in 1..10000000
        sum = sum + (i % 7)
    c1 = cpu_clock()
    t1 = bench_now_ns(ts_buf)
    dt_ns = t1 - t0
    if dt_ns < 1
        dt_ns = 1
    cyc = c1 - c0
    if cyc < 0
        cyc = 0
    // Expected closed-form: floor(10000000/7)*21 + (1+2+3) = 1428571*21 + 6 = 29999997
    say "[Tier I : Compile-Time Algebraic Proof O(N)->O(1)] sum=" + str(sum) + " | time=" + str(dt_ns) + " ns | cycles=" + str(cyc)
    return sum

fn run_tier2_xorshift_stream ts_buf dyn_seed n_iters
    x = dyn_seed | 1
    acc = 0
    i = 0
    t0 = bench_now_ns(ts_buf)
    c0 = cpu_clock()
    while i < n_iters
        x = x ^ (x << 13)
        // WHY: Mask right-shift to emulate logical unsigned shift over positive 47-bit state under i64 arithmetic sar.
        x = x ^ ((x >> 17) & 140737488355327)
        x = x ^ ((x << 5) & 2147483647)
        acc = acc + (x & 255)
        i = i + 1
    c1 = cpu_clock()
    t1 = bench_now_ns(ts_buf)
    dt_ns = t1 - t0
    if dt_ns < 1
        dt_ns = 1
    cyc = c1 - c0
    if cyc < 0
        cyc = 0
    mops = (n_iters * 1000) / dt_ns
    say "[Tier II-A: Dynamic Unfoldable Xorshift64*] iters=" + str(n_iters) + " | time=" + str(dt_ns / 1000) + " us | throughput=" + str(mops) + " M ops/s | cycles/op=" + str(cyc / n_iters) + " | chk=" + str(acc & 65535)
    return acc

fn run_tier2_buffer_scan ts_buf dyn_seed n_passes
    words = 8192
    buf_bytes = words * 8
    buf = malloc(buf_bytes)
    if buf == 0
        say "[ERR] malloc failed in Tier II-B"
        return 1

    i = 0
    while i < words
        mem_write(buf, i * 8, (i * 131 + dyn_seed) & 65535)
        i = i + 1

    total_acc = 0
    p = 0
    t0 = bench_now_ns(ts_buf)
    c0 = cpu_clock()
    while p < n_passes
        j = 0
        while j < words
            v = mem_read(buf, j * 8)
            total_acc = total_acc + ((v ^ (p * 17)) & 255)
            j = j + 1
        p = p + 1
    c1 = cpu_clock()
    t1 = bench_now_ns(ts_buf)

    syscall(11, buf, buf_bytes, 0, 0, 0, 0)
    dt_ns = t1 - t0
    if dt_ns < 1
        dt_ns = 1
    total_bytes = n_passes * buf_bytes
    mib_per_s = (total_bytes * 1000) / dt_ns
    say "[Tier II-B: Dynamic 64KiB Slab Scan] passes=" + str(n_passes) + " (" + str(total_bytes / 1048576) + " MiB) | time=" + str(dt_ns / 1000) + " us | bandwidth=" + str(mib_per_s) + " MB/s | chk=" + str(total_acc & 65535)
    return total_acc

fn run_tier2_slab_recycler ts_buf dyn_seed n_cycles
    // Prime one slot so first arena page is materialized before measuring net growth.
    warm = alloc(64)
    mem_write(warm, 0, dyn_seed)
    free(warm)
    arena_before = arena_allocated()

    chk = 0
    i = 0
    t0 = bench_now_ns(ts_buf)
    while i < n_cycles
        blk = alloc(64)
        mem_write(blk, 0, (i ^ dyn_seed) & 65535)
        chk = chk + mem_read(blk, 0)
        free(blk)
        i = i + 1
    t1 = bench_now_ns(ts_buf)

    arena_after = arena_allocated()
    heap_delta = arena_after - arena_before
    dt_ns = t1 - t0
    if dt_ns < 1
        dt_ns = 1
    kops = (n_cycles * 1000000) / dt_ns
    say "[Tier II-C: O(1) Slab Alloc/Free Recycler] cycles=" + str(n_cycles) + " | time=" + str(dt_ns / 1000) + " us | ns/pair=" + str(dt_ns / n_cycles) + " | pairs/s=" + str(kops) + " K/s | heap_delta=" + str(heap_delta) + " B"
    if heap_delta != 0
        say "[ERR] Slab free-list leaked arena memory: delta=" + str(heap_delta)
        return 0 - 1
    return chk

fn run_tier2_inline_eq_branch ts_buf dyn_seed n_iters
    acc = 0
    i = 0
    target = dyn_seed & 3
    t0 = bench_now_ns(ts_buf)
    while i < n_iters
        rem = i & 3
        if rem == target
            acc = acc + 3
        elif rem != 1
            acc = acc + 1
        i = i + 1
    t1 = bench_now_ns(ts_buf)
    dt_ns = t1 - t0
    if dt_ns < 1
        dt_ns = 1
    mops = (n_iters * 1000) / dt_ns
    say "[Tier II-D: Inline Integer Equality Branch] iters=" + str(n_iters) + " | time=" + str(dt_ns / 1000) + " us | throughput=" + str(mops) + " M ops/s | chk=" + str(acc & 65535)
    return acc

fn main
    args = argv()
    quick = 0
    if len(args) >= 2 and get(args, 1) == "--quick"
        quick = 1

    ts_buf = malloc(16)
    mem_write(ts_buf, 0, 0)
    mem_write(ts_buf, 8, 0)

    dyn_seed = bench_get_runtime_seed(ts_buf)
    // Prevent compile-time constant propagation by round-tripping runtime counts through memory slot.
    cfg_buf = malloc(32)
    if quick == 1
        mem_write(cfg_buf, 0, 1000000)
        mem_write(cfg_buf, 8, 16)
        mem_write(cfg_buf, 16, 50000)
        mem_write(cfg_buf, 24, 1000000)
    else
        mem_write(cfg_buf, 0, 20000000)
        mem_write(cfg_buf, 8, 256)
        mem_write(cfg_buf, 16, 500000)
        mem_write(cfg_buf, 24, 20000000)

    n_xor = mem_read(cfg_buf, 0)
    n_pass = mem_read(cfg_buf, 8)
    n_slab = mem_read(cfg_buf, 16)
    n_eq = mem_read(cfg_buf, 24)

    say "========================================================================"
    say "⚡ LIPI SOVEREIGN SILICON BENCHMARK (seed=" + str(dyn_seed) + ", quick=" + str(quick) + ")"
    say "========================================================================"

    r1 = run_tier1_algebraic_fold(ts_buf)
    r2 = run_tier2_xorshift_stream(ts_buf, dyn_seed, n_xor)
    r3 = run_tier2_buffer_scan(ts_buf, dyn_seed, n_pass)
    r4 = run_tier2_slab_recycler(ts_buf, dyn_seed, n_slab)
    r5 = run_tier2_inline_eq_branch(ts_buf, dyn_seed, n_eq)

    syscall(11, cfg_buf, 32, 0, 0, 0, 0)
    syscall(11, ts_buf, 16, 0, 0, 0, 0)

    if r1 != 29999997
        say "[ERR] Unexpected Tier I algebraic sum: " + str(r1)
        return 1
    if r4 < 0
        return 1

    say "========================================================================"
    say "✅ SOVEREIGN_TRUTH_BENCH_OK (combined=" + str((r1 + r2 + r3 + r4 + r5) & 65535) + ")"
    return 0

main()
