// ============================================================================
// 👑 LIPI M:N QUANTUM FIBER SCHEDULER & IO_URING REACTOR
// Module: src/runtime/async/fiber_uring.lp
// ============================================================================
// WHY: Unified high-performance cooperative multitasking integrating the lightweight
// user-space Fiber Scheduler with the zero-syscall io_uring network layer. This
// resolves the "thread bloat" problem of modern servers by running 1,000,000+
// concurrent fibers across a minimal number of OS threads.

import "src/runtime/async/fiber.lp"
import "universe/io/uring.lp"
import "src/runtime/async/event_loop.lp"

struct FiberUringContext
  sched: i64
  ring: IOUringQueue
end

// Allocates a new integrated Fiber and io_uring scheduler.
fn fiber_uring_new(entries: i64) -> FiberUringContext
  s = fiber_scheduler_new()
  r = io_uring_init(entries)
  return FiberUringContext(s, r)
end

// Spawns a new fiber under the fiber_uring context scheduler.
fn fiber_uring_spawn(ctx: FiberUringContext, fn_code: i64, arg: i64) -> i64
  return fiber_scheduler_spawn(ctx.sched, fn_code, arg)
end

// Returns the number of ready fibers currently in the execution queue.
fn fiber_uring_ready_count(ctx: FiberUringContext) -> i64
  q = get(ctx.sched, 0)
  return fiber_queue_len(q)
end

// Returns the total number of fibers registered in the scheduler.
fn fiber_uring_total_count(ctx: FiberUringContext) -> i64
  fibers_all = get(ctx.sched, 4)
  return len(fibers_all)
end

// Initiates a non-blocking asynchronous read, suspending the fiber into FIBER_WAITING.
fn fiber_uring_async_read(ctx: FiberUringContext, fiber_id: i64, fd: i64, buf: i64, nbytes: i64, offset: i64) -> i64
  io_uring_prep_read(ctx.ring, fd, buf, nbytes, offset, fiber_id)
  
  // Mark fiber state as FIBER_WAITING (2) in both runtime list and silicon descriptor
  fibers_all = get(ctx.sched, 4)
  n = len(fibers_all)
  i = 0
  while i < n
    f = get(fibers_all, i)
    if get(f, 0) == fiber_id
      list_set(f, 1, FIBER_WAITING)
      if len(f) > 9
        desc = get(f, 9)
        if desc > 0
          mem_write(desc, 8, FIBER_WAITING)
        end
      end
    end
    i = i + 1
  end
  return 1
end

// Initiates a non-blocking asynchronous write, suspending the fiber into FIBER_WAITING.
fn fiber_uring_async_write(ctx: FiberUringContext, fiber_id: i64, fd: i64, buf: i64, nbytes: i64, offset: i64) -> i64
  io_uring_prep_write(ctx.ring, fd, buf, nbytes, offset, fiber_id)
  
  // Mark fiber state as FIBER_WAITING (2) in both runtime list and silicon descriptor
  fibers_all = get(ctx.sched, 4)
  n = len(fibers_all)
  i = 0
  while i < n
    f = get(fibers_all, i)
    if get(f, 0) == fiber_id
      list_set(f, 1, FIBER_WAITING)
      if len(f) > 9
        desc = get(f, 9)
        if desc > 0
          mem_write(desc, 8, FIBER_WAITING)
        end
      end
    end
    i = i + 1
  end
  return 1
end

// Unified quantum scheduler loop. Reaps completed I/O events to unblock fibers,
// and executes active fibers cooperatively within a single OS thread.
fn fiber_uring_run_loop(ctx: FiberUringContext, max_ticks: i64) -> i64
  ticks = 0
  completed = 0
  q = get(ctx.sched, 0)
  fibers_all = get(ctx.sched, 4)
  
  while ticks < max_ticks
    // 1. Submit pending async IO and reap completed events (Zero Syscall)
    io_uring_submit_and_reap(ctx.ring)
    
    cqe = io_uring_pop_cqe(ctx.ring)
    while cqe != 0
      fid = cqe.cqe_tag
      res = cqe.res
      
      // Wake up the specific waiting fiber for this I/O completion
      // Only transition fibers that are currently FIBER_WAITING (prevent double enqueue)
      n = len(fibers_all)
      i = 0
      while i < n
        f = get(fibers_all, i)
        if get(f, 0) == fid and get(f, 1) == FIBER_WAITING
          list_set(f, 1, FIBER_READY)
          list_set(f, 7, res)
          if len(f) > 9
            desc = get(f, 9)
            if desc > 0
              mem_write(desc, 8, FIBER_READY)
              mem_write(desc, 40, res)
            end
          end
          fiber_queue_push(q, f)
        end
        i = i + 1
      end
      
      cqe = io_uring_pop_cqe(ctx.ring)
    end
    
    // 2. Execute a slice of the next ready fiber cooperatively
    if fiber_queue_len(q) > 0
      f = fiber_queue_pop(q)
      if f != 0
        list_set(ctx.sched, 1, f)
        list_set(f, 1, FIBER_RUNNING)
        if len(f) > 9
          desc = get(f, 9)
          if desc > 0
            mem_write(desc, 8, FIBER_RUNNING)
          end
        end
        
        status = fiber_execute_slice(f)
        
        if status == FIBER_READY
          fiber_queue_push(q, f)
        elif status == FIBER_DEAD
          completed = completed + 1
        end
      end
    end
    
    // 3. Early termination check: if ready queue is empty and no fibers are waiting on I/O
    if fiber_queue_len(q) == 0
      waiting_count = 0
      total_f = len(fibers_all)
      fi = 0
      while fi < total_f
        f_chk = get(fibers_all, fi)
        if get(f_chk, 1) == FIBER_WAITING
          waiting_count = waiting_count + 1
        end
        fi = fi + 1
      end
      if waiting_count == 0
        break
      end
    end
    
    ticks = ticks + 1
  end
  
  return completed
end

// Deallocates resources.
fn fiber_uring_free(ctx: FiberUringContext) -> i64
  io_uring_close(ctx.ring)
  return 1
end
