// ==============================================================================
// 👑 LIPI GRAND MASTER EMPIRICAL BENCHMARK SUITE (100% Pure Lipi — 0% Python)
// File: benchmarks/master_benchmark.lp
// ⚡ Compiles and runs Loop, ColumnStore, and Dynamic Truth workloads live on
//    silicon via direct Linux syscalls and records honest JSON metrics.
// ==============================================================================

include "utso/io"
include "utso/memory"
include "utso/string"

fn mb_now_ns ts_buf
    rc = syscall(228, 1, ts_buf, 0, 0, 0, 0)
    if rc < 0 return 0
    return mem_read(ts_buf, 0) * 1000000000 + mem_read(ts_buf, 8)

fn mb_file_size path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return 0
    sz = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if sz < 0 return 0
    return sz

fn mb_spawn cmd a1 a2 a3
    argv = syscall(9, 0, 64, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd)
    idx = 1
    if len(a1) > 0
        mem_word_write(argv, idx * 8, a1)
        idx = idx + 1
    if len(a2) > 0
        mem_word_write(argv, idx * 8, a2)
        idx = idx + 1
    if len(a3) > 0
        mem_word_write(argv, idx * 8, a3)
        idx = idx + 1
    mem_word_write(argv, idx * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(env, 0, "PATH=/usr/local/bin:/usr/bin:/bin")
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        nfd = syscall(2, "/dev/null", 2, 0, 0, 0, 0)
        if nfd >= 0
            syscall(33, nfd, 1, 0, 0, 0, 0)
            syscall(33, nfd, 2, 0, 0, 0, 0)
            syscall(3, nfd, 0, 0, 0, 0, 0)
        syscall(59, cmd, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw = mem_word_read(st, 0)
    code = (raw / 256) % 256
    if (raw & 127) != 0 code = 128 + (raw & 127)

    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return code

fn mb_fmt_ms ns
    ms_int = ns / 1000000
    ms_frac = (ns % 1000000) / 10000
    fstr = str(ms_frac)
    if ms_frac < 10 fstr = "0" + fstr
    return str(ms_int) + "." + fstr

fn mb_run_target ts_buf label src_path out_path
    if mb_spawn("bin/lipc", src_path, "-o", out_path) != 0
        say "  ❌ FAIL compiling " + label + " (" + src_path + ")"
        exit(1)
    best_ns = 999999999999
    r = 0
    while r < 3
        t0 = mb_now_ns(ts_buf)
        rc = mb_spawn(out_path, "", "", "")
        t1 = mb_now_ns(ts_buf)
        if rc != 0
            say "  ❌ FAIL running " + label
            exit(1)
        dt = t1 - t0
        if dt < 1 dt = 1
        if dt < best_ns best_ns = dt
        r = r + 1
    sz_kb = mb_file_size(out_path) / 1024
    syscall(87, out_path, 0, 0, 0, 0, 0)
    say "  ✔ " + label + ": best=" + mb_fmt_ms(best_ns) + " ms | size=" + str(sz_kb) + " KB"
    return best_ns

fn mb_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0 return 0
    n = len(content)
    written = 0
    while written < n
        w = syscall(1, fd, content + written, n - written, 0, 0, 0)
        if w <= 0 break
        written = written + w
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 1

fn main
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI GRAND MASTER BENCHMARK SUITE — 100% PURE LIPI (0% PYTHON)    ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    ts_buf = syscall(9, 0, 64, 3, 34, -1, 0)
    t_loop = mb_run_target(ts_buf, "Loop 10M Canonical", "benchmarks/bench_loop_canonical.lp", "/tmp/lipi_mb_loop")
    t_cs = mb_run_target(ts_buf, "ColumnStore 1M Canonical", "benchmarks/bench_columnstore_canonical.lp", "/tmp/lipi_mb_cs")
    t_truth = mb_run_target(ts_buf, "Sovereign Dynamic Truth Suite", "benchmarks/sovereign_truth_bench.lp", "/tmp/lipi_mb_truth")
    syscall(11, ts_buf, 64, 0, 0, 0, 0)

    json = "{\n"
    json = json + "  \"engine\": \"lipi-master-benchmark-pure\",\n"
    json = json + "  \"loop_10m_ms\": " + mb_fmt_ms(t_loop) + ",\n"
    json = json + "  \"columnstore_1m_ms\": " + mb_fmt_ms(t_cs) + ",\n"
    json = json + "  \"truth_bench_ms\": " + mb_fmt_ms(t_truth) + "\n"
    json = json + "}\n"
    mb_write_file("benchmarks/FULL_MASTER_BENCHMARK_RESULTS.json", json)

    say "\n🎉 ALL MASTER BENCHMARKS COMPLETED HONESTLY IN PURE LIPI!"
    return 0

main()
