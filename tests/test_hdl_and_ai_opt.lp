// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN TEST SUITE: HARDWARE HDL & AI OPTIMIZATION
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign R&D Parity
// 🏛️ File: tests/test_hdl_and_ai_opt.lp
// ==============================================================================
//
// WHY THIS TEST:
// 1. Verifies end-to-end integration of Verilog IEEE 1364-2001 hardware RTL synthesis.
// 2. Verifies neural network inference in middleend/ai_opt for loop unrolling & vectorization.
// 3. Verifies compiler CLI flags (--target=verilog, --ai-opt) and JIT execution (lipi run --jit).
// ==============================================================================

include "src/compiler/backend/targets/target_machine.lp"
include "src/compiler/middleend/ai_opt.lp"

fn test_assert cond msg
    if cond == 0
        say "  ❌ FAIL: " + msg
        exit(1)
    say "  ✔ PASS: " + msg
    return 1

fn contains_substr haystack needle
    h_len = len(haystack)
    n_len = len(needle)
    if n_len == 0 return 1
    if n_len > h_len return 0
    limit = h_len - n_len
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < n_len
            if char_at(haystack, i + j) != char_at(needle, j)
                match = 0
                j = n_len
            else
                j = j + 1
        if match == 1 return 1
        i = i + 1
    return 0

fn run_cmd cmd
    fd = syscall(2, "/tmp/cmd_test.sh", 577, 420, 0, 0, 0)
    if fd >= 0
        c_str = "#!/bin/sh\n" + cmd + "\n"
        syscall(1, fd, c_str, len(c_str), 0, 0, 0)
        syscall(3, fd, 0, 0, 0, 0, 0)
        code = syscall(57, 0, 0, 0, 0, 0, 0) // fork
        if code == 0
            // Child
            argv_buf = syscall(9, 0, 32, 3, 34, -1, 0)
            sh_path = "/bin/sh"
            arg_script = "/tmp/cmd_test.sh"
            mem_word_write(argv_buf, 0, sh_path)
            mem_word_write(argv_buf, 8, arg_script)
            mem_word_write(argv_buf, 16, 0)
            syscall(59, sh_path, argv_buf, 0, 0, 0, 0) // execve
            syscall(60, 127, 0, 0, 0, 0, 0)
        st = syscall(9, 0, 8, 3, 34, -1, 0)
        syscall(61, code, st, 0, 0, 0, 0) // wait4
        raw = mem_word_read(st, 0)
        syscall(11, st, 8, 0, 0, 0, 0)
        return (raw / 256) % 256
    return 1

fn read_text_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return ""
    buf = syscall(9, 0, 8192, 3, 34, -1, 0)
    out = ""
    while 1
        n = syscall(0, fd, buf, 8192, 0, 0, 0)
        if n <= 0 break
        i = 0
        while i < n
            out = out + chr(mem_byte_read(buf, i))
            i = i + 1
    syscall(3, fd, 0, 0, 0, 0, 0)
    syscall(11, buf, 8192, 0, 0, 0, 0)
    return out

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "👑 LIPI TEST: HARDWARE HDL & AI OPTIMIZATION PARITY"
    say "════════════════════════════════════════════════════════════════════════"

    // ── Phase 1: Target Machine Verilog Profile ──────────────────────────────
    say "\n[Phase 1]: Testing Verilog Target Machine Specification..."
    tm_v = target_machine_from_name("verilog")
    test_assert(tm_v.arch_id == TARGET_ID_VERILOG, "target_machine_from_name identifies verilog target")
    test_assert(tm_v.arch_name == "verilog", "Verilog architecture name string matches 'verilog'")
    test_assert(tm_v.num_int_registers == 64, "Verilog target allocates 64 hardware registers")

    // ── Phase 2: AI Neural Heuristic Optimization Model ──────────────────────
    say "\n[Phase 2]: Testing Middle-End AI Optimizer Neural Forward Pass..."
    weights = ai_opt_default_weights()
    test_assert(weights.layer1_weights.len() == 28, "Layer 1 weights has 7x4=28 parameters")
    test_assert(weights.layer2_weights.len() == 8, "Layer 2 weights has 4x2=8 parameters")

    // Compute decision for high-throughput loop
    feat = LoopFeatureVector(1000, 16, 4, 0, 1, 1, 0)
    decision = ai_opt_evaluate_loop(weights, feat)
    test_assert(decision.recommended_unroll_factor >= 2, "AI unroll heuristic predicts loop unroll factor >= 2")
    test_assert(decision.should_vectorize == 1, "AI vectorization heuristic recommends SIMD acceleration")
    test_assert(decision.predicted_speedup_pct > 100, "AI speedup prediction model indicates positive speedup")

    // ── Phase 3: Verilog RTL Silicon Synthesis CLI Integration ───────────────
    say "\n[Phase 3]: Testing Verilog RTL CLI Code Generation (--target=verilog)..."
    out_v = "/tmp/test_hdl_out.v"
    syscall(87, out_v, 0, 0, 0, 0, 0) // unlink
    c_code = run_cmd("./bin/lipc_micro --target=verilog tests/01_hello.lp -o " + out_v + " > /dev/null 2>&1")
    test_assert(c_code == 0, "lipc_micro --target=verilog executes cleanly with exit code 0")

    v_content = read_text_file(out_v)
    test_assert(len(v_content) > 100, "Generated Verilog file is non-empty")
    test_assert(contains_substr(v_content, "module lipi_01_hello"), "Verilog module header declares 'module lipi_01_hello'")
    test_assert(contains_substr(v_content, "input wire clk"), "Verilog module declares clock port 'input wire clk'")
    test_assert(contains_substr(v_content, "input wire rst_n"), "Verilog module declares reset port 'input wire rst_n'")
    test_assert(contains_substr(v_content, "output reg done"), "Verilog module declares status port 'output reg done'")
    test_assert(contains_substr(v_content, "endmodule"), "Verilog module terminates properly with 'endmodule'")

    // ── Phase 4: AI Optimization CLI Compilation & Execution ────────────────
    say "\n[Phase 4]: Testing AI-Guided Compilation & Execution (-O3 --ai-opt)..."
    out_ai = "/tmp/test_ai_out.bin"
    syscall(87, out_ai, 0, 0, 0, 0, 0) // unlink
    ai_compile_code = run_cmd("./bin/lipc_micro -O3 --ai-opt tests/01_hello.lp -o " + out_ai + " > /dev/null 2>&1")
    test_assert(ai_compile_code == 0, "lipc_micro -O3 --ai-opt compiles cleanly with exit code 0")

    ai_exec_code = run_cmd(out_ai + " > /dev/null 2>&1")
    test_assert(ai_exec_code == 0, "AI-optimized native binary executes with exit code 0")

    // ── Phase 5: JIT In-Memory Execution ─────────────────────────────────────
    say "\n[Phase 5]: Testing In-Memory JIT Execution (lipi run --jit)..."
    jit_code = run_cmd("./bin/lipi run --jit tests/01_hello.lp > /dev/null 2>&1")
    test_assert(jit_code == 0, "lipi run --jit executes cleanly with exit code 0")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "🎉 ALL HARDWARE HDL & AI OPTIMIZATION INVARIANTS VALIDATED SUCCESSFULLY!"
    say "════════════════════════════════════════════════════════════════════════"
    return 0

main()
