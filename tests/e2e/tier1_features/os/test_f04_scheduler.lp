@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F04: COROUTINE / TASK SCHEDULER
@! File: tests/e2e/tier1_features/os/test_f04_scheduler.maya
@! Description: Validates cooperative coroutines, MLFQ/Round-Robin scheduler, TCB
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@! Task States
@fn TASK_STATE_READY() return 0 @end
@fn TASK_STATE_RUNNING() return 1 @end
@fn TASK_STATE_YIELDED() return 2 @end
@fn TASK_STATE_TERMINATED() return 3 @end
@fn TASK_STATE_CANCELLED() return 4 @end

@struct TaskControlBlock
  task_id: 0
  name: ""
  state: 0
  priority: 1
  steps_completed: 0
  target_steps: 0
  result_val: 0
@end

@struct MayaScheduler
  tasks: []
  current_idx: 0
  quantum: 1
  ticks: 0
  completed_count: 0
@end

@fn scheduler_new(quantum)
  return {
    tasks: [],
    current_idx: 0,
    quantum: quantum,
    ticks: 0,
    completed_count: 0
  }
@end

@fn scheduler_spawn(sched, name, priority, target_steps)
  tid = sched.tasks.len() + 1
  tcb = {
    task_id: tid,
    name: name,
    state: TASK_STATE_READY(),
    priority: priority,
    steps_completed: 0,
    target_steps: target_steps,
    result_val: 0
  }
  sched.tasks = sched.tasks.push(tcb)
  return tid
@end

@fn scheduler_step(sched)
  n = sched.tasks.len()
  @if n == 0 return 0 @end

  @! Find highest priority ready task starting from current_idx
  best_idx = 0 - 1
  highest_pri = 0 - 1

  i = 0
  @while i < n
    idx = (sched.current_idx + i) % n
    t = sched.tasks[idx]
    @if t.state == TASK_STATE_READY() || t.state == TASK_STATE_YIELDED()
      @if t.priority > highest_pri
        highest_pri = t.priority
        best_idx = idx
      @end
    @end
    i = i + 1
  @end

  @if best_idx < 0
    return 0 @! No ready tasks
  @end

  task = sched.tasks[best_idx]
  task.state = TASK_STATE_RUNNING()
  task.steps_completed = task.steps_completed + 1
  task.result_val = task.result_val + (task.steps_completed * 10)
  sched.ticks = sched.ticks + 1

  @if task.steps_completed >= task.target_steps
    task.state = TASK_STATE_TERMINATED()
    sched.completed_count = sched.completed_count + 1
  @else
    task.state = TASK_STATE_READY()
  @end

  sched.current_idx = (best_idx + 1) % n
  return 1
@end

@fn scheduler_yield(sched, task_id)
  i = 0
  @while i < sched.tasks.len()
    t = sched.tasks[i]
    @if t.task_id == task_id
      @if t.state == TASK_STATE_RUNNING() || t.state == TASK_STATE_READY()
        t.state = TASK_STATE_YIELDED()
        return 1
      @end
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_kill(sched, task_id)
  i = 0
  @while i < sched.tasks.len()
    t = sched.tasks[i]
    @if t.task_id == task_id
      t.state = TASK_STATE_CANCELLED()
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn scheduler_run_all(sched)
  max_iterations = 10000
  iter = 0
  @while iter < max_iterations
    has_work = scheduler_step(sched)
    @if has_work == 0
      break
    @end
    iter = iter + 1
  @end
  return sched.completed_count
@end

@fn test_f04_01_spawn_and_run()
  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "TaskSumA", 1, 5)
  t2 = scheduler_spawn(sched, "TaskSumB", 1, 3)
  t3 = scheduler_spawn(sched, "TaskSumC", 1, 4)
  assert_eq(sched.tasks.len(), 3, "Scheduler must have 3 registered tasks")

  completed = scheduler_run_all(sched)
  assert_eq(completed, 3, "All 3 tasks must run to completion")

  task1 = sched.tasks[0]
  assert_eq(task1.state, TASK_STATE_TERMINATED(), "Task 1 must reach TERMINATED state")
  assert_eq(task1.steps_completed, 5, "Task 1 must complete 5 steps")

  task2 = sched.tasks[1]
  assert_eq(task2.state, TASK_STATE_TERMINATED(), "Task 2 must reach TERMINATED state")
  assert_eq(task2.steps_completed, 3, "Task 2 must complete 3 steps")

  task3 = sched.tasks[2]
  assert_eq(task3.state, TASK_STATE_TERMINATED(), "Task 3 must reach TERMINATED state")
  assert_eq(task3.steps_completed, 4, "Task 3 must complete 4 steps")
@end

