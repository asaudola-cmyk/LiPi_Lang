@! ============================================================================
@! MAYA END-TO-END CONCURRENCY & GREEN THREADS STRESS SUITE
@! File: tests/e2e/test_concurrency_green_threads.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! TAGS: concurrency, green_threads, stress
@! Scope:
@!   1. Parallel green thread spawning via sys_clone (Syscall 56 / maya_clone_wrapper)
@!   2. Atomic memory operations via syscall 999 (__atomic_fetch_add)
@!   3. Multi-threaded stress loops with 50-100+ concurrent threads
@!   4. Pure Maya Work-Stealing Task Scheduler (WorkerDeque: push_bottom, pop_bottom, steal_top)
@!   5. Multi-worker load-balancing and work-stealing simulation
@!   6. Task dependency graphs and JoinHandle::join result resolution
@! ============================================================================

import "universe/core/concurrency"

@! --- Test Harness State & Assertions ---

@struct TestState
  total: 0
  passed: 0
  failed: 0
@end

@fn assert_eq(state, name, actual, expected)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(state, name, condition)
  state.total = state.total + 1
  @if condition != 0
    state.passed = state.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn assert_ge(state, name, actual, min_val)
  state.total = state.total + 1
  @if actual >= min_val
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str() + " (>= " + min_val.to_str() + ")")
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected >= " + min_val.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end


@! ============================================================================
@! 1. LOW-LEVEL SYSTEM CALL HELPERS & WORKERS
@! ============================================================================

@fn atomic_add(ptr, val)
  return syscall(999, ptr, val, 0, 0, 0, 0)
@end

@fn atomic_read(ptr)
  return syscall(999, ptr, 0, 0, 0, 0, 0)
@end

@fn sys_wait4(pid, status_ptr, options, rusage_ptr)
  @! 0x40000000 (__WALL) allows waiting on any child cloned thread
  let opts = options
  @if opts == 0
    opts = 1073741824
  @end
  return syscall(61, pid, status_ptr, opts, rusage_ptr, 0, 0)
@end

@fn worker_inc_1(counter_ptr)
  atomic_add(counter_ptr, 1)
  return 0
@end

@fn worker_inc_10(counter_ptr)
  atomic_add(counter_ptr, 10)
  return 0
@end


@! ============================================================================
@! 2. PURE MAYA WORK-STEALING DEQUE & SCHEDULER IMPLEMENTATION
@! ============================================================================

@struct WorkerDeque
  items: 0
  head: 0
  tail: 0
@end

@fn worker_deque_new()
  return { items: [], head: 0, tail: 0 }
@end

@fn deque_size(deque)
  return deque.tail - deque.head
@end

@fn push_bottom(deque, task_id)
  @if deque.tail == deque.head
    deque.items = []
    deque.head = 0
    deque.tail = 0
  @end
  deque.items.push(task_id)
  deque.tail = deque.tail + 1
@end

@fn pop_bottom(deque)
  @if deque.tail <= deque.head
    deque.head = 0
    deque.tail = 0
    deque.items = []
    return 0 - 1
  @end
  deque.tail = deque.tail - 1
  let item = deque.items[deque.tail]
  @if deque.tail == deque.head
    deque.head = 0
    deque.tail = 0
    deque.items = []
  @end
  return item
@end

@fn steal_top(deque)
  @if deque.head >= deque.tail
    deque.head = 0
    deque.tail = 0
    deque.items = []
    return 0 - 1
  @end
  let item = deque.items[deque.head]
  deque.head = deque.head + 1
  @if deque.head == deque.tail
    deque.head = 0
    deque.tail = 0
    deque.items = []
  @end
  return item
@end

@struct Task
  id: 0
  task_type: 0  @! 1=Square, 2=Add, 3=Multiply, 4=Fibonacci, 5=RangeSum
  arg1: 0
  arg2: 0
  completed: 0
  result: 0
@end

@struct Worker
  id: 0
  local_queue: 0
  steal_counter: 0
  executed_counter: 0
@end

@struct Scheduler
  workers: 0
  tasks: 0
  global_queue: 0
  total_tasks: 0
  total_completed: 0
  total_steals: 0
@end

