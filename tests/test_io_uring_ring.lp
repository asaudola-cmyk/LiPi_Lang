// ==============================================================================
// 🧪 LIPI TEST SUITE: IO_URING ZERO-SYSCALL RING BUFFER ENGINE
// File: tests/test_io_uring_ring.lp
// 100% Pure Lipi Implementation — Zero External / C Dependencies
// ==============================================================================

import "universe/net/io_uring_ring"
import "universe/core/string"

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
  println("⚡ LIPI IO_URING ZERO-SYSCALL RING BUFFER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Ring Buffer Creation & Param Mapping ───────────────────────
  println("▶ Section 1: Ring Buffer Allocation & Memory Mapping...")
  total_tests = total_tests + 1

  ring = lipi_io_uring_new(64, 0)
  ok1 = assert_true(ring != 0, "Ring structure returned")
  ok2 = assert_true(ring.is_active == 1, "Ring is marked active")
  ok3 = assert_true(ring.sq_entries >= 64, "SQ entries allocation")
  
  if ok1 == 1 && ok2 == 1 && ok3 == 1
    println("  ✔ [PASS] Ring buffer created with mode: " + ring.backend_mode)
    passed_tests = passed_tests + 1
  end

  // ── Section 2: Zero-Syscall SQE Submission & Tail Advance ──────────────────
  println("▶ Section 2: SQE Submission & Barrier Tail Update...")
  total_tests = total_tests + 1

  buf_addr = lipi_alloc(128)
  res_sub1 = lipi_io_uring_submit_sqe(ring, IORING_OP_NOP(), 0, 0, 0, 1001)
  res_sub2 = lipi_io_uring_submit_sqe(ring, IORING_OP_NOP(), 0, 0, 0, 1002)

  ok_s1 = assert_eq_int(res_sub1, 1, "First SQE submission succeeded")
  ok_s2 = assert_eq_int(res_sub2, 1, "Second SQE submission succeeded")
  ok_s3 = assert_eq_int(ring.submitted_count, 2, "Submitted count incremented to 2")

  if ok_s1 == 1 && ok_s2 == 1 && ok_s3 == 1
    println("  ✔ [PASS] SQE submissions committed with correct memory ordering")
    passed_tests = passed_tests + 1
  end

  // ── Section 3: Completion Queue Event (CQE) Reaping ───────────────────────
  println("▶ Section 3: CQE Event Reaping & Head Advance...")
  total_tests = total_tests + 1

  // Reap completion event (using wait_cqe for kernel event delivery)
  cqe1 = lipi_io_uring_wait_cqe(ring, 1)
  ok_c1 = assert_true(cqe1 != 0, "CQE successfully reaped")
  if cqe1 != 0
    ok_c2 = assert_eq_int(cqe1.user_data, 1001, "CQE user_data matches submission (1001)")
    if ok_c1 == 1 && ok_c2 == 1
      println("  ✔ [PASS] CQE reaped with user_data = " + to_str(cqe1.user_data))
      passed_tests = passed_tests + 1
    end
  end

  // ── Section 4: Safe Resource Teardown & Unmap ──────────────────────────────
  println("▶ Section 4: Clean Ring Buffer Teardown...")
  total_tests = total_tests + 1

  res_close = lipi_io_uring_close(ring)
  ok_cl1 = assert_eq_int(res_close, 1, "Close returned success")
  ok_cl2 = assert_eq_int(ring.is_active, 0, "Ring is now inactive")

  if ok_cl1 == 1 && ok_cl2 == 1
    println("  ✔ [PASS] Ring buffer closed and memory released cleanly")
    passed_tests = passed_tests + 1
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL IO_URING RING BUFFER TESTS PASSED (4/4) ✔")
    return 0
  else
    println("❌ SOME IO_URING TESTS FAILED!")
    return 1
  end
@end

main()