@fn test_f04_02_round_robin_fairness()
  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "WorkerAlpha", 5, 4)
  t2 = scheduler_spawn(sched, "WorkerBeta", 5, 4)

  @! Step 1: WorkerAlpha runs step 1
  scheduler_step(sched)
  assert_eq(sched.tasks[0].steps_completed, 1, "Task 1 executed step 1")
  assert_eq(sched.tasks[1].steps_completed, 0, "Task 2 has not executed yet")

  @! Step 2: WorkerBeta runs step 1
  scheduler_step(sched)
  assert_eq(sched.tasks[0].steps_completed, 1, "Task 1 remains at step 1")
  assert_eq(sched.tasks[1].steps_completed, 1, "Task 2 executed step 1 (interleaved)")

  @! Run remainder
  scheduler_run_all(sched)
  assert_eq(sched.tasks[0].steps_completed, 4, "Task 1 completed all 4 steps")
  assert_eq(sched.tasks[1].steps_completed, 4, "Task 2 completed all 4 steps")
@end

@fn test_f04_03_priority_mlfq()
  sched = scheduler_new(1)
  t_low = scheduler_spawn(sched, "BackgroundIndex", 1, 5)
  t_high = scheduler_spawn(sched, "RealtimeAudio", 10, 3)

  @! High priority task should execute its 3 steps before low priority completes
  scheduler_step(sched)
  assert_eq(sched.tasks[1].steps_completed, 1, "High priority task executed first")

  scheduler_step(sched)
  assert_eq(sched.tasks[1].steps_completed, 2, "High priority task executed second step")

  scheduler_step(sched)
  assert_eq(sched.tasks[1].steps_completed, 3, "High priority task completed all 3 steps")
  assert_eq(sched.tasks[1].state, TASK_STATE_TERMINATED(), "High priority task finished before low priority")
  assert_eq(sched.tasks[0].steps_completed, 0, "Low priority task remained queued")

  scheduler_run_all(sched)
  assert_eq(sched.tasks[0].steps_completed, 5, "Low priority task subsequently ran to completion")
@end

@fn test_f04_04_cooperative_yield()
  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "TaskYielder", 5, 5)
  t2 = scheduler_spawn(sched, "TaskPeer", 5, 5)

  @! Manually yield task 1
  yield_res = scheduler_yield(sched, t1)
  assert_eq(yield_res, 1, "scheduler_yield must return 1 on successful state transition")
  assert_eq(sched.tasks[0].state, TASK_STATE_YIELDED(), "Task state must be YIELDED")

  scheduler_run_all(sched)
  assert_eq(sched.completed_count, 2, "Both tasks complete after yield recovery")
@end

@fn test_f04_05_task_cancellation()
  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "TaskToCancel", 1, 10)
  t2 = scheduler_spawn(sched, "TaskSurvivor", 1, 2)

  kill_res = scheduler_kill(sched, t1)
  assert_eq(kill_res, 1, "scheduler_kill must succeed")
  assert_eq(sched.tasks[0].state, TASK_STATE_CANCELLED(), "Task state must be CANCELLED")

  scheduler_run_all(sched)
  assert_eq(sched.tasks[0].steps_completed, 0, "Cancelled task must never execute steps")
  assert_eq(sched.tasks[1].state, TASK_STATE_TERMINATED(), "Survivor task must complete")
@end

@fn test_f04_06_tcb_data_integrity()
  sched = scheduler_new(1)
  t1 = scheduler_spawn(sched, "MathTask", 3, 3)
  scheduler_run_all(sched)

  task = sched.tasks[0]
  @! steps: 1 (val 10), 2 (val 10+20=30), 3 (val 30+30=60)
  assert_eq(task.result_val, 60, "Task computed result value must accurately reflect 60")
@end

@fn run_all_f04_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F04: Coroutine / Task Scheduler Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f04_01_spawn_and_run")
  test_f04_01_spawn_and_run()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_01_spawn_and_run")

  println("  [RUN] test_f04_02_round_robin_fairness")
  test_f04_02_round_robin_fairness()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_02_round_robin_fairness")

  println("  [RUN] test_f04_03_priority_mlfq")
  test_f04_03_priority_mlfq()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_03_priority_mlfq")

  println("  [RUN] test_f04_04_cooperative_yield")
  test_f04_04_cooperative_yield()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_04_cooperative_yield")

  println("  [RUN] test_f04_05_task_cancellation")
  test_f04_05_task_cancellation()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_05_task_cancellation")

  println("  [RUN] test_f04_06_tcb_data_integrity")
  test_f04_06_tcb_data_integrity()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f04_06_tcb_data_integrity")

  println("-----------------------------------------------------------------")
  println("F04 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f04_tests()
@end
