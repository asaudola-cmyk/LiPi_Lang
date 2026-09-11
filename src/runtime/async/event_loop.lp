@! ============================================================================
@! MAYA RUNTIME ASYNC: EVENT LOOP & EPOLL ENGINE
@! Module: runtime/async/event_loop
@! 100% Pure Maya Implementation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@enum IOEventKind
  Readable = 1
  Writable = 2
  Timer = 3
  Signal = 4
@end

@struct EpollEvent
  events: i64,
  fd: i64
@end

@struct Timer
  id: i64,
  expiry_time: i64,
  is_active: i64
@end

@struct EventLoop
  epoll_fd: i64,
  registered_fds: array,
  timers: array,
  pending_tasks: array,
  is_running: i64,
  next_timer_id: i64
@end

@fn event_loop_new() -> EventLoop
  return EventLoop {
    epoll_fd: 0,
    registered_fds: [],
    timers: [],
    pending_tasks: [],
    is_running: 0,
    next_timer_id: 1
  }
@end

@fn event_loop_register(loop: EventLoop, fd: i64, interest: i64) -> EventLoop
  loop.registered_fds = loop.registered_fds.push(fd)
  return loop
@end

@fn event_loop_deregister(loop: EventLoop, fd: i64) -> EventLoop
  new_fds = []
  i = 0
  len = loop.registered_fds.len()
  @while i < len
    @if loop.registered_fds[i] != fd
      new_fds = new_fds.push(loop.registered_fds[i])
    @end
    i = i + 1
  @end
  loop.registered_fds = new_fds
  return loop
@end

@fn event_loop_set_timeout(loop: EventLoop, delay_ms: i64) -> EventLoop
  tid = loop.next_timer_id
  loop.next_timer_id = loop.next_timer_id + 1
  t = Timer {
    id: tid,
    expiry_time: delay_ms,
    is_active: 1
  }
  loop.timers = loop.timers.push(t)
  return loop
@end

@struct Future
  is_ready: i64,
  value_int: i64,
  value_str: string
@end

@fn future_new() -> Future
  return Future {
    is_ready: 0,
    value_int: 0,
    value_str: ""
  }
@end

@fn future_resolve_int(fut: Future, val: i64) -> Future
  fut.is_ready = 1
  fut.value_int = val
  return fut
@end

@fn future_resolve_str(fut: Future, val: string) -> Future
  fut.is_ready = 1
  fut.value_str = val
  return fut
@end
