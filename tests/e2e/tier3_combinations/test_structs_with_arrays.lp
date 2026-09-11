@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: STRUCTS CONTAINING ARRAYS
@! File: tests/e2e/tier3_combinations/test_structs_with_arrays.maya
@! ============================================================================

import "universe/core/collections"

@struct StudentRecord
  id: 0
  grades: 0
  grade_count: 0
@end

@fn calc_average_grade(student)
  sum = 0
  i = 0
  @while i < student.grade_count
    sum = sum + student.grades[i]
    i = i + 1
  @end
  return sum / student.grade_count
@end

@fn add_grade(student, grade)
  student.grades.push(grade)
  student.grade_count = student.grade_count + 1
  return student
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 1: Structs Containing Dynamic Arrays")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.1: Struct Instantiation with Dynamic Array Field
  total = total + 1
  init_grades = [90, 80, 70]
  student = { id: 101, grades: init_grades, grade_count: 3 }
  @if student.id == 101 && student.grades[0] == 90 && student.grades[2] == 70
    passed = passed + 1
    println("  [PASS] T3.1: Struct containing dynamic array field initialization")
  @else
    failed = failed + 1
    println("  [FAIL] T3.1: Struct containing dynamic array field")
  @end

  @! T3.2: Reading and Modifying Array Element inside Struct
  total = total + 1
  student.grades[1] = 85
  @if student.grades[1] == 85
    passed = passed + 1
    println("  [PASS] T3.2: In-place mutation of array element inside struct (grades[1] = 85)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.2: Mutation of array element inside struct")
  @end

  @! T3.3: Average Calculation on Struct Array
  total = total + 1
  @! grades: [90, 85, 70], avg = 245 / 3 = 81
  avg = calc_average_grade(student)
  @if avg == 81
    passed = passed + 1
    println("  [PASS] T3.3: Iterative average computation over struct's array (avg == 81)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3: Average computation over struct's array")
  @end

  @! T3.4: Dynamic Push into Struct's Array Field
  total = total + 1
  student = add_grade(student, 95)
  @! grades now [90, 85, 70, 95], count = 4
  @! sum = 90 + 85 + 70 + 95 = 340, avg = 340 / 4 = 85
  avg_new = calc_average_grade(student)
  @if student.grade_count == 4 && student.grades[3] == 95 && avg_new == 85
    passed = passed + 1
    println("  [PASS] T3.4: Dynamic push appending into struct's array (count == 4, avg == 85)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.4: Dynamic push into struct's array")
  @end

  @! T3.5: Multiple Structs with Independent Array Instances
  total = total + 1
  s1 = { id: 1, grades: [100, 100], grade_count: 2 }
  s2 = { id: 2, grades: [50, 50], grade_count: 2 }
  s1.grades[0] = 90
  @if s1.grades[0] == 90 && s2.grades[0] == 50
    passed = passed + 1
    println("  [PASS] T3.5: Distinct struct instances hold independent arrays (s1: 90, s2: 50)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5: Distinct struct instances hold independent arrays")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 1 (Structs With Arrays) PASSED")
    return 0
  @else
    println("✗ Combination 1 (Structs With Arrays) FAILED")
    return 1
  @end
@end
