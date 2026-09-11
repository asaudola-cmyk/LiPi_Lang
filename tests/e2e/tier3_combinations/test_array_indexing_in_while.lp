@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: ARRAY INDEXING & MUTATION IN WHILE LOOPS
@! File: tests/e2e/tier3_combinations/test_array_indexing_in_while.maya
@! ============================================================================

import "universe/core/collections"

@fn reverse_array_inplace(arr, length)
  left = 0
  right = length - 1
  @while left < right
    tmp = arr[left]
    arr[left] = arr[right]
    arr[right] = tmp
    left = left + 1
    right = right - 1
  @end
  return arr
@end

@fn compute_prefix_sums(arr, length)
  prefixes = []
  running = 0
  i = 0
  @while i < length
    running = running + arr[i]
    prefixes.push(running)
    i = i + 1
  @end
  return prefixes
@end

@fn max_sliding_window_sum(arr, length, k)
  @! Compute max sum of contiguous sub-array of length k
  window_sum = 0
  i = 0
  @while i < k
    window_sum = window_sum + arr[i]
    i = i + 1
  @end
  max_sum = window_sum
  j = k
  @while j < length
    window_sum = window_sum - arr[j - k] + arr[j]
    @if window_sum > max_sum
      max_sum = window_sum
    @end
    j = j + 1
  @end
  return max_sum
@end

@fn count_even_numbers(arr, length)
  evens = 0
  i = 0
  @while i < length
    @if arr[i] % 2 == 0
      evens = evens + 1
    @end
    i = i + 1
  @end
  return evens
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 5: Array Indexing & Mutation in While Loops")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.21: In-place Array Reversal with Two Pointers
  total = total + 1
  nums = [1, 2, 3, 4, 5]
  rev = reverse_array_inplace(nums, 5)
  @if rev[0] == 5 && rev[1] == 4 && rev[2] == 3 && rev[3] == 2 && rev[4] == 1
    passed = passed + 1
    println("  [PASS] T3.21: Two-pointer in-place array reversal ([5, 4, 3, 2, 1])")
  @else
    failed = failed + 1
    println("  [FAIL] T3.21: Two-pointer in-place array reversal")
  @end

  @! T3.22: Prefix Sum Array Computation
  total = total + 1
  orig = [10, 20, 30, 40]
  pfx = compute_prefix_sums(orig, 4)
  @! [10, 30, 60, 100]
  @if pfx[0] == 10 && pfx[1] == 30 && pfx[2] == 60 && pfx[3] == 100
    passed = passed + 1
    println("  [PASS] T3.22: Prefix sum accumulation in dynamic array ([10, 30, 60, 100])")
  @else
    failed = failed + 1
    println("  [FAIL] T3.22: Prefix sum accumulation")
  @end

  @! T3.23: Sliding Window Sum of Size K = 3
  total = total + 1
  arr_data = [2, 1, 5, 1, 3, 2]
  @! Window size 3:
  @! [2,1,5] = 8, [1,5,1] = 7, [5,1,3] = 9, [1,3,2] = 6 -> max = 9
  max_win = max_sliding_window_sum(arr_data, 6, 3)
  @if max_win == 9
    passed = passed + 1
    println("  [PASS] T3.23: Sliding window max sum over dynamic array (max_win == 9)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.23: Sliding window max sum")
  @end

  @! T3.24: Filtering Evens in Array via Modulo in While Loop
  total = total + 1
  mixed = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  even_count = count_even_numbers(mixed, 10)
  @if even_count == 5
    passed = passed + 1
    println("  [PASS] T3.24: Even integer counting via loop indexing (even_count == 5)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.24: Even integer counting")
  @end

  @! T3.25: Array Element Swapping based on Index Parity
  total = total + 1
  parity_arr = [10, 20, 30, 40]
  k = 0
  @while k < 4
    parity_arr[k] = parity_arr[k] + k
    k = k + 1
  @end
  @! [10+0, 20+1, 30+2, 40+3] = [10, 21, 32, 43]
  @if parity_arr[0] == 10 && parity_arr[1] == 21 && parity_arr[2] == 32 && parity_arr[3] == 43
    passed = passed + 1
    println("  [PASS] T3.25: Index-dependent array arithmetic transformation ([10, 21, 32, 43])")
  @else
    failed = failed + 1
    println("  [FAIL] T3.25: Index-dependent array transformation")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 5 (Array Indexing in Loops) PASSED")
    return 0
  @else
    println("✗ Combination 5 (Array Indexing in Loops) FAILED")
    return 1
  @end
@end
