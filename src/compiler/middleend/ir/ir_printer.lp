// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END SSA IR PRINTER (src/compiler/middleend/ir/ir_printer.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Human-readable textual representation of Intermediate Representation is
//      indispensable for compiler debugging, regression testing, pass visualization,
//      and inspecting optimization diffs.
//      This module provides deterministic formatting of Modules, Functions,
//      Basic Blocks, Phi nodes, and Three-Address Code SSA instructions.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"

// ── 1. Single Instruction Formatter ───────────────────────────────────────────

fn ir_dump_instr_to_str inst
    if inst == 0 return "nop"
    op = inst.op

    // Memory operations
    if op == OP_ALLOCA
        res_str = ssa_value_to_str(inst.result)
        elem_ty = inst.extra_str
        if len(elem_ty) == 0 elem_ty = "i64"
        return "  " + res_str + " = alloca " + elem_ty

    if op == OP_LOAD
        res_str = ssa_value_to_str(inst.result)
        ptr_val = ssa_instr_get_operand(inst, 0)
        ptr_str = ssa_value_to_str(ptr_val)
        return "  " + res_str + " = load " + inst.result.vtype + ", " + ptr_str

    if op == OP_STORE
        val = ssa_instr_get_operand(inst, 0)
        ptr = ssa_instr_get_operand(inst, 1)
        return "  store " + ssa_value_to_str(val) + ", " + ssa_value_to_str(ptr)

    // Binary Arithmetic & Bitwise
    if ssa_is_binary_arithmetic(op) == 1 or ssa_is_bitwise(op) == 1
        res_str = ssa_value_to_str(inst.result)
        lhs = ssa_value_to_str(ssa_instr_get_operand(inst, 0))
        rhs = ssa_value_to_str(ssa_instr_get_operand(inst, 1))
        return "  " + res_str + " = " + ssa_opcode_name(op) + " " + inst.result.vtype + " " + lhs + ", " + rhs

    // Unary Negation
    if op == OP_NEG
        res_str = ssa_value_to_str(inst.result)
        val = ssa_value_to_str(ssa_instr_get_operand(inst, 0))
        return "  " + res_str + " = neg " + inst.result.vtype + " " + val

    // Comparison
    if op == OP_CMP
        res_str = ssa_value_to_str(inst.result)
        pred_str = ssa_cmp_pred_name(inst.extra_int)
        lhs = ssa_value_to_str(ssa_instr_get_operand(inst, 0))
        rhs = ssa_value_to_str(ssa_instr_get_operand(inst, 1))
        return "  " + res_str + " = cmp " + pred_str + " " + lhs + ", " + rhs

    // Control Flow: Conditional Branch
    if op == OP_BR
        cond_str = ssa_value_to_str(ssa_instr_get_operand(inst, 0))
        true_lbl = get(inst.extra_list, 0)
        false_lbl = get(inst.extra_list, 1)
        return "  br " + cond_str + ", label %" + true_lbl + ", label %" + false_lbl

    // Control Flow: Unconditional Jump
    if op == OP_JMP
        return "  jmp label %" + inst.extra_str

    // Control Flow: Return
    if op == OP_RET
        if len(inst.operands) > 0
            val = ssa_instr_get_operand(inst, 0)
            return "  ret " + val.vtype + " " + ssa_value_to_str(val)
        return "  ret void"

    // Function Invocation
    if op == OP_CALL
        res_prefix = ""
        if inst.result != 0
            res_prefix = ssa_value_to_str(inst.result) + " = "
        call_str = "  " + res_prefix + "call @" + inst.extra_str + "("
        i = 0
        cnt = len(inst.operands)
        while i < cnt
            if i > 0 call_str = call_str + ", "
            arg = ssa_instr_get_operand(inst, i)
            call_str = call_str + ssa_value_to_str(arg)
            i = i + 1
        call_str = call_str + ")"
        return call_str

    // SSA Confluence: Phi
    if op == OP_PHI
        res_str = ssa_value_to_str(inst.result)
        phi_str = "  " + res_str + " = phi " + inst.result.vtype + " "
        i = 0
        cnt = len(inst.operands)
        while i < cnt
            if i > 0 phi_str = phi_str + ", "
            val = ssa_instr_get_operand(inst, i)
            bb_lbl = get(inst.extra_list, i)
            phi_str = phi_str + "[" + ssa_value_to_str(val) + ", %" + bb_lbl + "]"
            i = i + 1
        return phi_str

    if op == OP_NOP
        return "  nop"

    return "  <unknown_inst>"

// ── 2. Basic Block Printer ────────────────────────────────────────────────────

fn ir_print_basic_block bb
    if bb == 0 return 0
    say bb.label + ":"

    // Display predecessor comments for CFG debugging
    if len(bb.predecessors) > 0
        preds_str = "  ; preds: "
        pi = 0
        while pi < len(bb.predecessors)
            if pi > 0 preds_str = preds_str + ", "
            preds_str = preds_str + "%" + get(bb.predecessors, pi)
            pi = pi + 1
        say preds_str

    ii = 0
    icnt = len(bb.instructions)
    while ii < icnt
        inst = get(bb.instructions, ii)
        say ir_dump_instr_to_str(inst)
        ii = ii + 1

    return 1

// ── 3. Function & Module Printers ─────────────────────────────────────────────

fn ir_print_function fn_obj
    if fn_obj == 0 return 0
    hdr = "define " + fn_obj.return_type + " @" + fn_obj.name + "("
    i = 0
    pcnt = len(fn_obj.params)
    while i < pcnt
        if i > 0 hdr = hdr + ", "
        p = get(fn_obj.params, i)
        hdr = hdr + p.vtype + " " + ssa_value_to_str(p)
        i = i + 1
    hdr = hdr + ") {"
    say hdr

    bi = 0
    bcnt = len(fn_obj.blocks)
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        ir_print_basic_block(bb)
        bi = bi + 1

    say "}\n"
    return 1

fn ir_print_module mod_obj
    if mod_obj == 0 return 0
    say "; =================================================================="
    say "; 👑 Lipi SSA IR Module: " + mod_obj.name
    say "; =================================================================="

    // Print metadata
    mi = 0
    mcnt = len(mod_obj.meta_keys)
    while mi < mcnt
        say "; meta: " + get(mod_obj.meta_keys, mi) + " = " + get(mod_obj.meta_vals, mi)
        mi = mi + 1

    // Print globals
    gi = 0
    gcnt = len(mod_obj.globals)
    while gi < gcnt
        g = get(mod_obj.globals, gi)
        const_tag = "global"
        if g.is_const == 1 const_tag = "constant"
        say g.name + " = " + const_tag + " " + g.gtype + " " + str(g.init_val)
        gi = gi + 1

    if gcnt > 0 say ""

    // Print functions
    fi = 0
    fcnt = len(mod_obj.functions)
    while fi < fcnt
        fn_obj = get(mod_obj.functions, fi)
        ir_print_function(fn_obj)
        fi = fi + 1

    return 1
