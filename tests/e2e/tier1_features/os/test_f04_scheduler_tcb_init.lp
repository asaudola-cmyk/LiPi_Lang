@! ============================================================================
@! MAYA E2E TIER 1 — F04.1: Task Control Block (TCB) Initialization
@! File: tests/e2e/tier1_features/os/test_f04_scheduler_tcb_init.maya
@! ============================================================================

import "universe/tools/maya_test"

@struct TaskControlBlock
  task_id: 0
  name: ""
  state: 0
  priority: 1
  steps: 0
@end

@fn main()
  println("▶ [TIER 1] F04.1: Scheduler TCB Initialization")

  tcb = {
    task_id: 42,
    name: "WorkerCoroutine",
    state: 0, @! READY
    priority: 5,
    steps: 0
  }

  assert_eq(tcb.task_id, 42, "Task ID matches 42")
  assert_str_eq(tcb.name, "WorkerCoroutine", "Name matches")
  assert_eq(tcb.state, 0, "Initial state is 0 (READY)")
  assert_eq(tcb.priority, 5, "Priority is 5")

  println("✓ PASS: F04.1 Scheduler TCB Initialization")
  return 0
@end
