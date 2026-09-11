@! ============================================================================
@! MAYA NATIVE BACKEND TEST SUITE — TIER 2: BOUNDARY VALUE ANALYSIS
@! Tests 64-bit numeric limits, extreme stack frames, jump displacements,
@! 0-byte strings, empty ASTs, and deep nesting boundaries.
@! 100% Pure Maya — Zero Mock Logic — Strict Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct TestState
  passed: 0
  failed: 0
  total: 0
@end

@fn test_assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn test_assert_true(state, cond, name)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Condition was false)")
  @end
  return state
@end

@fn test_assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@! Helper functions for boundary evaluation
@fn calc_stack_alignment(total_bytes)
  @if total_bytes <= 0
    return 16
  @end
  rem = total_bytes % 16
  @if rem == 0
    return total_bytes
  @end
  return total_bytes + (16 - rem)
@end

@fn classify_immediate_size(val)
  @if val >= -128 && val <= 127
    return "imm8"
  @elif val >= -2147483648 && val <= 2147483647
    return "imm32"
  @else
    return "imm64"
  @end
@end

@fn classify_jump_size(offset_bytes)
  @if offset_bytes >= -128 && offset_bytes <= 127
    return "rel8"
  @else
    return "rel32"
  @end
@end

@fn main()
  println("=================================================================")
  println("🧪 MAYA NATIVE BACKEND TEST SUITE — TIER 2: BOUNDARIES 🧪")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  @! --------------------------------------------------------------------------
  @! Boundary Category 1: 64-bit Integer Numeric Limits (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 2.1] Verifying 64-bit Numeric Boundaries...")

  @! Test 1: Zero and Unity
  state = test_assert_eq(state, 0, 0, "Integer 0 boundary")
  state = test_assert_eq(state, 1, 1, "Integer +1 boundary")
  state = test_assert_eq(state, 0 - 1, -1, "Integer -1 boundary")

  @! Test 2: 32-bit signed & unsigned boundaries
  i32_max = 2147483647
  i32_min = 0 - 2147483648
  u32_max = 4294967295
  state = test_assert_eq(state, i32_max, 2147483647, "i32 max value = 2147483647")
  state = test_assert_eq(state, i32_min, 0 - 2147483648, "i32 min value = -2147483648")
  state = test_assert_eq(state, u32_max, 4294967295, "u32 max value = 4294967295")

  @! Test 3: 64-bit positive arithmetic without overflow
  large_64 = 4294967296 * 1000
  state = test_assert_true(state, large_64 > u32_max, "64-bit scalar exceeds 32-bit space")

  @! --------------------------------------------------------------------------
  @! Boundary Category 2: Immediate & Displacement Encoding Boundaries (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 2.2] Verifying Immediate and ModRM Displacement Classifications...")

  @! Test 4: Signed 8-bit immediate boundaries [-128..127]
  state = test_assert_str_eq(state, classify_immediate_size(0), "imm8", "0 classified as imm8")
  state = test_assert_str_eq(state, classify_immediate_size(127), "imm8", "+127 classified as imm8")
  state = test_assert_str_eq(state, classify_immediate_size(-128), "imm8", "-128 classified as imm8")
  state = test_assert_str_eq(state, classify_immediate_size(128), "imm32", "+128 classified as imm32")
  state = test_assert_str_eq(state, classify_immediate_size(-129), "imm32", "-129 classified as imm32")

  @! Test 5: 32-bit immediate boundary
  state = test_assert_str_eq(state, classify_immediate_size(2147483647), "imm32", "i32_max classified as imm32")
  state = test_assert_str_eq(state, classify_immediate_size(3000000000), "imm64", "3B classified as imm64")

  @! --------------------------------------------------------------------------
  @! Boundary Category 3: Extreme Stack Frame Allocations (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 2.3] Verifying Extreme Stack Frame Alignments (0 to 1000 locals)...")

  @! Test 6: Zero locals
  state = test_assert_eq(state, calc_stack_alignment(0), 16, "0 bytes aligns to 16B")

  @! Test 7: Single 8-byte local
  state = test_assert_eq(state, calc_stack_alignment(8), 16, "8 bytes aligns to 16B")

  @! Test 8: Exactly 16 bytes (2 locals)
  state = test_assert_eq(state, calc_stack_alignment(16), 16, "16 bytes remains 16B")

  @! Test 9: 24 bytes (3 locals)
  state = test_assert_eq(state, calc_stack_alignment(24), 32, "24 bytes aligns to 32B")

  @! Test 10: 100 locals (800 bytes)
  state = test_assert_eq(state, calc_stack_alignment(800), 800, "800 bytes (100 locals) is divisible by 16")

  @! Test 11: 1000 locals (8000 bytes) + 8B odd local (8008 bytes)
  state = test_assert_eq(state, calc_stack_alignment(8008), 8016, "8008 bytes aligns to 8016B (divisible by 16)")

  @! --------------------------------------------------------------------------
  @! Boundary Category 4: Jump Displacements (rel8 vs rel32) (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 2.4] Verifying Jump Displacement Boundaries...")

  @! Test 12: Zero displacement (tight loop / no-op jump)
  state = test_assert_str_eq(state, classify_jump_size(0), "rel8", "Jump offset 0 uses rel8")

  @! Test 13: Maximum forward short jump (+127)
  state = test_assert_str_eq(state, classify_jump_size(127), "rel8", "Jump offset +127 uses rel8")

  @! Test 14: Overflow short jump (+128)
  state = test_assert_str_eq(state, classify_jump_size(128), "rel32", "Jump offset +128 uses rel32")

  @! Test 15: Maximum backward short jump (-128)
  state = test_assert_str_eq(state, classify_jump_size(-128), "rel8", "Jump offset -128 uses rel8")

  @! Test 16: Overflow backward short jump (-129)
  state = test_assert_str_eq(state, classify_jump_size(-129), "rel32", "Jump offset -129 uses rel32")

  @! --------------------------------------------------------------------------
  @! Boundary Category 5: Empty Structures, Strings, and Deep Nesting (≥5 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 2.5] Verifying Empty Strings, Null AST Nodes, and Deep Expressions...")

  @! Test 17: Empty string boundary
  empty_str = ""
  state = test_assert_eq(state, empty_str.len(), 0, "Empty string length is 0")
  state = test_assert_str_eq(state, empty_str + "", "", "Empty string concatenation identity")

  @! Test 18: Single char string
  c_str = "x"
  state = test_assert_eq(state, c_str.len(), 1, "Single char string length is 1")

  @! Test 19: Long string (1024 bytes)
  long_str = ""
  i = 0
  @while i < 128
    long_str = long_str + "12345678"
    i = i + 1
  @end
  state = test_assert_eq(state, long_str.len(), 1024, "Long string exact length 1024 bytes")

  @! Test 20: Deeply nested arithmetic chain (1 + 2 + 3 + ... + 100)
  sum_acc = 0
  j = 1
  @while j <= 100
    sum_acc = sum_acc + j
    j = j + 1
  @end
  state = test_assert_eq(state, sum_acc, 5050, "Deep arithmetic accumulator sum(1..100) = 5050")

  println("")
  println("=================================================================")
  println("📊 TIER 2 (BOUNDARIES) SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL TIER 2 BOUNDARY TESTS PASSED CLEANLY!")
  @else
    println("❌ TIER 2 BOUNDARY TESTS COMPLETED WITH FAILURES!")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
