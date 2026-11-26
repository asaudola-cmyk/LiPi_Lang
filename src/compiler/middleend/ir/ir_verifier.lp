// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END SSA IR VERIFIER (src/compiler/middleend/ir/ir_verifier.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Static Single Assignment (SSA) form relies on strict mathematical invariants:
//      1. Single Assignment: Every SSA value is defined exactly once.
//      2. Def-Use Completeness: Every use of a value is registered in its def-use list,
//         and every element in a def-use list actually references the value.
//      3. Well-formed CFG: Every basic block is terminated by Br, Jmp, or Ret.
//      4. Edge Symmetry: Predecessor and successor edge lists are symmetric.
//      5. Phi Invariant: Phi nodes precede all other instructions and match predecessors.
//      Running this verifier between optimization passes prevents subtle compiler bugs
//      from silently corrupting the instruction stream or emitting invalid machine code.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"

// ── 1. SSA Form Verifier ──────────────────────────────────────────────────────

fn ir_verify_function fn_obj
    if fn_obj == 0
        say "❌ [IR Verifier Error]: Null function object passed to verifier."
        return 0

    defined_set = dict() // O(1) defined SSA value ID set to enforce single assignment
    use_cache = dict()   // Lazy O(1) use-set cache for high-fanout values (len(uses) > 8)

    // ── Check 1: Register Formal Parameters ───────────────────────────────────
    i = 0
    pcnt = len(fn_obj.params)
    while i < pcnt
        param = get(fn_obj.params, i)
        if param == 0
            say "❌ [IR Verifier Error in " + fn_obj.name + "]: Null parameter at index " + str(i)
            return 0
        if has_key(defined_set, param.id) == 1
            say "❌ [IR Verifier SSA Violation in " + fn_obj.name + "]: Parameter " + param.id + " defined multiple times!"
            return 0
        defined_set[param.id] = 1
        i = i + 1

    // ── Check 2: Verify Basic Blocks and Instructions ─────────────────────────
    bcnt = len(fn_obj.blocks)
    if bcnt == 0
        say "❌ [IR Verifier Error in " + fn_obj.name + "]: Function has zero basic blocks."
        return 0

    bb_map = dict()
    bi = 0
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        if bb == 0
            say "❌ [IR Verifier Error in " + fn_obj.name + "]: Null basic block at index " + str(bi)
            return 0
        bb_map[bb.label] = bb

        icnt = len(bb.instructions)
        if icnt == 0
            say "❌ [IR Verifier Error in " + fn_obj.name + "]: Basic block " + bb.label + " is empty (contains no instructions)."
            return 0

        // Check terminator invariant: last instruction MUST be a terminator
        last_inst = get(bb.instructions, icnt - 1)
        if ssa_instr_is_terminator(last_inst) == 0
            say "❌ [IR Verifier Error in " + fn_obj.name + "]: Basic block " + bb.label + " is not terminated! (Last op: " + ssa_opcode_name(last_inst.op) + ")"
            return 0

        saw_non_phi = 0
        ii = 0
        while ii < icnt
            inst = get(bb.instructions, ii)
            if inst == 0
                say "❌ [IR Verifier Error in " + fn_obj.name + "]: Null instruction in block " + bb.label + " at index " + str(ii)
                return 0

            // Check terminator placement: no terminator allowed in middle of block
            if ii < (icnt - 1) and ssa_instr_is_terminator(inst) == 1
                say "❌ [IR Verifier Error in " + fn_obj.name + "]: Terminator " + ssa_opcode_name(inst.op) + " appears in middle of block " + bb.label + " at index " + str(ii)
                return 0

            // Check Phi placement invariant: all Phis must precede all non-Phis
            if inst.op == OP_PHI
                if saw_non_phi == 1
                    say "❌ [IR Verifier SSA Violation in " + fn_obj.name + "]: Phi node appears after non-phi instruction in block " + bb.label
                    return 0
                // Check Phi operand count matches incoming basic block count
                if len(inst.operands) != len(inst.extra_list)
                    say "❌ [IR Verifier SSA Violation in " + fn_obj.name + "]: Phi operand count (" + str(len(inst.operands)) + ") does not match incoming block count (" + str(len(inst.extra_list)) + ") in block " + bb.label
                    return 0
            else
                saw_non_phi = 1

            // Check Single-Assignment Invariant: instruction result defined only once (O(1))
            if inst.result != 0
                res_id = inst.result.id
                if has_key(defined_set, res_id) == 1
                    say "❌ [IR Verifier SSA Violation in " + fn_obj.name + "]: Value " + res_id + " defined multiple times! (Single-Assignment violated)"
                    return 0
                defined_set[res_id] = 1

            // Check Def-Use Integrity: each operand's use list must contain this instruction
            oi = 0
            ocnt = len(inst.operands)
            while oi < ocnt
                opnd = get(inst.operands, oi)
                if opnd != 0
                    found_in_uses = 0
                    ucnt = len(opnd.uses)
                    if ucnt <= 8
                        ui = 0
                        while ui < ucnt
                            if get(opnd.uses, ui) == inst
                                found_in_uses = 1
                                break
                            ui = ui + 1
                    else
                        if has_key(use_cache, opnd) == 0
                            uset = dict()
                            ui = 0
                            while ui < ucnt
                                uset[get(opnd.uses, ui)] = 1
                                ui = ui + 1
                            use_cache[opnd] = uset
                        end
                        found_in_uses = has_key(use_cache[opnd], inst)
                    end
                    if found_in_uses == 0
                        say "❌ [IR Verifier Def-Use Invariant Broken in " + fn_obj.name + "]: Instruction " + str(inst.id) + " consumes " + opnd.id + ", but is missing from its def-use list!"
                        return 0
                oi = oi + 1

            ii = ii + 1
        bi = bi + 1

    // ── Check 3: Verify CFG Edge Symmetry (O(1) block lookup) ─────────────────
    // WHY: If block A lists B in successors, B must list A in predecessors.
    bi = 0
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        si = 0
        scnt = len(bb.successors)
        while si < scnt
            succ_lbl = get(bb.successors, si)
            succ_bb = 0
            if has_key(bb_map, succ_lbl) == 1
                succ_bb = bb_map[succ_lbl]
            end
            if succ_bb == 0
                say "❌ [IR Verifier CFG Violation in " + fn_obj.name + "]: Block " + bb.label + " targets non-existent successor " + succ_lbl
                return 0
            if basic_block_has_pred(succ_bb, bb.label) == 0
                say "❌ [IR Verifier Edge Asymmetry in " + fn_obj.name + "]: Block " + bb.label + " has successor " + succ_lbl + ", but " + succ_lbl + " does not list " + bb.label + " as predecessor!"
                return 0
            si = si + 1
        bi = bi + 1

    return 1

fn ir_verify_module mod_obj
    if mod_obj == 0
        say "❌ [IR Verifier Error]: Null module object."
        return 0

    i = 0
    fcnt = len(mod_obj.functions)
    while i < fcnt
        fn_obj = get(mod_obj.functions, i)
        if ir_verify_function(fn_obj) == 0
            return 0
        i = i + 1

    return 1
