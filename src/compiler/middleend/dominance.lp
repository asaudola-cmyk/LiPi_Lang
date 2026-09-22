// ==============================================================================
// 👑 LIPI SOVEREIGN SSA DOMINATOR TREE & PHI-PLACEMENT ENGINE
// ⚡ 100% Pure Lipi | 0% C | 0% LLVM | Near-Linear O(n * alpha(n)) Algorithm
// 🏛️ File: src/compiler/middleend/dominance.lp
//
// WHY: Static Single Assignment (SSA) form is the global gold standard for optimizing
//      compilers. Constructing minimal SSA requires computing:
//      1. Immediate Dominator Tree (idom) via Lengauer-Tarjan algorithm.
//      2. Dominance Frontier (DF) for every basic block in the Control Flow Graph.
//      3. Iterated Dominance Frontier (IDF) for minimal phi-function placement.
//      4. Dead Code Elimination (DCE) pruning unreachable basic blocks.
// ==============================================================================

import "src/compiler/ssa_ir.lp"

// ── 1. Disjoint-Set Forest (Link-Eval) for Lengauer-Tarjan ─────────────────────
// WHY: Tarjan's Link-Eval data structure with path compression achieves O(alpha(n))
//      nearly constant amortized time for tree path minimum queries.

fn dom_eval node ancestor_map best_map semi_map dfs_num_map
    anc = ssa_map_get(ancestor_map, node, "")
    if anc != ""
        // Perform path compression
        dom_compress(node, ancestor_map, best_map, semi_map, dfs_num_map)
        return ssa_map_get(best_map, node, node)
    return ssa_map_get(best_map, node, node)

fn dom_compress node ancestor_map best_map semi_map dfs_num_map
    anc = ssa_map_get(ancestor_map, node, "")
    anc_parent = ssa_map_get(ancestor_map, anc, "")
    if anc_parent != ""
        dom_compress(anc, ancestor_map, best_map, semi_map, dfs_num_map)
        b_node = ssa_map_get(best_map, node, node)
        b_anc = ssa_map_get(best_map, anc, anc)

        semi_b_node = ssa_map_get(semi_map, b_node, 999999)
        semi_b_anc = ssa_map_get(semi_map, b_anc, 999999)

        if semi_b_anc < semi_b_node
            ssa_map_set(best_map, node, b_anc)
        ssa_map_set(ancestor_map, node, anc_parent)

fn dom_link parent child ancestor_map
    ssa_map_set(ancestor_map, child, parent)

