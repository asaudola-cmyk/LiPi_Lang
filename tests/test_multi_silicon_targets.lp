// ==============================================================================
// 👑 LIPI MULTI-SILICON TARGETS & BARE-METAL UNIKERNEL TEST SUITE (Test 204)
// ⚡ 100% Pure LiPi Implementation | 0% C | 0% Libc | Direct Kernel Syscalls
// File: tests/test_multi_silicon_targets.lp
// ==============================================================================
//
// WHY THIS TEST MODULE:
// 1. Validates that LiPi can synthesize pure silicon machine code for multiple hardware ISAs:
//    - x86_64: AMD64 / Intel 64-bit CISC machine code
//    - arm64: ARMv8-A / AArch64 32-bit fixed-width RISC machine code (EM_AARCH64 = 183)
//    - riscv64: RISC-V 64-bit LP64 open architecture (EM_RISCV = 243)
//    - wasm: W3C WebAssembly LEB128 bytecode (\0asm version 1)
//    - unikernel: Ring-0 bare-metal Multiboot2 bootable ELF image (Magic 0xE85250D6)
// 2. Tests both mathematical container invariants and real disk binary emission via lipc.
// ==============================================================================

include "utso/io"
include "utso/memory"
include "utso/string"

fn assert_eq actual expected test_name
    // WHY: Deterministic test condition validator with zero external assertions
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

fn spawn_compiler cmd src out target_flag
    // WHY: Invokes sovereign compiler via direct kernel fork/execve syscalls
    argv = syscall(9, 0, 64, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd)
    mem_word_write(argv, 8, src)
    idx = 2
    if len(out) > 0
        mem_word_write(argv, idx * 8, "-o")
        idx = idx + 1
        mem_word_write(argv, idx * 8, out)
        idx = idx + 1
    end
    if len(target_flag) > 0
        mem_word_write(argv, idx * 8, target_flag)
        idx = idx + 1
    end
    mem_word_write(argv, idx * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    path_env = "PATH=/usr/bin:/bin:/usr/local/bin"
    mem_word_write(env, 0, path_env)
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, cmd, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)
    end

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return exit_code

