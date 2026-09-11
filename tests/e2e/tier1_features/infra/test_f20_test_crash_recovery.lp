@! ============================================================================
@! MAYA E2E TIER 1 — F20: Test Crash Recovery
@! File: tests/e2e/tier1_features/infra/test_f20_test_crash_recovery.maya
@! ============================================================================

import "universe/tools/maya_test"

@fn failing_isolate()
  panic("Isolated crash simulation")
  return 0
@end

@fn main()
  res = run_isolated_test("sample_crash", failing_isolate)
  @if res.passed != 0 return 1 @end
  println("✓ PASS: test_f20_test_crash_recovery")
  return 0
@end
