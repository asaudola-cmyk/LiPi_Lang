@! ============================================================================
@! MAYA E2E TIER 1 — F04.2: Scheduler Round-Robin Interleaving
@! File: tests/e2e/tier1_features/os/test_f04_scheduler_round_robin.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f04_scheduler"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F04.2: Round-Robin Fairness")

  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "T1", 5, 2)
  t2 = scheduler_spawn(sched, "T2", 5, 2)

  scheduler_step(sched)
  assert_eq(sched.tasks[0].steps_completed, 1, "Task 1 stepped")
  assert_eq(sched.tasks[1].steps_completed, 0, "Task 2 paused")

  scheduler_step(sched)
  assert_eq(sched.tasks[1].steps_completed, 1, "Task 2 stepped (interleaved)")

  println("✓ PASS: F04.2 Round-Robin Fairness")
  return 0
@end
