// ==============================================================================
// 👑 Lipi Sovereign Direct WebAssembly (WASM) Binary Emitter
// ⚡ Written 100% in Pure Lipi (.lp) Indentation Syntax | 0% C | 0% LLVM | 0% Emscripten
// 🏛️ File: src/compiler/wasm_emitter.lp
//
// WHY: WebAssembly (WASM) represents the universal virtual silicon bytecode of the
//      modern web, edge nodes, and sandboxed cloud-native runtime environments.
//      To achieve complete computational sovereignty without relying on C toolchains,
//      LLVM, Clang, or Emscripten, Lipi synthesizes standard W3C WebAssembly binary
//      modules directly from pure Lipi memory manipulation and mathematical integer
//      encoding algorithms.
// ==============================================================================

// ── Native System Call Primitives for Memory Allocation ───────────────────────
// WHY: We define pure syscall primitives directly to avoid fragile nested include paths.
//      Linux x86_64 SYS_mmap = 9 (PROT_READ|PROT_WRITE = 3, MAP_PRIVATE|MAP_ANONYMOUS = 34)
//      Linux x86_64 SYS_munmap = 11.
fn malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

// ── WebAssembly Binary Magic & Version Headers ────────────────────────────────
// WHY: Every valid WebAssembly binary module begins with an invariant 4-byte magic
//      cookie ('\0asm' -> 0x00, 0x61, 0x73, 0x6D) followed by the 4-byte little-endian
//      specification version number (Version 1 -> 0x01, 0x00, 0x00, 0x00).
WASM_MAGIC_0        = 0        // 0x00 ('\0')
WASM_MAGIC_1        = 97       // 0x61 ('a')
WASM_MAGIC_2        = 115      // 0x73 ('s')
WASM_MAGIC_3        = 109      // 0x6D ('m')

WASM_VERSION_0      = 1        // 0x01 (Version 1, byte 0)
WASM_VERSION_1      = 0        // 0x00 (Version 1, byte 1)
WASM_VERSION_2      = 0        // 0x00 (Version 1, byte 2)
WASM_VERSION_3      = 0        // 0x00 (Version 1, byte 3)

// ── WebAssembly Canonical Section Identifiers ─────────────────────────────────
// WHY: WebAssembly binary format partitions a module into typed sections identified
//      by an unsigned 7-bit integer ID. When present, sections must appear in
//      strictly increasing ID order (with Custom sections permitted anywhere).
WASM_SEC_CUSTOM     = 0        // Debugging symbols, name annotations, metadata
WASM_SEC_TYPE       = 1        // Function signatures (parameter and return types)
WASM_SEC_IMPORT     = 2        // External host functions, memories, globals
WASM_SEC_FUNCTION   = 3        // Declaration mapping each function to a type signature
WASM_SEC_TABLE      = 4        // Indirect function call lookup tables
WASM_SEC_MEMORY     = 5        // Linear memory allocation descriptors (pages)
WASM_SEC_GLOBAL     = 6        // Mutable and immutable global variables
WASM_SEC_EXPORT     = 7        // Publicly exposed symbols (functions, memory, globals)
WASM_SEC_START      = 8        // Module initialization entry-point function
WASM_SEC_ELEMENT    = 9        // Table initialization elements
WASM_SEC_CODE       = 10       // Function definitions (local variable counts + bytecode)
WASM_SEC_DATA       = 11       // Memory initial data segments (string constants, tables)

// ── WebAssembly Value Types (valtype) ─────────────────────────────────────────
// WHY: WebAssembly specifies primitive numeric types as negative 7-bit signed
//      integers encoded in 1 byte (0x70 - 0x7F).
WASM_TYPE_I32       = 127      // 0x7F: 32-bit signed/unsigned integer
WASM_TYPE_I64       = 126      // 0x7E: 64-bit signed/unsigned integer
WASM_TYPE_F32       = 125      // 0x7D: 32-bit IEEE 754 single-precision float
WASM_TYPE_F64       = 124      // 0x7C: 64-bit IEEE 754 double-precision float
WASM_TYPE_V128      = 123      // 0x7B: 128-bit SIMD vector
WASM_TYPE_FUNCREF   = 112      // 0x70: Reference to a function
WASM_TYPE_EXTERNREF = 111      // 0x6F: Reference to an external host object
WASM_TYPE_FUNC      = 96       // 0x60: Function type constructor indicator
WASM_TYPE_VOID      = 64       // 0x40: Empty block/pseudo-type (no return value)

// ── WebAssembly External Export / Import Kinds ────────────────────────────────
// WHY: Disambiguates the namespace category of an exported or imported symbol.
WASM_KIND_FUNC      = 0        // Function export
WASM_KIND_TABLE     = 1        // Table export
WASM_KIND_MEM       = 2        // Linear memory export
WASM_KIND_GLOBAL    = 3        // Global variable export

// ── WebAssembly Bytecode Instructions (Opcodes) ───────────────────────────────
// WHY: WebAssembly is a stack-based virtual machine where instructions pop operands
//      from and push results onto an implicit evaluation stack.

