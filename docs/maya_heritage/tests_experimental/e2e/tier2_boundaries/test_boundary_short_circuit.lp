// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Short-Circuit Evaluation PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, short_circuit, boolean, zero_division_guard, side_effects, chained_bool

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: SHORT-CIRCUIT EVALUATION
@! File: tests/e2e/tier2_boundaries/test_boundary_short_circuit.maya
@! ============================================================================

@struct Tracker
  side_effects: i64
@end

@fn count_side_effect(t)
  t.side_effects = t.side_effects + 1
  return 1
@end

@fn divide_guard(denom)
  @! If denom == 0, short-circuit prevents (100 / denom) division by zero
  @if denom != 0 && (100 / denom > 2)
    return 1
  @else
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Short-Circuit Boolean Evaluation")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-SC-01: && Zero-Division Guard
  total = total + 1
  r_zero = divide_guard(0)
  r_ten = divide_guard(10)
  @if r_zero == 0 && r_ten == 1
    passed = passed + 1
    println("  [PASS] BC-SC-01: && short-circuit successfully guards zero-division (denom=0 -> 0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-01: && zero-division guard")
  @end

  @! BC-SC-02: || True Condition Skips RHS Side-Effect
  total = total + 1
  t = { side_effects: 0 }
  flag = 1
  @if flag == 1 || count_side_effect(t) == 1
    dummy = 1
  @end
  @if t.side_effects == 0
    passed = passed + 1
    println("  [PASS] BC-SC-02: || short-circuit on true skips RHS function invocation (side_effects == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-02: || side-effect skip")
  @end

  @! BC-SC-03: && False Condition Skips RHS Side-Effect
  total = total + 1
  false_flag = 0
  @if false_flag == 1 && count_side_effect(t) == 1
    dummy2 = 1
  @end
  @if t.side_effects == 0
    passed = passed + 1
    println("  [PASS] BC-SC-03: && short-circuit on false skips RHS function invocation (side_effects == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-03: && side-effect skip")
  @end

  @! BC-SC-04: Chained || Evaluating Until First True
  total = total + 1
  c1 = 0
  c2 = 1
  @if c1 == 1 || c2 == 1 || count_side_effect(t) == 1
    dummy3 = 1
  @end
  @if t.side_effects == 0
    passed = passed + 1
    println("  [PASS] BC-SC-04: Chained || evaluation terminates at first true condition")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-04: Chained || short-circuit")
  @end

  @! BC-SC-05: Short-Circuit Invariant in While Loop Condition
  total = total + 1
  index = 0
  items = [10, 20, 30]
  total_sum = 0
  @! When index reaches 3, index < 3 becomes false, guarding items[index]
  @while index < 3 && items[index] > 0
    total_sum = total_sum + items[index]
    index = index + 1
  @end
  @if total_sum == 60 && index == 3
    passed = passed + 1
    println("  [PASS] BC-SC-05: While loop condition short-circuits to safely guard boundary checks (sum == 60)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-05: While loop short-circuit")
  @end

  @! BC-SC-06: Chained && Evaluating Until First False
  total = total + 1
  ok1 = 1
  fail2 = 0
  @if ok1 == 1 && fail2 == 1 && count_side_effect(t) == 1
    dummy4 = 1
  @end
  @if t.side_effects == 0
    passed = passed + 1
    println("  [PASS] BC-SC-06: Chained && evaluation terminates at first false condition without invoking remainder")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-06: Chained && short-circuit")
  @end

  @! BC-SC-07: Nested Compound Short-Circuit Evaluation ((A || B) && (C || D))
  total = total + 1
  branch_eval = 0
  @if (1 == 1 || count_side_effect(t) == 1) && (0 == 1 || 2 == 2)
    branch_eval = 1
  @end
  @if branch_eval == 1 && t.side_effects == 0
    passed = passed + 1
    println("  [PASS] BC-SC-07: Nested boolean logic short-circuiting ((A || B) && (C || D))")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SC-07: Nested compound short-circuit")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Short-Circuit Evaluation PASSED")
    return 0
  @else
    println("✗ Boundary: Short-Circuit Evaluation FAILED")
    return 1
  @end
@end
