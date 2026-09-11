@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — AI-DRIVEN COMPILER OPTIMIZATION TEST SUITE
@! File: tests/ai/test_ai_compiler_opt.maya
@! ============================================================================

import "universe/core/collections"
import "compiler/middleend/ai_opt"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🧠 MAYA AI-DRIVEN COMPILER OPTIMIZATION TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  opt_model = ai_opt_default_weights()

  @! TEST 1: Compute-Intensive Parallel Vector Loop
  println("▶ Section 1: Neural Decision on Vectorizable Parallel Matrix Loop...")
  total_tests = total_tests + 1
  feat_matrix = {
    trip_count_hint: 1024,
    body_instruction_count: 8,
    memory_access_count: 3,
    floating_point_ops: 4,
    branch_count: 0,
    nesting_depth: 2,
    has_cross_iter_dependency: 0
  }
  dec_matrix = ai_opt_evaluate_loop(opt_model, feat_matrix)
  ok1 = assert_eq_int(dec_matrix.should_vectorize, 1, "AI recommends SIMD vectorization")
  ok2 = assert_true(dec_matrix.recommended_unroll_factor >= 4, "AI recommends aggressive unroll factor >= 4")
  ok3 = assert_true(dec_matrix.predicted_speedup_pct > 150, "Predicted speedup exceeds 150%")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Neural optimizer correctly selected SIMD + unroll for matrix loop")
  @end

  @! TEST 2: Serial Recurrence Loop with Cross-Iteration Dependency
  println("▶ Section 2: Loop with Cross-Iteration Dependency (Fibonacci / Recurrence)...")
  total_tests = total_tests + 1
  feat_serial = {
    trip_count_hint: 100,
    body_instruction_count: 4,
    memory_access_count: 1,
    floating_point_ops: 0,
    branch_count: 0,
    nesting_depth: 1,
    has_cross_iter_dependency: 1 @! Serial dependency!
  }
  dec_serial = ai_opt_evaluate_loop(opt_model, feat_serial)
  ok1 = assert_eq_int(dec_serial.should_vectorize, 0, "AI disables vectorization due to serial dependency")
  ok2 = assert_eq_int(dec_serial.recommended_unroll_factor, 1, "AI preserves scalar unroll factor 1")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Neural optimizer safely preserved serial semantics")
  @end

  @! TEST 3: Branch-Heavy Irregular Control Flow Loop
  println("▶ Section 3: Branch-Heavy Loop with High Register Pressure...")
  total_tests = total_tests + 1
  feat_branch = {
    trip_count_hint: 50,
    body_instruction_count: 45,
    memory_access_count: 12,
    floating_point_ops: 2,
    branch_count: 8,
    nesting_depth: 3,
    has_cross_iter_dependency: 0
  }
  dec_branch = ai_opt_evaluate_loop(opt_model, feat_branch)
  ok1 = assert_true(dec_branch.register_pressure_score > 0, "Tracks high register pressure score")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Register pressure heuristics scored accurately")
  @end

  println("=================================================================")
  println("📊 AI OPTIMIZER TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 AI-DRIVEN COMPILER OPTIMIZATION TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME AI OPTIMIZER TESTS FAILED")
    return 1
  @end
@end
