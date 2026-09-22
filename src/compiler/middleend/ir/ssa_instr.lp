// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END SSA INSTRUCTION (src/compiler/middleend/ir/ssa_instr.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: In SSA Intermediate Representation, an instruction node is the primary unit
//      of computation and control flow. Every instruction explicitly connects its
//      input operand values (Def-Use chains) to its defined output value, and anchors
//      itself to an enclosing BasicBlock.
//      This strict structural representation guarantees that any transformation
//      (such as instruction hoisting, copy propagation, or dead code elimination)
//      can maintain dominance and liveness invariants with mathematical precision.
// ==============================================================================

include "src/compiler/middleend/ir/ssa_opcodes.lp"
include "src/compiler/middleend/ir/ssa_value.lp"

// ── 1. SSA Instruction Node Structure ─────────────────────────────────────────
// WHY: Unified node format handles memory operations, 3-address arithmetic,
//      control flow transfers, and n-ary phi confluence nodes uniformly.

struct SSAInstr
    id          // integer: unique monotonic instruction identifier (index 0)
    inst_pad1   // alignment padding (index 1)
    inst_pad2   // alignment padding (index 2)
    inst_pad3   // alignment padding (index 3)
    inst_pad4   // alignment padding (index 4)
    inst_pad5   // alignment padding (index 5)
    op          // integer: opcode constant (OP_*) - index 6, perfectly aligned with ASTNode.op
    operands    // list: SSAValue objects consumed by this instruction (index 7)
    result      // SSAValue reference: value defined by this instruction (0 if void/store/branch)
    parent_bb   // reference: BasicBlock containing this instruction
    extra_int   // integer: comparison predicate (CMP_*), immediate tag, or flags
    extra_str   // string: callee symbol name or jump target label
    extra_list  // list: incoming basic block labels for phi nodes, or branch targets
    is_dead     // integer: 1 if instruction has been marked for elimination, 0 if live

// ── 2. Base Constructor ───────────────────────────────────────────────────────

fn ssa_instr_new id op result parent_bb
    inst = SSAInstr()
    inst.id = id
    inst.inst_pad1 = 0
    inst.inst_pad2 = 0
    inst.inst_pad3 = 0
    inst.inst_pad4 = 0
    inst.inst_pad5 = 0
    inst.op = op
    inst.operands = list()
    inst.result = result
    inst.parent_bb = parent_bb
    inst.extra_int = 0
    inst.extra_str = ""
    inst.extra_list = list()
    inst.is_dead = 0

    // If this instruction defines an SSA value, link value's def_inst back to here
    if result != 0
        result.def_inst = inst

    return inst

// ── 3. Specialized Instruction Builders ───────────────────────────────────────
// WHY: Ergonomic builders enforce invariant operand configurations and eliminate
//      boilerplate during AST lowering and optimization rewriting.

// %ptr = alloca elem_type, count
// WHY: Local stack allocations provide addressable storage for mutable local variables.
fn ir_build_alloca id result_val elem_type size_val
    inst = ssa_instr_new(id, OP_ALLOCA, result_val, 0)
    inst.extra_str = elem_type
    if size_val != 0
        push(inst.operands, size_val)
        ssa_value_add_use(size_val, inst)
    return inst

// %val = load type, %ptr
// WHY: Explicit load instructions demarcate points where memory state enters SSA registers.
fn ir_build_load id result_val ptr_val
    inst = ssa_instr_new(id, OP_LOAD, result_val, 0)
    push(inst.operands, ptr_val)
    ssa_value_add_use(ptr_val, inst)
    return inst

// store %val, %ptr
// WHY: Memory stores have observable side effects and do not define an SSA register.
fn ir_build_store id val ptr_val
    inst = ssa_instr_new(id, OP_STORE, 0, 0)
    push(inst.operands, val)
    push(inst.operands, ptr_val)
    ssa_value_add_use(val, inst)
    ssa_value_add_use(ptr_val, inst)
    return inst

// %res = binop %lhs, %rhs (OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, etc.)
// WHY: Three-Address Code binary operations are the workhorse of arithmetic calculation.
fn ir_build_binop id op result_val lhs rhs
    inst = ssa_instr_new(id, op, result_val, 0)
    push(inst.operands, lhs)
    push(inst.operands, rhs)
    ssa_value_add_use(lhs, inst)
    ssa_value_add_use(rhs, inst)
    return inst

// %res = neg %val
// WHY: Unary arithmetic negation.
fn ir_build_neg id result_val val
    inst = ssa_instr_new(id, OP_NEG, result_val, 0)
    push(inst.operands, val)
    ssa_value_add_use(val, inst)
    return inst

// %res = cmp pred, %lhs, %rhs
// WHY: Unified relational comparison with explicit predicate enum (CMP_EQ, CMP_SLT, etc.).
fn ir_build_cmp id pred result_val lhs rhs
    inst = ssa_instr_new(id, OP_CMP, result_val, 0)
    inst.extra_int = pred
    push(inst.operands, lhs)
    push(inst.operands, rhs)
    ssa_value_add_use(lhs, inst)
    ssa_value_add_use(rhs, inst)
    return inst