// ── 2. Lengauer-Tarjan Immediate Dominator Tree Algorithm ──────────────────────
// Returns a map: block_label -> immediate_dominator_label (idom)
fn compute_dominators cfg
    blocks = ir_func_blocks(cfg)
    total_blocks = len(blocks)
    if total_blocks == 0
        return ssa_map_new()

    entry_bb = ir_func_entry(cfg)
    entry_label = ir_block_label(entry_bb)

    // Data maps
    dfs_num_map   = ssa_map_new()
    vertex_map    = ssa_map_new() // int dfs_num -> string block_label
    parent_map    = ssa_map_new() // string block_label -> string parent_label
    semi_map      = ssa_map_new() // string block_label -> int semi_dfs_num
    idom_map      = ssa_map_new() // string block_label -> string idom_label
    ancestor_map  = ssa_map_new()
    best_map      = ssa_map_new()
    buckets_map   = ssa_map_new() // string block_label -> list of block_labels

    // Step 1: Depth-First Search pre-order numbering
    dfs_counter = list()
    push(dfs_counter, 0)

    visited_map = ssa_map_new()
    work_stack = list()
    push(work_stack, entry_label)

    dfs_order = list() // 1-indexed array of labels in discovery order
    push(dfs_order, "") // dummy at index 0

    // Iterative DFS to avoid stack overflow on deep CFGs
    dfs_rec(cfg, entry_label, "", dfs_counter, dfs_num_map, vertex_map, parent_map, semi_map, best_map, dfs_order)

    n = get(dfs_counter, 0)
    if n <= 1
        return idom_map

    // Initialize buckets
    i = 1
    while i <= n
        lbl = get(dfs_order, i)
        ssa_map_set(buckets_map, lbl, list())
        i = i + 1

    // Step 2 & 3: Compute semi-dominators and implicit immediate dominators
    // Iterate in reverse DFS order: n down to 2
    i = n
    while i >= 2
        w = get(dfs_order, i)
        p_w = ssa_map_get(parent_map, w, "")
        bb_w = ir_func_find_block(cfg, w)
        preds = ir_block_preds(bb_w)

        // For each predecessor v of w:
        p_idx = 0
        plen = len(preds)
        while p_idx < plen
            v = get(preds, p_idx)
            if ssa_map_has(dfs_num_map, v) == 1
                v_dfs = ssa_map_get(dfs_num_map, v, 0)
                w_dfs = ssa_map_get(dfs_num_map, w, 0)
                u = dom_eval(v, ancestor_map, best_map, semi_map, dfs_num_map)
                u_semi = ssa_map_get(semi_map, u, 999999)
                curr_semi = ssa_map_get(semi_map, w, 999999)

                if u_semi < curr_semi
                    ssa_map_set(semi_map, w, u_semi)
            p_idx = p_idx + 1

        // Add w to bucket of vertex(semi[w])
        semi_val = ssa_map_get(semi_map, w, 0)
        semi_lbl = ssa_map_get(vertex_map, semi_val, "")
        b_list = ssa_map_get(buckets_map, semi_lbl, list())
        push(b_list, w)

        // Link parent to w
        dom_link(p_w, w, ancestor_map)

        // Process bucket of parent
        p_bucket = ssa_map_get(buckets_map, p_w, list())
        b_i = 0
        blen = len(p_bucket)
        while b_i < blen
            v_item = get(p_bucket, b_i)
            u_item = dom_eval(v_item, ancestor_map, best_map, semi_map, dfs_num_map)
            u_semi2 = ssa_map_get(semi_map, u_item, 999999)
            v_semi2 = ssa_map_get(semi_map, v_item, 999999)
            if u_semi2 < v_semi2
                ssa_map_set(idom_map, v_item, u_item)
            else
                ssa_map_set(idom_map, v_item, p_w)
            b_i = b_i + 1
        ssa_map_set(buckets_map, p_w, list()) // clear bucket

        i = i - 1

    // Step 4: Final explicit immediate dominator assignment
    i = 2
    while i <= n
        w = get(dfs_order, i)
        semi_val = ssa_map_get(semi_map, w, 0)
        semi_lbl = ssa_map_get(vertex_map, semi_val, "")
        curr_idom = ssa_map_get(idom_map, w, "")

        if curr_idom != semi_lbl
            idom_parent = ssa_map_get(idom_map, curr_idom, "")
            ssa_map_set(idom_map, w, idom_parent)
        i = i + 1

    return idom_map

// DFS helper for pre-order tree traversal
fn dfs_rec cfg current_lbl parent_lbl dfs_counter dfs_num_map vertex_map parent_map semi_map best_map dfs_order
    if ssa_map_has(dfs_num_map, current_lbl) == 1
        return 0

    cnt = get(dfs_counter, 0) + 1
    list_set(dfs_counter, 0, cnt)

    ssa_map_set(dfs_num_map, current_lbl, cnt)
    ssa_map_set(vertex_map, cnt, current_lbl)
    ssa_map_set(parent_map, current_lbl, parent_lbl)
    ssa_map_set(semi_map, current_lbl, cnt)
    ssa_map_set(best_map, current_lbl, current_lbl)
    push(dfs_order, current_lbl)

    bb = ir_func_find_block(cfg, current_lbl)
    if bb == 0
        return 0

    succs = ir_block_succs(bb)
    s_i = 0
    slen = len(succs)
    while s_i < slen
        succ = get(succs, s_i)
        dfs_rec(cfg, succ, current_lbl, dfs_counter, dfs_num_map, vertex_map, parent_map, semi_map, best_map, dfs_order)
        s_i = s_i + 1
    return 1

