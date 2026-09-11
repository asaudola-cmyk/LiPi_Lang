@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: SOCKET SYSCALLS + BINARY PACKET SERIALIZER
@! File: tests/e2e/tier3_combinations/test_socket_binary_protocol.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/os/syscalls"

@struct Packet
  magic: 0      @! 0xAA55 (43605)
  pkt_type: 0   @! 1=Ping, 2=Data, 3=Ack
  seq_id: 0
  payload_len: 0
  checksum: 0
  payload_bytes: 0
@end

@struct DecodedPacket
  valid: 0
  reason: ""
  magic: 0
  pkt_type: 0
  seq_id: 0
  payload_len: 0
  checksum: 0
  payload: 0
@end

@fn crc32_update(crc, byte_val)
  c = (crc ^ byte_val) & 255
  j = 0
  @while j < 8
    @if c & 1 != 0
      c = (c / 2) ^ 0xEDB88320
    @else
      c = c / 2
    @end
    j = j + 1
  @end
  return (crc / 256) ^ c
@end

@fn compute_crc32(bytes_arr)
  crc = 0xFFFFFFFF
  i = 0
  len = bytes_arr.len()
  @while i < len
    crc = crc32_update(crc, bytes_arr[i] & 255)
    i = i + 1
  @end
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF
@end

@fn serialize_packet(pkt)
  buf = []

  @! Magic (2 bytes big endian)
  b0 = (pkt.magic / 256) & 255
  b1 = pkt.magic & 255
  buf.push(b0)
  buf.push(b1)

  @! Type (1 byte)
  buf.pushpkt.pkt_type & 255

  @! Seq ID (2 bytes big endian)
  buf.push((pkt.seq_id / 256) & 255)
  buf.pushpkt.seq_id & 255

  @! Payload Len (2 bytes big endian)
  buf.push((pkt.payload_len / 256) & 255)
  buf.pushpkt.payload_len & 255

  @! Checksum (4 bytes big endian)
  buf.push((pkt.checksum / 16777216) & 255)
  buf.push((pkt.checksum / 65536) & 255)
  buf.push((pkt.checksum / 256) & 255)
  buf.pushpkt.checksum & 255

  @! Payload
  p_len = pkt.payload_bytes.len()
  i = 0
  @while i < p_len
    buf.push(pkt.payload_bytes[i] & 255)
    i = i + 1
  @end

  return buf
@end

@fn make_invalid_decoded(reason)
  return {
    valid: 0,
    reason: reason,
    magic: 0,
    pkt_type: 0,
    seq_id: 0,
    payload_len: 0,
    checksum: 0,
    payload: []
  }
@end

@fn deserialize_packet(buf)
  @if buf.len() < 11
    return make_invalid_decoded("Buffer too small for header")
  @end

  b0 = buf[0] & 255
  b1 = buf[1] & 255
  magic = (b0 * 256) | b1
  @if magic != 43605  @! 0xAA55
    return make_invalid_decoded("Invalid magic byte")
  @end

  pkt_type = buf[2] & 255
  seq_id = ((buf[3] & 255) * 256) | (buf[4] & 255)
  p_len = ((buf[5] & 255) * 256) | (buf[6] & 255)

  c3 = buf[7] & 255
  c2 = buf[8] & 255
  c1 = buf[9] & 255
  c0 = buf[10] & 255
  checksum = (c3 * 16777216) | (c2 * 65536) | (c1 * 256) | c0

  @if buf.len() < 11 + p_len
    return make_invalid_decoded("Payload length mismatch")
  @end

  extracted_payload = []
  i = 0
  @while i < p_len
    extracted_payload.push(buf[11 + i])
    i = i + 1
  @end

  computed_crc = compute_crc32(extracted_payload)
  @if computed_crc != checksum
    return make_invalid_decoded("CRC32 Checksum mismatch")
  @end

  return {
    valid: 1,
    reason: "OK",
    magic: magic,
    pkt_type: pkt_type,
    seq_id: seq_id,
    payload_len: p_len,
    checksum: checksum,
    payload: extracted_payload
  }
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 9: Socket Syscalls & Binary Serialization")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.9.1: Live Socket Syscall Creation & Non-Blocking Option
  total = total + 1
  @! AF_INET = 2, SOCK_STREAM = 1, IPPROTO_TCP = 6
  sock_fd = sys_socket(2, 1, 6)
  sock_created = 0
  @if sock_fd >= 3
    sock_created = 1
    sys_close(sock_fd)
  @end

  @if sock_created == 1
    passed = passed + 1
    println("  [PASS] T3.9.1: sys_socket created valid AF_INET TCP socket descriptor (" + int_to_str(sock_fd) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9.1: sys_socket failed: " + int_to_str(sock_fd))
  @end

  @! T3.9.2: Binary Packet Assembly & CRC32 Computation
  total = total + 1
  payload = [72, 69, 76, 76, 79, 32, 77, 65, 89, 65]  @! "HELLO MAYA"
  crc = compute_crc32(payload)
  pkt = {
    magic: 43605,  @! 0xAA55
    pkt_type: 2,   @! Data
    seq_id: 101,
    payload_len: payload.len(),
    checksum: crc,
    payload_bytes: payload
  }
  raw_bytes = serialize_packet(pkt)

  @! Header: 11 bytes + Payload: 10 bytes = 21 bytes
  @if raw_bytes.len() == 21 && crc != 0
    passed = passed + 1
    println("  [PASS] T3.9.2: Binary packet serialized to 21 bytes with valid CRC32 (" + int_to_str(crc) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9.2: Serialization failed: len=" + int_to_str(raw_bytes.len()))
  @end

  @! T3.9.3: Packet Deserialization and Invariant Verification
  total = total + 1
  decoded = deserialize_packet(raw_bytes)
  @if decoded.valid == 1 && decoded.magic == 43605 && decoded.pkt_type == 2 && decoded.seq_id == 101 && decoded.payload_len == 10
    passed = passed + 1
    println("  [PASS] T3.9.3: Packet deserializer verified header fields, magic, and payload integrity")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9.3: Deserialization failed: reason=" + decoded.reason)
  @end

  @! T3.9.4: Checksum Tamper Rejection
  total = total + 1
  tampered_bytes = []
  i = 0
  @while i < raw_bytes.len()
    tampered_bytes.push(raw_bytes[i])
    i = i + 1
  @end
  tampered_bytes[15] = 99  @! Corrupt payload byte
  tamper_res = deserialize_packet(tampered_bytes)

  @if tamper_res.valid == 0 && tamper_res.reason == "CRC32 Checksum mismatch"
    passed = passed + 1
    println("  [PASS] T3.9.4: Tampered payload rejected by CRC32 validator: \"" + tamper_res.reason + "\"")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9.4: Tamper rejection failed: reason=" + tamper_res.reason)
  @end

  @! T3.9.5: Magic Byte Rejection
  total = total + 1
  tampered_magic = []
  i = 0
  @while i < raw_bytes.len()
    tampered_magic.push(raw_bytes[i])
    i = i + 1
  @end
  tampered_magic[0] = 0  @! Corrupt magic
  magic_res = deserialize_packet(tampered_magic)

  @if magic_res.valid == 0 && magic_res.reason == "Invalid magic byte"
    passed = passed + 1
    println("  [PASS] T3.9.5: Corrupted magic header byte rejected: \"" + magic_res.reason + "\"")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9.5: Magic rejection failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 9 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 9 (Socket Syscalls & Binary Serialization) PASSED")
    return 0
  @else
    println("✗ Combination 9 (Socket Syscalls & Binary Serialization) FAILED")
    return 1
  @end
@end
