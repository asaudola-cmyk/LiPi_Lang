// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END IR FUNCTION (src/compiler/middleend/ir/ir_function.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: An IR Function represents an isolated procedural compilation unit comprising:
//      1. Formal argument declarations (SSA inputs).
//      2. An entry basic block guaranteed to execute first upon entry.
//      3. A collection of basic blocks forming the Control Flow Graph.
//      4. A local stack allocation table (Alloca) for stack slot reservation.
//      Centralizing block registration and monotonic SSA temporary/label generation
//      at the function level prevents identifier collisions and simplifies inter-
//      block optimization algorithms.
// ==============================================================================

include "src/compiler/middleend/ir/basic_block.lp"

// ── 1. IR Function Structure ──────────────────────────────────────────────────

struct IRFunction
    name           // string: function identifier (e.g. "main", "fibonacci")
    params         // list: SSAValue objects representing formal parameters
    return_type    // string: return type signature ("i64", "void", "ptr", etc.)
    entry_block    // BasicBlock: dedicated unique entry point into the function
    blocks         // list: all BasicBlock objects belonging to this function
    allocas        // list: SSAInstr (OP_ALLOCA) records reserved for local stack slots
    val_counter    // integer: monotonically increasing counter for SSA registers (%v0, %v1)
    block_counter  // integer: monotonically increasing counter for unique block labels

// ── 2. Constructor ────────────────────────────────────────────────────────────

fn ir_function_new name return_type
    fn_obj = IRFunction()
    fn_obj.name = name
    fn_obj.params = list()
    fn_obj.return_type = return_type
    fn_obj.blocks = list()
    fn_obj.allocas = list()
    fn_obj.val_counter = 0
    fn_obj.block_counter = 1

    // Automatically construct and register the canonical entry basic block
    // WHY: Every function in standard SSA form must have a unique entry block
    //      with zero predecessors.
    entry_bb = basic_block_new("entry", fn_obj)
    fn_obj.entry_block = entry_bb
    push(fn_obj.blocks, entry_bb)

    return fn_obj

// ── 3. Parameter & Allocation Registration ────────────────────────────────────

// Adds a formal argument to the function signature
fn ir_function_add_param fn_obj param_val
    if fn_obj == 0 or param_val == 0 return 0
    push(fn_obj.params, param_val)
    return 1

fn IRFunction.add_param self param_val
    return ir_function_add_param(self, param_val)

fn add_param fn_obj param_val
    return ir_function_add_param(fn_obj, param_val)

// Registers a local stack slot allocation (Alloca instruction)
// WHY: Placing local allocations in a dedicated list allows the backend to compute
//      total stack frame byte size in O(alloca_count) time without scanning blocks.
fn ir_function_register_alloca fn_obj alloca_inst
    if fn_obj == 0 or alloca_inst == 0 return 0
    push(fn_obj.allocas, alloca_inst)
    return 1

fn IRFunction.register_alloca self alloca_inst
    return ir_function_register_alloca(self, alloca_inst)

fn register_alloca fn_obj alloca_inst
    return ir_function_register_alloca(fn_obj, alloca_inst)

// ── 4. Basic Block Management ─────────────────────────────────────────────────

// Appends an existing basic block to this function
fn ir_function_add_block fn_obj bb
    if fn_obj == 0 or bb == 0 return 0
    bb.parent_fn = fn_obj
    push(fn_obj.blocks, bb)
    return 1

fn IRFunction.add_block self bb
    return ir_function_add_block(self, bb)

fn add_block fn_obj bb
    return ir_function_add_block(fn_obj, bb)

// Creates, registers, and returns a fresh basic block with a unique label
// WHY: Guarantees globally unique labels within the function (e.g. "loop_body_2").
fn ir_function_create_block fn_obj label_prefix
    if fn_obj == 0 return 0
    cnt = fn_obj.block_counter
    fn_obj.block_counter = cnt + 1
    lbl = label_prefix + "_" + str(cnt)
    bb = basic_block_new(lbl, fn_obj)
    push(fn_obj.blocks, bb)
    return bb

