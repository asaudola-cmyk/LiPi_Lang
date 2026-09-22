// ==============================================================================
// 🧪 LIPI TEST 65: Pure SSA IR & Compiler Optimization Pipeline Verification
// ⚡ Tests Three-Address Code (TAC), SSA Basic Blocks, AST-to-IR Lowering,
//    Constant Propagation & Folding, Dead Code Elimination (DCE), and IR Execution.
// ==============================================================================

include "src/compiler/ssa_ir.lp"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

fn test_assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name + " (Condition not true)"
        exit(1)
    say "  ✔ PASS: " + test_name

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SOVEREIGN SSA IR & COMPILER OPTIMIZATION TEST SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 1]: Three-Address Code & Basic Block Construction
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 1]: Validating TAC Instructions & Basic Block Primitives..."

    bb = ir_block_new("entry")
    test_assert_eq(ir_block_label(bb), "entry", "ir_block_label(bb) == 'entry'")
    test_assert_eq(len(ir_block_insts(bb)), 0, "Initial block instructions empty")

    i1 = ir_const("t0", 42)
    ir_block_append(bb, i1)
    test_assert_eq(len(ir_block_insts(bb)), 1, "Appended 1 instruction")
    test_assert_eq(ir_inst_op(i1), IR_CONST, "i1 opcode == IR_CONST")
    test_assert_eq(ir_inst_dest(i1), "t0", "i1 dest == 't0'")
    test_assert_eq(ir_inst_src1(i1), 42, "i1 src1 == 42")

    i2 = ir_ret("t0")
    ir_block_append(bb, i2)
    test_assert_eq(ir_inst_op(i2), IR_RET, "i2 opcode == IR_RET")
    test_assert_eq(ir_inst_src1(i2), "t0", "i2 src1 == 't0'")

    str_i1 = ir_inst_to_str(i1)
    test_assert_eq(str_i1, "t0 = const 42", "ir_inst_to_str(i1) formatted correctly")

    str_i2 = ir_inst_to_str(i2)
    test_assert_eq(str_i2, "ret t0", "ir_inst_to_str(i2) formatted correctly")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 2]: AST-to-IR Translation & Lowering
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 2]: Lowering AST Expression Sequence to Linear TAC..."

    // Source code: let a = 10 + 20; let dead = 99 * 3; let b = a * 2; return b
    src_prog = "let a = 10 + 20; let dead = 99 * 3; let b = a * 2; return b"
    stmts = ssa_parse_source(src_prog)
    test_assert_eq(len(stmts), 4, "Parsed 4 statements from source string")

    func1 = ir_func_new("calc_bench", list())
    ast_to_ir_program(func1, stmts)

    init_inst_count = ir_func_count_insts(func1)
    say "  • Initial TAC instruction count: " + str(init_inst_count)
    test_assert_true(init_inst_count >= 10, "TAC lowering created >= 10 atomic instructions")

    // Verify raw unoptimized IR executes and produces expected result: (10 + 20) * 2 = 60
    raw_res = ir_exec_func(func1, list())
    test_assert_eq(raw_res, 60, "Unoptimized IR execution yields 60")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 3]: Constant Propagation & Algebraic Folding Pass
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 3]: Running Constant Propagation & Folding Optimization..."

    folds = ir_opt_const_fold(func1)
    say "  • Total operations folded: " + str(folds)
    test_assert_true(folds >= 3, "Constant folding performed >= 3 algebraic reductions")

    // Verify folded constant values in the instruction stream:
    // a must be folded to 30, dead folded to 297, b folded to 60
    blocks = ir_func_blocks(func1)
    entry_bb = get(blocks, 0)
    insts = ir_block_insts(entry_bb)

    found_a_30 = 0
    found_dead_297 = 0
    found_b_60 = 0

    idx = 0
    while idx < len(insts)
        inst = get(insts, idx)
        dest = ir_inst_dest(inst)
        op = ir_inst_op(inst)
        val = ssa_parse_int_val(str(ir_inst_src1(inst)))

        if dest == "a" and op == IR_CONST and val == 30
            found_a_30 = 1
        if dest == "dead" and op == IR_CONST and val == 297
            found_dead_297 = 1
        if dest == "b" and op == IR_CONST and val == 60
            found_b_60 = 1
        idx = idx + 1

    test_assert_eq(found_a_30, 1, "Constant Folding: '10 + 20' folded to 'a = const 30'")
    test_assert_eq(found_dead_297, 1, "Constant Folding: '99 * 3' folded to 'dead = const 297'")
    test_assert_eq(found_b_60, 1, "Constant Folding: 'a * 2' folded to 'b = const 60'")

    // Verify execution after constant folding still produces 60
    folded_res = ir_exec_func(func1, list())
    test_assert_eq(folded_res, 60, "Constant-folded IR execution yields 60")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 4]: Dead Code Elimination (DCE)
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 4]: Running Dead Code Elimination (DCE)..."

    eliminated = ir_opt_dce(func1)
    say "  • Total dead instructions eliminated: " + str(eliminated)
    test_assert_true(eliminated >= 4, "DCE eliminated >= 4 unused instructions")

    // Verify variable 'dead' is completely wiped out from the function CFG!
    has_dead = ir_func_has_symbol(func1, "dead")
    test_assert_eq(has_dead, 0, "DCE eliminated variable 'dead' completely from IR")

    // Verify variable 'b' is preserved
    has_b = ir_func_has_symbol(func1, "b")
    test_assert_eq(has_b, 1, "DCE preserved live return variable 'b'")

    post_dce_count = ir_func_count_insts(func1)
    say "  • Final compact instruction count after DCE: " + str(post_dce_count)
    test_assert_true(post_dce_count <= 4, "Compact IR has <= 4 instructions remaining")

    // Verify execution after DCE matches expected output: 60!
    dce_res = ir_exec_func(func1, list())
    test_assert_eq(dce_res, 60, "Post-DCE optimized IR execution yields 60")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 5]: Multi-Operator Arithmetic Expression & Dead Tree Elimination
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 5]: Testing Multi-Operator Math & Cascading Dead Tree Pruning..."

    // (15 * 4) - (100 / 5) + (7 % 3) = 60 - 20 + 1 = 41
    src2 = "let x = (15 * 4) - (100 / 5) + (7 % 3); let unused = (888 + 111) * 2; return x"
    stmts2 = ssa_parse_source(src2)
    func2 = ir_func_new("arith_test", list())
    ast_to_ir_program(func2, stmts2)

    exec2_raw = ir_exec_func(func2, list())
    test_assert_eq(exec2_raw, 41, "Raw multi-op execution: (15*4)-(100/5)+(7%3) == 41")

    // Full multi-pass optimization
    opt_count = ir_optimize(func2)
    say "  • Total optimization reductions in Phase 5: " + str(opt_count)

    test_assert_eq(ir_func_has_symbol(func2, "unused"), 0, "DCE eliminated unused arithmetic tree")
    exec2_opt = ir_exec_func(func2, list())
    test_assert_eq(exec2_opt, 41, "Optimized multi-op execution yields 41")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 6]: Control Flow, Branch Folding & Dead Block Elimination
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 6]: Testing Control Flow Reachability & Dead Block Pruning..."

    func3 = ir_func_new("branch_test", list())
    entry3 = ir_func_entry(func3)

    // Build CFG:
    // entry:
    //   t_cond = 5 > 2
    //   br_cond t_cond, true_branch, dead_branch
    // true_branch:
    //   ans = const 42
    //   jmp exit_bb
    // dead_branch:
    //   ans = const 999
    //   jmp exit_bb
    // exit_bb:
    //   ret ans

    true_bb = ir_func_new_block(func3, "true_branch")
    dead_bb = ir_func_new_block(func3, "dead_branch")
    exit_bb = ir_func_new_block(func3, "exit_bb")

    t_cond = ir_func_new_temp(func3)
    ir_block_append(entry3, ir_cmp(t_cond, ">", 5, 2))
    ir_block_append(entry3, ir_br_cond(t_cond, ir_block_label(true_bb), ir_block_label(dead_bb)))

    ir_block_append(true_bb, ir_const("ans", 42))
    ir_block_append(true_bb, ir_jmp(ir_block_label(exit_bb)))

    ir_block_append(dead_bb, ir_const("ans", 999))
    ir_block_append(dead_bb, ir_jmp(ir_block_label(exit_bb)))

    ir_block_append(exit_bb, ir_ret("ans"))

    test_assert_eq(len(ir_func_blocks(func3)), 4, "Initial CFG has 4 basic blocks")
    exec3_raw = ir_exec_func(func3, list())
    test_assert_eq(exec3_raw, 42, "Unoptimized CFG execution yields 42")

    // Optimize: 5 > 2 folds to 1, br_cond folds to unconditional jmp true_branch,
    // and dead_branch becomes unreachable and is pruned!
    ir_opt_const_fold(func3)
    ir_opt_eliminate_dead_blocks(func3)

    test_assert_eq(len(ir_func_blocks(func3)), 3, "Dead block pruned: CFG now has 3 basic blocks")
    test_assert_eq(ir_block_is_dead(dead_bb), 1, "dead_branch block marked as dead")

    exec3_opt = ir_exec_func(func3, list())
    test_assert_eq(exec3_opt, 42, "Branch-folded CFG execution yields 42")

    // ──────────────────────────────────────────────────────────────────────────
    // [Phase 7]: SSA Confluence PHI Nodes
    // ──────────────────────────────────────────────────────────────────────────
    say "\n[Phase 7]: Testing SSA PHI Node Resolution..."

    func4 = ir_func_new("phi_test", list())
    entry4 = ir_func_entry(func4)
    bb_left = ir_func_new_block(func4, "bb_left")
    bb_right = ir_func_new_block(func4, "bb_right")
    merge_bb = ir_func_new_block(func4, "bb_merge")

    // Jump from entry to left branch
    ir_block_append(entry4, ir_jmp(ir_block_label(bb_left)))

    ir_block_append(bb_left, ir_const("y_left", 123))
    ir_block_append(bb_left, ir_jmp(ir_block_label(merge_bb)))

    ir_block_append(bb_right, ir_const("y_right", 456))
    ir_block_append(bb_right, ir_jmp(ir_block_label(merge_bb)))

    // PHI node in merge_bb: select based on incoming block
    phi_pairs = list()
    pair1 = list()
    push(pair1, "y_left")
    push(pair1, ir_block_label(bb_left))
    push(phi_pairs, pair1)

    pair2 = list()
    push(pair2, "y_right")
    push(pair2, ir_block_label(bb_right))
    push(phi_pairs, pair2)

    ir_block_append(merge_bb, ir_phi("y_merged", phi_pairs))
    ir_block_append(merge_bb, ir_ret("y_merged"))

    exec4_res = ir_exec_func(func4, list())
    test_assert_eq(exec4_res, 123, "SSA PHI node successfully resolved incoming value 123")

    phi_str = ir_inst_to_str(get(ir_block_insts(merge_bb), 0))
    say "  • PHI representation: " + phi_str

    say "\n════════════════════════════════════════════════════════════════════════"
    say "  🎉 ALL SSA IR & OPTIMIZER INVARIANTS VALIDATED SUCCESSFULLY!"
    say "════════════════════════════════════════════════════════════════════════"
    say "PASS: Test 65 SSA Optimizer"
    return 0

main()
