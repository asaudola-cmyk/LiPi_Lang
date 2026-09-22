// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END BASIC BLOCK (src/compiler/middleend/ir/basic_block.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: A Basic Block is a maximal sequence of straight-line instructions with a
//      single entry point (at the first instruction) and a single exit point (at
//      the terminating instruction: Br, Jmp, or Ret).
//      Partitioning the program into basic blocks reduces global control flow to
//      a directed graph (CFG), enabling graph-theoretic analyses such as Dominator
//      Trees, Natural Loop detection, and global dataflow equations.
// ==============================================================================

include "src/compiler/middleend/ir/ssa_instr.lp"

// ── 1. Basic Block Structure ──────────────────────────────────────────────────
// WHY: Storing explicit predecessor and successor label lists enables bidirectional
//      graph navigation without needing to re-scan terminator instructions every time.

struct BasicBlock
    label         // string: unique symbol identifier (e.g. "entry", "loop_header")
    instructions  // list: ordered sequence of SSAInstr nodes
    predecessors  // list: string labels of all basic blocks with edges entering here
    successors    // list: string labels of all basic blocks reached by exit branches
    parent_fn     // reference: IRFunction containing this basic block
    is_sealed     // integer: 1 if all predecessor edges have been recorded (SSA sealing)

// ── 2. Constructor ────────────────────────────────────────────────────────────

fn basic_block_new label parent_fn
    bb = BasicBlock()
    bb.label = label
    bb.instructions = list()
    bb.predecessors = list()
    bb.successors = list()
    bb.parent_fn = parent_fn
    bb.is_sealed = 0
    return bb

// ── 3. Instruction Insertion and Removal ───────────────────────────────────────

// Appends an instruction to the end of the basic block
// WHY: Sets parent_bb link and ensures all operands are registered in def-use chains.
fn basic_block_append_inst bb inst
    if bb == 0 or inst == 0 return 0
    inst.parent_bb = bb
    push(bb.instructions, inst)
    i = 0
    cnt = len(inst.operands)
    while i < cnt
        opnd = get(inst.operands, i)
        if opnd != 0
            ssa_value_add_use(opnd, inst)
        i = i + 1
    return 1

fn BasicBlock.append_inst self inst
    return basic_block_append_inst(self, inst)

fn append_inst bb inst
    return basic_block_append_inst(bb, inst)

// Prepends an instruction to the beginning of the basic block
// WHY: Used for placing Phi nodes or stack allocations at the top of blocks.
fn basic_block_prepend_inst bb inst
    if bb == 0 or inst == 0 return 0
    inst.parent_bb = bb
    new_insts = list()
    push(new_insts, inst)
    i = 0
    cnt = len(bb.instructions)
    while i < cnt
        push(new_insts, get(bb.instructions, i))
        i = i + 1
    bb.instructions = new_insts
    
    j = 0
    ocnt = len(inst.operands)
    while j < ocnt
        opnd = get(inst.operands, j)
        if opnd != 0
            ssa_value_add_use(opnd, inst)
        j = j + 1
    return 1

fn BasicBlock.prepend_inst self inst
    return basic_block_prepend_inst(self, inst)

fn prepend_inst bb inst
    return basic_block_prepend_inst(bb, inst)

// Inserts an instruction immediately before a target instruction
// WHY: Essential for hoisting loop invariants right before a loop exit/terminator,
//      or inserting computation before its first use.
fn basic_block_insert_before bb target_inst new_inst
    if bb == 0 or target_inst == 0 or new_inst == 0 return 0
    new_inst.parent_bb = bb
    new_insts = list()
    i = 0
    cnt = len(bb.instructions)
    inserted = 0
    while i < cnt
        item = get(bb.instructions, i)
        if item == target_inst and inserted == 0
            push(new_insts, new_inst)
            inserted = 1
        push(new_insts, item)
        i = i + 1
    if inserted == 0
        push(new_insts, new_inst)
    bb.instructions = new_insts

    j = 0
    ocnt = len(new_inst.operands)
    while j < ocnt
        opnd = get(new_inst.operands, j)
        if opnd != 0
            ssa_value_add_use(opnd, new_inst)
        j = j + 1
    return 1

