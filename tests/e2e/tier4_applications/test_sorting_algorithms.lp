@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP 1: SORTING ALGORITHMS
@! File: tests/e2e/tier4_applications/test_sorting_algorithms.maya
@! ============================================================================

import "universe/core/collections"

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

@fn insertion_sort(arr, length)
  i = 1
  @while i < length
    key = arr[i]
    j = i - 1
    @while j >= 0 && arr[j] > key
      arr[j + 1] = arr[j]
      j = j - 1
    @end
    arr[j + 1] = key
    i = i + 1
  @end
  return arr
@end

@fn selection_sort(arr, length)
  i = 0
  @while i < length - 1
    min_idx = i
    j = i + 1
    @while j < length
      @if arr[j] < arr[min_idx]
        min_idx = j
      @end
      j = j + 1
    @end
    tmp = arr[i]
    arr[i] = arr[min_idx]
    arr[min_idx] = tmp
    i = i + 1
  @end
  return arr
@end

@fn partition(arr, low, high)
  pivot = arr[high]
  i = low - 1
  j = low
  @while j < high
    @if arr[j] <= pivot
      i = i + 1
      tmp = arr[i]
      arr[i] = arr[j]
      arr[j] = tmp
    @end
    j = j + 1
  @end
  tmp2 = arr[i + 1]
  arr[i + 1] = arr[high]
  arr[high] = tmp2
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

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application 1: Comprehensive Sorting Algorithms")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.1.1: Insertion Sort on Reverse-Sorted Array
  total = total + 1
  rev_arr = [50, 40, 30, 20, 10]
  ins_res = insertion_sort(rev_arr, 5)
  ins_sorted = is_sorted(ins_res, 5)
  @if ins_sorted == 1 && ins_res[0] == 10 && ins_res[4] == 50
    passed = passed + 1
    println("  [PASS] T4.1.1: Insertion sort on reverse-sorted array ([10, 20, 30, 40, 50])")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.1: Insertion sort on reverse-sorted array")
  @end

  @! T4.1.2: Selection Sort on Unsorted Array
  total = total + 1
  unsorted = [64, 25, 12, 22, 11]
  sel_res = selection_sort(unsorted, 5)
  sel_sorted = is_sorted(sel_res, 5)
  @if sel_sorted == 1 && sel_res[0] == 11 && sel_res[1] == 12 && sel_res[2] == 22 && sel_res[3] == 25 && sel_res[4] == 64
    passed = passed + 1
    println("  [PASS] T4.1.2: Selection sort on unsorted array ([11, 12, 22, 25, 64])")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.2: Selection sort on unsorted array")
  @end

  @! T4.1.3: Quicksort on 10-Element Array with Duplicates
  total = total + 1
  qs_arr = [38, 27, 43, 3, 9, 82, 10, 9, 43, 1]
  qs_res = quicksort(qs_arr, 0, 9)
  qs_sorted = is_sorted(qs_res, 10)
  @if qs_sorted == 1 && qs_res[0] == 1 && qs_res[9] == 82
    passed = passed + 1
    println("  [PASS] T4.1.3: Recursive Quicksort on 10-element array with duplicates")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.3: Recursive Quicksort")
  @end

  @! T4.1.4: Quicksort on Already-Sorted Array
  total = total + 1
  already_sorted = [1, 2, 3, 4, 5, 6, 7]
  as_res = quicksort(already_sorted, 0, 6)
  as_check = is_sorted(as_res, 7)
  @if as_check == 1 && as_res[0] == 1 && as_res[6] == 7
    passed = passed + 1
    println("  [PASS] T4.1.4: Quicksort on already sorted array")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.4: Quicksort on already sorted array")
  @end

  @! T4.1.5: Quicksort on Array with All Equal Elements
  total = total + 1
  equal_arr = [7, 7, 7, 7, 7]
  eq_res = quicksort(equal_arr, 0, 4)
  eq_check = is_sorted(eq_res, 5)
  @if eq_check == 1 && eq_res[0] == 7 && eq_res[4] == 7
    passed = passed + 1
    println("  [PASS] T4.1.5: Quicksort on all-equal element array")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.5: Quicksort on all-equal elements")
  @end

  println("-----------------------------------------------------------------")
  println("App 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Application 1 (Sorting Algorithms) PASSED")
    return 0
  @else
    println("✗ Application 1 (Sorting Algorithms) FAILED")
    return 1
  @end
@end