// Control Flow Opcodes
WASM_OP_UNREACHABLE = 0        // 0x00: Traps immediately
WASM_OP_NOP         = 1        // 0x01: No operation
WASM_OP_BLOCK       = 2        // 0x02: Begin structured block: block <blocktype>
WASM_OP_LOOP        = 3        // 0x03: Begin loop block: loop <blocktype>
WASM_OP_IF          = 4        // 0x04: Execute block if top of stack != 0: if <blocktype>
WASM_OP_ELSE        = 5        // 0x05: Else branch for if construct
WASM_OP_END         = 11       // 0x0B: Terminates block, loop, if, or function body
WASM_OP_BR          = 12       // 0x0C: Unconditional branch: br <relative_depth>
WASM_OP_BR_IF       = 13       // 0x0D: Conditional branch: br_if <relative_depth>
WASM_OP_RETURN      = 15       // 0x0F: Return from current function
WASM_OP_CALL        = 16       // 0x10: Invoke function: call <func_idx>
WASM_OP_CALL_IND    = 17       // 0x11: Invoke function pointer: call_indirect <type_idx> <tbl_idx>
WASM_OP_DROP        = 26       // 0x1A: Discard top value on evaluation stack
WASM_OP_SELECT      = 27       // 0x1B: Ternary selector: select (cond ? v1 : v2)

// Variable Access Opcodes
WASM_OP_LOCAL_GET   = 32       // 0x20: Push local variable value: local.get <local_idx>
WASM_OP_LOCAL_SET   = 33       // 0x21: Pop value into local variable: local.set <local_idx>
WASM_OP_LOCAL_TEE   = 34       // 0x22: Set local and keep value on stack: local.tee <local_idx>
WASM_OP_GLOBAL_GET  = 35       // 0x23: Push global variable value: global.get <global_idx>
WASM_OP_GLOBAL_SET  = 36       // 0x24: Pop value into global variable: global.set <global_idx>

// Memory Load / Store Opcodes
WASM_OP_I32_LOAD    = 40       // 0x28: Load 32-bit integer: i32.load <align> <offset>
WASM_OP_I32_LOAD8_S = 44       // 0x2C: Load signed 8-bit byte: i32.load8_s <align> <offset>
WASM_OP_I32_LOAD8_U = 45       // 0x2D: Load unsigned 8-bit byte: i32.load8_u <align> <offset>
WASM_OP_I32_STORE   = 54       // 0x36: Store 32-bit integer: i32.store <align> <offset>
WASM_OP_I32_STORE8  = 58       // 0x3A: Store 8-bit byte: i32.store8 <align> <offset>

// Constant Synthesis Opcodes
WASM_OP_I32_CONST   = 65       // 0x41: Push 32-bit constant: i32.const <s32_leb128>
WASM_OP_I64_CONST   = 66       // 0x42: Push 64-bit constant: i64.const <s64_leb128>

// Integer Comparison Opcodes
WASM_OP_I32_EQZ     = 69       // 0x45: Equal to zero (unary bool test): i32.eqz
WASM_OP_I32_EQ      = 70       // 0x46: Equal: i32.eq
WASM_OP_I32_NE      = 71       // 0x47: Not equal: i32.ne
WASM_OP_I32_LT_S    = 72       // 0x48: Less than signed: i32.lt_s
WASM_OP_I32_LT_U    = 73       // 0x49: Less than unsigned: i32.lt_u
WASM_OP_I32_GT_S    = 74       // 0x4A: Greater than signed: i32.gt_s
WASM_OP_I32_GT_U    = 75       // 0x4B: Greater than unsigned: i32.gt_u
WASM_OP_I32_LE_S    = 76       // 0x4C: Less than or equal signed: i32.le_s
WASM_OP_I32_LE_U    = 77       // 0x4D: Less than or equal unsigned: i32.le_u
WASM_OP_I32_GE_S    = 78       // 0x4E: Greater than or equal signed: i32.ge_s
WASM_OP_I32_GE_U    = 79       // 0x4F: Greater than or equal unsigned: i32.ge_u

// Integer Arithmetic & Bitwise Opcodes
WASM_OP_I32_CLZ     = 103      // 0x67: Count leading zeros: i32.clz
WASM_OP_I32_CTZ     = 104      // 0x68: Count trailing zeros: i32.ctz
WASM_OP_I32_POPCNT  = 105      // 0x69: Population count (1-bits): i32.popcnt
WASM_OP_I32_ADD     = 106      // 0x6A: Addition: i32.add
WASM_OP_I32_SUB     = 107      // 0x6B: Subtraction: i32.sub
WASM_OP_I32_MUL     = 108      // 0x6C: Multiplication: i32.mul
WASM_OP_I32_DIV_S   = 109      // 0x6D: Signed division: i32.div_s
WASM_OP_I32_DIV_U   = 110      // 0x6E: Unsigned division: i32.div_u
WASM_OP_I32_REM_S   = 111      // 0x6F: Signed remainder: i32.rem_s
WASM_OP_I32_REM_U   = 112      // 0x70: Unsigned remainder: i32.rem_u
WASM_OP_I32_AND     = 113      // 0x71: Bitwise AND: i32.and
WASM_OP_I32_OR      = 114      // 0x72: Bitwise OR: i32.or
WASM_OP_I32_XOR     = 115      // 0x73: Bitwise XOR: i32.xor
WASM_OP_I32_SHL     = 116      // 0x74: Shift left: i32.shl
WASM_OP_I32_SHR_S   = 117      // 0x75: Arithmetic shift right signed: i32.shr_s
WASM_OP_I32_SHR_U   = 118      // 0x76: Logical shift right unsigned: i32.shr_u
WASM_OP_I32_ROTL    = 119      // 0x77: Rotate left: i32.rotl
WASM_OP_I32_ROTR    = 120      // 0x78: Rotate right: i32.rotr