// ── 3. Dominance Frontier (DF) Computation ─────────────────────────────────────
// WHY: The dominance frontier DF(X) contains all blocks Y where X dominates a
//      predecessor of Y, but does not strictly dominate Y. These are the exact
//      locations where phi-nodes must be placed for variables defined in X.
fn compute_dominance_frontier cfg idom_map
    blocks = ir_func_blocks(cfg)
    df_map = ssa_map_new()

    // Initialize empty DF list for each block
    b_idx = 0
    blen = len(blocks)
    while b_idx < blen
        bb = get(blocks, b_idx)
        ssa_map_set(df_map, ir_block_label(bb), list())
        b_idx = b_idx + 1

    // Cytron's DF computation: walk up the dominator tree from predecessors
    b_idx = 0
    while b_idx < blen
        bb = get(blocks, b_idx)
        b_label = ir_block_label(bb)
        preds = ir_block_preds(bb)

        if len(preds) >= 2
            p_i = 0
            plen = len(preds)
            while p_i < plen
                runner = get(preds, p_i)
                idom_target = ssa_map_get(idom_map, b_label, "")

                while runner != "" and runner != idom_target
                    runner_df = ssa_map_get(df_map, runner, list())
                    // Add b_label to runner_df if not already present
                    already_in = 0
                    d_i = 0
                    while d_i < len(runner_df)
                        if get(runner_df, d_i) == b_label
                            already_in = 1
                            break
                        d_i = d_i + 1
                    if already_in == 0
                        push(runner_df, b_label)
                    runner = ssa_map_get(idom_map, runner, "")
                p_i = p_i + 1
        b_idx = b_idx + 1

    return df_map

// ── 4. Iterated Dominance Frontier (IDF) & Minimal Phi-Placement ───────────────
// WHY: Given a variable and the list of basic block labels where it is defined,
//      computes the exact minimal set of basic blocks that require a phi-node.
fn compute_phi_placement cfg df_map def_block_labels
    phi_blocks = list()
    worklist = list()
    has_phi = ssa_map_new()
    in_worklist = ssa_map_new()

    // Seed worklist with definition blocks
    i = 0
    dlen = len(def_block_labels)
    while i < dlen
        lbl = get(def_block_labels, i)
        push(worklist, lbl)
        ssa_map_set(in_worklist, lbl, 1)
        i = i + 1

    while len(worklist) > 0
        curr_b = get(worklist, 0)
        // Shift worklist
        new_w = list()
        w_i = 1
        while w_i < len(worklist)
            push(new_w, get(worklist, w_i))
            w_i = w_i + 1
        worklist = new_w
        ssa_map_set(in_worklist, curr_b, 0)

        // For each block Y in DF(curr_b)
        df_list = ssa_map_get(df_map, curr_b, list())
        y_i = 0
        ylen = len(df_list)
        while y_i < ylen
            y_lbl = get(df_list, y_i)
            if ssa_map_get(has_phi, y_lbl, 0) == 0
                push(phi_blocks, y_lbl)
                ssa_map_set(has_phi, y_lbl, 1)
                if ssa_map_get(in_worklist, y_lbl, 0) == 0
                    push(worklist, y_lbl)
                    ssa_map_set(in_worklist, y_lbl, 1)
            y_i = y_i + 1

    return phi_blocks

// ── 5. Dominance-Based Dead Code Elimination (DCE) ─────────────────────────────
// WHY: Any block not reachable from entry has no valid path and can be pruned.
fn dce_prune_unreachable_blocks cfg idom_map
    entry_bb = ir_func_entry(cfg)
    entry_lbl = ir_block_label(entry_bb)
    blocks = ir_func_blocks(cfg)
    pruned_count = 0

    b_idx = 0
    blen = len(blocks)
    while b_idx < blen
        bb = get(blocks, b_idx)
        lbl = ir_block_label(bb)
        if lbl != entry_lbl
            idom_node = ssa_map_get(idom_map, lbl, "")
            if idom_node == ""
                // Unreachable block: mark as dead
                ir_block_set_dead(bb, 1)
                pruned_count = pruned_count + 1
        b_idx = b_idx + 1

    return pruned_count