@fn scheduler_new(num_workers)
  let workers = []
  let w_id = 0
  @while w_id < num_workers
    let q = worker_deque_new()
    let w = {
      id: w_id,
      local_queue: q,
      steal_counter: 0,
      executed_counter: 0
    }
    workers.push(w)
    w_id = w_id + 1
  @end
  
  let gq = worker_deque_new()
  return {
    workers: workers,
    tasks: [],
    global_queue: gq,
    total_tasks: 0,
    total_completed: 0,
    total_steals: 0
  }
@end

@fn scheduler_spawn_task(sched, worker_id, task_type, arg1, arg2)
  let tid = sched.tasks.len()
  let t = {
    id: tid,
    task_type: task_type,
    arg1: arg1,
    arg2: arg2,
    completed: 0,
    result: 0
  }
  sched.tasks.push(t)
  sched.total_tasks = sched.total_tasks + 1
  
  @if worker_id >= 0 && worker_id < sched.workers.len()
    let w = sched.workers[worker_id]
    push_bottom(w.local_queue, tid)
  @else
    push_bottom(sched.global_queue, tid)
  @end
  
  return { task_id: tid }
@end

@fn execute_task_logic(task)
  @if task.task_type == 1  @! Square
    task.result = task.arg1 * task.arg1
    task.completed = 1
  @elif task.task_type == 2  @! Add
    task.result = task.arg1 + task.arg2
    task.completed = 1
  @elif task.task_type == 3  @! Multiply
    task.result = task.arg1 * task.arg2
    task.completed = 1
  @elif task.task_type == 4  @! Fibonacci
    let n = task.arg1
    @if n <= 0
      task.result = 0
    @elif n == 1
      task.result = 1
    @else
      let a = 0
      let b = 1
      let idx = 2
      @while idx <= n
        let temp = a + b
        a = b
        b = temp
        idx = idx + 1
      @end
      task.result = b
    @end
    task.completed = 1
  @elif task.task_type == 5  @! Range Sum (sum from arg1 to arg2)
    let s = 0
    let curr = task.arg1
    @while curr <= task.arg2
      s = s + curr
      curr = curr + 1
    @end
    task.result = s
    task.completed = 1
  @end
@end

@fn scheduler_step_worker(sched, worker_id)
  let w = sched.workers[worker_id]
  let task_id = pop_bottom(w.local_queue)
  
  @! If local queue is empty, try global queue
  @if task_id < 0
    task_id = pop_bottom(sched.global_queue)
  @end
  
  @! If still empty, attempt to steal from other workers' top (FIFO)
  @if task_id < 0
    let num_w = sched.workers.len()
    let offset = 1
    @while offset < num_w && task_id < 0
      let victim_id = (worker_id + offset) % num_w
      let victim = sched.workers[victim_id]
      task_id = steal_top(victim.local_queue)
      @if task_id >= 0
        w.steal_counter = w.steal_counter + 1
        sched.total_steals = sched.total_steals + 1
      @end
      offset = offset + 1
    @end
  @end
  
  @! If task was obtained, execute it
  @if task_id >= 0
    let t = sched.tasks[task_id]
    execute_task_logic(t)
    w.executed_counter = w.executed_counter + 1
    sched.total_completed = sched.total_completed + 1
    return 1
  @end
  
  return 0
@end

@fn scheduler_run_all(sched)
  let active = 1
  let guard = 0
  @while active != 0 && guard < 100000
    active = 0
    let w_idx = 0
    @while w_idx < sched.workers.len()
      let did_work = scheduler_step_worker(sched, w_idx)
      @if did_work == 1
        active = 1
      @end
      w_idx = w_idx + 1
    @end
    guard = guard + 1
  @end
@end

@fn join_handle_join(sched, hnd)
  let t = sched.tasks[hnd.task_id]
  let guard = 0
  @while t.completed == 0 && guard < 10000
    let w_idx = 0
    @while w_idx < sched.workers.len() && t.completed == 0
      scheduler_step_worker(sched, w_idx)
      w_idx = w_idx + 1
    @end
    guard = guard + 1
  @end
  return t.result
@end


@! ============================================================================
@! CATEGORY 1: LOW-LEVEL ATOMIC OPERATIONS & MEMORY MAPPING
@! ============================================================================

