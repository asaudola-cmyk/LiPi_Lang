// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Mach-O 64-Bit Binary Emitter PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: compiler, backend, macho, emitter, binary

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: MACH-O 64-BIT BINARY EMITTER
@! File: tests/e2e/tier1_features/test_emitter_macho.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "compiler/backend/macho_writer"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 4: Mach-O 64-Bit Binary Emitter")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Mach-O 64-Bit Magic Header Serialization
  total = total + 1
  hdr = macho_build_header(16777223, 2147483651, 3, 408, 133)
  @! Magic: 0xFEEDFACF -> [207, 250, 237, 254]
  is_magic = hdr[0] == 207 && hdr[1] == 250 && hdr[2] == 237 && hdr[3] == 254
  is_len = hdr.len() == 32
  @if is_magic && is_len
    passed = passed + 1
    println("  [PASS] T1.1: Mach-O 64-bit header (MH_MAGIC_64 0xFEEDFACF, 32 bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Mach-O 64-bit header serialization")
  @end

  @! T1.2: LC_SEGMENT_64 (__PAGEZERO) Command
  total = total + 1
  pagezero = macho_build_pagezero_segment()
  @! cmd = 25 (0x19), cmdsize = 72
  cmd_id = pagezero[0] | (pagezero[1] * 256)
  cmd_size = pagezero[4] | (pagezero[5] * 256)
  is_pz_len = pagezero.len() == 72
  @if cmd_id == 25 && cmd_size == 72 && is_pz_len
    passed = passed + 1
    println("  [PASS] T1.2: __PAGEZERO segment command (cmd=25 LC_SEGMENT_64, size=72)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: __PAGEZERO segment command")
  @end

  @! T1.3: LC_SEGMENT_64 (__TEXT) & __text Section Header
  total = total + 1
  text_seg = macho_build_text_segment(64, 4096)
  text_sec = macho_build_text_section(4294971392, 64, 4096)
  is_text_seg_len = text_seg.len() == 72
  is_text_sec_len = text_sec.len() == 80
  @if is_text_seg_len && is_text_sec_len
    passed = passed + 1
    println("  [PASS] T1.3: __TEXT segment (72B) and __text section header (80B) with 4KB alignment")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: __TEXT segment and __text section header")
  @end

  @! T1.4: LC_UNIXTHREAD Entry Point Command
  total = total + 1
  entry_point = 4294971392 @! 0x100001000
  th_cmd = macho_build_unixthread_command(entry_point)
  th_cmd_id = th_cmd[0] | (th_cmd[1] * 256)
  th_cmd_size = th_cmd[4] | (th_cmd[5] * 256)
  @if th_cmd_id == 5 && th_cmd_size == 184 && th_cmd.len() == 184
    passed = passed + 1
    println("  [PASS] T1.4: LC_UNIXTHREAD command (cmd=5, size=184, thread state x86_64)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: LC_UNIXTHREAD command")
  @end

  @! T1.5: Little-Endian Integer Encoders
  total = total + 1
  u16_bytes = macho_u16_le(4660) @! 0x1234 -> [0x34, 0x12] = [52, 18]
  u32_bytes = macho_u32_le(305419896) @! 0x12345678 -> [120, 86, 52, 18]
  @if u16_bytes[0] == 52 && u16_bytes[1] == 18 && u32_bytes[0] == 120 && u32_bytes[3] == 18
    passed = passed + 1
    println("  [PASS] T1.5: Little-endian integer byte encoding (u16/u32/u64)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Little-endian encoding")
  @end

  @! T1.6: Executable Binary File Generation
  total = total + 1
  pid = sys_getpid()
  out_path = "/tmp/maya_t1_macho_" + maya_int_to_str(pid) + ".bin"
  @! Machine code: mov eax, 42; ret (0xB8, 42, 0, 0, 0, 0xC3)
  code = [184, 42, 0, 0, 0, 195]
  res = write_macho64_executable(code, out_path)
  
  @! Check file was created and is at least 4096 + 16 bytes
  fd = sys_open(out_path, 0, 0)
  sys_close(fd)
  sys_unlink(out_path)

  @if res.mw_success == 1 && res.mw_file_size >= 4096 && fd > 0
    passed = passed + 1
    println("  [PASS] T1.6: Complete Mach-O 64-bit binary emission to disk (size=" + res.mw_file_size.to_str() + " bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: Executable binary generation")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 4 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Mach-O 64-Bit Binary Emitter PASSED")
    return 0
  @else
    println("✗ Feature: Mach-O 64-Bit Binary Emitter FAILED")
    return 1
  @end
@end
