@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: CALLBACKS & ARRAY COMBINATORS
@! File: tests/e2e/tier3_combinations/test_callbacks_array_combinators.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/core/collections"

@fn double_val(x)
  return x * 2
@end

@fn square_val(x)
  return x * x
@end

@fn is_even(x)
  @if x % 2 == 0
    return 1
  @else
    return 0
  @end
@end

@fn is_gt_10(x)
  @if x > 10
    return 1
  @else
    return 0
  @end
@end

@fn sum_reducer(acc, x)
  return acc + x
@end

@fn mult_reducer(acc, x)
  return acc * x
@end

@fn max_reducer(acc, x)
  @if x > acc
    return x
  @else
    return acc
  @end
@end

@fn custom_find(arr, pred_fn)
  len = arr.len()
  i = 0
  @while i < len
    @if pred_fn(arr[i]) == 1
      return arr[i]
    @end
    i = i + 1
  @end
  return -1
@end

@fn custom_all(arr, pred_fn)
  len = arr.len()
  i = 0
  @while i < len
    @if pred_fn(arr[i]) != 1
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 2: Callbacks & Array Combinators")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  @! T3.2.1: list_filter with predicate callback (extract even numbers)
  total = total + 1
  evens = list_filter(numbers, is_even)
  @if evens.len() == 5 && evens[0] == 2 && evens[1] == 4 && evens[2] == 6 && evens[3] == 8 && evens[4] == 10
    passed = passed + 1
    println("  [PASS] T3.2.1: list_filter extracts 5 even numbers [2, 4, 6, 8, 10]")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2.1: list_filter failed")
  @end

  @! T3.2.2: list_map with transform callback (double values)
  total = total + 1
  doubled = list_map(evens, double_val)
  @if doubled.len() == 5 && doubled[0] == 4 && doubled[1] == 8 && doubled[2] == 12 && doubled[3] == 16 && doubled[4] == 20
    passed = passed + 1
    println("  [PASS] T3.2.2: list_map doubles values to [4, 8, 12, 16, 20]")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2.2: list_map failed")
  @end

  @! T3.2.3: list_reduce with accumulator callback (sum == 60)
  total = total + 1
  sum_result = list_reduce(doubled, sum_reducer, 0)
  @if sum_result == 60
    passed = passed + 1
    println("  [PASS] T3.2.3: list_reduce correctly accumulates sum == 60")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2.3: list_reduce expected 60, got " + int_to_str(sum_result))
  @end

  @! T3.2.4: Chained combinator pipeline (filter -> map -> reduce)
  total = total + 1
  @! [1, 2, 3, 4, 5] -> map square [1, 4, 9, 16, 25] -> filter gt 10 [16, 25] -> reduce sum = 41
  base_5 = [1, 2, 3, 4, 5]
  sq_5 = list_map(base_5, square_val)
  gt10_5 = list_filter(sq_5, is_gt_10)
  chain_sum = list_reduce(gt10_5, sum_reducer, 0)
  @if chain_sum == 41
    passed = passed + 1
    println("  [PASS] T3.2.4: Chained pipeline (map sq -> filter >10 -> reduce sum == 41)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2.4: Chained pipeline failed, got " + int_to_str(chain_sum))
  @end

  @! T3.2.5: Custom predicate searches (custom_find and custom_all)
  total = total + 1
  first_gt10 = custom_find(sq_5, is_gt_10)
  all_even_check = custom_all(evens, is_even)
  all_even_check_fail = custom_all(numbers, is_even)
  @if first_gt10 == 16 && all_even_check == 1 && all_even_check_fail == 0
    passed = passed + 1
    println("  [PASS] T3.2.5: Higher-order search predicates (find == 16, all_even == 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2.5: Higher-order search predicates failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 2 (Callbacks & Array Combinators) PASSED")
    return 0
  @else
    println("✗ Combination 2 (Callbacks & Array Combinators) FAILED")
    return 1
  @end
@end