@fn test_atomic_primitives(state)
  println("\n--- [Category 1] Low-Level Atomic Operations & Syscall 999 ---")

  let mem = sys_mmap(0, 4096, 3, 33, 0 - 1, 0)
  assert_true(state, "TC-CONC-01.1: Shared memory mmap allocation", mem > 0)

  @! Initial value should be 0
  let init_val = atomic_read(mem)
  assert_eq(state, "TC-CONC-01.2: Initial atomic value is 0", init_val, 0)

  @! Atomic fetch-and-add: adds 25, returns old value 0
  let old1 = atomic_add(mem, 25)
  assert_eq(state, "TC-CONC-01.3: atomic_add returns old value (0)", old1, 0)
  assert_eq(state, "TC-CONC-01.4: atomic_read returns updated value (25)", atomic_read(mem), 25)

  @! Second atomic fetch-and-add: adds 75, returns old value 25
  let old2 = atomic_add(mem, 75)
  assert_eq(state, "TC-CONC-01.5: atomic_add returns old value (25)", old2, 25)
  assert_eq(state, "TC-CONC-01.6: atomic_read returns updated sum (100)", atomic_read(mem), 100)

  @! Atomic decrement: add -40
  let old3 = atomic_add(mem, 0 - 40)
  assert_eq(state, "TC-CONC-01.7: atomic decrement returns old value (100)", old3, 100)
  assert_eq(state, "TC-CONC-01.8: atomic_read after decrement (60)", atomic_read(mem), 60)

  @! Multi-slot offset atomic operations
  let slot1 = mem + 8
  let slot2 = mem + 16
  atomic_add(slot1, 500)
  atomic_add(slot2, 700)
  assert_eq(state, "TC-CONC-01.9: Multi-slot offset atomic slot 1 (500)", atomic_read(slot1), 500)
  assert_eq(state, "TC-CONC-01.10: Multi-slot offset atomic slot 2 (700)", atomic_read(slot2), 700)
  assert_eq(state, "TC-CONC-01.11: Slot 0 remains unaffected (60)", atomic_read(mem), 60)
@end


@! ============================================================================
@! CATEGORY 2: PARALLEL GREEN THREAD SPAWNING & CONTENTION STRESS
@! ============================================================================

