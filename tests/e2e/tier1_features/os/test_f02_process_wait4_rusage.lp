@! ============================================================================
@! MAYA E2E TIER 1 — F02.3: Process wait4 & Resource Usage Synchronization
@! File: tests/e2e/tier1_features/os/test_f02_process_wait4_rusage.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F02.3: Process wait4")

  pid = sys_fork()
  @if pid == 0
    sys_exit(33)
  @end

  ws = { val: 0 }
  res = sys_wait4(pid, ws, 0, 0)
  assert_eq(res, pid, "sys_wait4 returned reaped child PID")
  assert_eq(process_wexitstatus(ws.val), 33, "Exit status 33 decoded")

  println("✓ PASS: F02.3 Process wait4")
  return 0
@end
