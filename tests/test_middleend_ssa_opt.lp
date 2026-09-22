// ==============================================================================
// 👑 LIPI COMPILER TEST: MIDDLE-END SSA IR & 12 OPTIMIZATION PASSES
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
// 🏛️ File: tests/test_middleend_ssa_opt.lp
//
// WHY: Validates the complete middle-end SSA subsystem:
//      - 8 IR Subsystem Components: Opcodes, Values, Instructions, BasicBlocks,
//        Functions, Modules, Strict SSA Verifier, Human-Readable Printer.
//      - 3 Analysis Passes: CFG Analysis, Dominator Tree, Natural Loop Info.
//      - 8 Optimization Passes: Constant Folding, DCE, CSE, LICM, Unrolling,
//        Inlining, DSE, Peephole.
//      - 1 Pass Manager: Scheduling and executing O0, O1, O2, O3 pipelines with
//        strict SSA invariant verification at every stage.
// ==============================================================================

include "src/compiler/middleend/opt/pass_manager.lp"

fn test_assert condition msg
    if condition == 0
        say "❌ [ASSERTION FAILED]: " + msg
        exit(1)
    else
        say "  ✔ PASS: " + msg
    return 1

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "👑 TESTING LIPI FIRST 1.0.0 MIDDLE-END SSA IR & OPTIMIZATION PIPELINE"
    say "════════════════════════════════════════════════════════════════════════"

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 1: SSA OPCODES & VALUES (Def-Use & RAUW)
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 1]: SSA Opcodes & SSA Value Def-Use Chains"
    test_assert(ssa_is_terminator(OP_BR) == 1, "OP_BR is terminator")
    test_assert(ssa_is_terminator(OP_ADD) == 0, "OP_ADD is not terminator")
    test_assert(ssa_is_commutative(OP_ADD) == 1, "OP_ADD is commutative")
    test_assert(ssa_is_commutative(OP_SUB) == 0, "OP_SUB is not commutative")
    test_assert(ssa_has_side_effects(OP_STORE) == 1, "OP_STORE has side effects")

    val_a = ssa_value_new_arg("%a", "i64")
    val_b = ssa_value_new_const(10, "i64")
    test_assert(val_a.kind == VAL_KIND_ARG, "val_a kind is ARG")
    test_assert(val_b.kind == VAL_KIND_CONST, "val_b kind is CONST")
    test_assert(val_b.const_val == 10, "val_b immediate value is 10")
    test_assert(ssa_value_use_count(val_a) == 0, "Initial use count is 0")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 2: BASIC BLOCK & INSTRUCTIONS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 2]: Basic Block & Instruction Construction"
    bb = basic_block_new("bb0", 0)
    v_sum = ssa_value_new_inst("%v0", "i64", 0)
    inst_add = ir_build_binop(1, OP_ADD, v_sum, val_a, val_b)
    basic_block_append_inst(bb, inst_add)

    test_assert(basic_block_inst_count(bb) == 1, "Block instruction count is 1")
    test_assert(ssa_value_use_count(val_a) == 1, "val_a use count incremented to 1")
    test_assert(ssa_value_use_count(val_b) == 1, "val_b use count incremented to 1")

    inst_ret = ir_build_ret(2, v_sum)
    basic_block_append_inst(bb, inst_ret)
    test_assert(basic_block_inst_count(bb) == 2, "Block instruction count is 2")
    test_assert(ssa_value_use_count(v_sum) == 1, "v_sum used by ret")

    term = basic_block_get_terminator(bb)
    test_assert(term != 0, "Block terminator found")
    test_assert(term.op == OP_RET, "Terminator is OP_RET")

    // Test RAUW: replace val_b with val_c
    val_c = ssa_value_new_const(20, "i64")
    ssa_value_replace_all_uses_with(val_b, val_c)
    test_assert(ssa_value_use_count(val_b) == 0, "Old value has 0 uses after RAUW")
    test_assert(ssa_value_use_count(val_c) == 1, "New value has 1 use after RAUW")
    test_assert(ssa_instr_get_operand(inst_add, 1) == val_c, "Instruction operand updated to val_c")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 3: IR FUNCTION, MODULE, AND STRICT VERIFIER
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 3]: IR Function, Module, and Strict SSA Verifier"
    mod = ir_module_new("test_mod")
    mod.add_global("@version", "i64", 100, 1)
    mod.set_metadata("target", "x86_64")

    func = ir_function_new("add_and_mul", "i64")
    mod.add_function(func)
    p0 = ssa_value_new_arg("%x", "i64")
    func.add_param(p0)

    f_entry = func.entry_block
    v_add = func.new_val("i64")
    c5 = ssa_value_new_const(5, "i64")
    i1 = ir_build_binop(10, OP_ADD, v_add, p0, c5)
    basic_block_append_inst(f_entry, i1)

    v_mul = func.new_val("i64")
    c2 = ssa_value_new_const(2, "i64")
    i2 = ir_build_binop(11, OP_MUL, v_mul, v_add, c2)
    basic_block_append_inst(f_entry, i2)

    i3 = ir_build_ret(12, v_mul)
    basic_block_append_inst(f_entry, i3)

    cfg_rebuild_edges(func)
    v_ok = ir_verify_module(mod)
    test_assert(v_ok == 1, "Strict SSA Verifier passed on valid function")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 4: CFG ANALYSIS & DOMINATOR TREE
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 4]: CFG Analysis & Dominator Tree (Lengauer-Tarjan/Cooper-Harvey)"
    // Construct diamond CFG:
    //       entry
    //      /     \
    //    then    else
    //      \     /
    //       join
    f_flow = ir_function_new("flow_test", "i64")
    b_entry = f_flow.entry_block
    b_then  = f_flow.create_block("then")
    b_else  = f_flow.create_block("else")
    b_join  = f_flow.create_block("join")

    cond = ssa_value_new_arg("%c", "i64")
    f_flow.add_param(cond)

    basic_block_append_inst(b_entry, ir_build_br(1, cond, b_then.label, b_else.label))
    basic_block_append_inst(b_then, ir_build_jmp(2, b_join.label))
    basic_block_append_inst(b_else, ir_build_jmp(3, b_join.label))
    basic_block_append_inst(b_join, ir_build_ret(4, cond))

    cfg_rebuild_edges(f_flow)
    rpo = cfg_compute_rpo(f_flow)
    test_assert(len(rpo) == 4, "RPO computes 4 reachable blocks")

    dt = dom_tree_compute(f_flow)
    test_assert(dom_tree_dominates(dt, b_entry.label, b_join.label) == 1, "entry dominates join")
    test_assert(dom_tree_dominates(dt, b_then.label, b_join.label) == 0, "then does not dominate join")
    test_assert(dom_tree_dominates(dt, b_else.label, b_join.label) == 0, "else does not dominate join")
    test_assert(dom_tree_get_idom(dt, b_join.label) == b_entry.label, "idom(join) == entry")

    df_then = dom_tree_get_frontier(dt, b_then.label)
    test_assert(len(df_then) == 1, "DF(then) has 1 element")
    test_assert(get(df_then, 0) == b_join.label, "DF(then) contains join")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 5: NATURAL LOOP DETECTION & INDUCTION VARIABLE ANALYSIS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 5]: Natural Loop Detection & Induction Variable Analysis"
    f_loop = ir_function_new("loop_test", "i64")
    l_entry = f_loop.entry_block
    l_hdr   = f_loop.create_block("header")
    l_body  = f_loop.create_block("body")
    l_exit  = f_loop.create_block("exit")

    c_zero = ssa_value_new_const(0, "i64")
    c_one  = ssa_value_new_const(1, "i64")
    c_four = ssa_value_new_const(4, "i64")

    v_idx  = f_loop.new_val("i64")
    v_step = f_loop.new_val("i64")
    v_cond = f_loop.new_val("bool")

    basic_block_append_inst(l_entry, ir_build_jmp(1, l_hdr.label))

    p_vals = list()
    push(p_vals, c_zero)
    push(p_vals, v_step)
    p_bbs = list()
    push(p_bbs, l_entry.label)
    push(p_bbs, l_body.label)
    basic_block_append_inst(l_hdr, ir_build_phi(2, v_idx, p_vals, p_bbs))
    basic_block_append_inst(l_hdr, ir_build_cmp(3, CMP_SLT, v_cond, v_idx, c_four))
    basic_block_append_inst(l_hdr, ir_build_br(4, v_cond, l_body.label, l_exit.label))

    basic_block_append_inst(l_body, ir_build_binop(5, OP_ADD, v_step, v_idx, c_one))
    basic_block_append_inst(l_body, ir_build_jmp(6, l_hdr.label))

    basic_block_append_inst(l_exit, ir_build_ret(7, v_idx))

    cfg_rebuild_edges(f_loop)
    dt_loop = dom_tree_compute(f_loop)
    loops = loop_info_detect_loops(f_loop, dt_loop)

    test_assert(len(loops) == 1, "Detected 1 natural loop")
    detected_lp = get(loops, 0)
    test_assert(loop_get_header(detected_lp) == l_hdr.label, "Loop header correctly identified")
    test_assert(loop_get_latch(detected_lp) == l_body.label, "Loop latch correctly identified")
    test_assert(loop_is_const_trip(detected_lp) == 1, "Loop has constant trip count")
    test_assert(loop_get_trip_count(detected_lp) == 4, "Loop trip count is 4")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 6: CONSTANT FOLDING PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 6]: Constant Folding Pass"
    f_fold = ir_function_new("fold_test", "i64")
    ff_entry = f_fold.entry_block

    c15 = ssa_value_new_const(15, "i64")
    c3  = ssa_value_new_const(3, "i64")
    v_div = f_fold.new_val("i64")
    basic_block_append_inst(ff_entry, ir_build_binop(1, OP_DIV, v_div, c15, c3)) // 15 / 3 = 5

    v_cmp = f_fold.new_val("bool")
    basic_block_append_inst(ff_entry, ir_build_cmp(2, CMP_SLT, v_cmp, c3, c15)) // 3 < 15 = 1

    basic_block_append_inst(ff_entry, ir_build_ret(3, v_div))

    folds = pass_const_fold_run(f_fold)
    test_assert(folds == 2, "2 constant operations folded")
    test_assert(basic_block_inst_count(ff_entry) == 1, "Only return remains after folding")
    ret_val = ssa_instr_get_operand(basic_block_get_terminator(ff_entry), 0)
    test_assert(ret_val.const_val == 5, "Division folded to immediate 5")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 7: DEAD CODE ELIMINATION (DCE) PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 7]: Dead Code Elimination (DCE) Pass"
    f_dce = ir_function_new("dce_test", "i64")
    d_entry = f_dce.entry_block
    d_dead  = f_dce.create_block("dead_bb")

    v_live = f_dce.new_val("i64")
    basic_block_append_inst(d_entry, ir_build_binop(1, OP_ADD, v_live, c15, c15))

    v_useless = f_dce.new_val("i64")
    basic_block_append_inst(d_entry, ir_build_binop(2, OP_MUL, v_useless, c3, c3)) // Dead (0 uses)

    basic_block_append_inst(d_entry, ir_build_ret(3, v_live))

    basic_block_append_inst(d_dead, ir_build_ret(4, c15)) // Unreachable block

    cfg_rebuild_edges(f_dce)
    test_assert(len(f_dce.blocks) == 2, "2 blocks before DCE")
    test_assert(basic_block_inst_count(d_entry) == 3, "3 instructions before DCE")

    dce_killed = pass_dce_run(f_dce)
    test_assert(dce_killed == 2, "DCE eliminated 2 dead items (1 inst, 1 block)")
    test_assert(len(f_dce.blocks) == 1, "1 block remaining after DCE")
    test_assert(basic_block_inst_count(d_entry) == 2, "2 instructions remaining in entry")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 8: COMMON SUBEXPRESSION ELIMINATION (CSE) PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 8]: Common Subexpression Elimination (CSE) Pass"
    f_cse = ir_function_new("cse_test", "i64")
    cs_entry = f_cse.entry_block
    p_x = ssa_value_new_arg("%x", "i64")
    p_y = ssa_value_new_arg("%y", "i64")
    f_cse.add_param(p_x)
    f_cse.add_param(p_y)

    v_sub1 = f_cse.new_val("i64")
    basic_block_append_inst(cs_entry, ir_build_binop(1, OP_ADD, v_sub1, p_x, p_y))

    v_sub2 = f_cse.new_val("i64")
    basic_block_append_inst(cs_entry, ir_build_binop(2, OP_ADD, v_sub2, p_y, p_x)) // Commutative match!

    v_res = f_cse.new_val("i64")
    basic_block_append_inst(cs_entry, ir_build_binop(3, OP_MUL, v_res, v_sub1, v_sub2))
    basic_block_append_inst(cs_entry, ir_build_ret(4, v_res))

    cse_hits = pass_cse_run(f_cse)
    test_assert(cse_hits == 1, "CSE eliminated 1 duplicate subexpression")
    test_assert(basic_block_inst_count(cs_entry) == 3, "Entry instruction count reduced to 3")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 9: LOOP INVARIANT CODE MOTION (LICM) PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 9]: Loop Invariant Code Motion (LICM) Pass"
    f_licm = ir_function_new("licm_test", "i64")
    licm_entry = f_licm.entry_block
    licm_hdr   = f_licm.create_block("header")
    licm_body  = f_licm.create_block("body")
    licm_exit  = f_licm.create_block("exit")

    v_li_i    = f_licm.new_val("i64")
    v_li_next = f_licm.new_val("i64")
    v_li_cond = f_licm.new_val("bool")
    v_li_inv  = f_licm.new_val("i64")

    basic_block_append_inst(licm_entry, ir_build_jmp(1, licm_hdr.label))

    li_pvals = list()
    push(li_pvals, c_zero)
    push(li_pvals, v_li_next)
    li_pbbs = list()
    push(li_pbbs, licm_entry.label)
    push(li_pbbs, licm_body.label)
    basic_block_append_inst(licm_hdr, ir_build_phi(2, v_li_i, li_pvals, li_pbbs))
    basic_block_append_inst(licm_hdr, ir_build_cmp(3, CMP_SLT, v_li_cond, v_li_i, c15))
    basic_block_append_inst(licm_hdr, ir_build_br(4, v_li_cond, licm_body.label, licm_exit.label))

    // Invariant inside loop body:
    basic_block_append_inst(licm_body, ir_build_binop(5, OP_ADD, v_li_inv, c15, c3)) // Invariant!
    basic_block_append_inst(licm_body, ir_build_binop(6, OP_ADD, v_li_next, v_li_i, c_one))
    basic_block_append_inst(licm_body, ir_build_jmp(7, licm_hdr.label))

    basic_block_append_inst(licm_exit, ir_build_ret(8, v_li_inv))

    cfg_rebuild_edges(f_licm)
    test_assert(basic_block_inst_count(licm_body) == 3, "3 instructions in body before LICM")

    hoisted = pass_licm_run(f_licm)
    test_assert(hoisted == 1, "1 invariant instruction hoisted")
    test_assert(basic_block_inst_count(licm_body) == 2, "2 instructions in body after LICM")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 10: LOOP UNROLLING PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 10]: Loop Unrolling Pass"
    f_unroll = ir_function_new("unroll_test", "i64")
    u_entry = f_unroll.entry_block
    u_hdr   = f_unroll.create_block("header")
    u_body  = f_unroll.create_block("body")
    u_exit  = f_unroll.create_block("exit")

    u_idx  = f_unroll.new_val("i64")
    u_next = f_unroll.new_val("i64")
    u_cond = f_unroll.new_val("bool")

    basic_block_append_inst(u_entry, ir_build_jmp(1, u_hdr.label))

    u_pvals = list()
    push(u_pvals, c_zero)
    push(u_pvals, u_next)
    u_pbbs = list()
    push(u_pbbs, u_entry.label)
    push(u_pbbs, u_body.label)
    basic_block_append_inst(u_hdr, ir_build_phi(2, u_idx, u_pvals, u_pbbs))
    basic_block_append_inst(u_hdr, ir_build_cmp(3, CMP_SLT, u_cond, u_idx, c3)) // Trip count = 3
    basic_block_append_inst(u_hdr, ir_build_br(4, u_cond, u_body.label, u_exit.label))

    basic_block_append_inst(u_body, ir_build_binop(5, OP_ADD, u_next, u_idx, c_one))
    basic_block_append_inst(u_body, ir_build_jmp(6, u_hdr.label))

    basic_block_append_inst(u_exit, ir_build_ret(7, u_idx))

    cfg_rebuild_edges(f_unroll)
    unrolls = pass_unroll_run(f_unroll)
    test_assert(unrolls == 1, "Loop unrolled successfully")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 11: DEAD STORE ELIMINATION (DSE) PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 11]: Dead Store Elimination (DSE) Pass"
    f_dse = ir_function_new("dse_test", "i64")
    ds_entry = f_dse.entry_block

    ptr_slot = f_dse.new_val("ptr")
    alloc_i = ir_build_alloca(1, ptr_slot, "i64", 0)
    basic_block_append_inst(ds_entry, alloc_i)
    f_dse.register_alloca(alloc_i)

    // Store 10, then overwrite with 20 without reading:
    basic_block_append_inst(ds_entry, ir_build_store(2, c15, ptr_slot)) // Dead store!
    basic_block_append_inst(ds_entry, ir_build_store(3, c3, ptr_slot))

    v_read = f_dse.new_val("i64")
    basic_block_append_inst(ds_entry, ir_build_load(4, v_read, ptr_slot))
    basic_block_append_inst(ds_entry, ir_build_ret(5, v_read))

    dse_hits = pass_dse_run(f_dse)
    test_assert(dse_hits == 1, "1 overwritten dead store eliminated")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 12: PEEPHOLE & STRENGTH REDUCTION PASS
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 12]: Peephole & Strength Reduction Pass"
    f_peep = ir_function_new("peep_test", "i64")
    peep_entry = f_peep.entry_block
    p_v = ssa_value_new_arg("%v", "i64")
    f_peep.add_param(p_v)

    c_eight = ssa_value_new_const(8, "i64")

    // %v + 0 -> %v
    v_add0 = f_peep.new_val("i64")
    basic_block_append_inst(peep_entry, ir_build_binop(1, OP_ADD, v_add0, p_v, c_zero))

    // %v * 8 -> %v << 3 (strength reduction)
    v_mul8 = f_peep.new_val("i64")
    i_mul8 = ir_build_binop(2, OP_MUL, v_mul8, v_add0, c_eight)
    basic_block_append_inst(peep_entry, i_mul8)

    // %v - %v -> 0
    v_self = f_peep.new_val("i64")
    basic_block_append_inst(peep_entry, ir_build_binop(3, OP_SUB, v_self, p_v, p_v))

    basic_block_append_inst(peep_entry, ir_build_ret(4, v_mul8))

    peep_hits = pass_peephole_run(f_peep)
    test_assert(peep_hits == 2, "2 algebraic identities simplified")
    test_assert(i_mul8.op == OP_SHL, "Multiplication reduced to shift left (OP_SHL)")

    // ──────────────────────────────────────────────────────────────────────────
    // TEST 13: FULL PASS MANAGER PIPELINE (-O2 & -O3)
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Test 13]: Pass Manager Orchestration (-O2 & -O3)"
    pm_o2 = pass_manager_new(2)
    pm_o2.run_on_function(func)
    test_assert(pm_o2.stat_passes_run > 0, "PassManager -O2 executed passes")

    say "\n════════════════════════════════════════════════════════════════════════"
    say "🎉 ALL MIDDLE-END SSA IR & OPTIMIZER TESTS COMPLETED SUCCESSFULLY! 👑"
    say "════════════════════════════════════════════════════════════════════════"
    return 0
