// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Boundary Integers PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, integers, zero_identity, negative_math, 32bit_limits, modulo, bitwise

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: BOUNDARY INTEGERS
@! File: tests/e2e/tier2_boundaries/test_boundary_integers.maya
@! ============================================================================

@fn abs_val(n)
  @if n < 0
    return 0 - n
  @else
    return n
  @end
@end

@fn multiply_negatives(a, b)
  return a * b
@end

@fn divide_negatives(a, b)
  return a / b
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Boundary Integers (Zero, Negative, Limits)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-INT-01: Zero Value Arithmetic Identity
  total = total + 1
  zero_add = 42 + 0
  zero_mul = 42 * 0
  zero_div = 0 / 42
  zero_sub = 42 - 0
  @if zero_add == 42 && zero_mul == 0 && zero_div == 0 && zero_sub == 42
    passed = passed + 1
    println("  [PASS] BC-INT-01: Zero identity arithmetic (42+0=42, 42*0=0, 0/42=0, 42-0=42)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-01: Zero identity arithmetic")
  @end

  @! BC-INT-02: Negative Multiplication & Division
  total = total + 1
  neg_mul = multiply_negatives(-15, -4)
  neg_pos_mul = multiply_negatives(-15, 4)
  neg_div = divide_negatives(-60, -4)
  neg_pos_div = divide_negatives(-60, 4)
  @if neg_mul == 60 && neg_pos_mul == -60 && neg_div == 15 && neg_pos_div == -15
    passed = passed + 1
    println("  [PASS] BC-INT-02: Negative multiplication & division (-15*-4=60, -60/-4=15)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-02: Negative multiplication and division")
  @end

  @! BC-INT-03: Absolute Value of Extreme Negative, Positive and Zero
  total = total + 1
  abs_neg = abs_val(-2147483640)
  abs_pos = abs_val(2147483640)
  abs_zero = abs_val(0)
  @if abs_neg == 2147483640 && abs_pos == 2147483640 && abs_zero == 0
    passed = passed + 1
    println("  [PASS] BC-INT-03: Absolute value calculation (abs(-2147483640) == 2147483640, abs(0) == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-03: Absolute value calculation")
  @end

  @! BC-INT-04: Large Integers (32-bit boundary arithmetic)
  total = total + 1
  large_a = 2147483640
  large_b = 7
  large_sum = large_a + large_b
  large_sub = large_sum - large_b
  @if large_sum == 2147483647 && large_sub == 2147483640
    passed = passed + 1
    println("  [PASS] BC-INT-04: 32-bit boundary integer addition & subtraction (2147483640 + 7 == 2147483647)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-04: 32-bit boundary integer arithmetic")
  @end

  @! BC-INT-05: Double Negation and Negative Math
  total = total + 1
  double_neg = 50 - (-30)
  neg_neg_res = -(-100)
  @if double_neg == 80 && neg_neg_res == 100
    passed = passed + 1
    println("  [PASS] BC-INT-05: Subtraction of negative integers (50 - (-30) == 80, -(-100) == 100)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-05: Double negation arithmetic")
  @end

  @! BC-INT-06: Modulo Operations with Zero and Negative Numbers
  total = total + 1
  mod_zero = 0 % 50
  mod_same = 100 % 100
  mod_neg = -42 % 5
  @if mod_zero == 0 && mod_same == 0 && mod_neg == -2
    passed = passed + 1
    println("  [PASS] BC-INT-06: Modulo boundary arithmetic (0%50=0, 100%100=0, -42%5=-2)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-06: Modulo operations")
  @end

  @! BC-INT-07: Bitwise Operations with Zero and All-Ones (-1)
  total = total + 1
  b_and = 0 & -1
  b_or = 0 | -1
  b_xor = -1 ^ -1
  @if b_and == 0 && b_or == -1 && b_xor == 0
    passed = passed + 1
    println("  [PASS] BC-INT-07: Bitwise boundary math (0&-1=0, 0|-1=-1, -1^-1=0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-INT-07: Bitwise operations")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Boundary Integers PASSED")
    return 0
  @else
    println("✗ Boundary: Boundary Integers FAILED")
    return 1
  @end
@end
