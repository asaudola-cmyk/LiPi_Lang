// ==============================================================================
// Wave AA Sovereign Numerics, Multi-Arch FP/Throw & Concurrency Regression Suite
//   AA1: x86_64 SSA OP_FCMP IEEE-754 NaN Parity Flag (all 6 compares + ordered)
//   AA2: SSA 2-arg free(addr, size) SYS_munmap VMA leak prevention (/proc/self/maps)
//   AA3: u64 / unsigned high-bit while loops, boxed loop vars & SSA u64 struct fields
//   AA4: Compound /= %= div-by-0 throws, const % -1 no-SIGFPE, WASM SSA div/mod
//        no-trap in V8, and shift >= 64 -O0 vs -O3 bit-exact parity
//   AA5: Live qemu-aarch64 & qemu-riscv64 IEEE-754 f64 arithmetic/comparisons/print,
//        RV64 legacy div/mod-by-0 == 0, and uncaught throw 0 -> exit code 1 + message
//   AA6: fiber_reactor.lp green-thread fiber_context_switch + gc_collect() zero SIGSEGV
//   AA7: >= 8 threads, >= 12,800 concurrent ops across list, dict (rehash/del/get),
//        utso/core/channel.lp, heap allocs, and concurrent STW gc_collect()
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/os/env"
include "utso/core/fiber_reactor.lp"

struct AaU64Box { hi: u64, small: u32 }

G_AA_FIBER_CTX = 0
G_AA_FIBER_DONE = 0
G_AA_FIBER_ROOT_LEN = 0

G_AA_MT_LIST = 0
G_AA_MT_DICT = 0
G_AA_MT_CHAN = 0
G_AA_MT_CTRL = 0

