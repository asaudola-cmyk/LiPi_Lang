@! ============================================================================
@! MAYA E2E TIER 1 — F03.5: Dispatcher Shell-Free Direct Execution
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher_no_shell_exec.maya
@! ============================================================================

import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F03.5: Dispatcher Shell-Free Execution")

  res = dispatcher_run_capture("echo MAYA_SHELL_FREE_TEST_SUCCESS")
  assert_eq(res.exit_code, 0, "Execution returned exit code 0")
  assert_str_contains(res.stdout_data, "MAYA_SHELL_FREE_TEST_SUCCESS", "Captured stdout contains payload")

  println("✓ PASS: F03.5 Dispatcher Shell-Free Execution")
  return 0
@end
