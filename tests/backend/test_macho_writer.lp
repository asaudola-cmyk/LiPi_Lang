@! ============================================================================
@! MAYA COMPILER BACKEND — MACH-O 64-BIT BINARY EMITTER TEST SUITE
@! File: tests/backend/test_macho_writer.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/macho_writer"

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
  println("🍎 MAYA MACH-O 64-BIT NATIVE BINARY EMITTER TEST SUITE 🍎")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Mach-O 64 Header and Load Command Builders
  println("▶ Section 1: Mach-O 64 Header & Segment Structures...")
  total_tests = total_tests + 1

  hdr = macho_build_header(16777223, 2147483651, 3, 408, 133)
  ok1 = assert_eq_int(hdr.len(), 32, "Mach-O 64 header length is 32 bytes")
  ok2 = assert_eq_int(hdr[0], 207, "Magic byte 0 is 0xCF")
  ok3 = assert_eq_int(hdr[1], 250, "Magic byte 1 is 0xFA")
  ok4 = assert_eq_int(hdr[2], 237, "Magic byte 2 is 0xED")
  ok5 = assert_eq_int(hdr[3], 254, "Magic byte 3 is 0xFE (0xFEEDFACF MH_MAGIC_64)")
  ok6 = assert_eq_int(hdr[4], 7, "CPU Type is CPU_TYPE_X86_64 (7)")

  pagezero = macho_build_pagezero_segment()
  ok7 = assert_eq_int(pagezero.len(), 72, "__PAGEZERO segment length is 72 bytes")
  ok8 = assert_eq_int(pagezero[0], 25, "Command is LC_SEGMENT_64 (0x19 = 25)")

  text_seg = macho_build_text_segment(32, 4096)
  ok9 = assert_eq_int(text_seg.len(), 72, "__TEXT segment command length is 72 bytes")

  text_sec = macho_build_text_section(4294971392, 32, 4096)
  ok10 = assert_eq_int(text_sec.len(), 80, "__text section length is 80 bytes")

  th_cmd = macho_build_unixthread_command(4294971392)
  ok11 = assert_eq_int(th_cmd.len(), 184, "LC_UNIXTHREAD command length is 184 bytes")
  ok12 = assert_eq_int(th_cmd[0], 5, "Command is LC_UNIXTHREAD (5)")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Mach-O 64-bit headers, segments and thread command structures verified")
  @end

  @! SECTION 2: Executable Binary File Generation
  println("▶ Section 2: Executable Binary Generation to Disk...")
  total_tests = total_tests + 1

  @! Minimal x86_64 code: mov eax, 42; ret (0xB8, 42, 0, 0, 0, 0xC3)
  code = [184, 42, 0, 0, 0, 195]
  out_path = "/tmp/test_maya_macho_app"

  res = write_macho64_executable(code, out_path)
  ok1 = assert_eq_int(res.mw_success, 1, "write_macho64_executable succeeded")
  ok2 = assert_true(res.mw_file_size >= 4112, "Binary size includes 4KB header page + aligned code")
  ok3 = assert_eq_int(res.mw_entry_vaddr, 4294971392, "Entry point is 0x100001000 (4294971392)")

  status1 = macho_write_executable(code, "/tmp/test_maya_macho_app2")
  ok4 = assert_eq_int(status1, 1, "macho_write_executable(code, path) succeeded")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full 64-bit Mach-O executable binary emitted and verified")
  @end

  @! SECTION 3: Parameter Polymorphism ((path, code) & (code, path))
  println("▶ Section 3: Mach-O Parameter Polymorphism & Wrappers...")
  total_tests = total_tests + 1

  @! (path, code) order
  status2 = macho_write_executable("/tmp/test_maya_macho_app_poly1", code)
  ok_p1 = assert_eq_int(status2, 1, "macho_write_executable(path, code) succeeded")

  @! (code, path) order
  status3 = macho_write_executable(code, "/tmp/test_maya_macho_app_poly2")
  ok_p2 = assert_eq_int(status3, 1, "macho_write_executable(code, path) succeeded")

  @! emit_macho_64_executable wrapper both ways
  status4 = emit_macho_64_executable("/tmp/test_maya_macho_app_poly3", code)
  ok_p3 = assert_eq_int(status4, 1, "emit_macho_64_executable(path, code) succeeded")

  status5 = emit_macho_64_executable(code, "/tmp/test_maya_macho_app_poly4")
  ok_p4 = assert_eq_int(status5, 1, "emit_macho_64_executable(code, path) succeeded")

  @! Empty array and null code polymorphism
  status6 = macho_write_executable("/tmp/test_maya_macho_app_poly5", [])
  ok_p5 = assert_eq_int(status6, 1, "macho_write_executable(path, []) succeeded")

  status7 = macho_write_executable(0, "/tmp/test_maya_macho_app_poly6")
  ok_p6 = assert_eq_int(status7, 1, "macho_write_executable(0, path) succeeded")

  @if ok_p1 == 1 && ok_p2 == 1 && ok_p3 == 1 && ok_p4 == 1 && ok_p5 == 1 && ok_p6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] All parameter order permutations and edge cases verified")
  @end

  println("=================================================================")
  println("📊 MACH-O TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 MACH-O TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MACH-O TESTS FAILED")
    return 1
  @end
@end
