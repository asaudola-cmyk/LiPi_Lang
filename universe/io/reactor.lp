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

import "universe/io/uring.lp"
import "universe/core/collections.lp"
import "universe/core/string.lp"
import "universe/os/syscalls.lp"

// ── 1. Reactor Token & Handler Record ─────────────────────────────────────────
struct ReactorTask
  tag_id: i64
  op_type: i64
  fd: i64
  buf_addr: i64
  buf_len: i64
  offset: i64
  status: i64     // 0 = Pending, 1 = Completed, 2 = Failed
  res_bytes: i64
end

// ── 2. Unified IOUring Reactor Structure ──────────────────────────────────────
struct IOUringReactor
  ring: IOUringQueue
  capacity: i64
  tasks: array
  next_tag: i64
  total_submitted: i64
  total_completed: i64
  is_active: i64
end

// ── 3. Reactor Initialization ─────────────────────────────────────────────────
fn reactor_init(queue_depth: i64) -> IOUringReactor
  ring = io_uring_init(queue_depth)
  return IOUringReactor(ring, queue_depth, [], 1, 0, 0, 1)
end

// ── 4. Asynchronous Task Submissions ──────────────────────────────────────────
fn reactor_async_read(reactor: IOUringReactor, fd: i64, buf_addr: i64, nbytes: i64, offset: i64) -> i64
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = ReactorTask(tag, 22, fd, buf_addr, nbytes, offset, 0, 0)
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_read(reactor.ring, fd, buf_addr, nbytes, offset, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
end

fn reactor_async_write(reactor: IOUringReactor, fd: i64, buf_addr: i64, nbytes: i64, offset: i64) -> i64
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = ReactorTask(tag, 23, fd, buf_addr, nbytes, offset, 0, 0)
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_write(reactor.ring, fd, buf_addr, nbytes, offset, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
end

fn reactor_async_nop(reactor: IOUringReactor) -> i64
  tag = reactor.next_tag
  reactor.next_tag = tag + 1

  task = ReactorTask(tag, 0, 0 - 1, 0, 0, 0, 0, 0)
  reactor.tasks = reactor.tasks.push(task)

  ring = io_uring_prep_nop(reactor.ring, tag)
  reactor.ring = ring
  reactor.total_submitted = reactor.total_submitted + 1
  return tag
end

// ── 5. Batch Submission & Completion Reaping ─────────────────────────────────
// WHY: Commits all prepared SQEs in ring buffer to kernel via sys_io_uring_enter (426)
// and reaps corresponding completion queue entries in a single step.
fn reactor_submit_batch(reactor: IOUringReactor) -> i64
  ring = reactor.ring
  to_submit = ring.sq_tail - ring.sq_head
  if to_submit <= 0
    return 0
  end

  submitted = io_uring_submit_and_reap(ring)
  reactor.ring = ring

  // Resolve completed tasks
  cq_len = ring.cqes.len()
  completed_count = 0
  i = 0
  while i < cq_len
    cqe = ring.cqes[i]
    tag = cqe.cqe_tag
    res = cqe.res

    // Find matching task
    ti = 0
    t_count = reactor.tasks.len()
    while ti < t_count
      task = reactor.tasks[ti]
      if task.tag_id == tag and task.status == 0
        task.status = 1
        task.res_bytes = res
        reactor.total_completed = reactor.total_completed + 1
        completed_count = completed_count + 1
      end
      ti = ti + 1
    end
    i = i + 1
  end

  return submitted
end

// ── 6. Reactor Teardown ───────────────────────────────────────────────────────
fn reactor_close(reactor: IOUringReactor) -> i64
  if reactor.is_active == 0
    return 0
  end
  res = io_uring_close(reactor.ring)
  reactor.is_active = 0
  return 1
end
