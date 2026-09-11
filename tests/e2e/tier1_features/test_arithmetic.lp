@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: ARITHMETIC & OPERATORS
@! File: tests/e2e/tier1_features/test_arithmetic.maya
@! ============================================================================

@fn add_nums(a, b)
  return a + b
@end

@fn sub_nums(a, b)
  return a - b
@end

@fn mul_nums(a, b)
  return a * b
@end

@fn div_nums(a, b)
  return a / b
@end

@fn mod_nums(a, b)
  return a % b
@end

@fn complex_calc(a, b, c, d)
  return a + b * c - d
@end

import "universe/core/math"

@fn bitwise_ops(a, b)
  band = bit_and(a, b)
  bor = bit_or(a, b)
  bxor = bit_xor(a, b)
  return band + bor + bxor
@end

@fn shift_ops(val, shift)
  shl_val = val
  shr_val = val
  i = 0
  @while i < shift
    shl_val = shl_val * 2
    shr_val = shr_val / 2
    i = i + 1
  @end
  return shl_val + shr_val
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 1: Arithmetic & Operator Precedence")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Basic Addition, Subtraction, Multiplication
  total = total + 1
  sum_res = add_nums(1234, 5678)
  sub_res = sub_nums(5000, 1500)
  mul_res = mul_nums(25, 40)
  @if sum_res == 6912 && sub_res == 3500 && mul_res == 1000
    passed = passed + 1
    println("  [PASS] T1.1: Basic addition, subtraction, and multiplication")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Basic addition, subtraction, and multiplication")
  @end

  @! T1.2: Integer Division & Modulo
  total = total + 1
  d_res = div_nums(100, 7)
  m_res = mod_nums(100, 7)
  @if d_res == 14 && m_res == 2
    passed = passed + 1
    println("  [PASS] T1.2: Integer division (100 / 7 = 14) and modulo (100 % 7 = 2)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Integer division and modulo")
  @end

  @! T1.3: Operator Precedence (Multiplication before Addition)
  total = total + 1
  prec1 = 10 + 5 * 6 - 20 / 4
  @! 10 + 30 - 5 = 35
  prec2 = complex_calc(15, 4, 10, 5)
  @! 15 + 40 - 5 = 50
  @if prec1 == 35 && prec2 == 50
    passed = passed + 1
    println("  [PASS] T1.3: Operator precedence evaluation (10 + 5 * 6 - 20 / 4 = 35)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: Operator precedence evaluation")
  @end

  @! T1.4: Parentheses & Unary Negation
  total = total + 1
  group_res = (10 + 5) * (6 - 2)
  @! 15 * 4 = 60
  neg_val = 0 - 50
  neg_res = neg_val + 100
  @! -50 + 100 = 50
  @if group_res == 60 && neg_res == 50
    passed = passed + 1
    println("  [PASS] T1.4: Parentheses grouping ((10 + 5) * (6 - 2) = 60) and negation")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: Parentheses and unary negation")
  @end

  @! T1.5: Bitwise AND, OR, XOR Operations
  total = total + 1
  @! a = 0b1100 (12), b = 0b1010 (10)
  @! a & b = 0b1000 (8), a | b = 0b1110 (14), a ^ b = 0b0110 (6)
  @! sum = 8 + 14 + 6 = 28
  bw_res = bitwise_ops(12, 10)
  @if bw_res == 28
    passed = passed + 1
    println("  [PASS] T1.5: Bitwise AND, OR, XOR operations (12 & 10 + 12 | 10 + 12 ^ 10 = 28)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Bitwise operations")
  @end

  @! T1.6: Bit Shifts (Left Shift & Right Shift)
  total = total + 1
  @! val = 16 (0b10000), shift = 2
  @! 16 * 4 = 64, 16 / 4 = 4 -> sum = 68
  sh_res = shift_ops(16, 2)
  @if sh_res == 68
    passed = passed + 1
    println("  [PASS] T1.6: Bit shifts (16 * 4 + 16 / 4 = 68)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: Bit shifts")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature 1 (Arithmetic & Operators) PASSED")
    return 0
  @else
    println("✗ Feature 1 (Arithmetic & Operators) FAILED")
    return 1
  @end
@end
