@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: LOOPS (@while)
@! File: tests/e2e/tier1_features/test_loops.maya
@! ============================================================================

@fn sum_1_to_n(n)
  sum = 0
  i = 1
  @while i <= n
    sum = sum + i
    i = i + 1
  @end
  return sum
@end

@fn count_down(start)
  count = 0
  i = start
  @while i > 0
    count = count + 1
    i = i - 1
  @end
  return count
@end

@fn compute_power(base, exp)
  result = 1
  i = 0
  @while i < exp
    result = result * base
    i = i + 1
  @end
  return result
@end

@fn step_loop(limit, step)
  hits = 0
  i = 0
  @while i < limit
    hits = hits + 1
    i = i + step
  @end
  return hits
@end

@fn search_with_flag(target)
  found = -1
  i = 0
  done = 0
  @while done == 0 && i < 100
    @if i == target
      found = i
      done = 1
    @else
      i = i + 1
    @end
  @end
  return found
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 7: Loops (@while)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.38: While Loop Counter
  total = total + 1
  cd_res = count_down(20)
  @if cd_res == 20
    passed = passed + 1
    println("  [PASS] T1.38: Basic @while loop downward counter (count_down(20) == 20)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.38: Basic @while loop counter")
  @end

  @! T1.39: Accumulator While Loop (Sum 1 to 100)
  total = total + 1
  @! 100 * 101 / 2 = 5050
  sum100 = sum_1_to_n(100)
  @if sum100 == 5050
    passed = passed + 1
    println("  [PASS] T1.39: Accumulator loop sum 1..100 (sum == 5050)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.39: Accumulator loop sum")
  @end

  @! T1.40: Power Calculation Loop (2^10 = 1024, 3^4 = 81)
  total = total + 1
  p2_10 = compute_power(2, 10)
  p3_4 = compute_power(3, 4)
  @if p2_10 == 1024 && p3_4 == 81
    passed = passed + 1
    println("  [PASS] T1.40: Power computation (2^10 == 1024, 3^4 == 81)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.40: Power computation")
  @end

  @! T1.41: While Loop with Step Size
  total = total + 1
  step_hits = step_loop(50, 5)
  @! 0, 5, 10, 15, 20, 25, 30, 35, 40, 45 -> 10 iterations
  @if step_hits == 10
    passed = passed + 1
    println("  [PASS] T1.41: While loop with non-unit step (50 step 5 -> 10 iterations)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.41: While loop with non-unit step")
  @end

  @! T1.42: While Loop with Termination Flag
  total = total + 1
  search_res = search_with_flag(42)
  @if search_res == 42
    passed = passed + 1
    println("  [PASS] T1.42: While loop with early exit termination flag (target 42)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.42: While loop with termination flag")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 7 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature 7 (Loops) PASSED")
    return 0
  @else
    println("✗ Feature 7 (Loops) FAILED")
    return 1
  @end
@end
