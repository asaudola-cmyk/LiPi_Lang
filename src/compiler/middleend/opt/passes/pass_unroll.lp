// ==============================================================================
// 👑 LIPI FIRST 1.0.0 LOOP UNROLLING PASS (src/compiler/middleend/opt/passes/pass_unroll.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Loop Unrolling eliminates the branching penalty, induction variable increment,
//      and comparison overhead for loops with small, compile-time constant trip counts.
//      1. Pipeline Efficiency: Transforms tight cyclic control flow into straight-line
//         code, enabling full hardware instruction pipeline utilization with zero branch mispredicts.
//      2. Enabling Secondary Passes: Unrolling exposes inter-iteration constant values
//         and algebraic expressions to subsequent Constant Folding, Peephole, and CSE passes.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/loop_info.lp"

// ── 1. Helper to Map Copied SSA Values ────────────────────────────────────────

struct ValueMap
    keys  // list of SSAValue (old)
    vals  // list of SSAValue (new)

fn value_map_new
    vm = ValueMap()
    vm.keys = list()
    vm.vals = list()
    return vm

fn value_map_get vm old_val
    if vm == 0 or old_val == 0 return old_val
    i = 0
    cnt = len(vm.keys)
    while i < cnt
        if get(vm.keys, i) == old_val
            return get(vm.vals, i)
        i = i + 1
    return old_val

fn value_map_set vm old_val new_val
    if vm == 0 or old_val == 0 return 0
    i = 0
    cnt = len(vm.keys)
    while i < cnt
        if get(vm.keys, i) == old_val
            list_set(vm.vals, i, new_val)
            return 1
        i = i + 1
    push(vm.keys, old_val)
    push(vm.vals, new_val)
    return 1

// ── 2. Loop Unroller Implementation ───────────────────────────────────────────

