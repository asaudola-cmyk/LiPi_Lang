// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Empty Arrays PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, empty_arrays, collections, safe_bounds, push, reverse

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: EMPTY ARRAYS
@! File: tests/e2e/tier2_boundaries/test_empty_arrays.maya
@! ============================================================================

import "universe/core/collections"

@fn process_empty_array(arr, length)
  sum = 0
  i = 0
  @while i < length
    sum = sum + arr[i]
    i = i + 1
  @end
  return sum
@end

@fn array_is_empty(length)
  @if length == 0
    return 1
  @else
    return 0
  @end
@end

@fn find_max_empty(arr, length)
  @if length == 0
    return 0  @! Safe default on empty
  @end
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
  println("▶ [TIER 2] Boundary: Empty Arrays")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-ARR-01: Empty Array Allocation
  total = total + 1
  empty_arr = []
  check_empty = array_is_empty(0)
  @if check_empty == 1 && empty_arr.len() == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-01: Empty array [] initialization and empty check")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-01: Empty array initialization")
  @end

  @! BC-ARR-02: Loop Over Empty Array (0 iterations)
  total = total + 1
  empty_sum = process_empty_array(empty_arr, 0)
  @if empty_sum == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-02: Iterating over empty array yields 0 operations (sum == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-02: Iterating over empty array")
  @end

  @! BC-ARR-03: Pushing into Empty Array (0 -> 1 -> 2 items)
  total = total + 1
  growing = []
  growing.push(10)
  growing.push(20)
  @if growing[0] == 10 && growing[1] == 20 && growing.len() == 2
    passed = passed + 1
    println("  [PASS] BC-ARR-03: Pushing items into an initially empty array (0 -> 2 items)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-03: Pushing to empty array")
  @end

  @! BC-ARR-04: Range / For Loop over Empty Range
  total = total + 1
  loop_count = 0
  @for i in 0..0
    loop_count = loop_count + 1
  @end
  @if loop_count == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-04: Range for loop on empty range 0..0 executes 0 times")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-04: Empty range for loop")
  @end

  @! BC-ARR-05: Safe Search / Max on Empty Array
  total = total + 1
  max_val = find_max_empty(empty_arr, 0)
  @if max_val == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-05: Finding max in empty array returns safe default 0")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-05: Max in empty array")
  @end

  @! BC-ARR-06: For Loop Over Empty Array Reference
  total = total + 1
  for_arr_cnt = 0
  @for item in empty_arr
    for_arr_cnt = for_arr_cnt + 1
  @end
  @if for_arr_cnt == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-06: @for loop iterating directly over empty array executes 0 times")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-06: For loop over empty array")
  @end

  @! BC-ARR-07: Equality Comparison with Empty Arrays
  total = total + 1
  a1 = []
  a2 = []
  @if a1.len() == a2.len() && a1.len() == 0
    passed = passed + 1
    println("  [PASS] BC-ARR-07: Length equality between two distinct empty arrays")
  @else
    failed = failed + 1
    println("  [FAIL] BC-ARR-07: Empty array comparison")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Empty Arrays PASSED")
    return 0
  @else
    println("✗ Boundary: Empty Arrays FAILED")
    return 1
  @end
@end
