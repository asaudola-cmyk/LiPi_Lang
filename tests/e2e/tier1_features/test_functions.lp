@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: FUNCTIONS & CALLS
@! File: tests/e2e/tier1_features/test_functions.maya
@! ============================================================================

@fn square(x)
  return x * x
@end

@fn sum_of_squares(a, b)
  return square(a) + square(b)
@end

@fn early_return_check(val)
  @if val < 0
    return -1
  @elif val == 0
    return 0
  @else
    return 1
  @end
@end

@fn factorial(n)
  @if n <= 1
    return 1
  @else
    return n * factorial(n - 1)
  @end
@end

@fn multi_arg_sum(a, b, c, d, e)
  return a + b + c + d + e
@end

@fn local_scope_test(x)
  y = x * 2
  z = y + 10
  return z
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 5: Functions & Scope")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.26: Basic Function Parameter Passing & Return
  total = total + 1
  sq_val = square(9)
  @if sq_val == 81
    passed = passed + 1
    println("  [PASS] T1.26: Function parameter passing and return value (square(9) == 81)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.26: Function parameter passing")
  @end

  @! T1.27: Function Composition (Calling other functions)
  total = total + 1
  sos_val = sum_of_squares(3, 4)
  @! 3^2 + 4^2 = 9 + 16 = 25
  @if sos_val == 25
    passed = passed + 1
    println("  [PASS] T1.27: Function composition (sum_of_squares(3, 4) == 25)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.27: Function composition")
  @end

  @! T1.28: Local Variable Scoping
  total = total + 1
  y = 999
  scoped_res = local_scope_test(5)
  @! 5 * 2 + 10 = 20
  @if scoped_res == 20 && y == 999
    passed = passed + 1
    println("  [PASS] T1.28: Local variable lexical scope isolation (outer y remains 999)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.28: Local variable scoping")
  @end

  @! T1.29: Recursive Function (Factorial)
  total = total + 1
  fact5 = factorial(5)
  @! 5! = 120
  fact6 = factorial(6)
  @! 6! = 720
  @if fact5 == 120 && fact6 == 720
    passed = passed + 1
    println("  [PASS] T1.29: Recursive function evaluation (factorial(5) == 120, factorial(6) == 720)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.29: Recursive function evaluation")
  @end

  @! T1.30: Early Return in Conditionals
  total = total + 1
  r_neg = early_return_check(-10)
  r_zero = early_return_check(0)
  r_pos = early_return_check(42)
  @if r_neg == -1 && r_zero == 0 && r_pos == 1
    passed = passed + 1
    println("  [PASS] T1.30: Early returns across branching paths (-1, 0, 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.30: Early returns across branching paths")
  @end

  @! T1.31: Multiple Arguments Function (5 arguments)
  total = total + 1
  five_sum = multi_arg_sum(10, 20, 30, 40, 50)
  @if five_sum == 150
    passed = passed + 1
    println("  [PASS] T1.31: Multi-argument function invocation (sum == 150)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.31: Multi-argument function invocation")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature 5 (Functions) PASSED")
    return 0
  @else
    println("✗ Feature 5 (Functions) FAILED")
    return 1
  @end
@end
