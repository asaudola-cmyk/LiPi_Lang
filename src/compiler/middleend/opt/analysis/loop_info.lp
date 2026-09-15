// ==============================================================================
// 👑 LIPI FIRST 1.0.0 NATURAL LOOP & INDUCTION VARIABLE ANALYSIS (src/compiler/middleend/opt/analysis/loop_info.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Loop optimization is the highest ROI domain in compiler middle-ends.
//      Most compute cycles in user applications are spent inside nested loops.
//      This module provides:
//      1. Back-Edge Identification: Detecting edges (latch, header) where header dominates latch.
//      2. Natural Loop Recovery: Reconstructing the minimal set of blocks forming the loop body.
//      3. Dedicated Preheader Resolution: Guaranteeing a single landing pad for hoisting invariants.
//      4. Canonical Induction Variable Recognition: Discovering affine loop counters (i = i + step)
//         and computing exact compile-time trip counts for loop unrolling and vectorization.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/dominator_tree.lp"

// ── 1. Loop Representation ───────────────────────────────────────────────────

struct Loop
    loop_header_lbl     // string: loop header basic block label (single entry point)
    loop_latch_lbl      // string: latch basic block label containing back-edge to header
    loop_blocks         // list: string labels of all basic blocks within the natural loop
    loop_preheader_lbl  // string: dedicated outside predecessor block label
    loop_exit_lbls      // list: outside target block labels reached by loop exits
    loop_ind_var        // SSAValue: canonical induction variable (or 0)
    loop_ind_init_val   // integer: initial value of induction variable
    loop_ind_step_val   // integer: monotonic step per iteration
    loop_trip_count     // integer: constant trip count, or -1 if dynamic/unknown
    loop_is_const_trip  // integer: 1 if trip count is a known compile-time constant

fn loop_new header_lbl latch_lbl
    lp = Loop()
    lp.loop_header_lbl = header_lbl
    lp.loop_latch_lbl = latch_lbl
    lp.loop_blocks = list()
    lp.loop_preheader_lbl = ""
    lp.loop_exit_lbls = list()
    lp.loop_ind_var = 0
    lp.loop_ind_init_val = 0
    lp.loop_ind_step_val = 1
    lp.loop_trip_count = 0 - 1
    lp.loop_is_const_trip = 0

    // Header and latch are always in the loop
    push(lp.loop_blocks, header_lbl)
    if latch_lbl != header_lbl
        push(lp.loop_blocks, latch_lbl)

    return lp

// Accessors for Loop properties
fn loop_get_header lp = lp.loop_header_lbl
fn loop_get_latch lp = lp.loop_latch_lbl
fn loop_get_blocks lp = lp.loop_blocks
fn loop_get_preheader lp = lp.loop_preheader_lbl
fn loop_get_exits lp = lp.loop_exit_lbls
fn loop_get_ind_var lp = lp.loop_ind_var
fn loop_get_trip_count lp = lp.loop_trip_count
fn loop_is_const_trip lp = lp.loop_is_const_trip

// Returns 1 if a block label belongs to this loop
fn loop_contains_block lp label
    if lp == 0 return 0
    i = 0
    cnt = len(lp.loop_blocks)
    while i < cnt
        if get(lp.loop_blocks, i) == label
            return 1
        i = i + 1
    return 0

// ── 2. Natural Loop Population ────────────────────────────────────────────────
// WHY: Tarjan's backward DFS from latch up to header collects all blocks in the loop.

fn loop_populate_blocks lp fn_obj
    work_stack = list()
    if lp.loop_latch_lbl != lp.loop_header_lbl
        push(work_stack, lp.loop_latch_lbl)

    while len(work_stack) > 0
        curr_lbl = get(work_stack, len(work_stack) - 1)
        // pop
        new_stack = list()
        i = 0
        while i < (len(work_stack) - 1)
            push(new_stack, get(work_stack, i))
            i = i + 1
        work_stack = new_stack

        curr_bb = ir_function_find_block(fn_obj, curr_lbl)
        if curr_bb != 0
            pi = 0
            while pi < len(curr_bb.predecessors)
                pred_lbl = get(curr_bb.predecessors, pi)
                if loop_contains_block(lp, pred_lbl) == 0
                    push(lp.loop_blocks, pred_lbl)
                    push(work_stack, pred_lbl)
                pi = pi + 1

    return 1

