import "src/runtime/io_uring_bypass"
import "universe/core/string"
import "universe/os/syscalls"

@! ==============================================================================
@! 🧪 LIPI TEST SUITE: IO_URING BAREMETAL NETWORK WIRE ENGINE RUNTIME
@! File: tests/test_io_uring_bypass_wire.lp
@! 100% Pure Lipi Implementation — 0% Libc | 0% C Dependencies
@! ==============================================================================

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
  println("⚡ LIPI IO_URING BAREMETAL WIRE ENGINE RUNTIME TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Engine Initialization & Memory Ring Architecture ───────────
  println("▶ Section 1: Baremetal Engine Setup & Ring Mapping...")
  total_tests = total_tests + 1

  engine = io_uring_bypass_new(64, 0, 32, 2048)
  ok_e1 = assert_true(engine != 0, "IoUringBypassEngine returned")
  ok_e2 = assert_eq_int(engine.be_is_active, 1, "Engine is active")
  ok_e3 = assert_eq_int(engine.be_entries, 64, "SQ/CQ entries configured to 64")
  ok_e4 = assert_true(engine.be_sqes_ptr > 0, "SQEs shared memory array mapped")
  ok_e5 = assert_true(engine.be_dma_pool != 0, "Zero-copy DMA pool attached")

  if ok_e1 == 1 && ok_e2 == 1 && ok_e3 == 1 && ok_e4 == 1 && ok_e5 == 1
    println("  ✔ [PASS] Engine initialized with mode: " + engine.be_backend_mode)
    passed_tests = passed_tests + 1
  end

  // ── Section 2: Zero-Copy DMA Memory Pool Operations ───────────────────────
  println("▶ Section 2: Zero-Copy DMA Memory Pool Allocation & Data I/O...")
  total_tests = total_tests + 1

  pool = engine.be_dma_pool
  ok_dma1 = assert_eq_int(pool.dp_num_slots, 32, "DMA pool slot count is 32")
  ok_dma2 = assert_eq_int(pool.dp_slot_size, 2048, "DMA pool slot size is 2048 bytes (MTU aligned)")

  slot0 = bypass_dma_alloc(pool)
  ok_s0 = assert_true(slot0 >= 0, "DMA slot 0 allocated")

  test_msg = "DMA_ZERO_COPY_PAYLOAD_TEST_DATA"
  w_len = bypass_dma_write(pool, slot0, test_msg)
  ok_w = assert_eq_int(w_len, str_len(test_msg), "Wrote payload to DMA slot")

  read_back = bypass_dma_read(pool, slot0, w_len)
  ok_r = assert_eq_str(read_back, test_msg, "Read back string from DMA slot matches payload")

  slot0_ptr = bypass_dma_slot_ptr(pool, slot0)
  ok_ptr = assert_true(slot0_ptr > 0, "Direct memory pointer to DMA slot is valid")

  ok_f = assert_eq_int(bypass_dma_free(pool, slot0), 1, "DMA slot 0 recycled back to pool")

  if ok_dma1 == 1 && ok_dma2 == 1 && ok_s0 == 1 && ok_w == 1 && ok_r == 1 && ok_ptr == 1 && ok_f == 1
    println("  ✔ [PASS] Zero-copy DMA pool slot allocation, write/read and recycling verified")
    passed_tests = passed_tests + 1
  end

  // ── Section 3: SQE Ring Buffer Submission & Event Reaping ─────────────────
  println("▶ Section 3: SQE Submission Pipeline & Event Reaping...")
  total_tests = total_tests + 1

  // Allocate DMA slot for send SQE
  tx_slot = bypass_dma_alloc(pool)
  bypass_dma_write(pool, tx_slot, "ASYNC_SQE_DATA")
  tx_ptr = bypass_dma_slot_ptr(pool, tx_slot)

  // Prep send on loopback descriptor (testing queue plumbing)
  ok_prep = io_uring_bypass_prep_send(engine, 1, tx_ptr, 14, 0, 7777)
  ok_sub_prep = assert_eq_int(ok_prep, 1, "Prepared send SQE in submission ring")

  submitted_ops = io_uring_bypass_submit(engine)
  ok_sub_ops = assert_true(submitted_ops >= 1, "Submitted pending SQEs")

  cqe = io_uring_bypass_wait_cqe(engine, 1)
  ok_cqe = assert_true(cqe != 0, "Reaped CQE event from kernel")
  ok_tag = assert_eq_int(cqe.cqe_tag, 7777, "CQE user_data matches submission tag 7777")

  bypass_dma_free(pool, tx_slot)

  if ok_sub_prep == 1 && ok_sub_ops == 1 && ok_cqe == 1 && ok_tag == 1
    println("  ✔ [PASS] Asynchronous submission pipeline, SQ tail advance & CQE reaping verified")
    passed_tests = passed_tests + 1
  end

  // ── Section 4: Wire-Level Batch UDP Datagram Engine ───────────────────────
  println("▶ Section 4: Wire-Level UDP Batch Packet Transmission & Ingestion...")
  total_tests = total_tests + 1

  wire_port = 28991
  rx_sock = bypass_udp_bind(engine, wire_port)
  tx_sock = net_udp_socket()
  ok_wsock = assert_true(rx_sock >= 0, "UDP socket bound on port " + to_str(wire_port))

  // Construct batch of 3 datagram packets
  batch = [
    { data: "WIRE_PKT_ALPHA", ip: "127.0.0.1", port: wire_port },
    { data: "WIRE_PKT_BETA",  ip: "127.0.0.1", port: wire_port },
    { data: "WIRE_PKT_GAMMA", ip: "127.0.0.1", port: wire_port }
  ]

  sent_count = bypass_udp_batch_sendto(engine, tx_sock, batch)
  ok_bsent = assert_eq_int(sent_count, 3, "Batch of 3 datagrams sent via bypass engine")

  // Reap received datagrams via recvmmsg
  reaped_packets = bypass_udp_batch_recvfrom(engine, rx_sock, 3)
  ok_brecv = assert_eq_int(reaped_packets.len(), 3, "Batch of 3 datagrams reaped via wire receive queue")

  if reaped_packets.len() == 3
    p0 = reaped_packets[0]
    p1 = reaped_packets[1]
    p2 = reaped_packets[2]

    ok_p0 = assert_eq_str(p0.dpkt_data, "WIRE_PKT_ALPHA", "Reaped packet 0 verified")
    ok_p1 = assert_eq_str(p1.dpkt_data, "WIRE_PKT_BETA",  "Reaped packet 1 verified")
    ok_p2 = assert_eq_str(p2.dpkt_data, "WIRE_PKT_GAMMA", "Reaped packet 2 verified")
    ok_src = assert_eq_str(p0.dpkt_src_ip, "127.0.0.1", "Source IP verified as 127.0.0.1")

    if ok_p0 == 1 && ok_p1 == 1 && ok_p2 == 1 && ok_src == 1
      println("  ✔ [PASS] Wire-level UDP batch datagram processing verified")
      passed_tests = passed_tests + 1
    end
  end

  net_udp_close(rx_sock)
  net_udp_close(tx_sock)

  // ── Section 5: Engine Diagnostics & Clean Resource Teardown ───────────────
  println("▶ Section 5: Engine Telemetry & Clean Shutdown...")
  total_tests = total_tests + 1

  stats = io_uring_bypass_stats(engine)
  ok_st1 = assert_eq_int(stats.entries, 64, "Telemetry reports correct ring entries")
  ok_st2 = assert_eq_int(stats.dma_slots_total, 32, "Telemetry reports correct DMA slot capacity")

  r_close = io_uring_bypass_close(engine)
  ok_cls1 = assert_eq_int(r_close, 1, "Engine close returned success")
  ok_cls2 = assert_eq_int(engine.be_is_active, 0, "Engine marked inactive")
  ok_cls3 = assert_eq_int(engine.be_sq_ring_ptr, 0, "Shared memory ring unmapped cleanly")

  if ok_st1 == 1 && ok_st2 == 1 && ok_cls1 == 1 && ok_cls2 == 1 && ok_cls3 == 1
    println("  ✔ [PASS] Telemetry diagnostics and memory teardown verified")
    passed_tests = passed_tests + 1
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL IO_URING BAREMETAL WIRE ENGINE TESTS PASSED (" + to_str(passed_tests) + "/" + to_str(total_tests) + ") ✔")
    return 0
  else
    println("❌ FAILURES DETECTED: Passed " + to_str(passed_tests) + " of " + to_str(total_tests))
    return 1
  end
@end

main()