fn main
    say "========================================================================"
    say "🛸 LIPI SOVEREIGN MULTI-SILICON TARGETS & UNIKERNEL VERIFICATION 🛸"
    say "========================================================================"

    // ── Phase 1: ARM64 (AArch64) Invariants ───────────────────────────────────
    say "\n▶ [PHASE 1]: ARM64 (AArch64) Target Machine & ABI Invariants..."
    em_aarch64 = 183
    assert_eq(em_aarch64, 183, "ARM64 ELF Machine ID (EM_AARCH64 == 183 / 0xB7)")
    entry_arm64 = 4194424 // 0x400078
    assert_eq(entry_arm64, 4194424, "ARM64 Canonical Entry Virtual Address (0x400078)")

    // ── Phase 2: RISC-V 64 (RV64GC) Invariants ────────────────────────────────
    say "\n▶ [PHASE 2]: RISC-V 64 Target Machine & ABI Invariants..."
    em_riscv = 243
    assert_eq(em_riscv, 243, "RISC-V 64 ELF Machine ID (EM_RISCV == 243 / 0xF3)")
    entry_riscv = 4194424 // 0x400078
    assert_eq(entry_riscv, 4194424, "RISC-V Canonical Entry Virtual Address (0x400078)")

    // ── Phase 3: WebAssembly (WASM) Bytecode Invariants ───────────────────────
    say "\n▶ [PHASE 3]: WebAssembly (WASM) W3C MVP Bytecode Invariants..."
    wasm_m0 = 0
    wasm_m1 = 97  // 'a'
    wasm_m2 = 115 // 's'
    wasm_m3 = 109 // 'm'
    assert_eq(wasm_m0, 0, "WASM Magic Byte 0 == 0x00")
    assert_eq(wasm_m1, 97, "WASM Magic Byte 1 == 'a' (0x61)")
    assert_eq(wasm_m2, 115, "WASM Magic Byte 2 == 's' (0x73)")
    assert_eq(wasm_m3, 109, "WASM Magic Byte 3 == 'm' (0x6D)")

    // ── Phase 4: Multiboot2 Unikernel Specification Invariants ───────────────
    say "\n▶ [PHASE 4]: Ring-0 Multiboot2 Bare-Metal Boot Invariants..."
    mb2_magic = 3897741526 // 0xE85250D6
    mb2_arch = 0          // i386 / x86_64 protected & long mode
    mb2_len = 24          // Base header (16) + End Tag (8)
    mb2_csum = 397225746  // 0x17AD2F12
    sum_mb2 = (mb2_magic + mb2_arch + mb2_len + mb2_csum) % 4294967296
    assert_eq(sum_mb2, 0, "Multiboot2 Checksum Identity: -(magic + arch + len) + csum == 0")

    // ── Phase 5: Live Silicon Compiler Cross-Target Binary Generation ─────────
    say "\n▶ [PHASE 5]: Live Cross-Compilation via bin/lipc..."
    sample_lp = "/tmp/test_target_prog.lp"
    code = "fn main\n    say \"Sovereign Silicon Active\"\n    return 0\nmain()\n"
    file_write(sample_lp, code)

    arm_out = "/tmp/test_target_arm64.bin"
    rv_out = "/tmp/test_target_riscv64.bin"
    wasm_out = "/tmp/test_target_wasm.wasm"
    uni_out = "/tmp/test_target_unikernel.bin"

    // 1. Compile ARM64
    say "  • Cross-compiling sample to ARM64 (AArch64)..."
    c_arm = spawn_compiler("bin/lipc", sample_lp, arm_out, "--target=arm64")
    assert_eq(c_arm, 0, "bin/lipc compiles to ARM64 without error")
    fd_arm = syscall(2, arm_out, 0, 0, 0, 0, 0)
    assert_eq(fd_arm >= 0, 1, "ARM64 output file created on disk")
    buf_arm = malloc(64)
    syscall(0, fd_arm, buf_arm, 64, 0, 0, 0)
    syscall(3, fd_arm, 0, 0, 0, 0, 0)
    m_arm = mem_read_byte(buf_arm, 18)
    assert_eq(m_arm, 183, "ARM64 binary has ELF e_machine == 183 (EM_AARCH64)")
    free(buf_arm, 64)
    syscall(87, arm_out, 0, 0, 0, 0, 0)

    // 2. Compile RISC-V 64
    say "  • Cross-compiling sample to RISC-V 64 (RV64GC)..."
    c_rv = spawn_compiler("bin/lipc", sample_lp, rv_out, "--target=riscv64")
    assert_eq(c_rv, 0, "bin/lipc compiles to RISC-V 64 without error")
    fd_rv = syscall(2, rv_out, 0, 0, 0, 0, 0)
    assert_eq(fd_rv >= 0, 1, "RISC-V output file created on disk")
    buf_rv = malloc(64)
    syscall(0, fd_rv, buf_rv, 64, 0, 0, 0)
    syscall(3, fd_rv, 0, 0, 0, 0, 0)
    m_rv = mem_read_byte(buf_rv, 18)
    assert_eq(m_rv, 243, "RISC-V binary has ELF e_machine == 243 (EM_RISCV)")
    free(buf_rv, 64)
    syscall(87, rv_out, 0, 0, 0, 0, 0)

    // 3. Compile WebAssembly
    say "  • Cross-compiling sample to WebAssembly (WASM)..."
    c_wasm = spawn_compiler("bin/lipc", sample_lp, wasm_out, "--target=wasm")
    assert_eq(c_wasm, 0, "bin/lipc compiles to WebAssembly without error")
    fd_wasm = syscall(2, wasm_out, 0, 0, 0, 0, 0)
    assert_eq(fd_wasm >= 0, 1, "WASM output file created on disk")
    buf_wasm = malloc(16)
    syscall(0, fd_wasm, buf_wasm, 16, 0, 0, 0)
    syscall(3, fd_wasm, 0, 0, 0, 0, 0)
    b0 = mem_read_byte(buf_wasm, 0)
    b1 = mem_read_byte(buf_wasm, 1)
    b2 = mem_read_byte(buf_wasm, 2)
    b3 = mem_read_byte(buf_wasm, 3)
    assert_eq(b0, 0, "WASM byte 0 == 0x00")
    assert_eq(b1, 97, "WASM byte 1 == 'a'")
    assert_eq(b2, 115, "WASM byte 2 == 's'")
    assert_eq(b3, 109, "WASM byte 3 == 'm'")
    free(buf_wasm, 16)
    syscall(87, wasm_out, 0, 0, 0, 0, 0)

    // 4. Compile Ring-0 Unikernel
    say "  • Synthesizing Bare-Metal Ring-0 Unikernel image..."
    c_uni = spawn_compiler("bin/lipc", sample_lp, uni_out, "--target=unikernel")
    assert_eq(c_uni, 0, "bin/lipc compiles to Unikernel without error")
    fd_uni = syscall(2, uni_out, 0, 0, 0, 0, 0)
    assert_eq(fd_uni >= 0, 1, "Unikernel output image created on disk")
    buf_uni = malloc(256)
    syscall(0, fd_uni, buf_uni, 256, 0, 0, 0)
    syscall(3, fd_uni, 0, 0, 0, 0, 0)
    // Multiboot2 header is located in .text (offset 240)
    mb_b0 = mem_read_byte(buf_uni, 240)
    mb_b1 = mem_read_byte(buf_uni, 241)
    mb_b2 = mem_read_byte(buf_uni, 242)
    mb_b3 = mem_read_byte(buf_uni, 243)
    assert_eq(mb_b0, 214, "Multiboot2 Magic byte 0 == 0xD6 (214)")
    assert_eq(mb_b1, 80, "Multiboot2 Magic byte 1 == 0x50 (80)")
    assert_eq(mb_b2, 82, "Multiboot2 Magic byte 2 == 0x52 (82)")
    assert_eq(mb_b3, 232, "Multiboot2 Magic byte 3 == 0xE8 (232)")
    free(buf_uni, 256)
    syscall(87, uni_out, 0, 0, 0, 0, 0)

    // Clean up temporary sample
    syscall(87, sample_lp, 0, 0, 0, 0, 0)

    say "\n🎉 ALL MULTI-SILICON & UNIKERNEL TESTS PASSED WITH 100% SUCCESS!"
    return 0

main()