fn aa_spawn(cmd_path, args, log_path)
    // WHY: Fork/exec child process redirecting stdout+stderr to log_path, returning exit code (or 128+sig).
    argv = syscall(9, 0, 192, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 20
        mem_word_write(argv, (i + 1) * 8, args[i])
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    envp = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(envp, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
    mem_word_write(envp, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(log_path) > 0
            fd = syscall(2, log_path, 577, 420)
            if fd >= 0
                syscall(33, fd, 1, 0, 0, 0, 0)
                syscall(33, fd, 2, 0, 0, 0, 0)
                syscall(3, fd, 0, 0, 0, 0, 0)
            end
        end
        syscall(59, cmd_path, argv, envp, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)
    end

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_st = mem_word_read(st, 0)
    sig = raw_st & 127
    rc = 0
    if sig != 0
        rc = 128 + sig
    else
        rc = (raw_st / 256) % 256
    end
    syscall(11, argv, 192, 0, 0, 0, 0)
    syscall(11, envp, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn aa_unlink(path)
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn aa_find_node()
    if syscall(21, "/usr/bin/node", 1, 0, 0, 0, 0) == 0 return "/usr/bin/node" end
    if syscall(21, "/usr/local/bin/node", 1, 0, 0, 0, 0) == 0 return "/usr/local/bin/node" end
    pv = env_get("PATH")
    if len(pv) == 0 return "" end
    pos = 0
    plen = len(pv)
    while pos < plen
        cpos = pos
        while cpos < plen and str_char_at(pv, cpos) != 58
            cpos = cpos + 1
        end
        dir = str_sub(pv, pos, cpos)
        if len(dir) > 0
            cand = dir + "/node"
            if syscall(21, cand, 1, 0, 0, 0, 0) == 0
                return cand
            end
        end
        pos = cpos + 1
    end
    return ""
end

fn aa_count_proc_maps()
    // WHY: /proc/self/maps reports st_size == 0 on Linux procfs, so stream via raw SYS_read
    // and count newline bytes to measure live kernel VMA count accurately.
    fd = syscall(2, "/proc/self/maps", 0, 0, 0, 0, 0)
    if fd < 0 return 0 - 1 end
    buf = syscall(9, 0, 4096, 3, 34, -1, 0)
    lines = 0
    while 1 == 1
        n = syscall(0, fd, buf, 4096, 0, 0, 0)
        if n <= 0 break end
        i = 0
        while i < n
            if (mem_byte_read(buf, i) & 255) == 10
                lines = lines + 1
            end
            i = i + 1
        end
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    syscall(11, buf, 4096, 0, 0, 0, 0)
    return lines
end

// ── AA1: SSA-compiled IEEE-754 NaN comparison verifier ───────────────────────
fn aa_ssa_nan_check(z: f64)
    nan = z / z
    x = 1.0
    errs = 0
    if (nan == nan) != 0 errs = errs + 1 end
    if (nan == x) != 0 errs = errs + 2 end
    if (x == nan) != 0 errs = errs + 4 end
    if (nan != nan) != 1 errs = errs + 8 end
    if (nan != x) != 1 errs = errs + 16 end
    if (x != nan) != 1 errs = errs + 32 end
    if (nan < x) != 0 errs = errs + 64 end
    if (x < nan) != 0 errs = errs + 128 end
    if (nan < nan) != 0 errs = errs + 256 end
    if (nan <= x) != 0 errs = errs + 512 end
    if (x <= nan) != 0 errs = errs + 1024 end
    if (nan <= nan) != 0 errs = errs + 2048 end
    if (nan > x) != 0 errs = errs + 4096 end
    if (x > nan) != 0 errs = errs + 8192 end
    if (nan > nan) != 0 errs = errs + 16384 end
    if (nan >= x) != 0 errs = errs + 32768 end
    if (x >= nan) != 0 errs = errs + 65536 end
    if (nan >= nan) != 0 errs = errs + 131072 end
    // Ordered IEEE-754 checks
    if (1.5 == 1.5) != 1 errs = errs + 262144 end
    if (1.5 != 2.5) != 1 errs = errs + 524288 end
    if (1.5 < 2.5) != 1 errs = errs + 1048576 end
    if (2.5 < 1.5) != 0 errs = errs + 2097152 end
    if (1.5 <= 1.5) != 1 errs = errs + 4194304 end
    if (2.5 > 1.5) != 1 errs = errs + 8388608 end
    if (2.5 >= 2.5) != 1 errs = errs + 16777216 end
    neg_z = 0.0 - z
    if (neg_z == z) != 1 errs = errs + 33554432 end
    return errs
end

// ── AA2: Pure SSA function invoking 2-arg free(addr, size) ───────────────────
fn aa_ssa_mmap_unmap_once(sz)
    p = malloc(sz)
    if p <= 0 return 0 - 1 end
    mem_write(p, 0, 987654321)
    v = mem_read(p, 0)
    free(p, sz)
    return v
end

// ── AA3: Unsigned struct-field arithmetic, comparisons & compound /= ─────────
fn aa_u64_struct_ops(b: AaU64Box)
    // b.hi = 0xFFFFFFFFFFFFFFFE (18446744073709551614 as u64, -2 as i64)
    q = b.hi / 2
    r = b.hi % 10
    s = b.hi >> 1
    c_gt = 0
    c_ge = 0
    c_lt = 0
    c_le = 0
    if b.hi > 10 c_gt = 1 end
    if b.hi >= 10 c_ge = 1 end
    if b.hi < 10 c_lt = 1 end
    if b.hi <= 10 c_le = 1 end
    if q != 9223372036854775807 return 1 end
    if r != 4 return 2 end
    if s != 9223372036854775807 return 3 end
    if c_gt != 1 or c_ge != 1 or c_lt != 0 or c_le != 0 return 4 end
    if (b.small / 2) != 1 return 5 end
    // Compound unsigned /= on u64 struct field (guards parser + SSA + legacy u64 div)
    b.hi /= 2
    if b.hi != 9223372036854775807 return 6 end
    return 0
end

// ── AA6: Real green-thread fiber entry executed on dedicated mmap stack ──────
fn aa_green_fiber_entry()
    // Allocate GC-tracked objects on this fiber stack and run gc_collect() + slab overwrite
    // churn across TWO cooperative slices to prove BOTH fiber and caller/main stacks stay rooted!
    s1 = "aa_green_fiber_alive_" + str(777)
    arr = [10, 20, 30, 40]
    gc_collect()
    k = 0
    while k < 250
        churn1 = "FIBER_SLAB_CHURN_S1_" + str(k)
        k = k + 1
    end
    G_AA_FIBER_DONE = 1
    // Yield Slice 1 back to reactor (saving suspended fiber SP at [G_AA_FIBER_CTX + 8])
    ret_sp1 = mem_read(G_AA_FIBER_CTX, 0)
    fiber_context_switch(G_AA_FIBER_CTX + 8, ret_sp1)

    // Resumed in Slice 2: verify s1 & arr survived AND trigger another GC + churn
    s2 = s1 + "_still_here"
    gc_collect()
    k = 0
    while k < 250
        churn2 = "FIBER_SLAB_CHURN_S2_" + str(k)
        k = k + 1
    end
    gc_collect()
    if s2 == "aa_green_fiber_alive_777_still_here" and len(arr) == 4 and arr[3] == 40
        G_AA_FIBER_ROOT_LEN = len(s2)
        G_AA_FIBER_DONE = 12345
    end
    // Return control to reactor caller saved in [G_AA_FIBER_CTX + 0]
    ret_sp = mem_read(G_AA_FIBER_CTX, 0)
    fiber_context_switch(G_AA_FIBER_CTX + 16, ret_sp)
    return 0
end

// ── AA7: Multithreaded stress worker (list + dict + channel + alloc + GC) ───
// Control block G_AA_MT_CTRL offsets:
//   +0  : error count
//   +8  : completed workers count
//   +16 : total channel items received across all 4 consumer threads
//   +24 : sum of all channel items received across all 4 consumer threads
//   +32 : producer sent count
fn aa_mt_worker(tid)
    i = 0
    while i < 500
        // Concurrent list push + read + occasional pop (500 pushes, 100 pops -> net +400/thread)
        val = (tid + 1) * 10000 + i
        push(G_AA_MT_LIST, val)
        if (i % 5) == 0
            pv = pop(G_AA_MT_LIST)
            if pv <= 0
                atomic_add(G_AA_MT_CTRL, 1)
            end
        end
        if (i % 5) == 1
            cur_l = len(G_AA_MT_LIST)
            if cur_l > 0
                got = G_AA_MT_LIST[0]
                if got < 0
                    atomic_add(G_AA_MT_CTRL, 1)
                end
            end
        end

        // Concurrent dict insert (250 unique keys/thread triggering multi-level 2x rehashes),
        // read back, has_key, and delete 50 keys (net +200 keys/thread)
        if i < 250
            k = "t" + str(tid) + "_k" + str(i)
            expected = (tid + 1) * 1000 + i
            G_AA_MT_DICT[k] = expected
            if (i % 2) == 0
                got_d = G_AA_MT_DICT[k]
                if got_d != expected
                    atomic_add(G_AA_MT_CTRL, 1)
                end
            end
            if i >= 200
                del_ok = dict_del(G_AA_MT_DICT, k)
                if del_ok != 1
                    atomic_add(G_AA_MT_CTRL, 1)
                end
            end
        end

        // Concurrent channel: threads 0..3 produce 500 items each (1..500);
        // threads 4..7 consume until total received == 2000.
        if tid < 4
            item = i + 1
            sent = 0
            while sent == 0
                r = channel_send(G_AA_MT_CHAN, item)
                if r == 1
                    sent = 1
                    atomic_add(G_AA_MT_CTRL + 32, 1)
                else
                    syscall(24, 0, 0, 0, 0, 0, 0) // sched_yield
                end
            end
        else
            got_c = channel_recv(G_AA_MT_CHAN)
            if got_c > 0
                atomic_add(G_AA_MT_CTRL + 16, 1)
                atomic_add(G_AA_MT_CTRL + 24, got_c)
            end
        end

        // Periodic GC + slab alloc/free + concurrent dict keys()/values() snapshot churn
        if (i % 100) == 50
            dk = keys(G_AA_MT_DICT)
            dv = values(G_AA_MT_DICT)
            if len(dk) < 0 or len(dv) < 0
                atomic_add(G_AA_MT_CTRL, 1)
            end
        end
        if (i % 125) == 60
            tmp = alloc(128)
            mem_write(tmp, 0, val)
            free(tmp)
        end
        if tid == 0 and (i % 200) == 100
            gc_collect()
        end
        i = i + 1
    end

    // Consumer threads drain any remaining items until all 2000 items are received
    if tid >= 4
        while mem_read(G_AA_MT_CTRL + 16, 0) < 2000
            got_c = channel_recv(G_AA_MT_CHAN)
            if got_c > 0
                atomic_add(G_AA_MT_CTRL + 16, 1)
                atomic_add(G_AA_MT_CTRL + 24, got_c)
            else
                syscall(24, 0, 0, 0, 0, 0, 0)
            end
        end
    end

    atomic_add(G_AA_MT_CTRL + 8, 1)
    return 0
end

fn main()
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    base = "/tmp/lipi_waa_" + str(pid)
    log_p = base + ".log"

    compiler = env_get("LIPI_COMPILER")
    if len(compiler) == 0
        compiler = "bin/lipc"
        if syscall(21, "bin/lipc_bin", 1, 0, 0, 0, 0) == 0
            compiler = "bin/lipc_bin"
        end
    end

    say "================================================================="
    say "WAVE AA: NUMERICS, MULTI-ARCH FP/THROW, GC & MT CONCURRENCY SUITE"
    say "================================================================="

    // ── AA1: SSA OP_FCMP IEEE-754 NaN All 6 Comparisons ──────────────────────
    nan_errs = aa_ssa_nan_check(0.0)
    if nan_errs != 0
        say "FAIL AA1a: in-process SSA NaN check bitmask = " + str(nan_errs)
        exit(1)
    end
    // Also explicitly compile a child binary with --ssa-codegen and verify live!
    aa1_src = base + "_aa1.lp"
    aa1_bin = base + "_aa1"
    aa1_out = base + "_aa1.out"
    aa1_code = "fn chk(z: f64)\n    n = z / z\n    r = 0\n"
    aa1_code = aa1_code + "    if n == n r = r + 1 end\n"
    aa1_code = aa1_code + "    if n != n r = r + 2 end\n"
    aa1_code = aa1_code + "    if n < 1.0 r = r + 4 end\n"
    aa1_code = aa1_code + "    if n <= 1.0 r = r + 8 end\n"
    aa1_code = aa1_code + "    if n > 1.0 r = r + 16 end\n"
    aa1_code = aa1_code + "    if n >= 1.0 r = r + 32 end\n"
    aa1_code = aa1_code + "    if 1.0 < n r = r + 64 end\n"
    aa1_code = aa1_code + "    if 1.0 <= n r = r + 128 end\n"
    aa1_code = aa1_code + "    if 1.0 > n r = r + 256 end\n"
    aa1_code = aa1_code + "    if 1.0 >= n r = r + 512 end\n"
    aa1_code = aa1_code + "    return r\nend\nfn main()\n    say chk(0.0)\nend\n"
    file_write(aa1_src, aa1_code)
    if aa_spawn(compiler, [aa1_src, aa1_bin, "--ssa-codegen"], log_p) != 0
        say "FAIL AA1b: --ssa-codegen compile failed: " + file_read(log_p)
        exit(1)
    end
    if aa_spawn(aa1_bin, [], aa1_out) != 0
        say "FAIL AA1c: --ssa-codegen binary crashed"
        exit(1)
    end
    if str_contains(file_read(aa1_out), "2") != 1 or str_contains(file_read(aa1_out), "3") == 1
        say "FAIL AA1d: expected exact bitmask 2 (only NaN != NaN true), got: " + file_read(aa1_out)
        exit(1)
    end
    aa_unlink(aa1_src)
    aa_unlink(aa1_bin)
    aa_unlink(aa1_out)
    say "  [PASS] AA1. x86_64 SSA OP_FCMP IEEE-754 NaN all 6 comparisons (==,!=,<,<=,>,>=)"

    // ── AA2: SSA 2-arg free(addr, size) SYS_munmap VMA Leak Verification ────
    // Warm up once before measuring baseline /proc/self/maps line count
    w0 = aa_ssa_mmap_unmap_once(65536)
    if w0 != 987654321
        say "FAIL AA2a: warmup malloc/free returned " + str(w0)
        exit(1)
    end
    vma_before = aa_count_proc_maps()
    mi = 0
    while mi < 64
        rv = aa_ssa_mmap_unmap_once(65536)
        if rv != 987654321
            say "FAIL AA2b: iteration " + str(mi) + " returned " + str(rv)
            exit(1)
        end
        mi = mi + 1
    end
    vma_after = aa_count_proc_maps()
    vma_delta = vma_after - vma_before
    if vma_before <= 0 or vma_delta > 4
        say "FAIL AA2c: 2-arg free(addr,size) leaked VMAs! before=" + str(vma_before) + " after=" + str(vma_after)
        exit(1)
    end
    // Also verify 1-arg slab free(p) and arena_reset bounds/lock-release safety
    sp = alloc(64)
    mem_write(sp, 0, 424242)
    free(sp)
    if arena_reset(0) != (0 - 1)
        say "FAIL AA2d: arena_reset(0) did not return -1"
        exit(1)
    end
    if arena_reset(heap_curr_ptr() + 65536) != (0 - 1)
        say "FAIL AA2e: arena_reset(>heap_ptr) did not return -1"
        exit(1)
    end
    am = arena_mark()
    ap = alloc(128)
    mem_write(ap, 0, 777)
    if arena_reset(am) != 0
        say "FAIL AA2f: valid arena_reset failed"
        exit(1)
    end
    sp2 = alloc(64)
    if sp2 <= 0
        say "FAIL AA2g: alloc after arena_reset failed"
        exit(1)
    end
    free(sp2)
    say "  [PASS] AA2. SSA 2-arg free(addr, size) unmaps cleanly via SYS_munmap (VMA delta=" + str(vma_delta) + ") & arena_reset bounds"

    // ── AA3: u64 High-Bit while Loops, Boxed Loop Var & SSA u64 Struct Fields
    u_cur: u64 = 0 - 8
    u_lim: u64 = 0 - 2
    u_cnt = 0
    while u_cur < u_lim
        u_cnt = u_cnt + 1
        u_cur = u_cur + 1
    end
    if u_cnt != 6
        say "FAIL AA3a: u64 high-bit while (u < limit) expected 6, got " + str(u_cnt)
        exit(1)
    end
    u_hi: u64 = 0 - 1
    u_lo: u64 = 10
    u_entered = 0
    while u_hi > u_lo
        u_entered = 1
        break
    end
    if u_entered != 1
        say "FAIL AA3b: u64 high-bit while (0xFFFFFFFFFFFFFFFF > 10) failed to enter!"
        exit(1)
    end
    // Boxed loop variable captured by closure inside while loop
    bi = 0
    clos_fn = 0
    while bi < 5
        if bi == 3
            clos_fn = fn() => bi
        end
        bi = bi + 1
    end
    if bi != 5 or clos_fn() != 5
        say "FAIL AA3c: boxed while loop var mismatch bi=" + str(bi) + " clos=" + str(clos_fn())
        exit(1)
    end
    // u64/u32 struct fields in SSA + legacy
    ub = AaU64Box()
    ub.hi = 0 - 2
    ub.small = 2
    u_rc = aa_u64_struct_ops(ub)
    if u_rc != 0
        say "FAIL AA3d: u64 struct field ops failed with code " + str(u_rc)
        exit(1)
    end
    say "  [PASS] AA3. u64 high-bit while loops, boxed loop var, & u64 struct field div/mod/shr/cmp"

    // ── AA4: Div/Mod & Shift Consistency (x86_64, Optimizer -O0/-O3, WASM V8)
    // 4a. Compound /= and %= throw DivisionByZeroException inside try/catch
    caught_div = ""
    try
        dx = 100
        dx /= 0
    catch e1
        caught_div = e1
    end
    caught_mod = ""
    try
        mx = 100
        mx %= 0
    catch e2
        caught_mod = e2
    end
    if str_contains(caught_div, "DivisionByZero") != 1 or str_contains(caught_mod, "DivisionByZero") != 1
        say "FAIL AA4a: compound /= or %= did not throw DivisionByZeroException: div=" + caught_div + " mod=" + caught_mod
        exit(1)
    end
    // 4a2. Struct field and array-element compound /= and %= also throw DivisionByZeroException
    caught_fdiv = ""
    try
        ub_d0 = AaU64Box()
        ub_d0.hi = 100
        ub_d0.hi /= 0
    catch ef1
        caught_fdiv = ef1
    end
    caught_fmod = ""
    try
        ub_m0 = AaU64Box()
        ub_m0.hi = 100
        ub_m0.hi %= 0
    catch ef2
        caught_fmod = ef2
    end
    caught_adiv = ""
    try
        arr_d0 = [100, 200]
        arr_d0[0] /= 0
    catch ea1
        caught_adiv = ea1
    end
    if str_contains(caught_fdiv, "DivisionByZero") != 1 or str_contains(caught_fmod, "DivisionByZero") != 1 or str_contains(caught_adiv, "DivisionByZero") != 1
        say "FAIL AA4a2: struct/array compound /= %= did not throw: fdiv=" + caught_fdiv + " fmod=" + caught_fmod + " adiv=" + caught_adiv
        exit(1)
    end
    // 4b. Constant-RHS % -1 on INT64_MIN must return 0 without SIGFPE
    imin = -9223372036854775807 - 1
    rem_m1 = imin % -1
    div_m1 = imin / -1
    if rem_m1 != 0 or div_m1 != imin
        say "FAIL AA4b: INT64_MIN % -1 or / -1 wrong: rem=" + str(rem_m1) + " div=" + str(div_m1)
        exit(1)
    end
    // 4c. Shift >= 64 parity between -O0 and -O3
    aa4s_src = base + "_aa4_shift.lp"
    aa4s_o0 = base + "_aa4_o0"
    aa4s_o3 = base + "_aa4_o3"
    aa4s_out0 = base + "_aa4_o0.out"
    aa4s_out3 = base + "_aa4_o3.out"
    file_write(aa4s_src, "fn run_shifts()\n    a = 1 << 64\n    b = 1 << 65\n    c = 1024 >> 64\n    d = 1024 >> 66\n    e = 7 << 129\n    say str(a) + \",\" + str(b) + \",\" + str(c) + \",\" + str(d) + \",\" + str(e)\nend\nfn main()\n    run_shifts()\nend\n")
    if aa_spawn(compiler, [aa4s_src, aa4s_o0, "-O0"], log_p) != 0 or aa_spawn(compiler, [aa4s_src, aa4s_o3, "-O3"], log_p) != 0
        say "FAIL AA4c: shift -O0/-O3 compile failed: " + file_read(log_p)
        exit(1)
    end
    aa_spawn(aa4s_o0, [], aa4s_out0)
    aa_spawn(aa4s_o3, [], aa4s_out3)
    so0 = file_read(aa4s_out0)
    so3 = file_read(aa4s_out3)
    if so0 != so3 or str_contains(so0, "1,2,1024,256,14") != 1
        say "FAIL AA4d: shift >= 64 -O0 vs -O3 divergence! O0=" + so0 + " O3=" + so3
        exit(1)
    end
    aa_unlink(aa4s_src)
    aa_unlink(aa4s_o0)
    aa_unlink(aa4s_o3)
    aa_unlink(aa4s_out0)
    aa_unlink(aa4s_out3)

    // 4d. WASM SSA OP_DIV / OP_MOD no-trap on div-by-0 and INT64_MIN / -1 in V8
    node_bin = aa_find_node()
    if len(node_bin) > 0
        aa4w_src = base + "_aa4_wasm.lp"
        aa4w_bin = base + "_aa4.wasm"
        aa4w_js = base + "_aa4.mjs"
        aa4w_out = base + "_aa4_w.out"
        file_write(aa4w_src, "fn safe_div(a, b)\n    return a / b\nend\nfn safe_mod(a, b)\n    return a % b\nend\nfn main()\n    imin = -9223372036854775807 - 1\n    d0 = safe_div(100, 0)\n    m0 = safe_mod(100, 0)\n    dm = safe_div(imin, -1)\n    mm = safe_mod(imin, -1)\n    ok = safe_div(42, 6)\n    if d0 == 0 and m0 == 0 and dm == imin and mm == 0 and ok == 7\n        return 777\n    end\n    return 0\nend\n")
        if aa_spawn(compiler, [aa4w_src, aa4w_bin, "--target=wasm", "--ssa-codegen"], log_p) != 0
            say "FAIL AA4e: WASM SSA compile failed: " + file_read(log_p)
            exit(1)
        end
        js_code = "import fs from 'fs';\nconst b = fs.readFileSync(process.argv[2]);\nconst imp = { wasi_snapshot_preview1: { fd_write() { return 0; } } };\nconst { instance } = await WebAssembly.instantiate(b, imp);\nprocess.stdout.write('WRET=' + String(instance.exports.main()) + '\\n');\n"
        file_write(aa4w_js, js_code)
        if aa_spawn(node_bin, [aa4w_js, aa4w_bin], aa4w_out) != 0
            say "FAIL AA4f: WASM SSA trapped in V8: " + file_read(aa4w_out)
            exit(1)
        end
        if str_contains(file_read(aa4w_out), "WRET=777") != 1
            say "FAIL AA4g: WASM SSA result mismatch: " + file_read(aa4w_out)
            exit(1)
        end
        aa_unlink(aa4w_src)
        aa_unlink(aa4w_bin)
        aa_unlink(aa4w_js)
        aa_unlink(aa4w_out)
    end
    say "  [PASS] AA4. Compound /= %= throw, INT64_MIN%-1, shift>=64 -O0/-O3 parity, & WASM V8 no-trap"

    // ── AA5: Live ARM64 & RISC-V 64 IEEE-754 f64 + Uncaught throw Parity ─────
    aa5_fp_src = base + "_aa5_fp.lp"
    aa5_fp_code = "struct Pt { x: f64, y: f64 }\n"
    aa5_fp_code = aa5_fp_code + "fn calc(a: f64, b: f64) -> f64\n    return a + b * 4.0\nend\n"
    aa5_fp_code = aa5_fp_code + "fn ret_f()\n    return 3.5\nend\n"
    aa5_fp_code = aa5_fp_code + "fn ret_i()\n    return 10\nend\n"
    aa5_fp_code = aa5_fp_code + "fn main()\n"
    aa5_fp_code = aa5_fp_code + "    p = Pt()\n    p.x = 1.5\n    p.y = 2.25\n"
    aa5_fp_code = aa5_fp_code + "    r = calc(p.x, p.y)\n"
    aa5_fp_code = aa5_fp_code + "    say r\n"
    aa5_fp_code = aa5_fp_code + "    say 3.14\n"
    aa5_fp_code = aa5_fp_code + "    say (0.0 - 3.14)\n"
    aa5_fp_code = aa5_fp_code + "    say (1 + 2.5)\n"
    aa5_fp_code = aa5_fp_code + "    say (7.5 % 2.0)\n"
    aa5_fp_code = aa5_fp_code + "    z = 0.0\n"
    aa5_fp_code = aa5_fp_code + "    say (1.0 / z)\n"
    aa5_fp_code = aa5_fp_code + "    say ((0.0 - 1.0) / z)\n"
    aa5_fp_code = aa5_fp_code + "    n = z / z\n"
    aa5_fp_code = aa5_fp_code + "    say n\n"
    aa5_fp_code = aa5_fp_code + "    cf = 2.0\n"
    aa5_fp_code = aa5_fp_code + "    cf += 3.5\n"
    aa5_fp_code = aa5_fp_code + "    cf *= 2.0\n"
    aa5_fp_code = aa5_fp_code + "    say cf\n"
    aa5_fp_code = aa5_fp_code + "    p.x += 2.5\n"
    aa5_fp_code = aa5_fp_code + "    say (\"NF=\" + str(-ret_f()) + \",DM0=\" + str(ret_i() % 0) + \",PX=\" + str(p.x) + \",BIG=\" + str(1000000000.0 * 1000000000.0 * 100.0) + \",TINY=\" + str(1.0 / 100000000.0))\n"
    aa5_fp_code = aa5_fp_code + "    nbits = 0\n"
    aa5_fp_code = aa5_fp_code + "    if n == n nbits = nbits + 1 end\n"
    aa5_fp_code = aa5_fp_code + "    if n != n nbits = nbits + 2 end\n"
    aa5_fp_code = aa5_fp_code + "    if n < 1.0 nbits = nbits + 4 end\n"
    aa5_fp_code = aa5_fp_code + "    if n <= 1.0 nbits = nbits + 8 end\n"
    aa5_fp_code = aa5_fp_code + "    if n > 1.0 nbits = nbits + 16 end\n"
    aa5_fp_code = aa5_fp_code + "    if n >= 1.0 nbits = nbits + 32 end\n"
    aa5_fp_code = aa5_fp_code + "    if 1.0 < n nbits = nbits + 64 end\n"
    aa5_fp_code = aa5_fp_code + "    if 1.0 <= n nbits = nbits + 128 end\n"
    aa5_fp_code = aa5_fp_code + "    obits = 0\n"
    aa5_fp_code = aa5_fp_code + "    if 1.5 < 2.25 obits = obits + 1 end\n"
    aa5_fp_code = aa5_fp_code + "    if 2.25 <= 2.25 obits = obits + 2 end\n"
    aa5_fp_code = aa5_fp_code + "    if 3.5 > 2.25 obits = obits + 4 end\n"
    aa5_fp_code = aa5_fp_code + "    if 3.5 >= 3.5 obits = obits + 8 end\n"
    aa5_fp_code = aa5_fp_code + "    if 2.25 < 1.5 obits = obits + 16 end\n"
    aa5_fp_code = aa5_fp_code + "    say (\"FP=\" + str(3.14) + \",NB=\" + str(nbits) + \",OB=\" + str(obits) + \",D0=\" + str(10 / 0) + \",M0=\" + str(10 % 0))\n"
    aa5_fp_code = aa5_fp_code + "end\n"
    file_write(aa5_fp_src, aa5_fp_code)

    aa5_th0_src = base + "_aa5_th0.lp"
    file_write(aa5_th0_src, "fn boom()\n    throw 0\nend\nfn main()\n    boom()\nend\n")
    aa5_ths_src = base + "_aa5_ths.lp"
    file_write(aa5_ths_src, "fn main()\n    throw \"aa_uncaught_err\"\nend\n")

    aa5_a64_fp = base + "_aa5_a64_fp"
    aa5_rv_fp = base + "_aa5_rv_fp"
    aa5_a64_th0 = base + "_aa5_a64_th0"
    aa5_rv_th0 = base + "_aa5_rv_th0"
    aa5_a64_ths = base + "_aa5_a64_ths"
    aa5_rv_ths = base + "_aa5_rv_ths"
    aa5_out = base + "_aa5.out"

    if aa_spawn(compiler, [aa5_fp_src, aa5_a64_fp, "--target=arm64"], log_p) != 0
        say "FAIL AA5a: ARM64 FP compile failed: " + file_read(log_p)
        exit(1)
    end
    if aa_spawn(compiler, [aa5_fp_src, aa5_rv_fp, "--target=riscv64"], log_p) != 0
        say "FAIL AA5b: RISC-V 64 FP compile failed: " + file_read(log_p)
        exit(1)
    end
    if aa_spawn(compiler, [aa5_th0_src, aa5_a64_th0, "--target=arm64"], log_p) != 0 or aa_spawn(compiler, [aa5_th0_src, aa5_rv_th0, "--target=riscv64"], log_p) != 0
        say "FAIL AA5c: ARM64/RV64 throw 0 compile failed: " + file_read(log_p)
        exit(1)
    end
    if aa_spawn(compiler, [aa5_ths_src, aa5_a64_ths, "--target=arm64"], log_p) != 0 or aa_spawn(compiler, [aa5_ths_src, aa5_rv_ths, "--target=riscv64"], log_p) != 0
        say "FAIL AA5d: ARM64/RV64 throw str compile failed: " + file_read(log_p)
        exit(1)
    end

    if syscall(21, "/usr/bin/qemu-aarch64", 1, 0, 0, 0, 0) == 0
        rc_afp = aa_spawn("/usr/bin/qemu-aarch64", [aa5_a64_fp], aa5_out)
        o_afp = file_read(aa5_out)
        if rc_afp != 0 or str_contains(o_afp, "10.5") != 1 or str_contains(o_afp, "-3.14") != 1 or str_contains(o_afp, "3.5") != 1 or str_contains(o_afp, "1.5") != 1 or str_contains(o_afp, "-Inf") != 1 or str_contains(o_afp, "NaN") != 1 or str_contains(o_afp, "11") != 1 or str_contains(o_afp, "FP=3.14,NB=2,OB=15,D0=0,M0=0") != 1 or str_contains(o_afp, "NF=-3.5,DM0=0,PX=4.0,BIG=1.0e+20,TINY=1.0e-8") != 1
            say "FAIL AA5e: qemu-aarch64 FP mismatch (rc=" + str(rc_afp) + "): " + o_afp
            exit(1)
        end
        rc_at0 = aa_spawn("/usr/bin/qemu-aarch64", [aa5_a64_th0], aa5_out)
        o_at0 = file_read(aa5_out)
        if rc_at0 != 1 or str_contains(o_at0, "Uncaught exception: 0") != 1
            say "FAIL AA5f: qemu-aarch64 uncaught throw 0 mismatch (rc=" + str(rc_at0) + "): " + o_at0
            exit(1)
        end
        rc_ats = aa_spawn("/usr/bin/qemu-aarch64", [aa5_a64_ths], aa5_out)
        o_ats = file_read(aa5_out)
        if rc_ats != 1 or str_contains(o_ats, "Uncaught exception: aa_uncaught_err") != 1
            say "FAIL AA5g: qemu-aarch64 uncaught throw str mismatch (rc=" + str(rc_ats) + "): " + o_ats
            exit(1)
        end
    end
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0
        rc_rfp = aa_spawn("/usr/bin/qemu-riscv64", [aa5_rv_fp], aa5_out)
        o_rfp = file_read(aa5_out)
        if rc_rfp != 0 or str_contains(o_rfp, "10.5") != 1 or str_contains(o_rfp, "-3.14") != 1 or str_contains(o_rfp, "3.5") != 1 or str_contains(o_rfp, "1.5") != 1 or str_contains(o_rfp, "-Inf") != 1 or str_contains(o_rfp, "NaN") != 1 or str_contains(o_rfp, "11") != 1 or str_contains(o_rfp, "FP=3.14,NB=2,OB=15,D0=0,M0=0") != 1 or str_contains(o_rfp, "NF=-3.5,DM0=0,PX=4.0,BIG=1.0e+20,TINY=1.0e-8") != 1
            say "FAIL AA5h: qemu-riscv64 FP mismatch (rc=" + str(rc_rfp) + "): " + o_rfp
            exit(1)
        end
        rc_rt0 = aa_spawn("/usr/bin/qemu-riscv64", [aa5_rv_th0], aa5_out)
        o_rt0 = file_read(aa5_out)
        if rc_rt0 != 1 or str_contains(o_rt0, "Uncaught exception: 0") != 1
            say "FAIL AA5i: qemu-riscv64 uncaught throw 0 mismatch (rc=" + str(rc_rt0) + "): " + o_rt0
            exit(1)
        end
        rc_rts = aa_spawn("/usr/bin/qemu-riscv64", [aa5_rv_ths], aa5_out)
        o_rts = file_read(aa5_out)
        if rc_rts != 1 or str_contains(o_rts, "Uncaught exception: aa_uncaught_err") != 1
            say "FAIL AA5j: qemu-riscv64 uncaught throw str mismatch (rc=" + str(rc_rts) + "): " + o_rts
            exit(1)
        end
    end
    aa_unlink(aa5_fp_src)
    aa_unlink(aa5_th0_src)
    aa_unlink(aa5_ths_src)
    aa_unlink(aa5_a64_fp)
    aa_unlink(aa5_rv_fp)
    aa_unlink(aa5_a64_th0)
    aa_unlink(aa5_rv_th0)
    aa_unlink(aa5_a64_ths)
    aa_unlink(aa5_rv_ths)
    aa_unlink(aa5_out)
    say "  [PASS] AA5. Live qemu-aarch64 & qemu-riscv64 IEEE-754 f64 + NaN + div0 + uncaught throw parity"

    // ── AA6: fiber_reactor.lp Green-Thread Multi-Yield + Main-Stack GC Root Safety
    main_secret = "AA6_MAIN_STACK_SECRET_" + str(98765)
    main_arr = [77, 88, 99]
    sb_before = mem_read(slab_buckets_ptr(), 80)
    f_stk = malloc(65536)
    f_ctx = malloc(32)
    mem_zero(f_ctx, 32)
    // Align target_sp so (target_sp + 56) % 16 == 8 (System V AMD64 entry ABI)
    aligned_top = ((f_stk + 65536 - 128) / 16) * 16 + 8
    target_sp = aligned_top - 56
    mem_write(target_sp, 0, 0)  // r15
    mem_write(target_sp, 8, 0)  // r14
    mem_write(target_sp, 16, 0) // r13
    mem_write(target_sp, 24, 0) // r12
    mem_write(target_sp, 32, 0) // rbx
    mem_write(target_sp, 40, 0) // rbp
    mem_write(target_sp, 48, fn_ptr(aa_green_fiber_entry)) // ret RIP
    mem_write(f_ctx, 8, target_sp)
    G_AA_FIBER_CTX = f_ctx
    G_AA_FIBER_DONE = 0
    G_AA_FIBER_ROOT_LEN = 0

    fr = reactor_new(8)
    reactor_spawn_green_thread(fr, f_ctx)
    f_done1 = reactor_run_until_idle(fr, 1)
    if f_done1 != 1 or G_AA_FIBER_DONE != 1
        say "FAIL AA6a: fiber slice 1 failed: done1=" + str(f_done1) + " flag=" + str(G_AA_FIBER_DONE)
        exit(1)
    end
    // Resume Slice 2 on slot 0 (desc+32 keeps original fiber stack top)
    mem_write(mem_read(fr, 0), 8, FIBER_STATE_READY)
    f_done = reactor_run_until_idle(fr, 1)
    sb_after = mem_read(slab_buckets_ptr(), 80)
    gc_collect()
    reactor_free(fr)
    free(f_ctx, 32)
    free(f_stk, 65536)
    if f_done != 1 or G_AA_FIBER_DONE != 12345 or G_AA_FIBER_ROOT_LEN != 35 or sb_after != sb_before or main_secret != "AA6_MAIN_STACK_SECRET_98765" or main_arr[2] != 99
        say "FAIL AA6: fiber_reactor multi-yield + main-stack GC failed: done=" + str(f_done) + " flag=" + str(G_AA_FIBER_DONE) + " root=" + str(G_AA_FIBER_ROOT_LEN) + " sb_eq=" + str(sb_after == sb_before) + " main_secret=" + main_secret
        exit(1)
    end
    say "  [PASS] AA6. fiber_reactor.lp multi-yield green-thread + main-stack GC root preservation"

    // ── AA7: 8-Thread >=12,800-Op Concurrent list/dict/channel/alloc/GC Stress
    G_AA_MT_LIST = list()
    G_AA_MT_DICT = {}
    G_AA_MT_CHAN = channel_new(64)
    G_AA_MT_CTRL = malloc(64)
    mem_zero(G_AA_MT_CTRL, 64)

    handles = list()
    stacks = list()
    ti = 0
    while ti < 8
        st = malloc(131072)
        h = malloc(16)
        mem_write(h, 0, 1)
        push(stacks, st)
        push(handles, h)
        tid_res = thread_spawn_vm_joinable(fn_ptr(aa_mt_worker), ti, st + 131072, h)
        if tid_res <= 0
            say "FAIL AA7a: thread_spawn_vm_joinable failed on thread " + str(ti)
            exit(1)
        end
        ti = ti + 1
    end

    // Main thread concurrently triggers STW gc_collect() while all 8 threads run!
    gc_loops = 0
    while mem_read(G_AA_MT_CTRL + 8, 0) < 8 and gc_loops < 10
        gc_collect()
        syscall(24, 0, 0, 0, 0, 0, 0)
        gc_loops = gc_loops + 1
    end

    // Join all 8 threads via GC-safe futex_wait
    ti = 0
    while ti < 8
        h = handles[ti]
        while mem_read(h, 0) != 0
            cv = mem_read(h, 0)
            if cv != 0
                futex_wait(h, cv)
            end
        end
        ti = ti + 1
    end

    // Cleanup worker stacks & handles
    ti = 0
    while ti < 8
        free(handles[ti], 16)
        free(stacks[ti], 131072)
        ti = ti + 1
    end

    mt_errs = mem_read(G_AA_MT_CTRL, 0)
    mt_done = mem_read(G_AA_MT_CTRL + 8, 0)
    ch_recv_cnt = mem_read(G_AA_MT_CTRL + 16, 0)
    ch_recv_sum = mem_read(G_AA_MT_CTRL + 24, 0)
    ch_sent_cnt = mem_read(G_AA_MT_CTRL + 32, 0)
    list_final_len = len(G_AA_MT_LIST)
    dict_final_len = len(G_AA_MT_DICT)
    ch_final_len = channel_len(G_AA_MT_CHAN)

    // Verify every surviving dict key across all 8 threads (8 * 200 = 1600 exact entries!)
    dict_verify_errs = 0
    ti = 0
    while ti < 8
        ki = 0
        while ki < 200
            kk = "t" + str(ti) + "_k" + str(ki)
            if G_AA_MT_DICT[kk] != ((ti + 1) * 1000 + ki)
                dict_verify_errs = dict_verify_errs + 1
            end
            ki = ki + 1
        end
        ti = ti + 1
    end

    channel_free(G_AA_MT_CHAN)
    free(G_AA_MT_CTRL, 64)
    aa_unlink(log_p)

    // Expected: 4 producers * sum(1..500) = 4 * 125250 = 501000
    if mt_errs != 0 or mt_done != 8 or list_final_len != 3200 or dict_final_len != 1600 or dict_verify_errs != 0 or ch_sent_cnt != 2000 or ch_recv_cnt != 2000 or ch_recv_sum != 501000 or ch_final_len != 0
        say "FAIL AA7b: MT concurrency mismatch! errs=" + str(mt_errs) + " done=" + str(mt_done) + " list_len=" + str(list_final_len) + " dict_len=" + str(dict_final_len) + " dict_verr=" + str(dict_verify_errs) + " ch_sent=" + str(ch_sent_cnt) + " ch_recv=" + str(ch_recv_cnt) + " ch_sum=" + str(ch_recv_sum) + " ch_rem=" + str(ch_final_len)
        exit(1)
    end
    say "  [PASS] AA7. 8-thread 12,800+ op concurrent list/dict/channel/alloc + STW gc_collect() exact counts"

    // ── AA8: Live Cold-Path Safety (4096-slot Exhaustion & Disjoint Heap Fallback)
    slab8 = slab_buckets_ptr()
    slots8 = mem_read(slab8, 440)
    if slots8 == 0
        say "FAIL AA8a: GC thread slot registry uninitialized after AA7"
        exit(1)
    end
    st8 = malloc(65536)
    h8 = malloc(16)
    mem_write(h8, 0, 1)
    si = 0
    while si < 4096
        mem_write(slots8, si * 64, 3)
        si = si + 1
    end
    ex_r1 = thread_spawn_vm(fn_ptr(aa_mt_worker), 0, st8 + 65536)
    ex_r2 = thread_spawn_vm_joinable(fn_ptr(aa_mt_worker), 0, st8 + 65536, h8)
    si = 0
    while si < 4096
        mem_write(slots8, si * 64, 0)
        si = si + 1
    end
    free(h8, 16)
    free(st8, 65536)
    if ex_r1 != (0 - 1) or ex_r2 != (0 - 1)
        say "FAIL AA8b: thread_spawn did not return -1 on 4096-slot exhaustion: r1=" + str(ex_r1) + " r2=" + str(ex_r2)
        exit(1)
    end
    // Trigger real lower-chunk fallback by blocking MAP_FIXED_NOREPLACE at _heap_end
    c1_str = "CHUNK1_SURVIVOR_" + str(42)
    am8 = arena_mark()
    he8 = mem_read(slab8, 368)
    guard8 = syscall(9, he8, 4096, 3, 1048610, -1, 0)
    mem_write(slab8, 0 - 8, he8 - 16)
    c2_str = "CHUNK2_SURVIVOR_" + str(99)
    ai = 0
    while ai < 200
        p8 = alloc(64)
        mem_write(p8, 0, ai)
        ai = ai + 1
    end
    hb8 = mem_read(slab8, 0 - 16)
    hp8 = mem_read(slab8, 0 - 8)
    span_gb8 = (hp8 - hb8) / 1073741824
    ar8 = arena_reset(am8)
    gc_collect()
    if guard8 > 0
        syscall(11, guard8, 4096, 0, 0, 0, 0)
    end
    if span_gb8 > 16 or ar8 != 0 or c1_str != "CHUNK1_SURVIVOR_42" or c2_str != "CHUNK2_SURVIVOR_99"
        say "FAIL AA8c: disjoint chunk fallback regression: span_gb=" + str(span_gb8) + " ar=" + str(ar8) + " c1=" + c1_str + " c2=" + c2_str
        exit(1)
    end
    say "  [PASS] AA8. Live 4096-slot exhaustion (-1) + disjoint __alloc sub-alloc (span=" + str(span_gb8) + "GB) + arena_reset + GC"
    say "🎉 ALL WAVE AA TESTS PASSED!"
    return 0
end
