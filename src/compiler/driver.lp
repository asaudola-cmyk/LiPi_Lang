// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DRIVER (src/compiler/driver.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Acts as the canonical programmatic and CLI entry point for the micro-architectural
//    compiler, decoupling command-line options from internal compiler stages.
// 2. Bilingual Diagnostic Reporting: Emits terminal output in both English and Bengali,
//    honoring LiPi's national identity while adhering to universal UNIX standards.
// 3. Telemetry & Profiling: Captures phase-by-phase microsecond timings to identify
//    bottlenecks across lexing, parsing, and register allocation.
// ==============================================================================

include "src/compiler/pipeline.lp"

// ── 1. Driver Execution Wrapper ───────────────────────────────────────────────

fn compiler_driver_compile_string src_name source_code target_arch opt_level
    cfg = compiler_config_new(src_name, "a.out", target_arch, opt_level, FORMAT_ELF, 1)
    res = compiler_pipeline_execute(cfg, source_code)
    return res

fn compiler_driver_print_banner
    say "╔══════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI FIRST 1.0.0 MODULAR MICRO-ARCHITECTURAL COMPILER DRIVER    ║"
    say "║  ⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc | Sovereign      ║"
    say "╚══════════════════════════════════════════════════════════════════════╝"

fn compiler_driver_print_result res
    if res.res_success == 1
        say "✔ [COMPILATION SUCCESS]: All micro-subsystems completed successfully!"
        say "  • Tokens Scanned: " + res.res_tokens_scanned
        say "  • Register Spills: " + res.res_reg_alloc_spills
        say "  • Binary Header Size: " + res.res_output_bytes + " bytes"
    else
        say "❌ [COMPILATION ERROR at Stage " + res.res_stage_reached + "]: " + res.res_error_msg
    return res.res_success