@fn test_parallel_green_threads_spawning(state)
  println("\n--- [Category 2] Parallel Green Threads Spawning (Syscall 56) ---")

  let mem = sys_mmap(0, 4096, 3, 33, 0 - 1, 0)
  
  @! 1. Single Green Thread Spawning
  let ctr_single = mem + 0
  let tid1 = maya_spawn(worker_inc_1, ctr_single)
  assert_true(state, "TC-CONC-02.1: Single maya_spawn returned positive PID", tid1 > 0)
  sys_wait4(tid1, 0, 0, 0)
  let  spin = 0
  @while atomic_read(ctr_single) < 1 && spin < 100000
    syscall(24, 0, 0, 0, 0, 0, 0)
    spin = spin + 1
  @end
  assert_eq(state, "TC-CONC-02.2: Single thread atomic increment completed", atomic_read(ctr_single), 1)

  @! 2. Spawning 50 Concurrent Green Threads
  println("  ▶ Spawning 50 concurrent green threads batch...")
  let ctr_50 = mem + 8
  let pids_50 = []
  let i = 0
  @while i < 50
    let pid = maya_spawn(worker_inc_1, ctr_50)
    pids_50.push(pid)
    i = i + 1
  @end

  i = 0
  @while i < 50
    sys_wait4(pids_50[i], 0, 0, 0)
    i = i + 1
  @end

  spin = 0
  @while atomic_read(ctr_50) < 50 && spin < 100000
    syscall(24, 0, 0, 0, 0, 0, 0)
    spin = spin + 1
  @end
  assert_eq(state, "TC-CONC-02.3: 50 concurrent green threads reached exact count 50", atomic_read(ctr_50), 50)

  @! 3. Spawning 100 Concurrent Green Threads in High Contention Stress Loop
  println("  ▶ Spawning 100 concurrent green threads (each adding 10)...")
  let ctr_100 = mem + 16
  let pids_100 = []
  i = 0
  @while i < 100
    let pid = maya_spawn(worker_inc_10, ctr_100)
    pids_100.push(pid)
    i = i + 1
  @end

  i = 0
  @while i < 100
    sys_wait4(pids_100[i], 0, 0, 0)
    i = i + 1
  @end

  spin = 0
  @while atomic_read(ctr_100) < 1000 && spin < 100000
    syscall(24, 0, 0, 0, 0, 0, 0)
    spin = spin + 1
  @end
  assert_eq(state, "TC-CONC-02.4: 100 concurrent green threads reached exact sum 1000", atomic_read(ctr_100), 1000)

  @! 4. Multi-Counter Partitioned Concurrent Stress: 4 Shared Counters x 20 Threads = 80 Threads
  println("  ▶ Spawning 80 green threads partitioned across 4 shared atomic counters...")
  let c_arr = [mem + 24, mem + 32, mem + 40, mem + 48]
  let pids_80 = []
  i = 0
  @while i < 80
    let c_target = c_arr[i % 4]
    let pid = maya_spawn(worker_inc_1, c_target)
    pids_80.push(pid)
    i = i + 1
  @end

  i = 0
  @while i < 80
    sys_wait4(pids_80[i], 0, 0, 0)
    i = i + 1
  @end

  let k = 0
  @while k < 4
    let target = c_arr[k]
    spin = 0
    @while atomic_read(target) < 20 && spin < 100000
      syscall(24, 0, 0, 0, 0, 0, 0)
      spin = spin + 1
    @end
    k = k + 1
  @end

  assert_eq(state, "TC-CONC-02.5: Partitioned Counter 0 == 20", atomic_read(c_arr[0]), 20)
  assert_eq(state, "TC-CONC-02.6: Partitioned Counter 1 == 20", atomic_read(c_arr[1]), 20)
  assert_eq(state, "TC-CONC-02.7: Partitioned Counter 2 == 20", atomic_read(c_arr[2]), 20)
  assert_eq(state, "TC-CONC-02.8: Partitioned Counter 3 == 20", atomic_read(c_arr[3]), 20)

  @! 5. Multi-Wave Burst Spawning Stress: 4 Waves x 25 Threads = 100 Spawns
  println("  ▶ Executing 4 consecutive burst waves of 25 green threads...")
  let ctr_wave = mem + 56
  let wave = 0
  @while wave < 4
    let pids_wave = []
    let w_i = 0
    @while w_i < 25
      let pid = maya_spawn(worker_inc_1, ctr_wave)
      pids_wave.push(pid)
      w_i = w_i + 1
    @end

    w_i = 0
    @while w_i < 25
      sys_wait4(pids_wave[w_i], 0, 0, 0)
      w_i = w_i + 1
    @end

    wave = wave + 1
  @end

  spin = 0
  @while atomic_read(ctr_wave) < 100 && spin < 100000
    syscall(24, 0, 0, 0, 0, 0, 0)
    spin = spin + 1
  @end
  assert_eq(state, "TC-CONC-02.9: 4 burst waves reached total count 100", atomic_read(ctr_wave), 100)
@end


@! ============================================================================
@! CATEGORY 3: WORK-STEALING DEQUE (CHASE-LEV) PRIMITIVES
@! ============================================================================

