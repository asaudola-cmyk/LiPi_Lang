// ==============================================================================
// 👑 LIPI FIRST 1.0.0 DEAD STORE ELIMINATION (DSE) (src/compiler/middleend/opt/passes/pass_dse.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Dead Store Elimination (DSE) detects and eliminates memory writes that have
//      no observable effect on program execution:
//      1. Overwritten Stores: If a store to pointer P is immediately overwritten by
//         another store to P within the same basic block without an intervening load
//         or function call, the first store is dead.
//      2. Unread Alloca Stores: If a local stack slot (Alloca) does not escape to
//         external function calls and has zero Load instructions across the entire
//         function body, all stores to that slot are dead and can be discarded.
//      3. Cache & Bus Bandwidth: Eliminating dead stores saves L1/L2 cache write-backs
//         and reduces memory bus traffic.
// ==============================================================================

include "src/compiler/middleend/ir/ir_function.lp"

// ── 1. Alloca Escape and Load Analysis ─────────────────────────────────────────

// Returns 1 if pointer escapes to an external call or is loaded from
fn dse_is_alloca_loaded_or_escaped fn_obj alloca_val
    if fn_obj == 0 or alloca_val == 0 return 1

    bi = 0
    while bi < len(fn_obj.blocks)
        bb = get(fn_obj.blocks, bi)
        ii = 0
        while ii < len(bb.instructions)
            inst = get(bb.instructions, ii)

            // If loaded from, it is read
            if inst.op == OP_LOAD
                if len(inst.operands) > 0 and get(inst.operands, 0) == alloca_val
                    return 1

            // If passed as an argument to a call, pointer escapes
            if inst.op == OP_CALL
                oi = 0
                while oi < len(inst.operands)
                    if get(inst.operands, oi) == alloca_val
                        return 1
                    oi = oi + 1

            // If stored into another pointer, it escapes
            if inst.op == OP_STORE
                if len(inst.operands) >= 2 and get(inst.operands, 0) == alloca_val
                    return 1

            ii = ii + 1
        bi = bi + 1

    return 0

// ── 2. Main DSE Pass ──────────────────────────────────────────────────────────

fn pass_dse_run fn_obj
    if fn_obj == 0 return 0
    eliminated_stores = 0

    // ── Phase 1: Eliminate Stores to Unread Local Allocas ─────────────────────
    // WHY: If a variable is assigned locally but never read before return, all writes to it are dead.
    ai = 0
    while ai < len(fn_obj.allocas)
        alloca_inst = get(fn_obj.allocas, ai)
        ptr_val = alloca_inst.result
        if ptr_val != 0
            if dse_is_alloca_loaded_or_escaped(fn_obj, ptr_val) == 0
                // Pointer is never read and never escapes: eliminate all stores to it!
                bi = 0
                while bi < len(fn_obj.blocks)
                    bb = get(fn_obj.blocks, bi)
                    new_insts = list()
                    ii = 0
                    while ii < len(bb.instructions)
                        inst = get(bb.instructions, ii)
                        if inst.op == OP_STORE and len(inst.operands) >= 2 and get(inst.operands, 1) == ptr_val
                            // Eliminate dead store
                            ssa_instr_remove_from_operands_use_lists(inst)
                            inst.is_dead = 1
                            eliminated_stores = eliminated_stores + 1
                        else
                            push(new_insts, inst)
                        ii = ii + 1
                    bb.instructions = new_insts
                    bi = bi + 1
        ai = ai + 1

    // ── Phase 2: Eliminate Overwritten Stores Within Basic Blocks ─────────────
    // WHY: Within a straight-line basic block, if store(ptr, v1) is followed by store(ptr, v2)
    //      with no intervening load(ptr) or call, store(ptr, v1) is provably dead.
    bi = 0
    while bi < len(fn_obj.blocks)
        bb = get(fn_obj.blocks, bi)
        new_insts = list()

        active_stores_ptrs = list()
        active_stores_insts = list()

        ii = 0
        while ii < len(bb.instructions)
            inst = get(bb.instructions, ii)

            if inst.op == OP_STORE and len(inst.operands) >= 2
                ptr = get(inst.operands, 1)

                // Check if this pointer already has an active pending store
                found_idx = 0 - 1
                si = 0
                while si < len(active_stores_ptrs)
                    if get(active_stores_ptrs, si) == ptr
                        found_idx = si
                    si = si + 1

                if found_idx >= 0
                    // Overwritten dead store found!
                    dead_prev = get(active_stores_insts, found_idx)
                    ssa_instr_remove_from_operands_use_lists(dead_prev)
                    dead_prev.is_dead = 1
                    eliminated_stores = eliminated_stores + 1

                    // Update tracking with latest store
                    list_set(active_stores_insts, found_idx, inst)
                else
                    push(active_stores_ptrs, ptr)
                    push(active_stores_insts, inst)

                push(new_insts, inst)

            elif inst.op == OP_LOAD and len(inst.operands) >= 1
                // Intervening load: clear tracked store for this pointer
                loaded_ptr = get(inst.operands, 0)
                new_ptrs = list()
                new_inst_list = list()
                si = 0
                while si < len(active_stores_ptrs)
                    if get(active_stores_ptrs, si) != loaded_ptr
                        push(new_ptrs, get(active_stores_ptrs, si))
                        push(new_inst_list, get(active_stores_insts, si))
                    si = si + 1
                active_stores_ptrs = new_ptrs
                active_stores_insts = new_inst_list
                push(new_insts, inst)

            elif inst.op == OP_CALL
                // Call might read any pointer: clear all tracked pending stores
                active_stores_ptrs = list()
                active_stores_insts = list()
                push(new_insts, inst)

            else
                push(new_insts, inst)

            ii = ii + 1

        // Filter out instructions marked as dead
        cleaned_insts = list()
        ci = 0
        while ci < len(new_insts)
            item = get(new_insts, ci)
            if item.is_dead == 0
                push(cleaned_insts, item)
            ci = ci + 1
        bb.instructions = cleaned_insts

        bi = bi + 1

    return eliminated_stores
