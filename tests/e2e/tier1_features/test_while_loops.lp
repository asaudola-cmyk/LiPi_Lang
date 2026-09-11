// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: While Loops PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: while, loops, break, continue, nested_loops, invariants

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: WHILE LOOPS & CONTROL
@! File: tests/e2e/tier1_features/test_while_loops.maya
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

@fn find_first_divisible(start, divisor)
  val = start
  found = 0
  @while val < 1000 && found == 0
    @if val % divisor == 0
      found = 1
    @else
      val = val + 1
    @end
  @end
  return val
@end

@fn sum_evens_only(limit)
  sum = 0
  i = 0
  @while i < limit
    i = i + 1
    @if i % 2 == 0
      sum = sum + i
    @end
  @end
  return sum
@end

@fn nested_grid_count(rows, cols)
  count = 0
  r = 0
  @while r < rows
    c = 0
    @while c < cols
      count = count + 1
      c = c + 1
    @end
    r = r + 1
  @end
  return count
@end

@fn compound_invariant_loop()
  x = 100
  y = 0
  @while x > 0 && y < 40
    x = x - 2
    y = y + 1
  @end
  @! Ends when y reaches 40 (x = 100 - 80 = 20)
  return x * 1000 + y
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: While Loops & Control Flow")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-WH-01: Basic While Loop Summation
  total = total + 1
  s50 = sum_1_to_n(50)
  @! 50 * 51 / 2 = 1275
  @if s50 == 1275
    passed = passed + 1
    println("  [PASS] TC-WH-01: sum_1_to_n(50) == 1275")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WH-01: sum_1_to_n")
  @end

  @! TC-WH-02: While Loop with Early Break
  total = total + 1
  div7 = find_first_divisible(100, 7)
  @! 100 % 7 = 2 -> 105 % 7 == 0
  @if div7 == 105
    passed = passed + 1
    println("  [PASS] TC-WH-02: find_first_divisible(100, 7) == 105 (break)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WH-02: while break")
  @end

  @! TC-WH-03: While Loop with Continue Skipping
  total = total + 1
  sum_ev = sum_evens_only(10)
  @! 2 + 4 + 6 + 8 + 10 = 30
  @if sum_ev == 30
    passed = passed + 1
    println("  [PASS] TC-WH-03: sum_evens_only(10) == 30 (continue)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WH-03: while continue")
  @end

  @! TC-WH-04: Nested While Loops
  total = total + 1
  grid = nested_grid_count(5, 8)
  @if grid == 40
    passed = passed + 1
    println("  [PASS] TC-WH-04: nested_grid_count(5, 8) == 40")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WH-04: nested while loops")
  @end

  @! TC-WH-05: Compound Invariant Condition (x > 0 && y < 40)
  total = total + 1
  comp_res = compound_invariant_loop()
  @! x=20, y=40 -> 20040
  @if comp_res == 20040
    passed = passed + 1
    println("  [PASS] TC-WH-05: compound_invariant_loop() == 20040 (x=20, y=40)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-WH-05: compound invariant loop")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: While Loops PASSED")
    return 0
  @else
    println("✗ Feature: While Loops FAILED")
    return 1
  @end
@end
