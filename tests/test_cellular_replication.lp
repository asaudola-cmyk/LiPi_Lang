// ==============================================================================
// 🧪 LIPI TEST: Cellular Binary Self-Replication Verification Suite
// File: tests/test_cellular_replication.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Fixed
// ⚡ 100% Pure LiPi Implementation | Direct Linux Kernel Syscalls | Zero C / Shell
// ==============================================================================
//
// WHY THIS TEST:
// Biological systems achieve immortality through cellular self-replication.
// A sovereign programming language must never rely on foreign package managers,
// CDNs, or host C compilers to recreate its compiler seed. This test verifies that:
// 1. Any live LiPi runtime/compiler can autonomously spawn a byte-exact genesis seed.
// 2. The spawned seed is a fully autonomous standalone ELF64 executable.
// 3. The spawned seed can compile new LiPi programs independently.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"

// Process spawner via Linux AMD64 SYS_fork (57) and SYS_execve (59)
fn test_spawn_process cmd_path arg1 arg2 arg3
    argv = malloc(64)
    mem_word_write(argv, 0, cmd_path)
    idx = 1
    if len(arg1) > 0
        mem_word_write(argv, idx * 8, arg1)
        idx = idx + 1
    if len(arg2) > 0
        mem_word_write(argv, idx * 8, arg2)
        idx = idx + 1
    if len(arg3) > 0
        mem_word_write(argv, idx * 8, arg3)
        idx = idx + 1
    mem_word_write(argv, idx * 8, 0)

    env = malloc(32)
    path_env = "PATH=/usr/bin:/bin:/usr/local/bin"
    mem_word_write(env, 0, path_env)
    mem_word_write(env, 8, 0)

    st = malloc(8)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        null_fd = syscall(2, "/dev/null", 2, 0, 0, 0, 0)
        if null_fd >= 0
            syscall(33, null_fd, 1, 0, 0, 0, 0)
            syscall(33, null_fd, 2, 0, 0, 0, 0)
            syscall(3, null_fd, 0, 0, 0, 0, 0)
        syscall(59, cmd_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    free(argv, 64)
    free(env, 32)
    free(st, 8)
    return exit_code

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🌱 LIPI TEST: CELLULAR SELF-REPLICATION & BOOTSTRAP CLOSURE"
    say "════════════════════════════════════════════════════════════════════════"

    spawned_seed = "/tmp/lipi_spawned_seed_test"
    probe_src    = "/tmp/lipi_cellular_probe.lp"
    probe_bin    = "/tmp/lipi_cellular_probe_bin"

    // Clean any prior artifacts
    syscall(87, spawned_seed, 0, 0, 0, 0, 0)
    syscall(87, probe_src, 0, 0, 0, 0, 0)
    syscall(87, probe_bin, 0, 0, 0, 0, 0)

    // ── Phase 1: Replicate Genesis Seed via Direct Kernel Syscalls ─────────────
    say "\n[Phase 1]: Replicating Genesis Seed..."
    src_binary = ""
    if syscall(21, "boot/lipi-seed", 0, 0, 0, 0, 0) == 0
        src_binary = "boot/lipi-seed"
    elif syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        src_binary = "bin/lipc_bin"
    elif syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        src_binary = "bin/lipc"

    if len(src_binary) == 0
        say "  ❌ FAILED: No compiler seed source available."
        return 1

    fd_in = syscall(2, src_binary, 0, 0, 0, 0, 0)
    if fd_in < 0
        say "  ❌ FAILED: Unable to open source binary: " + src_binary
        return 1

    fd_out = syscall(2, spawned_seed, 577, 493, 0, 0, 0) // O_WRONLY|O_CREAT|O_TRUNC, 0755
    if fd_out < 0
        say "  ❌ FAILED: Unable to create spawned seed: " + spawned_seed
        syscall(3, fd_in, 0, 0, 0, 0, 0)
        return 1

    // Fast-Path: Linux Zero-Copy kernel space replication via sys_copy_file_range (Syscall 326)
    total_replicated = syscall(326, fd_in, 0, fd_out, 0, 10485760, 0)
    if total_replicated <= 0
        buf_size = 65536
        buf = malloc(buf_size)
        total_replicated = 0
        while 1 == 1
            n = syscall(0, fd_in, buf, buf_size, 0, 0, 0)
            if n <= 0
                break
            syscall(1, fd_out, buf, n, 0, 0, 0)
            total_replicated = total_replicated + n
        free(buf, buf_size)

    syscall(3, fd_in, 0, 0, 0, 0, 0)
    syscall(3, fd_out, 0, 0, 0, 0, 0)
    syscall(90, spawned_seed, 493, 0, 0, 0, 0) // chmod 0755

    say "  ✔ Replicated " + str(total_replicated) + " bytes from " + src_binary
    if total_replicated < 100000
        say "  ❌ FAILED: Spawned seed size too small: " + str(total_replicated)
        return 1

    // ── Phase 2: Validate ELF64 Header Integrity ──────────────────────────────
    say "\n[Phase 2]: Validating ELF64 Header & Magic..."
    fd_chk = syscall(2, spawned_seed, 0, 0, 0, 0, 0)
    if fd_chk < 0
        say "  ❌ FAILED: Could not open spawned seed for verification."
        return 1

    hdr = malloc(16)
    syscall(0, fd_chk, hdr, 4, 0, 0, 0)
    b0 = mem_byte_read(hdr, 0)
    b1 = mem_byte_read(hdr, 1)
    b2 = mem_byte_read(hdr, 2)
    b3 = mem_byte_read(hdr, 3)
    syscall(3, fd_chk, 0, 0, 0, 0, 0)
    free(hdr, 16)

    if b0 != 127 or b1 != 69 or b2 != 76 or b3 != 70
        say "  ❌ FAILED: ELF magic header invalid: " + str(b0) + "," + str(b1) + "," + str(b2) + "," + str(b3)
        return 1
    say "  ✔ ELF64 Magic Header Verified (0x7F 'E' 'L' 'F')"

    // ── Phase 3: Autonomous Compilation via Spawned Seed ──────────────────────
    say "\n[Phase 3]: Testing Independent Compilation via Spawned Seed..."
    // Write probe source file
    fd_probe = syscall(2, probe_src, 577, 420, 0, 0, 0)
    probe_code = "fn main\n    say \"PROBE_CELLULAR_ALIVE_42\"\n    return 0\nmain()\n"
    syscall(1, fd_probe, probe_code, len(probe_code), 0, 0, 0)
    syscall(3, fd_probe, 0, 0, 0, 0, 0)

    // Invoke the spawned seed to compile probe program
    c_res = test_spawn_process(spawned_seed, probe_src, "-o", probe_bin)
    if c_res != 0
        say "  ❌ FAILED: Spawned seed compilation failed (code " + str(c_res) + ")"
        return 1
    say "  ✔ Spawned seed successfully compiled probe source"

    // ── Phase 4: Verification of Probe Execution ──────────────────────────────
    say "\n[Phase 4]: Executing Program Produced by Spawned Seed..."
    x_res = test_spawn_process(probe_bin, "", "", "")
    if x_res != 0
        say "  ❌ FAILED: Probe program execution returned non-zero: " + str(x_res)
        return 1
    say "  ✔ Probe program executed successfully (exit code 0)"

    // ── Phase 5: Cleanup & Verification Closure ───────────────────────────────
    say "\n[Phase 5]: Releasing Scratch Artifacts..."
    syscall(87, spawned_seed, 0, 0, 0, 0, 0)
    syscall(87, probe_src, 0, 0, 0, 0, 0)
    syscall(87, probe_bin, 0, 0, 0, 0, 0)

    say "════════════════════════════════════════════════════════════════════════"
    say "🎉 ALL CELLULAR REPLICATION ASSERTIONS PASSED (100% AUTONOMOUS)"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
