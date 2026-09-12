// ==============================================================================
// 👑 LIPI UNIFIED IO_URING ASYNC EVENT REACTOR (universe/io/reactor.lp)
// Standard: Linux io_uring (Syscalls 425, 426, 427) High-Volume Reactor Engine
// 100% Pure Lipi Implementation — Zero Libc | Zero C | Zero Node.js Event Loop
// ==============================================================================
//
// WHY: Traditional epoll and synchronous syscalls incur CPU context-switch penalties
// and lock contention at high request volumes. The Lipi io_uring Reactor allows
// applications (web servers, database engines, P2P nodes) to submit hundreds of
// asynchronous file/socket operations in a single kernel transition, achieving 1M+ IOPS.
// ==============================================================================

import "universe/io/uring"
import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

// ── 1. Reactor Token & Handler Record ─────────────────────────────────────────
@struct ReactorTask
  tag_id: i64
  op_type: i64
  fd: i64
  buf_addr: i64
  buf_len: i64
  offset: i64
  status: i64     // 0 = Pending, 1 = Completed, 2 = Failed
  res_bytes: i64
@end

// ── 2. Unified IOUring Reactor Structure ──────────────────────────────────────
@struct IOUringReactor
  ring: IOUringQueue
  capacity: i64
  tasks: array
  next_tag: i64
  total_submitted: i64
  total_completed: i64
  is_active: i64
@end

// ── 3. Reactor Initialization ─────────────────────────────────────────────────
@fn reactor_init(queue_depth)
  ring = io_uring_init(queue_depth)
  return {
    ring: ring,
    capacity: queue_depth,
    tasks: [],
    next_tag: 1,
    total_submitted: 0,
    total_completed: 0,
    is_active: 1
  }
@end

// ── 4. Asynchronous Task Submissions ──────────────────────────────────────────
@fn reactor_async_read(reactor, fd, buf_addr, nbytes, offset)
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = {
    tag_id: tag,
    op_type: 22, // IORING_OP_READ
    fd: fd,
    buf_addr: buf_addr,
    buf_len: nbytes,
    offset: offset,
    status: 0,
    res_bytes: 0
  }
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_read(reactor.ring, fd, buf_addr, nbytes, offset, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
@end

@fn reactor_async_write(reactor, fd, buf_addr, nbytes, offset)
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = {
    tag_id: tag,
    op_type: 23, // IORING_OP_WRITE
    fd: fd,
    buf_addr: buf_addr,
    buf_len: nbytes,
    offset: offset,
    status: 0,
    res_bytes: 0
  }
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_write(reactor.ring, fd, buf_addr, nbytes, offset, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
@end

@fn reactor_async_nop(reactor)
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = {
    tag_id: tag,
    op_type: 0, // IORING_OP_NOP
    fd: 0 - 1,
    buf_addr: 0,
    buf_len: 0,
    offset: 0,
    status: 0,
    res_bytes: 0
  }
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_nop(reactor.ring, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
@end

// ── 5. Batch Submission & Completion Reaping ─────────────────────────────────
// WHY: Commits all prepared SQEs in ring buffer to kernel via sys_io_uring_enter (426)
// and reaps corresponding completion queue entries in a single step.
@fn reactor_submit_batch(reactor)
  ring = reactor.ring
  to_submit = ring.sq_tail - ring.sq_head
  @if to_submit <= 0 return 0 @end

  submitted = io_uring_submit_and_reap(ring)
  reactor.ring = ring

  // Resolve completed tasks
  cq_len = ring.cqes.len()
  completed_count = 0
  i = 0
  @while i < cq_len
    cqe = ring.cqes[i]
    tag = cqe.cqe_tag
    res = cqe.res

    // Find matching task
    ti = 0
    t_count = reactor.tasks.len()
    @while ti < t_count
      task = reactor.tasks[ti]
      @if task.tag_id == tag && task.status == 0
        task.status = 1
        task.res_bytes = res
        reactor.total_completed = reactor.total_completed + 1
        completed_count = completed_count + 1
      @end
      ti = ti + 1
    @end
    i = i + 1
  @end

  return submitted
@end

// ── 6. Reactor Teardown ───────────────────────────────────────────────────────
@fn reactor_close(reactor)
  @if reactor.is_active == 0 return 0 @end
  res = io_uring_close(reactor.ring)
  reactor.is_active = 0
  return res
@end
