@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — IO_URING ASYNC ENGINE TEST SUITE
@! File: tests/io/test_io_uring.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/io/uring"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA LINUX IO_URING ASYNC RING BUFFER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: SQ/CQ Shared Memory Ring Initialization (64 entries) via raw sys_mmap
  println("▶ Section 1: SQ/CQ Shared Memory Ring Initialization (64 Entries)...")
  total_tests = total_tests + 1
  ring = io_uring_init(64)
  ok1 = assert_eq_int(ring.entries, 64, "Queue initialized with 64 ring entries")
  ok2 = assert_eq_int(ring.sq_head, 0, "Submission queue head is 0")
  ok3 = assert_eq_int(ring.sq_tail, 0, "Submission queue tail is 0")
  ok4 = assert_eq_int(ring.cq_head, 0, "Completion queue head is 0")
  ok5 = assert_eq_int(ring.cq_tail, 0, "Completion queue tail is 0")
  ok6 = assert_true(ring.sq_ring_ptr > 0, "SQ ring buffer mapped in shared memory via sys_mmap")
  ok7 = assert_true(ring.cq_ring_ptr > 0, "CQ ring buffer mapped in shared memory via sys_mmap")
  ok8 = assert_true(ring.sqes_ptr > 0, "SQE entry array mapped in shared memory via sys_mmap")
  ok9 = assert_eq_int(ring.sq_mask, 63, "Submission queue mask is 63 (entries - 1)")
  ok10 = assert_eq_int(ring.cq_mask, 63, "Completion queue mask is 63 (entries - 1)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] io_uring ring queue initialization verified")
  @end

  @! SECTION 2: Zero-Syscall Submission Queue Entry (SQE) Preparation (read, write, accept)
  println("▶ Section 2: Zero-Syscall Submission Queue Entry (SQE) Preparation...")
  total_tests = total_tests + 1
  ring = io_uring_prep_read(ring, 10, 140737488355328, 4096, 0, 1001)
  ring = io_uring_prep_write(ring, 11, 140737488359424, 1024, 4096, 1002)
  ring = io_uring_prep_accept(ring, 12, 1003)

  ok1 = assert_eq_int(ring.sq_tail, 3, "3 SQEs enqueued into submission ring")
  sqe0 = ring.sqes[0]
  ok2 = assert_eq_int(sqe0.opcode, 22, "SQE 0 opcode is IORING_OP_READ (22)")
  ok3 = assert_eq_int(sqe0.sqe_tag, 1001, "SQE 0 user_data tag is 1001")
  ok4 = assert_eq_int(sqe0.fd, 10, "SQE 0 fd is 10")
  ok5 = assert_eq_int(sqe0.nbytes, 4096, "SQE 0 buffer length is 4096 bytes")

  sqe1 = ring.sqes[1]
  ok6 = assert_eq_int(sqe1.opcode, 23, "SQE 1 opcode is IORING_OP_WRITE (23)")
  ok7 = assert_eq_int(sqe1.sqe_tag, 1002, "SQE 1 user_data tag is 1002")
  ok8 = assert_eq_int(sqe1.fd, 11, "SQE 1 fd is 11")
  ok9 = assert_eq_int(sqe1.nbytes, 1024, "SQE 1 buffer length is 1024 bytes")

  sqe2 = ring.sqes[2]
  ok10 = assert_eq_int(sqe2.opcode, 13, "SQE 2 opcode is IORING_OP_ACCEPT (13)")
  ok11 = assert_eq_int(sqe2.sqe_tag, 1003, "SQE 2 user_data tag is 1003")
  ok12 = assert_eq_int(sqe2.fd, 12, "SQE 2 socket fd is 12")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] SQE read, write and accept preparation verified")
  @end

  @! SECTION 3: Batch Submission & Zero-Syscall CQE Event Reaping
  println("▶ Section 3: Batch Submission & Zero-Syscall CQE Event Reaping...")
  total_tests = total_tests + 1
  submitted = io_uring_submit_and_reap(ring)
  ok1 = assert_eq_int(submitted, 3, "Batch submitted all 3 pending SQEs")
  ok2 = assert_eq_int(ring.cqes.len(), 3, "Completion queue contains 3 reaped events")
  ok3 = assert_eq_int(ring.sq_head, 3, "Submission queue head advanced to 3")
  ok4 = assert_eq_int(ring.cq_tail, 3, "Completion queue tail advanced to 3")

  cqe1 = io_uring_pop_cqe(ring)
  ok5 = assert_eq_int(cqe1.cqe_tag, 1001, "First CQE matches user_data 1001")
  ok6 = assert_eq_int(cqe1.res, 4096, "First CQE transferred 4096 bytes")

  cqe2 = io_uring_pop_cqe(ring)
  ok7 = assert_eq_int(cqe2.cqe_tag, 1002, "Second CQE matches user_data 1002")
  ok8 = assert_eq_int(cqe2.res, 1024, "Second CQE transferred 1024 bytes")

  cqe3 = io_uring_pop_cqe(ring)
  ok9 = assert_eq_int(cqe3.cqe_tag, 1003, "Third CQE matches accept user_data 1003")
  ok10 = assert_eq_int(cqe3.res, 100, "Accept CQE returned client socket fd 100")

  ok11 = assert_eq_int(ring.cqes.len(), 0, "All CQEs drained from completion queue")
  ok12 = assert_eq_int(ring.cq_head, 3, "Completion queue head advanced to 3")
  cqe_empty = io_uring_pop_cqe(ring)
  ok13 = assert_eq_int(cqe_empty, 0, "Popping from empty completion queue returns 0")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1 && ok13 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] io_uring batch submit and CQE event reaping verified")
  @end

  println("=================================================================")
  println(str_concat("📊 IO_URING TEST RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " passed")))))
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 LINUX IO_URING TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME IO_URING TESTS FAILED")
    return 1
  @end
@end

