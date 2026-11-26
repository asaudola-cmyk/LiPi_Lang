// ==============================================================================
// Wave R Sovereign Regression Suite (Round 2 End-to-End Verification):
//   1. `lipi link` object-order independence (`a.o b.o` == `b.o a.o`, `--entry`)
//   2. `#![strict]` module directive & `#[strict]` per-function directive
//   3. `async fn` / `await`, cooperative `async_yield`, GC inside fiber,
//      Linux pipe + `async_wait_fd` epoll wakeup (zero RWX)
//   4. Inter-procedural `--strict-ownership` consuming wrapper propagation
//   5. `utso/collections` + `utso/hashmap` + native `DICT0` zero collision
//   6. `@bss` GC root survival + MT GC concurrent futex wakeup Dekker fix
//   7. WASM `--freestanding` (0 WASI imports) & Mach-O ARM64 (`LC_SYMTAB`, `-ENOSYS`)
//   8. RV64 live `--run-rv64` (`dyn_tagged`, `NullDeref`, `LSYM0` `stack_trace()`)
//      & ARM64 `LSYM0` binary table verification
//   9. Expanded `--ssa-codegen` (floats/strings/structs/calls/NullDeref) &
//      3-dialect lexer canonical normalization (English == Bengali == `@`-directive)
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/collections"
import "utso/hashmap"
include "utso/os/thread.lp"
include "src/compiler/frontend/lexer/tokenizer.lp"

@bss wr_bss_roots 64
@bss wr_mt_state 64
@bss wr_big_bss 131072

