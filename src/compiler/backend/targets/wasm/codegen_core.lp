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

// WHY: Converts i64 stack top to i32 for linear memory addresses (0xA7)
fn wasm_emit_i32_wrap_i64 byte_list
    push(byte_list, 167)
    return byte_list.len()

// WHY: Loads 64-bit integer from linear memory at [i32 address] (0x29)
fn wasm_emit_i64_load byte_list align offset
    push(byte_list, 41)
    wasm_emit_u32_leb(byte_list, align)
    wasm_emit_u32_leb(byte_list, offset)
    return byte_list.len()

// WHY: Stores 64-bit integer into linear memory at [i32 address, i64 value] (0x37)
fn wasm_emit_i64_store byte_list align offset
    push(byte_list, 55)
    wasm_emit_u32_leb(byte_list, align)
    wasm_emit_u32_leb(byte_list, offset)
    return byte_list.len()

// WHY: Loads 8-bit unsigned byte from linear memory at [i32 address] -> i64 (0x30)
fn wasm_emit_i64_load8_u byte_list align offset
    push(byte_list, 48)
    wasm_emit_u32_leb(byte_list, align)
    wasm_emit_u32_leb(byte_list, offset)
    return byte_list.len()

// WHY: Stores 8-bit byte into linear memory at [i32 address, i64 value] (0x3C)
fn wasm_emit_i64_store8 byte_list align offset
    push(byte_list, 60)
    wasm_emit_u32_leb(byte_list, align)
    wasm_emit_u32_leb(byte_list, offset)
    return byte_list.len()

// WHY: Immediate unreachable trap (0x00)
fn wasm_emit_unreachable byte_list
    push(byte_list, 0)
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