// br %cond, true_label, false_label
// WHY: Conditional branches terminate basic blocks, routing control to one of two successors.
fn ir_build_br id cond_val true_lbl false_lbl
    inst = ssa_instr_new(id, OP_BR, 0, 0)
    push(inst.operands, cond_val)
    ssa_value_add_use(cond_val, inst)
    push(inst.extra_list, true_lbl)
    push(inst.extra_list, false_lbl)
    return inst

// jmp target_label
// WHY: Unconditional jump terminates basic blocks with a single target successor.
fn ir_build_jmp id target_lbl
    inst = ssa_instr_new(id, OP_JMP, 0, 0)
    inst.extra_str = target_lbl
    return inst

// ret %val
// WHY: Function return transmitting an SSA value to caller stack/register ABI.
fn ir_build_ret id val
    inst = ssa_instr_new(id, OP_RET, 0, 0)
    if val != 0
        push(inst.operands, val)
        ssa_value_add_use(val, inst)
    return inst

// ret void
// WHY: Function return for procedures returning no value.
fn ir_build_ret_void id
    return ir_build_ret(id, 0)

// %res = call @callee, [%arg0, %arg1, ...]
// WHY: Function call node encapsulating argument operands and optional return value.
fn ir_build_call id result_val callee_name args_list
    inst = ssa_instr_new(id, OP_CALL, result_val, 0)
    inst.extra_str = callee_name
    i = 0
    cnt = len(args_list)
    while i < cnt
        arg = get(args_list, i)
        push(inst.operands, arg)
        ssa_value_add_use(arg, inst)
        i = i + 1
    return inst

// %res = phi [%val0, bb0], [%val1, bb1], ...
// WHY: SSA Phi node resolves variable values at control flow merge points.
fn ir_build_phi id result_val incoming_vals incoming_bbs
    inst = ssa_instr_new(id, OP_PHI, result_val, 0)
    inst.extra_list = incoming_bbs
    i = 0
    cnt = len(incoming_vals)
    while i < cnt
        val = get(incoming_vals, i)
        push(inst.operands, val)
        ssa_value_add_use(val, inst)
        i = i + 1
    return inst

// ── 4. Operand Manipulation & Use-Chain Maintenance ───────────────────────────

// Replaces all occurrences of old_val in this instruction's operands with new_val
// WHY: Maintains exact def-use invariant during optimization passes.
fn ssa_instr_replace_operand inst old_val new_val
    if inst == 0 or old_val == 0 or new_val == 0
        return 0
    replaced = 0
    i = 0
    cnt = len(inst.operands)
    while i < cnt
        opnd = get(inst.operands, i)
        if opnd == old_val
            list_set(inst.operands, i, new_val)
            ssa_value_add_use(new_val, inst)
            replaced = replaced + 1
        i = i + 1
    if replaced > 0
        ssa_value_remove_use(old_val, inst)
    return replaced

fn SSAInstr.replace_operand self old_val new_val
    return ssa_instr_replace_operand(self, old_val, new_val)

fn replace_operand inst old_val new_val
    return ssa_instr_replace_operand(inst, old_val, new_val)

// Removes this instruction from the use lists of all its operands
// WHY: Must be invoked when an instruction is removed or deleted by Dead Code Elimination.
fn ssa_instr_remove_from_operands_use_lists inst
    if inst == 0
        return 0
    i = 0
    cnt = len(inst.operands)
    while i < cnt
        opnd = get(inst.operands, i)
        if opnd != 0
            ssa_value_remove_use(opnd, inst)
        i = i + 1
    return 1

fn SSAInstr.remove_from_operands_use_lists self
    return ssa_instr_remove_from_operands_use_lists(self)

fn remove_from_operands_use_lists inst
    return ssa_instr_remove_from_operands_use_lists(inst)

// Returns 1 if this instruction is a block terminator (Br, Jmp, Ret)
fn ssa_instr_is_terminator inst
    if inst == 0 return 0
    return ssa_is_terminator(inst.op)

fn SSAInstr.is_terminator self
    return ssa_instr_is_terminator(self)

fn is_terminator inst
    return ssa_instr_is_terminator(inst)

// Returns 1 if this instruction has observable side effects (Store, Call, Ret, Br, Jmp)
fn ssa_instr_has_side_effects inst
    if inst == 0 return 0
    return ssa_has_side_effects(inst.op)

fn SSAInstr.has_side_effects self
    return ssa_instr_has_side_effects(self)

fn has_side_effects inst
    return ssa_instr_has_side_effects(inst)

// Safe operand getter
fn ssa_instr_get_operand inst idx
    if inst == 0 or idx < 0 or idx >= len(inst.operands)
        return 0
    return get(inst.operands, idx)

fn SSAInstr.get_operand self idx
    return ssa_instr_get_operand(self, idx)

fn get_operand inst idx
    return ssa_instr_get_operand(inst, idx)

// Safe operand count getter
fn ssa_instr_operand_count inst
    if inst == 0 return 0
    return len(inst.operands)

fn SSAInstr.operand_count self
    return ssa_instr_operand_count(self)

fn operand_count inst
    return ssa_instr_operand_count(inst)
