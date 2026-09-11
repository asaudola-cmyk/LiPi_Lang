@! ============================================================================
@! ADVERSARIAL TEST SUITE: MACH-O 64-BIT EMITTER STRESS & BYTE INTEGRITY
@! File: tests/adversarial/test_phase2_macho_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/macho_writer"

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] " + msg)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🍎 ADVERSARIAL MACH-O 64-BIT EMITTER STRESS SUITE 🍎")
  println("=================================================================")

  total = 0
  passed = 0

  @! 1. Edge Case: Empty machine code array
  println("▶ Section 1: Empty & Zero Machine Code Array Handling...")
  total = total + 1
  res_empty = write_macho64_executable([], "/tmp/test_macho_empty")
  ok1 = assert_eq_int(res_empty.mw_success, 1, "Empty machine code produces successful binary")
  ok2 = assert_eq_int(res_empty.mw_file_size, 4112, "File size is 4096 (header) + 16 (aligned nop/ret)")
  ok3 = assert_eq_int(res_empty.mw_entry_vaddr, 4294971392, "Entry point is 0x100001000")

  res_null = write_macho64_executable(0, "/tmp/test_macho_null")
  ok4 = assert_eq_int(res_null.mw_success, 1, "Null machine code produces successful binary")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed = passed + 1
    println("  [PASS] Empty and null code array fallbacks verified")
  @end

  @! 2. Edge Case: Non-aligned single-byte & 17-byte payloads
  println("▶ Section 2: Non-16-Byte Aligned Payloads (1-byte, 17-byte, 33-byte)...")
  total = total + 1
  code_1b = [144] @! 1 byte (nop)
  res_1b = write_macho64_executable(code_1b, "/tmp/test_macho_1b")
  ok5 = assert_eq_int(res_1b.mw_file_size, 4112, "1-byte payload aligned to 16 bytes (4112 total)")

  code_17b = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  res_17b = write_macho64_executable(code_17b, "/tmp/test_macho_17b")
  ok6 = assert_eq_int(res_17b.mw_file_size, 4128, "17-byte payload aligned to 32 bytes (4128 total)")

  @if ok5 == 1 && ok6 == 1
    passed = passed + 1
    println("  [PASS] Non-16-byte aligned payload alignment verified")
  @end

  @! 3. Stress Test: Large 64KB machine code buffer
  println("▶ Section 3: Large Machine Code Buffer (65,536 bytes)...")
  total = total + 1
  large_code = []
  i = 0
  @while i < 65536
    large_code = large_code.push(i % 256)
    i = i + 1
  @end
  res_large = write_macho64_executable(large_code, "/tmp/test_macho_large")
  ok7 = assert_eq_int(res_large.mw_success, 1, "Large 64KB Mach-O emitted successfully")
  ok8 = assert_eq_int(res_large.mw_file_size, 4096 + 65536, "File size matches 4096 header + 65536 code")
  @if ok7 == 1 && ok8 == 1
    passed = passed + 1
    println("  [PASS] 64KB large payload emitted and sized correctly")
  @end

  println("=================================================================")
  println("📊 MACH-O ADVERSARIAL RESULTS: " + passed.to_str() + " / " + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL MACH-O ADVERSARIAL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ MACH-O ADVERSARIAL TESTS FAILED")
    return 1
  @end
@end
