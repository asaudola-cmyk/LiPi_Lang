@! ============================================================================
@! MAYA E2E TIER 1 — F02.4: Process Signal Dispatch (SIGTERM)
@! File: tests/e2e/tier1_features/os/test_f02_process_kill_signal.maya
@! ============================================================================

import "universe/os/process"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F02.4: Process Signal Dispatch")

  child_pid = process_fork()
  @if child_pid == 0
    @while 1 == 1
      process_sleep_ms(100)
    @end
    process_exit(0)
  @end

  process_sleep_ms(20)
  process_kill(child_pid, SIGTERM())
  status = process_wait(child_pid)

  assert_eq(process_wifsignaled(status), 1, "Child was terminated by signal")
  assert_eq(process_wtermsig(status), 15, "Signal was SIGTERM (15)")

  println("✓ PASS: F02.4 Process Signal Dispatch")
  return 0
@end
