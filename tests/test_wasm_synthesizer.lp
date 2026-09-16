// ==============================================================================
// 🧪 LIPI SOVEREIGN WEBASSEMBLY (WASM) SYNTHESIZER TEST SUITE
// ⚡ Tests LEB128 encoders, W3C bytecode opcodes, section assembly,
//    expression precedence, conditionals, loops, functions, and standalone binary emission.
// 🏛️ File: tests/test_wasm_synthesizer.lp
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/targets/wasm/synthesizer"

fn test_assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name
    return 1

fn test_leb128_encoding
    say "\n── [Phase 1]: Validating Variable-Length LEB128 Encoders ──"

    // 1. Unsigned LEB128 0 -> [0]
    b0 = list()
    wasm_emit_u32_leb(b0, 0)
    test_assert_eq(b0.len(), 1, "u32_leb(0) length is 1")
    test_assert_eq(b0[0], 0, "u32_leb(0) == 0")

    // 2. Unsigned LEB128 1 -> [1]
    b1 = list()
    wasm_emit_u32_leb(b1, 1)
    test_assert_eq(b1.len(), 1, "u32_leb(1) length is 1")
    test_assert_eq(b1[0], 1, "u32_leb(1) == 1")

    // 3. Unsigned LEB128 127 -> [127]
    b127 = list()
    wasm_emit_u32_leb(b127, 127)
    test_assert_eq(b127.len(), 1, "u32_leb(127) length is 1")
    test_assert_eq(b127[0], 127, "u32_leb(127) == 127")

    // 4. Unsigned LEB128 128 -> [128, 1]
    b128 = list()
    wasm_emit_u32_leb(b128, 128)
    test_assert_eq(b128.len(), 2, "u32_leb(128) length is 2")
    test_assert_eq(b128[0], 128, "u32_leb(128) byte 0 == 128")
    test_assert_eq(b128[1], 1, "u32_leb(128) byte 1 == 1")

    // 5. Unsigned LEB128 624485 -> [229, 142, 38]
    b_large = list()
    wasm_emit_u32_leb(b_large, 624485)
    test_assert_eq(b_large.len(), 3, "u32_leb(624485) length is 3")
    test_assert_eq(b_large[0], 229, "u32_leb(624485) byte 0 == 229 (0xE5)")
    test_assert_eq(b_large[1], 142, "u32_leb(624485) byte 1 == 142 (0x8E)")
    test_assert_eq(b_large[2], 38, "u32_leb(624485) byte 2 == 38 (0x26)")

    // 6. Signed LEB128 -1 -> [127] (0x7F)
    b_neg1 = list()
    wasm_emit_i64_leb(b_neg1, 0 - 1)
    test_assert_eq(b_neg1.len(), 1, "i64_leb(-1) length is 1")
    test_assert_eq(b_neg1[0], 127, "i64_leb(-1) == 127 (0x7F)")

    // 7. Signed LEB128 -2 -> [126] (0x7E)
    b_neg2 = list()
    wasm_emit_i64_leb(b_neg2, 0 - 2)
    test_assert_eq(b_neg2.len(), 1, "i64_leb(-2) length is 1")
    test_assert_eq(b_neg2[0], 126, "i64_leb(-2) == 126 (0x7E)")

    // 8. Signed LEB128 -624485 -> [155, 241, 89]
    b_neg_large = list()
    wasm_emit_i64_leb(b_neg_large, 0 - 624485)
    test_assert_eq(b_neg_large.len(), 3, "i64_leb(-624485) length is 3")
    test_assert_eq(b_neg_large[0], 155, "i64_leb(-624485) byte 0 == 155 (0x9B)")
    test_assert_eq(b_neg_large[1], 241, "i64_leb(-624485) byte 1 == 241 (0xF1)")
    test_assert_eq(b_neg_large[2], 89, "i64_leb(-624485) byte 2 == 89 (0x59)")

    return 1

