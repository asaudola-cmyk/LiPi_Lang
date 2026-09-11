@! ============================================================================
@! MAYA E2E TIER 1 — F20: Test Process Isolation
@! File: tests/e2e/tier1_features/infra/test_f20_test_process_isolation.maya
@! ============================================================================

import "universe/tools/maya_test"

@fn isolate_me()
  return 0
@end

@fn main()
  res = run_isolated_test("sample_pass", isolate_me)
  @if res.passed != 1 || res.exit_code != 0 return 1 @end
  println("✓ PASS: test_f20_test_process_isolation")
  return 0
@end
