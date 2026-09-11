// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Dynamic Arrays PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: arrays, collections, indexing, mutation, push, matrix

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: DYNAMIC ARRAYS
@! File: tests/e2e/tier1_features/test_arrays.maya
@! ============================================================================

@fn sum_array(arr, length)
  sum = 0
  i = 0
  @while i < length
    sum = sum + arr[i]
    i = i + 1
  @end
  return sum
@end

@fn find_max(arr, length)
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
  println("▶ [TIER 1] Feature: Dynamic Arrays")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-ARR-01: Array Literal Creation & Initialization
  total = total + 1
  nums = [10, 20, 30, 40, 50]
  @if nums[0] == 10 && nums[2] == 30 && nums[4] == 50
    passed = passed + 1
    println("  [PASS] TC-ARR-01: Array literal initialization ([10, 20, 30, 40, 50])")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-01: Array literal initialization")
  @end

  @! TC-ARR-02: Array Element Mutation
  total = total + 1
  nums[1] = 99
  nums[3] = 77
  @if nums[1] == 99 && nums[3] == 77 && nums[0] == 10
    passed = passed + 1
    println("  [PASS] TC-ARR-02: Array element mutation (nums[1] = 99, nums[3] = 77)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-02: Array element mutation")
  @end

  @! TC-ARR-03: Array Summation via Loop
  total = total + 1
  @! Array is now [10, 99, 30, 77, 50] -> sum = 266
  arr_sum = sum_array(nums, 5)
  @if arr_sum == 266
    passed = passed + 1
    println("  [PASS] TC-ARR-03: Array element iteration and summation (sum == 266)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-03: Array summation")
  @end

  @! TC-ARR-04: Array Max Value Search
  total = total + 1
  max_item = find_max(nums, 5)
  @if max_item == 99
    passed = passed + 1
    println("  [PASS] TC-ARR-04: Finding max element in dynamic array (max == 99)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-04: Finding max element")
  @end

  @! TC-ARR-05: Dynamic Array Pushing
  total = total + 1
  dynamic_list = [1, 2, 3]
  dynamic_list.push(4)
  dynamic_list.push(5)
  @if dynamic_list[3] == 4 && dynamic_list[4] == 5 && dynamic_list.len() == 5
    passed = passed + 1
    println("  [PASS] TC-ARR-05: Dynamic array push appending new items (4, 5)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-05: Dynamic array push")
  @end

  @! TC-ARR-06: Multi-Dimensional / Matrix Indexing
  total = total + 1
  matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
  diag_sum = matrix[0][0] + matrix[1][1] + matrix[2][2]
  @! 1 + 5 + 9 = 15
  @if diag_sum == 15 && matrix[1][2] == 6
    passed = passed + 1
    println("  [PASS] TC-ARR-06: Multi-dimensional array matrix indexing (diag_sum == 15)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ARR-06: Multi-dimensional array matrix indexing")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Dynamic Arrays PASSED")
    return 0
  @else
    println("✗ Feature: Dynamic Arrays FAILED")
    return 1
  @end
@end
