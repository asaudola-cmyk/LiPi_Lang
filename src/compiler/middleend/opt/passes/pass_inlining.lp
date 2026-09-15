// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FUNCTION INLINING PASS (src/compiler/middleend/opt/passes/pass_inlining.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Function inlining eliminates procedural call overhead (argument passing,
//      stack frame allocation, branch predictor thrashing, and return sequencing)
//      for small leaf functions.
//      More importantly, inlining dissolves abstraction boundaries, bringing the
//      callee's instructions into the caller's context where local passes (such as
//      Constant Folding, CSE, and DCE) can optimize across former call boundaries.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"
include "src/compiler/middleend/opt/analysis/cfg.lp"

// ── 1. Value Mapping Dictionary ───────────────────────────────────────────────

struct InlineMap
    keys
    vals

fn inline_map_new
    im = InlineMap()
    im.keys = list()
    im.vals = list()
    return im

fn inline_map_get im old_val
    if im == 0 or old_val == 0 return old_val
    i = 0
    cnt = len(im.keys)
    while i < cnt
        if get(im.keys, i) == old_val
            return get(im.vals, i)
        i = i + 1
    return old_val

fn inline_map_set im old_val new_val
    if im == 0 or old_val == 0 return 0
    i = 0
    cnt = len(im.keys)
    while i < cnt
        if get(im.keys, i) == old_val
            list_set(im.vals, i, new_val)
            return 1
        i = i + 1
    push(im.keys, old_val)
    push(im.vals, new_val)
    return 1

// ── 2. Inlining Candidate Filter ──────────────────────────────────────────────
// WHY: Inlining excessively large or recursive functions causes code bloat and
//      cache thrashing. Limiting inlining to small functions (<= 25 instructions)
//      yields optimal instruction cache efficiency.

fn inlining_is_candidate callee_fn caller_fn threshold
    if callee_fn == 0 return 0
    if callee_fn == caller_fn return 0 // Guard against direct recursion
    inst_count = ir_function_count_insts(callee_fn)
    if inst_count == 0 or inst_count > threshold return 0
    return 1

// ── 3. Single Call-Site Inliner ────────────────────────────────────────────────