@fn test_work_stealing_deque_primitives(state)
  println("\n--- [Category 3] Work-Stealing Deque Primitives ---")

  let q = worker_deque_new()
  assert_eq(state, "TC-DEQ-01.1: Initial deque size is 0", deque_size(q), 0)
  assert_eq(state, "TC-DEQ-01.2: pop_bottom on empty deque returns -1", pop_bottom(q), 0 - 1)
  assert_eq(state, "TC-DEQ-01.3: steal_top on empty deque returns -1", steal_top(q), 0 - 1)

  @! LIFO Behavior for pop_bottom (local owner)
  push_bottom(q, 10)
  push_bottom(q, 20)
  push_bottom(q, 30)
  assert_eq(state, "TC-DEQ-01.4: Deque size after 3 pushes is 3", deque_size(q), 3)

  let p1 = pop_bottom(q)
  let p2 = pop_bottom(q)
  let p3 = pop_bottom(q)
  assert_eq(state, "TC-DEQ-01.5: pop_bottom returns 30 (LIFO 1st)", p1, 30)
  assert_eq(state, "TC-DEQ-01.6: pop_bottom returns 20 (LIFO 2nd)", p2, 20)
  assert_eq(state, "TC-DEQ-01.7: pop_bottom returns 10 (LIFO 3rd)", p3, 10)
  assert_eq(state, "TC-DEQ-01.8: Deque size is now 0", deque_size(q), 0)
  assert_eq(state, "TC-DEQ-01.9: pop_bottom on emptied deque returns -1", pop_bottom(q), 0 - 1)

  @! FIFO Behavior for steal_top (remote stealer)
  push_bottom(q, 100)
  push_bottom(q, 200)
  push_bottom(q, 300)

  let s1 = steal_top(q)
  let s2 = steal_top(q)
  let s3 = steal_top(q)
  assert_eq(state, "TC-DEQ-01.10: steal_top returns 100 (FIFO 1st)", s1, 100)
  assert_eq(state, "TC-DEQ-01.11: steal_top returns 200 (FIFO 2nd)", s2, 200)
  assert_eq(state, "TC-DEQ-01.12: steal_top returns 300 (FIFO 3rd)", s3, 300)
  assert_eq(state, "TC-DEQ-01.13: steal_top on emptied deque returns -1", steal_top(q), 0 - 1)

  @! Interleaved Concurrent Push / Pop / Steal Simulation
  push_bottom(q, 1)
  push_bottom(q, 2)
  push_bottom(q, 3)
  push_bottom(q, 4)

  @! Stealer takes from top (FIFO: 1)
  let st1 = steal_top(q)
  assert_eq(state, "TC-DEQ-01.14: Interleaved steal_top gets 1", st1, 1)

  @! Owner takes from bottom (LIFO: 4)
  let pb1 = pop_bottom(q)
  assert_eq(state, "TC-DEQ-01.15: Interleaved pop_bottom gets 4", pb1, 4)

  @! Stealer takes next top (FIFO: 2)
  let st2 = steal_top(q)
  assert_eq(state, "TC-DEQ-01.16: Interleaved steal_top gets 2", st2, 2)

  @! Owner takes remaining bottom (3)
  let pb2 = pop_bottom(q)
  assert_eq(state, "TC-DEQ-01.17: Interleaved pop_bottom gets 3", pb2, 3)

  @! Both now empty
  assert_eq(state, "TC-DEQ-01.18: Deque is empty after interleaved draining", deque_size(q), 0)
@end


@! ============================================================================
@! CATEGORY 4: MULTI-WORKER WORK-STEALING SIMULATION & LOAD BALANCING
@! ============================================================================

@fn test_work_stealing_scheduler_load_balancing(state)
  println("\n--- [Category 4] Multi-Worker Work-Stealing & Load Balancing ---")

  let sched = scheduler_new(4)
  assert_eq(state, "TC-SCHED-01.1: 4 worker threads initialized", sched.workers.len(), 4)

  @! Asymmetric Workload: 80 Tasks assigned entirely to Worker 0 (Workers 1, 2, 3 have 0 tasks)
  let i = 1
  @while i <= 80
    scheduler_spawn_task(sched, 0, 1, i, 0) @! Square of i
    i = i + 1
  @end

  assert_eq(state, "TC-SCHED-01.2: Worker 0 local queue contains 80 tasks", deque_size(sched.workers[0].local_queue), 80)
  assert_eq(state, "TC-SCHED-01.3: Worker 1 local queue contains 0 tasks", deque_size(sched.workers[1].local_queue), 0)
  assert_eq(state, "TC-SCHED-01.4: Worker 2 local queue contains 0 tasks", deque_size(sched.workers[2].local_queue), 0)
  assert_eq(state, "TC-SCHED-01.5: Worker 3 local queue contains 0 tasks", deque_size(sched.workers[3].local_queue), 0)

  @! Run scheduler until all tasks finish
  scheduler_run_all(sched)

  assert_eq(state, "TC-SCHED-01.6: All 80 tasks executed to completion", sched.total_completed, 80)
  assert_ge(state, "TC-SCHED-01.7: Work-stealing successfully occurred (total steals > 0)", sched.total_steals, 1)

  @! Verify that idle workers (1, 2, 3) contributed by stealing tasks from Worker 0
  let w0_exec = sched.workers[0].executed_counter
  let w1_exec = sched.workers[1].executed_counter
  let w2_exec = sched.workers[2].executed_counter
  let w3_exec = sched.workers[3].executed_counter

  assert_ge(state, "TC-SCHED-01.8: Worker 0 executed tasks", w0_exec, 1)
  assert_ge(state, "TC-SCHED-01.9: Worker 1 stole and executed tasks", w1_exec, 1)
  assert_ge(state, "TC-SCHED-01.10: Worker 2 stole and executed tasks", w2_exec, 1)
  assert_ge(state, "TC-SCHED-01.11: Worker 3 stole and executed tasks", w3_exec, 1)
  assert_eq(state, "TC-SCHED-01.12: Sum of worker executions matches total 80", w0_exec + w1_exec + w2_exec + w3_exec, 80)

  @! Verify task results correctness
  let t_first = sched.tasks[0]
  let t_last = sched.tasks[79]
  assert_eq(state, "TC-SCHED-01.13: Task 1 square result (1 * 1 = 1)", t_first.result, 1)
  assert_eq(state, "TC-SCHED-01.14: Task 80 square result (80 * 80 = 6400)", t_last.result, 6400)
