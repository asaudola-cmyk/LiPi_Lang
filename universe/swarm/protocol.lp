@! ============================================================================
@! MAYA SWARM — P2P BINARY & WIRE PROTOCOL CODEC (universe/swarm/protocol.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! ============================================================================

import "universe/net/tcp"
import "universe/net/udp"
import "universe/core/string"
import "universe/core/collections"
import "universe/swarm/types"

@fn net_u16_be(buf, off)
  b0 = buf[off] & 255
  t0 = b0 * 256
  b1 = buf[off + 1] & 255
  res = t0 | b1
  return res & 65535
@end

@fn net_u32_be(buf, off)
  b0 = buf[off] & 255
  w0 = b0 * 16777216
  b1 = buf[off + 1] & 255
  w1 = b1 * 65536
  b2 = buf[off + 2] & 255
  w2 = b2 * 256
  b3 = buf[off + 3] & 255
  r01 = w0 | w1
  r23 = w2 | b3
  res = r01 | r23
  return res & 4294967295
@end

@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@fn SWARM_MAGIC() return 21335 @end        @! 0x5357 = "SW"
@fn SWARM_VERSION() return 1 @end

@fn MSG_BEACON() return 1 @end
@fn MSG_HANDSHAKE() return 2 @end
@fn MSG_HEARTBEAT() return 3 @end
@fn MSG_TASK_SUBMIT() return 4 @end
@fn MSG_TASK_RESULT() return 5 @end
@fn MSG_ACTOR_CAST() return 6 @end
@fn MSG_ACTOR_CALL() return 7 @end
@fn MSG_ACTOR_REPLY() return 8 @end
@fn MSG_GOSSIP_REQ() return 9 @end
@fn MSG_GOSSIP_RESP() return 10 @end
@fn MSG_HEARTBEAT_ACK() return 11 @end
@fn MSG_HANDSHAKE_ACK() return 12 @end

@fn crc32_update(crc, byte_val)
  t_c = crc ^ byte_val
  c = t_c & 255
  j = 0
  @while j < 8
    c_low = c & 1
    @if c_low != 0
      d_c = c / 2
      c = d_c ^ 3988292384
    @else
      c = c / 2
    @end
    j = j + 1
  @end
  d_crc = crc / 256
  return d_crc ^ c
@end

@fn compute_crc32(str_val)
  crc = 4294967295
  i = 0
  num_items = str_len(str_val)
  @while i < num_items
    ch = str_char_at(str_val, i)
    ch_m = ch & 255
    crc = crc32_update(crc, ch_m)
    i = i + 1
  @end
  t_res = crc ^ 4294967295
  return t_res & 4294967295
@end

@fn compute_crc32_bytes(bytes_arr)
  crc = 4294967295
  i = 0
  num_items = bytes_arr.len()
  @while i < num_items
    b_m = bytes_arr[i] & 255
    crc = crc32_update(crc, b_m)
    i = i + 1
  @end
  t_res = crc ^ 4294967295
  return t_res & 4294967295
@end

@fn proto_hex_digit(v)
  v_low = v & 15
  @if v_low < 10 return str_from_char_code(48 + v_low) @end
  return str_from_char_code(65 + (v_low - 10))
@end

@fn proto_hex_val(ch)
  @if ch >= 48 && ch <= 57 return ch - 48 @end
  @if ch >= 65 && ch <= 70 return ch - 65 + 10 @end
  @if ch >= 97 && ch <= 102 return ch - 97 + 10 @end
  return 0
@end

@fn proto_int_to_hex8(val)
  res = ""
  i = 7
  @while i >= 0
    shift = i * 4
    p = maya_pow2(shift)
    d = val / p
    nibble = d & 15
    res = string_concat(res, proto_hex_digit(nibble))
    i = i - 1
  @end
  return res
@end

@fn proto_int_to_hex2(val)
  d1 = val / 16
  n1 = d1 & 15
  n0 = val & 15
  return string_concat(proto_hex_digit(n1), proto_hex_digit(n0))
@end

@fn proto_hex_to_int(hex_str, start, num_items)
  val = 0
  i = 0
  @while i < num_items
    ch = str_char_at(hex_str, start + i)
    t0 = val * 16
    val = t0 | proto_hex_val(ch)
    i = i + 1
  @end
  return val
@end

@fn protocol_encode_bytes(msg_type, payload_str)
  crc = compute_crc32(payload_str)
  plen = str_len(payload_str)

  buf = [83, 87, 1]
  b3 = msg_type & 255
  buf = buf.push(b3)
  b4 = (plen / 16777216) & 255
  buf = buf.push(b4)
  b5 = (plen / 65536) & 255
  buf = buf.push(b5)
  b6 = (plen / 256) & 255
  buf = buf.push(b6)
  b7 = plen & 255
  buf = buf.push(b7)

  b8 = (crc / 16777216) & 255
  buf = buf.push(b8)
  b9 = (crc / 65536) & 255
  buf = buf.push(b9)
  b10 = (crc / 256) & 255
  buf = buf.push(b10)
  b11 = crc & 255
  buf = buf.push(b11)

  i = 0
  @while i < plen
    ch_c = str_char_at(payload_str, i)
    buf = buf.push(ch_c)
    i = i + 1
  @end

  return buf
@end

@fn protocol_decode_bytes(buf)
  @if buf.len() < 12
    return {
      valid: 0,
      reason: "Buffer too small for header (< 12 bytes)",
      magic: 0,
      version: 0,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  m0 = buf[0] & 255
  m1 = buf[1] & 255
  t_m0 = m0 * 256
  magic = t_m0 | m1
  @if m0 != 83 || m1 != 87
    return {
      valid: 0,
      reason: "Invalid magic header (expected 0x53 0x57)",
      magic: magic,
      version: 0,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  version = buf[2] & 255
  @if version != 1
    return {
      valid: 0,
      reason: "Unsupported protocol version",
      magic: magic,
      version: version,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  msg_type = buf[3] & 255
  p_len = net_u32_be(buf, 4)
  checksum = net_u32_be(buf, 8)

  @if buf.len() < 12 + p_len
    return {
      valid: 0,
      reason: "Payload length mismatch",
      magic: magic,
      version: version,
      msg_type: msg_type,
      payload_len: p_len,
      checksum: checksum,
      payload: ""
    }
  @end

  p_str = ""
  i = 0
  @while i < p_len
    p_str = string_concat(p_str, str_from_char_code(buf[12 + i]))
    i = i + 1
  @end

  computed_crc = compute_crc32(p_str)
  @if computed_crc != checksum
    return {
      valid: 0,
      reason: "CRC32 Checksum mismatch",
      magic: magic,
      version: version,
      msg_type: msg_type,
      payload_len: p_len,
      checksum: checksum,
      payload: p_str
    }
  @end

  return {
    valid: 1,
    reason: "OK",
    magic: magic,
    version: version,
    msg_type: msg_type,
    payload_len: p_len,
    checksum: checksum,
    payload: p_str
  }
@end

@fn protocol_encode_wire(msg_type, payload_str)
  crc = compute_crc32(payload_str)
  plen = str_len(payload_str)
  h1 = string_concat("SW", proto_int_to_hex2(1))
  h2 = string_concat(h1, proto_int_to_hex2(msg_type))
  h3 = string_concat(h2, proto_int_to_hex8(plen))
  h4 = string_concat(h3, proto_int_to_hex8(crc))
  hdr = string_concat(h4, ":")
  return string_concat(hdr, payload_str)
@end

@fn protocol_decode_wire(wire_str)
  wlen = str_len(wire_str)
  @if wlen < 23
    return {
      valid: 0,
      reason: "Wire packet too short (< 23 bytes)",
      magic: 0,
      version: 0,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  c0 = str_char_at(wire_str, 0)
  c1 = str_char_at(wire_str, 1)
  t_c0 = c0 * 256
  magic = t_c0 | c1
  @if c0 != 83 || c1 != 87
    return {
      valid: 0,
      reason: "Invalid magic header (expected 0x53 0x57)",
      magic: magic,
      version: 0,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  version = proto_hex_to_int(wire_str, 2, 2)
  @if version != 1
    return {
      valid: 0,
      reason: "Unsupported protocol version",
      magic: magic,
      version: version,
      msg_type: 0,
      payload_len: 0,
      checksum: 0,
      payload: ""
    }
  @end

  msg_type = proto_hex_to_int(wire_str, 4, 2)
  plen = proto_hex_to_int(wire_str, 6, 8)
  checksum = proto_hex_to_int(wire_str, 14, 8)

  sep = str_char_at(wire_str, 22)
  @if sep != 58
    return {
      valid: 0,
      reason: "Missing payload delimiter :",
      magic: magic,
      version: version,
      msg_type: msg_type,
      payload_len: plen,
      checksum: checksum,
      payload: ""
    }
  @end

  @if wlen < 23 + plen
    return {
      valid: 0,
      reason: "Payload length mismatch",
      magic: magic,
      version: version,
      msg_type: msg_type,
      payload_len: plen,
      checksum: checksum,
      payload: ""
    }
  @end

  payload = str_substr(wire_str, 23, 23 + plen)
  computed_crc = compute_crc32(payload)
  @if computed_crc != checksum
    return {
      valid: 0,
      reason: "CRC32 Checksum mismatch",
      magic: magic,
      version: version,
      msg_type: msg_type,
      payload_len: plen,
      checksum: checksum,
      payload: payload
    }
  @end

  return {
    valid: 1,
    reason: "OK",
    magic: magic,
    version: version,
    msg_type: msg_type,
    payload_len: plen,
    checksum: checksum,
    payload: payload
  }
@end

@fn protocol_send_tcp(sockfd, msg_type, payload_str)
  wire = protocol_encode_wire(msg_type, payload_str)
  return tcp_send(sockfd, wire)
@end

@fn protocol_recv_tcp(sockfd)
  raw = tcp_recv(sockfd, 65536)
  @if raw == ""
    return { valid: 0, reason: "Socket closed or empty read", magic: 0, version: 0, msg_type: 0, payload_len: 0, checksum: 0, payload: "" }
  @end
  return protocol_decode_wire(raw)
@end

@fn protocol_send_udp(sockfd, host, port, msg_type, payload_str)
  wire = protocol_encode_wire(msg_type, payload_str)
  return udp_send_to(sockfd, host, port, wire)
@end

@fn protocol_recv_udp(sockfd)
  recv_res = udp_recv_from(sockfd, 65536)
  @if recv_res.bytes_read <= 0
    return { packet: { valid: 0, reason: "UDP read failed", magic: 0, version: 0, msg_type: 0, payload_len: 0, checksum: 0, payload: "" }, sender_host: "", sender_port: 0 }
  @end
  dec = protocol_decode_wire(recv_res.data)
  return { packet: dec, sender_host: recv_res.sender_host, sender_port: recv_res.sender_port }
@end

@fn protocol_recv_udp_nonblocking(sockfd)
  recv_res = udp_recv_from_nonblocking(sockfd, 65536)
  @if recv_res.bytes_read <= 0
    return { packet: { valid: 0, reason: "UDP no packet available", magic: 0, version: 0, msg_type: 0, payload_len: 0, checksum: 0, payload: "" }, sender_host: "", sender_port: 0 }
  @end
  dec = protocol_decode_wire(recv_res.data)
  return { packet: dec, sender_host: recv_res.sender_host, sender_port: recv_res.sender_port }
@end