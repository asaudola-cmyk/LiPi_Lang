// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: For Loops PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: for, range, array_iteration, break, continue, nested_loops

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: FOR..IN LOOPS
@! File: tests/e2e/tier1_features/test_for_loops.maya
@! ============================================================================

@fn sum_range(start, finish)
  total = 0
  @for i in start..finish
    total = total + i
  @end
  return total
@end

@fn sum_array(arr)
  total = 0
  @for x in arr
    total = total + x
  @end
  return total
@end

@fn find_break_in_range(limit, target)
  total = 0
  @for i in 0..limit
    @if i == target
      break
    @end
    total = total + i
  @end
  return total
@end

@fn count_matrix_cells(r_max, c_max)
  count = 0
  @for r in 0..r_max
    @for c in 0..c_max
      count = count + 1
    @end
  @end
  return count
@end

@fn sum_even_range(limit)
  total = 0
  @for i in 0..limit
    @if i % 2 != 0
      continue
    @end
    total = total + i
  @end
  return total
@end

@fn sum_squares_in_array(arr)
  total = 0
  @for x in arr
    total = total + x * x
  @end
  return total
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: For..In Range & Collection Loops")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-FOR-01: Range For Loop Summation (0..10)
  total = total + 1
  s10 = sum_range(0, 10)
  @! 0+1+2+3+4+5+6+7+8+9 = 45
  @if s10 == 45
    passed = passed + 1
    println("  [PASS] TC-FOR-01: sum_range(0, 10) == 45")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-01: sum_range")
  @end

  @! TC-FOR-02: Array Element Iteration
  total = total + 1
  arr = [10, 20, 30, 40, 50]
  arr_sum = sum_array(arr)
  @if arr_sum == 150
    passed = passed + 1
    println("  [PASS] TC-FOR-02: sum_array([10,20,30,40,50]) == 150")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-02: sum_array")
  @end

  @! TC-FOR-03: Range For Loop with Break
  total = total + 1
  b_sum = find_break_in_range(100, 6)
  @! 0+1+2+3+4+5 = 15
  @if b_sum == 15
    passed = passed + 1
    println("  [PASS] TC-FOR-03: find_break_in_range(100, 6) == 15")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-03: for break")
  @end

  @! TC-FOR-04: Nested Range For Loops (Matrix Grid)
  total = total + 1
  cells = count_matrix_cells(4, 6)
  @! 4 * 6 = 24
  @if cells == 24
    passed = passed + 1
    println("  [PASS] TC-FOR-04: count_matrix_cells(4, 6) == 24")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-04: nested for loops")
  @end

  @! TC-FOR-05: Range For Loop with Continue
  total = total + 1
  evens = sum_even_range(10)
  @! 0 + 2 + 4 + 6 + 8 = 20
  @if evens == 20
    passed = passed + 1
    println("  [PASS] TC-FOR-05: sum_even_range(10) == 20 (continue)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-05: for continue")
  @end

  @! TC-FOR-06: Array Elements Computations (Sum of Squares)
  total = total + 1
  items = [2, 3, 5, 7]
  sq_sum = sum_squares_in_array(items)
  @! 4 + 9 + 25 + 49 = 87
  @if sq_sum == 87
    passed = passed + 1
    println("  [PASS] TC-FOR-06: sum_squares_in_array([2,3,5,7]) == 87")
  @else
    failed = failed + 1
    println("  [FAIL] TC-FOR-06: sum_squares_in_array")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: For Loops PASSED")
    return 0
  @else
    println("✗ Feature: For Loops FAILED")
    return 1
  @end
@end
