// ==============================================================================
// 👑 LIPI FIRST 1.0.0 DEAD CODE ELIMINATION (DCE) PASS (src/compiler/middleend/opt/passes/pass_dce.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Dead Code Elimination (DCE) strips instructions and basic blocks that have
//      no observable effect on program execution.
//      1. Dead Instruction Elimination: In SSA form, an instruction is dead if its
//         result value has 0 uses and the instruction has no side-effects (not Store,
//         Call, or Terminator). Eliminating it cascades, often reducing use counts
//         of its operands to 0 and triggering further elimination.
//      2. Unreachable Block Pruning: Any basic block disjoint from the entry block
//         in the CFG reachability graph is deleted, and its edges into successor
//         Phi nodes are cleaned up to maintain SSA validity.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/cfg.lp"

// ── 1. Phi Node Cleanup on Block Deletion ──────────────────────────────────────
// WHY: When an unreachable predecessor block is deleted, successor Phi nodes must
//      have incoming value entries for that predecessor removed to preserve the
//      Phi-predecessor correspondence invariant.

fn dce_prune_phi_edges_for_block fn_obj dead_bb
    si = 0
    while si < len(dead_bb.successors)
        succ_lbl = get(dead_bb.successors, si)
        succ_bb = ir_function_find_block(fn_obj, succ_lbl)
        if succ_bb != 0
            ii = 0
            while ii < len(succ_bb.instructions)
                inst = get(succ_bb.instructions, ii)
                if inst.op == OP_PHI
                    new_operands = list()
                    new_bbs = list()
                    pi = 0
                    while pi < len(inst.extra_list)
                        lbl = get(inst.extra_list, pi)
                        opnd = get(inst.operands, pi)
                        if lbl != dead_bb.label
                            push(new_operands, opnd)
                            push(new_bbs, lbl)
                        else
                            ssa_value_remove_use(opnd, inst)
                        pi = pi + 1
                    inst.operands = new_operands
                    inst.extra_list = new_bbs
                ii = ii + 1
        si = si + 1
    return 1

// ── 2. Dead Instruction Sweeper ───────────────────────────────────────────────

fn dce_sweep_dead_instructions fn_obj
    eliminated = 0
    bi = 0
    while bi < len(fn_obj.blocks)
        bb = get(fn_obj.blocks, bi)
        new_insts = list()
        ii = 0
        while ii < len(bb.instructions)
            inst = get(bb.instructions, ii)
            // Check if instruction is dead
            is_dead = 0
            if inst.result != 0 and ssa_has_side_effects(inst.op) == 0
                if ssa_value_use_count(inst.result) == 0
                    is_dead = 1

            if is_dead == 1
                ssa_instr_remove_from_operands_use_lists(inst)
                inst.is_dead = 1
                eliminated = eliminated + 1
            else
                push(new_insts, inst)
            ii = ii + 1

        bb.instructions = new_insts
        bi = bi + 1

    return eliminated

// ── 3. Unreachable Block Sweeper ──────────────────────────────────────────────

fn dce_sweep_unreachable_blocks fn_obj
    unreachable = cfg_get_unreachable_blocks(fn_obj)
    if len(unreachable) == 0 return 0

    eliminated_blocks = 0
    ui = 0
    while ui < len(unreachable)
        dead_bb = get(unreachable, ui)
        // Ensure we never delete the canonical entry block
        if dead_bb != fn_obj.entry_block
            dce_prune_phi_edges_for_block(fn_obj, dead_bb)
            ir_function_remove_block(fn_obj, dead_bb)
            eliminated_blocks = eliminated_blocks + 1
        ui = ui + 1

    if eliminated_blocks > 0
        cfg_rebuild_edges(fn_obj)

    return eliminated_blocks

// ── 4. Main DCE Pass (Iterative Fixed-Point) ───────────────────────────────────

fn pass_dce_run fn_obj
    if fn_obj == 0 return 0
    total_eliminated = 0

    changed = 1
    max_iterations = 32
    iters = 0

    while changed == 1 and iters < max_iterations
        changed = 0

        // Phase 1: Dead instruction elimination
        insts_killed = dce_sweep_dead_instructions(fn_obj)
        if insts_killed > 0
            total_eliminated = total_eliminated + insts_killed
            changed = 1

        // Phase 2: Unreachable basic block elimination
        blocks_killed = dce_sweep_unreachable_blocks(fn_obj)
        if blocks_killed > 0
            total_eliminated = total_eliminated + blocks_killed
            changed = 1

        iters = iters + 1

    return total_eliminated
