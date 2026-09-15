// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMMON SUBEXPRESSION ELIMINATION (CSE) (src/compiler/middleend/opt/passes/pass_cse.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Common Subexpression Elimination (CSE) identifies redundant computations
//      that evaluate the same value as an earlier instruction.
//      By leveraging the Dominator Tree:
//      1. Value Equivalence: Two pure instructions are equivalent if they share the
//         same opcode, operands (accounting for commutativity), and comparison predicate.
//      2. Dominance Legality: An earlier instruction can legally replace a later instruction
//         if and only if the earlier instruction's basic block dominates the later
//         instruction's basic block.
//      3. Zero Redundant Cycles: Eliminating identical expressions reduces CPU register
//         pressure and saves execution cycles in inner computational loops.
// ==============================================================================

include "src/compiler/middleend/opt/analysis/dominator_tree.lp"

// ── 1. Pure Expression Equivalence Checker ─────────────────────────────────────
// Returns 1 if inst1 and inst2 compute mathematically identical values

fn cse_are_instructions_equivalent inst1 inst2
    if inst1 == 0 or inst2 == 0 or inst1 == inst2 return 0
    if inst1.op != inst2.op return 0

    op = inst1.op

    // Only pure arithmetic, bitwise, negation, and comparisons can be CSE'd
    if ssa_is_binary_arithmetic(op) == 0 and ssa_is_bitwise(op) == 0 and op != OP_CMP and op != OP_NEG
        return 0

    if op == OP_NEG
        if len(inst1.operands) != 1 or len(inst2.operands) != 1 return 0
        return get(inst1.operands, 0) == get(inst2.operands, 0)

    if len(inst1.operands) != 2 or len(inst2.operands) != 2 return 0

    l1 = get(inst1.operands, 0)
    r1 = get(inst1.operands, 1)
    l2 = get(inst2.operands, 0)
    r2 = get(inst2.operands, 1)

    // For OP_CMP, predicates must match
    if op == OP_CMP
        if inst1.extra_int != inst2.extra_int return 0
        // CMP_EQ and CMP_NE are commutative
        if inst1.extra_int == CMP_EQ or inst1.extra_int == CMP_NE
            if (l1 == l2 and r1 == r2) or (l1 == r2 and r1 == l2) return 1
            return 0
        // Other comparisons are non-commutative
        return l1 == l2 and r1 == r2

    // Commutative arithmetic and bitwise
    if ssa_is_commutative(op) == 1
        if (l1 == l2 and r1 == r2) or (l1 == r2 and r1 == l2) return 1
        return 0

    // Non-commutative (SUB, DIV, MOD, SHL, SHR)
    return l1 == l2 and r1 == r2

// ── 2. Dominance Check Between Instruction Locations ───────────────────────────
// Returns 1 if earlier_inst dominates later_inst

fn cse_instruction_dominates dt earlier_inst later_inst
    if earlier_inst == 0 or later_inst == 0 return 0
    bb1 = earlier_inst.parent_bb
    bb2 = later_inst.parent_bb
    if bb1 == 0 or bb2 == 0 return 0

    // If in the same basic block, check linear instruction ordering
    if bb1 == bb2
        i = 0
        saw_earlier = 0
        while i < len(bb1.instructions)
            item = get(bb1.instructions, i)
            if item == earlier_inst
                saw_earlier = 1
            if item == later_inst
                return saw_earlier
            i = i + 1
        return 0

    // Different basic blocks: query Dominator Tree
    return dom_tree_dominates(dt, bb1.label, bb2.label)

// ── 3. Main CSE Pass ──────────────────────────────────────────────────────────

fn pass_cse_run fn_obj
    if fn_obj == 0 return 0

    dt = dom_tree_compute(fn_obj)
    rpo_list = cfg_compute_rpo(fn_obj)

    available_insts = list()
    cse_count = 0

    // Traverse in Reverse Post-Order so definitions are processed before uses
    bi = 0
    while bi < len(rpo_list)
        bb = get(rpo_list, bi)
        new_insts = list()
        ii = 0
        while ii < len(bb.instructions)
            inst = get(bb.instructions, ii)
            eliminated = 0

            // Check against all previously seen available expressions
            if inst.result != 0 and ssa_has_side_effects(inst.op) == 0
                ai = 0
                while ai < len(available_insts)
                    avail = get(available_insts, ai)
                    if cse_are_instructions_equivalent(avail, inst) == 1
                        // Verify avail strictly dominates inst
                        if cse_instruction_dominates(dt, avail, inst) == 1
                            // Replace all uses of inst.result with avail.result!
                            ssa_value_replace_all_uses_with(inst.result, avail.result)
                            ssa_instr_remove_from_operands_use_lists(inst)
                            inst.is_dead = 1
                            eliminated = 1
                            cse_count = cse_count + 1
                            ai = len(available_insts) // break
                    ai = ai + 1

            if eliminated == 0
                push(new_insts, inst)
                if inst.result != 0 and ssa_has_side_effects(inst.op) == 0
                    push(available_insts, inst)

            ii = ii + 1

        bb.instructions = new_insts
        bi = bi + 1

    return cse_count