fn pass_unroll_single_loop fn_obj lp
    if fn_obj == 0 or lp == 0 return 0
    trip_k = loop_get_trip_count(lp)
    if trip_k <= 0 or trip_k > 8 return 0
    if len(loop_get_exits(lp)) != 1 return 0

    header_lbl = loop_get_header(lp)
    latch_lbl = loop_get_latch(lp)
    preheader_lbl = loop_get_preheader(lp)
    exit_lbl = get(loop_get_exits(lp), 0)

    header_bb = ir_function_find_block(fn_obj, header_lbl)
    latch_bb = ir_function_find_block(fn_obj, latch_lbl)
    preheader_bb = ir_function_find_block(fn_obj, preheader_lbl)
    exit_bb = ir_function_find_block(fn_obj, exit_lbl)

    if header_bb == 0 or latch_bb == 0 or preheader_bb == 0 or exit_bb == 0
        return 0

    // Create unrolled block
    unrolled_bb = ir_function_create_block(fn_obj, "unrolled_loop")

    ind_var = loop_get_ind_var(lp)
    step_k = lp.loop_ind_step_val
    curr_ind_val = lp.loop_ind_init_val

    vmap = value_map_new()

    // Unroll trip_k iterations
    iter = 0
    while iter < trip_k
        // Bind current iteration's induction variable to constant value
        const_i = ssa_value_new_const(curr_ind_val, "i64")
        if ind_var != 0
            value_map_set(vmap, ind_var, const_i)

        // Clone non-control instructions from loop blocks
        bi = 0
        while bi < len(loop_get_blocks(lp))
            b_lbl = get(loop_get_blocks(lp), bi)
            if b_lbl != preheader_lbl
                bb = ir_function_find_block(fn_obj, b_lbl)
                if bb != 0
                    ii = 0
                    while ii < len(bb.instructions)
                        inst = get(bb.instructions, ii)
                        // Skip Phis, loop branches, jumps, and induction variable increments
                        if inst.op != OP_PHI and inst.op != OP_BR and inst.op != OP_JMP
                            // Skip induction step instruction
                            is_ind_step = 0
                            if ind_var != 0 and len(inst.operands) == 2
                                if get(inst.operands, 0) == ind_var and (inst.op == OP_ADD or inst.op == OP_SUB)
                                    is_ind_step = 1

                            if is_ind_step == 0
                                // Create cloned instruction
                                cloned_res = 0
                                if inst.result != 0
                                    cloned_res = fn_obj.new_val(inst.result.vtype)
                                    value_map_set(vmap, inst.result, cloned_res)

                                cloned_inst = ssa_instr_new(1, inst.op, cloned_res, unrolled_bb)
                                cloned_inst.extra_int = inst.extra_int
                                cloned_inst.extra_str = inst.extra_str

                                oi = 0
                                while oi < len(inst.operands)
                                    opnd = get(inst.operands, oi)
                                    mapped_opnd = value_map_get(vmap, opnd)
                                    push(cloned_inst.operands, mapped_opnd)
                                    ssa_value_add_use(mapped_opnd, cloned_inst)
                                    oi = oi + 1

                                push(unrolled_bb.instructions, cloned_inst)
                        ii = ii + 1
            bi = bi + 1

        curr_ind_val = curr_ind_val + step_k
        iter = iter + 1

    // Terminate unrolled block with jump to exit
    unrolled_jmp = ir_build_jmp(1, exit_lbl)
    basic_block_append_inst(unrolled_bb, unrolled_jmp)

    // Reroute preheader terminator to unrolled_bb
    p_term = basic_block_get_terminator(preheader_bb)
    if p_term != 0
        if p_term.op == OP_JMP p_term.extra_str = unrolled_bb.label
        if p_term.op == OP_BR
            if len(p_term.extra_list) >= 2
                if get(p_term.extra_list, 0) == header_lbl
                    list_set(p_term.extra_list, 0, unrolled_bb.label)
                if get(p_term.extra_list, 1) == header_lbl
                    list_set(p_term.extra_list, 1, unrolled_bb.label)

    // Update Phi nodes in exit_bb
    ei = 0
    while ei < len(exit_bb.instructions)
        e_inst = get(exit_bb.instructions, ei)
        if e_inst.op == OP_PHI
            pi = 0
            while pi < len(e_inst.extra_list)
                lbl = get(e_inst.extra_list, pi)
                if loop_contains_block(lp, lbl) == 1
                    list_set(e_inst.extra_list, pi, unrolled_bb.label)
                    old_opnd = get(e_inst.operands, pi)
                    new_opnd = value_map_get(vmap, old_opnd)
                    if new_opnd != old_opnd
                        list_set(e_inst.operands, pi, new_opnd)
                        ssa_value_remove_use(old_opnd, e_inst)
                        ssa_value_add_use(new_opnd, e_inst)
                pi = pi + 1
        ei = ei + 1

    // Remove old loop blocks
    del_i = 0
    while del_i < len(loop_get_blocks(lp))
        del_lbl = get(loop_get_blocks(lp), del_i)
        if del_lbl != preheader_lbl
            del_bb = ir_function_find_block(fn_obj, del_lbl)
            if del_bb != 0
                ir_function_remove_block(fn_obj, del_bb)
        del_i = del_i + 1

    cfg_rebuild_edges(fn_obj)
    return 1

// ── 3. Main Loop Unrolling Pass ───────────────────────────────────────────────

fn pass_unroll_run fn_obj
    if fn_obj == 0 return 0

    cfg_rebuild_edges(fn_obj)
    dt = dom_tree_compute(fn_obj)
    loops = loop_info_detect_loops(fn_obj, dt)

    if len(loops) == 0 return 0

    unrolled_total = 0
    li = 0
    while li < len(loops)
        lp = get(loops, li)
        if loop_is_const_trip(lp) == 1
            if pass_unroll_single_loop(fn_obj, lp) == 1
                unrolled_total = unrolled_total + 1
        li = li + 1

    return unrolled_total
