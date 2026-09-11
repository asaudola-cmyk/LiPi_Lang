@! ============================================================================
@! MAYA ADVERSARIAL STRESS SUITE: MEMORY ALLOCATIONS & DYNAMIC ARRAYS
@! File: tests/stress/test_stress_memory_arrays.maya
@! ============================================================================

@fn binary_search(arr, length, target)
  low = 0
  high = length - 1
  @while low <= high
    mid = (low + high) / 2
    val = arr[mid]
    @if val == target
      return mid
    @elif val < target
      low = mid + 1
    @else
      high = mid - 1
    @end
  @end
  return -1
@end

@fn partition(arr, low, high)
  pivot = arr[high]
  i = low - 1
  j = low
  @while j < high
    @if arr[j] <= pivot
      i = i + 1
      temp = arr[i]
      arr[i] = arr[j]
      arr[j] = temp
    @end
    j = j + 1
  @end
  temp2 = arr[i + 1]
  arr[i + 1] = arr[high]
  arr[high] = temp2
  return i + 1
@end

@fn quicksort(arr, low, high)
  @if low < high
    pi = partition(arr, low, high)
    quicksort(arr, low, pi - 1)
    quicksort(arr, pi + 1, high)
  @end
  return arr
@end

@fn is_sorted(arr, length)
  i = 0
  @while i < length - 1
    @if arr[i] > arr[i + 1]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST 2: MEMORY ALLOCATIONS & DYNAMIC ARRAYS 🔥")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Stress 2.1: Large Dynamic Array Sequential Push (20,000 Elements)
  total = total + 1
  large_arr = []
  i = 0
  @while i < 20000
    large_arr.push(i * 3 + 1)
    i = i + 1
  @end

  len20k = large_arr.len()
  elem0 = large_arr[0]
  elem10k = large_arr[10000]
  elem19999 = large_arr[19999]

  @if len20k == 20000 && elem0 == 1 && elem10k == 30001 && elem19999 == 59998
    passed = passed + 1
    println("  [PASS] S2.1: Dynamic array push 20,000 elements (len == 20000, bounds checked)")
  @else
    failed = failed + 1
    println("  [FAIL] S2.1: Dynamic array push 20,000 elements")
  @end

  @! Stress 2.2: In-place Reversal of 20,000 Element Array
  total = total + 1
  l_idx = 0
  r_idx = large_arr.len() - 1
  @while l_idx < r_idx
    tmp = large_arr[l_idx]
    large_arr[l_idx] = large_arr[r_idx]
    large_arr[r_idx] = tmp
    l_idx = l_idx + 1
    r_idx = r_idx - 1
  @end

  rev_elem0 = large_arr[0]
  rev_elem10k = large_arr[10000]
  rev_elem19999 = large_arr[19999]

  @if rev_elem0 == 59998 && rev_elem10k == 29998 && rev_elem19999 == 1
    passed = passed + 1
    println("  [PASS] S2.2: In-place reversal of 20,000 elements (rev[0] == 59998, rev[19999] == 1)")
  @else
    failed = failed + 1
    println("  [FAIL] S2.2: In-place reversal of 20,000 elements (got " + rev_elem0.to_str() + ", " + rev_elem10k.to_str() + ", " + rev_elem19999.to_str() + ")")
  @end

  @! Stress 2.3: Binary Search on 15,000 Sorted Elements
  total = total + 1
  sorted_arr = []
  si = 0
  @while si < 15000
    sorted_arr.push(si * 5 + 2)
    si = si + 1
  @end

  bs_idx0 = binary_search(sorted_arr, 15000, 2)
  bs_idx7500 = binary_search(sorted_arr, 15000, 7500 * 5 + 2)
  bs_idx14999 = binary_search(sorted_arr, 15000, 14999 * 5 + 2)
  bs_missing = binary_search(sorted_arr, 15000, 999999)

  @if bs_idx0 == 0 && bs_idx7500 == 7500 && bs_idx14999 == 14999 && bs_missing == -1
    passed = passed + 1
    println("  [PASS] S2.3: Binary search on 15,000 sorted elements (found 0, 7500, 14999; rejected missing)")
  @else
    failed = failed + 1
    println("  [FAIL] S2.3: Binary search on 15,000 sorted elements")
  @end

  @! Stress 2.4: Recursive Quicksort on 2,000 Pseudorandom Elements
  total = total + 1
  rand_arr = []
  seed = 12345
  ri = 0
  @while ri < 2000
    seed = (seed * 1103515245 + 12345) % 2147483648
    rand_arr.push(seed % 10000)
    ri = ri + 1
  @end

  quicksort(rand_arr, 0, 1999)
  sorted_ok = is_sorted(rand_arr, 2000)

  @if sorted_ok == 1 && rand_arr.len() == 2000
    passed = passed + 1
    println("  [PASS] S2.4: Recursive quicksort on 2,000 pseudorandom elements (verified sorted)")
  @else
    failed = failed + 1
    println("  [FAIL] S2.4: Recursive quicksort on 2,000 pseudorandom elements")
  @end

  @! Stress 2.5: Boehm GC Memory Churn & Recycling (10,000 Dynamic Array Allocations)
  total = total + 1
  gc_iter = 0
  grand_total_sum = 0
  @while gc_iter < 10000
    temp_arr = []
    ti = 0
    @while ti < 20
      temp_arr.push(ti)
      ti = ti + 1
    @end
    @! sum of 0..19 = 19 * 20 / 2 = 190
    t_sum = 0
    ti = 0
    @while ti < 20
      t_sum = t_sum + temp_arr[ti]
      ti = ti + 1
    @end
    grand_total_sum = grand_total_sum + t_sum
    gc_iter = gc_iter + 1
  @end

  @! 10000 * 190 = 1900000
  @if grand_total_sum == 1900000
    passed = passed + 1
    println("  [PASS] S2.5: Boehm GC churn (10,000 arrays allocated & recycled, checksum == 1900000)")
  @else
    failed = failed + 1
    println("  [FAIL] S2.5: Boehm GC churn (checksum == " + grand_total_sum.to_str() + ")")
  @end

  println("-----------------------------------------------------------------")
  println("Stress Suite 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ ALL MEMORY & ARRAY STRESS TESTS PASSED")
    return 0
  @else
    println("✗ MEMORY & ARRAY STRESS TESTS FAILED")
    return 1
  @end
@end