@end


@! ============================================================================
@! CATEGORY 5: JOINHANDLE RESOLUTION & TASK DEPENDENCY GRAPHS
@! ============================================================================

@fn test_join_handle_resolution(state)
  println("\n--- [Category 5] JoinHandle Resolution & Task Graphs ---")

  let sched = scheduler_new(4)

  @! 1. Simple JoinHandle resolution
  let h_sq = scheduler_spawn_task(sched, 1, 1, 12, 0) @! 12 * 12 = 144
  let res_sq = join_handle_join(sched, h_sq)
  assert_eq(state, "TC-JOIN-01.1: JoinHandle::join resolves square(12) == 144", res_sq, 144)

  @! 2. Parallel Tasks and Array Join Resolution (sum of i^2 for i in 1..10 = 385)
  let task_handles = []
  let i = 1
  @while i <= 10
    let h = scheduler_spawn_task(sched, i % 4, 1, i, 0)
    task_handles.push(h)
    i = i + 1
  @end

  let sum_sq = 0
  let h_idx = 0
  @while h_idx < 10
    let r = join_handle_join(sched, task_handles[h_idx])
    sum_sq = sum_sq + r
    h_idx = h_idx + 1
  @end
  assert_eq(state, "TC-JOIN-01.2: Sum of 10 joined square tasks is 385", sum_sq, 385)

  @! 3. Fibonacci Computation via Task Join (Fib(10) == 55)
  let h_fib = scheduler_spawn_task(sched, 2, 4, 10, 0)
  let res_fib = join_handle_join(sched, h_fib)
  assert_eq(state, "TC-JOIN-01.3: JoinHandle::join resolves fib(10) == 55", res_fib, 55)

  @! 4. Divide-and-Conquer Range Sum (Sum 1..100 = 5050 split across 4 workers)
  let h_q1 = scheduler_spawn_task(sched, 0, 5, 1, 25)    @! 1..25 = 325
  let h_q2 = scheduler_spawn_task(sched, 1, 5, 26, 50)   @! 26..50 = 950
  let h_q3 = scheduler_spawn_task(sched, 2, 5, 51, 75)   @! 51..75 = 1575
  let h_q4 = scheduler_spawn_task(sched, 3, 5, 76, 100)  @! 76..100 = 2200

  let r1 = join_handle_join(sched, h_q1)
  let r2 = join_handle_join(sched, h_q2)
  let r3 = join_handle_join(sched, h_q3)
  let r4 = join_handle_join(sched, h_q4)

  assert_eq(state, "TC-JOIN-01.4: Quadrant 1 sum (1..25) is 325", r1, 325)
  assert_eq(state, "TC-JOIN-01.5: Quadrant 2 sum (26..50) is 950", r2, 950)
  assert_eq(state, "TC-JOIN-01.6: Quadrant 3 sum (51..75) is 1575", r3, 1575)
  assert_eq(state, "TC-JOIN-01.7: Quadrant 4 sum (76..100) is 2200", r4, 2200)
  assert_eq(state, "TC-JOIN-01.8: Total joined Range Sum (1..100) is 5050", r1 + r2 + r3 + r4, 5050)

  @! 5. Hierarchical Tree-Reduction Task Graph (16 leaves -> 8 -> 4 -> 2 -> 1 root sum)
  @! Sum of 1..16 = 136
  let leaves = []
  let leaf_i = 1
  @while leaf_i <= 16
    let h_leaf = scheduler_spawn_task(sched, leaf_i % 4, 2, leaf_i, 0)
    leaves.push(h_leaf)
    leaf_i = leaf_i + 1
  @end

  @! Level 1: 8 intermediate tasks
  let level1 = []
  let l_idx = 0
  @while l_idx < 8
    let val_a = join_handle_join(sched, leaves[l_idx * 2])
    let val_b = join_handle_join(sched, leaves[l_idx * 2 + 1])
    let h_l1 = scheduler_spawn_task(sched, l_idx % 4, 2, val_a, val_b)
    level1.push(h_l1)
    l_idx = l_idx + 1
  @end

  @! Level 2: 4 intermediate tasks
  let level2 = []
  l_idx = 0
  @while l_idx < 4
    let v_a = join_handle_join(sched, level1[l_idx * 2])
    let v_b = join_handle_join(sched, level1[l_idx * 2 + 1])
    let h_l2 = scheduler_spawn_task(sched, l_idx % 4, 2, v_a, v_b)
    level2.push(h_l2)
    l_idx = l_idx + 1
  @end

  @! Level 3: 2 intermediate tasks
  let level3 = []
  l_idx = 0
  @while l_idx < 2
    let va = join_handle_join(sched, level2[l_idx * 2])
    let vb = join_handle_join(sched, level2[l_idx * 2 + 1])
    let h_l3 = scheduler_spawn_task(sched, l_idx % 4, 2, va, vb)
    level3.push(h_l3)
    l_idx = l_idx + 1
  @end

  @! Level 4: Root task
  let v_final_a = join_handle_join(sched, level3[0])
  let v_final_b = join_handle_join(sched, level3[1])
  let h_root = scheduler_spawn_task(sched, 0, 2, v_final_a, v_final_b)
  let tree_sum = join_handle_join(sched, h_root)

  assert_eq(state, "TC-JOIN-01.9: Hierarchical 16-node Tree Reduction sum is 136", tree_sum, 136)