// ── Helper: Spawn process capturing stdout+stderr into a file ─────────────────
fn wr_spawn cmd_path args log_path
    argv = syscall(9, 0, 128, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 14
        mem_word_write(argv, (i + 1) * 8, args[i])
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(env, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
    mem_word_write(env, 8, 0)

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
        syscall(59, cmd_path, argv, env, 0, 0, 0)
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
    syscall(11, argv, 128, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc

fn wr_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0

fn wr_read_u32_le buf off
    b0 = mem_byte_read(buf, off)
    b1 = mem_byte_read(buf, off + 1)
    b2 = mem_byte_read(buf, off + 2)
    b3 = mem_byte_read(buf, off + 3)
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

fn wr_read_raw_file path sz_out_box
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        list_set(sz_out_box, 0, 0)
        return 0
    end
    fsize = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if fsize <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        list_set(sz_out_box, 0, 0)
        return 0
    end
    buf = malloc(fsize + 8)
    got = 0
    while got < fsize
        n = syscall(0, fd, buf + got, fsize - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    list_set(sz_out_box, 0, got)
    return buf

// ── Item 3: Native async fn / await / yield / GC / epoll pipe ────────────────
async fn wr_async_double x
    return x * 2

async fn wr_async_nested x
    v = await wr_async_double(x)
    return v + 100

async fn wr_coop_worker base trace_list
    i = 0
    while i < 3
        push(trace_list, base + i)
        if i == 1
            gc_collect()
        end
        async_yield()
        i = i + 1
    end
    return base

async fn wr_pipe_reader rfd
    async_wait_fd(rfd, 1)
    rbuf = malloc(16)
    mem_fill(rbuf, 0, 16)
    syscall(0, rfd, rbuf, 8, 0, 0, 0)
    val = mem_read(rbuf, 0)
    free(rbuf, 16)
    return val

async fn wr_pipe_writer wfd payload
    async_yield()
    wbuf = malloc(16)
    mem_write(wbuf, 0, payload)
    syscall(1, wfd, wbuf, 8, 0, 0, 0)
    free(wbuf, 16)
    return 1

async fn wr_gc_io_waiter rfd out_box
    local_s = "FIBER_GC_ROOT_" + str(777)
    async_wait_fd(rfd, 1)
    rb = malloc(16)
    syscall(0, rfd, rb, 1, 0, 0, 0)
    free(rb, 16)
    list_set(out_box, 0, local_s)
    return 100

async fn wr_gc_stressor wfd
    si = 0
    while si < 30
        tmp = "OVERWRITE_ASYNC_HEAP_" + str(si)
        if (si % 5) == 0
            gc_collect()
            async_yield()
        end
        si = si + 1
    end
    wb = malloc(16)
    mem_byte_write(wb, 0, 88)
    syscall(1, wfd, wb, 1, 0, 0, 0)
    free(wb, 16)
    return 200

async fn wr_nested_epoll_parent rfd
    ch = wr_pipe_reader(rfd)
    got = await ch
    return got + 50

async fn wr_async_boom x
    async_yield()
    if x == 1
        throw "wr_async_boom_err"
    end
    return x * 2

// ── Item 6: Concurrent MT GC futex wakeup worker (tests Dekker IN_SYSCALL->RUNNING race fix) ──
fn wr_mt_worker wid
    iters = 0
    while iters < 20
        if mem_read(wr_mt_state, 0) == 0
            futex_wait(wr_mt_state, 0)
        end
        s = "MT_STR_" + str(wid) + "_" + str(iters)
        if len(s) > 0
            atomic_add(wr_mt_state + 8, 1)
        end
        iters = iters + 1
    end
    atomic_add(wr_mt_state + 16, 1)
    return 0

// ── Item 9b: 3-dialect token-kind extractor ──────────────────────────────────
fn wr_lex_kinds src
    ts = tokenize_source(src)
    out = ""
    i = 0
    while i < ts.len()
        t = ts[i]
        if t.tok_kind != TOK_NEWLINE() and t.tok_kind != TOK_EOF()
            if len(out) > 0 out = out + "," end
            out = out + str(t.tok_kind)
        end
        i = i + 1
    end
    return out

fn main
    compiler = "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        compiler = "bin/lipc_bin"
    end

    // ── 1. lipi link object-order independence & --entry ──────────────────────
    file_write("/tmp/lipi_wr_a.lp", "fn ext_add x y\n    return x + y\n")
    file_write("/tmp/lipi_wr_b.lp", "extern fn ext_add(x, y)\nfn main\n    say ext_add(100, 23)\n")
    if wr_spawn(compiler, ["-c", "/tmp/lipi_wr_a.lp", "/tmp/lipi_wr_a.o"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1a compile a.o"
        exit(1)
    end
    if wr_spawn(compiler, ["-c", "/tmp/lipi_wr_b.lp", "/tmp/lipi_wr_b.o"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1b compile b.o"
        exit(1)
    end
    if wr_spawn(compiler, ["link", "/tmp/lipi_wr_a.o", "/tmp/lipi_wr_b.o", "-o", "/tmp/lipi_wr_ab"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1c link a.o b.o"
        exit(1)
    end
    if wr_spawn(compiler, ["link", "/tmp/lipi_wr_b.o", "/tmp/lipi_wr_a.o", "-o", "/tmp/lipi_wr_ba"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1d link b.o a.o"
        exit(1)
    end
    rc_ab = wr_spawn("/tmp/lipi_wr_ab", [], "/tmp/lipi_wr_out1.txt")
    rc_ba = wr_spawn("/tmp/lipi_wr_ba", [], "/tmp/lipi_wr_out2.txt")
    out_ab = file_read("/tmp/lipi_wr_out1.txt")
    out_ba = file_read("/tmp/lipi_wr_out2.txt")
    if rc_ab != 0 or rc_ba != 0 or out_ab != "123\n" or out_ba != "123\n"
        say "FAIL R1e link object-order output mismatch"
        exit(1)
    end
    rc_bad_entry = wr_spawn(compiler, ["link", "/tmp/lipi_wr_a.o", "/tmp/lipi_wr_b.o", "--entry=no_such_entry", "-o", "/tmp/lipi_wr_bad"], "/tmp/lipi_wr_log.txt")
    if rc_bad_entry == 0
        say "FAIL R1f nonexistent --entry must reject"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_a.lp")
    wr_unlink("/tmp/lipi_wr_b.lp")
    wr_unlink("/tmp/lipi_wr_a.o")
    wr_unlink("/tmp/lipi_wr_b.o")
    wr_unlink("/tmp/lipi_wr_ab")
    wr_unlink("/tmp/lipi_wr_ba")
    wr_unlink("/tmp/lipi_wr_bad")

    // R1g: Multi-.o cross-object @bss & mutable global isolation in both link orders
    file_write("/tmp/lipi_wr_ba.lp", "@bss buf_a: [64]u8\nglobal g_la = 0\nfn set_la v\n    mem_write(buf_a, 0, v)\n    g_la = v + 1\n    return 0\nend\nfn get_la\n    return mem_read(buf_a, 0) + g_la\nend\n")
    file_write("/tmp/lipi_wr_bb.lp", "extern fn set_la(v)\nextern fn get_la()\n@bss buf_b: [64]u8\nglobal g_lb = 0\nfn main\n    set_la(1111)\n    mem_write(buf_b, 0, 2222)\n    g_lb = 2223\n    say get_la()\n    say mem_read(buf_b, 0) + g_lb\n    return 0\nend\n")
    if wr_spawn(compiler, ["-c", "/tmp/lipi_wr_ba.lp", "/tmp/lipi_wr_ba.o"], "/tmp/lipi_wr_log.txt") != 0 or wr_spawn(compiler, ["-c", "/tmp/lipi_wr_bb.lp", "/tmp/lipi_wr_bb.o"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1g1 compile @bss .o"
        exit(1)
    end
    if wr_spawn(compiler, ["link", "/tmp/lipi_wr_ba.o", "/tmp/lipi_wr_bb.o", "-o", "/tmp/lipi_wr_bss1"], "/tmp/lipi_wr_log.txt") != 0 or wr_spawn(compiler, ["link", "/tmp/lipi_wr_bb.o", "/tmp/lipi_wr_ba.o", "-o", "/tmp/lipi_wr_bss2"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R1g2 link @bss .o"
        exit(1)
    end
    if wr_spawn("/tmp/lipi_wr_bss1", [], "/tmp/lipi_wr_out1.txt") != 0 or wr_spawn("/tmp/lipi_wr_bss2", [], "/tmp/lipi_wr_out2.txt") != 0
        say "FAIL R1g3 run @bss linked"
        exit(1)
    end
    if file_read("/tmp/lipi_wr_out1.txt") != "2223\n4445\n" or file_read("/tmp/lipi_wr_out2.txt") != "2223\n4445\n"
        say "FAIL R1g4 multi-.o @bss/global isolation mismatch"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_ba.lp")
    wr_unlink("/tmp/lipi_wr_bb.lp")
    wr_unlink("/tmp/lipi_wr_ba.o")
    wr_unlink("/tmp/lipi_wr_bb.o")
    wr_unlink("/tmp/lipi_wr_bss1")
    wr_unlink("/tmp/lipi_wr_bss2")

    // ── 2. #![strict] & #[strict] directives ─────────────────────────────────
    file_write("/tmp/lipi_wr_strict_ok.lp", "#![strict]\nfn main\n    b = malloc(16)\n    mem_byte_write(b, 0, 42)\n    v = mem_byte_read(b, 0)\n    free(b)\n    say v\n")
    if wr_spawn(compiler, ["/tmp/lipi_wr_strict_ok.lp", "/tmp/lipi_wr_strict_ok"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R2a #![strict] valid program compile"
        exit(1)
    end
    if wr_spawn("/tmp/lipi_wr_strict_ok", [], "/tmp/lipi_wr_out1.txt") != 0 or file_read("/tmp/lipi_wr_out1.txt") != "42\n"
        say "FAIL R2b #![strict] valid program run"
        exit(1)
    end
    file_write("/tmp/lipi_wr_strict_uaf.lp", "#![strict]\nfn main\n    b = malloc(16)\n    free(b)\n    say mem_byte_read(b, 0)\n")
    if wr_spawn(compiler, ["/tmp/lipi_wr_strict_uaf.lp", "/tmp/lipi_wr_strict_uaf"], "/tmp/lipi_wr_log.txt") == 0
        say "FAIL R2c #![strict] failed to reject UAF"
        exit(1)
    end
    file_write("/tmp/lipi_wr_fn_strict.lp", "#[strict]\nfn leaky\n    b = malloc(16)\n    return 0\nfn main\n    leaky()\n")
    if wr_spawn(compiler, ["/tmp/lipi_wr_fn_strict.lp", "/tmp/lipi_wr_fn_strict"], "/tmp/lipi_wr_log.txt") == 0
        say "FAIL R2d #[strict] failed to reject per-fn leak"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_strict_ok.lp")
    wr_unlink("/tmp/lipi_wr_strict_ok")
    wr_unlink("/tmp/lipi_wr_strict_uaf.lp")
    wr_unlink("/tmp/lipi_wr_fn_strict.lp")

    // ── 3. async fn / await + cooperative yield + GC + epoll pipe ────────────
    if (await wr_async_nested(21)) != 142
        say "FAIL R3a nested async/await"
        exit(1)
    end
    tr = list()
    t1 = wr_coop_worker(10, tr)
    t2 = wr_coop_worker(20, tr)
    await t1
    await t2
    if tr.len() != 6 or tr[0] != 10 or tr[1] != 20 or tr[2] != 11 or tr[3] != 21 or tr[4] != 12 or tr[5] != 22
        say "FAIL R3b cooperative async_yield interleaving"
        exit(1)
    end
    pfds = malloc(16)
    mem_fill(pfds, 0, 16)
    if syscall(22, pfds, 0, 0, 0, 0, 0) != 0
        say "FAIL R3c pipe syscall"
        exit(1)
    end
    rfd = wr_read_u32_le(pfds, 0)
    wfd = wr_read_u32_le(pfds, 4)
    free(pfds, 16)
    rt = wr_pipe_reader(rfd)
    wt = wr_pipe_writer(wfd, 4155)
    got_p = await rt
    await wt
    syscall(3, rfd, 0, 0, 0, 0, 0)
    syscall(3, wfd, 0, 0, 0, 0, 0)
    if got_p != 4155
        say "FAIL R3d epoll async_wait_fd pipe"
        exit(1)
    end

    // R3e: Multi-stack GC root survival across epoll-blocked fiber + suspended main stack
    main_live_s = "MAIN_ASYNC_ROOT_" + str(555)
    fiber_out_b = [""]
    pfds2 = malloc(16)
    mem_fill(pfds2, 0, 16)
    syscall(22, pfds2, 0, 0, 0, 0, 0)
    rfd2 = wr_read_u32_le(pfds2, 0)
    wfd2 = wr_read_u32_le(pfds2, 4)
    free(pfds2, 16)
    fw_gc = wr_gc_io_waiter(rfd2, fiber_out_b)
    fs_gc = wr_gc_stressor(wfd2)
    sr_gc = await fs_gc
    wr_gc = await fw_gc
    syscall(3, rfd2, 0, 0, 0, 0, 0)
    syscall(3, wfd2, 0, 0, 0, 0, 0)
    if main_live_s != "MAIN_ASYNC_ROOT_555" or fiber_out_b[0] != "FIBER_GC_ROOT_777" or (sr_gc + wr_gc) != 300
        say "FAIL R3e async+GC+epoll root survival"
        exit(1)
    end

    // R3f: Nested await over epoll-blocked child fiber (must suspend on waiter_head, never livelock)
    pfds3 = malloc(16)
    mem_fill(pfds3, 0, 16)
    syscall(22, pfds3, 0, 0, 0, 0, 0)
    rfd3 = wr_read_u32_le(pfds3, 0)
    wfd3 = wr_read_u32_le(pfds3, 4)
    free(pfds3, 16)
    fp_n = wr_nested_epoll_parent(rfd3)
    fw_n = wr_pipe_writer(wfd3, 700)
    await fw_n
    got_n = await fp_n
    syscall(3, rfd3, 0, 0, 0, 0, 0)
    syscall(3, wfd3, 0, 0, 0, 0, 0)
    if got_n != 750
        say "FAIL R3f nested await over epoll child"
        exit(1)
    end

    // R3g: Exception thrown inside async fn cleanly caught + GC + subsequent await succeeds
    caught_async = ""
    try
        await wr_async_boom(1)
    catch ae
        caught_async = ae
    end
    gc_collect()
    after_boom = await wr_async_boom(21)
    if caught_async != "wr_async_boom_err" or after_boom != 42
        say "FAIL R3g async exception isolation + recovery"
        exit(1)
    end

    // ── 4. Inter-procedural --strict-ownership consuming wrapper ─────────────
    file_write("/tmp/lipi_wr_own_bad.lp", "fn my_free p\n    free(p)\nfn main\n    b = malloc(16)\n    my_free(b)\n    say mem_byte_read(b, 0)\n")
    if wr_spawn(compiler, ["--strict-ownership", "/tmp/lipi_wr_own_bad.lp", "/tmp/lipi_wr_own_bad"], "/tmp/lipi_wr_log.txt") == 0
        say "FAIL R4a --strict-ownership did not catch freeing wrapper UAF"
        exit(1)
    end
    file_write("/tmp/lipi_wr_own_ok.lp", "fn touch_buf p\n    mem_byte_write(p, 0, 77)\nfn main\n    b = malloc(16)\n    touch_buf(b)\n    v = mem_byte_read(b, 0)\n    free(b)\n    say v\n")
    if wr_spawn(compiler, ["--strict-ownership", "/tmp/lipi_wr_own_ok.lp", "/tmp/lipi_wr_own_ok"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R4b --strict-ownership falsely rejected borrowing helper"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_own_bad.lp")
    wr_unlink("/tmp/lipi_wr_own_ok.lp")
    wr_unlink("/tmp/lipi_wr_own_ok")
    // R4c: Branch reassignment inside consuming helper must still flag caller UAF
    file_write("/tmp/lipi_wr_own_4c.lp", "fn wf p c\n    if c == 1\n        p = 0\n    end\n    free(p)\nfn main\n    b = malloc(16)\n    wf(b, 0)\n    say mem_byte_read(b, 0)\n")
    if wr_spawn(compiler, ["--strict-ownership", "/tmp/lipi_wr_own_4c.lp", "/tmp/lipi_wr_own_4c"], "/tmp/lipi_wr_log.txt") == 0
        say "FAIL R4c --strict-ownership missed branch-reassigned consuming wrapper"
        exit(1)
    end
    // R4d: Symmetric order-independent aliasing check wf(x, x) when second param consumes
    file_write("/tmp/lipi_wr_own_4h.lp", "fn wf a b\n    free(b)\nfn main\n    x = malloc(16)\n    wf(x, x)\n")
    if wr_spawn(compiler, ["--strict-ownership", "/tmp/lipi_wr_own_4h.lp", "/tmp/lipi_wr_own_4h"], "/tmp/lipi_wr_log.txt") == 0
        say "FAIL R4d --strict-ownership missed aliased second-arg consumption"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_own_4c.lp")
    wr_unlink("/tmp/lipi_wr_own_4h.lp")

    // ── 5. utso/collections + utso/hashmap + native DICT0 zero collision ─────
    dm = map_new()
    map_set(dm, "alpha", 100)
    map_set(dm, "beta", 200)
    hm = hashmap_new()
    hashmap_set(hm, "k1", 300)
    hashmap_set(hm, "k2", 240)
    hashmap_remove(hm, "k2")
    raw_hm = hashmap_create(16)
    hashmap_insert(raw_hm, 16, 42, 540)
    raw_v = hashmap_lookup(raw_hm, 16, 42)
    hashmap_free(raw_hm, 16)
    if map_get(dm, "alpha") != 100 or hashmap_get(hm, "k1") != 300 or hashmap_has(hm, "k2") != 0 or raw_v != 540
        say "FAIL R5 collections/hashmap/DICT0 unification"
        exit(1)
    end
    // R5b: Native DICT0 passed directly to utso/hashmap.lp:hashmap_delete ("LIPDICT0" magic check)
    nd = dict()
    nd["d1"] = 11
    nd["d2"] = 22
    hashmap_delete(nd, "d1")
    if has_key(nd, "d1") != 0 or has_key(nd, "d2") != 1 or nd["d2"] != 22
        say "FAIL R5b hashmap_delete DICT0 LIPDICT0 magic guard"
        exit(1)
    end

    // ── 6. @bss GC root survival + concurrent MT GC futex wakeup ─────────────
    bss_s = "WAVE_R_BSS_" + str(98765)
    mem_write(wr_bss_roots, 0, bss_s)
    bss_s = 0
    gi = 0
    while gi < 300
        tmp_g = "GARBAGE_FILL_" + str(gi)
        gi = gi + 1
    end
    gc_collect()
    gc_collect()
    recovered = mem_read(wr_bss_roots, 0)
    if recovered != "WAVE_R_BSS_98765"
        say "FAIL R6a @bss GC root survival"
        exit(1)
    end
    mem_write(wr_bss_roots, 0, 0)

    // R6c: Bare-size 128KB @bss wr_big_bss 131072 tail slot GC root survival
    big_s = "BIG_BSS_TAIL_" + str(131064)
    mem_write(wr_big_bss, 131064, big_s)
    big_s = 0
    gc_collect()
    if mem_read(wr_big_bss, 131064) != "BIG_BSS_TAIL_131064"
        say "FAIL R6c bare-size 128KB @bss tail GC root survival"
        exit(1)
    end
    mem_write(wr_big_bss, 131064, 0)

    // 4-thread futex wakeup + 20x STW GC stress
    mem_write(wr_mt_state, 0, 0)
    mem_write(wr_mt_state, 8, 0)
    mem_write(wr_mt_state, 16, 0)
    mt_stacks = list()
    mt_handles = list()
    ti = 0
    while ti < 4
        stk = malloc(65536)
        hdl = malloc(16)
        mem_write(hdl, 0, 1)
        push(mt_stacks, stk)
        push(mt_handles, hdl)
        thread_spawn_vm_joinable(fn_ptr(wr_mt_worker), ti, stk + 65536, hdl)
        ti = ti + 1
    end
    mem_write(wr_mt_state, 0, 1)
    futex_wake(wr_mt_state, 4)
    gc_i = 0
    while gc_i < 20
        gc_collect()
        gc_i = gc_i + 1
    end
    ti = 0
    while ti < 4
        h = mt_handles[ti]
        while mem_read(h, 0) != 0
            cv = mem_read(h, 0)
            if cv != 0 futex_wait(h, cv) end
        end
        free(mt_stacks[ti], 65536)
        free(mt_handles[ti], 16)
        ti = ti + 1
    end
    if mem_read(wr_mt_state, 8) != 80 or mem_read(wr_mt_state, 16) != 4
        say "FAIL R6b MT GC futex wakeup count mismatch"
        exit(1)
    end

    // ── 7a. WASM --freestanding (zero Import section ID=2) ───────────────────
    file_write("/tmp/lipi_wr_wasm.lp", "fn add a b\n    return a + b\nfn main\n    return add(19, 23)\n")
    if wr_spawn(compiler, ["--target=wasm", "--freestanding", "/tmp/lipi_wr_wasm.lp", "/tmp/lipi_wr_wasm.wasm"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R7a WASM --freestanding compile"
        exit(1)
    end
    wsz_b = [0]
    wbuf = wr_read_raw_file("/tmp/lipi_wr_wasm.wasm", wsz_b)
    wsz = wsz_b[0]
    if wbuf == 0 or wsz < 16 or wr_read_u32_le(wbuf, 0) != 1836278016
        say "FAIL R7b WASM magic"
        exit(1)
    end
    // Walk WASM sections starting at offset 8 and assert NO section ID 2 (Import)
    wpos = 8
    has_import_sec = 0
    while wpos < wsz
        sec_id = mem_byte_read(wbuf, wpos)
        wpos = wpos + 1
        if sec_id == 2
            has_import_sec = 1
        end
        // Decode unsigned LEB128 section size
        sec_len = 0
        sh = 0
        while wpos < wsz
            lb = mem_byte_read(wbuf, wpos)
            wpos = wpos + 1
            sec_len = sec_len | ((lb & 127) << sh)
            if (lb & 128) == 0 break end
            sh = sh + 7
        end
        wpos = wpos + sec_len
    end
    free(wbuf, wsz + 8)
    wr_unlink("/tmp/lipi_wr_wasm.lp")
    wr_unlink("/tmp/lipi_wr_wasm.wasm")
    if has_import_sec != 0
        say "FAIL R7c WASM --freestanding emitted WASI import section"
        exit(1)
    end

    // ── 7b. Mach-O ARM64 (LC_SYMTAB + LC_DYSYMTAB + LC_BUILD_VERSION + -ENOSYS)
    file_write("/tmp/lipi_wr_macho.lp", "fn main\n    r = syscall(318, 0, 0, 0, 0, 0, 0)\n    return r\n")
    if wr_spawn(compiler, ["--target=macos-arm64", "/tmp/lipi_wr_macho.lp", "/tmp/lipi_wr_macho.bin"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R7d Mach-O ARM64 compile"
        exit(1)
    end
    msz_b = [0]
    mbuf = wr_read_raw_file("/tmp/lipi_wr_macho.bin", msz_b)
    msz = msz_b[0]
    if mbuf == 0 or msz < 64 or wr_read_u32_le(mbuf, 0) != 4277009103
        say "FAIL R7e Mach-O MH_MAGIC_64"
        exit(1)
    end
    ncmds = wr_read_u32_le(mbuf, 16)
    moff = 32
    has_symtab = 0
    has_dysym = 0
    has_bver = 0
    text_off = 0
    text_sz = 0
    lci = 0
    while lci < ncmds and moff + 8 <= msz
        cmd = wr_read_u32_le(mbuf, moff)
        csz = wr_read_u32_le(mbuf, moff + 4)
        if cmd == 2 has_symtab = 1 end
        if cmd == 11 has_dysym = 1 end
        if cmd == 50 has_bver = 1 end
        if cmd == 25 and csz >= 152 and text_sz == 0
            // Check segname == "__TEXT" (95, 95, 84, 69, 88, 84)
            if mem_byte_read(mbuf, moff + 8) == 95 and mem_byte_read(mbuf, moff + 10) == 84 and mem_byte_read(mbuf, moff + 11) == 69
                text_sz = wr_read_u32_le(mbuf, moff + 112)
                text_off = wr_read_u32_le(mbuf, moff + 120)
            end
        end
        if csz < 8 break end
        moff = moff + csz
        lci = lci + 1
    end
    // Scan __TEXT.__text for MOVN X0, #77 (-ENOSYS = 0x928009A0 = 2457864608) & zero Linux SVC #0
    found_enosys = 0
    found_linux_svc = 0
    scan_off = text_off
    scan_end = text_off + text_sz
    while scan_off + 4 <= scan_end and scan_off + 4 <= msz
        ins = wr_read_u32_le(mbuf, scan_off)
        if ins == 2457864608 found_enosys = 1 end
        if ins == 3556769793 found_linux_svc = 1 end // SVC #0 (0xD4000001)
        scan_off = scan_off + 4
    end
    free(mbuf, msz + 8)
    wr_unlink("/tmp/lipi_wr_macho.lp")
    wr_unlink("/tmp/lipi_wr_macho.bin")
    if text_sz <= 0 or has_symtab != 1 or has_dysym != 1 or has_bver != 1 or found_enosys != 1 or found_linux_svc != 0
        say "FAIL R7f Mach-O hardening check"
        exit(1)
    end

    // ── 8. RV64 live dyn_tagged + NullDeref + LSYM0 stack_trace() & ARM64 LSYM0
    par_src = "struct Box\n    val: i64\nfn get_s m\n    return m[\"s\"]\nfn deref_null p: Box\n    return p.val\nfn inner_t\n    return stack_trace()\nfn outer_t\n    return inner_t()\nfn main\n    d = {\"s\": \"sovereign\", \"f\": 3.5}\n    say get_s(d)\n    say d[\"f\"]\n    try\n        x = deref_null(0)\n        say x\n    catch e\n        say e\n    end\n    say outer_t()\n"
    file_write("/tmp/lipi_wr_par.lp", par_src)
    if wr_spawn(compiler, ["--target=riscv64", "--run-rv64", "/tmp/lipi_wr_par.lp", "/tmp/lipi_wr_par.rv64"], "/tmp/lipi_wr_rv.txt") != 0
        say "FAIL R8a RV64 parity compile/run"
        exit(1)
    end
    rv_out = file_read("/tmp/lipi_wr_rv.txt")
    if str_contains(rv_out, "sovereign") != 1 or str_contains(rv_out, "3.5") != 1 or str_contains(rv_out, "NullPointerException") != 1 or str_contains(rv_out, "at inner_t") != 1 or str_contains(rv_out, "at outer_t") != 1 or str_contains(rv_out, "at main") != 1
        say "FAIL R8b RV64 parity output check"
        exit(1)
    end
    if wr_spawn(compiler, ["--target=arm64", "/tmp/lipi_wr_par.lp", "/tmp/lipi_wr_par.a64"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R8c ARM64 parity compile"
        exit(1)
    end
    asz_b = [0]
    abuf = wr_read_raw_file("/tmp/lipi_wr_par.a64", asz_b)
    asz = asz_b[0]
    found_lsym = 0
    ai = 0
    while ai + 12 <= asz
        if mem_byte_read(abuf, ai) == 76 and mem_byte_read(abuf, ai + 1) == 73 and mem_byte_read(abuf, ai + 2) == 80 and mem_byte_read(abuf, ai + 3) == 76 and mem_byte_read(abuf, ai + 4) == 83 and mem_byte_read(abuf, ai + 5) == 89 and mem_byte_read(abuf, ai + 6) == 77 and mem_byte_read(abuf, ai + 7) == 48
            fcnt = wr_read_u32_le(abuf, ai + 8)
            if fcnt >= 4
                found_lsym = 1
            end
            break
        end
        ai = ai + 1
    end
    free(abuf, asz + 8)
    wr_unlink("/tmp/lipi_wr_par.lp")
    wr_unlink("/tmp/lipi_wr_par.rv64")
    wr_unlink("/tmp/lipi_wr_par.a64")
    wr_unlink("/tmp/lipi_wr_rv.txt")
    if found_lsym != 1
        say "FAIL R8d ARM64 LIPLSYM0 table missing"
        exit(1)
    end

    // ── 9a. --ssa-codegen floats / strings / structs / div0 / dynamic ops ────
    ssa_src = "struct Vec2\n    x: i64\n    y: i64\nfn add_i a b\n    return a + b\nfn div_s a b\n    return a / b\nfn eq_s a b\n    if a == b return 1 end\n    return 0\nfn add_f a: f64 b: f64\n    return a + b\nfn scale_m n: i64 f: f64\n    r = n * f\n    return -r\nfn greet_s\n    return \"sovereign_ssa\"\nfn make_v a b\n    return Vec2(a, b)\nfn move_sum v: Vec2 dx dy\n    v.x = v.x + dx\n    v.y = v.y + dy\n    return add_i(v.x, v.y)\nfn main\n    say add_f(1.5, 2.25)\n    say scale_m(4, 2.5)\n    say greet_s()\n    say add_i(\"hello_\", \"ssa\")\n    say eq_s(\"abc\", \"abc\")\n    say eq_s(\"abc\", \"xyz\")\n    try\n        say div_s(10, 0)\n    catch e\n        say \"div0_ok\"\n    end\n    p = make_v(10, 20)\n    say move_sum(p, 5, 7)\n    try\n        say move_sum(0, 1, 2)\n    catch e2\n        say \"npe_ok\"\n    end\n"
    file_write("/tmp/lipi_wr_ssa.lp", ssa_src)
    if wr_spawn(compiler, ["/tmp/lipi_wr_ssa.lp", "/tmp/lipi_wr_ssa_d"], "/tmp/lipi_wr_log.txt") != 0
        say "FAIL R9a default compile"
        exit(1)
    end
    if wr_spawn(compiler, ["--ssa-codegen", "/tmp/lipi_wr_ssa.lp", "/tmp/lipi_wr_ssa_i"], "/tmp/lipi_wr_ssa_log.txt") != 0
        say "FAIL R9b --ssa-codegen compile"
        exit(1)
    end
    ssa_log = file_read("/tmp/lipi_wr_ssa_log.txt")
    if str_contains(ssa_log, "replaced 8/9 functions") != 1
        say "FAIL R9c --ssa-codegen replacement count"
        exit(1)
    end
    if wr_spawn("/tmp/lipi_wr_ssa_d", [], "/tmp/lipi_wr_out1.txt") != 0 or wr_spawn("/tmp/lipi_wr_ssa_i", [], "/tmp/lipi_wr_out2.txt") != 0
        say "FAIL R9d --ssa-codegen runtime"
        exit(1)
    end
    if file_read("/tmp/lipi_wr_out1.txt") != file_read("/tmp/lipi_wr_out2.txt")
        say "FAIL R9e --ssa-codegen output mismatch"
        exit(1)
    end
    wr_unlink("/tmp/lipi_wr_ssa.lp")
    wr_unlink("/tmp/lipi_wr_ssa_d")
    wr_unlink("/tmp/lipi_wr_ssa_i")
    wr_unlink("/tmp/lipi_wr_ssa_log.txt")

    // ── 9b. 3-dialect lexer canonical normalization + contextual variable names
    k_en = wr_lex_kinds("async fn a x\n try\n  if x > 0\n   defer say x\n   return x\n  else\n   return 0\n  end\n catch e\n end\nend\ntrait T\nend\nimpl T\nend\nenum E\nend\n")
    k_bn = wr_lex_kinds("অসমলয় কাজ a x\n চেষ্টা\n  যদি x > 0\n   বিলম্ব বলো x\n   ফেরত x\n  নাহলে\n   ফেরত 0\n  শেষ\n ধরো e\n শেষ\nশেষ\nবৈশিষ্ট্য T\nশেষ\nবাস্তবায়ন T\nশেষ\nগণনা E\nশেষ\n")
    k_at = wr_lex_kinds("@async @fn a x\n @try\n  @if x > 0\n   @defer @say x\n   @return x\n  @else\n   @return 0\n  @end\n @catch e\n @end\n@end\n@trait T\n@end\n@impl T\n@end\n@enum E\n@end\n")
    if k_en != k_bn or k_en != k_at
        say "FAIL R9f 3-dialect lexer normalization mismatch"
        exit(1)
    end
    trait = 42
    match = 7
    type = 3
    async = 5
    await = 6
    if (trait + match + type + async + await) != 63
        say "FAIL R9h contextual keyword variables broken"
        exit(1)
    end

    wr_unlink("/tmp/lipi_wr_log.txt")
    wr_unlink("/tmp/lipi_wr_out1.txt")
    wr_unlink("/tmp/lipi_wr_out2.txt")

    say "PASS_WAVE_R_ROUND2_SOVEREIGN_ALL_9_GATES"
    return 0