// ── Dynamic Byte Buffer Operations ───────────────────────────────────────────
// WHY: In Lipi, a dynamic byte buffer is modeled as a list of integer byte values
//      (0..255). Pure mathematical modulo operations prevent negative or overflow values.

fn wasm_buf_new
    return list()

fn wasm_buf_len buf
    return len(buf)

fn wasm_buf_get buf idx
    return get(buf, idx)

fn wasm_buf_set buf idx val
    v = floor(val) % 256
    if v < 0
        v = v + 256
    list_set(buf, idx, v)

fn wasm_buf_put8 buf b
    v = floor(b) % 256
    if v < 0
        v = v + 256
    push(buf, v)

fn wasm_buf_put16 buf val
    v = floor(val)
    if v < 0
        v = v + 65536
    wasm_buf_put8(buf, v % 256)
    wasm_buf_put8(buf, floor(v / 256) % 256)

fn wasm_buf_put32 buf val
    v = floor(val)
    if v < 0
        v = v + 4294967296
    wasm_buf_put8(buf, v % 256)
    wasm_buf_put8(buf, floor(v / 256) % 256)
    wasm_buf_put8(buf, floor(v / 65536) % 256)
    wasm_buf_put8(buf, floor(v / 16777216) % 256)

fn wasm_buf_put_bytes buf bytes_list
    i = 0
    blen = len(bytes_list)
    while i < blen
        wasm_buf_put8(buf, get(bytes_list, i))
        i = i + 1

// ── Mathematical LEB128 Integer Encoders ──────────────────────────────────────
// WHY: WebAssembly uses Variable-Length Quantity (VLQ) encoding in Little Endian
//      Base 128 (LEB128). Unsigned LEB128 (u32) encodes section sizes, type indices,
//      and counts. Signed LEB128 (s32) encodes signed immediate constants like i32.const.
//      Both are implemented with pure arithmetic (division, remainder) to avoid host bitwise bugs.

// Unsigned 32-Bit Integer LEB128 Encoder
// WHY: 7 bits of payload per byte. If remaining value > 0, the high bit (0x80) is set.
fn leb128_encode_u32 val
    out = list()
    v = floor(val)
    if v < 0
        v = v + 4294967296
    done = 0
    while done == 0
        byte = v % 128
        v = floor(v / 128)
        if v != 0
            byte = byte + 128
            push(out, byte)
        else
            push(out, byte)
            done = 1
    return out

// Signed 32-Bit Integer LEB128 Encoder
// WHY: Encodes two's complement integers into LEB128. For positive values, loop terminates
//      when v == 0 and sign bit of 7-bit chunk is 0 (byte < 64). For negative values,
//      loop terminates when arithmetic quotient is -1 and sign bit of 7-bit chunk is 1 (byte >= 64).
fn leb128_encode_s32 val
    out = list()
    v = floor(val)
    if v >= 0
        done = 0
        while done == 0
            byte = v % 128
            v = floor(v / 128)
            if v == 0
                if byte < 64
                    push(out, byte)
                    done = 1
                else
                    push(out, byte + 128)
            else
                push(out, byte + 128)
        return out

    // Negative integer branch: arithmetic division maintains sign extension
    done_neg = 0
    while done_neg == 0
        rem = v % 128
        if rem < 0
            rem = rem + 128
        byte = rem
        new_v = (v - byte) / 128
        if new_v == (0 - 1)
            if byte >= 64
                push(out, byte)
                done_neg = 1
            else
                push(out, byte + 128)
                v = new_v
        else
            push(out, byte + 128)
            v = new_v
    return out

fn wasm_buf_put_u32 buf val
    bytes = leb128_encode_u32(val)
    wasm_buf_put_bytes(buf, bytes)

fn wasm_buf_put_s32 buf val
    bytes = leb128_encode_s32(val)
    wasm_buf_put_bytes(buf, bytes)

// Put UTF-8 string with length prefix encoded in unsigned LEB128
// WHY: WebAssembly string format in Export, Import, and Custom sections requires
//      an unsigned LEB128 byte count immediately preceding raw UTF-8 byte payload.
fn wasm_buf_put_str buf text
    slen = len(text)
    wasm_buf_put_u32(buf, slen)
    i = 0
    while i < slen
        wasm_buf_put8(buf, ord(char_at(text, i)))
        i = i + 1

