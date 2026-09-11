@! ============================================================================
@! MAYA E2E TIER 1 — F04.4: Coroutine Cooperative Yield
@! File: tests/e2e/tier1_features/os/test_f04_scheduler_task_yield.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f04_scheduler"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F04.4: Cooperative Yield")

  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "TaskYield", 5, 3)
  res = scheduler_yield(sched, t1)
  assert_eq(res, 1, "scheduler_yield succeeded")
  assert_eq(sched.tasks[0].state, 2, "Task state is YIELDED (2)")

  println("✓ PASS: F04.4 Cooperative Yield")
  return 0
@end
