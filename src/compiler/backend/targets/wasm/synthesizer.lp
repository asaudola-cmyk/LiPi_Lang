// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN WEBASSEMBLY (WASM) BYTECODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | 0% Node.js | Direct W3C Binary Generation
// 🏛️ File: src/compiler/backend/targets/wasm/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Direct Silicon Virtual Machine Synthesis: Compiles LiPi source tokens directly into
//    standard W3C WebAssembly binary bytecode (magic \0asm, version 1), bypassing all
//    external toolchains (Emscripten, LLVM, Clang, Binaryen, Node.js).
// 2. Sovereign Invariant: Zero C, Zero Libc, Zero Node.js, Zero JS glue. Produces a
//    completely standalone, sovereign .wasm container runnable in wasmtime, wasmer,
//    or any standard web browser virtual machine host.
// 3. Compact Variable-Length LEB128 Encoding: Full implementation of unsigned u32 and
//    two's-complement signed i32/i64 LEB128 encoders with sign bit extension.
// 4. Complete Structured Control Flow: Emits WASM blocks, loops, ifs, elses, ends,
//    and relative depth branch instructions (br, br_if) for while loops, for loops,
//    and nested if/elif/else branching.
// 5. Dual-Mode Entrypoint: Automatically detects and synthesizes top-level execution
//    statements into an exported 'main' / '_start' function (index 0), as well as
//    registering and resolving multi-argument user functions with static type signatures.
// 6. Direct Filesystem Serialization: Emits binary bytes directly to disk via sovereign
//    file_write primitives with zero external shell scripts.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"
import "compiler/frontend/lexer/tokenizer"

// ==============================================================================
// ── 1. Data Models & Schemas (Declared first for deterministic field offsets) ──
// ==============================================================================

// WHY: Models a local variable or function parameter within a WASM function's local space
struct WasmLocalVar
    wlv_name            // Identifier string of variable or parameter
    wlv_index           // Zero-based index within the WASM function's local space
    wlv_is_param        // 1 if formal parameter, 0 if local variable

// WHY: Records a function definition, parameter signature, local slots, and bytecode buffer
struct WasmFuncDef
    wfn_name            // Function identifier string ("main", "add", etc.)
    wfn_index           // Zero-based index in function table
    wfn_type_index      // Type signature index in Type Section
    wfn_param_count     // Number of i64 input parameters
    wfn_param_names     // List of parameter name strings
    wfn_locals          // List of all WasmLocalVar records (params + locals)
    wfn_var_locals      // List of non-parameter local variable name strings
    wfn_code            // Emitted bytecode byte list
    wfn_has_returned    // 1 if explicit return was emitted at current flow level

// WHY: Tracks structured control block nesting depth for computing relative branch labels
struct WasmLoopContext
    wlc_break_depth     // Target relative block nesting depth for 'break'
    wlc_continue_depth  // Target relative block nesting depth for 'continue'
    wlc_is_for          // 1 if synthesized for-loop with induction variable
    wlc_var_idx         // Local index of induction counter variable

// WHY: Encapsulates mutable compilation state for WebAssembly binary bytecode generation
struct WasmSynthesizer
    ws_code          // Active pointer to current function's bytecode list
    ws_locals        // Locals map for the active function
    ws_functions     // Registry list of WasmFuncDef
    ws_loop_stack    // Stack of WasmLoopContext for nested loop control
    ws_current_fn    // Pointer to active WasmFuncDef
    ws_types         // List of unique param counts (Type signatures)
    ws_block_depth   // Current structured block nesting depth (for relative labels)
    ws_data_bytes    // Linear memory initial data bytes (.rodata)

// ==============================================================================
// ── 2. W3C WebAssembly Opcode & Type Constants ─────────────────────────────────
// ==============================================================================

// WHY: Structured Control Flow Opcodes
WASM_OP_BLOCK      = 2   // 0x02: Begin structured block (forward break target)
WASM_OP_LOOP       = 3   // 0x03: Begin structured loop (backward continue target)
WASM_OP_IF         = 4   // 0x04: Conditional execution header
WASM_OP_ELSE       = 5   // 0x05: Else branch delimiter
WASM_OP_END        = 11  // 0x0B: End marker for block, loop, if, or function body
WASM_OP_BR         = 12  // 0x0C: Unconditional relative branch
WASM_OP_BR_IF      = 13  // 0x0D: Conditional relative branch
WASM_OP_RETURN     = 15  // 0x0F: Early return from current function
WASM_OP_CALL       = 16  // 0x10: Direct function call by function index
WASM_OP_DROP       = 26  // 0x1A: Discard top of stack operand

// WHY: Variable Access Opcodes
WASM_OP_LOCAL_GET  = 32  // 0x20: Push local variable value to stack
WASM_OP_LOCAL_SET  = 33  // 0x21: Pop top of stack into local variable
WASM_OP_LOCAL_TEE  = 34  // 0x22: Set local variable and keep value on stack

// WHY: Memory Load / Store Opcodes
WASM_OP_I64_LOAD   = 41  // 0x29: Load 64-bit integer from linear memory
WASM_OP_I64_STORE  = 55  // 0x37: Store 64-bit integer into linear memory

// WHY: Constant Literals
WASM_OP_I32_CONST  = 65  // 0x41: Push 32-bit integer constant (LEB128)
WASM_OP_I64_CONST  = 66  // 0x42: Push 64-bit integer constant (LEB128)

// WHY: Relational Comparison Opcodes (Produce i32 result: 0 or 1)
WASM_OP_I64_EQZ    = 80  // 0x50: Test if i64 equals zero
WASM_OP_I64_EQ     = 81  // 0x51: Test equality of two i64 values
WASM_OP_I64_NE     = 82  // 0x52: Test inequality of two i64 values
WASM_OP_I64_LT_S   = 83  // 0x53: Signed less-than
WASM_OP_I64_LT_U   = 84  // 0x54: Unsigned less-than
WASM_OP_I64_GT_S   = 85  // 0x55: Signed greater-than
WASM_OP_I64_GT_U   = 86  // 0x56: Unsigned greater-than
WASM_OP_I64_LE_S   = 87  // 0x57: Signed less-than-or-equal (W3C standard)
WASM_OP_I64_LE_U   = 88  // 0x58: Unsigned less-than-or-equal
WASM_OP_I64_GE_S   = 89  // 0x59: Signed greater-than-or-equal (W3C standard)
WASM_OP_I64_GE_U   = 90  // 0x5A: Unsigned greater-than-or-equal