// ── WebAssembly Instruction Emitters ──────────────────────────────────────────
// WHY: Clean declarative helper functions for appending WASM machine instructions
//      and their typed immediate operands into a code buffer.

// 1. i32.const <val> (Opcode 0x41)
fn wasm_emit_i32_const buf val
    wasm_buf_put8(buf, WASM_OP_I32_CONST)
    wasm_buf_put_s32(buf, val)

// 2. Arithmetic & Logic Opcodes
fn wasm_emit_i32_add buf
    wasm_buf_put8(buf, WASM_OP_I32_ADD)

fn wasm_emit_i32_sub buf
    wasm_buf_put8(buf, WASM_OP_I32_SUB)

fn wasm_emit_i32_mul buf
    wasm_buf_put8(buf, WASM_OP_I32_MUL)

fn wasm_emit_i32_div_s buf
    wasm_buf_put8(buf, WASM_OP_I32_DIV_S)

fn wasm_emit_i32_div_u buf
    wasm_buf_put8(buf, WASM_OP_I32_DIV_U)

fn wasm_emit_i32_rem_s buf
    wasm_buf_put8(buf, WASM_OP_I32_REM_S)

fn wasm_emit_i32_rem_u buf
    wasm_buf_put8(buf, WASM_OP_I32_REM_U)

fn wasm_emit_i32_and buf
    wasm_buf_put8(buf, WASM_OP_I32_AND)

fn wasm_emit_i32_or buf
    wasm_buf_put8(buf, WASM_OP_I32_OR)

fn wasm_emit_i32_xor buf
    wasm_buf_put8(buf, WASM_OP_I32_XOR)

fn wasm_emit_i32_shl buf
    wasm_buf_put8(buf, WASM_OP_I32_SHL)

fn wasm_emit_i32_shr_s buf
    wasm_buf_put8(buf, WASM_OP_I32_SHR_S)

fn wasm_emit_i32_shr_u buf
    wasm_buf_put8(buf, WASM_OP_I32_SHR_U)

// 3. Comparisons
fn wasm_emit_i32_eqz buf
    wasm_buf_put8(buf, WASM_OP_I32_EQZ)

fn wasm_emit_i32_eq buf
    wasm_buf_put8(buf, WASM_OP_I32_EQ)

fn wasm_emit_i32_ne buf
    wasm_buf_put8(buf, WASM_OP_I32_NE)

fn wasm_emit_i32_lt_s buf
    wasm_buf_put8(buf, WASM_OP_I32_LT_S)

fn wasm_emit_i32_gt_s buf
    wasm_buf_put8(buf, WASM_OP_I32_GT_S)

fn wasm_emit_i32_le_s buf
    wasm_buf_put8(buf, WASM_OP_I32_LE_S)

fn wasm_emit_i32_ge_s buf
    wasm_buf_put8(buf, WASM_OP_I32_GE_S)

// 4. Variables
fn wasm_emit_local_get buf local_idx
    wasm_buf_put8(buf, WASM_OP_LOCAL_GET)
    wasm_buf_put_u32(buf, local_idx)

fn wasm_emit_local_set buf local_idx
    wasm_buf_put8(buf, WASM_OP_LOCAL_SET)
    wasm_buf_put_u32(buf, local_idx)

fn wasm_emit_local_tee buf local_idx
    wasm_buf_put8(buf, WASM_OP_LOCAL_TEE)
    wasm_buf_put_u32(buf, local_idx)

fn wasm_emit_global_get buf global_idx
    wasm_buf_put8(buf, WASM_OP_GLOBAL_GET)
    wasm_buf_put_u32(buf, global_idx)

fn wasm_emit_global_set buf global_idx
    wasm_buf_put8(buf, WASM_OP_GLOBAL_SET)
    wasm_buf_put_u32(buf, global_idx)

// 5. Control Flow
fn wasm_emit_call buf func_idx
    wasm_buf_put8(buf, WASM_OP_CALL)
    wasm_buf_put_u32(buf, func_idx)

fn wasm_emit_call_indirect buf type_idx table_idx
    wasm_buf_put8(buf, WASM_OP_CALL_IND)
    wasm_buf_put_u32(buf, type_idx)
    wasm_buf_put_u32(buf, table_idx)

fn wasm_emit_return buf
    wasm_buf_put8(buf, WASM_OP_RETURN)

fn wasm_emit_end buf
    wasm_buf_put8(buf, WASM_OP_END)

fn wasm_emit_nop buf
    wasm_buf_put8(buf, WASM_OP_NOP)

fn wasm_emit_unreachable buf
    wasm_buf_put8(buf, WASM_OP_UNREACHABLE)

fn wasm_emit_drop buf
    wasm_buf_put8(buf, WASM_OP_DROP)

fn wasm_emit_block buf block_type
    wasm_buf_put8(buf, WASM_OP_BLOCK)
    wasm_buf_put8(buf, block_type)

fn wasm_emit_loop buf block_type
    wasm_buf_put8(buf, WASM_OP_LOOP)
    wasm_buf_put8(buf, block_type)

