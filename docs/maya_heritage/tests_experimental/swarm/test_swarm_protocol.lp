@! ============================================================================
@! MAYA SWARM PROTOCOL TEST SUITE (tests/swarm/test_swarm_protocol.maya)
@! Tests:
@! 1. Binary packet serialization & byte framing
@! 2. CRC32 polynomial computation & validation
@! 3. Protocol magic (0x53 0x57) and version header verification
@! 4. All standard Swarm message type codes
@! 5. Checksum tamper detection & rejection
@! 6. Corrupted magic header rejection
@! 7. Truncated / buffer underrun packet rejection
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/swarm/types"
import "universe/swarm/protocol"

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(state, name, actual, expected)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(state, name, cond)
  state.total = state.total + 1
  @if cond != 0
    state.passed = state.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [MAYA SWARM PROTOCOL SUITE] Binary Framing & CRC32 Verification")
  println("=================================================================")

  state = { total: 0, passed: 0, failed: 0 }

  @! --------------------------------------------------------------------------
  @! SECTION 1: Protocol Constants & Header Fields
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: Magic & Message Type Constants")

  assert_eq(state, "TC-PROTO-01.1: Swarm Magic is 0x5357 (21335)", SWARM_MAGIC(), 21335)
  assert_eq(state, "TC-PROTO-01.2: Swarm Version is 1", SWARM_VERSION(), 1)
  assert_eq(state, "TC-PROTO-01.3: MSG_BEACON code is 1", MSG_BEACON(), 1)
  assert_eq(state, "TC-PROTO-01.4: MSG_HANDSHAKE code is 2", MSG_HANDSHAKE(), 2)
  assert_eq(state, "TC-PROTO-01.5: MSG_HEARTBEAT code is 3", MSG_HEARTBEAT(), 3)
  assert_eq(state, "TC-PROTO-01.6: MSG_TASK_SUBMIT code is 4", MSG_TASK_SUBMIT(), 4)
  assert_eq(state, "TC-PROTO-01.7: MSG_TASK_RESULT code is 5", MSG_TASK_RESULT(), 5)
  assert_eq(state, "TC-PROTO-01.8: MSG_ACTOR_CAST code is 6", MSG_ACTOR_CAST(), 6)
  assert_eq(state, "TC-PROTO-01.9: MSG_ACTOR_CALL code is 7", MSG_ACTOR_CALL(), 7)
  assert_eq(state, "TC-PROTO-01.10: MSG_ACTOR_REPLY code is 8", MSG_ACTOR_REPLY(), 8)
  assert_eq(state, "TC-PROTO-01.11: MSG_GOSSIP_REQ code is 9", MSG_GOSSIP_REQ(), 9)
  assert_eq(state, "TC-PROTO-01.12: MSG_GOSSIP_RESP code is 10", MSG_GOSSIP_RESP(), 10)

  @! --------------------------------------------------------------------------
  @! SECTION 2: CRC32 Polynomial Computation
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: CRC32 Polynomial Validation")

  crc_empty = compute_crc32("")
  assert_eq(state, "TC-CRC-01.1: CRC32 of empty string is 0", crc_empty, 0)

  payload_sample = "HELLO_MAYA_SWARM_CLUSTER"
  crc1 = compute_crc32(payload_sample)
  crc2 = compute_crc32(payload_sample)
  assert_true(state, "TC-CRC-01.2: CRC32 is deterministic non-zero", crc1 != 0 && crc1 == crc2)

  payload_altered = "HELLO_MAYA_SWARM_CLUSTES"
  crc_alt = compute_crc32(payload_altered)
  assert_true(state, "TC-CRC-01.3: 1-bit payload change alters CRC32 checksum", crc1 != crc_alt)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Binary Byte-Array Framing & Roundtrip
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Binary Byte-Array Framing & Roundtrip")

  test_payload = "{\"node_id\":\"maya-node-1042\",\"load\":3}"
  raw_bytes = protocol_encode_bytes(MSG_TASK_SUBMIT(), test_payload)

  @! Header is 12 bytes: 2 magic + 1 ver + 1 type + 4 len + 4 crc
  expected_len = 12 + test_payload.len()
  assert_eq(state, "TC-FRAME-01.1: Byte array serialized to exact 12+N bytes", raw_bytes.len(), expected_len)
  assert_eq(state, "TC-FRAME-01.2: Magic byte 0 is 0x53 ('S' = 83)", raw_bytes[0], 83)
  assert_eq(state, "TC-FRAME-01.3: Magic byte 1 is 0x57 ('W' = 87)", raw_bytes[1], 87)
  assert_eq(state, "TC-FRAME-01.4: Version byte is 1", raw_bytes[2], 1)
  assert_eq(state, "TC-FRAME-01.5: Message type byte is MSG_TASK_SUBMIT", raw_bytes[3], MSG_TASK_SUBMIT())

  decoded_bytes = protocol_decode_bytes(raw_bytes)
  assert_eq(state, "TC-FRAME-01.6: Binary deserializer validates packet", decoded_bytes.valid, 1)
  assert_eq(state, "TC-FRAME-01.7: Deserialized reason is 'OK'", decoded_bytes.reason, "OK")
  assert_eq(state, "TC-FRAME-01.8: Deserialized msg_type matches", decoded_bytes.msg_type, MSG_TASK_SUBMIT())
  assert_eq(state, "TC-FRAME-01.9: Deserialized payload matches verbatim", decoded_bytes.payload, test_payload)

  @! --------------------------------------------------------------------------
  @! SECTION 4: Wire-String Framing & Tamper Detection
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: Framed Wire Protocol & Tamper Rejection")

  wire_pkt = protocol_encode_wire(MSG_ACTOR_CAST(), "ACTION:SPAWN_WORKER")
  dec_wire = protocol_decode_wire(wire_pkt)
  assert_eq(state, "TC-WIRE-01.1: Wire-string deserialization succeeds", dec_wire.valid, 1)
  assert_eq(state, "TC-WIRE-01.2: Wire message type is MSG_ACTOR_CAST", dec_wire.msg_type, MSG_ACTOR_CAST())
  assert_eq(state, "TC-WIRE-01.3: Wire payload intact", dec_wire.payload, "ACTION:SPAWN_WORKER")

  @! Tamper 1: Byte in payload corrupted
  tampered_bytes = []
  i = 0
  @while i < raw_bytes.len()
    tampered_bytes.push(raw_bytes[i])
    i = i + 1
  @end
  tampered_bytes[15] = 120  @! Corrupt payload character
  tamper_res = protocol_decode_bytes(tampered_bytes)
  assert_eq(state, "TC-TAMPER-01.1: Corrupted payload rejected by CRC32 validator", tamper_res.valid, 0)
  assert_eq(state, "TC-TAMPER-01.2: Tamper reason identifies CRC mismatch", tamper_res.reason, "CRC32 Checksum mismatch")

  @! Tamper 2: Magic header corrupted
  corrupt_magic = []
  i = 0
  @while i < raw_bytes.len()
    corrupt_magic.push(raw_bytes[i])
    i = i + 1
  @end
  corrupt_magic[0] = 99  @! Alter magic byte
  magic_res = protocol_decode_bytes(corrupt_magic)
  assert_eq(state, "TC-TAMPER-01.3: Corrupted magic header rejected", magic_res.valid, 0)
  assert_true(state, "TC-TAMPER-01.4: Reason indicates invalid magic", contains(magic_res.reason, "Invalid magic"))

  @! Tamper 3: Truncated buffer
  short_buf = [83, 87, 1, 4]
  trunc_res = protocol_decode_bytes(short_buf)
  assert_eq(state, "TC-TAMPER-01.5: Truncated buffer (<12 bytes) rejected", trunc_res.valid, 0)

  @! Tamper 4: Truncated wire string
  trunc_wire_res = protocol_decode_wire("SW0104")
  assert_eq(state, "TC-TAMPER-01.6: Truncated wire string rejected", trunc_wire_res.valid, 0)

  println("\n=================================================================")
  println("📊 SWARM PROTOCOL SUITE SUMMARY: " + state.passed.to_str() + "/" + state.total.to_str() + " passed")
  println("=================================================================")

  @if state.failed == 0
    println("✓ ALL SWARM PROTOCOL TESTS PASSED")
    return 0
  @else
    println("✗ SOME SWARM PROTOCOL TESTS FAILED")
    return 1
  @end
@end
