@! ============================================================================
@! MAYA E2E TIER 1 — F04.5: Task Cancellation & Cleanup
@! File: tests/e2e/tier1_features/os/test_f04_scheduler_task_cancellation.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f04_scheduler"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F04.5: Task Cancellation")

  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "TaskToCancel", 1, 10)
  kill_res = scheduler_kill(sched, t1)
  assert_eq(kill_res, 1, "scheduler_kill succeeded")
  assert_eq(sched.tasks[0].state, 4, "Task state is CANCELLED (4)")

  println("✓ PASS: F04.5 Task Cancellation")
  return 0
@end