fn wasm_emit_if buf block_type
    wasm_buf_put8(buf, WASM_OP_IF)
    wasm_buf_put8(buf, block_type)

fn wasm_emit_else buf
    wasm_buf_put8(buf, WASM_OP_ELSE)

fn wasm_emit_br buf depth
    wasm_buf_put8(buf, WASM_OP_BR)
    wasm_buf_put_u32(buf, depth)

fn wasm_emit_br_if buf depth
    wasm_buf_put8(buf, WASM_OP_BR_IF)
    wasm_buf_put_u32(buf, depth)

// ── WebAssembly Module Container & Management API ─────────────────────────────
// WHY: State container encapsulates all module sections in mutable Lipi lists:
//   Index 0: types        (list of function type descriptors: [params_list, results_list])
//   Index 1: funcs        (list of function records: [name, type_idx, locals_list, code_buf])
//   Index 2: exports      (list of export records: [name, kind, index])
//   Index 3: memories     (list of memory descriptors: [min_pages, max_pages])
//   Index 4: globals      (list of global descriptors: [valtype, mutable, init_val])
//   Index 5: data_segs    (list of data segment descriptors: [offset, bytes_list])
//   Index 6: func_names   (list of function names for index resolution)

fn wasm_module_new
    m = list()
    push(m, list())     // 0: types
    push(m, list())     // 1: funcs
    push(m, list())     // 2: exports
    push(m, list())     // 3: memories
    push(m, list())     // 4: globals
    push(m, list())     // 5: data_segs
    push(m, list())     // 6: func_names
    return m

// Helper to compare two lists of integer types
fn wasm_types_match list_a list_b
    la = len(list_a)
    lb = len(list_b)
    if la != lb
        return 0
    i = 0
    while i < la
        if get(list_a, i) != get(list_b, i)
            return 0
        i = i + 1
    return 1

// Add or deduplicate function signature type in Section 1 (Type Section)
// WHY: WebAssembly enforces canonical signature indexing. Identical function signatures
//      must share the same type_idx to minimize binary footprint.
fn wasm_add_type module params results
    types = get(module, 0)
    ti = 0
    tlen = len(types)
    while ti < tlen
        entry = get(types, ti)
        e_params = get(entry, 0)
        e_results = get(entry, 1)
        if wasm_types_match(params, e_params) == 1 and wasm_types_match(results, e_results) == 1
            return ti
        ti = ti + 1

    new_entry = list()
    push(new_entry, params)
    push(new_entry, results)
    push(types, new_entry)
    return len(types) - 1

// Add function to module (declares entry in Function Section 3 and Code Section 10)
fn wasm_add_function module name type_idx
    funcs = get(module, 1)
    func_names = get(module, 6)
    func_idx = len(funcs)

    f_record = list()
    push(f_record, name)            // 0: name
    push(f_record, type_idx)        // 1: type_idx
    push(f_record, list())          // 2: locals (list of valtypes)
    push(f_record, wasm_buf_new())  // 3: code_buf

    push(funcs, f_record)
    push(func_names, name)
    return func_idx

// Add declared local variable to a function body
// WHY: Local variable indices in WASM follow parameter indices. If a function has
//      P parameters, the first declared local variable is at local_idx = P.
fn wasm_function_add_local module func_idx valtype
    funcs = get(module, 1)
    f_record = get(funcs, func_idx)
    locals = get(f_record, 2)
    type_idx = get(f_record, 1)

    types = get(module, 0)
    sig = get(types, type_idx)
    params = get(sig, 0)
    param_count = len(params)

    local_order = len(locals)
    push(locals, valtype)
    return param_count + local_order

// Get the instruction code buffer for a specific function
fn wasm_function_get_code module func_idx
    funcs = get(module, 1)
    f_record = get(funcs, func_idx)
    return get(f_record, 3)

// Export an entity (function, memory, global) in Section 7 (Export Section)
fn wasm_add_export module name kind index
    exports = get(module, 2)
    exp = list()
    push(exp, name)
    push(exp, kind)
    push(exp, index)
    push(exports, exp)

// Export a function by name and index
fn wasm_export_function module name func_idx
    wasm_add_export(module, name, WASM_KIND_FUNC, func_idx)

// Declare linear memory in Section 5 (Memory Section)
fn wasm_add_memory module min_pages max_pages
    mems = get(module, 3)
    mem_idx = len(mems)
    mem_desc = list()
    push(mem_desc, min_pages)
    push(mem_desc, max_pages)
    push(mems, mem_desc)
    return mem_idx

// Export linear memory
fn wasm_export_memory module name mem_idx
    wasm_add_export(module, name, WASM_KIND_MEM, mem_idx)

// Lookup function index by symbolic name
fn wasm_find_function module name
    names = get(module, 6)
    i = 0
    nlen = len(names)
    while i < nlen
        if get(names, i) == name
            return i
        i = i + 1
    return 0 - 1

// ── WebAssembly Section Synthesizers ──────────────────────────────────────────
// WHY: Wraps section payload bytes with standard 1-byte section ID and
//      unsigned LEB128 payload byte length prefix.

