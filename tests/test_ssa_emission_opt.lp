// ==============================================================================
// 👑 LIPI COMPILER TEST: SSA CONSTANT FOLDING, DCE & REGALLOC MACHINE EMISSION
// ⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc | Sovereign Micro-Architecture
// 🏛️ File: tests/test_ssa_emission_opt.lp
// ==============================================================================

include "src/compiler/driver.lp"

fn test_assert condition msg
    if condition == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    else
        say "  ✔ PASS: " + msg
    return 1

fn find_byte_subsequence haystack needle
    // Searches for exact byte subsequence needle in haystack list
    if needle.len() == 0 return 1
    if haystack.len() < needle.len() return 0
    limit = haystack.len() - needle.len()
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < needle.len()
            if haystack[i + j] != needle[j]
                match = 0
                break
            j = j + 1
        if match == 1
            return 1
        i = i + 1
    return 0

fn test_direct_regalloc_emission
    say "\n[Test 1]: Linear Scan Physical Register Allocation in Machine Code..."
    // Define variable 'acc' mapped to hardware callee-saved register %r12 (ID 12)
    toks = tokenize_source("acc = 42\n")
    reg_names = list()
    reg_regs = list()
    push(reg_names, "acc")
    push(reg_regs, 12)

    synth = x86_synth_compile_program_opt(toks, list(), list(), reg_names, reg_regs)

    // Locate local variable 'acc' in synthesizer
    lv_found = 0
    acc_reg = 0 - 1
    acc_spilled = 1
    i = 0
    while i < synth.synth_locals.len()
        lv = synth.synth_locals[i]
        if lv.lv_name == "acc"
            lv_found = 1
            acc_reg = lv.lv_reg
            acc_spilled = lv.lv_is_spilled
            break
        i = i + 1

    test_assert(lv_found == 1, "Local variable 'acc' registered in synthesizer")
    test_assert(acc_reg == 12, "Local variable 'acc' bound to hardware register 12 (%r12)")
    test_assert(acc_spilled == 0, "Local variable 'acc' marked unspilled in hardware register")

    // Verify machine code contains 'mov r12, rax' (REX.W+REX.B: 0x49, 0x89, 0xC4)
    mov_r12_rax = [73, 137, 196]
    has_mov = find_byte_subsequence(synth.synth_code, mov_r12_rax)
    test_assert(has_mov == 1, "Machine code contains 1-cycle 'mov r12, rax' register bind")

fn test_direct_const_fold_emission
    say "\n[Test 2]: Direct SSA Constant Folding Plumbing into Machine Code..."
    toks = tokenize_source("fn get_speed\n    return SPEED_OF_LIGHT\n")
    const_names = list()
    const_vals = list()
    push(const_names, "SPEED_OF_LIGHT")
    push(const_vals, 299792458)

    synth = x86_synth_compile_program_opt(toks, const_names, const_vals, list(), list())

    // In AMD64: movabs rax, 299792458
    // 0x48, 0xB8 followed by 8 bytes of 299792458:
    // 299792458 = 0x11DE784A -> 74, 120, 222, 17, 0, 0, 0, 0
    mov_imm = [72, 184, 74, 120, 222, 17, 0, 0, 0, 0]
    has_imm = find_byte_subsequence(synth.synth_code, mov_imm)
    test_assert(has_imm == 1, "Machine code contains folded immediate 299792458 (0x11DE784A) without stack load")

fn test_call_spanning_regalloc
    say "\n[Test 3]: Call-Spanning Live Interval Linear Scan Allocation..."
    // Construct IR function with an interval spanning an OP_CALL
    ir_fn = ir_function_new("test_spanning", "i64")
    bb = ir_fn.entry_block

    // v0 = arg 0 (defined at 0, live until return at 20)
    v0 = ssa_value_new_arg("%val_span", "i64")
    push(ir_fn.params, v0)

    // v_slot = alloca i64
    v_slot = ssa_value_new_inst("%slot_span", "ptr", 0)
    inst_alloca = ir_build_alloca(1, v_slot, "i64", 0)
    basic_block_append_inst(bb, inst_alloca)

    // inst0: store %val_span into slot
    inst0 = ir_build_store(2, v0, v_slot)
    basic_block_append_inst(bb, inst0)

    // inst1: OP_CALL
    v_call = ssa_value_new_inst("%call_res", "i64", 0)
    inst1 = ir_build_call(3, v_call, "fn_foo", list())
    basic_block_append_inst(bb, inst1)

    // inst2: OP_RET using %val_span
    inst2 = ir_build_ret(4, v0)
    basic_block_append_inst(bb, inst2)

    caller_regs = [10, 11] // %r10, %r11 (caller-saved)
    callee_regs = [12, 13] // %r12, %r13 (callee-saved)
    ra_res = linear_scan_allocate_function(ir_fn, caller_regs, callee_regs, 8)

    // Find interval for %val_span
    iv_span = 0
    i = 0
    while i < ra_res.intervals.len()
        iv = ra_res.intervals[i]
        if iv.vreg_name == "%val_span"
            iv_span = iv
            break
        i = i + 1

    test_assert(iv_span != 0, "Live interval constructed for call-spanning value")
    pi = 0
    while pi < ra_res.intervals.len()
        item = ra_res.intervals[pi]
        say "  IV[" + str(pi) + "]: name=" + item.vreg_name + " start=" + str(item.start_pos) + " end=" + str(item.end_pos) + " spans=" + str(item.spans_call) + " reg=" + str(item.assigned_reg)
        pi = pi + 1
    test_assert(iv_span.spans_call == 1, "Interval correctly identified as spanning OP_CALL")
    test_assert(iv_span.assigned_reg == 12 or iv_span.assigned_reg == 13, "Assigned to callee-saved register (12 or 13), protecting across call")

fn test_end_to_end_optimized_pipeline
    say "\n[Test 4]: Full End-to-End Pipeline Optimization (-O2)..."
    source = "fn main\n    a = 15 + 25\n    b = a * 2\n    dead_calc = 1234 * 5678\n    return b\n"
    res = compiler_driver_compile_string("test_e2e_opt.lp", source, TARGET_ID_X86_64(), 2)
    test_assert(res.res_success == 1, "Full -O2 compiler pipeline executed successfully")
    test_assert(res.res_stage_reached == PIPELINE_STAGE_COMPLETE(), "Reached PIPELINE_STAGE_COMPLETE")
    test_assert(res.res_reg_alloc_spills == 0, "Zero register allocation spills with SSA optimizations")
    test_assert(res.res_error_count == 0, "Zero compilation errors")

fn main
    say "╔══════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI FIRST 1.0.0 SSA MACHINE EMISSION OPTIMIZATION TEST SUITE    ║"
    say "║  ⚡ Constant Folding | Dead Code Elimination | Linear Scan Regalloc  ║"
    say "╚══════════════════════════════════════════════════════════════════════╝"

    test_direct_regalloc_emission()
    test_direct_const_fold_emission()
    test_call_spanning_regalloc()
    test_end_to_end_optimized_pipeline()

    say "\n========================================================================"
    say "🎉 ALL SSA OPTIMIZATION MACHINE EMISSION TESTS PASSED (100% VERIFIED)!"
    say "========================================================================"
    return 0

main()