// ── 3. Dedicated Preheader Resolution ─────────────────────────────────────────
// WHY: Loop Invariant Code Motion requires a unique, dedicated block immediately
//      preceding the loop header that executes exactly once whenever the loop is entered.

fn loop_resolve_preheader lp fn_obj
    header_bb = ir_function_find_block(fn_obj, lp.loop_header_lbl)
    if header_bb == 0 return ""

    outside_preds = list()
    pi = 0
    while pi < len(header_bb.predecessors)
        p_lbl = get(header_bb.predecessors, pi)
        if loop_contains_block(lp, p_lbl) == 0
            push(outside_preds, p_lbl)
        pi = pi + 1

    // If exactly one outside predecessor exists, check if it only has 1 successor
    if len(outside_preds) == 1
        outside_lbl = get(outside_preds, 0)
        outside_bb = ir_function_find_block(fn_obj, outside_lbl)
        if outside_bb != 0 and len(outside_bb.successors) == 1
            lp.loop_preheader_lbl = outside_lbl
            return outside_lbl

    // Otherwise, synthesize a dedicated preheader block
    preheader = ir_function_create_block(fn_obj, "loop_preheader")
    jmp_inst = ir_build_jmp(1, lp.loop_header_lbl)
    basic_block_append_inst(preheader, jmp_inst)

    // Reroute outside predecessors to target the new preheader instead
    oi = 0
    while oi < len(outside_preds)
        out_lbl = get(outside_preds, oi)
        out_bb = ir_function_find_block(fn_obj, out_lbl)
        if out_bb != 0
            term = basic_block_get_terminator(out_bb)
            if term != 0
                if term.op == OP_JMP and term.extra_str == lp.loop_header_lbl
                    term.extra_str = preheader.label
                if term.op == OP_BR
                    if len(term.extra_list) >= 2
                        if get(term.extra_list, 0) == lp.loop_header_lbl
                            list_set(term.extra_list, 0, preheader.label)
                        if get(term.extra_list, 1) == lp.loop_header_lbl
                            list_set(term.extra_list, 1, preheader.label)
        oi = oi + 1

    // Update Phi nodes in header: change incoming labels from outside predecessors to preheader
    ii = 0
    while ii < len(header_bb.instructions)
        inst = get(header_bb.instructions, ii)
        if inst.op == OP_PHI
            pi = 0
            while pi < len(inst.extra_list)
                lbl = get(inst.extra_list, pi)
                // If this incoming branch was from outside the loop, reroute to preheader
                if loop_contains_block(lp, lbl) == 0
                    list_set(inst.extra_list, pi, preheader.label)
                pi = pi + 1
        ii = ii + 1

    cfg_rebuild_edges(fn_obj)
    lp.loop_preheader_lbl = preheader.label
    return preheader.label

// ── 4. Loop Exit Collection ───────────────────────────────────────────────────

fn loop_collect_exits lp fn_obj
    lp.loop_exit_lbls = list()
    bi = 0
    while bi < len(lp.loop_blocks)
        b_lbl = get(lp.loop_blocks, bi)
        bb = ir_function_find_block(fn_obj, b_lbl)
        if bb != 0
            si = 0
            while si < len(bb.successors)
                succ_lbl = get(bb.successors, si)
                if loop_contains_block(lp, succ_lbl) == 0
                    // Check if already in exits
                    already_in_exits = 0
                    ei = 0
                    while ei < len(lp.loop_exit_lbls)
                        if get(lp.loop_exit_lbls, ei) == succ_lbl already_in_exits = 1
                        ei = ei + 1
                    if already_in_exits == 0
                        push(lp.loop_exit_lbls, succ_lbl)
                si = si + 1
        bi = bi + 1
    return len(lp.loop_exit_lbls)

// ── 5. Induction Variable & Trip Count Analysis ───────────────────────────────
// WHY: Discovers affine loop counters i = i + step and computes constant iteration
//      counts for loop unrolling.

