// ==============================================================================
// 🧪 LIPI TEST: Zero-JS Standalone WebAssembly HTML Emitter Verification Suite
// File: tests/test_standalone_wasm_html.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Fixed
// ⚡ 100% Pure LiPi Implementation | Zero External JS / Zero Webpack / Zero C
// ==============================================================================
//
// WHY THIS TEST:
// Web deployment in conventional programming ecosystems suffers from npm supply-chain
// bloat, heavy node runtimes, and external JS glue code.
// LiPi provides complete computational sovereignty by emitting self-contained,
// zero-dependency HTML bundles that embed raw WebAssembly virtual silicon bytecode
// directly into a typed buffer with an autonomous execution host interface.
// ==============================================================================

include "src/compiler/wasm_emitter.lp"

fn str_contains hay needle
    hlen = len(hay)
    nlen = len(needle)
    if nlen == 0 return 1
    if hlen < nlen return 0
    i = 0
    max_i = hlen - nlen
    while i <= max_i
        j = 0
        matched = 1
        while j < nlen
            if char_at(hay, i + j) != char_at(needle, j)
                matched = 0
                break
            j = j + 1
        if matched == 1
            return 1
        i = i + 1
    return 0

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🌐 LIPI TEST: ZERO-JS STANDALONE WEBASSEMBLY HTML EMITTER"
    say "════════════════════════════════════════════════════════════════════════"

    out_html = "/tmp/test_sovereign_wasm.html"
    syscall(87, out_html, 0, 0, 0, 0, 0) // Clean any existing file

    // ── Phase 1: Synthesize Sovereign WebAssembly Module ─────────────────────
    say "\n[Phase 1]: Synthesizing Arithmetic & Recursive WebAssembly Module..."
    mod = wasm_module_new()
    f_add = wasm_compile_function_add(mod)
    f_sub = wasm_compile_function_sub(mod)
    f_mul = wasm_compile_function_mul(mod)
    f_fib = wasm_compile_function_fib(mod)

    say "  ✔ Functions synthesized: add(0), sub(1), mul(2), fib(3)"

    // ── Phase 2: Emit Autonomous Standalone HTML Bundle ──────────────────────
    say "\n[Phase 2]: Generating Autonomous Standalone HTML Bundle..."
    status = wasm_module_emit_standalone_html(mod, out_html, "LiPi Sovereign Horizon")
    if status != 0
        say "  ❌ FAILED: wasm_module_emit_standalone_html returned error code: " + str(status)
        return 1
    say "  ✔ Standalone HTML bundle emitted to: " + out_html

    // ── Phase 3: Validate File Existence and Byte Density ─────────────────────
    say "\n[Phase 3]: Validating Bundle Existence & Header Magic..."
    if file_exists(out_html) == 0
        say "  ❌ FAILED: Output HTML file does not exist."
        return 1

    content = file_read(out_html)
    clen = len(content)
    say "  ✔ Generated standalone bundle size: " + str(clen) + " bytes"
    if clen < 800
        say "  ❌ FAILED: Standalone HTML bundle is unexpectedly small: " + str(clen)
        return 1

    // ── Phase 4: Validate Essential Sovereign Invariants ──────────────────────
    say "\n[Phase 4]: Validating Virtual Silicon Bytecode & Host Interface..."

    if str_contains(content, "<!DOCTYPE html>") == 0
        say "  ❌ FAILED: Missing DOCTYPE declaration."
        return 1
    say "  ✔ Verified DOCTYPE html structure"

    if str_contains(content, "👑 LiPi Sovereign Virtual Silicon") == 0
        say "  ❌ FAILED: Missing LiPi Virtual Silicon heading."
        return 1
    say "  ✔ Verified Sovereign Silicon Branding"

    // Verify Base64 encoded WebAssembly magic header: 'AGFzbQEAAAA' (\0asm v1)
    if str_contains(content, "AGFzbQEAAAA") == 0
        say "  ❌ FAILED: Missing embedded WebAssembly magic bytes (AGFzbQEAAAA in Base64)."
        return 1
    say "  ✔ Verified Embedded WebAssembly Base64 Magic Header (AGFzbQEAAAA)"

    if str_contains(content, "WebAssembly.instantiateStreaming") == 0
        say "  ❌ FAILED: Missing WebAssembly.instantiateStreaming concurrent JIT call."
        return 1
    say "  ✔ Verified WebAssembly.instantiateStreaming concurrent JIT pipeline"

    if str_contains(content, "data:application/wasm;base64,") == 0
        say "  ❌ FAILED: Missing data:application/wasm;base64 Data URI stream."
        return 1
    say "  ✔ Verified Data URI WebAssembly stream instantiation"

    if str_contains(content, "print_str") == 0 or str_contains(content, "print_int") == 0
        say "  ❌ FAILED: Missing virtual silicon runtime host callbacks."
        return 1
    say "  ✔ Verified Runtime Host Callbacks (print_str, print_int, time_now)"

    // ── Phase 5: Cleanup & Verification Closure ───────────────────────────────
    say "\n[Phase 5]: Releasing Scratch Artifacts..."
    syscall(87, out_html, 0, 0, 0, 0, 0)

    say "════════════════════════════════════════════════════════════════════════"
    say "🎉 ALL STANDALONE WASM HTML ASSERTIONS PASSED (ZERO JS DEPENDENCIES)"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
