@! ============================================================================
@! MAYA RAW NETWORK PROTOCOL STACK EXHAUSTIVE VERIFICATION SUITE
@! File: tests/net/test_raw.maya
@! Tests Layer 2 (Ethernet II, CRC-32), ARP, IPv4, ICMP, UDP, TCP, & Virtual Hub
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/net/raw"

@fn assert_true(cond, msg)
  @if cond
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Expected: " + maya_int_to_str(expected) + ", Got: " + maya_int_to_str(actual) + ")")
    return 0
  @end
@end

@fn assert_str_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (Expected: '" + expected + "', Got: '" + actual + "')")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🌐 MAYA OS-INDEPENDENT RAW NETWORK PROTOCOL VERIFICATION SUITE 🌐")
  println("=================================================================")

  total = 0
  passed = 0

  @! -------------------------------------------------------------
  @! GROUP 1: MAC & IP Address Conversion and Classification
  @! -------------------------------------------------------------
  println("\n▶ Group 1: MAC & IP Address Parsing and Conversion...")

  @! 1.1 MAC Parse standard colon
  total = total + 1
  mac1 = string_to_mac("00:1A:2B:3C:4D:5E")
  is_valid_mac1 = 0
  @if mac1.len() == 6
    @if mac1[0] == 0 && mac1[1] == 26 && mac1[2] == 43 && mac1[3] == 60 && mac1[4] == 77 && mac1[5] == 94
      is_valid_mac1 = 1
    @end
  @end
  passed = passed + assert_true(is_valid_mac1, "MAC parsing standard colon format")

  @! 1.2 MAC Parse hyphen format & lowercase
  total = total + 1
  mac2 = mac_parse("00-1a-2b-3c-4d-5e")
  passed = passed + assert_true(mac_equals(mac1, mac2) == 1, "MAC parsing hyphen lowercase equivalence")

  @! 1.3 MAC Format roundtrip
  total = total + 1
  mac_str = mac_to_string(mac1)
  passed = passed + assert_str_eq(mac_str, "00:1A:2B:3C:4D:5E", "MAC formatting canonical uppercase")

  @! 1.4 MAC Classification: Broadcast, Multicast, Unicast
  total = total + 1
  bcast_mac = string_to_mac("FF:FF:FF:FF:FF:FF")
  mcast_mac = string_to_mac("01:00:5E:00:00:01")
  unicast_mac = string_to_mac("52:54:00:12:34:56")
  passed = passed + assert_true(mac_is_broadcast(bcast_mac) == 1 && mac_is_multicast(mcast_mac) == 1 && mac_is_unicast(unicast_mac) == 1, "MAC classification (Broadcast, Multicast, Unicast)")

  @! 1.5 IPv4 Parse & Format roundtrip
  total = total + 1
  ip1 = string_to_ip("192.168.1.100")
  ip1_str = ip_to_string(ip1)
  is_valid_ip1 = 0
  @if ip1.len() == 4
    @if ip1[0] == 192 && ip1[1] == 168 && ip1[2] == 1 && ip1[3] == 100 && ip1_str == "192.168.1.100"
      is_valid_ip1 = 1
    @end
  @end
  passed = passed + assert_true(is_valid_ip1, "IPv4 string <-> byte array conversion roundtrip")

  @! 1.6 IPv4 U32 Integer Conversion
  total = total + 1
  ip_u32 = ipv4_to_u32(ip1)
  ip_from_u32 = ipv4_from_u32(ip_u32)
  passed = passed + assert_true(ip_u32 == 3232235876 && ipv4_equals(ip1, ip_from_u32) == 1, "IPv4 to/from 32-bit unsigned integer")

  @! 1.7 IPv4 Classification: Loopback, Private, Broadcast
  total = total + 1
  loop_ip = string_to_ip("127.0.0.1")
  priv_ip10 = string_to_ip("10.0.0.1")
  priv_ip172 = string_to_ip("172.16.5.4")
  priv_ip192 = string_to_ip("192.168.0.1")
  bcast_ip = string_to_ip("255.255.255.255")
  pub_ip = string_to_ip("8.8.8.8")
  passed = passed + assert_true(ipv4_is_loopback(loop_ip) == 1 && ipv4_is_private(priv_ip10) == 1 && ipv4_is_private(priv_ip172) == 1 && ipv4_is_private(priv_ip192) == 1 && ipv4_is_broadcast(bcast_ip) == 1 && ipv4_is_private(pub_ip) == 0, "IPv4 address classification (Loopback, RFC 1918, Broadcast)")

  @! -------------------------------------------------------------
  @! GROUP 2: IEEE 802.3 CRC-32 & Fast Table Engine
  @! -------------------------------------------------------------
  println("\n▶ Group 2: IEEE 802.3 CRC-32 Error Detection Engine...")

  @! 2.1 Standard test vector: empty array -> 0
  total = total + 1
  crc_empty = net_crc32([])
  passed = passed + assert_eq(crc_empty, 0, "CRC-32 empty input vector == 0")

  @! 2.2 Standard test vector: '123456789' -> 0xCBF43926 (3421780262)
  total = total + 1
  vec_123456789 = [49, 50, 51, 52, 53, 54, 55, 56, 57]
  crc_vec = crc32_ethernet(vec_123456789)
  passed = passed + assert_eq(crc_vec, 3421780262, "CRC-32 vector '123456789' == 0xCBF43926")

  @! 2.3 Fast Table acceleration match
  total = total + 1
  table = crc32_table_new()
  fast_crc = crc32_fast(vec_123456789, table)
  passed = passed + assert_eq(fast_crc, 3421780262, "CRC-32 fast table accelerated match")

  @! -------------------------------------------------------------
  @! GROUP 3: Layer 2 Ethernet II Framing, Padding & FCS
  @! -------------------------------------------------------------
  println("\n▶ Group 3: Ethernet II Frame Packing, Minimum Padding & FCS...")

  @! 3.1 Short payload padding (10 bytes -> 46 bytes payload, 64 bytes total)
  total = total + 1
  src_m = [0, 18, 52, 86, 120, 154]
  dst_m = [255, 255, 255, 255, 255, 255]
  short_payload = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  eth_frame = ethernet_frame_pack(dst_m, src_m, 2048, short_payload)
  passed = passed + assert_eq(eth_frame.len(), 64, "Ethernet II frame short payload padded to 64 bytes total")

  @! 3.2 Unpack valid Ethernet II Frame
  total = total + 1
  parsed_eth = ethernet_frame_unpack(eth_frame)
  passed = passed + assert_true(parsed_eth.is_valid == 1 && parsed_eth.ethertype == 2048 && mac_equals(parsed_eth.dst_mac, dst_m) == 1 && mac_equals(parsed_eth.src_mac, src_m) == 1, "Ethernet II frame parsing & CRC-32 FCS validation")

  @! 3.3 Physical Preamble & SFD prepend and strip
  total = total + 1
  preamble_frame = raw_eth_prepend_preamble(eth_frame)
  stripped_frame = raw_eth_strip_preamble(preamble_frame)
  is_valid_preamble = 0
  @if preamble_frame.len() == 72 && stripped_frame.len() == 64
    @if stripped_frame[0] == eth_frame[0]
      is_valid_preamble = 1
    @end
  @end
  passed = passed + assert_true(is_valid_preamble, "Physical preamble/SFD encapsulation and stripping")

  @! -------------------------------------------------------------
  @! GROUP 4: Corrupted Frame & FCS Invalidation Detection
  @! -------------------------------------------------------------
  println("\n▶ Group 4: FCS Bit-Flip & Corrupted Frame Detection...")

  @! 4.1 1-bit corruption in payload invalidates FCS
  total = total + 1
  @! Build corrupted_frame: copy eth_frame but flip byte[14] (first payload byte)
  corrupted_frame = []
  i = 0
  @while i < eth_frame.len()
    @if i == 14
      corrupted_frame = corrupted_frame.push((eth_frame[i] + 128) % 256)
    @else
      corrupted_frame = corrupted_frame.push(eth_frame[i])
    @end
    i = i + 1
  @end
  bad_eth = raw_eth_frame_parse(corrupted_frame)
  passed = passed + assert_eq(bad_eth.is_valid, 0, "Corrupted Ethernet frame payload detected by FCS (is_valid == 0)")

  @! 4.2 1-bit corruption in destination MAC invalidates FCS
  total = total + 1
  @! Build corrupted_mac_frame: copy eth_frame but flip byte[0] (first MAC byte)
  corrupted_mac_frame = []
  i = 0
  @while i < eth_frame.len()
    @if i == 0
      corrupted_mac_frame = corrupted_mac_frame.push((eth_frame[i] + 128) % 256)
    @else
      corrupted_mac_frame = corrupted_mac_frame.push(eth_frame[i])
    @end
    i = i + 1
  @end
  bad_mac_eth = raw_eth_frame_parse(corrupted_mac_frame)
  passed = passed + assert_eq(bad_mac_eth.is_valid, 0, "Corrupted Ethernet MAC header detected by FCS (is_valid == 0)")

  @! -------------------------------------------------------------
  @! GROUP 5: RFC 826 Address Resolution Protocol (ARP)
  @! -------------------------------------------------------------
  println("\n▶ Group 5: RFC 826 ARP Serialization, Parsing & Cache Table...")

  @! 5.1 ARP Request packet serialization & parsing
  total = total + 1
  host_mac = string_to_mac("52:54:00:AA:BB:CC")
  host_ip = string_to_ip("192.168.1.50")
  target_ip = string_to_ip("192.168.1.1")
  arp_req_frame = arp_frame_build_request(host_mac, host_ip, target_ip)
  parsed_req_eth = raw_eth_frame_parse(arp_req_frame)
  parsed_arp_req = arp_packet_unpack(parsed_req_eth.payload)
  passed = passed + assert_true(parsed_arp_req.is_valid == 1 && parsed_arp_req.opcode == 1 && ipv4_equals(parsed_arp_req.target_ip, target_ip) == 1, "ARP Request frame construction and unpacking")

  @! 5.2 ARP Cache Table Insertion & Lookup
  total = total + 1
  arp_tbl = arp_table_new()
  arp_tbl = arp_table_insert(arp_tbl, "192.168.1.1", "52:54:00:11:22:33")
  arp_tbl = arp_table_insert(arp_tbl, "192.168.1.2", "52:54:00:44:55:66")
  resolved_mac = arp_table_lookup(arp_tbl, "192.168.1.1")
  missing_mac = arp_table_lookup(arp_tbl, "192.168.1.99")
  passed = passed + assert_str_eq(resolved_mac, "52:54:00:11:22:33", "ARP table entry lookup resolved")
  total = total + 1
  passed = passed + assert_str_eq(missing_mac, "", "ARP table missing entry returns empty string")

  @! 5.3 Automated ARP Request Processing & Reply Synthesis
  total = total + 1
  router_mac = string_to_mac("52:54:00:11:22:33")
  router_ip = string_to_ip("192.168.1.1")
  reply_frame = arp_process_frame(arp_tbl, arp_req_frame, router_mac, router_ip)
  parsed_reply_eth = raw_eth_frame_parse(reply_frame)
  parsed_arp_reply = arp_packet_unpack(parsed_reply_eth.payload)
  passed = passed + assert_true(parsed_arp_reply.is_valid == 1 && parsed_arp_reply.opcode == 2 && mac_equals(parsed_arp_reply.sender_mac, router_mac) == 1 && ipv4_equals(parsed_arp_reply.sender_ip, router_ip) == 1 && mac_equals(parsed_arp_reply.target_mac, host_mac) == 1, "Automated ARP Reply synthesis and target mapping")

  @! -------------------------------------------------------------
  @! GROUP 6: RFC 791 IPv4 Packet Framing & RFC 1071 Checksum
  @! -------------------------------------------------------------
  println("\n▶ Group 6: RFC 791 IPv4 Framing & RFC 1071 Internet Checksum...")

  @! 6.1 IPv4 Header Checksum Calculation & Zero Verification
  total = total + 1
  ip_payload = [10, 20, 30, 40, 50]
  raw_ip_pkt = raw_ipv4_packet_build("10.0.0.1", "10.0.0.2", 17, ip_payload)
  parsed_ip = raw_ipv4_parse(raw_ip_pkt)
  passed = passed + assert_true(parsed_ip.is_valid == 1 && parsed_ip.version == 4 && parsed_ip.ihl == 5 && parsed_ip.total_len == 25 && parsed_ip.protocol == 17 && parsed_ip.payload.len() == 5, "IPv4 standard 20-byte header serialization and checksum")

  @! 6.2 IPv4 with IP Options (IHL = 6, 24 bytes header)
  total = total + 1
  ip_opt_pkt = {
    version: 4,
    ihl: 6,
    dscp: 0,
    total_len: 28,
    id: 42,
    flags: 2,
    frag_offset: 0,
    ttl: 128,
    protocol: 6,
    checksum: 0,
    src_ip: string_to_ip("172.16.0.1"),
    dst_ip: string_to_ip("172.16.0.2"),
    options: [1, 1, 1, 0], @! 4 bytes of NOP options
    payload: [65, 66, 67, 68],
    is_valid: 1
  }
  raw_opt_bytes = raw_ipv4_serialize(ip_opt_pkt)
  parsed_opt_ip = raw_ipv4_parse(raw_opt_bytes)
  passed = passed + assert_true(parsed_opt_ip.is_valid == 1 && parsed_opt_ip.ihl == 6 && parsed_opt_ip.options.len() == 4 && parsed_opt_ip.payload.len() == 4, "IPv4 header with 4-byte Options (IHL=6) and checksum")

  @! -------------------------------------------------------------
  @! GROUP 7: IPv4 Checksum Bit-Flip Detection
  @! -------------------------------------------------------------
  println("\n▶ Group 7: IPv4 Checksum Bit-Flip & Corruption Detection...")

  @! 7.1 Checksum failure on bit-flipped TTL
  total = total + 1
  @! Build bad_ip_bytes: copy raw_ip_pkt but flip byte[8] (TTL)
  bad_ip_bytes = []
  i = 0
  @while i < raw_ip_pkt.len()
    @if i == 8
      bad_ip_bytes = bad_ip_bytes.push((raw_ip_pkt[i] + 128) % 256)
    @else
      bad_ip_bytes = bad_ip_bytes.push(raw_ip_pkt[i])
    @end
    i = i + 1
  @end
  bad_ip = raw_ipv4_parse(bad_ip_bytes)
  passed = passed + assert_eq(bad_ip.is_valid, 0, "IPv4 header checksum rejects modified TTL (is_valid == 0)")

  @! 7.2 Checksum failure on bit-flipped IP address
  total = total + 1
  @! Build bad_ip_bytes2: copy raw_ip_pkt but flip byte[12] (Source IP)
  bad_ip_bytes2 = []
  i = 0
  @while i < raw_ip_pkt.len()
    @if i == 12
      bad_ip_bytes2 = bad_ip_bytes2.push((raw_ip_pkt[i] + 128) % 256)
    @else
      bad_ip_bytes2 = bad_ip_bytes2.push(raw_ip_pkt[i])
    @end
    i = i + 1
  @end
  bad_ip2 = raw_ipv4_parse(bad_ip_bytes2)
  passed = passed + assert_eq(bad_ip2.is_valid, 0, "IPv4 header checksum rejects modified Source IP (is_valid == 0)")

  @! -------------------------------------------------------------
  @! GROUP 8: RFC 792 ICMP Echo Request & Reply
  @! -------------------------------------------------------------
  println("\n▶ Group 8: RFC 792 ICMP Echo Request, Reply & Ping Verification...")

  @! 8.1 ICMP Echo Request Serialization
  total = total + 1
  ping_data = [80, 73, 78, 71, 33] @! "PING!"
  icmp_req_raw = raw_icmp_echo_request_build(1001, 1, ping_data)
  parsed_icmp_req = raw_icmp_parse(icmp_req_raw)
  @if parsed_icmp_req.is_valid == 1 && parsed_icmp_req.icmp_type == 8 && parsed_icmp_req.code == 0 && parsed_icmp_req.ident == 1001 && parsed_icmp_req.seq == 1 && parsed_icmp_req.payload.len() == 5
    passed = passed + assert_true(parsed_icmp_req.is_valid == 1 && parsed_icmp_req.icmp_type == 8 && parsed_icmp_req.code == 0 && parsed_icmp_req.ident == 1001 && parsed_icmp_req.seq == 1 && parsed_icmp_req.payload.len() == 5, "ICMP Echo Request (Type 8) serialization & checksum validation")
  @else
    passed = passed + assert_true(0, "ICMP Echo Request (Type 8) serialization & checksum validation")
  @end

  @! 8.2 ICMP Echo Reply Synthesis
  total = total + 1
  icmp_rep_raw = raw_icmp_echo_reply_build(parsed_icmp_req.ident, parsed_icmp_req.seq, parsed_icmp_req.payload)
  parsed_icmp_rep = raw_icmp_parse(icmp_rep_raw)
  @if parsed_icmp_rep.is_valid == 1 && parsed_icmp_rep.icmp_type == 0 && parsed_icmp_rep.code == 0 && parsed_icmp_rep.ident == 1001 && parsed_icmp_rep.seq == 1 && parsed_icmp_rep.payload.len() == 5
    passed = passed + assert_true(parsed_icmp_rep.is_valid == 1 && parsed_icmp_rep.icmp_type == 0 && parsed_icmp_rep.code == 0 && parsed_icmp_rep.ident == 1001 && parsed_icmp_rep.seq == 1 && parsed_icmp_rep.payload.len() == 5, "ICMP Echo Reply (Type 0) synthesis & checksum validation")
  @else
    passed = passed + assert_true(0, "ICMP Echo Reply (Type 0) synthesis & checksum validation")
  @end

  @! -------------------------------------------------------------
  @! GROUP 9: RFC 768 UDP Datagram & Pseudo-Header Checksum
  @! -------------------------------------------------------------
  println("\n▶ Group 9: RFC 768 UDP Datagram & Pseudo-Header Checksum...")

  @! 9.1 UDP Even-Length Payload with Pseudo-Header Checksum
  total = total + 1
  udp_src_ip = string_to_ip("192.168.1.10")
  udp_dst_ip = string_to_ip("192.168.1.20")
  udp_even_payload = [1, 2, 3, 4]
  udp_even_bytes = udp_packet_pack(8080, 53, udp_even_payload, udp_src_ip, udp_dst_ip)
  parsed_udp_even = udp_packet_unpack(udp_even_bytes, udp_src_ip, udp_dst_ip)
  @if parsed_udp_even.is_valid == 1 && parsed_udp_even.src_port == 8080 && parsed_udp_even.dst_port == 53 && parsed_udp_even.udp_len == 12 && parsed_udp_even.payload.len() == 4
    passed = passed + assert_true(parsed_udp_even.is_valid == 1 && parsed_udp_even.src_port == 8080 && parsed_udp_even.dst_port == 53 && parsed_udp_even.udp_len == 12 && parsed_udp_even.payload.len() == 4, "UDP datagram with even-length payload pseudo-header checksum")
  @else
    passed = passed + assert_true(0, "UDP datagram with even-length payload pseudo-header checksum")
  @end

  @! 9.2 UDP Odd-Length Payload (with virtual trailing zero padding in pseudo-header)
  total = total + 1
  udp_odd_payload = [10, 20, 30] @! 3 bytes odd
  udp_odd_bytes = udp_packet_pack(5000, 5001, udp_odd_payload, udp_src_ip, udp_dst_ip)
  parsed_udp_odd = udp_packet_unpack(udp_odd_bytes, udp_src_ip, udp_dst_ip)
  @if parsed_udp_odd.is_valid == 1 && parsed_udp_odd.udp_len == 11 && parsed_udp_odd.payload.len() == 3
    passed = passed + assert_true(parsed_udp_odd.is_valid == 1 && parsed_udp_odd.udp_len == 11 && parsed_udp_odd.payload.len() == 3, "UDP datagram with odd-length payload pseudo-header checksum")
  @else
    passed = passed + assert_true(0, "UDP datagram with odd-length payload pseudo-header checksum")
  @end

  @! 9.3 UDP Checksum Bit-Flip Corruption Rejection
  total = total + 1
  @! Build bad_udp_bytes: copy udp_even_bytes but flip byte[8] (payload byte)
  bad_udp_bytes = []
  i = 0
  @while i < udp_even_bytes.len()
    @if i == 8
      bad_udp_bytes = bad_udp_bytes.push((udp_even_bytes[i] + 128) % 256)
    @else
      bad_udp_bytes = bad_udp_bytes.push(udp_even_bytes[i])
    @end
    i = i + 1
  @end
  bad_udp = udp_packet_unpack(bad_udp_bytes, udp_src_ip, udp_dst_ip)
  passed = passed + assert_eq(bad_udp.is_valid, 0, "UDP pseudo-header checksum rejects corrupted payload (is_valid == 0)")

  @! -------------------------------------------------------------
  @! GROUP 10: RFC 793 TCP Segment Framing & Pseudo Checksum
  @! -------------------------------------------------------------
  println("\n▶ Group 10: RFC 793 TCP Segment Framing & Pseudo Checksum...")

  @! 10.1 TCP Segment Packing & Unpacking with SYN flag
  total = total + 1
  tcp_src_ip = string_to_ip("10.1.1.1")
  tcp_dst_ip = string_to_ip("10.1.1.2")
  tcp_seg_bytes = tcp_packet_pack(443, 80, 100000, 0, TCP_FLAG_SYN(), 64240, [], tcp_src_ip, tcp_dst_ip)
  parsed_tcp = tcp_packet_unpack(tcp_seg_bytes, tcp_src_ip, tcp_dst_ip)
  @if parsed_tcp.is_valid == 1 && parsed_tcp.src_port == 443 && parsed_tcp.dst_port == 80 && parsed_tcp.seq_num == 100000 && parsed_tcp.flags == TCP_FLAG_SYN() && parsed_tcp.window_size == 64240
    passed = passed + assert_true(parsed_tcp.is_valid == 1 && parsed_tcp.src_port == 443 && parsed_tcp.dst_port == 80 && parsed_tcp.seq_num == 100000 && parsed_tcp.flags == TCP_FLAG_SYN() && parsed_tcp.window_size == 64240, "TCP segment SYN packet packing and pseudo-header checksum")
  @else
    passed = passed + assert_true(0, "TCP segment SYN packet packing and pseudo-header checksum")
  @end

  @! 10.2 TCP Modulo Sequence Arithmetic
  total = total + 1
  seq_start = 4294967290
  seq_next = tcp_seq_add(seq_start, 10)
  seq_diff = tcp_seq_diff(seq_next, seq_start)
  @if seq_next == 4 && seq_diff == 10
    passed = passed + assert_true(seq_next == 4 && seq_diff == 10, "TCP 32-bit sequence number modulo wrapping arithmetic")
  @else
    passed = passed + assert_true(0, "TCP 32-bit sequence number modulo wrapping arithmetic")
  @end

  @! -------------------------------------------------------------
  @! GROUP 11: TCP Connection State Machine & Handshake Simulation
  @! -------------------------------------------------------------
  println("\n▶ Group 11: TCP Connection State Machine & Handshake Lifecycle...")

  @! 11.1 Client-Server 3-Way Handshake — index-tracking (outbox clear broken in Maya)
  total = total + 1
  client_ip = string_to_ip("192.168.1.101")
  server_ip = string_to_ip("192.168.1.202")

  server_ep = tcp_endpoint_new("server", server_ip, 8080)
  server_ep = tcp_endpoint_listen(server_ep)

  client_ep = tcp_endpoint_new("client", client_ip, 54321)
  client_ep = tcp_endpoint_connect(client_ep, server_ip, 8080, 1000)

  @! client_ep.outbox[0] = SYN packet (index 0)
  @! Step 1: Deliver SYN from Client to Server
  syn_pkt = client_ep.outbox[0]
  server_ep = tcp_endpoint_process_packet(server_ep, syn_pkt, client_ip)

  @! server_ep.outbox[0] = SYN-ACK (index 0)
  @! Step 2: Deliver SYN-ACK from Server to Client
  syn_ack_pkt = server_ep.outbox[0]
  client_ep = tcp_endpoint_process_packet(client_ep, syn_ack_pkt, server_ip)

  @! client_ep.outbox[1] = ACK (SYN was index 0, ACK is index 1)
  @! Step 3: Deliver ACK from Client to Server
  ack_pkt = client_ep.outbox[1]
  server_ep = tcp_endpoint_process_packet(server_ep, ack_pkt, client_ip)

  @if client_ep.tcp_state == TCP_STATE_ESTABLISHED() && server_ep.tcp_state == TCP_STATE_ESTABLISHED()
    passed = passed + assert_true(client_ep.tcp_state == TCP_STATE_ESTABLISHED() && server_ep.tcp_state == TCP_STATE_ESTABLISHED(), "TCP 3-way handshake established between client and server")
  @else
    passed = passed + assert_true(0, "TCP 3-way handshake established between client and server")
  @end

  @! 11.2 Full-Duplex Data Streaming over Established TCP Connection
  total = total + 1
  data_payload = [77, 65, 89, 65, 95, 78, 69, 84] @! "MAYA_NET" (8 bytes)
  client_ep = tcp_endpoint_send_data(client_ep, data_payload)
  @! client outbox: [SYN(0), ACK(1), DATA(2)]
  data_pkt = client_ep.outbox[2]
  server_ep = tcp_endpoint_process_packet(server_ep, data_pkt, client_ip)

  @! server outbox: [SYN-ACK(0), ACK-for-DATA(1)]
  data_ack_pkt = server_ep.outbox[1]
  client_ep = tcp_endpoint_process_packet(client_ep, data_ack_pkt, server_ip)

  @if server_ep.recv_buf.len() == 8 && server_ep.recv_buf[0] == 77 && server_ep.recv_buf[7] == 84
    passed = passed + assert_true(server_ep.recv_buf.len() == 8 && server_ep.recv_buf[0] == 77 && server_ep.recv_buf[7] == 84, "TCP data streaming payload transmission & buffer accumulation")
  @else
    passed = passed + assert_true(0, "TCP data streaming payload transmission & buffer accumulation")
  @end

  @! 11.3 Graceful Connection Teardown (FIN -> ACK -> FIN -> ACK)
  total = total + 1
  client_ep = tcp_endpoint_close(client_ep) @! Client -> FIN_WAIT_1
  @! client outbox: [SYN(0), ACK(1), DATA(2), FIN(3)]
  fin_pkt = client_ep.outbox[3]
  server_ep = tcp_endpoint_process_packet(server_ep, fin_pkt, client_ip) @! Server -> CLOSE_WAIT

  @! server outbox: [SYN-ACK(0), ACK-DATA(1), FIN-ACK(2)]
  fin_ack_pkt = server_ep.outbox[2]
  client_ep = tcp_endpoint_process_packet(client_ep, fin_ack_pkt, server_ip) @! Client -> FIN_WAIT_2

  server_ep = tcp_endpoint_close(server_ep) @! Server -> LAST_ACK
  @! server outbox: [SYN-ACK(0), ACK-DATA(1), FIN-ACK(2), FIN(3)]
  server_fin_pkt = server_ep.outbox[3]
  client_ep = tcp_endpoint_process_packet(client_ep, server_fin_pkt, server_ip) @! Client -> TIME_WAIT

  @! client outbox: [SYN(0), ACK(1), DATA(2), FIN(3), final-ACK(4)]
  client_final_ack = client_ep.outbox[4]
  server_ep = tcp_endpoint_process_packet(server_ep, client_final_ack, client_ip) @! Server -> CLOSED

  @if client_ep.tcp_state == TCP_STATE_TIME_WAIT() && server_ep.tcp_state == TCP_STATE_CLOSED()
    passed = passed + assert_true(client_ep.tcp_state == TCP_STATE_TIME_WAIT() && server_ep.tcp_state == TCP_STATE_CLOSED(), "TCP graceful connection teardown (FIN/ACK) simulation")
  @else
    passed = passed + assert_true(0, "TCP graceful connection teardown (FIN/ACK) simulation")
  @end

  @! -------------------------------------------------------------
  @! GROUP 12: VirtualNetworkHub Multi-Node Unicast & Broadcast
  @! -------------------------------------------------------------
  println("\n▶ Group 12: VirtualNetworkHub Multi-Node Routing Simulation...")

  @! 12.1 Register 3 Virtual Interfaces on Hub
  total = total + 1
  hub = vnet_hub_new()
  node_a = vnet_iface_from_str("node_a", "52:54:00:00:00:01", "10.0.0.1")
  node_b = vnet_iface_from_str("node_b", "52:54:00:00:00:02", "10.0.0.2")
  node_c = vnet_iface_from_str("node_c", "52:54:00:00:00:03", "10.0.0.3")

  hub = vnet_hub_add_interface(hub, node_a)
  hub = vnet_hub_add_interface(hub, node_b)
  hub = vnet_hub_add_interface(hub, node_c)

  passed = passed + assert_eq(hub.interfaces.len(), 3, "VirtualNetworkHub registered 3 virtual interfaces")

  @! 12.2 Unicast Routing: Node A -> Node B (Node C must not receive packet)
  @! Use vnet_hub_send_from instead of hub.interfaces[0]=node_a (arr element assign broken)
  total = total + 1
  unicast_payload = [100, 101, 102]
  unicast_frame = ethernet_frame_pack(node_b.mac_addr, node_a.mac_addr, 2048, unicast_payload)
  hub = vnet_hub_send_from(hub, 0, unicast_frame)

  hub = vnet_hub_step(hub)
  node_b_recvd = hub.interfaces[1].inbox.len()
  node_c_recvd = hub.interfaces[2].inbox.len()

  @if node_b_recvd == 1 && node_c_recvd == 0
    passed = passed + assert_true(node_b_recvd == 1 && node_c_recvd == 0, "VirtualNetworkHub delivers unicast frame exclusively to target interface")
  @else
    passed = passed + assert_true(0, "VirtualNetworkHub delivers unicast frame exclusively to target interface")
  @end

  @! 12.3 Broadcast Routing: Node A -> Broadcast (All nodes receive frame)
  @! Use vnet_hub_send_from — hub.interfaces[0]=X is broken in Maya
  total = total + 1
  bcast_frame = ethernet_frame_pack([255, 255, 255, 255, 255, 255], node_a.mac_addr, 2054, [1, 2, 3])
  hub = vnet_hub_send_from(hub, 0, bcast_frame)

  hub = vnet_hub_step(hub)
  hub_a_len = hub.interfaces[0].inbox.len()
  hub_b_len = hub.interfaces[1].inbox.len()
  hub_c_len = hub.interfaces[2].inbox.len()
  @if hub_a_len >= 1 && hub_b_len >= 2 && hub_c_len >= 1
    passed = passed + assert_true(hub_a_len >= 1 && hub_b_len >= 2 && hub_c_len >= 1, "VirtualNetworkHub broadcasts frame to all registered interfaces")
  @else
    passed = passed + assert_true(0, "VirtualNetworkHub broadcasts frame to all registered interfaces")
  @end

  println("\n=================================================================")
  println("RAW NETWORK STACK TEST RESULTS: " + maya_int_to_str(passed) + "/" + maya_int_to_str(total) + " assertions passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL OS-INDEPENDENT RAW NETWORK PROTOCOL TESTS PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ SOME NETWORK PROTOCOL TESTS FAILED!")
    return 1
  @end
@end
