// ==============================================================================
// 👑 LIPI FIRST 1.0.0 PEEPHOLE & ALGEBRAIC REWRITING PASS (src/compiler/middleend/opt/passes/pass_peephole.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Peephole optimization examines local instruction patterns within basic blocks
//      to perform algebraic identity simplifications and strength reductions.
//      1. Identity Laws: x + 0 -> x, x - x -> 0, x * 1 -> x, x * 0 -> 0, x / 1 -> x,
//         x & 0 -> 0, x | 0 -> x, x ^ x -> 0.
//      2. Strength Reduction: Multiplications and divisions by powers of two (2^k) are
//         transformed into 1-cycle bitwise shift operations (SHL, SHR).
//      3. Double Negation Inversion: neg(neg(x)) -> x.
//      4. Redundant Phi Collapsing: Phi nodes where all distinct non-self inputs are
//         the identical value x are collapsed directly to x.
// ==============================================================================

include "src/compiler/middleend/ir/ir_function.lp"

// ── 1. Power of Two Math Helpers ──────────────────────────────────────────────

fn peephole_is_power_of_two n
    if n <= 0 return 0
    return (n & (n - 1)) == 0

fn peephole_log2 n
    if n <= 0 return 0
    k = 0
    val = n
    while val > 1
        val = val / 2
        k = k + 1
    return k

// ── 2. Single Instruction Algebraic Simplifier ─────────────────────────────────
// Returns replacement SSAValue if simplified, or 0 if no simplification applied.

