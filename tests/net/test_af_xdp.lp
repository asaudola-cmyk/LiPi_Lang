@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — AF_XDP KERNEL BYPASS TEST SUITE
@! File: tests/net/test_af_xdp.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/net/xdp"

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
  println("⚡ MAYA AF_XDP KERNEL BYPASS PACKET INGESTION TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: AF_XDP Socket & UMEM Pool Creation
  println("▶ Section 1: AF_XDP Socket & Zero-Copy UMEM Pool Allocation...")
  total_tests = total_tests + 1
  xsk = xdp_socket_open(1, 0) @! Interface eth0 (idx 1), Queue 0
  ok1 = assert_eq_int(xsk.if_index, 1, "AF_XDP socket bound to interface index 1")
  ok2 = assert_eq_int(xsk.umem.total_frames, 64, "UMEM allocated 64 zero-copy DMA frames")
  ok3 = assert_eq_int(xsk.umem.frame_size, 2048, "UMEM frame size is 2048 bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] AF_XDP socket and UMEM memory frames initialized")
  @end

  @! SECTION 2: Direct Packet Ingestion to RX Ring
  println("▶ Section 2: Zero-Copy Raw NIC DMA Packet Ingestion...")
  total_tests = total_tests + 1
  @! 14-byte Ethernet frame: Dest MAC (6), Src MAC (6), EtherType (2: 0x0800 IPv4) + Payload (4 bytes)
  raw_eth = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 8, 0, 1, 2, 3, 4]
  ingested = xdp_ingest_packet(xsk, raw_eth)
  ok1 = assert_eq_int(ingested, 1, "Packet DMA deposited directly into UMEM frame")
  ok2 = assert_eq_int(xsk.rx_ring.tail, 1, "RX ring tail incremented to 1")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] NIC packet DMA ingestion to RX ring verified")
  @end

  @! SECTION 3: Polling and Kernel-Bypass Ethernet Frame Parsing
  println("▶ Section 3: Kernel-Bypass Ethernet Frame Decoding...")
  total_tests = total_tests + 1
  parsed_frame = xdp_poll_rx(xsk)
  ok1 = assert_true(parsed_frame.ether_type > 0, "Polled valid frame from RX ring")
  ok2 = assert_eq_int(parsed_frame.ether_type, 2048, "EtherType is IPv4 (0x0800 = 2048)")
  ok3 = assert_eq_int(parsed_frame.payload_bytes.len(), 4, "Payload length is 4 bytes")
  ok4 = assert_eq_int(parsed_frame.payload_bytes[0], 1, "Payload byte 0 matches 1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Kernel bypass zero-copy packet polling & decoding verified")
  @end

  println("=================================================================")
  println("📊 AF_XDP TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 AF_XDP KERNEL BYPASS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME AF_XDP TESTS FAILED")
    return 1
  @end
@end
