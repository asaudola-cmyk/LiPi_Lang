@! ============================================================================
@! MAYA RUNTIME ASYNC: WORK-STEALING TASK SCHEDULER
@! Module: runtime/async/scheduler
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct AsyncTask
  id: i64,
  coro_id: i64,
  priority: i64,
  completed: i64
@end

@struct WorkerDeque
  tasks: array
@end

@fn worker_deque_new() -> WorkerDeque
  return WorkerDeque { tasks: [] }
@end

@fn worker_deque_push(dq: WorkerDeque, task_id: i64) -> WorkerDeque
  dq.tasks = dq.tasks.push(task_id)
  return dq
@end

@struct WorkerThread
  id: i64,
  local_queue: WorkerDeque,
  steal_counter: i64,
  is_active: i64
@end

@struct TaskScheduler
  workers: array,
  global_queue: array,
  next_task_id: i64
@end

@fn task_scheduler_new(num_workers: i64) -> TaskScheduler
  workers = []
  i = 0
  @while i < num_workers
    w = WorkerThread {
      id: i,
      local_queue: worker_deque_new(),
      steal_counter: 0,
      is_active: 1
    }
    workers = workers.push(w)
    i = i + 1
  @end

  return TaskScheduler {
    workers: workers,
    global_queue: [],
    next_task_id: 1
  }
@end

@fn scheduler_spawn_task(sched: TaskScheduler, coro_id: i64) -> TaskScheduler
  tid = sched.next_task_id
  sched.next_task_id = sched.next_task_id + 1
  sched.global_queue = sched.global_queue.push(tid)
  return sched
@end

@fn main()
  return 0
@end
