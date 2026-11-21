// ==============================================================================
// REGRESSION TEST: SOVEREIGN KAVACH & SLAB FREE HARDENING
// ==============================================================================
// Verifies:
//   1. Valid --kavach program with `silicon_*` hardware crown + inter-procedural
//      ownership transfer (`return ptr`) compiles and runs cleanly.
//   2. Uncrowned raw `syscall` outside `silicon_*` / `সিলিকন_*` is rejected.
//   3. Uncrowned raw `mem_write` outside `silicon_*` / `সিলিকন_*` is rejected.
//   4. Return-leak (`alloc` + `return 0` without `free`) is caught even with Return tail.
//   5. Bounds-guarded & double-free-safe `_lipi_user_free` (`free(0)`, double-free) runs safely.

include "utso/io"
include "utso/string"

fn kv_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn kv_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn kv_exec_log exe a1 a2 a3 log_path
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
    if len(a3) > 0
        mem_write(argv, idx * 8, a3)
        idx = idx + 1
    mem_write(argv, idx * 8, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd = syscall(2, log_path, 577, 420, 0, 0, 0)
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

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = kv_resolve_compiler()
    base = "/tmp/kv_test_" + str(pid)

    // 1. Positive crowned + move proof case
    pos_lp = base + "_pos.lp"
    pos_bin = base + "_pos.elf"
    pos_clog = base + "_pos_c.log"
    pos_rlog = base + "_pos_r.log"
    pos_src = "fn silicon_seal p v\n  pid = syscall(39, 0, 0, 0, 0, 0, 0)\n  mem_write(p, 0, v ^ (pid & 255))\n  return pid\n\nfn mk_slot val\n  s = alloc(64)\n  silicon_seal(s, val)\n  return s\n\nfn main\n  b = mk_slot(919)\n  v = mem_read(b, 0)\n  free(b)\n  say \"KAVACH_POS_OK=\" + str(v)\n  return 0\n\nmain()\n"
    kv_write_file(pos_lp, pos_src)
    c1 = kv_exec_log(comp, pos_lp, pos_bin, "--kavach", pos_clog)
    if c1 != 0
        clog = file_read(pos_clog)
        say "[ERR] Valid --kavach test rejected compilation: " + clog
        return 1
    r1 = kv_exec_log(pos_bin, "", "", "", pos_rlog)
    out1 = file_read(pos_rlog)
    syscall(87, pos_lp, 0, 0, 0, 0, 0)
    syscall(87, pos_bin, 0, 0, 0, 0, 0)
    syscall(87, pos_clog, 0, 0, 0, 0, 0)
    syscall(87, pos_rlog, 0, 0, 0, 0, 0)
    if r1 != 0 or str_contains(out1, "KAVACH_POS_OK=") != 1
        say "[ERR] Positive --kavach binary execution problem"
        return 1
    say "[PASS] Valid --kavach crowned + ownership transfer compiled & ran"

    // 2. Negative uncrowned raw syscall check
    n1_lp = base + "_neg1.lp"
    n1_bin = base + "_neg1.elf"
    n1_log = base + "_neg1.log"
    kv_write_file(n1_lp, "fn rogue_sys\n  return syscall(39, 0, 0, 0, 0, 0, 0)\n\nfn main\n  return rogue_sys()\n\nmain()\n")
    c2 = kv_exec_log(comp, n1_lp, n1_bin, "--kavach", n1_log)
    syscall(87, n1_lp, 0, 0, 0, 0, 0)
    syscall(87, n1_bin, 0, 0, 0, 0, 0)
    syscall(87, n1_log, 0, 0, 0, 0, 0)
    if c2 == 0
        say "[ERR] Uncrowned raw syscall compiled under --kavach"
        return 1
    say "[PASS] --kavach rejected uncrowned raw syscall"

    // 3. Negative uncrowned raw mem_write check
    n2_lp = base + "_neg2.lp"
    n2_bin = base + "_neg2.elf"
    n2_log = base + "_neg2.log"
    kv_write_file(n2_lp, "fn rogue_poke ptr\n  mem_write(ptr, 0, 123)\n  return 0\n\nfn main\n  b = alloc(64)\n  rogue_poke(b)\n  free(b)\n  return 0\n\nmain()\n")
    c3 = kv_exec_log(comp, n2_lp, n2_bin, "--kavach", n2_log)
    syscall(87, n2_lp, 0, 0, 0, 0, 0)
    syscall(87, n2_bin, 0, 0, 0, 0, 0)
    syscall(87, n2_log, 0, 0, 0, 0, 0)
    if c3 == 0
        say "[ERR] Uncrowned raw mem_write compiled under --kavach"
        return 1
    say "[PASS] --kavach rejected uncrowned raw mem_write"

    // 4. Negative Return leak check (was previously bypassed by last_stmt == Return)
    n3_lp = base + "_neg3.lp"
    n3_bin = base + "_neg3.elf"
    n3_log = base + "_neg3.log"
    kv_write_file(n3_lp, "fn leak_with_ret x\n  b = alloc(64)\n  if x > 0\n    return 0\n  return 0\n\nfn main\n  return leak_with_ret(1)\n\nmain()\n")
    c4 = kv_exec_log(comp, n3_lp, n3_bin, "--kavach", n3_log)
    syscall(87, n3_lp, 0, 0, 0, 0, 0)
    syscall(87, n3_bin, 0, 0, 0, 0, 0)
    syscall(87, n3_log, 0, 0, 0, 0, 0)
    if c4 == 0
        say "[ERR] Return-tail memory leak escaped --kavach ownership proof"
        return 1
    say "[PASS] --kavach caught Return-tail memory leak"

    // 5. Runtime slab safety: free(0) & double-free cycle guard do not crash or corrupt heap
    free(0)
    p = alloc(64)
    mem_write(p, 0, 4242)
    free(p)
    free(p)
    q = alloc(64)
    mem_write(q, 0, 7777)
    qv = mem_read(q, 0)
    free(q)
    if qv != 7777
        say "[ERR] Slab reuse after guarded double-free returned unexpected data"
        return 1
    say "[PASS] Bounds & double-free guarded _lipi_user_free safe"
    say "✅ TEST_SOVEREIGN_KAVACH_MODE_COMPLETE"
    return 0

main()