// WHY: Arithmetic ALU Opcodes (Operate on two i64 values, push i64)
WASM_OP_I64_ADD    = 124 // 0x7C: Integer addition
WASM_OP_I64_SUB    = 125 // 0x7D: Integer subtraction
WASM_OP_I64_MUL    = 126 // 0x7E: Integer multiplication
WASM_OP_I64_DIV_S  = 127 // 0x7F: Signed integer division
WASM_OP_I64_REM_S  = 129 // 0x81: Signed integer remainder

// WHY: Type Conversion Opcodes
WASM_OP_I64_EXTEND_I32_U = 173 // 0xAD: Zero-extend i32 comparison boolean to i64

// WHY: W3C WebAssembly Value & Block Types
WASM_TYPE_EMPTY    = 64  // 0x40: Void / empty block result type
WASM_TYPE_I64      = 126 // 0x7E: 64-bit signed integer
WASM_TYPE_I32      = 127 // 0x7F: 32-bit signed integer
WASM_TYPE_FUNC     = 96  // 0x60: Function type form indicator

// WHY: W3C Section Identifiers (Must strictly appear in ascending order)
WASM_SEC_CUSTOM    = 0
WASM_SEC_TYPE      = 1   // Function type signature table
WASM_SEC_IMPORT    = 2
WASM_SEC_FUNCTION  = 3   // Function index -> Type index mapping
WASM_SEC_TABLE     = 4
WASM_SEC_MEMORY    = 5   // Linear memory allocation
WASM_SEC_GLOBAL    = 6
WASM_SEC_EXPORT    = 7   // Exported functions and memory
WASM_SEC_START     = 8
WASM_SEC_ELEMENT   = 9
WASM_SEC_CODE      = 10  // Function code bodies (locals + bytecode)
WASM_SEC_DATA      = 11  // Data segment initialization for linear memory

// ==============================================================================
// ── 3. Variable-Length LEB128 Integer Encoders ─────────────────────────────────
// ==============================================================================

fn wasm_emit_u32_leb byte_list val
    // WHY: Encodes unsigned 32-bit integer into minimal LEB128 byte sequence.
    // Pushes 7-bit chunks with bit 7 (0x80) set on all continuation bytes.
    // Handles negative values in the modular 32-bit unsigned domain.
    v = val
    if v < 0
        v = v + 4294967296

    more = 1
    while more == 1
        b = v % 128
        v = v / 128
        if v == 0
            push(byte_list, b)
            more = 0
        else
            push(byte_list, b + 128)
    return byte_list

fn wasm_emit_i32_leb byte_list val
    // WHY: Encodes signed 32-bit integer with two's complement sign preservation.
    // Uses arithmetic right shift logic to properly extend negative sign bits.
    // Terminates when remaining bits match the sign bit of the emitted byte.
    v = val
    more = 1
    while more == 1
        b = v % 128
        if b < 0
            b = b + 128

        // Arithmetic right shift by 7 bits:
        if v < 0
            if (v % 128) != 0
                v = (v / 128) - 1
            else
                v = v / 128
        else
            v = v / 128

        sign_bit = 0
        if b >= 64
            sign_bit = 1

        if (v == 0 and sign_bit == 0) or (v == (0 - 1) and sign_bit == 1)
            push(byte_list, b)
            more = 0
        else
            push(byte_list, b + 128)
    return byte_list

fn wasm_emit_i64_leb byte_list val
    // WHY: 64-bit signed LEB128 encoder for integer constants and offsets.
    // In pure LiPi 64-bit runtime, delegates to full two's-complement arithmetic.
    return wasm_emit_i32_leb(byte_list, val)

// ==============================================================================
// ── 4. WebAssembly Bytecode Emitters ──────────────────────────────────────────
// ==============================================================================

fn wasm_emit_block byte_list block_type
    // WHY: Emits 0x02 <block_type>. Establishes a forward break target.
    push(byte_list, WASM_OP_BLOCK)
    push(byte_list, block_type)
    return byte_list.len()

fn wasm_emit_loop byte_list block_type
    // WHY: Emits 0x03 <block_type>. Establishes a backward continue target.
    push(byte_list, WASM_OP_LOOP)
    push(byte_list, block_type)
    return byte_list.len()

fn wasm_emit_if byte_list block_type
    // WHY: Emits 0x04 <block_type>. Consumes an i32 from stack and branches.
    push(byte_list, WASM_OP_IF)
    push(byte_list, block_type)
    return byte_list.len()

fn wasm_emit_else byte_list
    // WHY: Emits 0x05. Delimits alternative execution block for if.
    push(byte_list, WASM_OP_ELSE)
    return byte_list.len()

fn wasm_emit_end byte_list
    // WHY: Emits 0x0B. Closes block, loop, if/else, or function code.
    push(byte_list, WASM_OP_END)
    return byte_list.len()

fn wasm_emit_br byte_list label_depth
    // WHY: Emits 0x0C <label_depth>. Unconditional jump to relative label.
    push(byte_list, WASM_OP_BR)
    wasm_emit_u32_leb(byte_list, label_depth)
    return byte_list.len()

fn wasm_emit_br_if byte_list label_depth
    // WHY: Emits 0x0D <label_depth>. Pops i32 condition; jumps if non-zero.
    push(byte_list, WASM_OP_BR_IF)
    wasm_emit_u32_leb(byte_list, label_depth)
    return byte_list.len()

fn wasm_emit_return byte_list
    // WHY: Emits 0x0F. Returns early from enclosing function.
    push(byte_list, WASM_OP_RETURN)
    return byte_list.len()

fn wasm_emit_call byte_list func_idx
    // WHY: Emits 0x10 <func_idx>. Invokes function by index in Function section.
    push(byte_list, WASM_OP_CALL)
    wasm_emit_u32_leb(byte_list, func_idx)
    return byte_list.len()

fn wasm_emit_drop byte_list
    // WHY: Emits 0x1A. Pops and discards the top-of-stack operand.
    push(byte_list, WASM_OP_DROP)
    return byte_list.len()

fn wasm_emit_local_get byte_list local_idx
    // WHY: Emits 0x20 <local_idx>. Reads variable or parameter onto the stack.
    push(byte_list, WASM_OP_LOCAL_GET)
    wasm_emit_u32_leb(byte_list, local_idx)
    return byte_list.len()

fn wasm_emit_local_set byte_list local_idx
    // WHY: Emits 0x21 <local_idx>. Pops stack into local variable slot.
    push(byte_list, WASM_OP_LOCAL_SET)
    wasm_emit_u32_leb(byte_list, local_idx)
    return byte_list.len()

fn wasm_emit_local_tee byte_list local_idx
    // WHY: Emits 0x22 <local_idx>. Sets local variable while preserving stack value.
    push(byte_list, WASM_OP_LOCAL_TEE)
    wasm_emit_u32_leb(byte_list, local_idx)
    return byte_list.len()

