// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Nested Loops PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, nested_loops, loops, 4_levels, break, continue, stress

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: NESTED LOOPS
@! File: tests/e2e/tier2_boundaries/test_nested_loops.maya
@! ============================================================================

@fn four_level_nested_loop(d1, d2, d3, d4)
  count = 0
  i = 0
  @while i < d1
    j = 0
    @while j < d2
      k = 0
      @while k < d3
        l = 0
        @while l < d4
          count = count + 1
          l = l + 1
        @end
        k = k + 1
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return count
@end

@fn nested_break_test(rows, cols)
  sum = 0
  r = 0
  @while r < rows
    c = 0
    @while c < cols
      @if c == 2
        break  @! Inner loop terminates at c=2
      @end
      sum = sum + 1
      c = c + 1
    @end
    r = r + 1
  @end
  return sum
@end

@fn nested_continue_test(rows, cols)
  sum = 0
  r = 0
  @while r < rows
    r = r + 1
    @if r % 2 == 0
      continue  @! Skip even rows
    @end
    c = 0
    @while c < cols
      c = c + 1
      @if c % 2 == 0
        continue  @! Skip even cols
      @end
      sum = sum + 1
    @end
  @end
  return sum
@end

@fn high_iteration_loop(limit)
  count = 0
  i = 0
  @while i < limit
    count = count + 1
    i = i + 1
  @end
  return count
@end

@fn triangular_sum(n)
  sum = 0
  i = 1
  @while i <= n
    j = 1
    @while j <= i
      sum = sum + 1
      j = j + 1
    @end
    i = i + 1
  @end
  return sum
@end

@fn nested_step_loop(outer_max, inner_max)
  hits = 0
  i = 0
  @while i < outer_max
    j = 0
    @while j < inner_max
      hits = hits + 1
      j = j + 2
    @end
    i = i + 3
  @end
  return hits
@end

@fn nested_dual_accumulator(n)
  sum_a = 0
  sum_b = 0
  i = 0
  @while i < n
    j = 0
    @while j < n
      sum_a = sum_a + i
      sum_b = sum_b + j
      j = j + 1
    @end
    i = i + 1
  @end
  return sum_a + sum_b
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Nested Loops & Deep Controls")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-NLP-01: 4-Level Nested Loop Evaluation (2 x 3 x 2 x 2 = 24)
  total = total + 1
  c24 = four_level_nested_loop(2, 3, 2, 2)
  @if c24 == 24
    passed = passed + 1
    println("  [PASS] BC-NLP-01: 4-level nested loop executes 2x3x2x2 = 24 iterations")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-01: 4-level nested loop")
  @end

  @! BC-NLP-02: Inner Loop Early Break
  total = total + 1
  @! 5 rows, each inner loop breaks at c=2 (2 iterations per row) -> sum = 10
  b_sum = nested_break_test(5, 10)
  @if b_sum == 10
    passed = passed + 1
    println("  [PASS] BC-NLP-02: Inner loop break branches correctly to outer latch (sum == 10)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-02: Inner loop break")
  @end

  @! BC-NLP-03: Multi-Level Continue Control
  total = total + 1
  @! 6 rows (odd rows: 1, 3, 5 = 3 rows), 6 cols (odd cols: 1, 3, 5 = 3 cols) -> sum = 3 * 3 = 9
  c_sum = nested_continue_test(6, 6)
  @if c_sum == 9
    passed = passed + 1
    println("  [PASS] BC-NLP-03: Multi-level continue properly advances respective loop headers (sum == 9)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-03: Multi-level continue")
  @end

  @! BC-NLP-04: High Iteration Count Loop (50,000 iterations)
  total = total + 1
  high_cnt = high_iteration_loop(50000)
  @if high_cnt == 50000
    passed = passed + 1
    println("  [PASS] BC-NLP-04: 50,000-iteration loop executes monotonically without stack frame drift")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-04: High iteration loop")
  @end

  @! BC-NLP-05: Triangular Nested Loops (O(N^2))
  total = total + 1
  tri10 = triangular_sum(10)
  @! 10 * 11 / 2 = 55
  @if tri10 == 55
    passed = passed + 1
    println("  [PASS] BC-NLP-05: Triangular nested loop (triangular_sum(10) == 55)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-05: Triangular nested loop")
  @end

  @! BC-NLP-06: Non-Unit Step Increments in Nested Loops
  total = total + 1
  @! outer steps 0, 3, 6, 9 (4 steps), inner steps 0, 2, 4, 6, 8 (5 steps) -> 4 * 5 = 20 hits
  step_hits = nested_step_loop(10, 10)
  @if step_hits == 20
    passed = passed + 1
    println("  [PASS] BC-NLP-06: Non-unit step increments in nested loops (hits == 20)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-06: Nested step loop")
  @end

  @! BC-NLP-07: Nested Loop Symmetric Dual Accumulator
  total = total + 1
  @! for n=4: sum_a = 4 * (0+1+2+3) = 24, sum_b = 4 * (0+1+2+3) = 24 -> total = 48
  dual_acc = nested_dual_accumulator(4)
  @if dual_acc == 48
    passed = passed + 1
    println("  [PASS] BC-NLP-07: Nested symmetric dual accumulation (sum == 48)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NLP-07: Nested dual accumulator")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Nested Loops PASSED")
    return 0
  @else
    println("✗ Boundary: Nested Loops FAILED")
    return 1
  @end
@end