fn wasm_build_section sec_id payload_buf
    sec_buf = wasm_buf_new()
    wasm_buf_put8(sec_buf, sec_id)
    wasm_buf_put_u32(sec_buf, wasm_buf_len(payload_buf))
    wasm_buf_put_bytes(sec_buf, payload_buf)
    return sec_buf

// Build Type Section (Section ID 1)
// Format: vec(functype) -> count | [0x60 | vec(param_types) | vec(result_types)]
fn wasm_build_type_section module
    types = get(module, 0)
    tcount = len(types)
    if tcount == 0
        return wasm_buf_new()

    payload = wasm_buf_new()
    wasm_buf_put_u32(payload, tcount)

    ti = 0
    while ti < tcount
        entry = get(types, ti)
        params = get(entry, 0)
        results = get(entry, 1)

        wasm_buf_put8(payload, WASM_TYPE_FUNC) // 0x60

        // Parameter types vector
        wasm_buf_put_u32(payload, len(params))
        pi = 0
        while pi < len(params)
            wasm_buf_put8(payload, get(params, pi))
            pi = pi + 1

        // Result types vector
        wasm_buf_put_u32(payload, len(results))
        ri = 0
        while ri < len(results)
            wasm_buf_put8(payload, get(results, ri))
            ri = ri + 1

        ti = ti + 1

    return wasm_build_section(WASM_SEC_TYPE, payload)

// Build Function Section (Section ID 3)
// Format: vec(typeidx) -> count | type_idx_0, type_idx_1, ...
fn wasm_build_func_section module
    funcs = get(module, 1)
    fcount = len(funcs)
    if fcount == 0
        return wasm_buf_new()

    payload = wasm_buf_new()
    wasm_buf_put_u32(payload, fcount)

    fi = 0
    while fi < fcount
        f_record = get(funcs, fi)
        type_idx = get(f_record, 1)
        wasm_buf_put_u32(payload, type_idx)
        fi = fi + 1

    return wasm_build_section(WASM_SEC_FUNCTION, payload)

// Build Memory Section (Section ID 5)
// Format: vec(mem) -> count | limits (flags=0 min | flags=1 min max)
fn wasm_build_memory_section module
    mems = get(module, 3)
    mcount = len(mems)
    if mcount == 0
        return wasm_buf_new()

    payload = wasm_buf_new()
    wasm_buf_put_u32(payload, mcount)

    mi = 0
    while mi < mcount
        entry = get(mems, mi)
        min_p = get(entry, 0)
        max_p = get(entry, 1)
        if max_p < 0
            // No maximum specified
            wasm_buf_put8(payload, 0) // flags = 0
            wasm_buf_put_u32(payload, min_p)
        else
            // Maximum specified
            wasm_buf_put8(payload, 1) // flags = 1
            wasm_buf_put_u32(payload, min_p)
            wasm_buf_put_u32(payload, max_p)
        mi = mi + 1

    return wasm_build_section(WASM_SEC_MEMORY, payload)

// Build Export Section (Section ID 7)
// Format: vec(export) -> count | [name_str | export_kind | export_idx]
fn wasm_build_export_section module
    exports = get(module, 2)
    ecount = len(exports)
    if ecount == 0
        return wasm_buf_new()

    payload = wasm_buf_new()
    wasm_buf_put_u32(payload, ecount)

    ei = 0
    while ei < ecount
        entry = get(exports, ei)
        ename = get(entry, 0)
        ekind = get(entry, 1)
        eidx  = get(entry, 2)

        wasm_buf_put_str(payload, ename)
        wasm_buf_put8(payload, ekind)
        wasm_buf_put_u32(payload, eidx)
        ei = ei + 1

    return wasm_build_section(WASM_SEC_EXPORT, payload)

// Helper: Group consecutive identical local types into compressed WASM local declarations
// WHY: WebAssembly encodes locals as vec(local) where each entry is (count: u32, type: valtype).
//      Compressing runs of the same type produces canonical and compact binaries.
fn wasm_encode_locals_payload locals_list
    loc_buf = wasm_buf_new()
    llen = len(locals_list)
    if llen == 0
        wasm_buf_put_u32(loc_buf, 0)
        return loc_buf

    // Group adjacent types
    groups_count = 0
    i = 0
    while i < llen
        curr_t = get(locals_list, i)
        run_len = 1
        while (i + run_len) < llen and get(locals_list, i + run_len) == curr_t
            run_len = run_len + 1
        groups_count = groups_count + 1
        i = i + run_len

    wasm_buf_put_u32(loc_buf, groups_count)

    i = 0
    while i < llen
        curr_t = get(locals_list, i)
        run_len = 1
        while (i + run_len) < llen and get(locals_list, i + run_len) == curr_t
            run_len = run_len + 1
        wasm_buf_put_u32(loc_buf, run_len)
        wasm_buf_put8(loc_buf, curr_t)
        i = i + run_len

    return loc_buf