fn BasicBlock.insert_before self target_inst new_inst
    return basic_block_insert_before(self, target_inst, new_inst)

fn insert_before bb target_inst new_inst
    return basic_block_insert_before(bb, target_inst, new_inst)

// Inserts an instruction immediately after a target instruction
fn basic_block_insert_after bb target_inst new_inst
    if bb == 0 or target_inst == 0 or new_inst == 0 return 0
    new_inst.parent_bb = bb
    new_insts = list()
    i = 0
    cnt = len(bb.instructions)
    inserted = 0
    while i < cnt
        item = get(bb.instructions, i)
        push(new_insts, item)
        if item == target_inst and inserted == 0
            push(new_insts, new_inst)
            inserted = 1
        i = i + 1
    if inserted == 0
        push(new_insts, new_inst)
    bb.instructions = new_insts

    j = 0
    ocnt = len(new_inst.operands)
    while j < ocnt
        opnd = get(new_inst.operands, j)
        if opnd != 0
            ssa_value_add_use(opnd, new_inst)
        j = j + 1
    return 1

fn BasicBlock.insert_after self target_inst new_inst
    return basic_block_insert_after(self, target_inst, new_inst)

fn insert_after bb target_inst new_inst
    return basic_block_insert_after(bb, target_inst, new_inst)

// Removes an instruction from this basic block
// WHY: Automatically cleans up operand use lists and marks the instruction as dead.
fn basic_block_remove_inst bb inst
    if bb == 0 or inst == 0 return 0
    new_insts = list()
    i = 0
    cnt = len(bb.instructions)
    found = 0
    while i < cnt
        item = get(bb.instructions, i)
        if item != inst
            push(new_insts, item)
        else
            found = 1
        i = i + 1
    bb.instructions = new_insts
    if found == 1
        ssa_instr_remove_from_operands_use_lists(inst)
        inst.is_dead = 1
    return found

fn BasicBlock.remove_inst self inst
    return basic_block_remove_inst(self, inst)

fn remove_inst bb inst
    return basic_block_remove_inst(bb, inst)

// ── 4. Block Inspection Utilities ─────────────────────────────────────────────

// Returns the terminator instruction of this basic block, or 0 if block is malformed/unterminated
// WHY: Every valid SSA basic block must conclude with Br, Jmp, or Ret.
fn basic_block_get_terminator bb
    if bb == 0 return 0
    cnt = len(bb.instructions)
    if cnt == 0 return 0
    last_inst = get(bb.instructions, cnt - 1)
    if ssa_instr_is_terminator(last_inst) == 1
        return last_inst
    return 0

fn BasicBlock.get_terminator self
    return basic_block_get_terminator(self)

fn get_terminator bb
    return basic_block_get_terminator(bb)

// Returns the first instruction in the block that is not an OP_PHI
// WHY: Hoisted loop invariants and function setup instructions must be placed
//      after all Phi nodes, as Phi nodes must precede all other instructions.
fn basic_block_first_non_phi bb
    if bb == 0 return 0
    i = 0
    cnt = len(bb.instructions)
    while i < cnt
        inst = get(bb.instructions, i)
        if inst.op != OP_PHI
            return inst
        i = i + 1
    return 0

fn BasicBlock.first_non_phi self
    return basic_block_first_non_phi(self)

fn first_non_phi bb
    return basic_block_first_non_phi(bb)

// Returns the number of instructions in this block
fn basic_block_inst_count bb
    if bb == 0 return 0
    return len(bb.instructions)

fn BasicBlock.inst_count self
    return basic_block_inst_count(self)

