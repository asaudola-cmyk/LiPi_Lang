import "src/runtime/io_uring_bypass"
import "universe/core/net"
import "universe/core/string"
import "universe/os/syscalls"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  ❌ [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " -> Expected " + to_str(expected) + ", got " + to_str(actual))
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI NETWORK WIRE ENGINE & BYPASS EDGE CASES TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Edge Case 1: IP Parsing Boundary Values & Malformed Inputs ────────────
  println("▶ Edge Case 1: IP Parsing Edge Cases...")
  total_tests = total_tests + 1

  empty_ip = net_parse_ipv4_octets("")
  ok_e1 = assert_eq_int(empty_ip[0], 0, "Empty IP octet 0 is 0")
  ok_e2 = assert_eq_int(empty_ip[3], 0, "Empty IP octet 3 is 0")

  zero_ip = net_parse_ipv4_octets("0.0.0.0")
  ok_z1 = assert_eq_int(zero_ip[0], 0, "0.0.0.0 octet 0 is 0")

  lh_ip = net_parse_ipv4_octets("localhost")
  ok_lh = assert_eq_int(lh_ip[0], 127, "localhost parsed as 127.0.0.1")

  malformed = net_parse_ipv4_octets("invalid.ip.string")
  ok_mf = assert_eq_int(malformed[0], 0, "Malformed IP safely defaults to 0")

  // Endianness boundaries
  p_zero = htons(0)
  ok_pz = assert_eq_int(p_zero, 0, "htons(0) == 0")
  p_max = htons(65535)
  ok_pm = assert_eq_int(p_max, 65535, "htons(65535) == 65535")

  if ok_e1 == 1 && ok_e2 == 1 && ok_z1 == 1 && ok_lh == 1 && ok_mf == 1 && ok_pz == 1 && ok_pm == 1
    println("  ✔ [PASS] IP parsing edge cases and endianness boundaries verified")
    passed_tests = passed_tests + 1
  end

  // ── Edge Case 2: NetRingBuffer Empty, Full & Wrap-Around ───────────────────
  println("▶ Edge Case 2: Ring Buffer Underflow, Overflow & Wraparound...")
  total_tests = total_tests + 1

  // Small 2-slot ring
  ring = net_ring_new(2, 32)
  ok_emp1 = assert_eq_str(net_ring_pop_str(ring), "", "Pop from empty ring returns empty string")
  ok_is_emp = assert_eq_int(net_ring_is_empty(ring), 1, "Ring reports is_empty == 1")

  // Fill capacity (2 slots)
  ok_psh1 = assert_true(net_ring_push_str(ring, "SLOT_0") > 0, "Push 1 succeeded")
  ok_psh2 = assert_true(net_ring_push_str(ring, "SLOT_1") > 0, "Push 2 succeeded")
  ok_full = assert_eq_int(net_ring_is_full(ring), 1, "Ring reports is_full == 1")

  // Push on full ring should be rejected
  ok_rej = assert_eq_int(net_ring_push_str(ring, "OVERFLOW_SLOT"), 0, "Push on full ring returns 0")

  // Pop both and verify
  v0 = net_ring_pop_str(ring)
  v1 = net_ring_pop_str(ring)
  ok_v0 = assert_eq_str(v0, "SLOT_0", "Popped slot 0")
  ok_v1 = assert_eq_str(v1, "SLOT_1", "Popped slot 1")
  ok_emp2 = assert_eq_int(net_ring_is_empty(ring), 1, "Ring is empty again")

  // Wraparound test: push 2 more cycles
  net_ring_push_str(ring, "CYCLE_2_A")
  net_ring_push_str(ring, "CYCLE_2_B")
  c2a = net_ring_pop_str(ring)
  c2b = net_ring_pop_str(ring)
  ok_wrap = assert_eq_str(c2a + "_" + c2b, "CYCLE_2_A_CYCLE_2_B", "Wraparound ring operations match")

  net_ring_free(ring)
  // Double free safety
  ok_dfree = assert_eq_int(net_ring_free(ring), 1, "Double free is safe and idempotent")

  if ok_emp1 == 1 && ok_is_emp == 1 && ok_psh1 == 1 && ok_psh2 == 1 && ok_full == 1 && ok_rej == 1 && ok_v0 == 1 && ok_v1 == 1 && ok_emp2 == 1 && ok_wrap == 1 && ok_dfree == 1
    println("  ✔ [PASS] NetRingBuffer underflow, overflow & wraparound verified")
    passed_tests = passed_tests + 1
  end

  // ── Edge Case 3: NetBatchQueue Boundary Bounds & Clamping ──────────────────
  println("▶ Edge Case 3: NetBatchQueue Bounds Checking & Clamping...")
  total_tests = total_tests + 1

  bq = net_batch_queue_new(2, 64)
  // Negative index
  ok_neg = assert_eq_int(net_batch_set_packet(bq, -1, "DATA", "127.0.0.1", 8080), 0, "Negative index rejected")
  // Out-of-bounds index
  ok_oob = assert_eq_int(net_batch_set_packet(bq, 2, "DATA", "127.0.0.1", 8080), 0, "Out-of-bounds index 2 rejected")

  // Valid slot
  ok_valid = assert_true(net_batch_set_packet(bq, 0, "HELLO_VALID", "127.0.0.1", 8080) > 0, "Index 0 accepted")

  // Large payload clamping (longer than slot_size 64)
  long_msg = "0123456789012345678901234567890123456789012345678901234567890123456789EXTRA_BYTES"
  written = net_batch_set_packet(bq, 1, long_msg, "127.0.0.1", 8080)
  ok_clamp = assert_eq_int(written, 64, "Oversized payload clamped to slot size 64")

  // Send with count <= 0
  ok_zero_send = assert_eq_int(net_batch_send(1, bq, 0), 0, "Send with count 0 returns 0")

  net_batch_queue_free(bq)
  ok_bq_dfree = assert_eq_int(net_batch_queue_free(bq), 1, "Double free of batch queue is safe")

  if ok_neg == 1 && ok_oob == 1 && ok_valid == 1 && ok_clamp == 1 && ok_zero_send == 1 && ok_bq_dfree == 1
    println("  ✔ [PASS] NetBatchQueue index validation and payload clamping verified")
    passed_tests = passed_tests + 1
  end

  // ── Edge Case 4: DMA Pool Exhaustion & Invalid Slots ───────────────────────
  println("▶ Edge Case 4: DMA Pool Exhaustion & Safe Recycling...")
  total_tests = total_tests + 1

  pool = bypass_dma_pool_new(2, 64)
  s0 = bypass_dma_alloc(pool)
  s1 = bypass_dma_alloc(pool)
  ok_allocs = assert_true(s0 >= 0 && s1 >= 0, "Allocated all available slots (0, 1)")

  // Exhausted allocation
  s_exhaust = bypass_dma_alloc(pool)
  ok_exh = assert_eq_int(s_exhaust, -1, "Allocation on exhausted pool returns -1")

  // Free invalid index
  ok_finv1 = assert_eq_int(bypass_dma_free(pool, -1), 0, "Freeing slot -1 rejected")
  ok_finv2 = assert_eq_int(bypass_dma_free(pool, 5), 0, "Freeing out-of-range slot 5 rejected")

  // Free s0 and reallocate
  bypass_dma_free(pool, s0)
  s_realloc = bypass_dma_alloc(pool)
  ok_realloc = assert_eq_int(s_realloc, s0, "Reallocated slot matches recycled slot")

  bypass_dma_pool_free(pool)
  ok_p_dfree = assert_eq_int(bypass_dma_pool_free(pool), 1, "Double free of DMA pool is safe")

  if ok_allocs == 1 && ok_exh == 1 && ok_finv1 == 1 && ok_finv2 == 1 && ok_realloc == 1 && ok_p_dfree == 1
    println("  ✔ [PASS] DMA pool exhaustion and invalid slot recovery verified")
    passed_tests = passed_tests + 1
  end

  // ── Edge Case 5: Empty Ring Peek & Signed Negative Error CQE Handling ────
  println("▶ Edge Case 5: Empty Ring Peek & Signed Negative CQE Errno...")
  total_tests = total_tests + 1

  r_test = net_ring_new(4, 64)
  ok_epk = assert_eq_str(net_ring_peek_str(r_test), "", "Peek on empty ring returns empty string")
  net_ring_push_str(r_test, "PEEK_DATA")
  ok_npk = assert_eq_str(net_ring_peek_str(r_test), "PEEK_DATA", "Peek returns item data")
  ok_cnt = assert_eq_int(net_ring_count(r_test), 1, "Count remains 1 after peek")
  net_ring_free(r_test)

  // Test signed negative error return code in io_uring
  err_engine = io_uring_bypass_new(16, 0, 4, 512)
  io_uring_bypass_prep_recv(err_engine, 99999, 0, 128, 0, 8888)
  io_uring_bypass_submit(err_engine)
  err_cqe = io_uring_bypass_wait_cqe(err_engine, 1)
  ok_has_cqe = assert_true(err_cqe != 0, "Reaped CQE for invalid descriptor")
  ok_is_neg = assert_true(err_cqe.cqe_res < 0, "CQE res is correctly negative signed errno: " + to_str(err_cqe.cqe_res))
  io_uring_bypass_close(err_engine)

  if ok_epk == 1 && ok_npk == 1 && ok_cnt == 1 && ok_has_cqe == 1 && ok_is_neg == 1
    println("  ✔ [PASS] Non-destructive empty peek and signed negative errno CQE verified")
    passed_tests = passed_tests + 1
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL NETWORK WIRE ENGINE EDGE CASE TESTS PASSED (" + to_str(passed_tests) + "/" + to_str(total_tests) + ") ✔")
    return 0
  else
    println("❌ FAILURES DETECTED: Passed " + to_str(passed_tests) + " of " + to_str(total_tests))
    return 1
  end
@end

main()
