// ==============================================================================
// 👑 LIPI FIRST 1.0.0 LOOP INVARIANT CODE MOTION (LICM) (src/compiler/middleend/opt/passes/pass_licm.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Loop Invariant Code Motion (LICM) identifies expressions evaluated inside a
//      loop whose operands never change across loop iterations.
//      1. Computational Hoisting: Hoisting invariant instructions out of the loop body
//         into the loop preheader converts O(N) evaluations into O(1) evaluation.
//      2. Dominance Preservation: Invariants are placed in the dedicated preheader,
//         which strictly dominates the loop header and all loop blocks, guaranteeing
//         the SSA dominance invariant is preserved.
//      3. Silicon Throughput: Reduces dynamic instruction count in innermost loops,
//         maximizing CPU branch predictor and pipeline utilization.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/loop_info.lp"

// ── 1. Invariance Checker ─────────────────────────────────────────────────────

fn licm_is_value_invariant val lp hoisted_vals
    if val == 0 return 1
    // Constants and arguments are globally invariant
    if val.kind == VAL_KIND_CONST or val.kind == VAL_KIND_ARG or val.kind == VAL_KIND_GLOBAL
        return 1

    // If defined by an instruction already hoisted in this pass
    hi = 0
    while hi < len(hoisted_vals)
        if get(hoisted_vals, hi) == val
            return 1
        hi = hi + 1

    // If defined outside the loop
    def_i = val.def_inst
    if def_i != 0
        if def_i.parent_bb == 0
            return 1
        if loop_contains_block(lp, def_i.parent_bb.label) == 0
            return 1

    return 0

fn licm_is_inst_invariant inst lp hoisted_vals
    if inst == 0 return 0
    if inst.result == 0 return 0

    // Do not hoist instructions with side-effects, Phis, or allocas
    if ssa_has_side_effects(inst.op) == 1 or inst.op == OP_PHI or inst.op == OP_ALLOCA
        return 0

    // Only hoist pure arithmetic, bitwise, comparisons, negation
    if ssa_is_binary_arithmetic(inst.op) == 0 and ssa_is_bitwise(inst.op) == 0 and inst.op != OP_CMP and inst.op != OP_NEG
        return 0

    // Check all operands
    oi = 0
    while oi < len(inst.operands)
        opnd = get(inst.operands, oi)
        if licm_is_value_invariant(opnd, lp, hoisted_vals) == 0
            return 0
        oi = oi + 1

    return 1

// ── 2. Main LICM Pass ─────────────────────────────────────────────────────────

fn pass_licm_run fn_obj
    if fn_obj == 0 return 0

    cfg_rebuild_edges(fn_obj)
    dt = dom_tree_compute(fn_obj)
    loops = loop_info_detect_loops(fn_obj, dt)

    if len(loops) == 0 return 0

    hoisted_total = 0

    li = 0
    while li < len(loops)
        lp = get(loops, li)
        preheader_lbl = loop_get_preheader(lp)
        preheader_bb = ir_function_find_block(fn_obj, preheader_lbl)

        if preheader_bb != 0
            preheader_term = basic_block_get_terminator(preheader_bb)
            hoisted_vals = list()

            // Iterative scan to hoist cascades of invariant instructions
            more_invariants = 1
            while more_invariants == 1
                more_invariants = 0

                bi = 0
                while bi < len(loop_get_blocks(lp))
                    b_lbl = get(loop_get_blocks(lp), bi)
                    // Do not hoist from the preheader itself
                    if b_lbl != preheader_lbl
                        bb = ir_function_find_block(fn_obj, b_lbl)
                        if bb != 0
                            new_insts = list()
                            ii = 0
                            while ii < len(bb.instructions)
                                inst = get(bb.instructions, ii)
                                if licm_is_inst_invariant(inst, lp, hoisted_vals) == 1
                                    // Hoist into preheader immediately before terminator
                                    basic_block_insert_before(preheader_bb, preheader_term, inst)
                                    push(hoisted_vals, inst.result)
                                    hoisted_total = hoisted_total + 1
                                    more_invariants = 1
                                else
                                    push(new_insts, inst)
                                ii = ii + 1
                            bb.instructions = new_insts
                    bi = bi + 1

        li = li + 1

    return hoisted_total