// Build Code Section (Section ID 10)
// Format: vec(code) -> count | [body_size | locals_vec | expr_opcodes | 0x0B]
fn wasm_build_code_section module
    funcs = get(module, 1)
    fcount = len(funcs)
    if fcount == 0
        return wasm_buf_new()

    payload = wasm_buf_new()
    wasm_buf_put_u32(payload, fcount)

    fi = 0
    while fi < fcount
        f_record = get(funcs, fi)
        locals   = get(f_record, 2)
        code_buf = get(f_record, 3)

        // Assemble single function body
        body_buf = wasm_buf_new()

        // 1. Local variables vector
        loc_hdr = wasm_encode_locals_payload(locals)
        wasm_buf_put_bytes(body_buf, loc_hdr)

        // 2. Instructions
        wasm_buf_put_bytes(body_buf, code_buf)

        // 3. Emit body size in uLEB128 followed by body bytes
        body_size = wasm_buf_len(body_buf)
        wasm_buf_put_u32(payload, body_size)
        wasm_buf_put_bytes(payload, body_buf)

        fi = fi + 1

    return wasm_build_section(WASM_SEC_CODE, payload)

// ── WebAssembly Complete Module Assembly ──────────────────────────────────────
// WHY: Assembles the final binary byte sequence by stitching magic header,
//      version header, and all populated sections in standard canonical sequence.

fn wasm_assemble module
    out = wasm_buf_new()

    // 1. WebAssembly 4-byte Magic Cookie: '\0asm'
    wasm_buf_put8(out, WASM_MAGIC_0)
    wasm_buf_put8(out, WASM_MAGIC_1)
    wasm_buf_put8(out, WASM_MAGIC_2)
    wasm_buf_put8(out, WASM_MAGIC_3)

    // 2. WebAssembly 4-byte Version: 0x00000001
    wasm_buf_put8(out, WASM_VERSION_0)
    wasm_buf_put8(out, WASM_VERSION_1)
    wasm_buf_put8(out, WASM_VERSION_2)
    wasm_buf_put8(out, WASM_VERSION_3)

    // 3. Section 1: Type Section
    sec_type = wasm_build_type_section(module)
    wasm_buf_put_bytes(out, sec_type)

    // 4. Section 3: Function Section
    sec_func = wasm_build_func_section(module)
    wasm_buf_put_bytes(out, sec_func)

    // 5. Section 5: Memory Section (if configured)
    sec_mem = wasm_build_memory_section(module)
    wasm_buf_put_bytes(out, sec_mem)

    // 6. Section 7: Export Section
    sec_export = wasm_build_export_section(module)
    wasm_buf_put_bytes(out, sec_export)

    // 7. Section 10: Code Section
    sec_code = wasm_build_code_section(module)
    wasm_buf_put_bytes(out, sec_code)

    return out

// ── Pure Lipi Memory Manipulation & Direct File Writing ───────────────────────
// WHY: In accordance with computational sovereignty principles, this function
//      allocates an unmanaged heap page buffer via direct Linux SYS_mmap (malloc),
//      populates it byte-by-byte via mem_byte_write, validates contents via
//      mem_byte_read, and commits binary bytes directly to disk via file_write.

// Pure Lipi file_write wrapper delegating to native file_write_bytes primitive
fn file_write path bytes_list
    return file_write_bytes(path, bytes_list)

// Write binary bytes directly using pure Lipi memory manipulation and file_write
fn wasm_write_file path bytes_list
    blen = len(bytes_list)
    if blen == 0
        return 0 - 1

    // Step 1: Allocate unmanaged memory buffer via Linux SYS_mmap
    buf = malloc(blen)
    if buf <= 0
        return 0 - 1

    // Step 2: Copy bytes into allocated memory buffer using direct pointer writes
    i = 0
    while i < blen
        bval = get(bytes_list, i)
        mem_byte_write(buf, i, bval)
        i = i + 1

    // Step 3: Validate memory contents before committing
    i = 0
    mem_valid = 1
    while i < blen
        read_val = mem_byte_read(buf, i)
        expected_val = get(bytes_list, i)
        if read_val != expected_val
            mem_valid = 0
        i = i + 1

    if mem_valid == 0
        free(buf, blen)
        return 0 - 2

    // Step 4: Write binary bytes directly to disk using file_write
    res = file_write(path, bytes_list)

    // Step 5: Release memory buffer via Linux SYS_munmap
    free(buf, blen)
    return res

// Assemble module and commit to filesystem path
fn wasm_module_write module out_path
    assembled_bytes = wasm_assemble(module)
    return wasm_write_file(out_path, assembled_bytes)

// ── High-Level Lipi Function Compilers (Sovereign WASM Synthesis) ──────────────
// WHY: Equips the sovereign compiler with predefined code generators for
//      fundamental arithmetic, recursion, and entry-point functions.

// 1. Compile 'add(a, b) -> a + b'
// Exports: "add", Type: (i32, i32) -> (i32)
// Bytecode: local.get 0, local.get 1, i32.add, end
fn wasm_compile_function_add module
    params = list()
    push(params, WASM_TYPE_I32)
    push(params, WASM_TYPE_I32)

    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "add", t_idx)
    code = wasm_function_get_code(module, f_idx)

    wasm_emit_local_get(code, 0)
    wasm_emit_local_get(code, 1)
    wasm_emit_i32_add(code)
    wasm_emit_end(code)

    wasm_export_function(module, "add", f_idx)
    return f_idx

