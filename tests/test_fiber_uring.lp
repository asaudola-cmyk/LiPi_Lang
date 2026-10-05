// ==============================================================================
// 🧪 LIPI TEST SUITE: M:N QUANTUM FIBER SCHEDULER & IO_URING REACTOR
// File: tests/test_fiber_uring.lp
// Module Under Test: src/runtime/async/fiber_uring.lp
// 100% Pure LiPi Sovereign Implementation — Zero External / C Dependencies
// ==============================================================================
// WHY: Validates the seamless harmonization and integration of user-space
// green-thread fibers with the zero-syscall Linux io_uring asynchronous reactor.
// Ensures deterministic fiber scheduling, async I/O state transitions,
// silicon descriptor register/state synchronization, CQE event reaping,
// multi-fiber concurrency, and safe resource reclamation.

import "src/runtime/async/fiber_uring.lp"
import "src/runtime/async/coroutine.lp"
import "src/runtime/async/event_loop.lp"
import "src/runtime/async/scheduler.lp"

fn assert_true(cond: i64, msg: string) -> i64
  if cond == 0
    say("  ❌ FAILED: " + msg)
    exit(1)
  end
  say("  ✔ " + msg)
  return 1
end

fn assert_eq(actual: i64, expected: i64, msg: string) -> i64
  if actual != expected
    say("  ❌ FAILED: " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")")
    exit(1)
  end
  say("  ✔ " + msg)
  return 1
end

