// ==============================================================================
// 🧪 LIPI TEST: Multi-Architecture Silicon Sovereignty (x86_64, ARM64, WASM)
// ⚡ Tests direct machine code synthesis across multiple processor targets:
//    1. x86_64 Linux ELF64 (EM_X86_64 = 62)
//    2. ARM64 / AArch64 Linux ELF64 (EM_AARCH64 = 183)
//    3. W3C WebAssembly WASM Module (Magic: 0x00 0x61 0x73 0x6D, Version 1)
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

fn malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

// Helper: executes command via fork + execve
fn exec_cmd cmd_str
    sh = "/bin/sh"
    flag = "-c"
    argv = malloc(32)
    mem_word_write(argv, 0, sh)
    mem_word_write(argv, 8, flag)
    mem_word_write(argv, 16, cmd_str)
    mem_word_write(argv, 24, 0)

    env = malloc(8)
    mem_word_write(env, 0, 0)

    st = malloc(8)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, sh, argv, env, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    free(argv, 32)
    free(env, 8)
    free(st, 8)
    return exit_code

say "========================================================"
say "👑 Testing Lipi Multi-Architecture Target Synthesis"
say "========================================================"

in_src = "tests/51_minimal_hello.lp"
out_x86 = "dist/test_target_x86"
out_arm = "dist/test_target_arm64"
out_wasm = "dist/test_target.wasm"

// ── Test 1: x86_64 Direct Linux ELF64 Emitter ─────────────────────────────────
say "[1/3] Testing Linux x86_64 ELF64 Target Compilation..."
cmd1 = "./bin/lipc --target=x86_64 " + in_src + " -o " + out_x86
rc1 = exec_cmd(cmd1)
assert_eq(rc1, 0, "x86_64 compilation exited with status 0")

// Read 64-byte ELF header of generated binary
fd1 = syscall(2, out_x86, 0, 0, 0, 0, 0) // O_RDONLY = 0
hdr1 = malloc(64)
syscall(0, fd1, hdr1, 64, 0, 0, 0)
syscall(3, fd1, 0, 0, 0, 0, 0)

m0 = mem_byte_read(hdr1, 0)
m1 = mem_byte_read(hdr1, 1)
m2 = mem_byte_read(hdr1, 2)
m3 = mem_byte_read(hdr1, 3)
assert_eq(m0, 127, "x86_64 ELF magic byte 0 is 0x7F")
assert_eq(m1, 69, "x86_64 ELF magic byte 1 is 'E'")
assert_eq(m2, 76, "x86_64 ELF magic byte 2 is 'L'")
assert_eq(m3, 70, "x86_64 ELF magic byte 3 is 'F'")

e_mach_lo = mem_byte_read(hdr1, 18) // e_machine offset 18
e_mach_hi = mem_byte_read(hdr1, 19)
e_mach = e_mach_lo + (e_mach_hi * 256)
assert_eq(e_mach, 62, "ELF Machine architecture is EM_X86_64 (62)")
free(hdr1, 64)

// ── Test 2: ARM64 (AArch64) Direct Linux ELF64 Emitter ────────────────────────
say "[2/3] Testing Linux AArch64 (ARM64) ELF64 Target Compilation..."
cmd2 = "./bin/lipc --target=arm64 " + in_src + " -o " + out_arm
rc2 = exec_cmd(cmd2)
assert_eq(rc2, 0, "ARM64 compilation exited with status 0")

fd2 = syscall(2, out_arm, 0, 0, 0, 0, 0)
hdr2 = malloc(64)
syscall(0, fd2, hdr2, 64, 0, 0, 0)
syscall(3, fd2, 0, 0, 0, 0, 0)

am0 = mem_byte_read(hdr2, 0)
am1 = mem_byte_read(hdr2, 1)
am2 = mem_byte_read(hdr2, 2)
am3 = mem_byte_read(hdr2, 3)
assert_eq(am0, 127, "ARM64 ELF magic byte 0 is 0x7F")
assert_eq(am1, 69, "ARM64 ELF magic byte 1 is 'E'")
assert_eq(am2, 76, "ARM64 ELF magic byte 2 is 'L'")
assert_eq(am3, 70, "ARM64 ELF magic byte 3 is 'F'")

arm_mach_lo = mem_byte_read(hdr2, 18)
arm_mach_hi = mem_byte_read(hdr2, 19)
arm_mach = arm_mach_lo + (arm_mach_hi * 256)
assert_eq(arm_mach, 183, "ELF Machine architecture is EM_AARCH64 (183)")
free(hdr2, 64)

// ── Test 3: WebAssembly (WASM) Target Synthesis ───────────────────────────────
say "[3/3] Testing W3C WebAssembly (WASM) Target Compilation..."
cmd3 = "./bin/lipc --target=wasm " + in_src + " -o " + out_wasm
rc3 = exec_cmd(cmd3)
assert_eq(rc3, 0, "WASM compilation exited with status 0")

fd3 = syscall(2, out_wasm, 0, 0, 0, 0, 0)
hdr3 = malloc(8)
syscall(0, fd3, hdr3, 8, 0, 0, 0)
syscall(3, fd3, 0, 0, 0, 0, 0)

wm0 = mem_byte_read(hdr3, 0)
wm1 = mem_byte_read(hdr3, 1)
wm2 = mem_byte_read(hdr3, 2)
wm3 = mem_byte_read(hdr3, 3)
assert_eq(wm0, 0, "WASM Magic byte 0 is 0x00")
assert_eq(wm1, 97, "WASM Magic byte 1 is 'a'")
assert_eq(wm2, 115, "WASM Magic byte 2 is 's'")
assert_eq(wm3, 109, "WASM Magic byte 3 is 'm'")

wv0 = mem_byte_read(hdr3, 4)
assert_eq(wv0, 1, "WASM Specification Version is 1")
free(hdr3, 8)

say "========================================================"
say "PASS: Lipi Multi-Architecture Target Synthesis Verified 100%!"
say "========================================================"