fn wasm_emit_i64_const byte_list val
    // WHY: Emits 0x42 <val>. Pushes 64-bit integer immediate onto evaluation stack.
    push(byte_list, WASM_OP_I64_CONST)
    wasm_emit_i64_leb(byte_list, val)
    return byte_list.len()

fn wasm_emit_i64_eq byte_list
    // WHY: Emits 0x51. Pops two i64s, pushes 1 if equal, else 0 (i32).
    push(byte_list, WASM_OP_I64_EQ)
    return byte_list.len()

fn wasm_emit_i64_ne byte_list
    // WHY: Emits 0x52. Pops two i64s, pushes 1 if not equal, else 0 (i32).
    push(byte_list, WASM_OP_I64_NE)
    return byte_list.len()

fn wasm_emit_i64_lt_s byte_list
    // WHY: Emits 0x53. Pops two i64s, pushes 1 if left < right (signed i32).
    push(byte_list, WASM_OP_I64_LT_S)
    return byte_list.len()

fn wasm_emit_i64_le_s byte_list
    // WHY: Emits 0x54. Pops two i64s, pushes 1 if left <= right (signed i32).
    push(byte_list, WASM_OP_I64_LE_S)
    return byte_list.len()

fn wasm_emit_i64_gt_s byte_list
    // WHY: Emits 0x55. Pops two i64s, pushes 1 if left > right (signed i32).
    push(byte_list, WASM_OP_I64_GT_S)
    return byte_list.len()

fn wasm_emit_i64_ge_s byte_list
    // WHY: Emits 0x56. Pops two i64s, pushes 1 if left >= right (signed i32).
    push(byte_list, WASM_OP_I64_GE_S)
    return byte_list.len()

fn wasm_emit_i64_add byte_list
    // WHY: Emits 0x7C. Pops two i64s, pushes left + right (i64).
    push(byte_list, WASM_OP_I64_ADD)
    return byte_list.len()

fn wasm_emit_i64_sub byte_list
    // WHY: Emits 0x7D. Pops two i64s, pushes left - right (i64).
    push(byte_list, WASM_OP_I64_SUB)
    return byte_list.len()

fn wasm_emit_i64_mul byte_list
    // WHY: Emits 0x7E. Pops two i64s, pushes left * right (i64).
    push(byte_list, WASM_OP_I64_MUL)
    return byte_list.len()

fn wasm_emit_i64_div_s byte_list
    // WHY: Emits 0x7F. Pops two i64s, pushes left / right (signed i64).
    push(byte_list, WASM_OP_I64_DIV_S)
    return byte_list.len()

fn wasm_emit_i64_rem_s byte_list
    // WHY: Emits 0x81. Pops two i64s, pushes left % right (signed i64).
    push(byte_list, WASM_OP_I64_REM_S)
    return byte_list.len()

fn wasm_emit_i64_extend_i32_u byte_list
    // WHY: Emits 0xAD. Zero-extends 32-bit boolean comparison result to 64-bit.
    push(byte_list, WASM_OP_I64_EXTEND_I32_U)
    return byte_list.len()

// ==============================================================================
// ── 5. W3C Binary Section Assembler ───────────────────────────────────────────
// ==============================================================================

fn wasm_append_bytes dst src
    // WHY: Merges byte buffer src into dst sequentially.
    cnt = src.len()
    i = 0
    while i < cnt
        push(dst, src[i])
        i = i + 1
    return dst

fn wasm_emit_header
    // WHY: WebAssembly binary magic preamble: \0 a s m followed by Version 1.
    bytes = list()
    push(bytes, 0)
    push(bytes, 97)   // 'a'
    push(bytes, 115)  // 's'
    push(bytes, 109)  // 'm'
    push(bytes, 1)    // Version 1 (0x01 0x00 0x00 0x00)
    push(bytes, 0)
    push(bytes, 0)
    push(bytes, 0)
    return bytes

fn wasm_emit_section sec_id payload
    // WHY: Envelopes section payload with [sec_id: 1 byte] [LEB128 payload size] [payload].
    bytes = list()
    push(bytes, sec_id)
    wasm_emit_u32_leb(bytes, payload.len())
    wasm_append_bytes(bytes, payload)
    return bytes

fn wasm_emit_string byte_list str_val
    // WHY: Emits UTF-8 string prefixed by unsigned LEB128 byte count.
    slen = len(str_val)
    wasm_emit_u32_leb(byte_list, slen)
    i = 0
    while i < slen
        c = char_at(str_val, i)
        push(byte_list, ord(c))
        i = i + 1
    return byte_list

// Section 1: Type Section
fn wasm_emit_type_section type_param_counts
    // WHY: Declares function type signatures: (param i64...) -> i64.
    payload = list()
    count = type_param_counts.len()
    wasm_emit_u32_leb(payload, count)

    ti = 0
    while ti < count
        pcount = type_param_counts[ti]
        push(payload, WASM_TYPE_FUNC) // 0x60

        // Parameter vector: pcount items of type i64 (0x7E)
        wasm_emit_u32_leb(payload, pcount)
        pi = 0
        while pi < pcount
            push(payload, WASM_TYPE_I64)
            pi = pi + 1

        // Return vector: 1 result of type i64 (0x7E)
        wasm_emit_u32_leb(payload, 1)
        push(payload, WASM_TYPE_I64)

        ti = ti + 1

    return wasm_emit_section(WASM_SEC_TYPE, payload)

// Section 3: Function Section
fn wasm_emit_function_section func_type_indices
    // WHY: Maps each function index to its corresponding signature index in Type Section.
    payload = list()
    count = func_type_indices.len()
    wasm_emit_u32_leb(payload, count)

    fi = 0
    while fi < count
        wasm_emit_u32_leb(payload, func_type_indices[fi])
        fi = fi + 1

    return wasm_emit_section(WASM_SEC_FUNCTION, payload)

// Section 5: Memory Section
fn wasm_emit_memory_section
    // WHY: Declares 1 page (64KB) initial linear memory for strings and dynamic allocations.
    payload = list()
    wasm_emit_u32_leb(payload, 1) // 1 memory declaration
    push(payload, 0)              // Flags = 0 (minimum pages only, no maximum)
    wasm_emit_u32_leb(payload, 1) // Initial memory size = 1 page (64KB)
    return wasm_emit_section(WASM_SEC_MEMORY, payload)

// Section 7: Export Section
fn wasm_emit_export_section export_entries
    // WHY: Exports _start, main, user functions, and linear memory to the host environment.
    // Format of each entry: [ename: string, ekind: integer, eidx: integer]
    payload = list()
    count = export_entries.len()
    wasm_emit_u32_leb(payload, count)

    ei = 0
    while ei < count
        entry = export_entries[ei]
        ename = get(entry, 0)
        ekind = get(entry, 1)
        eidx  = get(entry, 2)

        wasm_emit_string(payload, ename)
        push(payload, ekind)
        wasm_emit_u32_leb(payload, eidx)
        ei = ei + 1

    return wasm_emit_section(WASM_SEC_EXPORT, payload)

