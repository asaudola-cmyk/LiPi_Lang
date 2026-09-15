// ==============================================================================
// 👑 LIPI FIRST 1.0.0 CFG BUILDER & TRAVERSER (src/compiler/middleend/opt/analysis/cfg.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Control Flow Graph (CFG) analysis is the foundational substrate of compiler
//      optimization. CFG analysis establishes:
//      1. Edge Symmetry: Reconstructing predecessor and successor edges directly from
//         terminator branch instructions.
//      2. Reverse Post-Order (RPO) Traversal: A topological ordering where predecessors
//         are processed before successors (essential for iterative dataflow convergence).
//      3. Reachability Analysis: Identifying dead blocks disjoint from the entry block.
//      4. Critical Edge Splitting: Eliminating edges from multi-successor blocks to
//         multi-predecessor blocks, which is necessary for phi-lowering and code motion.
// ==============================================================================

include "src/compiler/middleend/ir/ir_function.lp"

// ── 1. CFG Edge Rebuilder ─────────────────────────────────────────────────────
// WHY: Transformations like dead block pruning, branch folding, and unrolling
//      mutate terminator targets. Rebuilding edges guarantees 100% consistency.

fn cfg_rebuild_edges fn_obj
    if fn_obj == 0 return 0
    bcnt = len(fn_obj.blocks)

    // Step 1: Clear existing edge lists on all blocks
    bi = 0
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        bb.predecessors = list()
        bb.successors = list()
        bi = bi + 1

    // Step 2: Scan terminator instructions and reconstruct edges
    bi = 0
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        term = basic_block_get_terminator(bb)
        if term != 0
            if term.op == OP_JMP
                target_lbl = term.extra_str
                basic_block_add_succ(bb, target_lbl)
                target_bb = ir_function_find_block(fn_obj, target_lbl)
                if target_bb != 0
                    basic_block_add_pred(target_bb, bb.label)

            if term.op == OP_BR
                if len(term.extra_list) >= 2
                    true_lbl = get(term.extra_list, 0)
                    false_lbl = get(term.extra_list, 1)

                    basic_block_add_succ(bb, true_lbl)
                    true_bb = ir_function_find_block(fn_obj, true_lbl)
                    if true_bb != 0
                        basic_block_add_pred(true_bb, bb.label)

                    basic_block_add_succ(bb, false_lbl)
                    false_bb = ir_function_find_block(fn_obj, false_lbl)
                    if false_bb != 0
                        basic_block_add_pred(false_bb, bb.label)
        bi = bi + 1

    return 1

// ── 2. Depth-First Search & Post-Order Traversal ───────────────────────────────

fn cfg_dfs_post_order fn_obj current_bb visited_labels post_order_list
    if current_bb == 0 return 0

    // Mark as visited
    push(visited_labels, current_bb.label)

    // Recurse on all successors
    si = 0
    scnt = len(current_bb.successors)
    while si < scnt
        succ_lbl = get(current_bb.successors, si)
        // Check if already visited
        already_visited = 0
        vi = 0
        while vi < len(visited_labels)
            if get(visited_labels, vi) == succ_lbl
                already_visited = 1
            vi = vi + 1

        if already_visited == 0
            succ_bb = ir_function_find_block(fn_obj, succ_lbl)
            if succ_bb != 0
                cfg_dfs_post_order(fn_obj, succ_bb, visited_labels, post_order_list)
        si = si + 1

    // Backtrack: push to post-order list
    push(post_order_list, current_bb)
    return 1

// Computes standard Post-Order list of basic blocks reachable from entry
fn cfg_compute_post_order fn_obj
    post_order_list = list()
    if fn_obj == 0 or fn_obj.entry_block == 0 return post_order_list
    visited_labels = list()
    cfg_dfs_post_order(fn_obj, fn_obj.entry_block, visited_labels, post_order_list)
    return post_order_list

// ── 3. Reverse Post-Order (RPO) Traversal ─────────────────────────────────────
// WHY: In a directed acyclic graph or natural loop structure, Reverse Post-Order
//      processes defining blocks before their users, accelerating dataflow convergence.

fn cfg_compute_rpo fn_obj
    po = cfg_compute_post_order(fn_obj)
    rpo = list()
    i = len(po) - 1
    while i >= 0
        push(rpo, get(po, i))
        i = i - 1
    return rpo

// ── 4. Reachability Analysis ──────────────────────────────────────────────────
// WHY: Unreachable blocks waste instruction cache and register resources.
//      Identifying them allows Dead Code Elimination to prune them completely.

fn cfg_get_unreachable_blocks fn_obj
    unreachable = list()
    if fn_obj == 0 return unreachable

    visited = list()
    po = list()
    if fn_obj.entry_block != 0
        cfg_dfs_post_order(fn_obj, fn_obj.entry_block, visited, po)

    // Compare visited against all blocks in function
    bi = 0
    bcnt = len(fn_obj.blocks)
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        is_visited = 0
        vi = 0
        while vi < len(visited)
            if get(visited, vi) == bb.label
                is_visited = 1
            vi = vi + 1
        if is_visited == 0
            push(unreachable, bb)
        bi = bi + 1

    return unreachable

// ── 5. Critical Edge Splitting ────────────────────────────────────────────────
// WHY: A critical edge connects a block with > 1 successor to a block with > 1 predecessor.
//      If an instruction were hoisted or phi node lowered onto a critical edge without
//      splitting, it would erroneously execute for other unrelated execution paths.

fn cfg_split_critical_edges fn_obj
    if fn_obj == 0 return 0
    split_count = 0

    bi = 0
    while bi < len(fn_obj.blocks)
        bb = get(fn_obj.blocks, bi)
        if len(bb.successors) > 1
            term = basic_block_get_terminator(bb)
            if term != 0 and term.op == OP_BR
                si = 0
                while si < 2
                    succ_lbl = get(term.extra_list, si)
                    succ_bb = ir_function_find_block(fn_obj, succ_lbl)
                    if succ_bb != 0 and len(succ_bb.predecessors) > 1
                        // This is a critical edge (bb -> succ_bb)
                        // Create intermediate trampoline block
                        trampoline = ir_function_create_block(fn_obj, "crit_split")
                        jmp_inst = ir_build_jmp(1, succ_lbl)
                        basic_block_append_inst(trampoline, jmp_inst)

                        // Reroute terminator in source block
                        list_set(term.extra_list, si, trampoline.label)

                        // In succ_bb, update any Phi nodes referencing bb to trampoline
                        ii = 0
                        while ii < len(succ_bb.instructions)
                            p_inst = get(succ_bb.instructions, ii)
                            if p_inst.op == OP_PHI
                                pi = 0
                                while pi < len(p_inst.extra_list)
                                    if get(p_inst.extra_list, pi) == bb.label
                                        list_set(p_inst.extra_list, pi, trampoline.label)
                                    pi = pi + 1
                            ii = ii + 1

                        split_count = split_count + 1
                    si = si + 1
        bi = bi + 1

    if split_count > 0
        cfg_rebuild_edges(fn_obj)

    return split_count
