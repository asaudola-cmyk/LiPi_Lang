// @! RUN: %maya %file
// @! EXPECT: ✓ Tier 2: Boundary Emitters & LEB128 Limits PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: emitter, wasm, macho, omni, leb128, boundary, limits

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY VALUE ANALYSIS: BINARY EMITTERS & LEB128 LIMITS
@! File: tests/e2e/tier2_boundaries/test_boundary_emitters_leb128.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"
import "compiler/backend/macho_writer"
import "compiler/backend/omni_binary"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary Value Analysis: Binary Emitters & LEB128")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T2.1: Unsigned LEB128 Boundary Values (0, 1, 63, 64, 127, 128, 255, 16383, 16384)
  total = total + 1
  buf_u = bytebuf_new()
  encode_u32_leb128(buf_u, 0)      @! 1 byte: [0]
  encode_u32_leb128(buf_u, 1)      @! 1 byte: [1]
  encode_u32_leb128(buf_u, 63)     @! 1 byte: [63]
  encode_u32_leb128(buf_u, 64)     @! 1 byte: [64]
  encode_u32_leb128(buf_u, 127)    @! 1 byte: [127]
  encode_u32_leb128(buf_u, 128)    @! 2 bytes: [128, 1]
  encode_u32_leb128(buf_u, 255)    @! 2 bytes: [255, 1]
  encode_u32_leb128(buf_u, 16383)  @! 2 bytes: [255, 127]
  encode_u32_leb128(buf_u, 16384)  @! 3 bytes: [128, 128, 1]
  
  u_ok1 = buf_u.bytes[0] == 0 && buf_u.bytes[1] == 1 && buf_u.bytes[2] == 63
  u_ok2 = buf_u.bytes[3] == 64 && buf_u.bytes[4] == 127
  u_ok3 = buf_u.bytes[5] == 128 && buf_u.bytes[6] == 1 && buf_u.bytes[7] == 255 && buf_u.bytes[8] == 1
  u_ok4 = buf_u.bytes[9] == 255 && buf_u.bytes[10] == 127
  u_ok5 = buf_u.bytes[11] == 128 && buf_u.bytes[12] == 128 && buf_u.bytes[13] == 1
  @if u_ok1 && u_ok2 && u_ok3 && u_ok4 && u_ok5
    passed = passed + 1
    println("  [PASS] T2.1: Unsigned LEB128 boundary limits (0..16384 varint width expansion)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.1: Unsigned LEB128 boundary limits")
  @end

  @! T2.2: Signed LEB128 Negative Boundary Values (-1, -64, -65, -128)
  total = total + 1
  buf_s = bytebuf_new()
  encode_i32_leb128(buf_s, -1)   @! 1 byte: [127]
  encode_i32_leb128(buf_s, -64)  @! 1 byte: [64]
  encode_i32_leb128(buf_s, 63)   @! 1 byte: [63]
  encode_i32_leb128(buf_s, 64)   @! 2 bytes: [192, 0]
  encode_i32_leb128(buf_s, -128) @! 2 bytes: [128, 127]

  s_ok1 = buf_s.bytes[0] == 127 && buf_s.bytes[1] == 64 && buf_s.bytes[2] == 63
  s_ok2 = buf_s.bytes[3] == 192 && buf_s.bytes[4] == 0 && buf_s.bytes[5] == 128 && buf_s.bytes[6] == 127
  @if s_ok1 && s_ok2
    passed = passed + 1
    println("  [PASS] T2.2: Signed LEB128 negative boundary limits (-1, -64, 63, 64, -128)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.2: Signed LEB128 negative boundary limits")
  @end

  @! T2.3: Mach-O 0-Byte / Empty Code Section Resiliency
  total = total + 1
  pid = sys_getpid()
  macho_empty_path = "/tmp/maya_t2_macho_empty_" + maya_int_to_str(pid) + ".bin"
  res_empty = write_macho64_executable([], macho_empty_path)
  
  fd_m = sys_open(macho_empty_path, 0, 0)
  sys_close(fd_m)
  sys_unlink(macho_empty_path)

  @if res_empty.mw_success == 1 && res_empty.mw_file_size >= 4096 && fd_m > 0
    passed = passed + 1
    println("  [PASS] T2.3: Mach-O emitter empty 0-byte code fallback handling (nop; ret padded to 4KB page)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.3: Mach-O emitter empty code fallback")
  @end

  @! T2.4: Omni-Binary Empty Payloads & Multi-OS Header Offsets
  total = total + 1
  omni_empty = omni_pack_binary([], [], [], "empty_key")
  hdr_empty = omni_empty.header
  raw_empty = omni_empty.polyglot_raw_bytes
  
  is_ape = raw_empty[0] == 77 && raw_empty[1] == 90 && raw_empty[2] == 113
  is_offsets = hdr_empty.e_lfanew == 256 && hdr_empty.elf_header_offset == 64 && hdr_empty.macho_header_offset == 128
  @if is_ape && is_offsets && raw_empty.len() >= 260
    passed = passed + 1
    println("  [PASS] T2.4: Omni-Binary empty payload multi-OS header offset invariance")
  @else
    failed = failed + 1
    println("  [FAIL] T2.4: Omni-Binary empty payload handling")
  @end

  @! T2.5: WASM Multi-Section Empty List Resiliency
  total = total + 1
  mod_empty = wasm_module_new()
  buf_w_empty = write_wasm_module(mod_empty)
  @! An empty WASM module emits exactly 8 bytes (magic + version) without trailing garbage
  is_wasm_empty = buf_w_empty.size == 8 && buf_w_empty.bytes[0] == 0 && buf_w_empty.bytes[1] == 97
  @if is_wasm_empty
    passed = passed + 1
    println("  [PASS] T2.5: WASM module empty section list produces pristine 8-byte binary header")
  @else
    failed = failed + 1
    println("  [FAIL] T2.5: WASM module empty section list")
  @end

  println("-----------------------------------------------------------------")
  println("Tier 2 Emitters Boundary Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Tier 2: Boundary Emitters & LEB128 Limits PASSED")
    return 0
  @else
    println("✗ Tier 2: Boundary Emitters & LEB128 Limits FAILED")
    return 1
  @end
@end
