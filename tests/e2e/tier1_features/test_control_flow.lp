// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Control Flow & Conditionals PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: if, elif, else, boolean, logic, nested_branching

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: CONTROL FLOW (IF / ELIF / ELSE)
@! File: tests/e2e/tier1_features/test_control_flow.maya
@! ============================================================================

@fn classify_grade(score)
  @if score >= 90
    return 1 @! Grade A
  @elif score >= 80
    return 2 @! Grade B
  @elif score >= 70
    return 3 @! Grade C
  @elif score >= 60
    return 4 @! Grade D
  @else
    return 5 @! Grade F
  @end
@end

@fn nested_check(x, y)
  result = 0
  @if x > 0
    @if y > 0
      result = 1 @! Quadrant 1
    @else
      result = 4 @! Quadrant 4
    @end
  @else
    @if y > 0
      result = 2 @! Quadrant 2
    @else
      result = 3 @! Quadrant 3
    @end
  @end
  return result
@end

@fn logic_conditions(a, b, c)
  passes = 0
  @if (a > 10 && b < 20) || c == 100
    passes = passes + 1
  @end
  @if !(a == 0) && b != 0
    passes = passes + 1
  @end
  return passes
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Control Flow & Conditionals")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-IF-01: Simple If Without Else
  total = total + 1
  flag = 10
  executed = 0
  @if flag == 10
    executed = 1
  @end
  @if executed == 1
    passed = passed + 1
    println("  [PASS] TC-IF-01: Single if branch executes on true condition")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IF-01: Single if branch")
  @end

  @! TC-IF-02: Binary If / Else
  total = total + 1
  val = 50
  branch_taken = 0
  @if val > 100
    branch_taken = 1
  @else
    branch_taken = 2
  @end
  @if branch_taken == 2
    passed = passed + 1
    println("  [PASS] TC-IF-02: Binary if/else correctly takes else branch")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IF-02: Binary if/else")
  @end

  @! TC-IF-03: Multi-Branch If / Elif / Else Ladder
  total = total + 1
  g95 = classify_grade(95)
  g85 = classify_grade(85)
  g75 = classify_grade(75)
  g65 = classify_grade(65)
  g40 = classify_grade(40)
  @if g95 == 1 && g85 == 2 && g75 == 3 && g65 == 4 && g40 == 5
    passed = passed + 1
    println("  [PASS] TC-IF-03: Multi-way if/elif/else ladder classifies all 5 grade boundaries")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IF-03: Multi-way if/elif/else ladder")
  @end

  @! TC-IF-04: Complex Logical Boolean Conditions
  total = total + 1
  cond_res1 = logic_conditions(15, 10, 0)
  cond_res2 = logic_conditions(5, 50, 100)
  @if cond_res1 == 2 && cond_res2 == 2
    passed = passed + 1
    println("  [PASS] TC-IF-04: Complex boolean operators (&&, ||, !) evaluation")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IF-04: Complex boolean operators")
  @end

  @! TC-IF-05: Nested Conditionals
  total = total + 1
  q1 = nested_check(5, 5)
  q2 = nested_check(-5, 5)
  q3 = nested_check(-5, -5)
  q4 = nested_check(5, -5)
  @if q1 == 1 && q2 == 2 && q3 == 3 && q4 == 4
    passed = passed + 1
    println("  [PASS] TC-IF-05: Nested conditional branches (all 4 quadrants 1, 2, 3, 4)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-IF-05: Nested conditional branches")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Control Flow & Conditionals PASSED")
    return 0
  @else
    println("✗ Feature: Control Flow & Conditionals FAILED")
    return 1
  @end
@end
