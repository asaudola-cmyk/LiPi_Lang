// ============================================================================
// 👑 LIPI RUNTIME ASYNC: WORK-STEALING TASK SCHEDULER
// Module: src/runtime/async/scheduler.lp
// 100% Pure LiPi Implementation — Multi-Core Fiber Scheduler
// ============================================================================
// WHY: Work-stealing task schedulers balance asynchronous execution loads
// dynamically across multiple worker threads or fibers. When a worker runs out
// of local tasks, it attempts to steal tasks from victim deques, maximizing CPU
// utilization without lock contention.

// ── Async Task Descriptor ───────────────────────────────────────────────────
struct AsyncTask
  id: i64
  coro_id: i64
  priority: i64
  completed: i64
end

// ── Lock-Free Worker Double-Ended Queue (Deque) ──────────────────────────────
struct WorkerDeque
  tasks: array
end

// Allocates an empty worker deque.
fn worker_deque_new() -> WorkerDeque
  return WorkerDeque([])
end

// Pushes a task ID onto the worker's local deque.
fn worker_deque_push(dq: WorkerDeque, task_id: i64) -> WorkerDeque
  dq.tasks = dq.tasks.push(task_id)
  return dq
end

// ── Worker Thread Execution State ───────────────────────────────────────────
struct WorkerThread
  id: i64
  local_queue: WorkerDeque
  steal_counter: i64
  is_active: i64
end

// ── Multi-Core Task Scheduler ───────────────────────────────────────────────
struct TaskScheduler
  workers: array
  global_queue: array
  next_task_id: i64
end

// Allocates and initializes a new task scheduler with num_workers worker threads.
fn task_scheduler_new(num_workers: i64) -> TaskScheduler
  workers = []
  i = 0
  while i < num_workers
    w = WorkerThread(i, worker_deque_new(), 0, 1)
    workers = workers.push(w)
    i = i + 1
  end

  return TaskScheduler(workers, [], 1)
end

// Enqueues a new coroutine task into the scheduler's global dispatch queue.
fn scheduler_spawn_task(sched: TaskScheduler, coro_id: i64) -> TaskScheduler
  tid = sched.next_task_id
  sched.next_task_id = sched.next_task_id + 1
  sched.global_queue = sched.global_queue.push(tid)
  return sched
end
