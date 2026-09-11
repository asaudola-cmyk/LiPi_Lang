@! ============================================================================
@! MAYA E2E TIER 1 — F02.5: Process Exit Code Propagation
@! File: tests/e2e/tier1_features/os/test_f02_process_exit_codes.maya
@! ============================================================================

import "universe/os/process"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F02.5: Process Exit Codes")

  codes = [0, 1, 42, 127]
  i = 0
  @while i < codes.len()
    expected_c = codes[i]
    pid = process_fork()
    @if pid == 0
      process_exit(expected_c)
    @end

    status = process_wait(pid)
    assert_eq(process_wifexited(status), 1, "Child must exit normally")
    assert_eq(process_wexitstatus(status), expected_c, "Exit code must match")
    i = i + 1
  @end

  println("✓ PASS: F02.5 Process Exit Codes")
  return 0
@end