fn inst_count bb
    return basic_block_inst_count(bb)

// Returns instruction at specified index
fn basic_block_get_inst bb idx
    if bb == 0 or idx < 0 or idx >= len(bb.instructions)
        return 0
    return get(bb.instructions, idx)

fn BasicBlock.get_inst self idx
    return basic_block_get_inst(self, idx)

fn get_inst bb idx
    return basic_block_get_inst(bb, idx)

// ── 5. CFG Edge Maintenance ───────────────────────────────────────────────────

// Adds a predecessor block label if not already present
fn basic_block_add_pred bb pred_lbl
    if bb == 0 or len(pred_lbl) == 0 return 0
    i = 0
    cnt = len(bb.predecessors)
    while i < cnt
        if get(bb.predecessors, i) == pred_lbl
            return 0
        i = i + 1
    push(bb.predecessors, pred_lbl)
    return 1

fn BasicBlock.add_pred self pred_lbl
    return basic_block_add_pred(self, pred_lbl)

fn add_pred bb pred_lbl
    return basic_block_add_pred(bb, pred_lbl)

// Adds a successor block label if not already present
fn basic_block_add_succ bb succ_lbl
    if bb == 0 or len(succ_lbl) == 0 return 0
    i = 0
    cnt = len(bb.successors)
    while i < cnt
        if get(bb.successors, i) == succ_lbl
            return 0
        i = i + 1
    push(bb.successors, succ_lbl)
    return 1

fn BasicBlock.add_succ self succ_lbl
    return basic_block_add_succ(self, succ_lbl)

fn add_succ bb succ_lbl
    return basic_block_add_succ(bb, succ_lbl)

// Removes a predecessor block label
fn basic_block_remove_pred bb pred_lbl
    if bb == 0 return 0
    new_preds = list()
    i = 0
    cnt = len(bb.predecessors)
    found = 0
    while i < cnt
        p = get(bb.predecessors, i)
        if p != pred_lbl
            push(new_preds, p)
        else
            found = 1
        i = i + 1
    bb.predecessors = new_preds
    return found

fn BasicBlock.remove_pred self pred_lbl
    return basic_block_remove_pred(self, pred_lbl)

fn remove_pred bb pred_lbl
    return basic_block_remove_pred(bb, pred_lbl)

// Removes a successor block label
fn basic_block_remove_succ bb succ_lbl
    if bb == 0 return 0
    new_succs = list()
    i = 0
    cnt = len(bb.successors)
    found = 0
    while i < cnt
        s = get(bb.successors, i)
        if s != succ_lbl
            push(new_succs, s)
        else
            found = 1
        i = i + 1
    bb.successors = new_succs
    return found

fn BasicBlock.remove_succ self succ_lbl
    return basic_block_remove_succ(self, succ_lbl)

fn remove_succ bb succ_lbl
    return basic_block_remove_succ(bb, succ_lbl)

// Returns 1 if pred_lbl is in this block's predecessors
fn basic_block_has_pred bb pred_lbl
    if bb == 0 return 0
    i = 0
    cnt = len(bb.predecessors)
    while i < cnt
        if get(bb.predecessors, i) == pred_lbl
            return 1
        i = i + 1
    return 0

fn BasicBlock.has_pred self pred_lbl
    return basic_block_has_pred(self, pred_lbl)

fn has_pred bb pred_lbl
    return basic_block_has_pred(bb, pred_lbl)

// Returns 1 if succ_lbl is in this block's successors
fn basic_block_has_succ bb succ_lbl
    if bb == 0 return 0
    i = 0
    cnt = len(bb.successors)
    while i < cnt
        if get(bb.successors, i) == succ_lbl
            return 1
        i = i + 1
    return 0

fn BasicBlock.has_succ self succ_lbl
    return basic_block_has_succ(self, succ_lbl)

fn has_succ bb succ_lbl
    return basic_block_has_succ(bb, succ_lbl)
