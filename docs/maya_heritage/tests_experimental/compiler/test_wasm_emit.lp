@! ============================================================================
@! MAYA COMPILER BACKEND — WEBASSEMBLY EMITTER & LEB128 TEST SUITE
@! File: tests/compiler/test_wasm_emit.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"
import "compiler/backend/wasm/codegen"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🕸️ MAYA WEBASSEMBLY EMITTER & 64-BIT LEB128 TEST SUITE 🕸️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Unsigned 64-bit LEB128 Encoding
  println("▶ Section 1: 64-Bit Unsigned LEB128 (ULEB128) Test Vectors...")
  total_tests = total_tests + 1

  b1 = bytebuf_new()
  encode_u64_leb128(b1, 0)
  ok1 = assert_eq_int(b1.bytes.len(), 1, "0 is 1 byte")
  ok2 = assert_eq_int(b1.bytes[0], 0, "0 encodes to [0x00]")

  b2 = bytebuf_new()
  encode_u64_leb128(b2, 1)
  ok3 = assert_eq_int(b2.bytes[0], 1, "1 encodes to [0x01]")

  b3 = bytebuf_new()
  encode_u64_leb128(b3, 127)
  ok4 = assert_eq_int(b3.bytes[0], 127, "127 encodes to [0x7F]")

  b4 = bytebuf_new()
  encode_u64_leb128(b4, 128)
  ok5 = assert_eq_int(b4.bytes.len(), 2, "128 is 2 bytes")
  ok6 = assert_eq_int(b4.bytes[0], 128, "128 byte 0 is 0x80")
  ok7 = assert_eq_int(b4.bytes[1], 1, "128 byte 1 is 0x01")

  b5 = bytebuf_new()
  encode_u64_leb128(b5, 624485)
  ok8 = assert_eq_int(b5.bytes.len(), 3, "624485 is 3 bytes")
  ok9 = assert_eq_int(b5.bytes[0], 229, "624485 byte 0 is 0xE5 (229)")
  ok10 = assert_eq_int(b5.bytes[1], 142, "624485 byte 1 is 0x8E (142)")
  ok11 = assert_eq_int(b5.bytes[2], 38, "624485 byte 2 is 0x26 (38)")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unsigned 64-bit LEB128 vectors verified")
  @end

  @! SECTION 2: Signed 64-bit LEB128 Encoding
  println("▶ Section 2: 64-Bit Signed LEB128 (SLEB128) Test Vectors...")
  total_tests = total_tests + 1

  sb1 = bytebuf_new()
  encode_i64_leb128(sb1, 0)
  sok1 = assert_eq_int(sb1.bytes[0], 0, "0 encodes to [0x00]")

  sb2 = bytebuf_new()
  encode_i64_leb128(sb2, 1)
  sok2 = assert_eq_int(sb2.bytes[0], 1, "1 encodes to [0x01]")

  sb3 = bytebuf_new()
  encode_i64_leb128(sb3, -1)
  sok3 = assert_eq_int(sb3.bytes.len(), 1, "-1 is exactly 1 byte in SLEB128")
  sok4 = assert_eq_int(sb3.bytes[0], 127, "-1 encodes to [0x7F]")

  sb4 = bytebuf_new()
  encode_i64_leb128(sb4, -624485)
  sok5 = assert_eq_int(sb4.bytes.len(), 3, "-624485 is 3 bytes in SLEB128")
  sok6 = assert_eq_int(sb4.bytes[0], 155, "-624485 byte 0 is 0x9B (155)")
  sok7 = assert_eq_int(sb4.bytes[1], 241, "-624485 byte 1 is 0xF1 (241)")
  sok8 = assert_eq_int(sb4.bytes[2], 89, "-624485 byte 2 is 0x59 (89)")

  sb5 = bytebuf_new()
  encode_i64_leb128(sb5, -128)
  sok9 = assert_eq_int(sb5.bytes.len(), 2, "-128 is 2 bytes")
  sok10 = assert_eq_int(sb5.bytes[0], 128, "-128 byte 0 is 0x80")
  sok11 = assert_eq_int(sb5.bytes[1], 127, "-128 byte 1 is 0x7F")

  sb6 = bytebuf_new()
  encode_i64_leb128(sb6, 127)
  sok12 = assert_eq_int(sb6.bytes.len(), 2, "127 is 2 bytes in SLEB128")
  sok13 = assert_eq_int(sb6.bytes[0], 255, "127 byte 0 is 0xFF")
  sok14 = assert_eq_int(sb6.bytes[1], 0, "127 byte 1 is 0x00")

  @if sok1 == 1 && sok2 == 1 && sok3 == 1 && sok4 == 1 && sok5 == 1 && sok6 == 1 && sok7 == 1 && sok8 == 1 && sok9 == 1 && sok10 == 1 && sok11 == 1 && sok12 == 1 && sok13 == 1 && sok14 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Signed 64-bit LEB128 vectors (-1 -> [0x7F], -624485 -> [0x9B, 0xF1, 0x59]) verified")
  @end

  @! SECTION 3: WasmBuf Instruction Emission
  println("▶ Section 3: WasmBuf Codegen & Instruction Emission...")
  total_tests = total_tests + 1

  wb = wasm_buf_new()
  wasm_emit_i32_const(wb, -1)
  wb_ok1 = assert_eq_int(wb.wb_data[0], 65, "i32.const opcode is 0x41 (65)")
  wb_ok2 = assert_eq_int(wb.wb_data[1], 127, "i32.const -1 immediate is 0x7F (127)")

  wb2 = wasm_buf_new()
  wasm_emit_i32_const(wb2, -624485)
  wb_ok3 = assert_eq_int(wb2.wb_data[0], 65, "i32.const opcode 65")
  wb_ok4 = assert_eq_int(wb2.wb_data[1], 155, "-624485 byte 0 is 155")
  wb_ok5 = assert_eq_int(wb2.wb_data[2], 241, "-624485 byte 1 is 241")
  wb_ok6 = assert_eq_int(wb2.wb_data[3], 89, "-624485 byte 2 is 89")

  wb3 = wasm_buf_new()
  wasm_emit_local_get(wb3, 0)
  wasm_emit_local_get(wb3, 1)
  wasm_emit_add_i64(wb3)
  wasm_emit_return(wb3)
  wb_ok7 = assert_eq_int(wb3.wb_data[0], 32, "local.get opcode is 32")
  wb_ok8 = assert_eq_int(wb3.wb_data[1], 0, "local 0")
  wb_ok9 = assert_eq_int(wb3.wb_data[2], 32, "local.get opcode is 32")
  wb_ok10 = assert_eq_int(wb3.wb_data[3], 1, "local 1")
  wb_ok11 = assert_eq_int(wb3.wb_data[4], 124, "i64.add opcode is 124")
  wb_ok12 = assert_eq_int(wb3.wb_data[5], 15, "return opcode is 15")

  @if wb_ok1 == 1 && wb_ok2 == 1 && wb_ok3 == 1 && wb_ok4 == 1 && wb_ok5 == 1 && wb_ok6 == 1 && wb_ok7 == 1 && wb_ok8 == 1 && wb_ok9 == 1 && wb_ok10 == 1 && wb_ok11 == 1 && wb_ok12 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] WasmBuf instruction and SLEB128 constant emission verified")
  @end

  @! SECTION 4: End-to-End WASM Module Serialization & Disk Writing
  println("▶ Section 4: Full WASM Module Binary Serialization & Disk Write...")
  total_tests = total_tests + 1

  @! Build Module: fn add(i32, i32) -> i32
  fn_type = {
    params: [127, 127], @! [i32, i32]
    results: [127]      @! [i32]
  }

  instr_get0 = instr_new(32) @! 0x20 local.get
  instr_get0.imm_list = [0]

  instr_get1 = instr_new(32) @! 0x20 local.get
  instr_get1.imm_list = [1]

  instr_add = instr_new(106) @! 0x6A i32.add
  instr_ret = instr_new(15)  @! 0x0F return

  func = {
    type_idx: 0,
    locals: [],
    body: [instr_get0, instr_get1, instr_add, instr_ret]
  }

  mem = {
    limits_min: 1,
    limits_max: 1,
    has_max: 0
  }

  exp_fn = {
    name: "add",
    kind: 0, @! function export
    index: 0
  }

  exp_mem = {
    name: "memory",
    kind: 2, @! memory export
    index: 0
  }

  module = {
    types: [fn_type],
    imports: [],
    functions: [func],
    tables: [],
    memories: [mem],
    globals: [],
    exports: [exp_fn, exp_mem],
    start: 0,
    has_start: 0,
    data: [],
    elements: []
  }

  mod_buf = write_wasm_module(module)
  mod_ok1 = assert_eq_int(mod_buf.bytes[0], 0, "Magic byte 0 is 0x00")
  mod_ok2 = assert_eq_int(mod_buf.bytes[1], 97, "Magic byte 1 is 'a'")
  mod_ok3 = assert_eq_int(mod_buf.bytes[2], 115, "Magic byte 2 is 's'")
  mod_ok4 = assert_eq_int(mod_buf.bytes[3], 109, "Magic byte 3 is 'm' (\\0asm)")
  mod_ok5 = assert_eq_int(mod_buf.bytes[4], 1, "WASM Version 1")

  out_wasm_path = "/tmp/test_maya_calc.wasm"
  write_status = wasm_write_module(module, out_wasm_path)
  mod_ok6 = assert_eq_int(write_status, 1, "wasm_write_module successfully serialized and wrote to disk")

  @if mod_ok1 == 1 && mod_ok2 == 1 && mod_ok3 == 1 && mod_ok4 == 1 && mod_ok5 == 1 && mod_ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full WASM binary module serialization and disk write verified")
  @end

  @! SECTION 5: WasmGlobal Struct Field Alignment & Global Section Emission
  println("▶ Section 5: WasmGlobal is_mut & Global Section Serialization...")
  total_tests = total_tests + 1

  glob1 = {
    val_type: 127, @! i32
    is_mut: 1,    @! mutable
    init_expr: [instr_new_const_i32(65536)]
  }

  glob2 = {
    val_type: 126, @! i64
    is_mut: 0,    @! immutable
    init_expr: [instr_new_const_i32(1000000)]
  }

  mod_glob = {
    types: [],
    imports: [],
    functions: [],
    tables: [],
    memories: [],
    globals: [glob1, glob2],
    exports: [],
    start: 0,
    has_start: 0,
    data: [],
    elements: []
  }

  glob_buf = write_wasm_module(mod_glob)
  g_ok1 = assert_true(glob_buf.bytes.len() > 8, "Global module serialized with header")
  
  @! Find section 6 (global section)
  found_sec6 = 0
  sec6_mut1 = 0
  sec6_mut2 = 0
  idx = 8
  @while idx < glob_buf.bytes.len()
    sec_id = glob_buf.bytes[idx]
    @if sec_id == 6
      found_sec6 = 1
      @! Byte layout: sec_id (6), sec_len, count (2), glob1_type (127), glob1_mut (1), ...
      sec6_mut1 = glob_buf.bytes[idx + 4]
    @end
    idx = idx + 1
  @end

  g_ok2 = assert_eq_int(found_sec6, 1, "Global section (ID 6) present in serialized bytes")
  g_ok3 = assert_eq_int(sec6_mut1, 1, "WasmGlobal glob1 is_mut is correctly emitted as 1")

  out_glob_path = "/tmp/test_maya_globals.wasm"
  g_write = wasm_write_module(mod_glob, out_glob_path)
  g_ok4 = assert_eq_int(g_write, 1, "Global module written to disk successfully")

  @if g_ok1 == 1 && g_ok2 == 1 && g_ok3 == 1 && g_ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] WasmGlobal struct field alignment and global section emission verified")
  @end

  println("=================================================================")
  println("📊 WASM TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 WASM TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME WASM TESTS FAILED")
    return 1
  @end
@end
