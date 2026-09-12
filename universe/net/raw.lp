@fn raw_u16_be(buf, off)
  b0 = buf[off] % 256
  t0 = b0 * 256
  b1 = buf[off + 1] % 256
  res = t0 + b1
  return res % 65536
@end

@fn raw_u32_be(buf, off)
  b0 = buf[off] % 256
  t0 = b0 * 16777216
  b1 = buf[off + 1] % 256
  t1 = b1 * 65536
  b2 = buf[off + 2] % 256
  t2 = b2 * 256
  b3 = buf[off + 3] % 256
  r01 = t0 + t1
  r23 = t2 + b3
  res = r01 + r23
  return res % 4294967296
@end

@! ============================================================================
@! LIPI UNIVERSE: OS-INDEPENDENT RAW NETWORK PROTOCOL STACK
@! Module: universe/net/raw.lp
@! 100% Pure Lipi Implementation - Zero External / OS C Socket Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! ============================================================================
@! 1. Data Structures (@struct)
@! ============================================================================

@struct EthFrame
  dst_mac: array
  src_mac: array
  ethertype: i64
  payload: array
  fcs: i64
  is_valid: i64
@end

@struct ArpPacket
  htype: i64
  ptype: i64
  hlen: i64
  plen: i64
  opcode: i64
  sender_mac: array
  sender_ip: array
  target_mac: array
  target_ip: array
  is_valid: i64
@end

@struct ArpEntry
  ip: string
  mac: string
  arp_state: string
  ttl: i64
@end

@struct ArpTable
  entries: array
  max_entries: i64
@end

@struct IPv4Packet
  version: i64
  ihl: i64
  dscp: i64
  total_len: i64
  id: i64
  flags: i64
  frag_offset: i64
  ttl: i64
  protocol: i64
  checksum: i64
  src_ip: array
  dst_ip: array
  options: array
  payload: array
  is_valid: i64
@end

@struct IPv6Packet
  version: i64
  payload_len: i64
  next_header: i64
  hop_limit: i64
  src_ip: array
  dst_ip: array
  payload: array
  is_valid: i64
@end

@struct ICMPPacket
  icmp_type: i64
  code: i64
  checksum: i64
  ident: i64
  seq: i64
  payload: array
  is_valid: i64
@end

@struct UDPSegment
  src_port: i64
  dst_port: i64
  udp_len: i64
  checksum: i64
  payload: array
  is_valid: i64
@end

@struct TCPSegment
  src_port: i64
  dst_port: i64
  seq_num: i64
  ack_num: i64
  data_offset: i64
  flags: i64
  window_size: i64
  checksum: i64
  urgent_ptr: i64
  payload: array
  is_valid: i64
@end

@struct VirtualInterface
  iface_id: string
  mac_addr: array
  ip_addr: array
  inbox: array
  outbox: array
@end

@struct VirtualNetworkHub
  interfaces: array
  buffer_queue: array
  packet_count: i64
@end

@struct TcpEndpoint
  ep_id: string
  tcp_state: i64
  local_ip: array
  local_port: i64
  remote_ip: array
  remote_port: i64
  seq_num: i64
  ack_num: i64
  recv_buf: array
  outbox: array
  is_valid: i64
@end

@struct TcpConnection
  client_id: string
  server_id: string
  is_connected: i64
@end

@! ============================================================================
@! 2. Empty Struct Factories for Type-Safe Parsing Error Paths
@! ============================================================================

@fn raw_eth_empty()
  return {
    dst_mac: [],
    src_mac: [],
    ethertype: 0,
    payload: [],
    fcs: 0,
    is_valid: 0
  }
@end

@fn raw_arp_empty()
  return {
    htype: 0,
    ptype: 0,
    hlen: 0,
    plen: 0,
    opcode: 0,
    sender_mac: [],
    sender_ip: [],
    target_mac: [],
    target_ip: [],
    is_valid: 0
  }
@end

@fn raw_ipv4_empty()
  return {
    version: 0,
    ihl: 0,
    dscp: 0,
    total_len: 0,
    id: 0,
    flags: 0,
    frag_offset: 0,
    ttl: 0,
    protocol: 0,
    checksum: 0,
    src_ip: [],
    dst_ip: [],
    options: [],
    payload: [],
    is_valid: 0
  }
@end

@fn raw_ipv6_empty()
  return {
    version: 0,
    payload_len: 0,
    next_header: 0,
    hop_limit: 0,
    src_ip: [],
    dst_ip: [],
    payload: [],
    is_valid: 0
  }
@end

@fn raw_icmp_empty()
  return {
    icmp_type: 0,
    code: 0,
    checksum: 0,
    ident: 0,
    seq: 0,
    payload: [],
    is_valid: 0
  }
@end

@fn raw_udp_empty()
  return {
    src_port: 0,
    dst_port: 0,
    udp_len: 0,
    checksum: 0,
    payload: [],
    is_valid: 0
  }
@end

@fn raw_tcp_empty()
  return {
    src_port: 0,
    dst_port: 0,
    seq_num: 0,
    ack_num: 0,
    data_offset: 0,
    flags: 0,
    window_size: 0,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 0
  }
@end

@! ============================================================================
@! 3. Address Parsing, Formatting & Classification Utilities
@! ============================================================================

@fn hex_char_to_val(ch)
  @if ch == "0" return 0 @end
  @if ch == "1" return 1 @end
  @if ch == "2" return 2 @end
  @if ch == "3" return 3 @end
  @if ch == "4" return 4 @end
  @if ch == "5" return 5 @end
  @if ch == "6" return 6 @end
  @if ch == "7" return 7 @end
  @if ch == "8" return 8 @end
  @if ch == "9" return 9 @end
  @if ch == "A" return 10 @end
  @if ch == "B" return 11 @end
  @if ch == "C" return 12 @end
  @if ch == "D" return 13 @end
  @if ch == "E" return 14 @end
  @if ch == "F" return 15 @end
  @if ch == "a" return 10 @end
  @if ch == "b" return 11 @end
  @if ch == "c" return 12 @end
  @if ch == "d" return 13 @end
  @if ch == "e" return 14 @end
  @if ch == "f" return 15 @end
  return -1
@end

