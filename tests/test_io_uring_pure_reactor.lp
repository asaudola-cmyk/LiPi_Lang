// ==============================================================================
// ⚡ LIPI LINUX IO_URING ASYNCHRONOUS REACTOR REGRESSION SUITE
// File: tests/test_io_uring_pure_reactor.lp
// 100% Pure Lipi — 0% Libc, 0% liburing, 0% Shell
// ==============================================================================
//
// WHY: Validates the sovereign io_uring async networking reactor:
// 1. Direct Linux kernel syscall 425 (io_uring_setup) with SQPOLL / fallback.
// 2. Multi-op asynchronous submission (READ, WRITE, POLL_ADD, ACCEPT).
// 3. User-space non-blocking event harvesting via io_uring_reactor_poll.
// 4. Memory-mapped parameters unmapping and kernel descriptor cleanup.

import "universe/net/io_uring_reactor"
import "universe/core/io"
import "universe/core/string"

@fn assert_true(cond: i64, test_name: string)
  @if cond == 0
    println("  ❌ FAIL: " + test_name)
    sys_exit(1)
  @end
  println("  ✔ PASS: " + test_name)
@end

@fn assert_eq_int(actual: i64, expected: i64, test_name: string)
  @if actual != expected
    println("  ❌ FAIL: " + test_name + " (Expected " + int_to_str(expected) + ", got " + int_to_str(actual) + ")")
    sys_exit(1)
  @end
  println("  ✔ PASS: " + test_name)
@end

@fn main()
  println("══════════════════════════════════════════════════════════════════════")
  println("⚡ TESTING DIRECT LINUX IO_URING ASYNC REACTOR (0% LIBURING)")
  println("══════════════════════════════════════════════════════════════════════")

  // Phase 1: Initialize Reactor with 128 queue depth and SQPOLL preference
  println("\n▶ Phase 1: Direct io_uring Kernel Setup...")
  reactor = io_uring_reactor_new(128, 1)
  assert_true(reactor.is_active == 1, "Reactor active and initialized")
  assert_true(reactor.sq_entries == 128, "Queue capacity allocated for 128 entries")
  println("  • Active Backend: " + reactor.backend_mode)
  assert_true(str_len(reactor.backend_mode) > 0, "Valid backend mode determined (sqpoll/standard/epoll)")

  // Phase 2: Asynchronous Multi-Operation Submission
  println("\n▶ Phase 2: Asynchronous Multi-Op Submission (Batching)...")
  dummy_buf = 65536

  // 1. Async Read Submission
  r1 = io_uring_submit_read(reactor, 3, dummy_buf, 512)
  assert_eq_int(r1, 1, "Asynchronous READ operation enqueued")

  // 2. Async Write Submission
  r2 = io_uring_submit_write(reactor, 4, dummy_buf, 256)
  assert_eq_int(r2, 1, "Asynchronous WRITE operation enqueued")

  // 3. Async Poll Add (POLLIN=1)
  r3 = io_uring_submit_poll_add(reactor, 5, 1)
  assert_eq_int(r3, 1, "Asynchronous POLL_ADD operation enqueued")

  // 4. Async Socket Accept
  r4 = io_uring_submit_accept(reactor, 6)
  assert_eq_int(r4, 1, "Asynchronous ACCEPT operation enqueued")

  assert_eq_int(reactor.pending_ops.len(), 4, "All 4 asynchronous operations pending in reactor queue")

  // Phase 3: Event Reaping via Non-Blocking Reactor Polling
  println("\n▶ Phase 3: Non-Blocking Event Reaping & Dispatch...")
  // Harvest first 2 events
  batch1 = io_uring_reactor_poll(reactor, 2)
  assert_eq_int(batch1.len(), 2, "Reaped first batch of 2 completed events")
  assert_eq_int(reactor.pending_ops.len(), 2, "Remaining 2 operations preserved in pending queue")

  // Harvest remaining events
  batch2 = io_uring_reactor_poll(reactor, 10)
  assert_eq_int(batch2.len(), 2, "Reaped second batch of remaining 2 events")
  assert_eq_int(reactor.pending_ops.len(), 0, "Queue drained completely to 0 pending operations")

  // Phase 4: Clean Deallocation & Descriptor Release
  println("\n▶ Phase 4: Reactor Teardown & Resource Deallocation...")
  c_res = io_uring_reactor_close(reactor)
  assert_eq_int(c_res, 1, "Reactor close succeeded")
  assert_eq_int(reactor.is_active, 0, "Reactor marked inactive")
  assert_eq_int(reactor.ring_fd, 0 - 1, "Kernel ring descriptor closed")
  assert_eq_int(reactor.params_buf, 0, "Memory-mapped parameter buffer unmapped")

  println("\n══════════════════════════════════════════════════════════════════════")
  println("🎉 ALL IO_URING PURE REACTOR TESTS PASSED WITH 100% SUCCESS!")
  println("══════════════════════════════════════════════════════════════════════")
  return 0
@end

main()
