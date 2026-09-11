@! ============================================================================
@! MAYA SCHEDULER & MLFQ UNIT TEST SUITE (tests/os/test_scheduler_mlfq.maya)
@! ============================================================================

import "universe/os/scheduler"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⏱️ MAYA TASK SCHEDULER & 3-TIER MLFQ TEST SUITE ⏱️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Round-Robin Mode
  println("▶ Section 1: Round-Robin Scheduler Mode...")
  total_tests = total_tests + 1
  
  sched_rr = scheduler_init(0) @! Mode 0 = Round-Robin
  t1 = scheduler_create_task(sched_rr, "rr_task1", 100, 4096, 0)
  t2 = scheduler_create_task(sched_rr, "rr_task2", 200, 4096, 0)
  
  ok1 = assert_eq_int(sched_rr.current_task_id, 1, "Task 1 active")
  next_id = scheduler_yield(sched_rr)
  ok2 = assert_eq_int(next_id, 2, "Switched to Task 2 on yield")
  next_id2 = scheduler_yield(sched_rr)
  ok3 = assert_eq_int(next_id2, 1, "Circularly returned to Task 1")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Round-Robin scheduling verified")
  @end

  @! SECTION 2: MLFQ 3-Tier Mode & Anti-Starvation Boost
  println("▶ Section 2: MLFQ Demotion & Anti-Starvation Priority Boost...")
  total_tests = total_tests + 1
  
  sched_mlfq = scheduler_init(1) @! Mode 1 = MLFQ
  t_cpu = scheduler_create_task(sched_mlfq, "cpu_heavy", 1000, 8192, 0)
  
  @! Run for 30 ticks (exhausting Q0=10, then Q1=20)
  i = 0
  @while i < 30
    scheduler_tick(sched_mlfq)
    i = i + 1
  @end
  
  task = scheduler_get_task(sched_mlfq, 1)
  ok1 = assert_eq_int(task.priority, 2, "Task demoted to lowest Priority 2 (Q2)")
  
  @! Run up to 100 ticks to trigger anti-starvation boost
  @while sched_mlfq.system_ticks < 105
    scheduler_tick(sched_mlfq)
  @end
  
  scheduler_schedule_next(sched_mlfq)
  task_boosted = scheduler_get_task(sched_mlfq, 1)
  ok2 = assert_eq_int(task_boosted.priority, 0, "Anti-starvation boost promoted task back to Priority 0")
  
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] MLFQ demotion & starvation boost verified")
  @end

  println("=================================================================")
  println("📊 SCHEDULER RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end
