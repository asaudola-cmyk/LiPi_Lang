// ==============================================================================
// 🧪 LIPI TEST 68: Client-Side WebAssembly Runner & Worker Suite
// ⚡ Direct Verification of apps/website/public/wasm_runner.js & lipi_worker.js
// 🏛️ File: tests/68_wasm_client_runner.lp
//
// WHY: Validates the client-side JavaScript execution runtime (wasm_runner.js)
//      and dedicated WebWorker (lipi_worker.js) directly from a sovereign Lipi test
//      program. Synthesizes a bit-exact WebAssembly binary, writes it to disk,
//      and invokes the automated verification test harness.
// ==============================================================================

include "src/compiler/wasm_emitter.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

// Spawns a shell command via Linux SYS_fork (57) and SYS_execve (59)
// WHY: Executes external test verification harness directly via Linux kernel syscalls.
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
    say "║  🧪 LIPI TEST 68: Client-Side WebAssembly Runner & Worker Suite        ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    // ──────────────────────────────────────────────────────────────────────────
    // [Step 1]: Ensure Fresh WebAssembly Binary is Emitted to /tmp/test.wasm
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Step 1]: Compiling Sovereign WebAssembly Module..."
    mod = wasm_module_new()

    f_add = wasm_compile_function_add(mod)
    f_sub = wasm_compile_function_sub(mod)
    f_mul = wasm_compile_function_mul(mod)
    f_div = wasm_compile_function_div_s(mod)
    f_fib = wasm_compile_function_fib(mod)
    f_main = wasm_compile_function_main(mod, f_add)

    out_wasm_path = "/tmp/test.wasm"
    write_res = wasm_module_write(mod, out_wasm_path)
    test_assert_eq(write_res, 0, "WASM binary compiled and written to /tmp/test.wasm")

    // ──────────────────────────────────────────────────────────────────────────
    // [Step 2]: Execute JavaScript Test Harness (wasm_runner.js + lipi_worker.js)
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Step 2]: Invoking tests/test_wasm_runner.js via Node.js..."
    test_cmd = "node tests/test_wasm_runner.js"
    exit_code = run_shell_command(test_cmd)
    test_assert_eq(exit_code, 0, "All wasm_runner.js and lipi_worker.js checks passed (exit code 0)")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL CLIENT-SIDE WASM ENGINE INVARIANTS PASS BIT-EXACT!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 68 WASM Client Runner"
    return 0

main()
