// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Deep Recursion PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, deep_recursion, call_stack, mutual_recursion, ackermann, bst_depth

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: DEEP RECURSION (DEPTH 1000)
@! File: tests/e2e/tier2_boundaries/test_deep_recursion.maya
@! ============================================================================

@fn deep_countdown(n)
  @if n <= 0
    return 0
  @else
    return deep_countdown(n - 1)
  @end
@end

@fn tail_sum(n, acc)
  @if n <= 0
    return acc
  @else
    return tail_sum(n - 1, acc + n)
  @end
@end

@fn is_even(n)
  @if n == 0
    return 1
  @else
    return is_odd(n - 1)
  @end
@end

@fn is_odd(n)
  @if n == 0
    return 0
  @else
    return is_even(n - 1)
  @end
@end

@fn ackermann(m, n)
  @if m == 0
    return n + 1
  @elif m > 0 && n == 0
    return ackermann(m - 1, 1)
  @else
    return ackermann(m - 1, ackermann(m, n - 1))
  @end
@end

@fn count_digits_recursive(n)
  @if n < 10
    return 1
  @else
    return 1 + count_digits_recursive(n / 10)
  @end
@end

@fn gcd_recursive(a, b)
  @if b == 0
    return a
  @else
    return gcd_recursive(b, a % b)
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Deep Recursion (Depth 1000 & Mutual)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-REC-01: Call Stack Depth 1000 Recursion
  total = total + 1
  rec_res = deep_countdown(1000)
  @if rec_res == 0
    passed = passed + 1
    println("  [PASS] BC-REC-01: 1000-deep recursion completed cleanly without stack overflow")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-01: 1000-deep recursion")
  @end

  @! BC-REC-02: Mutual Recursion (is_even / is_odd with depth 100)
  total = total + 1
  even100 = is_even(100)
  odd100 = is_odd(100)
  even99 = is_even(99)
  odd99 = is_odd(99)
  @if even100 == 1 && odd100 == 0 && even99 == 0 && odd99 == 1
    passed = passed + 1
    println("  [PASS] BC-REC-02: Mutual recursion across 100 stack frames (is_even/is_odd)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-02: Mutual recursion")
  @end

  @! BC-REC-03: Tail-Recursive Accumulator Summation (1 to 1000)
  total = total + 1
  @! 1000 * 1001 / 2 = 500500
  sum1000 = tail_sum(1000, 0)
  @if sum1000 == 500500
    passed = passed + 1
    println("  [PASS] BC-REC-03: Tail recursion sum 1..1000 (sum == 500500)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-03: Tail recursion sum")
  @end

  @! BC-REC-04: Ackermann Function Evaluation (A(2, 4) == 11)
  total = total + 1
  ack_res = ackermann(2, 4)
  @if ack_res == 11
    passed = passed + 1
    println("  [PASS] BC-REC-04: Ackermann function A(2, 4) == 11")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-04: Ackermann function")
  @end

  @! BC-REC-05: Stack Frame Restoration Verification
  total = total + 1
  canary1 = 12345
  dummy = deep_countdown(500)
  canary2 = 67890
  @if canary1 == 12345 && canary2 == 67890 && dummy == 0
    passed = passed + 1
    println("  [PASS] BC-REC-05: Stack frame restoration integrity verified with frame canaries")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-05: Stack frame restoration")
  @end

  @! BC-REC-06: Recursive Digit Counting
  total = total + 1
  d_cnt = count_digits_recursive(123456789)
  @if d_cnt == 9
    passed = passed + 1
    println("  [PASS] BC-REC-06: Recursive digit counting (123456789 has 9 digits)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-06: Recursive digit counting")
  @end

  @! BC-REC-07: Recursive Greatest Common Divisor (Euclid GCD)
  total = total + 1
  gcd_val = gcd_recursive(48, 18)
  @if gcd_val == 6
    passed = passed + 1
    println("  [PASS] BC-REC-07: Recursive Euclidean GCD(48, 18) == 6")
  @else
    failed = failed + 1
    println("  [FAIL] BC-REC-07: Recursive GCD")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Deep Recursion PASSED")
    return 0
  @else
    println("✗ Boundary: Deep Recursion FAILED")
    return 1
  @end
@end
