@! ============================================================================
@! ADVERSARIAL STRESS TEST: NUMERIC LIMITS & NEGATIVE ARITHMETIC (test_adv_numeric_limits.maya)
@! Tests:
@! 1. INT64 max / min boundaries and large arithmetic
@! 2. Negative number arithmetic (+, -, *, /, %)
@! 3. Negative number relational comparisons (<, <=, >, >=, ==, !=)
@! 4. Negative numbers in loops (countdown through 0, negative bounds)
@! 5. Hexadecimal and binary integer representation
@! ============================================================================

@fn loop_countdown_sum(start_val, end_val)
  let sum = 0
  let i = start_val
  @while i >= end_val
    sum = sum + i
    i = i - 1
  @end
  return sum
@end

@fn loop_countup_sum(start_val, end_val)
  let sum = 0
  let i = start_val
  @while i <= end_val
    sum = sum + i
    i = i + 1
  @end
  return sum
@end

@fn main()
  println("=================================================================")
  println("ADVERSARIAL SUITE: NUMERIC LIMITS & NEGATIVES")
  println("=================================================================")

  let passed = 0
  let total = 0

  @! -------------------------------------------------------------
  @! 1. INT64 Boundaries
  @! -------------------------------------------------------------
  println("▶ Section 1: INT64 Boundaries")

  total = total + 1
  let max_i64 = 9223372036854775807
  let max_minus_one = 9223372036854775806
  @if max_i64 > max_minus_one && max_i64 > 0
    passed = passed + 1
    println("  [PASS] N1.1: INT64_MAX literal comparison")
  @else
    println("  [FAIL] N1.1: INT64_MAX literal comparison")
  @end

  total = total + 1
  let min_i64 = 0 - 9223372036854775807 - 1
  @if min_i64 < 0 && min_i64 < (0 - 9223372036854775807)
    passed = passed + 1
    println("  [PASS] N1.2: INT64_MIN arithmetic representation and negativity")
  @else
    println("  [FAIL] N1.2: INT64_MIN arithmetic")
  @end

  total = total + 1
  let big_base = 9223372036854775800
  let big_sum = big_base + 7
  @if big_sum == max_i64
    passed = passed + 1
    println("  [PASS] N1.3: Large 64-bit integer addition up to INT64_MAX")
  @else
    println("  [FAIL] N1.3: Large 64-bit addition")
  @end

  @! -------------------------------------------------------------
  @! 2. Negative Number Arithmetic
  @! -------------------------------------------------------------
  println("▶ Section 2: Negative Number Arithmetic")

  total = total + 1
  let neg_add = (0 - 15) + (0 - 25)
  @if neg_add == (0 - 40)
    passed = passed + 1
    println("  [PASS] N2.1: Negative addition: (-15) + (-25) == -40")
  @else
    println("  [FAIL] N2.1: Negative addition")
  @end

  total = total + 1
  let neg_sub1 = 10 - 50
  let neg_sub2 = (0 - 15) - (0 - 25)
  @if neg_sub1 == (0 - 40) && neg_sub2 == 10
    passed = passed + 1
    println("  [PASS] N2.2: Subtraction yielding negatives and double negatives: 10 - 50 = -40, (-15) - (-25) = 10")
  @else
    println("  [FAIL] N2.2: Negative subtraction")
  @end

  total = total + 1
  let neg_mul1 = (0 - 7) * 8
  let neg_mul2 = (0 - 7) * (0 - 8)
  @if neg_mul1 == (0 - 56) && neg_mul2 == 56
    passed = passed + 1
    println("  [PASS] N2.3: Negative multiplication: (-7) * 8 = -56, (-7) * (-8) = 56")
  @else
    println("  [FAIL] N2.3: Negative multiplication")
  @end

  total = total + 1
  let neg_div1 = (0 - 100) / 10
  let neg_div2 = (0 - 100) / (0 - 10)
  let neg_div3 = 100 / (0 - 10)
  @if neg_div1 == (0 - 10) && neg_div2 == 10 && neg_div3 == (0 - 10)
    passed = passed + 1
    println("  [PASS] N2.4: Signed integer division with negative operands")
  @else
    println("  [FAIL] N2.4: Signed integer division")
  @end

  total = total + 1
  let neg_rem = (0 - 17) % 5
  @if neg_rem == (0 - 2)
    passed = passed + 1
    println("  [PASS] N2.5: Signed remainder with negative dividend: (-17) % 5 == -2")
  @else
    println("  [FAIL] N2.5: Signed remainder")
  @end

  @! -------------------------------------------------------------
  @! 3. Negative Number Comparisons & Relational Operators
  @! -------------------------------------------------------------
  println("▶ Section 3: Negative Number Comparisons")

  total = total + 1
  let n_100 = 0 - 100
  let n_50 = 0 - 50
  let cmp_lt = n_100 < n_50
  let cmp_gt = n_50 > n_100
  let cmp_lte = n_100 <= n_100
  let cmp_gte = n_50 >= n_50
  let cmp_eq = n_100 == (0 - 100)
  let cmp_ne = n_100 != n_50
  @if cmp_lt == 1 && cmp_gt == 1 && cmp_lte == 1 && cmp_gte == 1 && cmp_eq == 1 && cmp_ne == 1
    passed = passed + 1
    println("  [PASS] N3.1: All signed comparison operators on negative integers (<, >, <=, >=, ==, !=)")
  @else
    println("  [FAIL] N3.1: Signed negative comparisons")
  @end

  @! -------------------------------------------------------------
  @! 4. Negative Numbers in Loops & Stepping
  @! -------------------------------------------------------------
  println("▶ Section 4: Negative Loops & Countdown")

  total = total + 1
  @! Countdown from 5 to -5: 5+4+3+2+1+0+(-1)+(-2)+(-3)+(-4)+(-5) = 0
  let sum_zero = loop_countdown_sum(5, 0 - 5)
  @if sum_zero == 0
    passed = passed + 1
    println("  [PASS] N4.1: Loop countdown from 5 to -5 crossing zero (sum = 0)")
  @else
    println("  [FAIL] N4.1: Countdown loop crossing zero")
  @end

  total = total + 1
  @! Countup from -10 to 0: (-10)+(-9)+...+(-1)+0 = -55
  let sum_neg = loop_countup_sum(0 - 10, 0)
  @if sum_neg == (0 - 55)
    passed = passed + 1
    println("  [PASS] N4.2: Loop countup from -10 to 0 (sum = -55)")
  @else
    println("  [FAIL] N4.2: Countup loop in negative space")
  @end

  @! -------------------------------------------------------------
  @! 5. Hexadecimal and Binary Literals
  @! -------------------------------------------------------------
  println("▶ Section 5: Hex & Binary Literals")

  total = total + 1
  let hex_byte = 0xFF
  let hex_word = 0x1000
  let bin_byte = 0b11111111
  let bin_nibble = 0b1010
  @if hex_byte == 255 && hex_word == 4096 && bin_byte == 255 && bin_nibble == 10
    passed = passed + 1
    println("  [PASS] N5.1: Hexadecimal and Binary literal evaluations (0xFF=255, 0x1000=4096, 0b11111111=255, 0b1010=10)")
  @else
    println("  [FAIL] N5.1: Hex/Binary literals")
  @end

  total = total + 1
  let hex_max = 0x7FFFFFFFFFFFFFFF
  @if hex_max == max_i64
    passed = passed + 1
    println("  [PASS] N5.2: 64-bit Hex literal 0x7FFFFFFFFFFFFFFF == INT64_MAX")
  @else
    println("  [FAIL] N5.2: 64-bit Hex literal")
  @end

  println("=================================================================")
  println("NUMERIC LIMITS TESTS SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    return 0
  @else
    return 1
  @end
@end