@fn byte_to_hex_upper(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
  v = b % 256
  @if v < 0 v = 0 @end
  hi = (v / 16) % 16
  lo = v % 16
  return hex_chars[hi] + hex_chars[lo]
@end

@fn byte_to_hex_lower(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  v = b % 256
  @if v < 0 v = 0 @end
  hi = (v / 16) % 16
  lo = v % 16
  return hex_chars[hi] + hex_chars[lo]
@end

@fn is_hex_char(ch)
  @if ch == "0" return 1 @end
  @if ch == "1" return 1 @end
  @if ch == "2" return 1 @end
  @if ch == "3" return 1 @end
  @if ch == "4" return 1 @end
  @if ch == "5" return 1 @end
  @if ch == "6" return 1 @end
  @if ch == "7" return 1 @end
  @if ch == "8" return 1 @end
  @if ch == "9" return 1 @end
  @if ch == "A" return 1 @end
  @if ch == "B" return 1 @end
  @if ch == "C" return 1 @end
  @if ch == "D" return 1 @end
  @if ch == "E" return 1 @end
  @if ch == "F" return 1 @end
  @if ch == "a" return 1 @end
  @if ch == "b" return 1 @end
  @if ch == "c" return 1 @end
  @if ch == "d" return 1 @end
  @if ch == "e" return 1 @end
  @if ch == "f" return 1 @end
  return 0
@end

@fn mac_parse_byte(s, pos)
  ch1 = str_char_at(s, pos)
  ch2 = str_char_at(s, pos + 1)
  @if is_hex_char(ch1) == 0 return -1 @end
  @if is_hex_char(ch2) == 0 return -1 @end
  hi = hex_char_to_val(ch1)
  lo = hex_char_to_val(ch2)
  return (hi * 16 + lo) % 256
@end

@fn mac_parse(s)
  @! Supports "AA:BB:CC:DD:EE:FF" and "AA-BB-CC-DD-EE-FF" (17 chars) and "AABBCCDDEEFF" (12 chars)
  n = str_len(s)
  @if n == 17
    @! Colon/hyphen separated — bytes at positions 0,3,6,9,12,15
    b0 = mac_parse_byte(s, 0)
    b1 = mac_parse_byte(s, 3)
    b2 = mac_parse_byte(s, 6)
    b3 = mac_parse_byte(s, 9)
    b4 = mac_parse_byte(s, 12)
    b5 = mac_parse_byte(s, 15)
    @if b0 < 0 return [] @end
    @if b1 < 0 return [] @end
    @if b2 < 0 return [] @end
    @if b3 < 0 return [] @end
    @if b4 < 0 return [] @end
    @if b5 < 0 return [] @end
    return [b0, b1, b2, b3, b4, b5]
  @end
  @if n == 12
    @! No separators — bytes at positions 0,2,4,6,8,10
    b0 = mac_parse_byte(s, 0)
    b1 = mac_parse_byte(s, 2)
    b2 = mac_parse_byte(s, 4)
    b3 = mac_parse_byte(s, 6)
    b4 = mac_parse_byte(s, 8)
    b5 = mac_parse_byte(s, 10)
    @if b0 < 0 return [] @end
    @if b1 < 0 return [] @end
    @if b2 < 0 return [] @end
    @if b3 < 0 return [] @end
    @if b4 < 0 return [] @end
    @if b5 < 0 return [] @end
    return [b0, b1, b2, b3, b4, b5]
  @end
  return []
@end

@fn string_to_mac(s)
  return mac_parse(s)
@end

@fn mac_format(mac_bytes)
  @if mac_bytes.len() != 6 return "" @end
  return byte_to_hex_upper(mac_bytes[0]) + ":" + byte_to_hex_upper(mac_bytes[1]) + ":" + byte_to_hex_upper(mac_bytes[2]) + ":" + byte_to_hex_upper(mac_bytes[3]) + ":" + byte_to_hex_upper(mac_bytes[4]) + ":" + byte_to_hex_upper(mac_bytes[5])
@end

@fn mac_to_string(mac_bytes)
  return mac_format(mac_bytes)
@end

@fn mac_is_broadcast(bytes)
  @if bytes.len() != 6 return 0 @end
  v0 = bytes[0] % 256
  v1 = bytes[1] % 256
  v2 = bytes[2] % 256
  v3 = bytes[3] % 256
  v4 = bytes[4] % 256
  v5 = bytes[5] % 256
  @if v0 != 255 return 0 @end
  @if v1 != 255 return 0 @end
  @if v2 != 255 return 0 @end
  @if v3 != 255 return 0 @end
  @if v4 != 255 return 0 @end
  @if v5 != 255 return 0 @end
  return 1
@end

@fn mac_is_multicast(bytes)
  @if bytes.len() != 6 return 0 @end
  @if mac_is_broadcast(bytes) == 1 return 0 @end
  masked_v = bytes[0] % 2
  @if masked_v == 1 return 1 @end
  return 0
@end

@fn mac_is_unicast(bytes)
  @if bytes.len() != 6 return 0 @end
  @if mac_is_broadcast(bytes) == 1 return 0 @end
  masked_v = bytes[0] % 2
  @if masked_v == 0 return 1 @end
  return 0
@end

@fn mac_equals(a, b)
  @if a.len() != 6 return 0 @end
  @if b.len() != 6 return 0 @end
  a0 = a[0] % 256
  a1 = a[1] % 256
  a2 = a[2] % 256
  a3 = a[3] % 256
  a4 = a[4] % 256
  a5 = a[5] % 256
  b0 = b[0] % 256
  b1 = b[1] % 256
  b2 = b[2] % 256
  b3 = b[3] % 256
  b4 = b[4] % 256
  b5 = b[5] % 256
  @if a0 != b0 return 0 @end
  @if a1 != b1 return 0 @end
  @if a2 != b2 return 0 @end
  @if a3 != b3 return 0 @end
  @if a4 != b4 return 0 @end
  @if a5 != b5 return 0 @end
  return 1
@end

@fn is_digit_char(ch)
  @if ch == "0" return 1 @end
  @if ch == "1" return 1 @end
  @if ch == "2" return 1 @end
  @if ch == "3" return 1 @end
  @if ch == "4" return 1 @end
  @if ch == "5" return 1 @end
  @if ch == "6" return 1 @end
  @if ch == "7" return 1 @end
  @if ch == "8" return 1 @end
  @if ch == "9" return 1 @end
  return 0
@end

@fn digit_char_to_val(ch)
  @if ch == "0" return 0 @end
  @if ch == "1" return 1 @end
  @if ch == "2" return 2 @end
  @if ch == "3" return 3 @end
  @if ch == "4" return 4 @end
  @if ch == "5" return 5 @end
  @if ch == "6" return 6 @end
  @if ch == "7" return 7 @end
  @if ch == "8" return 8 @end
  @if ch == "9" return 9 @end
  return 0
@end

@fn parse_ip_octet(s, start, end_pos)
  @! Parse decimal integer from s[start..end_pos]
  val = 0
  i = start
  @while i < end_pos
    ch = str_char_at(s, i)
    @if is_digit_char(ch) == 1
      val = val * 10 + digit_char_to_val(ch)
    @end
    i = i + 1
  @end
  return val
@end

@fn ipv4_parse(s)
  @! Parse "a.b.c.d" format — find dot positions and parse octets
  n = str_len(s)
  @if n < 7 return [] @end
  @if n > 15 return [] @end
  dot1 = -1
  dot2 = -1
  dot3 = -1
  j = 0
  @while j < n
    ch = str_char_at(s, j)
    @if ch == "."
      @if dot1 < 0
        dot1 = j
      @else
        @if dot2 < 0
          dot2 = j
        @else
          dot3 = j
        @end
      @end
    @end
    j = j + 1
  @end
  @if dot1 < 0 return [] @end
  @if dot2 < 0 return [] @end
  @if dot3 < 0 return [] @end
  b0 = parse_ip_octet(s, 0, dot1)
  b1 = parse_ip_octet(s, dot1 + 1, dot2)
  b2 = parse_ip_octet(s, dot2 + 1, dot3)
  b3 = parse_ip_octet(s, dot3 + 1, n)
  @if b0 > 255 return [] @end
  @if b1 > 255 return [] @end
  @if b2 > 255 return [] @end
  @if b3 > 255 return [] @end
  return [b0, b1, b2, b3]
@end

@fn string_to_ip(s)
  return ipv4_parse(s)
@end

@fn ipv4_format(ip_bytes)
  @if ip_bytes.len() != 4 return "" @end
  v0 = ip_bytes[0] % 256
  v1 = ip_bytes[1] % 256
  v2 = ip_bytes[2] % 256
  v3 = ip_bytes[3] % 256
  return v0.to_str() + "." + v1.to_str() + "." + v2.to_str() + "." + v3.to_str()
@end

@fn ip_to_string(ip_bytes)
  return ipv4_format(ip_bytes)
@end

@fn ipv4_to_u32(ip_bytes)
  @if ip_bytes.len() != 4 return 0 @end
  b0 = ip_bytes[0] % 256
  b1 = ip_bytes[1] % 256
  b2 = ip_bytes[2] % 256
  b3 = ip_bytes[3] % 256
  return b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
@end

@fn ipv4_from_u32(val)
  v = val % 4294967296
  b0 = (v / 16777216) % 256
  b1 = (v / 65536) % 256
  b2 = (v / 256) % 256
  b3 = v % 256
  return [b0, b1, b2, b3]
@end

@fn ipv4_is_loopback(bytes)
  @if bytes.len() != 4 return 0 @end
  masked_v = bytes[0] % 256
    @if masked_v == 127 return 1 @end
  return 0
@end

@fn ipv4_is_private(bytes)
  @if bytes.len() != 4 return 0 @end
  b0 = bytes[0] % 256
  b1 = bytes[1] % 256
  @if b0 == 10 return 1 @end
  @if b0 == 172 && b1 >= 16 && b1 <= 31 return 1 @end
  @if b0 == 192 && b1 == 168 return 1 @end
  return 0
@end

@fn ipv4_is_broadcast(bytes)
  @if bytes.len() != 4 return 0 @end
  b0 = bytes[0] % 256
  b1 = bytes[1] % 256
  b2 = bytes[2] % 256
  b3 = bytes[3] % 256
  @if b0 == 255 && b1 == 255 && b2 == 255 && b3 == 255
    return 1
  @end
  return 0
@end

@fn ipv4_equals(a, b)
  @if a.len() != 4 || b.len() != 4 return 0 @end
  i = 0
  @while i < 4
    ai = a[i] % 256
    bi = b[i] % 256
    @if ai != bi return 0 @end
    i = i + 1
  @end
  return 1
@end

@! ============================================================================
@! 4. IEEE 802.3 CRC-32 Frame Check Sequence Engine
@! ============================================================================

@fn bit_xor32(a, b)
  @! Pure arithmetic XOR for 32-bit values — Maya's ^ operator is broken
  result = 0
  place = 1
  @while place < 4294967297
    a_bit = (a / place) % 2
    b_bit = (b / place) % 2
    xor_bit = a_bit + b_bit - 2 * a_bit * b_bit
    result = result + xor_bit * place
    place = place * 2
  @end
  return result
@end

@fn crc32_bit_step(c)
  @! One CRC-32 bit step using arithmetic XOR (no broken ^ operator)
  low = c % 2
  shifted = c / 2
  @if low == 1
    xored = bit_xor32(shifted, 3988292384)
    return xored
  @end
  return shifted
@end

@fn crc32_entry(byte_val)
  @! CRC-32 table entry — fully unrolled 8-bit inner loop
  c = byte_val % 256
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  c = crc32_bit_step(c)
  return c % 4294967296
@end

@fn net_crc32(bytes_arr)
  @! CRC-32 (IEEE 802.3) — single-level @while, arithmetic XOR
  crc = 4294967295
  i = 0
  n = bytes_arr.len()
  @while i < n
    b = bytes_arr[i] % 256
    xor_tmp = bit_xor32(crc, b)
    xor_byte = xor_tmp % 256
    entry = crc32_entry(xor_byte)
    crc_hi = crc / 256
    crc = bit_xor32(crc_hi, entry)
    crc = crc % 4294967296
    i = i + 1
  @end
  return bit_xor32(crc, 4294967295) % 4294967296
@end

@fn crc32_ethernet(data)
  return net_crc32(data)
@end

@fn crc32_table_new()
  @! 256-entry CRC-32 lookup table — single-level @while
  table = []
  i = 0
  @while i < 256
    table = table.push(crc32_entry(i))
    i = i + 1
  @end
  return table
@end

@fn crc32_fast(data_bytes, table)
  @! CRC-32 with pre-built table — arithmetic XOR, single-level @while
  crc = 4294967295
  i = 0
  n = data_bytes.len()
  @while i < n
    b = data_bytes[i] % 256
    xor_tmp = bit_xor32(crc, b)
    idx = xor_tmp % 256
    crc_hi = crc / 256
    tbl_val = table[idx]
    crc = bit_xor32(crc_hi, tbl_val)
    crc = crc % 4294967296
    i = i + 1
  @end
  return bit_xor32(crc, 4294967295) % 4294967296
@end

@fn net_checksum_rfc1071(data_bytes)
  sum = 0
  i = 0
  num_items = data_bytes.len()
  @while i < num_items
    b0 = data_bytes[i] % 256
    b1 = 0
    @if i + 1 < num_items
      b1 = data_bytes[i + 1] % 256
    @end
    word = (b0 * 256) + b1
    sum = sum + word
    i = i + 2
  @end

  @while (sum / 65536) > 0
    sum = sum % 65536 + (sum / 65536)
  @end

  complement = 65535 - (sum % 65536)
  return complement % 65536
@end

@fn net_checksum_rfc1071_skip(data_bytes, skip_offset)
  sum = 0
  i = 0
  num_items = data_bytes.len()
  @while i < num_items
    @if i == skip_offset
      i = i + 2
    @else
      b0 = data_bytes[i] % 256
      b1 = 0
      @if i + 1 < num_items
        b1 = data_bytes[i + 1] % 256
      @end
      word = (b0 * 256) + b1
      sum = sum + word
      i = i + 2
    @end
  @end

  @while (sum / 65536) > 0
    sum = sum % 65536 + (sum / 65536)
  @end

  complement = 65535 - (sum % 65536)
  return complement % 65536
@end

@fn net_ipv4_checksum(header_bytes)
  return net_checksum_rfc1071(header_bytes)
@end

@fn ipv4_checksum(header_bytes)
  return net_checksum_rfc1071(header_bytes)
@end

@fn net_icmp_checksum(icmp_bytes)
  return net_checksum_rfc1071_skip(icmp_bytes, 2)
@end

@fn icmp_checksum(icmp_bytes)
  return net_checksum_rfc1071_skip(icmp_bytes, 2)
@end

@fn net_udp_checksum(src_ip, dst_ip, udp_bytes)
  udp_len = udp_bytes.len()
  pseudo = []

  @! 1. Source IP (4B)
  pseudo = pseudo.push(src_ip[0] % 256)
  pseudo = pseudo.push(src_ip[1] % 256)
  pseudo = pseudo.push(src_ip[2] % 256)
  pseudo = pseudo.push(src_ip[3] % 256)

  @! 2. Destination IP (4B)
  pseudo = pseudo.push(dst_ip[0] % 256)
  pseudo = pseudo.push(dst_ip[1] % 256)
  pseudo = pseudo.push(dst_ip[2] % 256)
  pseudo = pseudo.push(dst_ip[3] % 256)

  @! 3. Zero (1B) + Protocol (17 = UDP)
  pseudo = pseudo.push(0)
  pseudo = pseudo.push(17)

  @! 4. UDP Length (2B)
  pseudo = pseudo.push((udp_len / 256 % 256))
  pseudo = pseudo.push(udp_len % 256)

  @! 5. UDP Header & Payload (with Checksum at bytes 6-7 zeroed)
  i = 0
  @while i < udp_len
    @if i == 6 || i == 7
      pseudo = pseudo.push(0)
    @else
      pseudo = pseudo.push(udp_bytes[i] % 256)
    @end
    i = i + 1
  @end

  @! 6. Trailing zero byte if odd length
  @if (pseudo.len() % 2) != 0
    pseudo = pseudo.push(0)
  @end

  csum = net_checksum_rfc1071(pseudo)
  @if csum == 0
    return 65535 @! 0xFFFF
  @end
  return csum
@end

@fn udp_checksum(src_ip, dst_ip, udp_bytes)
  return net_udp_checksum(src_ip, dst_ip, udp_bytes)
@end

@fn net_tcp_checksum(src_ip, dst_ip, tcp_bytes)
  tcp_len = tcp_bytes.len()
  pseudo = []

  @! 1. Source IP (4B)
  pseudo = pseudo.push(src_ip[0] % 256)
  pseudo = pseudo.push(src_ip[1] % 256)
  pseudo = pseudo.push(src_ip[2] % 256)
  pseudo = pseudo.push(src_ip[3] % 256)

  @! 2. Destination IP (4B)
  pseudo = pseudo.push(dst_ip[0] % 256)
  pseudo = pseudo.push(dst_ip[1] % 256)
  pseudo = pseudo.push(dst_ip[2] % 256)
  pseudo = pseudo.push(dst_ip[3] % 256)

  @! 3. Zero (1B) + Protocol (6 = TCP)
  pseudo = pseudo.push(0)
  pseudo = pseudo.push(6)

  @! 4. TCP Length (2B)
  pseudo = pseudo.push((tcp_len / 256 % 256))
  pseudo = pseudo.push(tcp_len % 256)

  @! 5. TCP Header & Payload (with Checksum at bytes 16-17 zeroed)
  i = 0
  @while i < tcp_len
    @if i == 16 || i == 17
      pseudo = pseudo.push(0)
    @else
      pseudo = pseudo.push(tcp_bytes[i] % 256)
    @end
    i = i + 1
  @end

  @! 6. Trailing zero byte if odd length
  @if (pseudo.len() % 2) != 0
    pseudo = pseudo.push(0)
  @end

  return net_checksum_rfc1071(pseudo)
@end

@fn tcp_checksum(src_ip, dst_ip, tcp_bytes)
  return net_tcp_checksum(src_ip, dst_ip, tcp_bytes)
@end

@! ============================================================================
@! 6. Layer 2: Ethernet II Framing
@! ============================================================================

@fn ethernet_frame_pack(dst_mac, src_mac, ethertype, payload)
  frame = []

  @! Destination MAC (6 Bytes)
  i = 0
  @while i < 6
    frame = frame.push(dst_mac[i] % 256)
    i = i + 1
  @end

  @! Source MAC (6 Bytes)
  i = 0
  @while i < 6
    frame = frame.push(src_mac[i] % 256)
    i = i + 1
  @end

  @! EtherType (2 Bytes Big Endian)
  frame = frame.push((ethertype / 256 % 256))
  frame = frame.push(ethertype % 256)

  @! Payload
  i = 0
  p_len = payload.len()
  @while i < p_len
    frame = frame.push(payload[i] % 256)
    i = i + 1
  @end

  @! Minimum 46-byte payload padding (60 bytes before FCS)
  @while frame.len() < 60
    frame = frame.push(0)
  @end

  @! Compute IEEE 802.3 CRC-32 FCS
  fcs = net_crc32(frame)

  @! Append FCS (4 Bytes Big Endian)
  frame = frame.push((fcs / 16777216 % 256))
  frame = frame.push((fcs / 65536 % 256))
  frame = frame.push((fcs / 256 % 256))
  frame = frame.push(fcs % 256)

  return frame
@end

@fn raw_eth_frame_serialize(frame_obj)
  return ethernet_frame_pack(frame_obj.dst_mac, frame_obj.src_mac, frame_obj.ethertype, frame_obj.payload)
@end

@fn ethernet_frame_unpack(raw_bytes)
  total_len = raw_bytes.len()
  @if total_len < 14
    return raw_eth_empty()
  @end

  dst = [
    raw_bytes[0] % 256, raw_bytes[1] % 256, raw_bytes[2] % 256,
    raw_bytes[3] % 256, raw_bytes[4] % 256, raw_bytes[5] % 256
  ]
  src = [
    raw_bytes[6] % 256, raw_bytes[7] % 256, raw_bytes[8] % 256,
    raw_bytes[9] % 256, raw_bytes[10] % 256, raw_bytes[11] % 256
  ]
  r12 = raw_bytes[12] % 256
  t12 = r12 * 256
  r13 = raw_bytes[13] % 256
  ethertype = t12 + r13

  @if total_len >= 18
    payload_end = total_len - 4
    payload = []
    i = 14
    @while i < payload_end
      payload = payload.push(raw_bytes[i] % 256)
      i = i + 1
    @end

    v0 = raw_bytes[total_len - 4] % 256
    b0 = v0 * 16777216
    v1 = raw_bytes[total_len - 3] % 256
    b1 = v1 * 65536
    v2 = raw_bytes[total_len - 2] % 256
    b2 = v2 * 256
    b3 = raw_bytes[total_len - 1] % 256
    f01 = b0 + b1
    f23 = b2 + b3
    fcs_val = f01 + f23
    fcs_raw = fcs_val % 4294967296

    frame_body = []
    i = 0
    @while i < payload_end
      frame_body = frame_body.push(raw_bytes[i] % 256)
      i = i + 1
    @end
    computed_fcs = net_crc32(frame_body)
    is_valid = 0
    @if computed_fcs == fcs_raw
      is_valid = 1
    @end

    return {
      dst_mac: dst,
      src_mac: src,
      ethertype: ethertype,
      payload: payload,
      fcs: fcs_raw,
      is_valid: is_valid
    }
  @else
    payload = []
    i = 14
    @while i < total_len
      payload = payload.push(raw_bytes[i] % 256)
      i = i + 1
    @end
    return {
      dst_mac: dst,
      src_mac: src,
      ethertype: ethertype,
      payload: payload,
      fcs: 0,
      is_valid: 1
    }
  @end
@end

@fn raw_eth_frame_parse(raw_bytes)
  return ethernet_frame_unpack(raw_bytes)
@end

@fn raw_eth_prepend_preamble(frame_bytes)
  res = [85, 85, 85, 85, 85, 85, 85, 213]
  i = 0
  num_items = frame_bytes.len()
  @while i < num_items
    res = res.push(frame_bytes[i] % 256)
    i = i + 1
  @end
  return res
@end

@fn raw_eth_strip_preamble(frame_bytes)
  num_items = frame_bytes.len()
  @if num_items < 8 return [] @end
  masked_v = frame_bytes[7] % 256
    @if masked_v != 213 return [] @end
  res = []
  i = 8
  @while i < num_items
    res = res.push(frame_bytes[i] % 256)
    i = i + 1
  @end
  return res
@end

@! ============================================================================
@! 7. RFC 826 Address Resolution Protocol (ARP)
@! ============================================================================

@fn arp_packet_pack(opcode, sender_mac, sender_ip, target_mac, target_ip)
  pkt = []

  @! HTYPE (Ethernet = 1)
  pkt = pkt.push(0)
  pkt = pkt.push(1)

  @! PTYPE (IPv4 = 0x0800)
  pkt = pkt.push(8)
  pkt = pkt.push(0)

  @! HLEN (6) & PLEN (4)
  pkt = pkt.push(6)
  pkt = pkt.push(4)

  @! Opcode (1 = Request, 2 = Reply)
  pkt = pkt.push((opcode / 256 % 256))
  pkt = pkt.push(opcode % 256)

  @! Sender MAC (6 Bytes)
  i = 0
  @while i < 6
    pkt = pkt.push(sender_mac[i] % 256)
    i = i + 1
  @end

  @! Sender IP (4 Bytes)
  i = 0
  @while i < 4
    pkt = pkt.push(sender_ip[i] % 256)
    i = i + 1
  @end

  @! Target MAC (6 Bytes)
  i = 0
  @while i < 6
    pkt = pkt.push(target_mac[i] % 256)
    i = i + 1
  @end

  @! Target IP (4 Bytes)
  i = 0
  @while i < 4
    pkt = pkt.push(target_ip[i] % 256)
    i = i + 1
  @end

  return pkt
@end

@fn arp_packet_unpack(data)
  @if data.len() < 28
    return raw_arp_empty()
  @end

  htype = raw_u16_be(data, 0)
  ptype = raw_u16_be(data, 2)
  hlen  = data[4] % 256
  plen  = data[5] % 256
  op    = raw_u16_be(data, 6)

  s_mac = [data[8] % 256, data[9] % 256, data[10] % 256, data[11] % 256, data[12] % 256, data[13] % 256]
  s_ip  = [data[14] % 256, data[15] % 256, data[16] % 256, data[17] % 256]
  t_mac = [data[18] % 256, data[19] % 256, data[20] % 256, data[21] % 256, data[22] % 256, data[23] % 256]
  t_ip  = [data[24] % 256, data[25] % 256, data[26] % 256, data[27] % 256]

  is_valid = 0
  @if htype == 1 && ptype == 2048 && hlen == 6 && plen == 4 && (op == 1 || op == 2)
    is_valid = 1
  @end

  return {
    htype: htype,
    ptype: ptype,
    hlen: hlen,
    plen: plen,
    opcode: op,
    sender_mac: s_mac,
    sender_ip: s_ip,
    target_mac: t_mac,
    target_ip: t_ip,
    is_valid: is_valid
  }
@end

@fn arp_frame_build_request(sender_mac, sender_ip, target_ip)
  bcast_mac = [255, 255, 255, 255, 255, 255]
  zero_mac  = [0, 0, 0, 0, 0, 0]
  arp_body = arp_packet_pack(1, sender_mac, sender_ip, zero_mac, target_ip)
  return ethernet_frame_pack(bcast_mac, sender_mac, 0x0806, arp_body)
@end

@fn arp_frame_build_reply(sender_mac, sender_ip, target_mac, target_ip)
  arp_body = arp_packet_pack(2, sender_mac, sender_ip, target_mac, target_ip)
  return ethernet_frame_pack(target_mac, sender_mac, 0x0806, arp_body)
@end

@fn arp_table_new()
  return { entries: [], max_entries: 256 }
@end

@fn arp_table_lookup(table, ip_str)
  __entry_idx = 0
  __entry_len = table.entries.len()
  @while __entry_idx < __entry_len
    entry = table.entries[__entry_idx]
    @if entry.ip == ip_str
      return entry.mac
    @end
    __entry_idx = __entry_idx + 1
  @end
  return ""
@end

@fn arp_table_insert(table, ip_str, mac_str)
  new_entries = []
  found = 0
  __entry_idx = 0
  __entry_len = table.entries.len()
  @while __entry_idx < __entry_len
    entry = table.entries[__entry_idx]
    @if entry.ip == ip_str
      new_entries = new_entries.push({ ip: ip_str, mac: mac_str, arp_state: "RESOLVED", ttl: 300 })
      found = 1
    @else
      new_entries = new_entries.push(entry)
    @end
    __entry_idx = __entry_idx + 1
  @end
  @if found == 0
    new_entries = new_entries.push({ ip: ip_str, mac: mac_str, arp_state: "RESOLVED", ttl: 300 })
  @end
  table.entries = new_entries
  return table
@end

@fn arp_table_update(table, ip_str, mac_str)
  return arp_table_insert(table, ip_str, mac_str)
@end

@fn arp_process_frame(table, raw_frame_bytes, local_mac, local_ip)
  eth = ethernet_frame_unpack(raw_frame_bytes)
  @if eth.is_valid == 0 || eth.ethertype != 0x0806 return [] @end

  arp = arp_packet_unpack(eth.payload)
  @if arp.is_valid == 0 return [] @end

  s_ip_str = ipv4_format(arp.sender_ip)
  s_mac_str = mac_format(arp.sender_mac)
  table = arp_table_update(table, s_ip_str, s_mac_str)

  @if arp.opcode == 1 && ipv4_equals(arp.target_ip, local_ip) == 1
    return arp_frame_build_reply(local_mac, local_ip, arp.sender_mac, arp.sender_ip)
  @end

  return []
@end

@fn arp_handle_packet(table, raw_frame_bytes, local_mac, local_ip)
  return arp_process_frame(table, raw_frame_bytes, local_mac, local_ip)
@end

@! ============================================================================
@! 8. RFC 791 IPv4 Packet Framing
@! ============================================================================

@fn raw_ipv4_serialize(pkt)
  header_words = 5
  @if pkt.options.len() > 0
    opt_words = (pkt.options.len() + 3) / 4
    header_words = 5 + opt_words
  @end
  ihl = header_words
  header_len = ihl * 4
  payload_len = pkt.payload.len()
  total_len = header_len + payload_len

  @! Build header_pre: bytes 0-9 (before checksum)
  t_ihl = ihl % 16
  t_ver = 64 + t_ihl
  flags_frag = (pkt.flags % 8) * 8192 + pkt.frag_offset % 8192

  header_pre = []
  header_pre = header_pre.push(t_ver % 256)
  header_pre = header_pre.push(pkt.dscp % 256)
  header_pre = header_pre.push((total_len / 256) % 256)
  header_pre = header_pre.push(total_len % 256)
  header_pre = header_pre.push((pkt.id / 256) % 256)
  header_pre = header_pre.push(pkt.id % 256)
  header_pre = header_pre.push((flags_frag / 256) % 256)
  header_pre = header_pre.push(flags_frag % 256)
  header_pre = header_pre.push(pkt.ttl % 256)
  header_pre = header_pre.push(pkt.protocol % 256)
  @! Bytes 10-11: placeholder 0 for checksum
  header_pre = header_pre.push(0)
  header_pre = header_pre.push(0)
  header_pre = header_pre.push((pkt.src_ip[0]) % 256)
  header_pre = header_pre.push((pkt.src_ip[1]) % 256)
  header_pre = header_pre.push((pkt.src_ip[2]) % 256)
  header_pre = header_pre.push((pkt.src_ip[3]) % 256)
  header_pre = header_pre.push((pkt.dst_ip[0]) % 256)
  header_pre = header_pre.push((pkt.dst_ip[1]) % 256)
  header_pre = header_pre.push((pkt.dst_ip[2]) % 256)
  header_pre = header_pre.push((pkt.dst_ip[3]) % 256)

  @! Options & Padding
  i = 0
  @while i < pkt.options.len()
    header_pre = header_pre.push((pkt.options[i]) % 256)
    i = i + 1
  @end
  @while header_pre.len() < header_len
    header_pre = header_pre.push(0)
  @end

  @! Compute checksum over header with zero checksum field
  csum = net_checksum_rfc1071(header_pre)
  csum_hi = (csum / 256) % 256
  csum_lo = csum % 256

  @! Rebuild final header with real checksum at bytes 10-11
  bytes = []
  j = 0
  @while j < header_pre.len()
    @if j == 10
      bytes = bytes.push(csum_hi)
    @else
      @if j == 11
        bytes = bytes.push(csum_lo)
      @else
        bytes = bytes.push(header_pre[j])
      @end
    @end
    j = j + 1
  @end

  @! Append Payload
  i = 0
  @while i < payload_len
    bytes = bytes.push((pkt.payload[i]) % 256)
    i = i + 1
  @end

  return bytes
@end

@fn raw_ipv4_parse(raw_bytes)
  num_items = raw_bytes.len()
  @if num_items < 20
    return raw_ipv4_empty()
  @end

  v_ihl = raw_bytes[0] % 256
  version = ((v_ihl / 16)) % 16
  ihl = v_ihl % 16
  header_len = ihl * 4

  @if version != 4 || ihl < 5 || num_items < header_len
    return raw_ipv4_empty()
  @end

  dscp = raw_bytes[1] % 256
  total_len = raw_u16_be(raw_bytes, 2)
  id = raw_u16_be(raw_bytes, 4)

  flags_frag = raw_u16_be(raw_bytes, 6)
  flags = (flags_frag / 8192) % 8
  frag_offset = flags_frag % 8192

  ttl = raw_bytes[8] % 256
  protocol = raw_bytes[9] % 256
  checksum = raw_u16_be(raw_bytes, 10)

  src_ip = [
    raw_bytes[12] % 256,
    raw_bytes[13] % 256,
    raw_bytes[14] % 256,
    raw_bytes[15] % 256
  ]
  dst_ip = [
    raw_bytes[16] % 256,
    raw_bytes[17] % 256,
    raw_bytes[18] % 256,
    raw_bytes[19] % 256
  ]

  @! Verify Header Checksum
  header_slice = []
  i = 0
  @while i < header_len
    header_slice = header_slice.push(raw_bytes[i] % 256)
    i = i + 1
  @end
  computed_csum = net_checksum_rfc1071_skip(header_slice, 10)
  @if computed_csum != checksum
    return raw_ipv4_empty()
  @end

  options = []
  @if header_len > 20
    k = 20
    @while k < header_len
      options = options.push(raw_bytes[k] % 256)
      k = k + 1
    @end
  @end

  end_idx = total_len
  @if end_idx > num_items || end_idx == 0
    end_idx = num_items
  @end

  payload = []
  k = header_len
  @while k < end_idx
    payload = payload.push(raw_bytes[k] % 256)
    k = k + 1
  @end

  return {
    version: version,
    ihl: ihl,
    dscp: dscp,
    total_len: total_len,
    id: id,
    flags: flags,
    frag_offset: frag_offset,
    ttl: ttl,
    protocol: protocol,
    checksum: checksum,
    src_ip: src_ip,
    dst_ip: dst_ip,
    options: options,
    payload: payload,
    is_valid: 1
  }
@end

@fn ipv4_packet_pack(src_ip, dst_ip, protocol, payload)
  pkt = {
    version: 4,
    ihl: 5,
    dscp: 0,
    total_len: 20 + payload.len(),
    id: 1,
    flags: 2, @! DF = 1
    frag_offset: 0,
    ttl: 64,
    protocol: protocol,
    checksum: 0,
    src_ip: src_ip,
    dst_ip: dst_ip,
    options: [],
    payload: payload,
    is_valid: 1
  }
  return raw_ipv4_serialize(pkt)
@end

@fn ipv4_packet_unpack(raw_bytes)
  return raw_ipv4_parse(raw_bytes)
@end

@fn raw_ipv4_packet_build(src_ip_str, dst_ip_str, protocol, payload)
  s_ip = string_to_ip(src_ip_str)
  d_ip = string_to_ip(dst_ip_str)
  return ipv4_packet_pack(s_ip, d_ip, protocol, payload)
@end

@! ============================================================================
@! 9. RFC 792 ICMP Packet Framing
@! ============================================================================

@fn raw_icmp_serialize(pkt)
  @! Phase 1: build with placeholder checksum
  pre = []
  pre = pre.push(pkt.icmp_type % 256)
  pre = pre.push(pkt.code % 256)
  pre = pre.push(0)
  pre = pre.push(0)
  pre = pre.push((pkt.ident / 256) % 256)
  pre = pre.push(pkt.ident % 256)
  pre = pre.push((pkt.seq / 256) % 256)
  pre = pre.push(pkt.seq % 256)
  i = 0
  p_len = pkt.payload.len()
  @while i < p_len
    pre = pre.push((pkt.payload[i]) % 256)
    i = i + 1
  @end
  @! Phase 2: compute checksum, rebuild with it at bytes 2-3
  csum = net_checksum_rfc1071(pre)
  csum_hi = (csum / 256) % 256
  csum_lo = csum % 256
  bytes = []
  j = 0
  @while j < pre.len()
    @if j == 2
      bytes = bytes.push(csum_hi)
    @else
      @if j == 3
        bytes = bytes.push(csum_lo)
      @else
        bytes = bytes.push(pre[j])
      @end
    @end
    j = j + 1
  @end
  return bytes
@end

@fn raw_icmp_parse(raw_bytes)
  num_items = raw_bytes.len()
  @if num_items < 8
    return raw_icmp_empty()
  @end

  type_val = raw_bytes[0] % 256
  code_val = raw_bytes[1] % 256
  checksum = raw_u16_be(raw_bytes, 2)
  ident = raw_u16_be(raw_bytes, 4)
  seq = raw_u16_be(raw_bytes, 6)

  computed_csum = net_checksum_rfc1071_skip(raw_bytes, 2)
  @if computed_csum != checksum
    return raw_icmp_empty()
  @end

  payload = []
  i = 8
  @while i < num_items
    payload = payload.push(raw_bytes[i] % 256)
    i = i + 1
  @end

  return {
    icmp_type: type_val,
    code: code_val,
    checksum: checksum,
    ident: ident,
    seq: seq,
    payload: payload,
    is_valid: 1
  }
@end

@fn icmp_packet_pack(icmp_type, code, ident, seq, payload)
  pkt = {
    icmp_type: icmp_type,
    code: code,
    checksum: 0,
    ident: ident,
    seq: seq,
    payload: payload,
    is_valid: 1
  }
  return raw_icmp_serialize(pkt)
@end

@fn icmp_packet_unpack(raw_bytes)
  return raw_icmp_parse(raw_bytes)
@end

@fn raw_icmp_echo_request_build(ident, seq, payload)
  return icmp_packet_pack(8, 0, ident, seq, payload)
@end

@fn icmp_echo_request(ident, seq, payload)
  return raw_icmp_echo_request_build(ident, seq, payload)
@end

@fn raw_icmp_echo_reply_build(ident, seq, payload)
  return icmp_packet_pack(0, 0, ident, seq, payload)
@end

@fn icmp_echo_reply(ident, seq, payload)
  return raw_icmp_echo_reply_build(ident, seq, payload)
@end

@! ============================================================================
@! 10. RFC 768 UDP Datagram Framing
@! ============================================================================

@fn raw_udp_serialize(seg, src_ip, dst_ip)
  udp_len = 8 + seg.payload.len()
  pre = []
  pre = pre.push((seg.src_port / 256) % 256)
  pre = pre.push(seg.src_port % 256)
  pre = pre.push((seg.dst_port / 256) % 256)
  pre = pre.push(seg.dst_port % 256)
  pre = pre.push((udp_len / 256) % 256)
  pre = pre.push(udp_len % 256)
  pre = pre.push(0)
  pre = pre.push(0)
  i = 0
  p_len = seg.payload.len()
  @while i < p_len
    pre = pre.push((seg.payload[i]) % 256)
    i = i + 1
  @end
  csum = net_udp_checksum(src_ip, dst_ip, pre)
  csum_hi = (csum / 256) % 256
  csum_lo = csum % 256
  bytes = []
  j = 0
  @while j < pre.len()
    @if j == 6
      bytes = bytes.push(csum_hi)
    @else
      @if j == 7
        bytes = bytes.push(csum_lo)
      @else
        bytes = bytes.push(pre[j])
      @end
    @end
    j = j + 1
  @end
  return bytes
@end

@fn raw_udp_parse(raw_bytes, src_ip, dst_ip)
  num_items = raw_bytes.len()
  @if num_items < 8
    return raw_udp_empty()
  @end

  src_port = raw_u16_be(raw_bytes, 0)
  dst_port = raw_u16_be(raw_bytes, 2)
  length = raw_u16_be(raw_bytes, 4)
  checksum = raw_u16_be(raw_bytes, 6)

  @if length < 8 || length > num_items
    return raw_udp_empty()
  @end

  @if checksum != 0 && src_ip.len() == 4 && dst_ip.len() == 4
    computed_csum = net_udp_checksum(src_ip, dst_ip, raw_bytes)
    @if computed_csum != checksum
      return raw_udp_empty()
    @end
  @end

  payload = []
  i = 8
  @while i < length
    payload = payload.push(raw_bytes[i] % 256)
    i = i + 1
  @end

  return {
    src_port: src_port,
    dst_port: dst_port,
    udp_len: length,
    checksum: checksum,
    payload: payload,
    is_valid: 1
  }
@end

@fn udp_packet_pack(src_port, dst_port, payload, src_ip, dst_ip)
  seg = {
    src_port: src_port,
    dst_port: dst_port,
    udp_len: 8 + payload.len(),
    checksum: 0,
    payload: payload,
    is_valid: 1
  }
  return raw_udp_serialize(seg, src_ip, dst_ip)
@end

@fn udp_packet_unpack(raw_bytes, src_ip, dst_ip)
  return raw_udp_parse(raw_bytes, src_ip, dst_ip)
@end

@fn raw_udp_packet_build(src_ip_str, dst_ip_str, src_port, dst_port, payload)
  src_ip = string_to_ip(src_ip_str)
  dst_ip = string_to_ip(dst_ip_str)
  seg = {
    src_port: src_port,
    dst_port: dst_port,
    udp_len: 8 + payload.len(),
    checksum: 0,
    payload: payload,
    is_valid: 1
  }
  udp_raw = raw_udp_serialize(seg, src_ip, dst_ip)
  return raw_ipv4_packet_build(src_ip_str, dst_ip_str, 17, udp_raw)
@end

@! ============================================================================
@! 11. RFC 793 TCP Segment Framing & Checksum
@! ============================================================================

@fn TCP_FLAG_FIN() return 1 @end   @! 0x01: Finish / close connection
@fn TCP_FLAG_SYN() return 2 @end   @! 0x02: Synchronize sequence numbers
@fn TCP_FLAG_RST() return 4 @end   @! 0x04: Reset connection
@fn TCP_FLAG_PSH() return 8 @end   @! 0x08: Push data to application
@fn TCP_FLAG_ACK() return 16 @end  @! 0x10: Acknowledgment field valid
@fn TCP_FLAG_URG() return 32 @end  @! 0x20: Urgent pointer field valid
@fn TCP_FLAG_ECE() return 64 @end  @! 0x40: ECN Echo
@fn TCP_FLAG_CWR() return 128 @end @! 0x80: Congestion Window Reduced

@fn tcp_seq_add(seq, delta)
  return (seq + delta) % 4294967296
@end

@fn tcp_seq_diff(seq_a, seq_b)
  @if seq_a >= seq_b
    diff = seq_a - seq_b
    @if diff > 2147483647
      return diff - 4294967296
    @end
    return diff
  @else
    diff = 4294967296 - seq_b + seq_a
    @if diff > 2147483647
      return diff - 4294967296
    @end
    return diff
  @end
@end

@fn tcp_seq_gte(seq_a, seq_b)
  return tcp_seq_diff(seq_a, seq_b) >= 0
@end

@fn raw_tcp_serialize(seg, src_ip, dst_ip)
  data_off = seg.data_offset
  @if data_off < 5 data_off = 5 @end
  header_len = data_off * 4

  pre = []
  pre = pre.push((seg.src_port / 256) % 256)
  pre = pre.push(seg.src_port % 256)
  pre = pre.push((seg.dst_port / 256) % 256)
  pre = pre.push(seg.dst_port % 256)
  pre = pre.push((seg.seq_num / 16777216) % 256)
  pre = pre.push((seg.seq_num / 65536) % 256)
  pre = pre.push((seg.seq_num / 256) % 256)
  pre = pre.push(seg.seq_num % 256)
  pre = pre.push((seg.ack_num / 16777216) % 256)
  pre = pre.push((seg.ack_num / 65536) % 256)
  pre = pre.push((seg.ack_num / 256) % 256)
  pre = pre.push(seg.ack_num % 256)
  pre = pre.push((data_off % 16) * 16)
  pre = pre.push(seg.flags % 256)
  pre = pre.push((seg.window_size / 256) % 256)
  pre = pre.push(seg.window_size % 256)
  pre = pre.push(0)
  pre = pre.push(0)
  pre = pre.push((seg.urgent_ptr / 256) % 256)
  pre = pre.push(seg.urgent_ptr % 256)
  @while pre.len() < header_len
    pre = pre.push(0)
  @end
  i = 0
  p_len = seg.payload.len()
  @while i < p_len
    pre = pre.push((seg.payload[i]) % 256)
    i = i + 1
  @end
  csum = net_tcp_checksum(src_ip, dst_ip, pre)
  csum_hi = (csum / 256) % 256
  csum_lo = csum % 256
  bytes = []
  j = 0
  @while j < pre.len()
    @if j == 16
      bytes = bytes.push(csum_hi)
    @else
      @if j == 17
        bytes = bytes.push(csum_lo)
      @else
        bytes = bytes.push(pre[j])
      @end
    @end
    j = j + 1
  @end
  return bytes
@end

@fn raw_tcp_parse(raw_bytes, src_ip, dst_ip)
  num_items = raw_bytes.len()
  @if num_items < 20
    return raw_tcp_empty()
  @end

  src_port = raw_u16_be(raw_bytes, 0)
  dst_port = raw_u16_be(raw_bytes, 2)

  seq_num = raw_u32_be(raw_bytes, 4)

  ack_num = raw_u32_be(raw_bytes, 8)

  data_offset = (raw_bytes[12] / 16) % 16
  header_len = data_offset * 4

  @if data_offset < 5 || num_items < header_len
    return raw_tcp_empty()
  @end

  flags = raw_bytes[13] % 256
  window_size = raw_u16_be(raw_bytes, 14)
  checksum = raw_u16_be(raw_bytes, 16)
  urgent_ptr = raw_u16_be(raw_bytes, 18)

  @if src_ip.len() == 4 && dst_ip.len() == 4
    computed_csum = net_tcp_checksum(src_ip, dst_ip, raw_bytes)
    @if computed_csum != checksum
      return raw_tcp_empty()
    @end
  @end

  payload = []
  i = header_len
  @while i < num_items
    payload = payload.push(raw_bytes[i] % 256)
    i = i + 1
  @end

  return {
    src_port: src_port,
    dst_port: dst_port,
    seq_num: seq_num,
    ack_num: ack_num,
    data_offset: data_offset,
    flags: flags,
    window_size: window_size,
    checksum: checksum,
    urgent_ptr: urgent_ptr,
    payload: payload,
    is_valid: 1
  }
@end

@fn tcp_packet_pack(src_port, dst_port, seq_num, ack_num, flags, window_size, payload, src_ip, dst_ip)
  seg = {
    src_port: src_port,
    dst_port: dst_port,
    seq_num: seq_num,
    ack_num: ack_num,
    data_offset: 5,
    flags: flags,
    window_size: window_size,
    checksum: 0,
    urgent_ptr: 0,
    payload: payload,
    is_valid: 1
  }
  return raw_tcp_serialize(seg, src_ip, dst_ip)
@end

@fn tcp_packet_unpack(raw_bytes, src_ip, dst_ip)
  return raw_tcp_parse(raw_bytes, src_ip, dst_ip)
@end

@fn raw_tcp_segment_build(src_port, dst_port, seq_num, ack_num, flags, window_size, payload, src_ip, dst_ip)
  return tcp_packet_pack(src_port, dst_port, seq_num, ack_num, flags, window_size, payload, src_ip, dst_ip)
@end

@! ============================================================================
@! 12. TCP Connection State Machine (RFC 793)
@! ============================================================================

@fn TCP_STATE_CLOSED() return 0 @end
@fn TCP_STATE_LISTEN() return 1 @end
@fn TCP_STATE_SYN_SENT() return 2 @end
@fn TCP_STATE_SYN_RECEIVED() return 3 @end
@fn TCP_STATE_ESTABLISHED() return 4 @end
@fn TCP_STATE_FIN_WAIT_1() return 5 @end
@fn TCP_STATE_FIN_WAIT_2() return 6 @end
@fn TCP_STATE_CLOSE_WAIT() return 7 @end
@fn TCP_STATE_CLOSING() return 8 @end
@fn TCP_STATE_LAST_ACK() return 9 @end
@fn TCP_STATE_TIME_WAIT() return 10 @end

@fn tcp_endpoint_new(id, local_ip, local_port)
  return {
    ep_id: id,
    tcp_state: 0,
    local_ip: local_ip,
    local_port: local_port,
    remote_ip: [0, 0, 0, 0],
    remote_port: 0,
    seq_num: 0,
    ack_num: 0,
    recv_buf: [],
    outbox: [],
    is_valid: 1
  }
@end

@fn tcp_endpoint_listen(ep)
  ep.tcp_state = 1
  return ep
@end

@fn tcp_endpoint_connect(ep, remote_ip, remote_port, isn)
  ep.remote_ip = remote_ip
  ep.remote_port = remote_port
  ep.seq_num = isn
  ep.ack_num = 0
  ep.tcp_state = 2

  @! Emit SYN packet
  syn_seg = {
    src_port: ep.local_port,
    dst_port: remote_port,
    seq_num: isn,
    ack_num: 0,
    data_offset: 5,
    flags: 2,
    window_size: 64240,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  raw_bytes = raw_tcp_serialize(syn_seg, ep.local_ip, remote_ip)
  ep.outbox = ep.outbox.push(raw_bytes)
  return ep
@end

@fn tcp_endpoint_send_data(ep, data_bytes)
  @if ep.tcp_state != 4
    return ep
  @end

  seg = {
    src_port: ep.local_port,
    dst_port: ep.remote_port,
    seq_num: ep.seq_num,
    ack_num: ep.ack_num,
    data_offset: 5,
    flags: 24,
    window_size: 64240,
    checksum: 0,
    urgent_ptr: 0,
    payload: data_bytes,
    is_valid: 1
  }
  raw_bytes = raw_tcp_serialize(seg, ep.local_ip, ep.remote_ip)
  ep.outbox = ep.outbox.push(raw_bytes)
  ep.seq_num = tcp_seq_add(ep.seq_num, data_bytes.len())
  return ep
@end

@fn tcp_endpoint_close(ep)
  @if ep.tcp_state == 4
    ep.tcp_state = 5
    seg = {
      src_port: ep.local_port,
      dst_port: ep.remote_port,
      seq_num: ep.seq_num,
      ack_num: ep.ack_num,
      data_offset: 5,
      flags: 17,
      window_size: 64240,
      checksum: 0,
      urgent_ptr: 0,
      payload: [],
      is_valid: 1
    }
    raw_bytes = raw_tcp_serialize(seg, ep.local_ip, ep.remote_ip)
    ep.outbox = ep.outbox.push(raw_bytes)
    ep.seq_num = tcp_seq_add(ep.seq_num, 1)
  @elif ep.tcp_state == 7
    ep.tcp_state = 9
    seg = {
      src_port: ep.local_port,
      dst_port: ep.remote_port,
      seq_num: ep.seq_num,
      ack_num: ep.ack_num,
      data_offset: 5,
      flags: 17,
      window_size: 64240,
      checksum: 0,
      urgent_ptr: 0,
      payload: [],
      is_valid: 1
    }
    raw_bytes = raw_tcp_serialize(seg, ep.local_ip, ep.remote_ip)
    ep.outbox = ep.outbox.push(raw_bytes)
    ep.seq_num = tcp_seq_add(ep.seq_num, 1)
  @end
  return ep
@end

@fn tcp_endpoint_process_packet(ep, raw_tcp_bytes, sender_ip)
  seg = raw_tcp_parse(raw_tcp_bytes, sender_ip, ep.local_ip)
  @if seg.is_valid == 0
    return ep
  @end

  cur_state = ep.tcp_state
  flags = seg.flags

  @! 1. State: LISTEN (1)
  @if cur_state == 1
    @if ((flags / 2) % 2 * 2) != 0
      ep.remote_ip = sender_ip
      ep.remote_port = seg.src_port
      ep.ack_num = tcp_seq_add(seg.seq_num, 1)
      ep.seq_num = 5000
      ep.tcp_state = 3

      syn_ack = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 18,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(syn_ack, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
      ep.seq_num = tcp_seq_add(ep.seq_num, 1)
    @end
    return ep
  @end

  @! 2. State: SYN_SENT (2)
  @if cur_state == 2
    f_a = ((flags / 2) % 2 * 2)
    f_b = ((flags / 16) % 2 * 16)
    @if f_a != 0 && f_b != 0
      ep.ack_num = tcp_seq_add(seg.seq_num, 1)
      ep.seq_num = tcp_seq_add(ep.seq_num, 1)
      ep.tcp_state = 4

      ack_seg = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 16,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(ack_seg, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
    @end
    return ep
  @end

  @! 3. State: SYN_RECEIVED (3)
  @if cur_state == 3
    @if ((flags / 16) % 2 * 16) != 0
      ep.tcp_state = 4
    @end
    return ep
  @end

  @! 4. State: ESTABLISHED (4)
  @if cur_state == 4
    @if flags % 2 != 0
      ep.ack_num = tcp_seq_add(seg.seq_num, 1)
      ep.tcp_state = 7

      ack_seg = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 16,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(ack_seg, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
    @elif seg.payload.len() > 0
      i = 0
      p_len = seg.payload.len()
      @while i < p_len
        ep.recv_buf = ep.recv_buf.push((seg.payload[i]) % 256)
        i = i + 1
      @end
      ep.ack_num = tcp_seq_add(seg.seq_num, seg.payload.len())

      ack_seg = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 16,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(ack_seg, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
    @end
    return ep
  @end

  @! 5. State: FIN_WAIT_1 (5)
  @if cur_state == 5
    f_a = flags % 2
    f_b = ((flags / 16) % 2 * 16)
    @if f_a != 0 && f_b != 0
      ep.ack_num = tcp_seq_add(seg.seq_num, 1)
      ep.tcp_state = 10
      ack_seg = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 16,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(ack_seg, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
    @elif ((flags / 16) % 2 * 16) != 0
      ep.tcp_state = 6
    @end
    return ep
  @end

  @! 6. State: FIN_WAIT_2 (6)
  @if cur_state == 6
    @if flags % 2 != 0
      ep.ack_num = tcp_seq_add(seg.seq_num, 1)
      ep.tcp_state = 10
      ack_seg = {
        src_port: ep.local_port,
        dst_port: seg.src_port,
        seq_num: ep.seq_num,
        ack_num: ep.ack_num,
        data_offset: 5,
        flags: 16,
        window_size: 64240,
        checksum: 0,
        urgent_ptr: 0,
        payload: [],
        is_valid: 1
      }
      out_bytes = raw_tcp_serialize(ack_seg, ep.local_ip, sender_ip)
      ep.outbox = ep.outbox.push(out_bytes)
    @end
    return ep
  @end

  @! 7. State: LAST_ACK (9)
  @if cur_state == 9
    @if ((flags / 16) % 2 * 16) != 0
      ep.tcp_state = 0
    @end
    return ep
  @end

  return ep
@end

@fn tcp_connection_new(client_id, server_id)
  return {
    client_id: client_id,
    server_id: server_id,
    is_connected: 0
  }
@end

@! ============================================================================
@! 13. In-Memory Virtual Network Hub & Interface Simulation
@! ============================================================================

@fn vnet_iface_new(id, mac_addr, ip_addr)
  return {
    iface_id: id,
    mac_addr: mac_addr,
    ip_addr: ip_addr,
    inbox: [],
    outbox: []
  }
@end

@fn vnet_iface_from_str(id, mac_str, ip_str)
  m_bytes = string_to_mac(mac_str)
  i_bytes = string_to_ip(ip_str)
  return vnet_iface_new(id, m_bytes, i_bytes)
@end

@fn vnet_hub_new()
  return {
    interfaces: [],
    buffer_queue: [],
    packet_count: 0
  }
@end

@fn vnet_hub_add_interface(hub, iface)
  hub.interfaces = hub.interfaces.push(iface)
  return hub
@end

@fn vnet_add_interface(hub, iface)
  return vnet_hub_add_interface(hub, iface)
@end

@fn vnet_send_packet(hub, frame_bytes)
  hub.buffer_queue = hub.buffer_queue.push(frame_bytes)
  hub.packet_count = hub.packet_count + 1
  return hub
@end

@fn vnet_recv_packet(hub)
  @if hub.buffer_queue.len() == 0
    return []
  @end
  pkt = hub.buffer_queue[0]
  new_queue = []
  i = 1
  num_items = hub.buffer_queue.len()
  @while i < num_items
    new_queue = new_queue.push(hub.buffer_queue[i])
    i = i + 1
  @end
  hub.buffer_queue = new_queue
  return pkt
@end

@fn vnet_iface_send_raw(iface, frame_bytes)
  iface.outbox = iface.outbox.push(frame_bytes)
  return iface
@end

@fn vnet_iface_poll_packet(iface)
  @if iface.inbox.len() == 0
    return []
  @end
  pkt = iface.inbox[0]
  new_inbox = []
  i = 1
  num_items = iface.inbox.len()
  @while i < num_items
    new_inbox = new_inbox.push(iface.inbox[i])
    i = i + 1
  @end
  iface.inbox = new_inbox
  return pkt
@end

@fn vnet_iface_clone_outbox(iface, new_outbox)
  return {
    iface_id: iface.iface_id,
    mac_addr: iface.mac_addr,
    ip_addr: iface.ip_addr,
    inbox: iface.inbox,
    outbox: new_outbox
  }
@end

@fn vnet_iface_clone_inbox(iface, new_inbox)
  return {
    iface_id: iface.iface_id,
    mac_addr: iface.mac_addr,
    ip_addr: iface.ip_addr,
    inbox: new_inbox,
    outbox: iface.outbox
  }
@end

@fn vnet_hub_set_iface(hub, target_idx, new_iface)
  new_ifaces = []
  i = 0
  n = hub.interfaces.len()
  @while i < n
    @if i == target_idx
      new_ifaces = new_ifaces.push(new_iface)
    @else
      new_ifaces = new_ifaces.push(hub.interfaces[i])
    @end
    i = i + 1
  @end
  hub.interfaces = new_ifaces
  return hub
@end

@fn vnet_hub_send_from(hub, src_idx, frame)
  src_iface = hub.interfaces[src_idx]
  new_outbox = src_iface.outbox.push(frame)
  new_iface = vnet_iface_clone_outbox(src_iface, new_outbox)
  return vnet_hub_set_iface(hub, src_idx, new_iface)
@end

@fn vnet_hub_deliver_frame(hub, frame)
  @if frame.len() < 14
    return hub
  @end
  d0 = frame[0] % 256
  d1 = frame[1] % 256
  d2 = frame[2] % 256
  d3 = frame[3] % 256
  d4 = frame[4] % 256
  d5 = frame[5] % 256
  dst_mac = [d0, d1, d2, d3, d4, d5]
  is_bcast = mac_is_broadcast(dst_mac)
  new_ifaces = []
  j = 0
  n = hub.interfaces.len()
  @while j < n
    target = hub.interfaces[j]
    should_recv = 0
    @if is_bcast == 1
      should_recv = 1
    @else
      @if mac_equals(target.mac_addr, dst_mac) == 1
        should_recv = 1
      @end
    @end
    @if should_recv == 1
      new_inbox = target.inbox.push(frame)
      new_ifaces = new_ifaces.push(vnet_iface_clone_inbox(target, new_inbox))
    @else
      new_ifaces = new_ifaces.push(target)
    @end
    j = j + 1
  @end
  hub.interfaces = new_ifaces
  return hub
@end

@fn vnet_hub_step(hub)
  all_frames = []
  empty_ob = []
  cleared_ifaces = []
  i = 0
  n = hub.interfaces.len()
  @while i < n
    iface = hub.interfaces[i]
    k = 0
    k_len = iface.outbox.len()
    @while k < k_len
      all_frames = all_frames.push(iface.outbox[k])
      k = k + 1
    @end
    cleared = vnet_iface_clone_outbox(iface, empty_ob)
    cleared_ifaces = cleared_ifaces.push(cleared)
    i = i + 1
  @end
  hub.interfaces = cleared_ifaces
  fi = 0
  f_len = all_frames.len()
  @while fi < f_len
    hub = vnet_hub_deliver_frame(hub, all_frames[fi])
    hub.packet_count = hub.packet_count + 1
    fi = fi + 1
  @end
  return hub
@end

