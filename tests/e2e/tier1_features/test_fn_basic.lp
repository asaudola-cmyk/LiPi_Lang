// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Basic Functions & Calls PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: functions, abi, recursion, scoping, returns

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: FUNCTIONS & CALLS
@! File: tests/e2e/tier1_features/test_fn_basic.maya
@! ============================================================================

@fn add(a: i64, b: i64) -> i64
  return a + b
@end

@fn sum6(a, b, c, d, e, f)
  return a + b + c + d + e + f
@end

@fn sum8(a, b, c, d, e, f, g, h)
  return a + b + c + d + e + f + g + h
@end

@fn fib(n)
  @if n <= 1
    return n
  @else
    return fib(n - 1) + fib(n - 2)
  @end
@end

@fn sign(x)
  @if x > 0
    return 1
  @elif x < 0
    return -1
  @else
    return 0
  @end
@end

@fn scope_shadowing(val)
  a = val * 2
  b = a + 10
  res = 0
  @if b > 15
    a = 100
    res = a + b
  @else
    res = b
  @end
  return res + a
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Functions, ABI Spilling & Scoping")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-FN-01: Basic Function Parameter Passing & Return
  total = total + 1
  sum_ab = add(40, 2)
  @if sum_ab == 42
    passed = passed + 1
    println("  [PASS] TC-FN-01: add(40, 2) == 42")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-01: add(40, 2)")
  @end

  @! TC-FN-02: Multi-Argument ABI Register Passing (6 args)
  total = total + 1
  s6 = sum6(1, 2, 3, 4, 5, 6)
  @if s6 == 21
    passed = passed + 1
    println("  [PASS] TC-FN-02: sum6(1,2,3,4,5,6) == 21")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-02: sum6")
  @end

  @! TC-FN-03: Stack Argument Spilling (>6 args: 8 args)
  total = total + 1
  s8 = sum8(10, 20, 30, 40, 50, 60, 70, 80)
  @if s8 == 360
    passed = passed + 1
    println("  [PASS] TC-FN-03: sum8(10,20,30,40,50,60,70,80) == 360")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-03: sum8 stack argument spilling")
  @end

  @! TC-FN-04: Recursive Fibonacci & Call Stack
  total = total + 1
  fib10 = fib(10)
  fib7 = fib(7)
  @if fib10 == 55 && fib7 == 13
    passed = passed + 1
    println("  [PASS] TC-FN-04: fib(10) == 55, fib(7) == 13")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-04: recursive fibonacci")
  @end

  @! TC-FN-05: Early Return Across Branching Paths
  total = total + 1
  s_neg = sign(-55)
  s_pos = sign(100)
  s_zero = sign(0)
  @if s_neg == -1 && s_pos == 1 && s_zero == 0
    passed = passed + 1
    println("  [PASS] TC-FN-05: sign(-55) == -1, sign(100) == 1, sign(0) == 0")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-05: early return sign")
  @end

  @! TC-FN-06: Local Variable Scoping & Shadowing
  total = total + 1
  @! scope_shadowing(5): a=10, b=20. b>15 -> inner a=100 -> res=120. outer a=10 -> return 120 + 10 = 130
  scope_res = scope_shadowing(5)
  @if scope_res == 130
    passed = passed + 1
    println("  [PASS] TC-FN-06: scope_shadowing(5) == 130")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FN-06: scope_shadowing")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Basic Functions & Calls PASSED")
    return 0
  @else
    println("✗ Feature: Basic Functions & Calls FAILED")
    return 1
  @end
@end
