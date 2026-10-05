import "universe/core/net"
import "universe/os/syscalls"
import "universe/core/string"

@! ==============================================================================
@! 🧪 LIPI TEST SUITE: BAREMETAL NETWORK WIRE ENGINE & CORE NETWORKING
@! File: tests/test_net_core_wire.lp
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
  println("⚡ LIPI BAREMETAL NETWORK WIRE ENGINE TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: IPv4 Parsing, Formatting & Endian Conversions ───────────────
  println("▶ Section 1: IPv4 Address Operations & Endian Swapping...")
  total_tests = total_tests + 1

  // Test htons / ntohs
  port = 8080
  h_port = htons(port)
  n_port = ntohs(h_port)
  ok_end1 = assert_eq_int(n_port, 8080, "Endian roundtrip for port 8080")

  // Test net_parse_ipv4_octets
  octets_local = net_parse_ipv4_octets("127.0.0.1")
  ok_ip1 = assert_eq_int(octets_local[0], 127, "Octet 0 is 127")
  ok_ip2 = assert_eq_int(octets_local[1], 0, "Octet 1 is 0")
  ok_ip3 = assert_eq_int(octets_local[2], 0, "Octet 2 is 0")
  ok_ip4 = assert_eq_int(octets_local[3], 1, "Octet 3 is 1")

  octets_custom = net_parse_ipv4_octets("192.168.10.254")
  ok_ip5 = assert_eq_int(octets_custom[0], 192, "Custom IP octet 0 is 192")
  ok_ip6 = assert_eq_int(octets_custom[3], 254, "Custom IP octet 3 is 254")

  fmt_ip = net_format_ipv4(octets_custom[0], octets_custom[1], octets_custom[2], octets_custom[3])
  ok_fmt = assert_eq_str(fmt_ip, "192.168.10.254", "Formatted IP string matches original")

  // Test sockaddr_in allocation and extraction
  saddr = net_sockaddr_in_alloc("10.0.0.1", 9090)
  ok_sa1 = assert_true(saddr > 0, "sockaddr_in allocated in memory")
  parsed_ip = net_sockaddr_in_get_ip(saddr)
  parsed_port = net_sockaddr_in_get_port(saddr)
  ok_sa2 = assert_eq_str(parsed_ip, "10.0.0.1", "Extracted IP from sockaddr_in matches 10.0.0.1")
  ok_sa3 = assert_eq_int(parsed_port, 9090, "Extracted port from sockaddr_in matches 9090")
  net_sockaddr_in_free(saddr)

  @if ok_end1 == 1 && ok_ip1 == 1 && ok_ip2 == 1 && ok_ip3 == 1 && ok_ip4 == 1 && ok_ip5 == 1 && ok_ip6 == 1 && ok_fmt == 1 && ok_sa1 == 1 && ok_sa2 == 1 && ok_sa3 == 1
    println("  ✔ [PASS] IP parsing, formatting & sockaddr_in operations verified")
    passed_tests = passed_tests + 1
  @end

  // ── Section 2: Socket Creation & Advanced Tuning Flags ─────────────────────
  println("▶ Section 2: Socket Allocation & Syscall Tuning...")
  total_tests = total_tests + 1

  tcp_s = net_tcp_socket()
  ok_ts1 = assert_true(tcp_s >= 0, "TCP socket allocated via syscall 41")

  udp_s = net_udp_socket()
  ok_us1 = assert_true(udp_s >= 0, "UDP socket allocated via syscall 41")

  // Apply tuning
  r_reuse = net_set_reuseaddr(tcp_s, 1)
  ok_opt1 = assert_eq_int(r_reuse, 0, "SO_REUSEADDR set successfully")

  r_reuseport = net_set_reuseport(tcp_s, 1)
  ok_opt2 = assert_eq_int(r_reuseport, 0, "SO_REUSEPORT set successfully")

  r_nodelay = net_set_nodelay(tcp_s, 1)
  ok_opt3 = assert_eq_int(r_nodelay, 0, "TCP_NODELAY set successfully")

  r_nonblock = net_set_nonblocking(tcp_s, 1)
  ok_opt4 = assert_true(r_nonblock >= 0, "O_NONBLOCK configured via fcntl syscall 72")

  r_bcast = net_set_broadcast(udp_s, 1)
  ok_opt5 = assert_eq_int(r_bcast, 0, "SO_BROADCAST set on UDP socket")

  net_tcp_close(tcp_s)
  net_udp_close(udp_s)

  @if ok_ts1 == 1 && ok_us1 == 1 && ok_opt1 == 1 && ok_opt2 == 1 && ok_opt3 == 1 && ok_opt4 == 1 && ok_opt5 == 1
    println("  ✔ [PASS] Socket lifecycle and kernel tuning flags verified")
    passed_tests = passed_tests + 1
  @end

  // ── Section 3: UDP Datagram Loopback Communication ─────────────────────────
  println("▶ Section 3: Raw UDP Datagram Ingestion & Delivery...")
  total_tests = total_tests + 1

  udp_rx = net_udp_socket()
  udp_tx = net_udp_socket()

  loop_port = 24567
  r_bind = net_udp_bind(udp_rx, loop_port)
  ok_ub1 = assert_eq_int(r_bind, 0, "UDP receiver bound to port " + to_str(loop_port))

  // Transmit payload
  msg_payload = "LIPI_DATAGRAM_WIRE_PACKET_99"
  r_sendto = net_udp_sendto(udp_tx, msg_payload, "127.0.0.1", loop_port)
  ok_usend = assert_eq_int(r_sendto, str_len(msg_payload), "UDP packet transmitted via sendto (syscall 44)")

  // Receive payload
  pkt = net_udp_recvfrom(udp_rx, 1024)
  ok_urecv = assert_eq_int(pkt.pkt_bytes_received, str_len(msg_payload), "Bytes received matches payload length")
  ok_udata = assert_eq_str(pkt.pkt_data, msg_payload, "Received packet payload content verified")
  ok_uip = assert_eq_str(pkt.pkt_src_ip, "127.0.0.1", "Source IP matches sender loopback 127.0.0.1")

  net_udp_close(udp_rx)
  net_udp_close(udp_tx)

  @if ok_ub1 == 1 && ok_usend == 1 && ok_urecv == 1 && ok_udata == 1 && ok_uip == 1
    println("  ✔ [PASS] Raw UDP datagram loopback verified with sender identification")
    passed_tests = passed_tests + 1
  @end

  // ── Section 4: Lock-Free Contiguous NetRingBuffer ──────────────────────────
  println("▶ Section 4: Lock-Free NetRingBuffer Allocation & Operations...")
  total_tests = total_tests + 1

  ring = net_ring_new(8, 64)
  ok_rn1 = assert_true(ring != 0, "NetRingBuffer allocated via sys_mmap")
  ok_rn2 = assert_eq_int(ring.rb_capacity, 8, "Ring capacity is 8 slots")
  ok_rn3 = assert_true(net_ring_is_empty(ring) == 1, "Ring is initially empty")

  // Push items
  net_ring_push_str(ring, "FRAME_0")
  net_ring_push_str(ring, "FRAME_1")
  net_ring_push_str(ring, "FRAME_2")
  ok_rc = assert_eq_int(net_ring_count(ring), 3, "Ring count is 3 after pushes")

  // Non-destructive peek
  peek_item0 = net_ring_peek_str(ring)
  ok_pk0 = assert_eq_str(peek_item0, "FRAME_0", "Peek item 0 matches FRAME_0 without popping")
  ok_rc2 = assert_eq_int(net_ring_count(ring), 3, "Ring count unchanged at 3 after peek")

  // Pop items
  item0 = net_ring_pop_str(ring)
  item1 = net_ring_pop_str(ring)
  item2 = net_ring_pop_str(ring)
  ok_p0 = assert_eq_str(item0, "FRAME_0", "Popped item 0 matches FRAME_0")
  ok_p1 = assert_eq_str(item1, "FRAME_1", "Popped item 1 matches FRAME_1")
  ok_p2 = assert_eq_str(item2, "FRAME_2", "Popped item 2 matches FRAME_2")
  ok_remp = assert_true(net_ring_is_empty(ring) == 1, "Ring is empty after all pops")

  net_ring_free(ring)
  ok_rfree = assert_eq_int(ring.rb_is_active, 0, "NetRingBuffer unmapped cleanly")

  @if ok_rn1 == 1 && ok_rn2 == 1 && ok_rn3 == 1 && ok_rc == 1 && ok_pk0 == 1 && ok_rc2 == 1 && ok_p0 == 1 && ok_p1 == 1 && ok_p2 == 1 && ok_remp == 1 && ok_rfree == 1
    println("  ✔ [PASS] NetRingBuffer FIFO ordering, non-destructive peek & lifecycle verified")
    passed_tests = passed_tests + 1
  @end

  // ── Section 5: Batch Packet Queues (sendmmsg & recvmmsg) ───────────────────
  println("▶ Section 5: High-Throughput Batch Packet Transmission (sendmmsg / recvmmsg)...")
  total_tests = total_tests + 1

  batch_rx = net_udp_socket()
  batch_tx = net_udp_socket()

  batch_port = 25678
  net_udp_bind(batch_rx, batch_port)

  // Construct a 512-byte payload to rigorously test >255 byte multi-byte msg_len handling
  large_payload = ""
  li = 0
  @while li < 512
    large_payload = large_payload + "K"
    li = li + 1
  @end

  // Create batch queue of 4 packets (including large payload)
  tx_queue = net_batch_queue_new(4, 1024)
  ok_bq1 = assert_true(tx_queue != 0, "TX NetBatchQueue created with 4 descriptors")

  net_batch_set_packet(tx_queue, 0, "BURST_PACKET_0", "127.0.0.1", batch_port)
  net_batch_set_packet(tx_queue, 1, large_payload, "127.0.0.1", batch_port)
  net_batch_set_packet(tx_queue, 2, "BURST_PACKET_2", "127.0.0.1", batch_port)
  net_batch_set_packet(tx_queue, 3, "BURST_PACKET_3", "127.0.0.1", batch_port)

  // Single syscall transmission (Syscall 307 sendmmsg)
  sent_batch = net_batch_send(batch_tx, tx_queue, 4)
  ok_bsent = assert_eq_int(sent_batch, 4, "4 packets sent atomically via sendmmsg (syscall 307)")

  // Single syscall reception (Syscall 299 recvmmsg)
  rx_queue = net_batch_queue_new(4, 1024)
  recv_batch = net_batch_recv(batch_rx, rx_queue, 4, 100)
  ok_brecv = assert_eq_int(recv_batch, 4, "4 packets received atomically via recvmmsg (syscall 299)")

  pkt0_data = net_batch_get_packet_data(rx_queue, 0)
  pkt1_len  = net_batch_get_packet_len(rx_queue, 1)
  pkt1_data = net_batch_get_packet_data(rx_queue, 1)
  pkt2_data = net_batch_get_packet_data(rx_queue, 2)
  pkt3_data = net_batch_get_packet_data(rx_queue, 3)

  ok_bp0 = assert_eq_str(pkt0_data, "BURST_PACKET_0", "Batch packet 0 verified")
  ok_bp1_len = assert_eq_int(pkt1_len, 512, "Large 512-byte packet length verified without truncation")
  ok_bp1_data = assert_eq_int(str_len(pkt1_data), 512, "Large 512-byte payload string length matches")
  ok_bp2 = assert_eq_str(pkt2_data, "BURST_PACKET_2", "Batch packet 2 verified")
  ok_bp3 = assert_eq_str(pkt3_data, "BURST_PACKET_3", "Batch packet 3 verified")

  net_batch_queue_free(tx_queue)
  net_batch_queue_free(rx_queue)
  net_udp_close(batch_rx)
  net_udp_close(batch_tx)

  @if ok_bq1 == 1 && ok_bsent == 1 && ok_brecv == 1 && ok_bp0 == 1 && ok_bp1_len == 1 && ok_bp1_data == 1 && ok_bp2 == 1 && ok_bp3 == 1
    println("  ✔ [PASS] High-throughput batch transmission and reception verified (sendmmsg/recvmmsg with >255B packets)")
    passed_tests = passed_tests + 1
  @end

  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL CORE NETWORK WIRE ENGINE TESTS PASSED (" + to_str(passed_tests) + "/" + to_str(total_tests) + ") ✔")
    return 0
  @else
    println("❌ FAILURES DETECTED: Passed " + to_str(passed_tests) + " of " + to_str(total_tests))
    return 1
  @end
@end

main()
