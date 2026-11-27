// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SSA CONSTANT FOLDING PASS (src/compiler/middleend/opt/passes/pass_const_fold.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Constant Folding computes operations on compile-time known constants ahead of
//      time at compilation instead of emitting runtime machine instructions.
//      1. Arithmetic & Bitwise Reduction: Pre-computes additions, subtractions, multiplications,
//         and shifts directly into immediate scalar values.
//      2. Comparison Resolution: Resolves relational predicates on constant operands to
//         boolean 1 (true) or 0 (false).
//      3. Branch Simplification: Turns conditional branches (br cond, then, else) with
//         known constant conditions into unconditional jumps (jmp target), enabling Dead
//         Code Elimination to discard entire untaken branch subtrees.
// ==============================================================================

include "src/compiler/middleend/ir/ir_function.lp"

// ── 1. Arithmetic & Bitwise Evaluator ─────────────────────────────────────────

fn const_fold_eval_binary op l r
    if op == OP_ADD return l + r
    if op == OP_SUB return l - r
    if op == OP_MUL return l * r
    if op == OP_DIV
        if r != 0 return l / r
        return 0 // Avoid hardware div-by-zero trap
    if op == OP_MOD
        if r != 0 return l % r
        return 0
    if op == OP_AND return l & r
    if op == OP_OR  return l | r
    if op == OP_XOR return l ^ r
    if op == OP_SHL
        // WHY: Match 64-bit hardware shift semantics across x86_64/ARM64/RV64/WASM (count & 63)
        // so -O1/-O2/-O3 constant folding never diverges from -O0 runtime execution.
        shift = r & 63
        return l << shift
    if op == OP_SHR
        // WHY: Match 64-bit hardware arithmetic right-shift semantics (count & 63, exact on INT64_MIN)
        // so -O1/-O2/-O3 constant folding matches -O0 runtime execution identically.
        shift = r & 63
        return l >> shift
    return 0

fn const_fold_eval_cmp pred l r
    if pred == CMP_EQ
        if l == r return 1
        return 0
    if pred == CMP_NE
        if l != r return 1
        return 0
    if pred == CMP_SLT
        if l < r return 1
        return 0
    if pred == CMP_SLE
        if l <= r return 1
        return 0
    if pred == CMP_SGT
        if l > r return 1
        return 0
    if pred == CMP_SGE
        if l >= r return 1
        return 0
    return 0

// ── 2. Dead Branch Phi Maintenance ───────────────────────────────────────────
// WHY: When a conditional branch br cond, L_true, L_false is simplified to jmp L_true,
//      the CFG edge (bb -> L_false) is deleted. Any Phi node in L_false expecting
//      an incoming value from bb must have that incoming value pruned to preserve SSA form.

fn const_fold_prune_phi_incoming target_bb source_lbl
    if target_bb == 0 return 0
    ii = 0
    while ii < len(target_bb.instructions)
        inst = get(target_bb.instructions, ii)
        if inst.op == OP_PHI
            new_operands = list()
            new_bbs = list()
            pi = 0
            while pi < len(inst.extra_list)
                lbl = get(inst.extra_list, pi)
                opnd = get(inst.operands, pi)
                if lbl != source_lbl
                    push(new_operands, opnd)
                    push(new_bbs, lbl)
                else
                    // Remove use of pruned operand
                    ssa_value_remove_use(opnd, inst)
                pi = pi + 1
            inst.operands = new_operands
            inst.extra_list = new_bbs
        ii = ii + 1
    return 1

// ── 3. Main Constant Folding Pass ─────────────────────────────────────────────

fn pass_const_fold_run fn_obj
    if fn_obj == 0 return 0
    folds_count = 0

    bi = 0
    bcnt = len(fn_obj.blocks)
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        insts = bb.instructions
        icnt = len(insts)
        blk_folded = 0
        ii = 0
        while ii < icnt
            inst = get(insts, ii)
            folded = 0

            // Case A: Binary arithmetic / bitwise with 2 constant operands
            if (ssa_is_binary_arithmetic(inst.op) == 1 or ssa_is_bitwise(inst.op) == 1) and len(inst.operands) == 2
                op0 = get(inst.operands, 0)
                op1 = get(inst.operands, 1)
                if op0.kind == VAL_KIND_CONST and op1.kind == VAL_KIND_CONST
                    // Check division / modulo by zero
                    if not ((inst.op == OP_DIV or inst.op == OP_MOD) and op1.const_val == 0)
                        c_res = const_fold_eval_binary(inst.op, op0.const_val, op1.const_val)
                        const_val = ssa_value_new_const(c_res, inst.result.vtype)
                        ssa_value_replace_all_uses_with(inst.result, const_val)
                        ssa_instr_remove_from_operands_use_lists(inst)
                        inst.is_dead = 1
                        folded = 1
                        blk_folded = 1
                        folds_count = folds_count + 1
                    end

            // Case B: Unary negation on constant operand
            if folded == 0 and inst.op == OP_NEG and len(inst.operands) == 1
                op0 = get(inst.operands, 0)
                if op0.kind == VAL_KIND_CONST
                    c_res = 0 - op0.const_val
                    const_val = ssa_value_new_const(c_res, inst.result.vtype)
                    ssa_value_replace_all_uses_with(inst.result, const_val)
                    ssa_instr_remove_from_operands_use_lists(inst)
                    inst.is_dead = 1
                    folded = 1
                    blk_folded = 1
                    folds_count = folds_count + 1

            // Case C: Relational comparison on two constant operands
            if folded == 0 and inst.op == OP_CMP and len(inst.operands) == 2
                op0 = get(inst.operands, 0)
                op1 = get(inst.operands, 1)
                if op0.kind == VAL_KIND_CONST and op1.kind == VAL_KIND_CONST
                    c_res = const_fold_eval_cmp(inst.extra_int, op0.const_val, op1.const_val)
                    const_val = ssa_value_new_const(c_res, inst.result.vtype)
                    ssa_value_replace_all_uses_with(inst.result, const_val)
                    ssa_instr_remove_from_operands_use_lists(inst)
                    inst.is_dead = 1
                    folded = 1
                    blk_folded = 1
                    folds_count = folds_count + 1

            // Case D: Conditional branch with constant condition
            if folded == 0 and inst.op == OP_BR and len(inst.operands) == 1
                cond_val = get(inst.operands, 0)
                if cond_val.kind == VAL_KIND_CONST and len(inst.extra_list) >= 2
                    true_lbl = get(inst.extra_list, 0)
                    false_lbl = get(inst.extra_list, 1)

                    if cond_val.const_val != 0
                        inst.op = OP_JMP
                        inst.extra_str = true_lbl
                        inst.operands = list()
                        inst.extra_list = ssa_instr_empty_list()
                        ssa_value_remove_use(cond_val, inst)

                        false_bb = ir_function_find_block(fn_obj, false_lbl)
                        const_fold_prune_phi_incoming(false_bb, bb.label)
                    else
                        inst.op = OP_JMP
                        inst.extra_str = false_lbl
                        inst.operands = list()
                        inst.extra_list = ssa_instr_empty_list()
                        ssa_value_remove_use(cond_val, inst)

                        true_bb = ir_function_find_block(fn_obj, true_lbl)
                        const_fold_prune_phi_incoming(true_bb, bb.label)

                    folded = 1
                    folds_count = folds_count + 1

            ii = ii + 1
        end

        if blk_folded == 1
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

    return folds_count
