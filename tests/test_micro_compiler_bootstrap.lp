// ==============================================================================
// 👑 LIPI FIRST 1.0.0 TEST 167: STANDALONE SOVEREIGN MICRO-COMPILER BOOTSTRAP
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// 🏛️ File: tests/test_micro_compiler_bootstrap.lp
// ==============================================================================

include "universe/core/memory.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name
    return 1

fn run_shell_command cmd_str
    sh_path = "/bin/sh"
    sh_flag = "-c"

    argv = malloc(32)
    mem_word_write(argv, 0, sh_path)
    mem_word_write(argv, 8, sh_flag)
    mem_word_write(argv, 16, cmd_str)
    mem_word_write(argv, 24, 0)

    env = malloc(8)
    mem_word_write(env, 0, 0)

    st = malloc(8)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        syscall(59, sh_path, argv, env, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    free(argv, 32)
    free(env, 8)
    free(st, 8)

    return exit_code

fn main
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  🧪 LIPI TEST 167: Standalone Sovereign Micro-Compiler Bootstrap Suite ║"
    say "║  ⚡ Direct Verification of bin/lipc_micro Executable & Multi-Target     ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    say "\n[Step 1]: Verifying bin/lipc_micro --version..."
    c_ver = run_shell_command("./bin/lipc_micro --version > /dev/null")
    test_assert_eq(c_ver, 0, "lipc_micro --version exits with code 0")

    say "\n[Step 2]: Verifying bin/lipc_micro --help..."
    c_help = run_shell_command("./bin/lipc_micro --help > /dev/null")
    test_assert_eq(c_help, 0, "lipc_micro --help exits with code 0")

    say "\n[Step 3]: Stage 1 Compilation of 01_hello.lp via bin/lipc_micro..."
    c_comp = run_shell_command("./bin/lipc_micro tests/01_hello.lp -o /tmp/lipi_test_stage1_bin > /dev/null")
    test_assert_eq(c_comp, 0, "lipc_micro compiles tests/01_hello.lp to native ELF64")

    say "\n[Step 4]: Stage 2 Direct Execution of Compiled Binary..."
    c_exec = run_shell_command("/tmp/lipi_test_stage1_bin > /dev/null")
    test_assert_eq(c_exec, 0, "Generated ELF64 binary executes successfully (exit code 0)")

    say "\n[Step 5]: Multi-Target Cross-Compilation (ARM64, WASM, RISC-V)..."
    c_arm = run_shell_command("./bin/lipc_micro --target=arm64 tests/01_hello.lp -o /tmp/lipi_test_arm64.bin > /dev/null")
    test_assert_eq(c_arm, 0, "ARM64 cross-compilation pipeline succeeds")

    c_wasm = run_shell_command("./bin/lipc_micro --target=wasm tests/01_hello.lp -o /tmp/lipi_test_wasm.wasm > /dev/null")
    test_assert_eq(c_wasm, 0, "WASM cross-compilation pipeline succeeds")

    c_riscv = run_shell_command("./bin/lipc_micro --target=riscv64 tests/01_hello.lp -o /tmp/lipi_test_riscv.bin > /dev/null")
    test_assert_eq(c_riscv, 0, "RISC-V cross-compilation pipeline succeeds")

    say "\n[Step 6]: Graceful Error Handling on Missing Source File..."
    c_err = run_shell_command("./bin/lipc_micro non_existent_file.lp -o /tmp/should_fail.bin 2> /dev/null > /dev/null")
    test_assert_eq(c_err, 1, "Missing input file gracefully caught with exit code 1")

    // Cleanup temporary files
    run_shell_command("rm -f /tmp/lipi_test_stage1_bin /tmp/lipi_test_arm64.bin /tmp/lipi_test_wasm.wasm /tmp/lipi_test_riscv.bin")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL SOVEREIGN MICRO-COMPILER BOOTSTRAP INVARIANTS PASS (100%)!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 167 Micro Compiler Bootstrap"
    return 0

main()