fn inline_call_site caller_fn callee_fn caller_bb call_inst call_idx inline_id
    imap = inline_map_new()

    // Step 1: Map callee formal parameters to actual argument values at call site
    pi = 0
    pcnt = len(callee_fn.params)
    while pi < pcnt
        param = get(callee_fn.params, pi)
        arg = ssa_instr_get_operand(call_inst, pi)
        if arg != 0
            inline_map_set(imap, param, arg)
        pi = pi + 1

    // Step 2: Split caller basic block into before and after continuation blocks
    after_bb = ir_function_create_block(caller_fn, "inline_cont")

    // Move instructions after call_inst to after_bb
    new_caller_insts = list()
    i = 0
    while i < call_idx
        push(new_caller_insts, get(caller_bb.instructions, i))
        i = i + 1

    j = call_idx + 1
    while j < len(caller_bb.instructions)
        succ_inst = get(caller_bb.instructions, j)
        succ_inst.parent_bb = after_bb
        push(after_bb.instructions, succ_inst)
        j = j + 1

    caller_bb.instructions = new_caller_insts

    // Step 3: Clone callee basic blocks into caller function with unique label prefixes
    cloned_blocks = list()
    cloned_labels = list()

    bi = 0
    while bi < len(callee_fn.blocks)
        c_bb = get(callee_fn.blocks, bi)
        cloned_lbl = "inlined_" + str(inline_id) + "_" + c_bb.label
        fresh_bb = basic_block_new(cloned_lbl, caller_fn)
        ir_function_add_block(caller_fn, fresh_bb)
        push(cloned_blocks, fresh_bb)
        push(cloned_labels, cloned_lbl)
        bi = bi + 1

    cloned_entry = get(cloned_blocks, 0)

    // Step 4: Clone instructions from callee into cloned blocks
    ret_val = 0

    bi = 0
    while bi < len(callee_fn.blocks)
        orig_bb = get(callee_fn.blocks, bi)
        target_bb = get(cloned_blocks, bi)

        ii = 0
        while ii < len(orig_bb.instructions)
            orig_inst = get(orig_bb.instructions, ii)

            if orig_inst.op == OP_RET
                // Return instruction: capture return value and branch to after_bb
                if len(orig_inst.operands) > 0
                    r_opnd = get(orig_inst.operands, 0)
                    ret_val = inline_map_get(imap, r_opnd)
                // Replace ret with jmp to after_bb
                jmp_cont = ir_build_jmp(1, after_bb.label)
                basic_block_append_inst(target_bb, jmp_cont)
            else
                // Clone general instruction
                cloned_res = 0
                if orig_inst.result != 0
                    cloned_res = caller_fn.new_val(orig_inst.result.vtype)
                    inline_map_set(imap, orig_inst.result, cloned_res)

                c_inst = ssa_instr_new(1, orig_inst.op, cloned_res, target_bb)
                c_inst.extra_int = orig_inst.extra_int
                c_inst.extra_str = orig_inst.extra_str

                // Rewrite branch target labels to match cloned block names
                if orig_inst.op == OP_JMP
                    ti = 0
                    while ti < len(callee_fn.blocks)
                        if get(callee_fn.blocks, ti).label == orig_inst.extra_str
                            c_inst.extra_str = get(cloned_labels, ti)
                        ti = ti + 1

                if orig_inst.op == OP_BR
                    ci = 0
                    while ci < len(orig_inst.extra_list)
                        tgt = get(orig_inst.extra_list, ci)
                        ti = 0
                        while ti < len(callee_fn.blocks)
                            if get(callee_fn.blocks, ti).label == tgt
                                push(c_inst.extra_list, get(cloned_labels, ti))
                            ti = ti + 1
                        ci = ci + 1

                // Map operands
                oi = 0
                while oi < len(orig_inst.operands)
                    opnd = get(orig_inst.operands, oi)
                    mapped = inline_map_get(imap, opnd)
                    push(c_inst.operands, mapped)
                    ssa_value_add_use(mapped, c_inst)
                    oi = oi + 1

                push(target_bb.instructions, c_inst)

            ii = ii + 1
        bi = bi + 1

    // Step 5: Connect caller_bb to cloned_entry
    jmp_entry = ir_build_jmp(1, cloned_entry.label)
    basic_block_append_inst(caller_bb, jmp_entry)

    // Step 6: Replace call result value with inlined return value
    if call_inst.result != 0 and ret_val != 0
        ssa_value_replace_all_uses_with(call_inst.result, ret_val)

    // Remove call instruction use bindings
    ssa_instr_remove_from_operands_use_lists(call_inst)
    call_inst.is_dead = 1

    return 1

// ── 4. Main Inlining Pass ─────────────────────────────────────────────────────

fn pass_inlining_run mod_obj
    if mod_obj == 0 return 0
    inlined_count = 0
    inline_id = 1
    threshold = 25

    fi = 0
    while fi < len(mod_obj.functions)
        caller_fn = get(mod_obj.functions, fi)

        // Scan caller blocks for OP_CALL
        bi = 0
        while bi < len(caller_fn.blocks)
            bb = get(caller_fn.blocks, bi)
            ii = 0
            while ii < len(bb.instructions)
                inst = get(bb.instructions, ii)
                if inst.op == OP_CALL
                    callee_name = inst.extra_str
                    callee_fn = ir_module_find_function(mod_obj, callee_name)
                    if callee_fn != 0 and inlining_is_candidate(callee_fn, caller_fn, threshold) == 1
                        inline_call_site(caller_fn, callee_fn, bb, inst, ii, inline_id)
                        inline_id = inline_id + 1
                        inlined_count = inlined_count + 1
                        cfg_rebuild_edges(caller_fn)
                        ii = len(bb.instructions) // block was split, advance to next block
                ii = ii + 1
            bi = bi + 1

        fi = fi + 1

    return inlined_count
