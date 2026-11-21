// ==============================================================================
// REGRESSION TEST: FLAGSHIP SOVEREIGN SHOWCASES (01, 02, 03)
// ==============================================================================
// Compiles and runs all three flagship showcases in examples/flagship/:
//   01_sovereign_kavach_vault.lp     (--kavach mode enforced)
//   02_sovereign_silicon_brain.lp    (pure f64 neural net XOR convergence)
//   03_omni_six_target_harmony.lp    (bilingual cross-target list/slab parity)

include "utso/io"
include "utso/string"

fn fl_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn fl_exec exe a1 a2 a3 log_path
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

fn run_flagship comp src_path flag marker tmp_base idx
    bin_p = tmp_base + "_" + str(idx) + ".elf"
    clog = tmp_base + "_c" + str(idx) + ".log"
    rlog = tmp_base + "_r" + str(idx) + ".log"

    ce = fl_exec(comp, src_path, bin_p, flag, clog)
    c_out = file_read(clog)
    syscall(87, clog, 0, 0, 0, 0, 0)
    if ce != 0
        syscall(87, bin_p, 0, 0, 0, 0, 0)
        say "[ERR] Compile error on " + src_path + ": " + c_out
        return 1

    re = fl_exec(bin_p, "", "", "", rlog)
    r_out = file_read(rlog)
    syscall(87, rlog, 0, 0, 0, 0, 0)
    syscall(87, bin_p, 0, 0, 0, 0, 0)
    if re != 0 or str_contains(r_out, marker) != 1
        say "[ERR] Runtime check mismatch on " + src_path + " (exit=" + str(re) + ")"
        return 1
    say "[PASS] " + src_path + " verified (" + marker + ")"
    return 0

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = fl_resolve_compiler()
    base = "/tmp/flagship_test_" + str(pid)

    if run_flagship(comp, "examples/flagship/01_sovereign_kavach_vault.lp", "--kavach", "KAVACH_VAULT_VERIFIED", base, 1) != 0
        return 1
    if run_flagship(comp, "examples/flagship/02_sovereign_silicon_brain.lp", "", "SILICON_BRAIN_XOR_CONVERGED", base, 2) != 0
        return 1
    if run_flagship(comp, "examples/flagship/03_omni_six_target_harmony.lp", "", "OMNI_HARMONY_VERIFIED", base, 3) != 0
        return 1

    say "✅ TEST_FLAGSHIP_SHOWCASES_COMPLETE"
    return 0

main()
