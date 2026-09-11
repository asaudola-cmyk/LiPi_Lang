@! ============================================================================
@! MAYA E2E TIER 1 — F20: Test Timing Measurement
@! File: tests/e2e/tier1_features/infra/test_f20_test_timing_measurement.maya
@! ============================================================================

import "universe/tools/maya_test"

@fn timed_unit()
  i = 0
  sum = 0
  @while i < 1000
    sum = sum + i
    i = i + 1
  @end
  return 0
@end

@fn main()
  res = run_isolated_test("sample_timed", timed_unit)
  @if res.passed != 1 return 1 @end
  println("✓ PASS: test_f20_test_timing_measurement")
  return 0
@end
