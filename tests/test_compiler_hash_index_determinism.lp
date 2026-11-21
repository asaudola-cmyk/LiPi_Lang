// ==============================================================================
// REGRESSION TEST: COMPILER HASH-INDEX DETERMINISM & BIT-FOR-BIT ELF REPRO
// ==============================================================================
// Verifies that the O(N) 4096-bucket hash indexing in `ssa_lowerer.lp` and
// `x86_64/` synthesizer scales cleanly across many structs/globals/functions
// and produces byte-for-byte deterministic Static-PIE ELF binaries.

include "utso/io"
include "utso/string"

fn hd_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn hd_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn hd_read_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return ""
    rbuf = malloc(16384)
    total = 0
    while total < 16383
        n = syscall(0, fd, rbuf + total, 16383 - total, 0, 0, 0)
        if n <= 0
            break
        total = total + n
    syscall(3, fd, 0, 0, 0, 0, 0)
    out = ""
    i = 0
    while i < total
        out = out + chr(mem_byte_read(rbuf, i))
        i = i + 1
    syscall(11, rbuf, 16384, 0, 0, 0, 0)
    return out

fn hd_exec exe a1 a2 log_p
    argv = malloc(64)
    env = malloc(16)
    st = malloc(8)
    i = 0
    while i < 64
        mem_byte_write(argv, i, 0)
        i = i + 1
    mem_write(env, 0, 0)
    mem_write(env, 8, 0)
    mem_write(st, 0, 0)

    mem_write(argv, 0, exe)
    idx = 1
    if len(a1) > 0
        mem_write(argv, idx * 8, a1)
        idx = idx + 1
    if len(a2) > 0
        mem_write(argv, idx * 8, a2)
        idx = idx + 1
    mem_write(argv, idx * 8, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd = syscall(2, log_p, 577, 420, 0, 0, 0)
        if cfd >= 0
            syscall(33, cfd, 1, 0, 0, 0, 0)
            syscall(33, cfd, 2, 0, 0, 0, 0)
            syscall(3, cfd, 0, 0, 0, 0, 0)
        syscall(59, exe, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw = mem_read(st, 0) & 65535
    code = (raw / 256) % 256
    if (raw & 127) != 0
        code = 128 + (raw & 127)
    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 16, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return code

fn hd_cmp_files p1 p2
    fd1 = syscall(2, p1, 0, 0, 0, 0, 0)
    fd2 = syscall(2, p2, 0, 0, 0, 0, 0)
    if fd1 < 0 or fd2 < 0
        if fd1 >= 0
            syscall(3, fd1, 0, 0, 0, 0, 0)
        if fd2 >= 0
            syscall(3, fd2, 0, 0, 0, 0, 0)
        return 0 - 1
    b1 = malloc(4096)
    b2 = malloc(4096)
    total = 0
    same = 1
    while same == 1
        n1 = syscall(0, fd1, b1, 4096, 0, 0, 0)
        n2 = syscall(0, fd2, b2, 4096, 0, 0, 0)
        if n1 != n2
            same = 0
            break
        if n1 <= 0
            break
        k = 0
        while k < n1
            if mem_byte_read(b1, k) != mem_byte_read(b2, k)
                same = 0
                break
            k = k + 1
        total = total + n1
    syscall(3, fd1, 0, 0, 0, 0, 0)
    syscall(3, fd2, 0, 0, 0, 0, 0)
    syscall(11, b1, 4096, 0, 0, 0, 0)
    syscall(11, b2, 4096, 0, 0, 0, 0)
    if same == 0
        return 0 - 1
    return total

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = hd_resolve_compiler()
    src_p = "/tmp/det_src_" + str(pid) + ".lp"
    out_a = "/tmp/det_a_" + str(pid)
    out_b = "/tmp/det_b_" + str(pid)
    log_p = "/tmp/det_log_" + str(pid) + ".txt"

    src = ""
    si = 0
    while si < 30
        src = src + "struct Node" + str(si) + "\n    val" + str(si) + "\n\n"
        si = si + 1

    gi = 0
    while gi < 20
        src = src + "G_CONST_" + str(gi) + " = " + str(gi + 1) + "\n"
        gi = gi + 1

    src = src + "\nfn f0 x\n    if x < 0\n        return 0\n    return x + 1\n\n"
    fi = 1
    while fi < 60
        src = src + "fn f" + str(fi) + " x\n    if (x % 2) == 0\n        return f" + str(fi - 1) + "(x) + 1\n    return f" + str(fi - 1) + "(x) + 1\n\n"
        fi = fi + 1

    src = src + "fn main\n    n = Node0()\n    n.val0 = G_CONST_19\n    res = f59(n.val0)\n    if res == 80\n        say \"DETERMINISM_80\"\n        return 0\n    return 1\n\nmain()\n"
    hd_write_file(src_p, src)

    if hd_exec(comp, src_p, out_a, log_p) != 0
        say "[ERR] first compilation error"
        return 1
    if hd_exec(comp, src_p, out_b, log_p) != 0
        say "[ERR] second compilation error"
        return 1

    sz = hd_cmp_files(out_a, out_b)
    if sz <= 4096
        say "[ERR] binary determinism mismatch: sz=" + str(sz)
        return 1
    say "[PASS] byte-for-byte identical ELF binaries synthesized (" + str(sz) + " bytes across 30 structs & 60 fns)"

    if hd_exec(out_a, "", "", log_p) != 0
        say "[ERR] synthesized binary exited non-zero"
        return 1
    out_log = hd_read_file(log_p)
    if str_contains(out_log, "DETERMINISM_80") != 1
        say "[ERR] synthesized output mismatch"
        return 1
    say "[PASS] hash-indexed program executed cleanly (out=DETERMINISM_80)"

    syscall(87, src_p, 0, 0, 0, 0, 0)
    syscall(87, out_a, 0, 0, 0, 0, 0)
    syscall(87, out_b, 0, 0, 0, 0, 0)
    syscall(87, log_p, 0, 0, 0, 0, 0)

    say "✅ TEST_COMPILER_HASH_INDEX_DETERMINISM_COMPLETE"
    return 0

main()
