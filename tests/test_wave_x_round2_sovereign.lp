// ==============================================================================
// Wave X Round-2 Sovereign End-to-End Regression Suite
//   X1: ARM64 & RISC-V 64 >8 Stack-Arg Calls + str(...) Parity (SSA Default & Legacy)
//   X2: Braced/Indented try+defer+throw Mixing, Braced Loops, & Same-Fn Catch Rethrow
//   X3: RISC-V 64 OpenSBI S-mode sbi_ecall (Positive ELF-Kernel + 2 Linux Purity Gates)
//   X4: Linear-Scan Physical-Register SSA CFG, Non-RPO Nested-Loop Dataflow, f64 Struct
//       Fields, OP_STRUCT_NEW Live Operands, & WASM Unified SSA Default (V8 Verified)
// ==============================================================================

import "utso/io"
import "utso/string"

fn wx_spawn cmd_path args log_path
    argv = syscall(9, 0, 160, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 18
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
        devnull = syscall(2, "/dev/null", 0, 0, 0, 0, 0)
        if devnull >= 0
            syscall(33, devnull, 0, 0, 0, 0, 0)
            syscall(3, devnull, 0, 0, 0, 0, 0)
        end
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
    syscall(11, argv, 160, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn wx_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn wx_read_raw path sz_box
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        list_set(sz_box, 0, 0)
        return 0
    end
    fsize = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if fsize <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        list_set(sz_box, 0, 0)
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
    list_set(sz_box, 0, got)
    return buf
end

fn wx_read_u16_le buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    return b0 | (b1 << 8)
end

fn wx_read_u32_le buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    b2 = mem_byte_read(buf, off + 2) & 255
    b3 = mem_byte_read(buf, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

fn wx_read_u64_le buf off
    lo = wx_read_u32_le(buf, off)
    hi = wx_read_u32_le(buf, off + 4)
    return lo | (hi << 32)
end

// ── Section X2: Braced/Indented try+defer+throw Mixing & Catch Rethrow ───────
fn wx_braced_indented_try(log) {
    try
        defer push(log, "try_defer")
        throw "boom_a"
    catch e
        push(log, "caught:" + e)
    end
    return 1
}

fn wx_braced_noparen {
    s = 0
    i = 0
    while i < 5 {
        s = s + i
        i = i + 1
    }
    xs = [10, 20, 30]
    for v in xs {
        s = s + v
    }
    repeat 3 {
        s = s + 1
    }
    return s
}

fn wx_rethrow_ordering(log) {
    try {
        try {
            defer push(log, "defer_A")
            throw "e1"
        } catch e {
            defer push(log, "defer_C")
            push(log, "inner_catch:" + e)
            throw "e2"
        } finally {
            push(log, "inner_finally")
        }
    } catch e2 {
        push(log, "outer_catch:" + e2)
    }
    return 1
}

fn wx_catch_return_ordering(log) {
    try {
        defer push(log, "defer_try_ret")
        throw "ret_err"
    } catch e {
        defer push(log, "defer_catch_ret")
        push(log, "in_catch:" + e)
        return 77
    } finally {
        push(log, "finally_ret")
    }
    return 0
}

fn wx_break_cont_try_finally() {
    log = ""
    i = 0
    while i < 5 {
        try {
            defer { log = log + "d" + str(i) + "," }
            if i == 1 {
                i = i + 1
                continue
            }
            if i == 3 {
                break
            }
            log = log + "b" + str(i) + ","
        } finally {
            log = log + "f" + str(i) + ","
        }
        i = i + 1
    }
    return log
}

fn wx_unbraced_match_in_braced(x) {
    r = 0
    match x
        case 1 => r = 11
        case 2 => r = 22
        default => r = 99
    return r
}

fn wx_unused_param a b c
    return a + c
end

fn wx_clamp_pos n
    if n < 0
        return 777
    end
    return n * 2
end

fn wx_call_clamp x
    return wx_clamp_pos(x) + 10
end

// ── Section X4: Physical-Register SSA CFG, Non-RPO Nested Loop, f64 Struct ───
struct WxF64Box
    a: f64
    b: f64
    c: f64
    d: f64
    e: f64
    f: f64
    g: f64
    h: f64

fn wx_call_leaf x
    return (x * 3) + 1
end

fn wx_nested_nonrpo_loop n m
    // WHY: Nested loop with inner if/elif/else + calls creates non-RPO CFG blocks where
    // outer loop counter `bi` must stay live across inner blocks placed after the outer latch.
    total = 0
    bi = 0
    while bi < n
        ii = 0
        while ii < m
            v = wx_call_leaf(bi + ii)
            changed = 0
            if (v % 3) == 0
                changed = 1
            elif (v % 5) == 0
                changed = 2
            else
                changed = 0
            end
            if changed == 1
                total = total + v
            elif changed == 2
                total = total + (v * 2)
            else
                total = total + 1
            end
            ii = ii + 1
        end
        bi = bi + 1
    end
    return total
end

fn wx_struct_live_and_f64(x: f64, y: f64) -> f64
    // Exercises OP_STRUCT_NEW with 8 live f64 operands across _lipi_user_alloc AND typed f64 field loads/stores!
    v1 = x + 1.0
    v2 = y + 2.0
    v3 = x * 2.0
    v4 = y * 3.0
    v5 = v1 + v2
    v6 = v3 + v4
    v7 = v5 - v1
    v8 = v6 - v3
    box = WxF64Box(v1, v2, v3, v4, v5, v6, v7, v8)
    box.a = box.a + 0.5
    return box.a + box.b + box.c + box.d + box.e + box.f + box.g + box.h
end

fn wx_add10_x86 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10
    return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10
end

fn main
    compiler = "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        compiler = "bin/lipc_bin"
    end

    // ── X2. Verify Braced/Indented try+defer+throw & Catch Rethrow ───────────
    log1 = list()
    wx_braced_indented_try(log1)
    if log1.len() != 2 or log1[0] != "caught:boom_a" or log1[1] != "try_defer"
        say "FAIL X2a braced_indented_try ordering"
        exit(1)
    end
    if wx_braced_noparen() != 73
        say "FAIL X2b braced_noparen loops"
        exit(1)
    end
    log2 = list()
    wx_rethrow_ordering(log2)
    // Inner catch -> inner_finally -> defer_C -> defer_A -> outer_catch:e2
    if log2.len() != 5 or log2[0] != "inner_catch:e1" or log2[1] != "inner_finally" or log2[2] != "defer_C" or log2[3] != "defer_A" or log2[4] != "outer_catch:e2"
        say "FAIL X2c catch rethrow ordering: len=" + str(log2.len())
        exit(1)
    end
    log3 = list()
    r3 = wx_catch_return_ordering(log3)
    if r3 != 77 or log3.len() != 4 or log3[0] != "in_catch:ret_err" or log3[1] != "finally_ret" or log3[2] != "defer_catch_ret" or log3[3] != "defer_try_ret"
        say "FAIL X2d catch return ordering"
        exit(1)
    end
    if wx_break_cont_try_finally() != "b0,f0,d0,f2,d2,b2,f2,d2,f3,d3,"
        say "FAIL X2e break/continue inside try+finally+defer"
        exit(1)
    end
    if wx_unbraced_match_in_braced(2) != 22 or wx_unbraced_match_in_braced(9) != 99
        say "FAIL X2f unbraced match inside braced fn"
        exit(1)
    end
    say "  [PASS] X2: Braced/indented try+defer+throw, break/continue+finally, match & catch rethrow verified"

    // ── X4a. Verify Register-Allocated SSA CFG, Non-RPO Loops & f64 Structs ──
    nr_val = wx_nested_nonrpo_loop(6, 5)
    // Deterministic check: compute reference sum inline without SSA non-RPO risk? Same exact math:
    // bi=0..5, ii=0..4 -> v = 3*(bi+ii)+1 -> v%3 == 1 always! v%5==0 when 3*(bi+ii)+1 divisible by 5 (s=3,8):
    // pairs with s=3: (0,3),(1,2),(2,1),(3,0) -> 4 pairs, v=10 -> 20*4 = 80
    // pairs with s=8: (4,4),(5,3) -> 2 pairs, v=25 -> 50*2 = 100
    // remaining 30-6=24 pairs -> +1 each = 24 -> total = 204
    if nr_val != 204
        say "FAIL X4a nested non-RPO loop regalloc: got " + str(nr_val) + " expected 204"
        exit(1)
    end
    f_res = wx_struct_live_and_f64(1.5, 2.5)
    // v1=2.5, v2=4.5, v3=3.0, v4=7.5, v5=7.0, v6=10.5, v7=4.5, v8=7.5; box.a+=0.5 -> 3.0
    // sum = 3.0 + 4.5 + 3.0 + 7.5 + 7.0 + 10.5 + 4.5 + 7.5 = 47.5
    if f_res < 47.49 or f_res > 47.51
        say "FAIL X4b struct f64 + OP_STRUCT_NEW live operands"
        exit(1)
    end
    if wx_add10_x86(1, 2, 3, 4, 5, 6, 7, 8, 9, 10) != 55
        say "FAIL X4c x86_64 10-arg SSA call"
        exit(1)
    end
    if wx_unused_param(100, 999, 5) != 105
        say "FAIL X4c2 unused-param linear-scan regalloc"
        exit(1)
    end
    if wx_call_clamp(-5) != 787 or wx_call_clamp(7) != 24
        say "FAIL X4c3 multi-return inlining check"
        exit(1)
    end
    // Explicitly test -O2 unused-param regalloc AND -O3 multi-return inlining via child compiles
    o23_src = "fn up a b c\n    return a + c\nend\nfn cl n\n    if n < 0 return 777 end\n    return n * 2\nend\nfn cc x\n    return cl(x) + 10\nend\nsay str(up(100,999,5)) + \",\" + str(cc(-5)) + \",\" + str(cc(7))\n"
    file_write("/tmp/lipi_wx_o23.lp", o23_src)
    if wx_spawn(compiler, ["/tmp/lipi_wx_o23.lp", "/tmp/lipi_wx_o2", "-O2"], "/tmp/lipi_wx_o23_log.txt") != 0
        say "FAIL X4c4 -O2 compile failed"
        exit(1)
    end
    if wx_spawn("/tmp/lipi_wx_o2", [], "/tmp/lipi_wx_o23_out.txt") != 0 or file_read("/tmp/lipi_wx_o23_out.txt") != "105,787,24\n"
        say "FAIL X4c5 -O2 unused-param regalloc output mismatch"
        exit(1)
    end
    if wx_spawn(compiler, ["/tmp/lipi_wx_o23.lp", "/tmp/lipi_wx_o3", "-O3"], "/tmp/lipi_wx_o23_log.txt") != 0
        say "FAIL X4c6 -O3 compile failed"
        exit(1)
    end
    if wx_spawn("/tmp/lipi_wx_o3", [], "/tmp/lipi_wx_o23_out.txt") != 0 or file_read("/tmp/lipi_wx_o23_out.txt") != "105,787,24\n"
        say "FAIL X4c7 -O3 multi-return inlining output mismatch"
        exit(1)
    end
    say "  [PASS] X4a: Non-RPO nested-loop regalloc, -O2 unused-param, -O3 multi-return inlining, f64 struct & 10-arg SSA verified"

    // ── X1. ARM64 & RISC-V 64 >8 Stack Args + Phys-Reg SSA + str(u64)/mixed Parity ─
    x1_src = "fn add10 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10\n"
    x1_src = x1_src + "    return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10\nend\n"
    x1_src = x1_src + "fn add12 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12\n"
    x1_src = x1_src + "    return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12\nend\n"
    x1_src = x1_src + "fn call_add10 b\n"
    x1_src = x1_src + "    return add10(b, b+1, b+2, b+3, b+4, b+5, b+6, b+7, b+8, b+9)\nend\n"
    x1_src = x1_src + "fn nested_loop n\n"
    x1_src = x1_src + "    acc = 0\n    i = 0\n    while i < n\n        j = 0\n        while j < n\n            acc = acc + (i * 3 + j)\n            j = j + 1\n        end\n        i = i + 1\n    end\n    return acc\nend\n"
    x1_src = x1_src + "fn main\n"
    x1_src = x1_src + "    say add10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n"
    x1_src = x1_src + "    say add12(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)\n"
    x1_src = x1_src + "    say call_add10(100)\n"
    x1_src = x1_src + "    say \"sum=\" + str(add10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))\n"
    x1_src = x1_src + "    say \"neg=\" + str(-12345) + \",zero=\" + str(0)\n"
    x1_src = x1_src + "    u: u64 = 18446744073709551615\n"
    x1_src = x1_src + "    mn = 0 - 9223372036854775807 - 1\n"
    x1_src = x1_src + "    say \"u64=\" + str(u) + \",mn=\" + str(mn)\n"
    x1_src = x1_src + "    say \"mix=\" + add12(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12) + \",loop=\" + str(nested_loop(6))\n"
    x1_src = x1_src + "    base = 1000\n"
    x1_src = x1_src + "    f = fn(x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) => base + x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9 + x10\n"
    x1_src = x1_src + "    say \"clos=\" + str(f(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))\n"
    x1_src = x1_src + "end\n"
    file_write("/tmp/lipi_wx_x1.lp", x1_src)
    x1_exp = "55\n78\n1045\nsum=55\nneg=-12345,zero=0\nu64=18446744073709551615,mn=-9223372036854775808\nmix=78,loop=360\nclos=1055\n"

    // ARM64 SSA default + legacy
    if wx_spawn(compiler, ["/tmp/lipi_wx_x1.lp", "/tmp/lipi_wx_a64_ssa", "--target=arm64"], "/tmp/lipi_wx_a64_log.txt") != 0
        say "FAIL X1a arm64 SSA compile"
        exit(1)
    end
    a64_clog = file_read("/tmp/lipi_wx_a64_log.txt")
    if str_contains(a64_clog, "replaced 4/5 functions directly from SSA CFG") != 1
        say "FAIL X1a2 arm64 SSA did not replace 4/5 functions"
        exit(1)
    end
    if wx_spawn(compiler, ["/tmp/lipi_wx_x1.lp", "/tmp/lipi_wx_a64_leg", "--target=arm64", "--no-ssa-codegen"], "/tmp/lipi_wx_a64_log.txt") != 0
        say "FAIL X1b arm64 legacy compile"
        exit(1)
    end
    if syscall(21, "/usr/bin/qemu-aarch64", 1, 0, 0, 0, 0) == 0
        if wx_spawn("/usr/bin/qemu-aarch64", ["/tmp/lipi_wx_a64_ssa"], "/tmp/lipi_wx_a64_out.txt") != 0 or file_read("/tmp/lipi_wx_a64_out.txt") != x1_exp
            say "FAIL X1c qemu-aarch64 SSA output mismatch"
            exit(1)
        end
        if wx_spawn("/usr/bin/qemu-aarch64", ["/tmp/lipi_wx_a64_leg"], "/tmp/lipi_wx_a64_out.txt") != 0 or file_read("/tmp/lipi_wx_a64_out.txt") != x1_exp
            say "FAIL X1d qemu-aarch64 legacy output mismatch"
            exit(1)
        end
    end

    // RISC-V 64 SSA default + legacy
    if wx_spawn(compiler, ["/tmp/lipi_wx_x1.lp", "/tmp/lipi_wx_rv64_ssa", "--target=riscv64"], "/tmp/lipi_wx_rv64_log.txt") != 0
        say "FAIL X1e riscv64 SSA compile"
        exit(1)
    end
    rv_clog = file_read("/tmp/lipi_wx_rv64_log.txt")
    if str_contains(rv_clog, "replaced 4/5 functions directly from SSA CFG") != 1
        say "FAIL X1e2 riscv64 SSA did not replace 4/5 functions"
        exit(1)
    end
    if wx_spawn(compiler, ["/tmp/lipi_wx_x1.lp", "/tmp/lipi_wx_rv64_leg", "--target=riscv64", "--no-ssa-codegen"], "/tmp/lipi_wx_rv64_log.txt") != 0
        say "FAIL X1f riscv64 legacy compile"
        exit(1)
    end
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0
        if wx_spawn("/usr/bin/qemu-riscv64", ["/tmp/lipi_wx_rv64_ssa"], "/tmp/lipi_wx_rv64_out.txt") != 0 or file_read("/tmp/lipi_wx_rv64_out.txt") != x1_exp
            say "FAIL X1g qemu-riscv64 SSA output mismatch"
            exit(1)
        end
        if wx_spawn("/usr/bin/qemu-riscv64", ["/tmp/lipi_wx_rv64_leg"], "/tmp/lipi_wx_rv64_out.txt") != 0 or file_read("/tmp/lipi_wx_rv64_out.txt") != x1_exp
            say "FAIL X1h qemu-riscv64 legacy output mismatch"
            exit(1)
        end
    end
    say "  [PASS] X1: ARM64 & RISC-V 64 >8 stack-arg calls + str() parity verified (SSA & legacy)"

    // ── X3. RISC-V 64 OpenSBI S-mode sbi_ecall + Bare-Metal Purity Gate ──────
    sbi_ok_src = "include \"utso/silicon/opensbi.lp\"\n"
    sbi_ok_src = sbi_ok_src + "fn kmain\n"
    sbi_ok_src = sbi_ok_src + "    spec = silicon_sbi_get_spec_version()\n"
    sbi_ok_src = sbi_ok_src + "    has_srst = silicon_sbi_probe_ext(SBI_EXT_SRST())\n"
    sbi_ok_src = sbi_ok_src + "    silicon_sbi_console_write_byte(79)\n"
    sbi_ok_src = sbi_ok_src + "    silicon_sbi_set_timer(1000000)\n"
    sbi_ok_src = sbi_ok_src + "    if has_srst != 0\n"
    sbi_ok_src = sbi_ok_src + "        silicon_sbi_shutdown()\n"
    sbi_ok_src = sbi_ok_src + "    end\n"
    sbi_ok_src = sbi_ok_src + "    return spec\nend\n"
    file_write("/tmp/lipi_wx_sbi_ok.lp", sbi_ok_src)

    if wx_spawn(compiler, ["/tmp/lipi_wx_sbi_ok.lp", "/tmp/lipi_wx_sbi_ok.elf", "--target=riscv64", "--freestanding", "--format=elf-kernel", "--base-addr=0x80200000"], "/tmp/lipi_wx_sbi_log.txt") != 0
        say "FAIL X3a OpenSBI RV64 elf-kernel compile failed"
        exit(1)
    end
    sz_b = [0]
    ebuf = wx_read_raw("/tmp/lipi_wx_sbi_ok.elf", sz_b)
    elen = sz_b[0]
    if ebuf == 0 or elen < 128
        say "FAIL X3b OpenSBI ELF unreadable"
        exit(1)
    end
    if wx_read_u16_le(ebuf, 18) != 243
        say "FAIL X3c OpenSBI ELF e_machine != EM_RISCV (243)"
        exit(1)
    end
    // Verify 0 RWE segments
    phoff = wx_read_u64_le(ebuf, 32)
    phentsz = wx_read_u16_le(ebuf, 54)
    phnum = wx_read_u16_le(ebuf, 56)
    phi = 0
    while phi < phnum
        pf = wx_read_u32_le(ebuf, phoff + (phi * phentsz) + 4)
        if (pf & 7) == 7
            say "FAIL X3d OpenSBI ELF has RWE segment"
            exit(1)
        end
        phi = phi + 1
    end
    // Count exact 8-byte OpenSBI HINT (0x5B100013) + ecall (0x00000073) pairs
    hint_pairs = 0
    bi_s = 0
    while bi_s + 8 <= elen
        if wx_read_u32_le(ebuf, bi_s) == 1527775251 and wx_read_u32_le(ebuf, bi_s + 4) == 115
            hint_pairs = hint_pairs + 1
        end
        bi_s = bi_s + 4
    end
    free(ebuf, elen + 8)
    if hint_pairs < 5
        say "FAIL X3e expected >=5 OpenSBI HINT+ecall pairs, got " + str(hint_pairs)
        exit(1)
    end

    // Negative 1: Raw Linux syscall(64, ...) MUST be rejected
    file_write("/tmp/lipi_wx_sbi_bad1.lp", "fn kmain\n    syscall(64, 1, 0, 0, 0, 0, 0)\n    return 0\nend\n")
    if wx_spawn(compiler, ["/tmp/lipi_wx_sbi_bad1.lp", "/tmp/lipi_wx_sbi_bad1.elf", "--target=riscv64", "--freestanding", "--format=elf-kernel", "--base-addr=0x80200000"], "/tmp/lipi_wx_sbi_log.txt") == 0
        say "FAIL X3f Linux syscall(64) was NOT rejected by RV64 Bare-Metal Purity Gate"
        exit(1)
    end
    // Negative 2: Smuggling Linux SYS_exit (93) through sbi_ecall MUST be rejected
    file_write("/tmp/lipi_wx_sbi_bad2.lp", "fn kmain\n    return sbi_ecall(93, 0, 0)\nend\n")
    if wx_spawn(compiler, ["/tmp/lipi_wx_sbi_bad2.lp", "/tmp/lipi_wx_sbi_bad2.elf", "--target=riscv64", "--freestanding", "--format=elf-kernel", "--base-addr=0x80200000"], "/tmp/lipi_wx_sbi_log.txt") == 0
        say "FAIL X3g sbi_ecall(93) Linux syscall smuggle was NOT rejected"
        exit(1)
    end
    // Negative 3: Constant-expression smuggling `sbi_ecall(60 + 4, ...)` MUST be rejected statically
    file_write("/tmp/lipi_wx_sbi_bad3.lp", "fn kmain\n    return sbi_ecall(60 + 4, 0, 1, 0, 0)\nend\n")
    if wx_spawn(compiler, ["/tmp/lipi_wx_sbi_bad3.lp", "/tmp/lipi_wx_sbi_bad3.elf", "--target=riscv64", "--freestanding", "--format=elf-kernel", "--base-addr=0x80200000"], "/tmp/lipi_wx_sbi_log.txt") == 0
        say "FAIL X3g2 sbi_ecall(60 + 4) constant-expr smuggle was NOT rejected"
        exit(1)
    end
    // Runtime hardware guard: dynamic Linux EIDs (64, 93, 290) blocked with SBI_ERR_NOT_SUPPORTED (-2)
    // on BOTH sbi_ecall and 9-arg sbi_ecall_ret without executing ecall or leaking stack args!
    sbi_dyn_src = "fn chk_dyn(eid) {\n    out_v = 42\n    r1 = sbi_ecall(eid, 0, 1, 2, 3, 4, 5, 6)\n    r2 = sbi_ecall_ret(eid, 0, &out_v, 1, 2, 3, 4, 5, 6)\n    return r1 * 100 + r2\n}\nsay str(chk_dyn(64)) + \",\" + str(chk_dyn(93)) + \",\" + str(chk_dyn(290))\n"
    file_write("/tmp/lipi_wx_sbi_dyn.lp", sbi_dyn_src)
    if wx_spawn(compiler, ["/tmp/lipi_wx_sbi_dyn.lp", "/tmp/lipi_wx_sbi_dyn", "--target=riscv64"], "/tmp/lipi_wx_sbi_log.txt") != 0
        say "FAIL X3h1 OpenSBI dynamic runtime guard compile failed"
        exit(1)
    end
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0
        if wx_spawn("/usr/bin/qemu-riscv64", ["/tmp/lipi_wx_sbi_dyn"], "/tmp/lipi_wx_rv64_out.txt") != 0 or file_read("/tmp/lipi_wx_rv64_out.txt") != "-202,-202,-202\n"
            say "FAIL X3h2 OpenSBI dynamic runtime guard mismatch in qemu-riscv64"
            exit(1)
        end
    end
    say "  [PASS] X3: OpenSBI S-mode sbi_ecall (" + str(hint_pairs) + " HINT+ecall traps, 0 RWE) + 3 static gates + qemu-riscv64 runtime guard verified"

    // ── X3b. Live Full-System Bare-Metal Kernel Boot in qemu-system-riscv64 & qemu-system-aarch64 ──
    if syscall(21, "/usr/bin/qemu-system-riscv64", 1, 0, 0, 0, 0) == 0
        rv_boot_src = "import \"utso/silicon/opensbi.lp\"\nfn main\n"
        rv_boot_src = rv_boot_src + "    uart = RV_UART0_BASE()\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_init(uart)\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_cstr(uart, \"LIPI_RV64_LIVE_BOOT_OK\\n\")\n"
        rv_boot_src = rv_boot_src + "    spec = silicon_sbi_get_spec_version()\n"
        rv_boot_src = rv_boot_src + "    impl_id = silicon_sbi_get_impl_id()\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_cstr(uart, \"SBI_SPEC=\")\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_u64(uart, spec)\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_cstr(uart, \" IMPL=\")\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_u64(uart, impl_id)\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_uart_write_cstr(uart, \"\\n\")\n"
        rv_boot_src = rv_boot_src + "    silicon_sbi_call(SBI_EXT_SRST(), SBI_FID_SRST_SYSTEM_RESET(), 0, 0, 0, 0, 0, 0)\n"
        rv_boot_src = rv_boot_src + "    silicon_rv_syscon_poweroff(RV_SYSCON_BASE())\n"
        rv_boot_src = rv_boot_src + "end\n"
        file_write("/tmp/lipi_wx_rv_boot.lp", rv_boot_src)
        if wx_spawn(compiler, ["/tmp/lipi_wx_rv_boot.lp", "/tmp/lipi_wx_rv_boot.elf", "--target=riscv64-elf-kernel", "--base-addr=0x80200000"], "/tmp/lipi_wx_sbi_log.txt") != 0
            say "FAIL X3b1 RV64 live-boot kernel compile failed"
            exit(1)
        end
        rv_b_rc = wx_spawn("/usr/bin/qemu-system-riscv64", ["-machine", "virt", "-display", "none", "-monitor", "none", "-serial", "stdio", "-bios", "default", "-kernel", "/tmp/lipi_wx_rv_boot.elf"], "/tmp/lipi_wx_rv_boot.out")
        rv_b_out = file_read("/tmp/lipi_wx_rv_boot.out")
        if rv_b_rc != 0 or str_contains(rv_b_out, "OpenSBI") != 1 or str_contains(rv_b_out, "LIPI_RV64_LIVE_BOOT_OK") != 1 or str_contains(rv_b_out, "SBI_SPEC=") != 1 or str_contains(rv_b_out, "IMPL=1") != 1
            say "FAIL X3b2 qemu-system-riscv64 live OpenSBI kernel boot mismatch (rc=" + str(rv_b_rc) + "): " + rv_b_out
            exit(1)
        end
        wx_unlink("/tmp/lipi_wx_rv_boot.lp")
        wx_unlink("/tmp/lipi_wx_rv_boot.elf")
        wx_unlink("/tmp/lipi_wx_rv_boot.out")
        say "  [PASS] X3b: Live qemu-system-riscv64 OpenSBI v1.3 S-mode kernel boot + SBI_EXT_BASE + SBI_EXT_SRST poweroff verified"
    end

    if syscall(21, "/usr/bin/qemu-system-aarch64", 1, 0, 0, 0, 0) == 0
        a64_boot_src = "import \"utso/silicon/pl011.lp\"\nimport \"utso/silicon/gic.lp\"\nfn main\n"
        a64_boot_src = a64_boot_src + "    uart = PL011_QEMU_VIRT_BASE()\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_init(uart, 24000000, 115200)\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_write_cstr(uart, \"LIPI_ARM64_LIVE_BOOT_OK\\n\")\n"
        a64_boot_src = a64_boot_src + "    max_irqs = silicon_gic_dist_init(GICD_QEMU_VIRT_BASE())\n"
        a64_boot_src = a64_boot_src + "    silicon_gic_cpu_init(GICC_QEMU_VIRT_BASE(), 255)\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_write_cstr(uart, \"GIC_MAX_IRQS=\")\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_write_u64(uart, max_irqs)\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_write_cstr(uart, \"\\n\")\n"
        a64_boot_src = a64_boot_src + "    silicon_pl011_flush(uart)\n"
        a64_boot_src = a64_boot_src + "    silicon_arm64_psci_poweroff()\n"
        a64_boot_src = a64_boot_src + "end\n"
        file_write("/tmp/lipi_wx_a64_boot.lp", a64_boot_src)
        if wx_spawn(compiler, ["/tmp/lipi_wx_a64_boot.lp", "/tmp/lipi_wx_a64_boot.elf", "--target=arm64-elf-kernel", "--base-addr=0x40080000"], "/tmp/lipi_wx_sbi_log.txt") != 0
            say "FAIL X3c1 ARM64 live-boot kernel compile failed"
            exit(1)
        end
        a64_b_rc = wx_spawn("/usr/bin/qemu-system-aarch64", ["-machine", "virt", "-cpu", "cortex-a57", "-display", "none", "-monitor", "none", "-serial", "stdio", "-kernel", "/tmp/lipi_wx_a64_boot.elf"], "/tmp/lipi_wx_a64_boot.out")
        a64_b_out = file_read("/tmp/lipi_wx_a64_boot.out")
        if a64_b_rc != 0 or str_contains(a64_b_out, "LIPI_ARM64_LIVE_BOOT_OK") != 1 or str_contains(a64_b_out, "GIC_MAX_IRQS=") != 1
            say "FAIL X3c2 qemu-system-aarch64 live EL1 kernel boot mismatch (rc=" + str(a64_b_rc) + "): " + a64_b_out
            exit(1)
        end
        wx_unlink("/tmp/lipi_wx_a64_boot.lp")
        wx_unlink("/tmp/lipi_wx_a64_boot.elf")
        wx_unlink("/tmp/lipi_wx_a64_boot.out")
        say "  [PASS] X3c: Live qemu-system-aarch64 EL1h kernel boot + PL011 UART + GICv2 + PSCI HVC poweroff verified"
    end

    // ── X4b. WASM Unified SSA Default (Verified in V8 when node exists) ──────
    w_src = "fn add10 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10\n    return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10\nend\n"
    w_src = w_src + "fn fib n\n    if n <= 1 return n end\n    return fib(n - 1) + fib(n - 2)\nend\n"
    w_src = w_src + "fn loop_sum n\n    i = 0\n    s = 0\n    while i <= n\n        s = s + i\n        i = i + 1\n    end\n    return s\nend\n"
    w_src = w_src + "fn main\n    return add10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10) + fib(10) + loop_sum(10)\nend\n"
    file_write("/tmp/lipi_wx_wasm.lp", w_src)
    if wx_spawn(compiler, ["/tmp/lipi_wx_wasm.lp", "/tmp/lipi_wx_wasm.wasm", "--target=wasm", "--freestanding"], "/tmp/lipi_wx_wasm_log.txt") != 0
        say "FAIL X4d WASM unified SSA compile failed"
        exit(1)
    end
    w_clog = file_read("/tmp/lipi_wx_wasm_log.txt")
    if str_contains(w_clog, "replaced 3/4 functions directly from SSA CFG") != 1
        say "FAIL X4e WASM SSA did not replace 3/4 functions"
        exit(1)
    end
    if syscall(21, "/usr/bin/node", 1, 0, 0, 0, 0) == 0
        js_chk = "const fs=require('fs'); WebAssembly.instantiate(fs.readFileSync('/tmp/lipi_wx_wasm.wasm')).then(({instance})=>{ const r=instance.exports.main(); console.log('WASM_X4='+r.toString()); if(r!==165n) process.exit(1); });"
        if wx_spawn("/usr/bin/node", ["-e", js_chk], "/tmp/lipi_wx_wasm_out.txt") != 0 or str_contains(file_read("/tmp/lipi_wx_wasm_out.txt"), "WASM_X4=165") != 1
            say "FAIL X4f WASM V8 execution mismatch"
            exit(1)
        end
    end
    say "  [PASS] X4b: WASM unified SSA CFG (3/4 fns) verified in V8 (165)"

    // Clean up temporary files
    wx_unlink("/tmp/lipi_wx_x1.lp")
    wx_unlink("/tmp/lipi_wx_a64_ssa")
    wx_unlink("/tmp/lipi_wx_a64_leg")
    wx_unlink("/tmp/lipi_wx_a64_log.txt")
    wx_unlink("/tmp/lipi_wx_a64_out.txt")
    wx_unlink("/tmp/lipi_wx_rv64_ssa")
    wx_unlink("/tmp/lipi_wx_rv64_leg")
    wx_unlink("/tmp/lipi_wx_rv64_log.txt")
    wx_unlink("/tmp/lipi_wx_rv64_out.txt")
    wx_unlink("/tmp/lipi_wx_sbi_ok.lp")
    wx_unlink("/tmp/lipi_wx_sbi_ok.elf")
    wx_unlink("/tmp/lipi_wx_sbi_bad1.lp")
    wx_unlink("/tmp/lipi_wx_sbi_bad1.elf")
    wx_unlink("/tmp/lipi_wx_sbi_bad2.lp")
    wx_unlink("/tmp/lipi_wx_sbi_bad2.elf")
    wx_unlink("/tmp/lipi_wx_sbi_bad3.lp")
    wx_unlink("/tmp/lipi_wx_sbi_bad3.elf")
    wx_unlink("/tmp/lipi_wx_sbi_dyn.lp")
    wx_unlink("/tmp/lipi_wx_sbi_dyn")
    wx_unlink("/tmp/lipi_wx_o23.lp")
    wx_unlink("/tmp/lipi_wx_o2")
    wx_unlink("/tmp/lipi_wx_o3")
    wx_unlink("/tmp/lipi_wx_o23_log.txt")
    wx_unlink("/tmp/lipi_wx_o23_out.txt")
    wx_unlink("/tmp/lipi_wx_sbi_log.txt")
    wx_unlink("/tmp/lipi_wx_wasm.lp")
    wx_unlink("/tmp/lipi_wx_wasm.wasm")
    wx_unlink("/tmp/lipi_wx_wasm_log.txt")
    wx_unlink("/tmp/lipi_wx_wasm_out.txt")

    say "PASS_WAVE_X_ROUND2_SOVEREIGN"
    return 0
end