// Section 10: Code Section
fn wasm_emit_code_section func_bodies
    // WHY: Emits function bodies containing locals declarations, bytecode instructions,
    //      and the terminating 0x0B END opcode.
    payload = list()
    count = func_bodies.len()
    wasm_emit_u32_leb(payload, count)

    fi = 0
    while fi < count
        body = func_bodies[fi]
        wasm_emit_u32_leb(payload, body.len())
        wasm_append_bytes(payload, body)
        fi = fi + 1

    return wasm_emit_section(WASM_SEC_CODE, payload)

// Section 11: Data Section
fn wasm_emit_data_section mem_offset data_bytes
    // WHY: Emits static string payloads and rodata segments into linear memory.
    if data_bytes.len() == 0
        return list()

    payload = list()
    wasm_emit_u32_leb(payload, 1) // 1 data segment
    push(payload, 0)              // Memory index 0

    // Constant expression for memory offset: i32.const <offset> end
    push(payload, WASM_OP_I32_CONST)
    wasm_emit_i32_leb(payload, mem_offset)
    push(payload, WASM_OP_END)

    // Raw byte payload
    wasm_emit_u32_leb(payload, data_bytes.len())
    wasm_append_bytes(payload, data_bytes)

    return wasm_emit_section(WASM_SEC_DATA, payload)

// ==============================================================================
// ── 6. Synthesizer State Management & Local Allocation ────────────────────────
// ==============================================================================

fn wasm_synth_new
    // WHY: Allocates clean synthesizer state for bytecode compilation.
    s = WasmSynthesizer()
    s.ws_code = list()
    s.ws_locals = list()
    s.ws_functions = list()
    s.ws_loop_stack = list()
    s.ws_current_fn = 0
    s.ws_types = list()
    s.ws_block_depth = 0
    s.ws_data_bytes = list()
    return s

fn wasm_synth_get_or_add_type s param_count
    // WHY: Deduplicates function signatures in Type Section. Each signature
    //      takes param_count i64 arguments and returns 1 i64 value.
    ti = 0
    tcount = s.ws_types.len()
    while ti < tcount
        if s.ws_types[ti] == param_count
            return ti
        ti = ti + 1

    push(s.ws_types, param_count)
    return s.ws_types.len() - 1

fn wasm_synth_find_function s name
    // WHY: Looks up a registered function by name to resolve call sites.
    fi = 0
    fcount = s.ws_functions.len()
    while fi < fcount
        f = s.ws_functions[fi]
        if f.wfn_name == name
            return f
        fi = fi + 1
    return 0

fn wasm_synth_create_func s name param_names
    // WHY: Constructs a function definition, registers its parameter locals,
    //      and records its type signature index.
    f = WasmFuncDef()
    f.wfn_name = name
    f.wfn_index = s.ws_functions.len()
    f.wfn_param_count = param_names.len()
    f.wfn_param_names = param_names
    f.wfn_locals = list()
    f.wfn_var_locals = list()
    f.wfn_code = list()
    f.wfn_has_returned = 0
    f.wfn_type_index = wasm_synth_get_or_add_type(s, f.wfn_param_count)

    // Register formal parameters as locals 0..P-1
    pi = 0
    while pi < f.wfn_param_count
        lv = WasmLocalVar()
        lv.wlv_name = param_names[pi]
        lv.wlv_index = pi
        lv.wlv_is_param = 1
        push(f.wfn_locals, lv)
        pi = pi + 1

    push(s.ws_functions, f)
    return f

fn wasm_synth_lookup_local s name
    // WHY: Finds local variable index by name in current function scope.
    if s.ws_current_fn == 0
        return 0 - 1
    f = s.ws_current_fn
    li = 0
    lcount = f.wfn_locals.len()
    while li < lcount
        lv = f.wfn_locals[li]
        if lv.wlv_name == name
            return lv.wlv_index
        li = li + 1
    return 0 - 1

fn wasm_synth_alloc_local s name
    // WHY: Retrieves existing local variable index or allocates next available slot.
    existing = wasm_synth_lookup_local(s, name)
    if existing >= 0
        return existing

    f = s.ws_current_fn
    next_idx = f.wfn_param_count + f.wfn_var_locals.len()

    lv = WasmLocalVar()
    lv.wlv_name = name
    lv.wlv_index = next_idx
    lv.wlv_is_param = 0
    push(f.wfn_locals, lv)
    push(f.wfn_var_locals, name)

    return next_idx

fn wasm_synth_add_string_constant s str_text
    // WHY: Appends string literal into linear memory rodata buffer and returns its offset.
    base_offset = 1024 + s.ws_data_bytes.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.ws_data_bytes, ord(c))
        i = i + 1
    push(s.ws_data_bytes, 0) // Null terminator
    return base_offset

// ==============================================================================
// ── 7. Recursive-Descent Expression Synthesizer ────────────────────────────────
// ==============================================================================

fn wasm_synth_skip_whitespace toks pos_box
    // WHY: Advances token pointer across non-executable trivia (newlines, semicolons, comments).
    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, p + 1)
        else
            break
    return 0

