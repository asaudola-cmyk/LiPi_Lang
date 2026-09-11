@! ============================================================================
@! MAYA E2E TIER 1 — F03.2: Dispatcher Executable Path Resolution
@! File: tests/e2e/tier1_features/os/test_f03_dispatcher_path_lookup.maya
@! ============================================================================

import "universe/os/dispatcher"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F03.2: Dispatcher Path Lookup")

  p_echo = dispatcher_resolve_path("echo")
  assert_true(p_echo.len() > 0, "echo path resolved")

  p_ls = dispatcher_resolve_path("ls")
  assert_true(p_ls.len() > 0, "ls path resolved")

  println("✓ PASS: F03.2 Dispatcher Path Lookup")
  return 0
@end
