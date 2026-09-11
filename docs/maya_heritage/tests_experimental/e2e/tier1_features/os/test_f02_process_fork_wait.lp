@! ============================================================================
@! MAYA E2E TIER 1 — F02.1: Process Fork and Wait Synchronization
@! File: tests/e2e/tier1_features/os/test_f02_process_fork_wait.maya
@! ============================================================================

import "universe/os/process"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F02.1: Process Fork & Wait")

  pid = process_fork()
  @if pid == 0
    process_exit(0)
  @end

  assert_gt(pid, 0, "process_fork returns child PID > 0 in parent")
  status = process_wait(pid)
  assert_ge(status, 0, "process_wait succeeds")
  assert_eq(process_wifexited(status), 1, "Child exited normally")
  assert_eq(process_wexitstatus(status), 0, "Child exit code is 0")

  println("✓ PASS: F02.1 Process Fork & Wait")
  return 0
@end
