@! ============================================================================
@! MAYA E2E TIER 1 — F04.3: MLFQ Multi-Priority Scheduling
@! File: tests/e2e/tier1_features/os/test_f04_scheduler_mlfq_priority.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f04_scheduler"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F04.3: MLFQ Priority Scheduling")

  sched = scheduler_new(1)
  t_low = scheduler_spawn(sched, "LowTask", 1, 3)
  t_high = scheduler_spawn(sched, "HighTask", 10, 2)

  scheduler_step(sched)
  assert_eq(sched.tasks[1].steps_completed, 1, "High priority executed first")

  println("✓ PASS: F04.3 MLFQ Priority Scheduling")
  return 0
@end
