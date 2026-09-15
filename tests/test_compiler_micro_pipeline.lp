// ==============================================================================
// 👑 LIPI COMPILER TEST: UNIFIED MODULAR MICRO-PIPELINE & DRIVER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Sovereign Micro-Architecture Verification
// 🏛️ File: tests/test_compiler_micro_pipeline.lp
// ==============================================================================

include "src/compiler/driver.lp"

fn test_assert condition msg
    if condition == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    else
        say "  ✔ PASS: " + msg
    return 1

fn main
    compiler_driver_print_banner()

    say "\n[Test 1]: End-to-End Modular Pipeline Execution (O0 Debug Mode)..."
    res_o0 = compiler_driver_compile_string("test_o0.lp", "fn main\n    say \"Hello\"\n    return 0\n", TARGET_ID_X86_64, 0)
    test_assert(res_o0.res_success == 1, "O0 compilation pipeline succeeded")
    test_assert(res_o0.res_stage_reached == PIPELINE_STAGE_COMPLETE, "Reached PIPELINE_STAGE_COMPLETE")
    test_assert(res_o0.res_output_bytes == 64, "Generated 64-byte standard ELF64 header")
    test_assert(res_o0.res_tokens_scanned > 0, "Tokens scanned > 0")

    say "\n[Test 2]: End-to-End Modular Pipeline with O2 Optimization Level..."
    res_o2 = compiler_driver_compile_string("test_o2.lp", "fn compute x\n    a = 10 + 20\n    return a\n", TARGET_ID_X86_64, 2)
    test_assert(res_o2.res_success == 1, "O2 compilation pipeline succeeded")

    say "\n[Test 3]: Cross-Target Architecture Selection (ARM64, WASM, RISC-V)..."
    res_arm = compiler_driver_compile_string("test_arm.lp", "fn main\n    return 1\n", TARGET_ID_ARM64, 1)
    test_assert(res_arm.res_success == 1, "ARM64 target pipeline succeeded")

    res_wasm = compiler_driver_compile_string("test_wasm.lp", "fn main\n    return 1\n", TARGET_ID_WASM, 1)
    test_assert(res_wasm.res_success == 1, "WASM target pipeline succeeded")

    res_riscv = compiler_driver_compile_string("test_riscv.lp", "fn main\n    return 1\n", TARGET_ID_RISCV64, 1)
    test_assert(res_riscv.res_success == 1, "RISC-V target pipeline succeeded")

    say "\n[Test 4]: Lexical Error Detection on Empty Source..."
    res_err = compiler_driver_compile_string("test_empty.lp", "   \n\t  ", TARGET_ID_X86_64, 0)
    test_assert(res_err.res_success == 0, "Empty source caught as compilation error")
    test_assert(res_err.res_stage_reached == PIPELINE_STAGE_LEX, "Stopped at PIPELINE_STAGE_LEX")

    say "\n========================================================================"
    say "🎉 ALL COMPILER MICRO-PIPELINE & DRIVER TESTS PASSED (100% SOVEREIGN)!"
    say "========================================================================"
    return 0

main()