fn main()
  say("=================================================================")
  say("👑 LIPI ASYNC: FIBER & IO_URING REACTOR INTEGRATION TEST SUITE")
  say("=================================================================")

  // ── Test 1: Context Creation & Convenience Spawner ──────────────────────────
  // WHY: Verify that integrated context correctly instantiates both the lock-free
  // ready queue fiber scheduler and the memory-mapped io_uring ring structures.
  say("[1/6] Testing fiber_uring_new initialization & spawn helpers...")
  ctx = fiber_uring_new(64)
  assert_true(ctx.sched != 0, "Fiber scheduler allocated successfully")
  assert_true(ctx.ring != 0, "io_uring queue allocated successfully")
  assert_eq(fiber_uring_ready_count(ctx), 0, "Initial ready queue count is 0")
  assert_eq(fiber_uring_total_count(ctx), 0, "Initial total fiber count is 0")

  // Spawn fiber using high-level spawn helper
  spawned_id = fiber_uring_spawn(ctx, 1, 2)
  assert_eq(spawned_id, 1, "First spawned fiber assigned ID 1")
  assert_eq(fiber_uring_ready_count(ctx), 1, "Ready queue count incremented to 1")
  assert_eq(fiber_uring_total_count(ctx), 1, "Total fiber count incremented to 1")

  // Run the spawned fiber to completion
  c_spawn = fiber_uring_run_loop(ctx, 50)
  assert_eq(c_spawn, 1, "High-level spawned fiber completed cooperatively")
  assert_eq(fiber_uring_ready_count(ctx), 0, "Ready queue emptied after completion")

  // ── Test 2: Single Cooperative Fiber Execution ──────────────────────────────
  // WHY: Validates System V AMD64 silicon context switching and cooperative
  // time-slicing across discrete scheduler ticks.
  say("[2/6] Testing single cooperative fiber time-slicing...")
  f1 = fiber_new(101, 1, 3, 4096)
  q = get(ctx.sched, 0)
  fibers_all = get(ctx.sched, 4)
  fiber_queue_push(q, f1)
  push(fibers_all, f1)

  c1 = fiber_uring_run_loop(ctx, 50)
  assert_eq(c1, 1, "Fiber 101 ran cooperatively to completion")
  assert_eq(get(f1, 1), FIBER_DEAD, "Fiber 101 transitioned to FIBER_DEAD (3)")
  assert_eq(get(f1, 7), 3, "Fiber 101 result counter reached 3")

  // ── Test 3: Multiple Concurrent Fibers ──────────────────────────────────────
  // WHY: Validates fair scheduling across multiple fibers interleaving counter
  // loops (Task 1) and accumulator operations (Task 2) without starvation.
  say("[3/6] Testing multi-fiber concurrent execution loop...")
  f_a = fiber_new(201, 1, 2, 4096)
  f_b = fiber_new(202, 1, 4, 4096)
  f_c = fiber_new(203, 2, 50, 4096) // Accumulator task (+50)

  fiber_queue_push(q, f_a)
  fiber_queue_push(q, f_b)
  fiber_queue_push(q, f_c)
  push(fibers_all, f_a)
  push(fibers_all, f_b)
  push(fibers_all, f_c)

  c_multi = fiber_uring_run_loop(ctx, 150)
  assert_eq(c_multi, 3, "All 3 concurrent fibers completed execution")
  assert_eq(get(f_a, 1), FIBER_DEAD, "Fiber 201 reached FIBER_DEAD")
  assert_eq(get(f_b, 1), FIBER_DEAD, "Fiber 202 reached FIBER_DEAD")
  assert_eq(get(f_c, 1), FIBER_DEAD, "Fiber 203 reached FIBER_DEAD")
  assert_eq(get(f_c, 7), 50, "Fiber 203 accumulator result is 50")

  // ── Test 4: Async I/O Suspension & Silicon Descriptor Sync ───────────────────
  // WHY: Ensures that when an async I/O operation is initiated, the fiber transitions
  // to FIBER_WAITING in BOTH the Lipi object array and the physical AMD64 silicon
  // context descriptor (offset 8), preventing desynchronization.
  say("[4/6] Testing async I/O registration and silicon descriptor synchronization...")
  f_io = fiber_new(301, 1, 5, 4096)
  push(fibers_all, f_io)
  assert_eq(get(f_io, 1), FIBER_READY, "Initial fiber state is FIBER_READY (0)")

  // Register non-blocking read operation
  buf = malloc(128)
  r_res = fiber_uring_async_read(ctx, 301, 0, buf, 64, 0)
  assert_eq(r_res, 1, "Async read operation prepared successfully")
  assert_eq(get(f_io, 1), FIBER_WAITING, "Fiber 301 suspended to FIBER_WAITING in list")
  
  // Verify physical silicon descriptor state at desc + 8
  desc_io = get(f_io, 9)
  assert_true(desc_io > 0, "Fiber 301 silicon descriptor pointer is valid")
  desc_state = mem_read(desc_io, 8)
  assert_eq(desc_state, FIBER_WAITING, "Silicon descriptor memory holds FIBER_WAITING (2)")

  // Register non-blocking write operation
  w_res = fiber_uring_async_write(ctx, 301, 1, buf, 64, 0)
  assert_eq(w_res, 1, "Async write operation prepared successfully")
  assert_eq(get(f_io, 1), FIBER_WAITING, "Fiber 301 maintains FIBER_WAITING in list")
  assert_eq(mem_read(desc_io, 8), FIBER_WAITING, "Silicon descriptor maintains FIBER_WAITING (2)")
  free(buf, 128)

  // ── Test 5: CQE Event Reaping, Fiber Wakeup & Result Propagation ────────────
  // WHY: Validates the full async lifecycle: kernel/userland ring buffer submission,
  // CQE reaping, fiber unblocking, and result propagation into silicon descriptor.
  say("[5/6] Testing CQE completion reaping and fiber wakeup cycle...")
  // Fiber 301 is waiting for I/O completion. Running the loop will submit and reap CQE.
  c_reap = fiber_uring_run_loop(ctx, 50)
  assert_eq(c_reap, 1, "Woken fiber 301 resumed and executed to FIBER_DEAD")
  assert_eq(get(f_io, 1), FIBER_DEAD, "Fiber 301 transitioned to FIBER_DEAD (3)")
  assert_eq(mem_read(desc_io, 8), FIBER_DEAD, "Silicon descriptor updated to FIBER_DEAD (3)")
  // Fiber result holds CQE transferred bytes (64) delivered into silicon descriptor
  assert_eq(get(f_io, 7), 64, "Fiber 301 received 64-byte I/O completion result in silicon descriptor")

  // ── Test 6: Resource Cleanup & Deallocation ─────────────────────────────────
  // WHY: Validates clean teardown of kernel-mapped memory regions (SQ, CQ, SQEs)
  // preventing memory leaks in long-running services.
  say("[6/6] Testing fiber_uring_free teardown...")
  f_res = fiber_uring_free(ctx)
  assert_eq(f_res, 1, "fiber_uring resources cleanly released")

  say("=================================================================")
  say("🎉 ALL FIBER & IO_URING TESTS PASSED (100% SOVEREIGN LIPI)!")
  say("=================================================================")
  return 0
end