fn peephole_simplify_inst inst
    if inst == 0 or inst.result == 0 return 0
    op = inst.op

    // ── Pattern 1: Unary Negation (neg (neg x) -> x) ──────────────────────────
    if op == OP_NEG and len(inst.operands) == 1
        opnd = get(inst.operands, 0)
        def_i = opnd.def_inst
        if def_i != 0 and def_i.op == OP_NEG and len(def_i.operands) == 1
            return get(def_i.operands, 0)

    // ── Pattern 2: Binary Operations ──────────────────────────────────────────
    if len(inst.operands) == 2
        l = get(inst.operands, 0)
        r = get(inst.operands, 1)

        is_l_const = l.kind == VAL_KIND_CONST
        is_r_const = r.kind == VAL_KIND_CONST
        l_val = l.const_val
        r_val = r.const_val

        // Rule: Self-operations (x - x -> 0, x ^ x -> 0)
        if l == r
            if op == OP_SUB return ssa_value_new_const(0, inst.result.vtype)
            if op == OP_XOR return ssa_value_new_const(0, inst.result.vtype)
            if op == OP_AND or op == OP_OR return l

        // Addition: x + 0 -> x, 0 + x -> x
        if op == OP_ADD
            if is_r_const == 1 and r_val == 0 return l
            if is_l_const == 1 and l_val == 0 return r

        // Subtraction: x - 0 -> x
        if op == OP_SUB
            if is_r_const == 1 and r_val == 0 return l

        // Multiplication: x * 1 -> x, x * 0 -> 0, 1 * x -> x, 0 * x -> 0
        if op == OP_MUL
            if is_r_const == 1
                if r_val == 1 return l
                if r_val == 0 return ssa_value_new_const(0, inst.result.vtype)
                // Strength reduction: x * 2^k -> x << k
                if r_val > 1 and peephole_is_power_of_two(r_val) == 1
                    shift_k = peephole_log2(r_val)
                    inst.op = OP_SHL
                    const_k = ssa_value_new_const(shift_k, "i64")
                    ssa_value_remove_use(r, inst)
                    list_set(inst.operands, 1, const_k)
                    ssa_value_add_use(const_k, inst)
                    return 0 // Rewritten in place
            if is_l_const == 1
                if l_val == 1 return r
                if l_val == 0 return ssa_value_new_const(0, inst.result.vtype)
                // Commutative strength reduction: 2^k * x -> x << k
                if l_val > 1 and peephole_is_power_of_two(l_val) == 1
                    shift_k = peephole_log2(l_val)
                    inst.op = OP_SHL
                    const_k = ssa_value_new_const(shift_k, "i64")
                    ssa_value_remove_use(l, inst)
                    list_set(inst.operands, 0, r)
                    list_set(inst.operands, 1, const_k)
                    ssa_value_add_use(const_k, inst)
                    return 0

        // Division: x / 1 -> x, 0 / x -> 0
        if op == OP_DIV
            if is_r_const == 1
                if r_val == 1 return l
                // Strength reduction: x / 2^k -> x >> k
                if r_val > 1 and peephole_is_power_of_two(r_val) == 1
                    shift_k = peephole_log2(r_val)
                    inst.op = OP_SHR
                    const_k = ssa_value_new_const(shift_k, "i64")
                    ssa_value_remove_use(r, inst)
                    list_set(inst.operands, 1, const_k)
                    ssa_value_add_use(const_k, inst)
                    return 0
            if is_l_const == 1 and l_val == 0
                return ssa_value_new_const(0, inst.result.vtype)

        // Bitwise AND: x & 0 -> 0, 0 & x -> 0
        if op == OP_AND
            if is_r_const == 1 and r_val == 0 return ssa_value_new_const(0, inst.result.vtype)
            if is_l_const == 1 and l_val == 0 return ssa_value_new_const(0, inst.result.vtype)

        // Bitwise OR: x | 0 -> x, 0 | x -> x
        if op == OP_OR
            if is_r_const == 1 and r_val == 0 return l
            if is_l_const == 1 and l_val == 0 return r

        // Bitwise XOR: x ^ 0 -> x, 0 ^ x -> x
        if op == OP_XOR
            if is_r_const == 1 and r_val == 0 return l
            if is_l_const == 1 and l_val == 0 return r

        // Shifts by 0: x << 0 -> x, x >> 0 -> x
        if op == OP_SHL or op == OP_SHR
            if is_r_const == 1 and r_val == 0 return l
            if is_l_const == 1 and l_val == 0 return ssa_value_new_const(0, inst.result.vtype)

        // Comparisons on self: cmp pred x, x
        if op == OP_CMP and l == r
            pred = inst.extra_int
            if pred == CMP_EQ or pred == CMP_SLE or pred == CMP_SGE
                return ssa_value_new_const(1, inst.result.vtype)
            if pred == CMP_NE or pred == CMP_SLT or pred == CMP_SGT
                return ssa_value_new_const(0, inst.result.vtype)

    // ── Pattern 3: Phi Node Simplification ────────────────────────────────────
    // WHY: If all non-self incoming values to a Phi node are the same value v,
    //      the confluence is trivial and can be replaced by v directly.
    if op == OP_PHI and len(inst.operands) > 0
        unique_candidate = 0
        is_trivial = 1
        oi = 0
        while oi < len(inst.operands)
            opnd = get(inst.operands, oi)
            if opnd != inst.result
                if unique_candidate == 0
                    unique_candidate = opnd
                elif opnd != unique_candidate
                    is_trivial = 0
            oi = oi + 1

        if is_trivial == 1 and unique_candidate != 0
            return unique_candidate

    return 0

// ── 3. Main Peephole Pass ─────────────────────────────────────────────────────

fn pass_peephole_run fn_obj
    if fn_obj == 0 return 0
    simplified_count = 0

    bi = 0
    while bi < len(fn_obj.blocks)
        bb = get(fn_obj.blocks, bi)
        new_insts = list()
        ii = 0
        while ii < len(bb.instructions)
            inst = get(bb.instructions, ii)
            replacement_val = peephole_simplify_inst(inst)

            if replacement_val != 0
                // Replace all uses of inst.result with replacement_val
                ssa_value_replace_all_uses_with(inst.result, replacement_val)
                ssa_instr_remove_from_operands_use_lists(inst)
                inst.is_dead = 1
                simplified_count = simplified_count + 1
            else
                push(new_insts, inst)

            ii = ii + 1

        bb.instructions = new_insts
        bi = bi + 1

    return simplified_count
