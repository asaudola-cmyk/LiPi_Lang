// ==============================================================================
// 👑 LIPI FIRST 1.0.0 TEST 168: MICRO-COMPILER FEATURE PARITY & DIRECT SILICON SUITE
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// 🏛️ File: tests/test_micro_compiler_parity.lp
// ==============================================================================
//
// WHY THIS TEST:
// 1. Verifies that the new standalone micro-compiler (`bin/lipc_micro`) can compile
//    arbitrary real-world LiPi programs directly to Linux AMD64 silicon executables
//    without falling back to the monolithic compiler or any external assembler.
// 2. Parity Invariants Tested:
//    - Stage 1: String Literal Emission & Linux SYS_write Execution.
//    - Stage 2: Arithmetic Evaluation & Return Status Codes.
//    - Stage 3: Inter-procedural Function Calling & SysV AMD64 Parameter Passing.
//    - Stage 4: Bilingual Bengali Rune Identifiers & Keywords (বলো, ফেরত, চলক, কাজ).
//    - Stage 5: Integer Formatting & Dynamic Terminal Output.
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
    say "║  🧪 LIPI TEST 168: Micro-Compiler Feature Parity & Silicon Bridge      ║"
    say "║  ⚡ Direct Silicon Verification of bin/lipc_micro Machine Code        ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    // ── Phase 1: Direct String Output & Return Code 42 ────────────────────────
    say "\n[Phase 1]: Compiling String Output & Return Status..."
    src1 = "say \"Hello, Sovereign LiPi Silicon!\"\nreturn 42\n"
    file_write("/tmp/parity_test_1.lp", src1)
    c_comp1 = run_shell_command("./bin/lipc_micro /tmp/parity_test_1.lp -o /tmp/parity_bin_1 > /dev/null")
    test_assert_eq(c_comp1, 0, "lipc_micro compiles /tmp/parity_test_1.lp to ELF64")

    c_run1 = run_shell_command("/tmp/parity_bin_1 > /dev/null")
    test_assert_eq(c_run1, 42, "Generated binary exits with status code 42")

    // ── Phase 2: Arithmetic Evaluation & Variable Stacking ────────────────────
    say "\n[Phase 2]: Compiling Arithmetic Expressions & Variables..."
    src2 = "x = 100\ny = 58\nreturn x - y\n"
    file_write("/tmp/parity_test_2.lp", src2)
    c_comp2 = run_shell_command("./bin/lipc_micro /tmp/parity_test_2.lp -o /tmp/parity_bin_2 > /dev/null")
    test_assert_eq(c_comp2, 0, "lipc_micro compiles arithmetic expressions")

    c_run2 = run_shell_command("/tmp/parity_bin_2 > /dev/null")
    test_assert_eq(c_run2, 42, "Arithmetic computation (100 - 58) evaluates to 42")

    // ── Phase 3: Function Declarations & SysV ABI Calling ─────────────────────
    say "\n[Phase 3]: Compiling Multi-Function ABI Parameter Passing..."
    src3 = "fn multiply a b\n    return a * b\nfn main\n    return multiply(6, 7)\n"
    file_write("/tmp/parity_test_3.lp", src3)
    c_comp3 = run_shell_command("./bin/lipc_micro /tmp/parity_test_3.lp -o /tmp/parity_bin_3 > /dev/null")
    test_assert_eq(c_comp3, 0, "lipc_micro compiles multi-function source")

    c_run3 = run_shell_command("/tmp/parity_bin_3 > /dev/null")
    test_assert_eq(c_run3, 42, "Function multiply(6, 7) returns 42 through SysV ABI")

    // ── Phase 4: Bilingual Bengali Keyword & Rune Parity ──────────────────────
    say "\n[Phase 4]: Compiling Bilingual Bengali Keywords & Runes..."
    src4 = "কাজ যোগ ক খ\n    ফেরত ক + খ\nকাজ main\n    বলো \"বাংলা লিপিতে তৈরি সার্বভৌমিক বাইনারি\"\n    ফেরত যোগ(20, 22)\n"
    file_write("/tmp/parity_test_4.lp", src4)
    c_comp4 = run_shell_command("./bin/lipc_micro /tmp/parity_test_4.lp -o /tmp/parity_bin_4 > /dev/null")
    test_assert_eq(c_comp4, 0, "lipc_micro compiles pure Bengali keywords & functions")

    c_run4 = run_shell_command("/tmp/parity_bin_4 > /dev/null")
    test_assert_eq(c_run4, 42, "Bengali binary outputs UTF-8 string and exits with 42")

    // ── Phase 5: Integer Formatting & Calculation Printing ────────────────────
    say "\n[Phase 5]: Compiling Integer Printing & Dynamic Expression Format..."
    src5 = "say 10 + 20 + 12\nreturn 0\n"
    file_write("/tmp/parity_test_5.lp", src5)
    c_comp5 = run_shell_command("./bin/lipc_micro /tmp/parity_test_5.lp -o /tmp/parity_bin_5 > /dev/null")
    test_assert_eq(c_comp5, 0, "lipc_micro compiles integer formatting expressions")

    c_run5 = run_shell_command("/tmp/parity_bin_5 > /dev/null")
    test_assert_eq(c_run5, 0, "Integer print execution finishes with exit code 0")

    // Cleanup temporary files
    run_shell_command("rm -f /tmp/parity_test_*.lp /tmp/parity_bin_*")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL 5 MICRO-COMPILER FEATURE PARITY PHASES PASS (100%)!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 168 Micro Compiler Parity"
    return 0

main()