// 2. Compile 'sub(a, b) -> a - b'
// Exports: "sub", Type: (i32, i32) -> (i32)
// Bytecode: local.get 0, local.get 1, i32.sub, end
fn wasm_compile_function_sub module
    params = list()
    push(params, WASM_TYPE_I32)
    push(params, WASM_TYPE_I32)

    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "sub", t_idx)
    code = wasm_function_get_code(module, f_idx)

    wasm_emit_local_get(code, 0)
    wasm_emit_local_get(code, 1)
    wasm_emit_i32_sub(code)
    wasm_emit_end(code)

    wasm_export_function(module, "sub", f_idx)
    return f_idx

// 3. Compile 'mul(a, b) -> a * b'
// Exports: "mul", Type: (i32, i32) -> (i32)
// Bytecode: local.get 0, local.get 1, i32.mul, end
fn wasm_compile_function_mul module
    params = list()
    push(params, WASM_TYPE_I32)
    push(params, WASM_TYPE_I32)

    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "mul", t_idx)
    code = wasm_function_get_code(module, f_idx)

    wasm_emit_local_get(code, 0)
    wasm_emit_local_get(code, 1)
    wasm_emit_i32_mul(code)
    wasm_emit_end(code)

    wasm_export_function(module, "mul", f_idx)
    return f_idx

// 4. Compile 'div_s(a, b) -> a / b' (Signed division)
// Exports: "div_s", Type: (i32, i32) -> (i32)
// Bytecode: local.get 0, local.get 1, i32.div_s, end
fn wasm_compile_function_div_s module
    params = list()
    push(params, WASM_TYPE_I32)
    push(params, WASM_TYPE_I32)

    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "div_s", t_idx)
    code = wasm_function_get_code(module, f_idx)

    wasm_emit_local_get(code, 0)
    wasm_emit_local_get(code, 1)
    wasm_emit_i32_div_s(code)
    wasm_emit_end(code)

    wasm_export_function(module, "div_s", f_idx)
    return f_idx

// 5. Compile recursive 'fib(n)'
// Exports: "fib", Type: (i32) -> (i32)
// Logic: if n <= 1 return n else return fib(n-1) + fib(n-2)
// Demonstrates call <func_idx>, if/else/end, comparisons, arithmetic
fn wasm_compile_function_fib module
    params = list()
    push(params, WASM_TYPE_I32)

    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "fib", t_idx)
    code = wasm_function_get_code(module, f_idx)

    // local.get 0
    wasm_emit_local_get(code, 0)
    // i32.const 1
    wasm_emit_i32_const(code, 1)
    // i32.le_s
    wasm_emit_i32_le_s(code)

    // if i32 (then return n else fib(n-1) + fib(n-2))
    wasm_emit_if(code, WASM_TYPE_I32)
    wasm_emit_local_get(code, 0)
    wasm_emit_else(code)
    wasm_emit_local_get(code, 0)
    wasm_emit_i32_const(code, 1)
    wasm_emit_i32_sub(code)
    wasm_emit_call(code, f_idx)

    wasm_emit_local_get(code, 0)
    wasm_emit_i32_const(code, 2)
    wasm_emit_i32_sub(code)
    wasm_emit_call(code, f_idx)

    wasm_emit_i32_add(code)
    wasm_emit_end(code) // end if

    wasm_emit_end(code) // end function

    wasm_export_function(module, "fib", f_idx)
    return f_idx

// 6. Compile 'main() -> i32'
// Exports: "main", Type: () -> (i32)
// Calls: add(10, 32) and returns 42
// Bytecode: i32.const 10, i32.const 32, call <add_idx>, end
fn wasm_compile_function_main module target_add_idx
    params = list()
    results = list()
    push(results, WASM_TYPE_I32)

    t_idx = wasm_add_type(module, params, results)
    f_idx = wasm_add_function(module, "main", t_idx)
    code = wasm_function_get_code(module, f_idx)

    wasm_emit_i32_const(code, 10)
    wasm_emit_i32_const(code, 32)
    wasm_emit_call(code, target_add_idx)
    wasm_emit_end(code)

    wasm_export_function(module, "main", f_idx)
    return f_idx

// 7. Compile a Complete Sample WASM Suite into a standalone .wasm binary
// Synthesizes a module containing add, sub, mul, div_s, fib, and main.
fn wasm_compile_sample_suite out_path
    mod = wasm_module_new()
    f_add = wasm_compile_function_add(mod)
    f_sub = wasm_compile_function_sub(mod)
    f_mul = wasm_compile_function_mul(mod)
    f_div = wasm_compile_function_div_s(mod)
    f_fib = wasm_compile_function_fib(mod)
    f_main = wasm_compile_function_main(mod, f_add)

    res = wasm_module_write(mod, out_path)
    return res