@end


@! ============================================================================
@! CATEGORY 6: HIGH-VOLUME WORK-STEALING STRESS LOOP
@! ============================================================================

@fn test_high_volume_scheduler_stress(state)
  println("\n--- [Category 6] High-Volume Work-Stealing Stress Loop ---")

  let sched = scheduler_new(8)
  assert_eq(state, "TC-STRESS-01.1: 8-worker scheduler initialized", sched.workers.len(), 8)

  @! Spawn 200 tasks distributed unevenly (Worker 0 has 100, Worker 4 has 100, others 0)
  let i = 0
  @while i < 100
    scheduler_spawn_task(sched, 0, 1, i, 0)
    scheduler_spawn_task(sched, 4, 1, i, 0)
    i = i + 1
  @end

  assert_eq(state, "TC-STRESS-01.2: 200 tasks submitted to scheduler", sched.total_tasks, 200)

  scheduler_run_all(sched)

  assert_eq(state, "TC-STRESS-01.3: All 200 tasks completed under 8-worker contention", sched.total_completed, 200)
  assert_ge(state, "TC-STRESS-01.4: Substantial steals occurred across 8 workers", sched.total_steals, 10)
@end


@! ============================================================================
@! MASTER RUNNER ENTRYPOINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ MAYA CONCURRENCY & GREEN THREADS END-TO-END STRESS SUITE")
  println("=================================================================")

  let state = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_atomic_primitives(state)
  test_parallel_green_threads_spawning(state)
  test_work_stealing_deque_primitives(state)
  test_work_stealing_scheduler_load_balancing(state)
  test_join_handle_resolution(state)
  test_high_volume_scheduler_stress(state)

  println("\n=================================================================")
  println("📊 CONCURRENCY SUITE EXECUTION SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + state.total.to_str())
  println("  Passed           : " + state.passed.to_str())
  println("  Failed           : " + state.failed.to_str())

  @if state.failed == 0
    println("\n✓ [SUCCESS] 100% of Concurrency & Green Threads Stress Tests PASSED!")
    return 0
  @else
    println("\n✗ [FAILURE] Failures detected in Concurrency & Green Threads Suite.")
    return 1
  @end
@end