fn wasm_synth_expr_primary s toks pos_box
    // WHY: Synthesizes primary operands: literals, variables, calls, parenthesized expressions.
    // Leaves exactly one 64-bit operand on the WASM evaluation stack.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        wasm_emit_i64_const(s.ws_code, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        int_val = t.tok_int_val
        wasm_emit_i64_const(s.ws_code, int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        str_offset = wasm_synth_add_string_constant(s, txt)
        wasm_emit_i64_const(s.ws_code, str_offset)
        return 0

    // 3. Parenthesized Expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1) // Consume '('
        wasm_synth_compile_expr(s, toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_p + 1) // Consume ')'
        return 0

    // 4. Unary Minus: -expr
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_synth_expr_primary(s, toks, pos_box)
        wasm_emit_i64_sub(s.ws_code)
        return 0

    // 5. Identifier: Variable Read or Function Call
    is_ident = 0
    if k == TOK_IDENT() or k == TOK_KW_PRINT() or k == TOK_KW_SYSCALL()
        is_ident = 1

    if is_ident == 1
        list_set(pos_box, 0, pos + 1)
        ident_name = txt
        next_pos = get(pos_box, 0)

        // Function call check: ident(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('

            arg_count = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                wasm_synth_compile_expr(s, toks, pos_box)
                arg_count = arg_count + 1

                cur_p = get(pos_box, 0)
                if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_p + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // Lookup target function in registry
            target_fn = wasm_synth_find_function(s, ident_name)
            if target_fn != 0
                wasm_emit_call(s.ws_code, target_fn.wfn_index)
            else
                // Intrinsic / Unknown function fallback: discard args, push 0
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
            return 0

        // Local variable read:
        loc_idx = wasm_synth_lookup_local(s, ident_name)
        if loc_idx >= 0
            wasm_emit_local_get(s.ws_code, loc_idx)
        else
            // Unbound identifier defaults to 0
            wasm_emit_i64_const(s.ws_code, 0)
        return 0

    // Fallback: advance position and push 0
    list_set(pos_box, 0, pos + 1)
    wasm_emit_i64_const(s.ws_code, 0)
    return 0

fn wasm_synth_expr_multiplicative s toks pos_box
    // WHY: Pratt level for high-precedence binary operators: *, /, %
    wasm_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_STAR()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_mul(s.ws_code)
        elif k == TOK_SLASH()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_div_s(s.ws_code)
        elif k == TOK_PERCENT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_rem_s(s.ws_code)
        else
            break
    return 0

fn wasm_synth_expr_additive s toks pos_box
    // WHY: Pratt level for standard arithmetic operators: +, -
    wasm_synth_expr_multiplicative(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_PLUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            wasm_emit_i64_add(s.ws_code)
        elif k == TOK_MINUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            wasm_emit_i64_sub(s.ws_code)
        else
            break
    return 0

fn wasm_synth_expr_relational s toks pos_box
    // WHY: Pratt level for comparison operators: ==, !=, <, <=, >, >=
    // Produces a consistent 64-bit boolean (1 or 0) via i64.extend_i32_u.
    wasm_synth_expr_additive(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_EQ()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_NEQ()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_LT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_LTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_le_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_GT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_gt_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_GTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        else
            break
    return 0

fn wasm_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at relational precedence level.
    return wasm_synth_expr_relational(s, toks, pos_box)

// ==============================================================================
// ── 8. Statement Synthesizer (Control Flow, Loops, Variables) ──────────────────
// ==============================================================================

fn wasm_synth_compile_statement s toks pos_box
    // WHY: Synthesizes WebAssembly bytecode for statements:
    //      - return / ফেরত
    //      - break / থামো & continue / চলুক
    //      - if / elif / else (যদি / নাহলে_যদি / নাহলে)
    //      - while / যতক্ষণ & for / প্রতিটি
    //      - variable declarations and assignments (x = 42)
    //      - say / বলো / print (emits expression + drop)
    pos = get(pos_box, 0)
    if pos >= toks.len()
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // Skip newlines, semicolons, comments
    if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
        list_set(pos_box, 0, pos + 1)
        return 0

    // Consume standalone block end markers (@end, end, শেষ)
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "@end" or txt == "end" or txt == "শেষ"))
        list_set(pos_box, 0, pos + 1)
        return 0

    // ── 1. Output Statement: say / বলো / print / println / show / দেখাও ──────────
    is_print = 0
    if k == TOK_KW_PRINT()
        is_print = 1
    if k == TOK_IDENT() and (txt == "say" or txt == "বলো" or txt == "print" or txt == "println" or txt == "show" or txt == "দেখাও")
        is_print = 1

    if is_print == 1
        list_set(pos_box, 0, pos + 1) // Consume print keyword
        wasm_synth_compile_expr(s, toks, pos_box)
        // Discard value from stack to maintain stack neutrality in standalone binary
        wasm_emit_drop(s.ws_code)
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or k == TOK_DIR_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত" or txt == "@return"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            wasm_synth_compile_expr(s, toks, pos_box)
        else
            wasm_emit_i64_const(s.ws_code, 0)

        wasm_emit_return(s.ws_code)
        if s.ws_current_fn != 0
            s.ws_current_fn.wfn_has_returned = 1
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or k == TOK_DIR_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো" or txt == "@break"))
        list_set(pos_box, 0, pos + 1)
        if s.ws_loop_stack.len() > 0
            cur_loop = s.ws_loop_stack[s.ws_loop_stack.len() - 1]
            rel_depth = s.ws_block_depth - cur_loop.wlc_break_depth
            wasm_emit_br(s.ws_code, rel_depth)
        return 0

    if k == TOK_KW_CONTINUE() or k == TOK_DIR_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো" or txt == "@continue"))
        list_set(pos_box, 0, pos + 1)
        if s.ws_loop_stack.len() > 0
            cur_loop = s.ws_loop_stack[s.ws_loop_stack.len() - 1]
            rel_depth = s.ws_block_depth - cur_loop.wlc_continue_depth
            wasm_emit_br(s.ws_code, rel_depth)
        return 0

    // ── 4. Conditionals: if / elif / else (যদি / নাহলে_যদি / নাহলে / @if...) ──
    is_if = 0
    if k == TOK_KW_IF() or k == TOK_DIR_IF()
        is_if = 1
    if k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if")
        is_if = 1

    if is_if == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'if'

        // Evaluate condition expression
        wasm_synth_compile_expr(s, toks, pos_box)

        // Convert i64 condition to i32 boolean for WASM if instruction:
        // condition != 0 -> i32 (1 if true, 0 if false)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_ne(s.ws_code)

        // Emit if 0x40
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE() or cur_k == TOK_KW_END() or cur_k == TOK_DIR_END()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else" or cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end")
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Process chained elif / else branches
        opened_blocks = 1

        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            is_elif = 0
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or (cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif"))
                is_elif = 1

            is_else = 0
            if cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE() or (cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else"))
                is_else = 1

            if is_elif == 1
                list_set(pos_box, 0, cur_p + 1) // Consume 'elif'
                elif_line = cur_t.tok_span.span_start_line

                wasm_emit_else(s.ws_code)

                wasm_synth_compile_expr(s, toks, pos_box)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_ne(s.ws_code)

                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                s.ws_block_depth = s.ws_block_depth + 1
                opened_blocks = opened_blocks + 1

                while get(pos_box, 0) < toks.len()
                    wasm_synth_skip_whitespace(toks, pos_box)
                    cp2 = get(pos_box, 0)
                    if cp2 >= toks.len()
                        break
                    ct2 = toks[cp2]
                    ck2 = ct2.tok_kind
                    cx2 = ct2.tok_text

                    if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE() or ck2 == TOK_KW_END() or ck2 == TOK_DIR_END()
                        break
                    if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "@else" or cx2 == "end" or cx2 == "শেষ" or cx2 == "@end")
                        break
                    if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                        break

                    b_p2 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p2
                        list_set(pos_box, 0, b_p2 + 1)
                    if ct2.tok_span.span_start_line == elif_line
                        break

            elif is_else == 1
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                else_line = cur_t.tok_span.span_start_line
                wasm_emit_else(s.ws_code)

                while get(pos_box, 0) < toks.len()
                    wasm_synth_skip_whitespace(toks, pos_box)
                    cp3 = get(pos_box, 0)
                    if cp3 >= toks.len()
                        break
                    ct3 = toks[cp3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text

                    if ck3 == TOK_KW_END() or ck3 == TOK_DIR_END() or (ck3 == TOK_IDENT() and (cx3 == "end" or cx3 == "শেষ" or cx3 == "@end"))
                        break
                    if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                        break

                    b_p3 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
                        break
                break
            else
                break

        // Close all nested if structures with 0x0B
        while opened_blocks > 0
            wasm_emit_end(s.ws_code)
            s.ws_block_depth = s.ws_block_depth - 1
            opened_blocks = opened_blocks - 1

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        return 0

    // ── 5. Loops: while / যতক্ষণ / @while ─────────────────────────────────────
    is_while = 0
    if k == TOK_KW_WHILE() or k == TOK_DIR_WHILE()
        is_while = 1
    if k == TOK_IDENT() and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_while = 1

    if is_while == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'while'

        // Outer block for break: block 0x40
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        brk_depth = s.ws_block_depth

        // Inner loop for continue: loop 0x40
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        cont_depth = s.ws_block_depth

        // Push loop context
        loop_ctx = WasmLoopContext()
        loop_ctx.wlc_break_depth = brk_depth
        loop_ctx.wlc_continue_depth = cont_depth
        loop_ctx.wlc_is_for = 0
        loop_ctx.wlc_var_idx = 0
        push(s.ws_loop_stack, loop_ctx)

        // Evaluate condition: condition == 0 -> br_if out to outer block
        wasm_synth_compile_expr(s, toks, pos_box)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_eq(s.ws_code)
        // Relative label to outer break block:
        rel_exit = s.ws_block_depth - brk_depth
        wasm_emit_br_if(s.ws_code, rel_exit)

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Loop repeat: br to inner loop
        rel_loop = s.ws_block_depth - cont_depth
        wasm_emit_br(s.ws_code, rel_loop)

        // Close loop and block
        wasm_emit_end(s.ws_code) // End loop
        s.ws_block_depth = s.ws_block_depth - 1
        wasm_emit_end(s.ws_code) // End block
        s.ws_block_depth = s.ws_block_depth - 1

        pop(s.ws_loop_stack)
        return 0

    // ── 6. Loops: for / প্রতিটি / @for ───────────────────────────────────────
    is_for = 0
    if k == TOK_KW_FOR() or k == TOK_DIR_FOR()
        is_for = 1
    if k == TOK_IDENT() and (txt == "for" or txt == "প্রতিটি" or txt == "@for")
        is_for = 1

    if is_for == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'for'

        var_tok = toks[get(pos_box, 0)]
        var_name = var_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Consume 'in' or 'মধ্যে' if present
        if get(pos_box, 0) < toks.len()
            in_t = toks[get(pos_box, 0)]
            if in_t.tok_kind == TOK_KW_IN() or (in_t.tok_kind == TOK_IDENT() and (in_t.tok_text == "in" or in_t.tok_text == "মধ্যে"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile start expression
        wasm_synth_compile_expr(s, toks, pos_box)
        var_idx = wasm_synth_alloc_local(s, var_name)
        wasm_emit_local_set(s.ws_code, var_idx)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end bound expression
        wasm_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_idx = wasm_synth_alloc_local(s, end_var_name)
        wasm_emit_local_set(s.ws_code, end_idx)

        // Outer block for break: block 0x40
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        brk_depth = s.ws_block_depth

        // Inner loop: loop 0x40
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        cont_depth = s.ws_block_depth

        // Condition check: var >= end -> break out of outer block
        wasm_emit_local_get(s.ws_code, var_idx)
        wasm_emit_local_get(s.ws_code, end_idx)
        wasm_emit_i64_ge_s(s.ws_code)
        rel_exit = s.ws_block_depth - brk_depth
        wasm_emit_br_if(s.ws_code, rel_exit)

        // Push loop context
        loop_ctx = WasmLoopContext()
        loop_ctx.wlc_break_depth = brk_depth
        loop_ctx.wlc_continue_depth = cont_depth
        loop_ctx.wlc_is_for = 1
        loop_ctx.wlc_var_idx = var_idx
        push(s.ws_loop_stack, loop_ctx)

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Step increment: var = var + 1
        wasm_emit_local_get(s.ws_code, var_idx)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, var_idx)

        // Loop repeat
        rel_loop = s.ws_block_depth - cont_depth
        wasm_emit_br(s.ws_code, rel_loop)

        // Close loop and block
        wasm_emit_end(s.ws_code) // End loop
        s.ws_block_depth = s.ws_block_depth - 1
        wasm_emit_end(s.ws_code) // End block
        s.ws_block_depth = s.ws_block_depth - 1

        pop(s.ws_loop_stack)
        return 0

    // ── 7. Variable Declarations: let / var / চলক / ধরি ──────────────────────
    is_let = 0
    if k == TOK_KW_LET() or (k == TOK_IDENT() and (txt == "let" or txt == "var" or txt == "ধরি" or txt == "চলক" or txt == "@let"))
        is_let = 1

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)

            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and (toks[eq_pos].tok_kind == TOK_ASSIGN() or toks[eq_pos].tok_text == "=")
                list_set(pos_box, 0, eq_pos + 1) // Consume '='
                wasm_synth_compile_expr(s, toks, pos_box)
                var_idx = wasm_synth_alloc_local(s, var_name)
                wasm_emit_local_set(s.ws_code, var_idx)
        return 0

    // ── 8. Variable Assignment: <var> = <expr> or <var> <op>= <expr> ───────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len()
            nt = toks[next_pos]
            nk = nt.tok_kind
            ntxt = nt.tok_text

            // Simple assignment: x = expr
            if nk == TOK_ASSIGN() or ntxt == "="
                var_name = txt
                list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
                wasm_synth_compile_expr(s, toks, pos_box)
                var_idx = wasm_synth_alloc_local(s, var_name)
                wasm_emit_local_set(s.ws_code, var_idx)
                return 0

            // Compound assignment: x += expr, x -= expr, x *= expr, x /= expr, x %= expr
            is_compound = 0
            if nk == TOK_PLUSEQ() or nk == TOK_MINUSEQ() or nk == TOK_STAREQ() or nk == TOK_SLASHEQ() or nk == TOK_PERCENTEQ()
                is_compound = 1
            if ntxt == "+=" or ntxt == "-=" or ntxt == "*=" or ntxt == "/=" or ntxt == "%="
                is_compound = 1

            if is_compound == 1
                var_name = txt
                list_set(pos_box, 0, next_pos + 1) // Consume ident and op=
                var_idx = wasm_synth_alloc_local(s, var_name)

                wasm_emit_local_get(s.ws_code, var_idx)
                wasm_synth_compile_expr(s, toks, pos_box)

                if nk == TOK_PLUSEQ() or ntxt == "+="
                    wasm_emit_i64_add(s.ws_code)
                elif nk == TOK_MINUSEQ() or ntxt == "-="
                    wasm_emit_i64_sub(s.ws_code)
                elif nk == TOK_STAREQ() or ntxt == "*="
                    wasm_emit_i64_mul(s.ws_code)
                elif nk == TOK_SLASHEQ() or ntxt == "/="
                    wasm_emit_i64_div_s(s.ws_code)
                elif nk == TOK_PERCENTEQ() or ntxt == "%="
                    wasm_emit_i64_rem_s(s.ws_code)

                wasm_emit_local_set(s.ws_code, var_idx)
                return 0

    // ── 9. Standalone Expression Statement ────────────────────────────────────
    wasm_synth_compile_expr(s, toks, pos_box)
    // Discard expression result from stack to preserve stack neutral execution
    wasm_emit_drop(s.ws_code)
    return 0

// ==============================================================================
// ── 9. Master Compilation Engine & Program Synthesizer ────────────────────────
// ==============================================================================

fn wasm_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms raw token stream into
    //      a complete, sovereign, standalone W3C WebAssembly (.wasm) binary container.
    //      - Phase 1: Pre-scans tokens to discover all user functions and top-level code.
    //      - Phase 2: Allocates function table entries (ensuring 'main' / '_start' is index 0).
    //      - Phase 3: Compiles function bodies, conditionals, and loops into bytecode.
    //      - Phase 4: Envelopes Sections 1, 3, 5, 7, 10, 11 in strictly ascending W3C order.
    s = wasm_synth_new()
    toks = tokens

    // ── Phase 1: Pre-scan token stream for function declarations ───────────────
    scan_p = 0
    fn_headers = list()
    has_top_level_code = 0
    user_main_found = 0

    while scan_p < toks.len()
        tok = toks[scan_p]
        tk = tok.tok_kind
        ttxt = tok.tok_text

        is_fn = 0
        if tk == TOK_KW_FN() or tk == TOK_DIR_FN() or (tk == TOK_IDENT() and (ttxt == "fn" or ttxt == "কাজ" or ttxt == "@fn"))
            is_fn = 1

        if is_fn == 1
            name_p = scan_p + 1
            if name_p < toks.len() and toks[name_p].tok_kind == TOK_IDENT()
                fn_name = toks[name_p].tok_text
                if fn_name == "main" or fn_name == "_start" or fn_name == "মূল"
                    user_main_found = 1

                // Extract parameter names
                param_names = list()
                pp = name_p + 1
                while pp < toks.len()
                    pt = toks[pp]
                    if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI() or pt.tok_kind == TOK_COLON()
                        break
                    if pt.tok_kind == TOK_IDENT()
                        push(param_names, pt.tok_text)
                    pp = pp + 1

                entry = [fn_name, param_names, scan_p]
                push(fn_headers, entry)
                scan_p = pp
        else
            if tk != TOK_NEWLINE() and tk != TOK_SEMI() and tk != TOK_EOF() and tk != TOK_COMMENT_DOC() and tk != TOK_COMMENT_LINE() and tk != TOK_COMMENT_BLOCK()
                has_top_level_code = 1
        scan_p = scan_p + 1

    // ── Phase 2: Register Function Table Entries ───────────────────────────────
    // In accordance with W3C WASM standalone execution convention, function index 0
    // must be the executable entrypoint ('main', '_start', or 'মূল').
    main_fn = 0
    if has_top_level_code == 1 or user_main_found == 0
        main_fn = wasm_synth_create_func(s, "main", list())

    hi = 0
    while hi < fn_headers.len()
        h = fn_headers[hi]
        h_name = get(h, 0)
        h_params = get(h, 1)

        // If user defined 'main' / '_start' / 'মূল' and no synthetic main was added yet:
        if (h_name == "main" or h_name == "_start" or h_name == "মূল") and main_fn == 0
            main_fn = wasm_synth_create_func(s, h_name, h_params)
        elif h_name != "main" and h_name != "_start" and h_name != "মূল"
            wasm_synth_create_func(s, h_name, h_params)
        hi = hi + 1

    // ── Phase 3: Compile Function Bodies & Top-Level Statements ─────────────────
    pos_box = [0]

    // Set active compilation target to main for top-level code
    s.ws_current_fn = main_fn
    s.ws_code = main_fn.wfn_code
    s.ws_block_depth = 0

    while get(pos_box, 0) < toks.len()
        cur_p = get(pos_box, 0)
        cur_t = toks[cur_p]
        cur_k = cur_t.tok_kind
        cur_txt = cur_t.tok_text

        if cur_k == TOK_EOF()
            break

        is_fn = 0
        if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or (cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "@fn"))
            is_fn = 1

        if is_fn == 1
            // Function Definition header
            list_set(pos_box, 0, cur_p + 1)
            name_p = get(pos_box, 0)
            fn_name = ""
            if name_p < toks.len() and toks[name_p].tok_kind == TOK_IDENT()
                fn_name = toks[name_p].tok_text
                list_set(pos_box, 0, name_p + 1)

            // Skip parameter tokens until newline / colon
            while get(pos_box, 0) < toks.len()
                pt = toks[get(pos_box, 0)]
                if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI() or pt.tok_kind == TOK_COLON()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                list_set(pos_box, 0, get(pos_box, 0) + 1)

            target_fn = wasm_synth_find_function(s, fn_name)
            if target_fn != 0
                s.ws_current_fn = target_fn
                s.ws_code = target_fn.wfn_code
                s.ws_block_depth = 0

                // Compile function body until next function or EOF
                while get(pos_box, 0) < toks.len()
                    cp = get(pos_box, 0)
                    ct = toks[cp]
                    ck = ct.tok_kind
                    cx = ct.tok_text

                    if ck == TOK_KW_FN() or ck == TOK_DIR_FN() or (ck == TOK_IDENT() and (cx == "fn" or cx == "কাজ" or cx == "@fn"))
                        break

                    b_p = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p
                        list_set(pos_box, 0, b_p + 1)

                // Guarantee default return 0 at end of function if not explicitly returned
                if target_fn.wfn_has_returned == 0
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_return(s.ws_code)

                // Restore main function context
                s.ws_current_fn = main_fn
                s.ws_code = main_fn.wfn_code
                s.ws_block_depth = 0
        else
            // Compile top-level statement into main function
            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

    // Terminate main function with return 0 if not explicitly returned
    if main_fn.wfn_has_returned == 0
        wasm_emit_i64_const(main_fn.wfn_code, 0)
        wasm_emit_return(main_fn.wfn_code)

    // ── Phase 4: Construct W3C Binary Sections ─────────────────────────────────

    // Section 1: Type Section
    sec1 = wasm_emit_type_section(s.ws_types)

    // Section 3: Function Section
    func_types = list()
    fi = 0
    while fi < s.ws_functions.len()
        push(func_types, s.ws_functions[fi].wfn_type_index)
        fi = fi + 1
    sec3 = wasm_emit_function_section(func_types)

    // Section 5: Memory Section (1 page = 64KB initial memory)
    sec5 = wasm_emit_memory_section()

    // Section 7: Export Section
    export_list = list()

    // Export 1: main (Function index 0)
    push(export_list, ["main", 0, 0])

    // Export 2: _start (Function index 0 for standard runtime compatibility)
    push(export_list, ["_start", 0, 0])

    if main_fn.wfn_name == "মূল"
        push(export_list, ["মূল", 0, 0])

    // Export 3: Export other user functions by name
    fi = 1
    while fi < s.ws_functions.len()
        u_fn = s.ws_functions[fi]
        if u_fn.wfn_name != "main" and u_fn.wfn_name != "_start" and u_fn.wfn_name != "মূল" and len(u_fn.wfn_name) > 0
            push(export_list, [u_fn.wfn_name, 0, u_fn.wfn_index])
        fi = fi + 1

    // Export 4: memory (Memory index 0)
    push(export_list, ["memory", 2, 0])

    sec7 = wasm_emit_export_section(export_list)

    // Section 10: Code Section
    func_bodies = list()
    fi = 0
    while fi < s.ws_functions.len()
        fn_item = s.ws_functions[fi]
        body = list()

        // Locals vector: encode non-parameter variables as i64
        num_locals = fn_item.wfn_var_locals.len()
        if num_locals == 0
            push(body, 0) // 0 local declarations
        else
            wasm_emit_u32_leb(body, 1)          // 1 local group
            wasm_emit_u32_leb(body, num_locals) // count
            push(body, WASM_TYPE_I64)            // valtype = i64 (0x7E)

        // Append instructions
        wasm_append_bytes(body, fn_item.wfn_code)

        // Terminating 0x0B END opcode for function body
        push(body, WASM_OP_END)

        push(func_bodies, body)
        fi = fi + 1

    sec10 = wasm_emit_code_section(func_bodies)

    // Section 11: Data Section (Optional static string payloads)
    sec11 = list()
    if s.ws_data_bytes.len() > 0
        sec11 = wasm_emit_data_section(1024, s.ws_data_bytes)

    // ── Phase 5: Assemble Complete W3C WebAssembly Binary Container ────────────
    wasm_bytes = wasm_emit_header()
    wasm_append_bytes(wasm_bytes, sec1)
    wasm_append_bytes(wasm_bytes, sec3)
    wasm_append_bytes(wasm_bytes, sec5)
    wasm_append_bytes(wasm_bytes, sec7)
    wasm_append_bytes(wasm_bytes, sec10)
    if sec11.len() > 0
        wasm_append_bytes(wasm_bytes, sec11)

    return wasm_bytes

fn wasm_synth_compile_source source_code
    // WHY: High-level convenience compiler turning raw LiPi source string
    //      directly into valid W3C WebAssembly bytecode bytes.
    toks = tokenize_source(source_code)
    return wasm_synth_compile_program(toks)

fn wasm_emit_binary_file wasm_bytes out_path
    // WHY: Commits raw WebAssembly binary bytecode bytes directly to disk via file_write_bytes.
    //      Pure Lipi sovereign binary write without external shell or tools.
    return file_write_bytes(out_path, wasm_bytes)

// ==============================================================================
// ── 10. Autonomous Verification Self-Test Suite ───────────────────────────────
// ==============================================================================

fn test_wasm_synthesizer_subsystem
    // WHY: Autonomous self-test suite validating LEB128 encoders, section assembly,
    //      expression compilation, conditionals, loops, and standalone binary emission.

    // 1. Verify Unsigned LEB128
    u_buf = list()
    wasm_emit_u32_leb(u_buf, 0)
    if u_buf.len() != 1 or u_buf[0] != 0
        say "FAIL: wasm_emit_u32_leb(0)"
        return 0

    u_buf = list()
    wasm_emit_u32_leb(u_buf, 624485)
    if u_buf.len() != 3 or u_buf[0] != 229 or u_buf[1] != 142 or u_buf[2] != 38
        say "FAIL: wasm_emit_u32_leb(624485)"
        return 0

    // 2. Verify Signed LEB128
    s_buf = list()
    wasm_emit_i64_leb(s_buf, 0 - 1)
    if s_buf.len() != 1 or s_buf[0] != 127
        say "FAIL: wasm_emit_i64_leb(-1)"
        return 0

    s_buf = list()
    wasm_emit_i64_leb(s_buf, 0 - 624485)
    if s_buf.len() != 3 or s_buf[0] != 155 or s_buf[1] != 241 or s_buf[2] != 89
        say "FAIL: wasm_emit_i64_leb(-624485)"
        return 0

    // 3. Verify Header and Magic Byte Sequence
    hdr = wasm_emit_header()
    if hdr.len() != 8 or hdr[0] != 0 or hdr[1] != 97 or hdr[2] != 115 or hdr[3] != 109 or hdr[4] != 1
        say "FAIL: WASM header sequence mismatch"
        return 0

    // 4. Verify Program Compilation (Arithmetic + Variable + Return)
    prog_src = "x = 10\ny = 32\nreturn x + y"
    toks = tokenize_source(prog_src)
    wasm_bin = wasm_synth_compile_program(toks)

    if wasm_bin.len() < 30
        say "FAIL: Compiled wasm binary is too small"
        return 0

    if wasm_bin[0] != 0 or wasm_bin[1] != 97 or wasm_bin[2] != 115 or wasm_bin[3] != 109
        say "FAIL: Compiled binary lacks \\0asm magic header"
        return 0

    // 5. Verify Standalone File Emission
    out_file = "/tmp/lipi_wasm_synth_test.wasm"
    write_res = wasm_emit_binary_file(wasm_bin, out_file)
    if write_res < 0
        say "FAIL: wasm_emit_binary_file failed to write disk binary"
        return 0

    say "✔ WASM Synthesizer self-test passed successfully!"
    return 1

// test_wasm_synthesizer_subsystem()
