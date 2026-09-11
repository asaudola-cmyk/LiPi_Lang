@! ============================================================================
@! PHASE 3 ADVERSARIAL CHALLENGER TEST SUITE (PURE MAYA)
@! File: tests/adversarial/test_phase3_gc_disambig_challenger.maya
@! Scope: Stress tests GC allocation loops, dynamic string/integer additions,
@!        pointer disambiguation, and array lifecycle under the compiler.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct ChallengeCtx
  total: 0
  passed: 0
  failed: 0
@end

@fn chk_assert(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> evaluated to false (0)")
    return 0
  @end
@end

@fn chk_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn test_gc_heavy_allocation_loop(ctx)
  println("\n--- [Phase 3 Challenger 1] Heavy Allocation Churn in Pure Maya ---")

  @! Run a 5000-iteration string creation and concatenation loop
  live_str = "MayaRootPrefix_"
  i = 0
  @while i < 5000
    temp_num = maya_int_to_str(i * 37)
    temp_concat = live_str + temp_num
    @! Every 1000 iterations verify live_str is intact
    @if i % 1000 == 0
      chk_assert(ctx, "Iteration " + maya_int_to_str(i) + " prefix intact", maya_str_starts_with(temp_concat, live_str))
    @end
    i = i + 1
  @end

  chk_eq(ctx, "Completed 5000 string allocation churn cycles", i, 5000)
@end

@fn test_dynamic_add_and_disambiguation(ctx)
  println("\n--- [Phase 3 Challenger 2] Dynamic Addition & String vs Number Disambiguation ---")

  @! 1. Number + Number
  n1 = 100
  n2 = 200
  res_num = n1 + n2
  chk_eq(ctx, "100 + 200 == 300", res_num, 300)

  @! 2. String + String
  s1 = "Hello "
  s2 = "Maya"
  res_str = s1 + s2
  chk_assert(ctx, "'Hello ' + 'Maya' == 'Hello Maya'", maya_str_eq(res_str, "Hello Maya"))

  @! 3. Large integer disambiguation: timestamps & big numbers should not be treated as string pointers
  timestamp = 1710000000000
  chk_eq(ctx, "Timestamp numeric identity preserved", timestamp, 1710000000000)

  @! 4. Number + String dynamic concatenation
  mixed = "Timestamp: " + maya_int_to_str(timestamp)
  chk_assert(ctx, "Timestamp formatted into string", maya_str_starts_with(mixed, "Timestamp: 1710000000000"))
@end

@fn test_array_gc_lifecycle(ctx)
  println("\n--- [Phase 3 Challenger 3] Dynamic Array Churn & Nested Allocations ---")

  arr = maya_array_new(4, 8)
  j = 0
  @while j < 500
    maya_array_push(arr, j * 10)
    j = j + 1
  @end

  chk_eq(ctx, "Array length reached 500", maya_array_len(arr), 500)
  chk_eq(ctx, "Array element at 0 is 0", maya_array_get(arr, 0), 0)
  chk_eq(ctx, "Array element at 250 is 2500", maya_array_get(arr, 250), 2500)
  chk_eq(ctx, "Array element at 499 is 4990", maya_array_get(arr, 499), 4990)
@end

@fn main()
  println("=================================================================")
  println("🛡️  MAYA PURE MAYA PHASE 3 ADVERSARIAL CHALLENGER SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_gc_heavy_allocation_loop(ctx)
  test_dynamic_add_and_disambiguation(ctx)
  test_array_gc_lifecycle(ctx)

  println("\n=================================================================")
  println("📊 PHASE 3 PURE MAYA CHALLENGER SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All Pure Maya Phase 3 challenges passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more Pure Maya Phase 3 challenges failed.")
    return 1
  @end
@end
