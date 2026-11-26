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
    bcnt = len(fn_obj.blocks)

    // ── Phase 1: Eliminate Stores to Unread Local Allocas in O(N + A) ─────────
    // WHY: Single pass collects every loaded/escaped pointer into a DICT0 set,
    // replacing O(A * N) per-alloca whole-function rescans with O(N) linear scan.
    acnt = len(fn_obj.allocas)
    if acnt > 0
        live_ptrs = dict()
        bi = 0
        while bi < bcnt
            bb = get(fn_obj.blocks, bi)
            insts = bb.instructions
            icnt = len(insts)
            ii = 0
            while ii < icnt
                inst = get(insts, ii)
                iop = inst.op
                if iop == OP_LOAD
                    if len(inst.operands) > 0
                        live_ptrs[get(inst.operands, 0)] = 1
                    end
                elif iop == OP_CALL
                    oi = 0
                    ocnt = len(inst.operands)
                    while oi < ocnt
                        live_ptrs[get(inst.operands, oi)] = 1
                        oi = oi + 1
                    end
                elif iop == OP_STORE
                    if len(inst.operands) >= 2
                        live_ptrs[get(inst.operands, 0)] = 1
                    end
                end
                ii = ii + 1
            end
            bi = bi + 1
        end

        dead_allocas = dict()
        dead_cnt = 0
        ai = 0
        while ai < acnt
            alloca_inst = get(fn_obj.allocas, ai)
            ptr_val = alloca_inst.result
            if ptr_val != 0 and has_key(live_ptrs, ptr_val) == 0
                dead_allocas[ptr_val] = 1
                dead_cnt = dead_cnt + 1
            end
            ai = ai + 1
        end

        if dead_cnt > 0
            bi = 0
            while bi < bcnt
                bb = get(fn_obj.blocks, bi)
                insts = bb.instructions
                icnt = len(insts)
                blk_changed = 0
                ii = 0
                while ii < icnt
                    inst = get(insts, ii)
                    if inst.op == OP_STORE and len(inst.operands) >= 2 and has_key(dead_allocas, get(inst.operands, 1)) == 1
                        ssa_instr_remove_from_operands_use_lists(inst)
                        inst.is_dead = 1
                        eliminated_stores = eliminated_stores + 1
                        blk_changed = 1
                    end
                    ii = ii + 1
                end
                if blk_changed == 1
                    new_insts = list()
                    ii = 0
                    while ii < icnt
                        it = get(insts, ii)
                        if it.is_dead == 0
                            push(new_insts, it)
                        end
                        ii = ii + 1
                    end
                    bb.instructions = new_insts
                end
                bi = bi + 1
            end
        end
    end

    // ── Phase 2: Eliminate Overwritten Stores Within Basic Blocks in O(N) ─────
    // WHY: Uses O(1) DICT0 map ptr -> pending_store_inst (0 per-load list reallocations).
    bi = 0
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        insts = bb.instructions
        icnt = len(insts)
        active_stores = dict()
        active_cnt = 0
        blk_killed = 0

        ii = 0
        while ii < icnt
            inst = get(insts, ii)
            iop = inst.op

            if iop == OP_STORE and len(inst.operands) >= 2
                ptr = get(inst.operands, 1)
                if has_key(active_stores, ptr) == 1
                    dead_prev = active_stores[ptr]
                    if dead_prev != 0
                        ssa_instr_remove_from_operands_use_lists(dead_prev)
                        dead_prev.is_dead = 1
                        eliminated_stores = eliminated_stores + 1
                        blk_killed = 1
                    end
                else
                    active_cnt = active_cnt + 1
                end
                active_stores[ptr] = inst

            elif iop == OP_LOAD and len(inst.operands) >= 1
                if active_cnt > 0
                    loaded_ptr = get(inst.operands, 0)
                    if has_key(active_stores, loaded_ptr) == 1
                        del_key(active_stores, loaded_ptr)
                        active_cnt = active_cnt - 1
                    end
                end

            elif iop == OP_CALL
                if active_cnt > 0
                    active_stores = dict()
                    active_cnt = 0
                end
            end

            ii = ii + 1
        end

        if blk_killed == 1
            cleaned_insts = list()
            ci = 0
            while ci < icnt
                item = get(insts, ci)
                if item.is_dead == 0
                    push(cleaned_insts, item)
                end
                ci = ci + 1
            end
            bb.instructions = cleaned_insts
        end

        bi = bi + 1
    end

    return eliminated_stores