fn loop_analyze_induction_variables lp fn_obj
    header_bb = ir_function_find_block(fn_obj, lp.loop_header_lbl)
    if header_bb == 0 return 0

    // Scan Phi nodes in header
    ii = 0
    while ii < len(header_bb.instructions)
        inst = get(header_bb.instructions, ii)
        if inst.op == OP_PHI
            // Expect 2 incoming values: one from preheader, one from latch
            if len(inst.operands) == 2
                val0 = get(inst.operands, 0)
                lbl0 = get(inst.extra_list, 0)
                val1 = get(inst.operands, 1)
                lbl1 = get(inst.extra_list, 1)

                init_val = 0
                next_val = 0
                if lbl0 == lp.loop_preheader_lbl and lbl1 == lp.loop_latch_lbl
                    init_val = val0
                    next_val = val1
                elif lbl1 == lp.loop_preheader_lbl and lbl0 == lp.loop_latch_lbl
                    init_val = val1
                    next_val = val0

                if init_val != 0 and next_val != 0
                    // Check if next_val is an OP_ADD or OP_SUB of inst.result and a constant step
                    step_inst = next_val.def_inst
                    if step_inst != 0 and (step_inst.op == OP_ADD or step_inst.op == OP_SUB)
                        opnd0 = ssa_instr_get_operand(step_inst, 0)
                        opnd1 = ssa_instr_get_operand(step_inst, 1)

                        if opnd0 == inst.result and opnd1.kind == VAL_KIND_CONST
                            lp.loop_ind_var = inst.result
                            step_k = opnd1.const_val
                            if step_inst.op == OP_SUB step_k = 0 - step_k
                            lp.loop_ind_step_val = step_k
                            if init_val.kind == VAL_KIND_CONST
                                lp.loop_ind_init_val = init_val.const_val

                                // Check exit condition in latch (or header)
                                term = basic_block_get_terminator(header_bb)
                                if term == 0 or term.op != OP_BR
                                    latch_bb = ir_function_find_block(fn_obj, lp.loop_latch_lbl)
                                    if latch_bb != 0 term = basic_block_get_terminator(latch_bb)

                                if term != 0 and term.op == OP_BR
                                    cond_val = ssa_instr_get_operand(term, 0)
                                    cmp_inst = cond_val.def_inst
                                    if cmp_inst != 0 and cmp_inst.op == OP_CMP
                                        cmp_lhs = ssa_instr_get_operand(cmp_inst, 0)
                                        cmp_rhs = ssa_instr_get_operand(cmp_inst, 1)
                                        pred = cmp_inst.extra_int

                                        if cmp_lhs == inst.result and cmp_rhs.kind == VAL_KIND_CONST
                                            limit = cmp_rhs.const_val
                                            if pred == CMP_SLT and lp.loop_ind_step_val == 1
                                                if limit > lp.loop_ind_init_val
                                                    lp.loop_trip_count = limit - lp.loop_ind_init_val
                                                    lp.loop_is_const_trip = 1
                                            if pred == CMP_SLE and lp.loop_ind_step_val == 1
                                                if limit >= lp.loop_ind_init_val
                                                    lp.loop_trip_count = (limit - lp.loop_ind_init_val) + 1
                                                    lp.loop_is_const_trip = 1
        ii = ii + 1

    return lp.loop_is_const_trip

// ── 6. Loop Detector Entry Point ──────────────────────────────────────────────
// Returns list of Loop objects discovered in the function

fn loop_info_detect_loops fn_obj dt
    loops = list()
    if fn_obj == 0 or dt == 0 return loops

    cfg_rebuild_edges(fn_obj)

    // Scan all CFG edges (u, v) for back-edges: where v dominates u
    bi = 0
    while bi < len(fn_obj.blocks)
        u_bb = get(fn_obj.blocks, bi)
        si = 0
        while si < len(u_bb.successors)
            v_lbl = get(u_bb.successors, si)
            // If v dominates u, (u -> v) is a back-edge!
            if dom_tree_dominates(dt, v_lbl, u_bb.label) == 1
                lp = loop_new(v_lbl, u_bb.label)
                loop_populate_blocks(lp, fn_obj)
                loop_resolve_preheader(lp, fn_obj)
                loop_collect_exits(lp, fn_obj)
                loop_analyze_induction_variables(lp, fn_obj)
                push(loops, lp)
            si = si + 1
        bi = bi + 1

    return loops