fn IRFunction.create_block self label_prefix
    return ir_function_create_block(self, label_prefix)

fn create_block fn_obj label_prefix
    return ir_function_create_block(fn_obj, label_prefix)

// Finds a basic block in the function by label string
fn ir_function_find_block fn_obj label
    if fn_obj == 0 return 0
    i = 0
    cnt = len(fn_obj.blocks)
    while i < cnt
        bb = get(fn_obj.blocks, i)
        if bb.label == label
            return bb
        i = i + 1
    return 0

fn IRFunction.find_block self label
    return ir_function_find_block(self, label)

fn find_block fn_obj label
    return ir_function_find_block(fn_obj, label)

// Removes a basic block from the function and purges its instructions from use lists
// WHY: Used by unreachable code elimination (DCE) to delete orphaned blocks.
fn ir_function_remove_block fn_obj bb
    if fn_obj == 0 or bb == 0 return 0
    new_blocks = list()
    i = 0
    cnt = len(fn_obj.blocks)
    found = 0
    while i < cnt
        item = get(fn_obj.blocks, i)
        if item != bb
            push(new_blocks, item)
        else
            found = 1
        i = i + 1
    fn_obj.blocks = new_blocks

    if found == 1
        // Clean up all instructions in this block
        j = 0
        icnt = len(bb.instructions)
        while j < icnt
            inst = get(bb.instructions, j)
            ssa_instr_remove_from_operands_use_lists(inst)
            inst.is_dead = 1
            j = j + 1
    return found

fn IRFunction.remove_block self bb
    return ir_function_remove_block(self, bb)

fn remove_block fn_obj bb
    return ir_function_remove_block(fn_obj, bb)

// ── 5. Value Generation & Inspection ──────────────────────────────────────────

// Generates a fresh monotonic SSA register value (%v0, %v1, %v2, ...)
// WHY: Strict single-assignment invariant requires each computed temporary to have
//      a distinct name.
fn ir_function_new_val fn_obj vtype
    if fn_obj == 0 return 0
    cnt = fn_obj.val_counter
    fn_obj.val_counter = cnt + 1
    id_str = "%v" + str(cnt)
    return ssa_value_new_inst(id_str, vtype, 0)

fn IRFunction.new_val self vtype
    return ir_function_new_val(self, vtype)

fn new_val fn_obj vtype
    return ir_function_new_val(fn_obj, vtype)

// Returns the total instruction count across all basic blocks in the function
// WHY: Used by inlining heuristics to gauge callee code size against threshold limits.
fn ir_function_count_insts fn_obj
    if fn_obj == 0 return 0
    total = 0
    i = 0
    cnt = len(fn_obj.blocks)
    while i < cnt
        bb = get(fn_obj.blocks, i)
        total = total + len(bb.instructions)
        i = i + 1
    return total

fn IRFunction.count_insts self
    return ir_function_count_insts(self)

fn count_insts fn_obj
    return ir_function_count_insts(fn_obj)

// Collects all defined SSA values in the function (parameters + instruction outputs)
// WHY: Used by SSA verifiers and liveness analyzers to validate global consistency.
fn ir_function_get_all_values fn_obj
    val_list = list()
    if fn_obj == 0 return val_list

    // 1. Gather parameters
    i = 0
    pcnt = len(fn_obj.params)
    while i < pcnt
        push(val_list, get(fn_obj.params, i))
        i = i + 1

    // 2. Gather instruction results
    bi = 0
    bcnt = len(fn_obj.blocks)
    while bi < bcnt
        bb = get(fn_obj.blocks, bi)
        ii = 0
        icnt = len(bb.instructions)
        while ii < icnt
            inst = get(bb.instructions, ii)
            if inst.result != 0
                push(val_list, inst.result)
            ii = ii + 1
        bi = bi + 1

    return val_list

fn IRFunction.get_all_values self
    return ir_function_get_all_values(self)

fn get_all_values fn_obj
    return ir_function_get_all_values(fn_obj)
