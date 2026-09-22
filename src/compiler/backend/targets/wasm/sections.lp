// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — WEBASSEMBLY BINARY SECTION EMITTER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/wasm/sections.lp
//
// WHY THIS MODULE:
// 1. WebAssembly (W3C WASM Standard) binaries are organized as structured binary modules
//    preceded by an 8-byte magic header ("\0asm", version 1).
// 2. Ordered Section Layout:
//    Sections must strictly appear in ascending ID order in the binary file:
//    - Section 1: Type Section (Function signatures: parameters and returns)
//    - Section 2: Import Section (Host functions e.g. console.log / runtime intrinsics)
//    - Section 3: Function Section (Maps function index to type signature index)
//    - Section 7: Export Section (Public function exports and memory exports)
//    - Section 10: Code Section (Function local variables and bytecode instructions)
//    - Section 11: Data Section (Static string literals and data segment payloads)
// 3. Section Envelope Protocol:
//    Every section is encapsulated in a standardized envelope:
//    [Section ID: 1 byte] [Payload Size in bytes: u32 LEB128] [Payload Data...]
// ==============================================================================

// ── 1. WASM Section Identifiers & Value Types ─────────────────────────────────

WASM_SEC_CUSTOM   = 0
WASM_SEC_TYPE     = 1
WASM_SEC_IMPORT   = 2
WASM_SEC_FUNCTION = 3
WASM_SEC_TABLE    = 4
WASM_SEC_MEMORY   = 5
WASM_SEC_GLOBAL   = 6
WASM_SEC_EXPORT   = 7
WASM_SEC_START    = 8
WASM_SEC_ELEMENT  = 9
WASM_SEC_CODE     = 10
WASM_SEC_DATA     = 11

WASM_TYPE_I32     = 127  // 0x7F
WASM_TYPE_I64     = 126  // 0x7E
WASM_TYPE_F32     = 125  // 0x7D
WASM_TYPE_F64     = 124  // 0x7C
WASM_TYPE_FUNC    = 96   // 0x60

// ── 2. Helper Primitives & LEB128 Integration ────────────────────────────────

fn wasm_leb_u32 val
    // WHY: Encodes section length or vector size as unsigned LEB128.
    bytes = list()
    v = val
    if v < 0 v = v + 4294967296
    more = 1
    while more == 1
        b = v % 128
        v = v / 128
        if v == 0
            push(bytes, b)
            more = 0
        else
            push(bytes, b + 128)
    return bytes

fn wasm_append_bytes dst src
    // WHY: Ingests one byte buffer into another.
    cnt = len(src)
    i = 0
    while i < cnt
        push(dst, get(src, i))
        i = i + 1
    return dst

fn wasm_encode_string str_val
    // WHY: Emits UTF-8 string with LEB128 byte-count prefix.
    bytes = list()
    slen = len(str_val)
    wasm_append_bytes(bytes, wasm_leb_u32(slen))
    i = 0
    while i < slen
        c = char_at(str_val, i)
        push(bytes, ord(c))
        i = i + 1
    return bytes

// ── 3. WASM Header & Section Envelope ─────────────────────────────────────────

fn wasm_emit_header
    // WHY: Every valid WASM binary begins with the 8-byte preamble:
    //      Magic: \0 a s m (0x00, 0x61, 0x73, 0x6D)
    //      Version: 1 (0x01, 0x00, 0x00, 0x00)
    bytes = list()
    push(bytes, 0)
    push(bytes, 97)   // 'a'
    push(bytes, 115)  // 's'
    push(bytes, 109)  // 'm'
    push(bytes, 1)    // Version 1
    push(bytes, 0)
    push(bytes, 0)
    push(bytes, 0)
    return bytes

fn wasm_emit_section sec_id payload
    // WHY: Envelopes arbitrary section payload with [Section ID] and [LEB128 size].
    bytes = list()
    push(bytes, sec_id)
    size = len(payload)
    wasm_append_bytes(bytes, wasm_leb_u32(size))
    wasm_append_bytes(bytes, payload)
    return bytes

