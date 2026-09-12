// ==============================================================================
// ⚡ LIPI HIGH-CONCURRENCY STRESS SUITE: IO_URING ASYNC PIPELINE
// File: tests/test_io_uring_stress.lp
// 100% Pure Lipi Implementation — Zero Libc | Zero External Dependencies
// ==============================================================================

import "universe/net/io_uring_reactor"
import "universe/core/string"
import "universe/os/syscalls"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI IO_URING & ASYNC PIPELINE BURST STRESS TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── SECTION 1: High-Capacity Reactor Initialization ────────────────────────
  println("▶ Section 1: Initializing High-Capacity Ring (256 SQ Entries)...")
  total_tests = total_tests + 1

  reactor = io_uring_reactor_new(256, 1)
  ok_init = assert_eq_int(reactor.is_active, 1, "Reactor is active")
  println(str_concat("  • Reactor Mode: ", reactor.backend_mode))
  println(str_concat("  • Queue Entries: ", to_str(reactor.sq_entries)))

  @if ok_init == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] High-capacity reactor ring initialized successfully.")
  @end

  // ── SECTION 2: Burst Operation Submissions (1,000 Pipelined Ops) ───────────
  println("▶ Section 2: Burst Submitting 1,000 Async I/O Requests...")
  total_tests = total_tests + 1

  buf_addr = 65536
  ops_count = 1000
  submitted_reads = 0
  submitted_writes = 0

  i = 0
  @while i < ops_count
    @if i % 2 == 0
      r = io_uring_submit_read(reactor, 10 + (i % 64), buf_addr, 512)
      @if r == 1
        submitted_reads = submitted_reads + 1
      @end
    @else
      w = io_uring_submit_write(reactor, 10 + (i % 64), buf_addr, 256)
      @if w == 1
        submitted_writes = submitted_writes + 1
      @end
    @end
    i = i + 1
  @end

  println(str_concat("  • Submitted Async Reads : ", to_str(submitted_reads)))
  println(str_concat("  • Submitted Async Writes: ", to_str(submitted_writes)))
  println(str_concat("  • Total Ops Enqueued    : ", to_str(reactor.pending_ops.len())))

  ok_batch = assert_eq_int(reactor.pending_ops.len(), 1000, "1000 pending operations in reactor queue")
  @if ok_batch == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] 1,000 Burst I/O requests submitted with zero memory fault.")
  @end

  // ── SECTION 3: Safe Teardown & Buffer Reclamation ──────────────────────────
  println("▶ Section 3: Clean Reactor Close & Resource Reclamation...")
  total_tests = total_tests + 1

  close_ok = io_uring_reactor_close(reactor)
  ok_close = assert_eq_int(close_ok, 1, "Reactor closed cleanly")
  ok_state = assert_eq_int(reactor.is_active, 0, "Reactor state is inactive")

  @if ok_close == 1 && ok_state == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Reactor ring and mmap params buffer safely unmapped.")
  @end

  println("")
  println("=================================================================")
  println(str_concat("🎉 TOTAL STRESS SECTIONS PASSED: ", str_concat(to_str(passed_tests), str_concat(" / ", to_str(total_tests)))))
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end

main()
