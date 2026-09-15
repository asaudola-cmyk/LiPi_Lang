// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END SSA IR OPCODES (src/compiler/middleend/ir/ssa_opcodes.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: Intermediate Representation (IR) in Static Single Assignment (SSA) form
//      is the computational backbone of modern optimizing compilers.
//      By defining an explicit, closed set of atomic numeric opcodes, the compiler
//      transforms complex language constructs into primitive silicon-friendly
//      operations. Numeric opcodes allow single-cycle integer comparisons during
//      optimization passes (e.g. constant folding, CSE, DCE), avoiding expensive
//      string comparison overhead.
// ==============================================================================

// ── 1. SSA Opcode Constants ───────────────────────────────────────────────────
// WHY: Explicit numeric constants allow fast dispatch in pattern matching and
//      analysis passes without string parsing overhead.

OP_NOP      = 0   // No-operation (tombstone placeholder for deleted instructions)
OP_ALLOCA   = 1   // Stack frame slot allocation: %ptr = alloca type, count
OP_LOAD     = 2   // Memory read: %val = load type, %ptr
OP_STORE    = 3   // Memory write: store %val, %ptr (has side-effects, no SSA result)
OP_ADD      = 4   // Integer addition: %res = add %a, %b
OP_SUB      = 5   // Integer subtraction: %res = sub %a, %b
OP_MUL      = 6   // Integer multiplication: %res = mul %a, %b
OP_DIV      = 7   // Signed integer division: %res = div %a, %b
OP_MOD      = 8   // Signed remainder/modulo: %res = mod %a, %b
OP_NEG      = 9   // Unary arithmetic negation: %res = neg %a
OP_SHL      = 10  // Bitwise logical shift left: %res = shl %a, %bits
OP_SHR      = 11  // Bitwise arithmetic shift right: %res = shr %a, %bits
OP_AND      = 12  // Bitwise AND: %res = and %a, %b
OP_OR       = 13  // Bitwise OR: %res = or %a, %b
OP_XOR      = 14  // Bitwise XOR: %res = xor %a, %b
OP_CMP      = 15  // Relational comparison: %res = cmp pred, %a, %b
OP_BR       = 16  // Conditional control transfer: br %cond, label_then, label_else
OP_JMP      = 17  // Unconditional control transfer: jmp label_target
OP_RET      = 18  // Function return: ret %val (or ret void)
OP_CALL     = 19  // Function invocation: %res = call @callee, [%arg0, %arg1, ...]
OP_PHI      = 20  // SSA Confluence selector: %res = phi [%val0, bb0], [%val1, bb1]

// ── 2. Comparison Predicates ──────────────────────────────────────────────────
// WHY: Unifying relational comparisons under a single OP_CMP opcode with a predicate
//      attribute mirrors high-performance compiler architectures (such as LLVM ICmp)
//      and simplifies instruction selection and peephole inversions.

CMP_EQ      = 1   // Equal (==)
CMP_NE      = 2   // Not Equal (!=)
CMP_SLT     = 3   // Signed Less Than (<)
CMP_SLE     = 4   // Signed Less Than or Equal (<=)
CMP_SGT     = 5   // Signed Greater Than (>)
CMP_SGE     = 6   // Signed Greater Than or Equal (>=)

// ── 3. Opcode Mnemonic Names ──────────────────────────────────────────────────
// WHY: Human-readable string representations are essential for debug dumps,
//      error reporting in verifiers, and IR visualization.

fn ssa_opcode_name op
    if op == OP_NOP return "nop"
    if op == OP_ALLOCA return "alloca"
    if op == OP_LOAD return "load"
    if op == OP_STORE return "store"
    if op == OP_ADD return "add"
    if op == OP_SUB return "sub"
    if op == OP_MUL return "mul"
    if op == OP_DIV return "div"
    if op == OP_MOD return "mod"
    if op == OP_NEG return "neg"
    if op == OP_SHL return "shl"
    if op == OP_SHR return "shr"
    if op == OP_AND return "and"
    if op == OP_OR return "or"
    if op == OP_XOR return "xor"
    if op == OP_CMP return "cmp"
    if op == OP_BR return "br"
    if op == OP_JMP return "jmp"
    if op == OP_RET return "ret"
    if op == OP_CALL return "call"
    if op == OP_PHI return "phi"
    return "unknown_op"

fn ssa_cmp_pred_name pred
    if pred == CMP_EQ return "eq"
    if pred == CMP_NE return "ne"
    if pred == CMP_SLT return "slt"
    if pred == CMP_SLE return "sle"
    if pred == CMP_SGT return "sgt"
    if pred == CMP_SGE return "sge"
    return "unknown_pred"

// ── 4. Opcode Classification Queries ──────────────────────────────────────────
// WHY: Optimization passes need instant categorization of instructions to guarantee
//      invariants without complex branching logic.

// Returns 1 if the opcode terminates a basic block, transferring control elsewhere
fn ssa_is_terminator op
    if op == OP_BR return 1
    if op == OP_JMP return 1
    if op == OP_RET return 1
    return 0

// Returns 1 if the opcode is a pure binary arithmetic operation
fn ssa_is_binary_arithmetic op
    if op == OP_ADD return 1
    if op == OP_SUB return 1
    if op == OP_MUL return 1
    if op == OP_DIV return 1
    if op == OP_MOD return 1
    return 0

// Returns 1 if the opcode is a bitwise logic or shift operation
fn ssa_is_bitwise op
    if op == OP_SHL return 1
    if op == OP_SHR return 1
    if op == OP_AND return 1
    if op == OP_OR return 1
    if op == OP_XOR return 1
    return 0

// Returns 1 if operands can be legally swapped without altering computation semantics
// WHY: Canonicalizing commutative operands (e.g. putting constants or lower-indexed IDs on rhs)
//      enables maximal hits in Common Subexpression Elimination (CSE).
fn ssa_is_commutative op
    if op == OP_ADD return 1
    if op == OP_MUL return 1
    if op == OP_AND return 1
    if op == OP_OR return 1
    if op == OP_XOR return 1
    return 0

// Returns 1 if instruction has observable side-effects and cannot be removed by DCE
// unless proven unreachable or dead by specialized memory/control-flow passes.
fn ssa_has_side_effects op
    if op == OP_STORE return 1
    if op == OP_CALL return 1
    if op == OP_RET return 1
    if op == OP_BR return 1
    if op == OP_JMP return 1
    return 0

// Returns 1 if the instruction defines an SSA output value register
fn ssa_produces_value op
    if op == OP_NOP return 0
    if op == OP_STORE return 0
    if op == OP_BR return 0
    if op == OP_JMP return 0
    return 1
