// ==============================================================================
// 🧪 LIPI TEST 68: Sovereign Web/Bytecode Native Runner & Worker Suite
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Node.js | Zero .js Dependencies
// 🏛️ File: tests/68_wasm_client_runner.lp
//
// WHY: Validates the sovereign native execution runtime (sovereign_runner.lp)
//      and virtual machine (sovereign_vm.lp) directly from a sovereign Lipi test
//      program. Synthesizes a bit-exact WebAssembly binary, writes it to disk,
//      and validates exported arithmetic, linear memory, and UTF-8 string decoding
//      with zero reliance on external JavaScript or Node.js runtimes.
// ==============================================================================

include "src/compiler/wasm_emitter.lp"
include "src/runtime/wasm/sovereign_runner.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name
    return 1

fn test_assert_str actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + expected
        say "     Actual:   " + actual
        exit(1)
    say "  ✔ PASS: " + test_name
    return 1

fn main
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  🧪 LIPI TEST 68: Sovereign Web/Bytecode Native Runner Verification    ║"
    say "║  ⚡ 100% Pure Silicon Machine Code | 0% Node.js | 0% JS | Sovereign    ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

    // ──────────────────────────────────────────────────────────────────────────
    // [Step 1]: Synthesize & Emit WebAssembly Binary to Disk
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
    // [Step 2]: Execute Sovereign Native Runner (0% JS / 0% Node.js)
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Step 2]: Instantiating Sovereign Native Runner (src/runtime/wasm/sovereign_runner.lp)..."
    runner = sovereign_runner_new()
    test_assert_eq(runner.sr_is_instantiated, 1, "Sovereign runner successfully instantiated")
    test_assert_eq(runner.sr_export_count, 6, "All 6 exported functions registered")

    // ──────────────────────────────────────────────────────────────────────────
    // [Step 3]: Mathematical Function Verification
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Step 3]: Validating Bit-Exact Mathematical Exports..."
    r_add = sovereign_runner_add(runner, 10, 32)
    test_assert_eq(r_add, 42, "Exported add(10, 32) == 42")

    r_sub = sovereign_runner_sub(runner, 50, 8)
    test_assert_eq(r_sub, 42, "Exported sub(50, 8) == 42")

    r_mul = sovereign_runner_mul(runner, 6, 7)
    test_assert_eq(r_mul, 42, "Exported mul(6, 7) == 42")

    r_div = sovereign_runner_div_s(runner, 84, 2)
    test_assert_eq(r_div, 42, "Exported div_s(84, 2) == 42")

    r_fib = sovereign_runner_fib(runner, 10)
    test_assert_eq(r_fib, 55, "Exported fib(10) == 55")

    r_main = sovereign_runner_main(runner)
    test_assert_eq(r_main, 42, "Exported main() == 42")

    // ──────────────────────────────────────────────────────────────────────────
    // [Step 4]: Linear Memory UTF-8 Inspection & Unicode Decoding
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Step 4]: Linear Memory Inspection (ASCII & Bengali Unicode Runes)..."
    ascii_sample = "Lipi-First-1.0.0"
    sovereign_runner_write_utf8(runner, 0, ascii_sample)
    decoded_ascii = sovereign_runner_decode_utf8(runner, 0, len(ascii_sample))
    test_assert_str(decoded_ascii, ascii_sample, "Linear memory decodes ASCII string")

    bengali_sample = "লিপি"
    sovereign_runner_write_utf8(runner, 32, bengali_sample)
    decoded_bengali = sovereign_runner_decode_utf8(runner, 32, len(bengali_sample))
    test_assert_str(decoded_bengali, bengali_sample, "Linear memory decodes Bengali Unicode runes 'লিপি'")

    sovereign_runner_free(runner)

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL SOVEREIGN RUNNER INVARIANTS PASS (0% JS / 0% NODE.JS)!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 68 WASM Client Runner"
    return 0

main()
