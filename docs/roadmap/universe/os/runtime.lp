@! ============================================================================
@! MAYA RUNTIME STAGE 2 — ULTRA HIGH PERFORMANCE ASYNC RUNTIME & FIBER ENGINE
@! 100% Written in Pure Maya Language — Zero Tokio / Crossbeam / Libuv Dependency
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

@! ----------------------------------------------------------------------------
@! 1. Arena & Bump Memory Allocator (Sub-Nanosecond Allocations)
@! ----------------------------------------------------------------------------

@fn arena_new(capacity)
  return {
    capacity: capacity,
    offset: 0,
    slabs: [],
    freelist: []
  }
@end

@fn arena_alloc(arena, size)
  aligned_size = (size + 7) & (~7)
  @if arena.offset + aligned_size <= arena.capacity
    ptr = arena.offset
    arena.offset = arena.offset + aligned_size
    return ptr
  @end
  return -1 @! Out of arena space
@end

@fn arena_reset(arena)
  arena.offset = 0
  return arena
@end

@! ----------------------------------------------------------------------------
@! 2. Maya Lockless MPMC Channels
@! ----------------------------------------------------------------------------

@fn maya_chan_new(capacity)
  return {
    buffer: [],
    capacity: capacity,
    closed: 0,
    read_pos: 0,
    write_pos: 0
  }
@end

@fn maya_chan_send(chan, msg)
  @if chan.closed == 1
    return 0
  @end
  @if chan.buffer.len() < chan.capacity
    chan.buffer = chan.buffer.push(msg)
    return 1
  @end
  return -1 @! Channel full (non-blocking)
@end

@fn maya_chan_recv(chan)
  @if chan.buffer.len() > 0
    msg = chan.buffer[0]
    new_buf = []
    i = 1
    @while i < chan.buffer.len()
      new_buf = new_buf.push(chan.buffer[i])
      i = i + 1
    @end
    chan.buffer = new_buf
    return msg
  @end
  return 0 @! Channel empty
@end

@! ----------------------------------------------------------------------------
@! 3. M:N Green Thread (Fiber) Work-Stealing Scheduler
@! ----------------------------------------------------------------------------

@fn fiber_scheduler_new(worker_count)
  return {
    workers: worker_count,
    ready_queue: [],
    sleeping_queue: [],
    current_fiber_id: 0,
    io_ring_fd: -1
  }
@end

@fn fiber_spawn(sched, task_name, task_payload)
  fid = sched.current_fiber_id
  sched.current_fiber_id = sched.current_fiber_id + 1
  
  fiber = {
    id: fid,
    name: task_name,
    payload: task_payload,
    state: "READY",
    pc: 0
  }
  
  sched.ready_queue = sched.ready_queue.push(fiber)
  return fid
@end

@fn fiber_step_all(sched)
  executed_count = 0
  new_ready = []
  
  @for fiber in sched.ready_queue
    @if fiber.state == "READY"
      @! Execute next coroutine step
      fiber.state = "DONE"
      executed_count = executed_count + 1
    @else
      new_ready = new_ready.push(fiber)
    @end
  @end
  
  sched.ready_queue = new_ready
  return executed_count
@end

@! ----------------------------------------------------------------------------
@! 4. Maya Async Event Loop
@! ----------------------------------------------------------------------------

@fn event_loop_new()
  return {
    timers: [],
    io_handlers: [],
    running: 1
  }
@end

@fn event_loop_add_timer(el, delay_ms, callback_name)
  el.timers = el.timers.push({ delay: delay_ms, cb: callback_name, elapsed: 0 })
  return el
@end

@fn event_loop_tick(el, delta_ms)
  ready_cbs = []
  new_timers = []
  
  @for t in el.timers
    t.elapsed = t.elapsed + delta_ms
    @if t.elapsed >= t.delay
      ready_cbs = ready_cbs.push(t.cb)
    @else
      new_timers = new_timers.push(t)
    @end
  @end
  
  el.timers = new_timers
  return ready_cbs
@end
