@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: ARRAY OF STRUCTS + SORT + BINSEARCH
@! File: tests/e2e/tier3_combinations/test_array_structs_sort_binsearch.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@struct Student
  id: 0
  score: 0
  grade: ""
@end

@fn calc_grade(score)
  @if score >= 90
    return "A"
  @elif score >= 80
    return "B"
  @elif score >= 70
    return "C"
  @elif score >= 60
    return "D"
  @else
    return "F"
  @end
@end

@fn quicksort_students(arr, low, high)
  @if low < high
    pivot_score = arr[high].score
    i = low - 1
    j = low
    @while j < high
      @if arr[j].score <= pivot_score
        i = i + 1
        temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp
      @end
      j = j + 1
    @end
    temp = arr[i + 1]
    arr[i + 1] = arr[high]
    arr[high] = temp
    pivot_idx = i + 1

    quicksort_students(arr, low, pivot_idx - 1)
    quicksort_students(arr, pivot_idx + 1, high)
  @end
  return arr
@end

@fn binary_search_score(arr, len, target_score)
  low = 0
  high = len - 1
  @while low <= high
    mid = low + (high - low) / 2
    @if arr[mid].score == target_score
      return mid
    @elif arr[mid].score < target_score
      low = mid + 1
    @else
      high = mid - 1
    @end
  @end
  return -1
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 6: Array of Structs + QuickSort + BinSearch")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! 1. Generate 100 students with deterministic pseudo-random formula
  students = []
  seed = 42
  i = 0
  @while i < 100
    seed = (seed * 1103515245 + 12345) % 2147483648
    @if seed < 0
      seed = 0 - seed
    @end
    raw_score = 10 + (seed % 90)  @! 10..99
    st = {
      id: 1000 + i,
      score: raw_score,
      grade: calc_grade(raw_score)
    }
    students = students.push(st)
    i = i + 1
  @end

  @! T3.6.1: Array Generation and Initial Length
  total = total + 1
  @if students.len() == 100 && students[0].id == 1000
    passed = passed + 1
    println("  [PASS] T3.6.1: Array of 100 Student structs created successfully")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6.1: Array creation failed")
  @end

  @! T3.6.2: In-place Field Mutation on Specific Students
  total = total + 1
  @! Mutate student 0 to score 99 (A) and student 50 to score 15 (F)
  students[0].score = 99
  students[0].grade = calc_grade(99)
  students[50].score = 15
  students[50].grade = calc_grade(15)

  @if students[0].score == 99 && students[0].grade == "A" && students[50].score == 15 && students[50].grade == "F"
    passed = passed + 1
    println("  [PASS] T3.6.2: In-place struct field mutation in array elements")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6.2: In-place mutation failed")
  @end

  @! T3.6.3: In-Place QuickSort by Struct Field (score ascending)
  total = total + 1
  quicksort_students(students, 0, students.len() - 1)

  is_sorted = 1
  k = 0
  @while k < 99
    @if students[k].score > students[k + 1].score
      is_sorted = 0
    @end
    k = k + 1
  @end

  @if is_sorted == 1 && students[0].score <= students[99].score
    passed = passed + 1
    println("  [PASS] T3.6.3: In-place QuickSort verified monotonic ascending (" + int_to_str(students[0].score) + " -> " + int_to_str(students[99].score) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6.3: QuickSort did not sort array correctly")
  @end

  @! T3.6.4: Binary Search for Exact Mutated Scores
  total = total + 1
  found_idx_99 = binary_search_score(students, 100, 99)
  found_idx_15 = binary_search_score(students, 100, 15)

  @if found_idx_99 >= 0 && students[found_idx_99].score == 99 && found_idx_15 >= 0 && students[found_idx_15].score == 15
    passed = passed + 1
    println("  [PASS] T3.6.4: Binary search located target struct elements (score 99 at idx " + int_to_str(found_idx_99) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6.4: Binary search failed")
  @end

  @! T3.6.5: Binary Search for Nonexistent Score
  total = total + 1
  missing_idx = binary_search_score(students, 100, 9999)
  @if missing_idx == -1
    passed = passed + 1
    println("  [PASS] T3.6.5: Binary search for missing key returns -1 correctly")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6.5: Binary search for missing key failed, returned " + int_to_str(missing_idx))
  @end

  println("-----------------------------------------------------------------")
  println("Combination 6 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 6 (Array of Structs + Sort + BinSearch) PASSED")
    return 0
  @else
    println("✗ Combination 6 (Array of Structs + Sort + BinSearch) FAILED")
    return 1
  @end
@end
