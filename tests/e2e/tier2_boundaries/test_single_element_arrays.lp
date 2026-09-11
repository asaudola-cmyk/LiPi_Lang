// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Single Element Arrays PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, single_element, arrays, mutation, loop, range_for

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: SINGLE ELEMENT ARRAYS
@! File: tests/e2e/tier2_boundaries/test_single_element_arrays.maya
@! ============================================================================

import "universe/core/collections"

@fn sum_single_array(arr, length)
  sum = 0
  i = 0
  @while i < length
    sum = sum + arr[i]
    i = i + 1
  @end
  return sum
@end

@fn find_max_single(arr, length)
  max_val = arr[0]
  i = 1
  @while i < length
    @if arr[i] > max_val
      max_val = arr[i]
    @end
    i = i + 1
  @end
  return max_val
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Single Element Arrays")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-SEA-01: Single Element Array Allocation
  total = total + 1
  single_arr = [42]
  @if single_arr.len() == 1 && single_arr[0] == 42
    passed = passed + 1
    println("  [PASS] BC-SEA-01: Single element array [42] has length 1 and arr[0] == 42")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-01: Single element array allocation")
  @end

  @! BC-SEA-02: Single Element In-Place Mutation
  total = total + 1
  single_arr[0] = 999
  @if single_arr[0] == 999 && single_arr.len() == 1
    passed = passed + 1
    println("  [PASS] BC-SEA-02: In-place mutation of single element (single_arr[0] = 999)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-02: Single element mutation")
  @end

  @! BC-SEA-03: Loop Iteration over Single Element (1 iteration)
  total = total + 1
  s_sum = sum_single_array(single_arr, 1)
  @if s_sum == 999
    passed = passed + 1
    println("  [PASS] BC-SEA-03: Loop over single element array executes exactly 1 time (sum == 999)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-03: Single element iteration")
  @end

  @! BC-SEA-04: Finding Max in Single Element Array
  total = total + 1
  m_val = find_max_single(single_arr, 1)
  @if m_val == 999
    passed = passed + 1
    println("  [PASS] BC-SEA-04: find_max on single element array returns that element (999)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-04: Single element max search")
  @end

  @! BC-SEA-05: Pushing into Single Element Array (1 -> 2 items)
  total = total + 1
  arr_expand = [7]
  arr_expand.push(14)
  @if arr_expand.len() == 2 && arr_expand[0] == 7 && arr_expand[1] == 14
    passed = passed + 1
    println("  [PASS] BC-SEA-05: Expanding single element array via push (1 -> 2 items: [7, 14])")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-05: Single element push")
  @end

  @! BC-SEA-06: Range For Loop over 1-Element Range (0..1)
  total = total + 1
  r_cnt = 0
  r_val = -1
  @for i in 0..1
    r_cnt = r_cnt + 1
    r_val = i
  @end
  @if r_cnt == 1 && r_val == 0
    passed = passed + 1
    println("  [PASS] BC-SEA-06: Range for loop 0..1 executes exactly 1 iteration with i=0")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-06: 1-element range for loop")
  @end

  @! BC-SEA-07: In-Place Element Swapping with Self
  total = total + 1
  self_swap = [888]
  tmp = self_swap[0]
  self_swap[0] = tmp
  @if self_swap[0] == 888 && self_swap.len() == 1
    passed = passed + 1
    println("  [PASS] BC-SEA-07: Single element in-place self identity swap")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SEA-07: Single element self swap")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Single Element Arrays PASSED")
    return 0
  @else
    println("✗ Boundary: Single Element Arrays FAILED")
    return 1
  @end
@end
