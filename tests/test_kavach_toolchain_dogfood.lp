// ==============================================================================
// REGRESSION TEST: KAVACH (--kavach) TOOLCHAIN DOGFOODING & SILICON CROWN AUDIT
// ==============================================================================
// Verifies end-to-end:
//   1. src/tools/lipidoc.lp compiles cleanly under `--kavach`.
//   2. src/tools/lipifmt.lp compiles cleanly under `--kavach`.
//   3. src/tools/lipi_akhara.lp compiles cleanly under `--kavach` & `--selftest` passes.
//   4. `--kavach` rejects rogue unisolated `syscall(...)` outside `silicon_*` primitives.

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

fn kv_read_file path
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

fn kv_exec exe a1 a2 a3 log_p
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

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = kv_resolve_compiler()
    doc_out = "/tmp/kv_doc_" + str(pid)
    fmt_out = "/tmp/kv_fmt_" + str(pid)
    akh_out = "/tmp/kv_akh_" + str(pid)
    rogue_src = "/tmp/kv_rogue_" + str(pid) + ".lp"
    rogue_out = "/tmp/kv_rogue_" + str(pid)
    log_p = "/tmp/kv_log_" + str(pid) + ".txt"

    if kv_exec(comp, "src/tools/lipidoc.lp", doc_out, "--kavach", log_p) != 0
        say "[ERR] lipidoc.lp blocked by --kavach"
        return 1
    say "[PASS] lipidoc.lp compiled cleanly under --kavach"

    if kv_exec(comp, "src/tools/lipifmt.lp", fmt_out, "--kavach", log_p) != 0
        say "[ERR] lipifmt.lp blocked by --kavach"
        return 1
    say "[PASS] lipifmt.lp compiled cleanly under --kavach"

    if kv_exec(comp, "src/tools/lipi_akhara.lp", akh_out, "--kavach", log_p) != 0
        say "[ERR] lipi_akhara.lp blocked by --kavach"
        return 1
    say "[PASS] lipi_akhara.lp compiled cleanly under --kavach"

    if kv_exec(akh_out, "--selftest", "", "", log_p) != 0
        say "[ERR] --kavach lipi_akhara --selftest execution returned non-zero"
        return 1
    selftest_log = kv_read_file(log_p)
    if str_contains(selftest_log, "AKHARA_SELFTEST_COMPLETE") != 1
        say "[ERR] --kavach lipi_akhara --selftest output mismatch"
        return 1
    say "[PASS] --kavach lipi_akhara --selftest verified"

    rogue_code = "fn main\n  r = syscall(39, 0, 0, 0, 0, 0, 0)\n  return 0\n\nmain()\n"
    kv_write_file(rogue_src, rogue_code)
    rc_rogue = kv_exec(comp, rogue_src, rogue_out, "--kavach", log_p)
    if rc_rogue == 0
        say "[ERR] --kavach allowed unisolated raw syscall"
        return 1
    say "[PASS] --kavach blocked rogue raw syscall outside silicon_* boundary"

    syscall(87, doc_out, 0, 0, 0, 0, 0)
    syscall(87, fmt_out, 0, 0, 0, 0, 0)
    syscall(87, akh_out, 0, 0, 0, 0, 0)
    syscall(87, rogue_src, 0, 0, 0, 0, 0)
    syscall(87, rogue_out, 0, 0, 0, 0, 0)
    syscall(87, log_p, 0, 0, 0, 0, 0)

    say "✅ TEST_KAVACH_TOOLCHAIN_DOGFOOD_COMPLETE"
    return 0

main()
