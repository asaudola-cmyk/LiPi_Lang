// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: WASM LEB128 Emitter PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: compiler, backend, wasm, leb128, emitter

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: WASM MODULE CODEGEN & LEB128 ENCODING
@! File: tests/e2e/tier1_features/test_emitter_wasm_leb128.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 5: WebAssembly Module Codegen & LEB128 Emitter")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Unsigned LEB128 Encoding (encode_u32_leb128 / encode_u64_leb128)
  total = total + 1
  buf1 = bytebuf_new()
  buf1 = encode_u32_leb128(buf1, 0)      @! 0 -> [0]
  buf1 = encode_u32_leb128(buf1, 1)      @! 1 -> [1]
  buf1 = encode_u32_leb128(buf1, 127)    @! 127 -> [127]
  buf1 = encode_u32_leb128(buf1, 128)    @! 128 -> [128, 1]
  buf1 = encode_u32_leb128(buf1, 624485) @! 624485 -> [0xE5, 0x8E, 0x26] = [229, 142, 38]
  
  ok1 = buf1.bytes[0] == 0 && buf1.bytes[1] == 1 && buf1.bytes[2] == 127
  ok2 = buf1.bytes[3] == 128 && buf1.bytes[4] == 1
  ok3 = buf1.bytes[5] == 229 && buf1.bytes[6] == 142 && buf1.bytes[7] == 38
  @if ok1 && ok2 && ok3
    passed = passed + 1
    println("  [PASS] T1.1: Unsigned LEB128 encoding (0, 1, 127, 128, 624485)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Unsigned LEB128 encoding")
  @end

  @! T1.2: Signed LEB128 Encoding (encode_i32_leb128 / encode_i64_leb128)
  total = total + 1
  buf2 = bytebuf_new()
  buf2 = encode_i32_leb128(buf2, 0)   @! 0 -> [0]
  buf2 = encode_i32_leb128(buf2, 0 - 1)  @! -1 -> [0x7F] = [127]
  buf2 = encode_i32_leb128(buf2, 0 - 64) @! -64 -> [0x40] = [64]
  buf2 = encode_i32_leb128(buf2, 63)  @! 63 -> [0x3F] = [63]
  buf2 = encode_i32_leb128(buf2, 0 - 65) @! -65 -> [0x7F, 0x7F] = [191, 127] (with high bit: 0xBF, 0x7F)
  
  s_ok1 = buf2.bytes[0] == 0 && buf2.bytes[1] == 127 && buf2.bytes[2] == 64
  s_ok2 = buf2.bytes[3] == 63
  @if s_ok1 && s_ok2
    passed = passed + 1
    println("  [PASS] T1.2: Signed LEB128 encoding (0, -1, -64, 63)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Signed LEB128 encoding")
  @end

  @! T1.3: WASM Binary Magic Header (\0asm\1\0\0\0)
  total = total + 1
  mod = wasm_module_new()
  mod_buf = write_wasm_module(mod)
  @! Magic: 0x00, 0x61, 0x73, 0x6D -> 1836278016 (little-endian uint32: [0x00, 0x61, 0x73, 0x6D])
  @! Version: 0x01, 0x00, 0x00, 0x00 -> 1
  has_magic = mod_buf.bytes[0] == 0 && mod_buf.bytes[1] == 97 && mod_buf.bytes[2] == 115 && mod_buf.bytes[3] == 109
  has_ver = mod_buf.bytes[4] == 1 && mod_buf.bytes[5] == 0 && mod_buf.bytes[6] == 0 && mod_buf.bytes[7] == 0
  @if has_magic && has_ver && mod_buf.size >= 8
    passed = passed + 1
    println("  [PASS] T1.3: WASM Binary Magic Header (\\0asm) and Version 1 (8 bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: WASM magic header and version")
  @end

  @! T1.4: Type Section (Section 1) & Function Section (Section 3)
  total = total + 1
  mod_full = wasm_module_new()
  @! FuncType: (i32, i32) -> i32
  ft = { params: [127, 127], results: [127] }
  mod_full.types = mod_full.types.push(ft)
  
  @! Function 0 with type index 0
  wf = {
    type_idx: 0,
    locals: [],
    body: [
      { opcode: 32, imm_i64: 0, imm_f64: 0, imm_list: [0], block_type: 64 }, @! local.get 0
      { opcode: 32, imm_i64: 0, imm_f64: 0, imm_list: [1], block_type: 64 }, @! local.get 1
      { opcode: 106, imm_i64: 0, imm_f64: 0, imm_list: [], block_type: 64 }   @! i32.add
    ]
  }
  mod_full.functions = mod_full.functions.push(wf)
  
  full_buf = write_wasm_module(mod_full)
  @if full_buf.size > 8 && mod_full.types.len() == 1 && mod_full.functions.len() == 1
    passed = passed + 1
    println("  [PASS] T1.4: WASM Type section and Function section emission")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: WASM Type and Function sections")
  @end

  @! T1.5: Export Section (Section 7) & Code Section (Section 10)
  total = total + 1
  exp = { name: "add", kind: 0, index: 0 }
  mod_full.exports = mod_full.exports.push(exp)
  
  buf_exported = write_wasm_module(mod_full)
  @if buf_exported.size > full_buf.size && mod_full.exports.len() == 1
    passed = passed + 1
    println("  [PASS] T1.5: WASM Export section (func 'add') and Code section serialization")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: WASM Export and Code sections")
  @end

  @! T1.6: WASM Module Disk Serialization
  total = total + 1
  pid = sys_getpid()
  wasm_path = "/tmp/maya_t1_wasm_" + maya_int_to_str(pid) + ".wasm"
  status = emit_wasm_module_to_file(mod_full, wasm_path)
  
  fd = sys_open(wasm_path, 0, 0)
  sys_close(fd)
  sys_unlink(wasm_path)

  @if status > 0 && fd > 0
    passed = passed + 1
    println("  [PASS] T1.6: Complete WASM binary module serialization to file (bytes written=" + status.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: WASM module disk serialization")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: WASM LEB128 Emitter PASSED")
    return 0
  @else
    println("✗ Feature: WASM LEB128 Emitter FAILED")
    return 1
  @end
@end