// ── 4. Canonical Section Builders ─────────────────────────────────────────────

fn wasm_emit_type_section param_types return_types
    // WHY: Emits Section 1 declaring a single function type (e.g. (i32) -> i32).
    payload = list()
    // Type vector count = 1
    wasm_append_bytes(payload, wasm_leb_u32(1))

    // 0x60: Func form
    push(payload, WASM_TYPE_FUNC)

    // Parameter vector
    num_params = len(param_types)
    wasm_append_bytes(payload, wasm_leb_u32(num_params))
    p_i = 0
    while p_i < num_params
        push(payload, get(param_types, p_i))
        p_i = p_i + 1

    // Return vector
    num_rets = len(return_types)
    wasm_append_bytes(payload, wasm_leb_u32(num_rets))
    r_i = 0
    while r_i < num_rets
        push(payload, get(return_types, r_i))
        r_i = r_i + 1

    return wasm_emit_section(WASM_SEC_TYPE, payload)

fn wasm_emit_function_section type_indices
    // WHY: Emits Section 3 mapping functions to their signature indices in Type section.
    payload = list()
    count = len(type_indices)
    wasm_append_bytes(payload, wasm_leb_u32(count))
    i = 0
    while i < count
        wasm_append_bytes(payload, wasm_leb_u32(get(type_indices, i)))
        i = i + 1
    return wasm_emit_section(WASM_SEC_FUNCTION, payload)

fn wasm_emit_code_section function_bodies
    // WHY: Emits Section 10 containing executable bytecode for each function.
    //      Format: vector of [Function Body: u32 size, local vec, bytecodes, 0x0B END].
    payload = list()
    count = len(function_bodies)
    wasm_append_bytes(payload, wasm_leb_u32(count))
    i = 0
    while i < count
        body = get(function_bodies, i)
        // Each body must have its own length prefix
        wasm_append_bytes(payload, wasm_leb_u32(len(body)))
        wasm_append_bytes(payload, body)
        i = i + 1
    return wasm_emit_section(WASM_SEC_CODE, payload)

fn wasm_emit_data_section mem_offset data_bytes
    // WHY: Emits Section 11 initializing linear memory at mem_offset.
    payload = list()
    // Data segment count = 1
    wasm_append_bytes(payload, wasm_leb_u32(1))

    // Memory index 0
    push(payload, 0)

    // Offset expression: i32.const mem_offset, end (0x41, LEB, 0x0B)
    push(payload, 65) // 0x41: i32.const
    wasm_append_bytes(payload, wasm_leb_u32(mem_offset))
    push(payload, 11) // 0x0B: end

    // Data payload
    d_len = len(data_bytes)
    wasm_append_bytes(payload, wasm_leb_u32(d_len))
    wasm_append_bytes(payload, data_bytes)

    return wasm_emit_section(WASM_SEC_DATA, payload)

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_wasm_sections_subsystem
    // 1. Verify 8-byte WASM header: \0 a s m 1 0 0 0
    hdr = wasm_emit_header()
    if len(hdr) != 8 or get(hdr, 0) != 0 or get(hdr, 1) != 97 or get(hdr, 2) != 115 or get(hdr, 3) != 109 or get(hdr, 4) != 1
        say "FAIL: WASM magic header mismatch"
        return 0

    // 2. Verify Type Section with 1 param (i32) and 1 return (i32)
    params = list()
    push(params, WASM_TYPE_I32)
    rets = list()
    push(rets, WASM_TYPE_I32)
    sec1 = wasm_emit_type_section(params, rets)
    if get(sec1, 0) != WASM_SEC_TYPE
        say "FAIL: Type section ID must be 1"
        return 0

    // 3. Verify Function Section with type index 0
    f_types = list()
    push(f_types, 0)
    sec3 = wasm_emit_function_section(f_types)
    if get(sec3, 0) != WASM_SEC_FUNCTION
        say "FAIL: Function section ID must be 3"
        return 0

    return 1

// test_wasm_sections_subsystem()