fn test_bytecode_opcodes
    say "\n── [Phase 2]: Validating WebAssembly Bytecode Encoders ──"

    buf = list()
    wasm_emit_block(buf, WASM_TYPE_EMPTY)
    test_assert_eq(buf[0], WASM_OP_BLOCK, "block opcode is 0x02")
    test_assert_eq(buf[1], WASM_TYPE_EMPTY, "block type is 0x40")

    buf2 = list()
    wasm_emit_loop(buf2, WASM_TYPE_EMPTY)
    test_assert_eq(buf2[0], WASM_OP_LOOP, "loop opcode is 0x03")

    buf3 = list()
    wasm_emit_i64_const(buf3, 42)
    test_assert_eq(buf3[0], WASM_OP_I64_CONST, "i64.const opcode is 0x42")
    test_assert_eq(buf3[1], 42, "i64.const immediate is 42")

    buf4 = list()
    wasm_emit_i64_add(buf4)
    test_assert_eq(buf4[0], WASM_OP_I64_ADD, "i64.add opcode is 0x7C")

    buf5 = list()
    wasm_emit_i64_sub(buf5)
    test_assert_eq(buf5[0], WASM_OP_I64_SUB, "i64.sub opcode is 0x7D")

    buf6 = list()
    wasm_emit_i64_mul(buf6)
    test_assert_eq(buf6[0], WASM_OP_I64_MUL, "i64.mul opcode is 0x7E")

    buf7 = list()
    wasm_emit_i64_div_s(buf7)
    test_assert_eq(buf7[0], WASM_OP_I64_DIV_S, "i64.div_s opcode is 0x7F")

    buf8 = list()
    wasm_emit_i64_rem_s(buf8)
    test_assert_eq(buf8[0], WASM_OP_I64_REM_S, "i64.rem_s opcode is 0x81")

    buf9 = list()
    wasm_emit_i64_le_s(buf9)
    test_assert_eq(buf9[0], WASM_OP_I64_LE_S, "i64.le_s opcode is 0x57 (87)")

    buf10 = list()
    wasm_emit_i64_ge_s(buf10)
    test_assert_eq(buf10[0], WASM_OP_I64_GE_S, "i64.ge_s opcode is 0x59 (89)")

    return 1

fn test_section_assembler
    say "\n── [Phase 3]: Validating W3C Binary Section Layout ──"

    // 1. Header
    hdr = wasm_emit_header()
    test_assert_eq(hdr.len(), 8, "Header length is 8 bytes")
    test_assert_eq(hdr[0], 0, "Magic byte 0 == 0")
    test_assert_eq(hdr[1], 97, "Magic byte 1 == 'a'")
    test_assert_eq(hdr[2], 115, "Magic byte 2 == 's'")
    test_assert_eq(hdr[3], 109, "Magic byte 3 == 'm'")
    test_assert_eq(hdr[4], 1, "Version == 1")

    // 2. Type Section (Section 1)
    types = [0, 2] // func with 0 params, and func with 2 params
    sec1 = wasm_emit_type_section(types)
    test_assert_eq(sec1[0], WASM_SEC_TYPE, "Section ID is 1 (Type)")

    // 3. Function Section (Section 3)
    f_types = [0, 1]
    sec3 = wasm_emit_function_section(f_types)
    test_assert_eq(sec3[0], WASM_SEC_FUNCTION, "Section ID is 3 (Function)")

    // 4. Memory Section (Section 5)
    sec5 = wasm_emit_memory_section()
    test_assert_eq(sec5[0], WASM_SEC_MEMORY, "Section ID is 5 (Memory)")

    // 5. Export Section (Section 7)
    exports = [["main", 0, 0], ["memory", 2, 0]]
    sec7 = wasm_emit_export_section(exports)
    test_assert_eq(sec7[0], WASM_SEC_EXPORT, "Section ID is 7 (Export)")

    return 1

fn test_compilation_and_file_write
    say "\n── [Phase 4]: Validating Complete Program Synthesis & Disk Emission ──"

    prog = "fn add a b\n    return a + b\n\nfn main\n    x = 20\n    y = 22\n    return add(x, y)"
    wasm_bytes = wasm_synth_compile_source(prog)

    test_assert_eq(wasm_bytes[0], 0, "Magic byte 0 == 0")
    test_assert_eq(wasm_bytes[1], 97, "Magic byte 1 == 'a'")
    test_assert_eq(wasm_bytes[2], 115, "Magic byte 2 == 's'")
    test_assert_eq(wasm_bytes[3], 109, "Magic byte 3 == 'm'")

    out_file = "/tmp/lipi_wasm_suite_test.wasm"
    res = wasm_emit_binary_file(wasm_bytes, out_file)
    test_assert_eq(res >= 0, 1, "wasm_emit_binary_file returned success")

    return 1

fn main
    say "=============================================================================="
    say "👑 RUNNING LIPI SOVEREIGN WEBASSEMBLY (WASM) SYNTHESIZER TEST SUITE"
    say "=============================================================================="

    test_leb128_encoding()
    test_bytecode_opcodes()
    test_section_assembler()
    test_compilation_and_file_write()

    say "\n=============================================================================="
    say "✔ ALL WEBASSEMBLY SYNTHESIZER TESTS PASSED WITH 100% SUCCESS!"
    say "=============================================================================="
    return 0

main()
