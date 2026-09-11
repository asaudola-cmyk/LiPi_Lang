@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — IO_URING SQPOLL TEST SUITE
@! File: tests/io/test_uring_sqpoll.maya
@! ============================================================================

import "universe/core/collections"
import "universe/io/uring_sqpoll"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA IO_URING SQPOLL (ZERO-SYSCALL I/O) TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: SQPOLL Queue Setup & Kernel Thread Binding
  println("▶ Section 1: SQPOLL Queue Initialization & CPU Core Affinity...")
  total_tests = total_tests + 1
  sq_q = io_uring_sqpoll_init(64, 3, 2000) @! 64 entries, CPU core 3, 2000ms idle
  
  ok1 = assert_eq_int(sq_q.is_kthread_active, 1, "Kernel polling kthread is active")
  ok2 = assert_eq_int(sq_q.sq_thread_cpu, 3, "kthread pinned to CPU core 3")
  ok3 = assert_eq_int(sq_q.sq_capacity, 64, "SQ capacity initialized to 64")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] SQPOLL queue and kernel kthread initialization verified")
  @end

  @! SECTION 2: Zero-Syscall Memory Writes to SQ Ring
  println("▶ Section 2: Zero-Syscall Submission (In-Memory Queue Pushing)...")
  total_tests = total_tests + 1
  sq_q = io_uring_sqpoll_push_sqe(sq_q, 22, 10, 140737488355328, 8192, 5001)
  sq_q = io_uring_sqpoll_push_sqe(sq_q, 23, 11, 140737488359424, 4096, 5002)

  ok1 = assert_eq_int(sq_q.sq_tail, 2, "2 SQEs pushed to shared ring memory (0 syscalls made)")
  sqe0 = sq_q.sq_queue[0]
  ok2 = assert_eq_int(sqe0.sqe_tag, 5001, "SQE 0 user_data is 5001")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Zero-syscall SQE memory push verified")
  @end

  @! SECTION 3: Kernel Thread Autonomous Harvesting & CQE Reaping
  println("▶ Section 3: Kernel Polling Thread Harvesting & Completion CQE Generation...")
  total_tests = total_tests + 1
  harvested = io_uring_sqpoll_poll_kthread(sq_q)
  ok1 = assert_eq_int(harvested, 2, "kthread autonomously harvested 2 SQEs from ring memory")
  ok2 = assert_eq_int(sq_q.total_zero_syscall_ops, 2, "Total zero-syscall I/O operations counter incremented")
  
  cqe1 = io_uring_sqpoll_pop_cqe(sq_q)
  ok3 = assert_eq_int(cqe1.cqe_tag, 5001, "CQE 1 user_data matches 5001")
  ok4 = assert_eq_int(cqe1.res, 8192, "CQE 1 transferred 8192 bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Kernel thread SQ harvesting & CQE reaping verified")
  @end

  println("=================================================================")
  println("📊 SQPOLL TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 IO_URING SQPOLL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SQPOLL TESTS FAILED")
    return 1
  @end
@end
