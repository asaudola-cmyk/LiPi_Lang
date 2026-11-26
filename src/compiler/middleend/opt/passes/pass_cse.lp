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

// ── 3. Main CSE Pass (O(N) Hash-Bucketed Value Numbering) ────────────────────

fn cse_expr_hash inst
    // WHY: Zero-allocation 64-bit integer hash for pure SSA expressions (commutative-canonicalized).
    op = inst.op
    if ssa_is_binary_arithmetic(op) == 0 and ssa_is_bitwise(op) == 0 and op != OP_CMP and op != OP_NEG
        return 0
    end
    if op == OP_NEG
        if len(inst.operands) != 1 return 0 end
        o0 = get(inst.operands, 0)
        return ((op * 1000003) ^ (o0 * 2654435761)) | 1
    end
    if len(inst.operands) != 2 return 0 end
    l = get(inst.operands, 0)
    r = get(inst.operands, 1)
    is_comm = 0
    if op == OP_CMP
        if inst.extra_int == CMP_EQ or inst.extra_int == CMP_NE
            is_comm = 1
        end
    elif ssa_is_commutative(op) == 1
        is_comm = 1
    end
    if is_comm == 1 and l > r
        tmp = l
        l = r
        r = tmp
    end
    h = (op * 1315423911) ^ (inst.extra_int * 2654435761)
    h = (h * 31) ^ (l * 11400714819323198485)
    h = (h * 31) ^ (r * 14029467366897019727)
    return h | 1

fn pass_cse_run fn_obj
    if fn_obj == 0 return 0
    bcnt = len(fn_obj.blocks)
    if bcnt == 0 return 0 end

    dt = 0
    rpo_list = fn_obj.blocks
    if bcnt > 1
        dt = dom_tree_compute(fn_obj)
        rpo_list = cfg_compute_rpo(fn_obj)
    end

    // O(1) hash-bucketed map: expr_hash -> list of available SSAInstr candidates
    avail_map = dict()
    cse_count = 0

    // Traverse in Reverse Post-Order so definitions are processed before uses
    bi = 0
    rcnt = len(rpo_list)
    while bi < rcnt
        bb = get(rpo_list, bi)
        insts = bb.instructions
        icnt = len(insts)
        blk_changed = 0
        ii = 0
        while ii < icnt
            inst = get(insts, ii)
            eliminated = 0

            if inst.result != 0 and ssa_has_side_effects(inst.op) == 0
                eh = cse_expr_hash(inst)
                if eh != 0
                    if has_key(avail_map, eh) == 1
                        bucket = avail_map[eh]
                        ai = 0
                        blen = len(bucket)
                        while ai < blen
                            avail = get(bucket, ai)
                            if cse_are_instructions_equivalent(avail, inst) == 1
                                // Since RPO + in-block forward order guarantees earlier placement in same block:
                                dom_ok = 0
                                if avail.parent_bb == bb
                                    dom_ok = 1
                                elif dt != 0 and avail.parent_bb != 0
                                    dom_ok = dom_tree_dominates(dt, avail.parent_bb.label, bb.label)
                                end
                                if dom_ok == 1
                                    ssa_value_replace_all_uses_with(inst.result, avail.result)
                                    ssa_instr_remove_from_operands_use_lists(inst)
                                    inst.is_dead = 1
                                    eliminated = 1
                                    blk_changed = 1
                                    cse_count = cse_count + 1
                                    break
                                end
                            end
                            ai = ai + 1
                        end
                        if eliminated == 0
                            push(bucket, inst)
                        end
                    else
                        avail_map[eh] = [inst]
                    end
                end
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

    return cse_count
