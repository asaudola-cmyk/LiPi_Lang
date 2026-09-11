@! ============================================================================
@! TEST: tests/ai/test_transformer_real.maya
@! Phase 6 — Real argmax / gpt_generate_token tests
@! Proves that gpt_generate_token does REAL computation (not hardcoded return).
@! ============================================================================

import "universe/ai/transformer/gpt"

g_passed = 0
g_failed = 0

@fn check(label, got, expected)
  @if got == expected
    g_passed = g_passed + 1
    println("  PASS: " + label + " (got=" + got.to_str() + ")")
  @else
    g_failed = g_failed + 1
    println("  FAIL: " + label + " got=" + got.to_str() + " expected=" + expected.to_str())
  @end
@end

@fn main()
  println("=== Transformer Real Argmax Tests ===")

  @! ---- Test 1: Peak at index 1 ----
  @! [0.1, 0.9, 0.2, 0.05] — highest value is 0.9 at index 1
  @! Maya uses integer arithmetic: represent as [10, 90, 20, 5]
  logits1 = [10, 90, 20, 5]
  r1 = gpt_generate_token(logits1)
  check("argmax([10,90,20,5]) == 1", r1, 1)

  @! ---- Test 2: Peak at index 2 ----
  @! [0.5, 0.1, 0.9, 0.2] — highest value is 0.9 at index 2
  logits2 = [50, 10, 90, 20]
  r2 = gpt_generate_token(logits2)
  check("argmax([50,10,90,20]) == 2", r2, 2)

  @! ---- Test 3: Peak at index 0 ----
  logits3 = [999, 1, 2, 3]
  r3 = gpt_generate_token(logits3)
  check("argmax([999,1,2,3]) == 0", r3, 0)

  @! ---- Test 4: Peak at last index ----
  logits4 = [1, 2, 3, 100]
  r4 = gpt_generate_token(logits4)
  check("argmax([1,2,3,100]) == 3", r4, 3)

  @! ---- Test 5: All equal — returns index 0 ----
  logits5 = [5, 5, 5, 5]
  r5 = gpt_generate_token(logits5)
  check("argmax equal values == 0 (first winner)", r5, 0)

  @! ---- Test 6: Single element ----
  logits6 = [42]
  r6 = gpt_generate_token(logits6)
  check("argmax single-element == 0", r6, 0)

  @! ---- Test 7: Negative logits — least-negative wins ----
  logits7 = [-100, -10, -50, -200]
  r7 = gpt_generate_token(logits7)
  check("argmax([-100,-10,-50,-200]) == 1", r7, 1)

  @! ---- Test 8: Intentional-break guard ----
  @! If gpt_generate_token were "return 1" hardcoded, tests 1,3,4,5,6,7
  @! would fail (they expect 0, 0, 3, 0, 0, 1 respectively).
  @! We assert that the results differ between test1 and test2:
  @if r1 != r2
    g_passed = g_passed + 1
    println("  PASS: different logit arrays produce different token indices")
  @else
    g_failed = g_failed + 1
    println("  FAIL: all argmax calls returned same index — likely hardcoded!")
  @end

  println("=== RESULTS: " + g_passed.to_str() + " passed, " + g_failed.to_str() + " failed ===")
  @if g_failed == 0
    println("ALL TRANSFORMER REAL TESTS PASSED")
  @else
    println("SOME TRANSFORMER REAL TESTS FAILED")
  @end
@end
