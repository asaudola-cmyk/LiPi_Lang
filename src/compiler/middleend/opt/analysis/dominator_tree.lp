// ==============================================================================
// 👑 LIPI FIRST 1.0.0 DOMINATOR TREE & DOMINANCE FRONTIER (src/compiler/middleend/opt/analysis/dominator_tree.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Dominance is the core structural relation of SSA Intermediate Representation.
//      Node D dominates node N (D dom N) if every execution path from the CFG entry
//      to N must pass through D.
//      1. Immediate Dominator (idom): Forms the Dominator Tree used by Common Subexpression
//         Elimination (CSE) and Loop Invariant Code Motion (LICM) to verify that an
//         available expression or hoisted value is guaranteed to dominate all its uses.
//      2. Dominance Frontier (DF): Identifies the exact confluence points where multiple
//         definitions converge, determining minimal placement locations for Phi nodes.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/cfg.lp"

// ── 1. Dominator Tree Structure ───────────────────────────────────────────────

struct DomTree
    fn_ref        // reference to IRFunction
    block_labels  // list of block label strings
    idoms         // list of immediate dominator labels parallel to block_labels
    rpo_nums      // list of integer RPO ranks parallel to block_labels
    df_lists      // list of string lists (dominance frontier for each block)

fn dom_tree_new fn_ref
    dt = DomTree()
    dt.fn_ref = fn_ref
    dt.block_labels = list()
    dt.idoms = list()
    dt.rpo_nums = list()
    dt.df_lists = list()
    return dt

// ── 2. Internal Lookup Helpers ────────────────────────────────────────────────

fn dom_tree_find_idx dt label
    i = 0
    cnt = len(dt.block_labels)
    while i < cnt
        if get(dt.block_labels, i) == label
            return i
        i = i + 1
    return 0 - 1

fn dom_tree_get_idom dt label
    idx = dom_tree_find_idx(dt, label)
    if idx < 0 return ""
    return get(dt.idoms, idx)

fn dom_tree_set_idom dt label idom_lbl
    idx = dom_tree_find_idx(dt, label)
    if idx >= 0
        list_set(dt.idoms, idx, idom_lbl)
        return 1
    return 0

fn dom_tree_get_rpo_num dt label
    idx = dom_tree_find_idx(dt, label)
    if idx < 0 return 999999
    return get(dt.rpo_nums, idx)

// ── 3. Cooper-Harvey-Kennedy Intersection Algorithm ───────────────────────────
// WHY: Climbs the Dominator Tree using RPO ranks until the two paths meet at the
//      Lowest Common Ancestor (LCA), achieving near-linear performance with zero recursion.

fn dom_tree_intersect dt b1 b2
    finger1 = b1
    finger2 = b2
    while finger1 != finger2
        while dom_tree_get_rpo_num(dt, finger1) > dom_tree_get_rpo_num(dt, finger2)
            finger1 = dom_tree_get_idom(dt, finger1)
            if len(finger1) == 0 return finger2
        while dom_tree_get_rpo_num(dt, finger2) > dom_tree_get_rpo_num(dt, finger1)
            finger2 = dom_tree_get_idom(dt, finger2)
            if len(finger2) == 0 return finger1
    return finger1

// ── 4. Dominator Tree Construction ────────────────────────────────────────────

fn dom_tree_compute fn_obj
    dt = dom_tree_new(fn_obj)
    if fn_obj == 0 or fn_obj.entry_block == 0 return dt

    // Step 1: Rebuild edges and compute Reverse Post-Order (RPO)
    cfg_rebuild_edges(fn_obj)
    rpo_list = cfg_compute_rpo(fn_obj)
    rpo_cnt = len(rpo_list)
    if rpo_cnt == 0 return dt

    entry_lbl = fn_obj.entry_block.label

    // Step 2: Initialize data arrays
    i = 0
    while i < rpo_cnt
        bb = get(rpo_list, i)
        push(dt.block_labels, bb.label)
        push(dt.idoms, "")
        push(dt.rpo_nums, i)
        push(dt.df_lists, list())
        i = i + 1

    // Entry block dominates itself
    dom_tree_set_idom(dt, entry_lbl, entry_lbl)

    // Step 3: Fixed-point iteration in RPO order
    changed = 1
    while changed == 1
        changed = 0
        idx = 0
        while idx < rpo_cnt
            bb = get(rpo_list, idx)
            lbl = bb.label
            if lbl != entry_lbl
                // Find first processed predecessor
                new_idom = ""
                pi = 0
                pcnt = len(bb.predecessors)
                while pi < pcnt
                    p_lbl = get(bb.predecessors, pi)
                    if len(dom_tree_get_idom(dt, p_lbl)) > 0
                        new_idom = p_lbl
                        pi = pcnt // break
                    pi = pi + 1

                // Intersect with remaining processed predecessors
                pj = 0
                while pj < pcnt
                    p_lbl = get(bb.predecessors, pj)
                    if p_lbl != new_idom and len(dom_tree_get_idom(dt, p_lbl)) > 0
                        new_idom = dom_tree_intersect(dt, p_lbl, new_idom)
                    pj = pj + 1

                // Check if idom changed
                curr_idom = dom_tree_get_idom(dt, lbl)
                if curr_idom != new_idom
                    dom_tree_set_idom(dt, lbl, new_idom)
                    changed = 1

            idx = idx + 1

    // Step 4: Dominance Frontier Calculation (Cytron et al.)
    // WHY: DF(X) contains nodes Y where X dominates a predecessor of Y but does not strictly dominate Y.
    bi = 0
    while bi < rpo_cnt
        bb = get(rpo_list, bi)
        if len(bb.predecessors) >= 2
            curr_idom = dom_tree_get_idom(dt, bb.label)
            pi = 0
            while pi < len(bb.predecessors)
                runner = get(bb.predecessors, pi)
                while runner != curr_idom and len(runner) > 0 and runner != entry_lbl
                    // Add bb.label to DF(runner)
                    r_idx = dom_tree_find_idx(dt, runner)
                    if r_idx >= 0
                        df = get(dt.df_lists, r_idx)
                        // Add without duplicates
                        already_in_df = 0
                        di = 0
                        while di < len(df)
                            if get(df, di) == bb.label already_in_df = 1
                            di = di + 1
                        if already_in_df == 0 push(df, bb.label)
                    runner = dom_tree_get_idom(dt, runner)
                pi = pi + 1
        bi = bi + 1

    return dt

// ── 5. Dominance Query ────────────────────────────────────────────────────────
// Returns 1 if block `a_label` dominates block `b_label`

fn dom_tree_dominates dt a_label b_label
    if dt == 0 return 0
    if a_label == b_label return 1

    curr = b_label
    entry_lbl = dt.fn_ref.entry_block.label
    visited_cnt = 0
    max_steps = len(dt.block_labels) + 2

    while len(curr) > 0 and curr != entry_lbl and visited_cnt < max_steps
        curr = dom_tree_get_idom(dt, curr)
        if curr == a_label return 1
        visited_cnt = visited_cnt + 1

    return 0

// Returns 1 if `a_label` strictly dominates `b_label` (a dominates b and a != b)
fn dom_tree_strictly_dominates dt a_label b_label
    if a_label == b_label return 0
    return dom_tree_dominates(dt, a_label, b_label)

// Retrieves the Dominance Frontier list for a given block
fn dom_tree_get_frontier dt label
    idx = dom_tree_find_idx(dt, label)
    if idx < 0 return list()
    return get(dt.df_lists, idx)
