@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE: QUIC RFC 9000 & TLS 1.3 E2E TEST SUITE
@! File: tests/e2e/test_quic_e2e.maya
@! Milestone 5: Pure Maya RFC 9000 QUIC, TLS 1.3 AES-GCM Integration & Congestion
@! 100% Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/aes"
import "universe/net/tls/tls13"
import "universe/net/quic"

@! ============================================================================
@! 1. TEST STATE & ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_true(state: TestState, cond, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if cond == true || cond == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state: TestState, cond, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if cond == false || cond == 0
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state: TestState, actual: i64, expected: i64, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_ge_int(state: TestState, actual: i64, min_val: i64, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual >= min_val
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc + " (val=" + actual.to_str() + " >= " + min_val.to_str() + ")")
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected >= " + min_val.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state: TestState, actual: string, expected: string, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn assert_eq_array(state: TestState, actual: array, expected: array, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual.len() != expected.len()
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (len mismatch: expected " + expected.len().to_str() + ", got " + actual.len().to_str() + ")")
    return 0
  @end
  
  i = 0
  len = actual.len()
  @while i < len
    @if actual[i] != expected[i]
      state.failed = state.failed + 1
      println("  [FAIL] " + test_id + ": " + desc + " (element " + i.to_str() + " mismatch: expected " + expected[i].to_str() + ", got " + actual[i].to_str() + ")")
      return 0
    @end
    i = i + 1
  @end

  state.passed = state.passed + 1
  println("  [PASS] " + test_id + ": " + desc + " (matched " + len.to_str() + " elements)")
  return 1
@end

@! ============================================================================
@! TIER 1: FEATURE COVERAGE & PROTOCOL UNIT VERIFICATIONS
@! ============================================================================

@fn run_tier1_features(state: TestState)
  println("\n-----------------------------------------------------------------")
  println("▶ [TIER 1] RFC 9000 QUIC CORE FEATURE & FRAMING COVERAGE")
  println("-----------------------------------------------------------------")

  @! 1.1 Variable-Length Integer (Varint) Codec (RFC 9000 §16)
  v1_enc = quic_encode_varint(25)
  assert_eq_int(state, v1_enc.len(), 1, "T1.1.1", "1-byte varint encoding length for value 25")
  v1_dec = quic_decode_varint(v1_enc, 0)
  assert_eq_int(state, v1_dec.varint_val, 25, "T1.1.2", "1-byte varint decoded value == 25")
  assert_eq_int(state, v1_dec.varint_len, 1, "T1.1.3", "1-byte varint consumed length == 1")
  assert_eq_int(state, v1_dec.varint_next_offset, 1, "T1.1.4", "1-byte varint next offset == 1")

  v2_enc = quic_encode_varint(5000)
  assert_eq_int(state, v2_enc.len(), 2, "T1.1.5", "2-byte varint encoding length for value 5000")
  v2_dec = quic_decode_varint(v2_enc, 0)
  assert_eq_int(state, v2_dec.varint_val, 5000, "T1.1.6", "2-byte varint decoded value == 5000")
  assert_eq_int(state, v2_dec.varint_len, 2, "T1.1.7", "2-byte varint consumed length == 2")

  v4_enc = quic_encode_varint(70000000)
  assert_eq_int(state, v4_enc.len(), 4, "T1.1.8", "4-byte varint encoding length for value 70000000")
  v4_dec = quic_decode_varint(v4_enc, 0)
  assert_eq_int(state, v4_dec.varint_val, 70000000, "T1.1.9", "4-byte varint decoded value == 70000000")
  assert_eq_int(state, v4_dec.varint_len, 4, "T1.1.10", "4-byte varint consumed length == 4")

  v8_enc = quic_encode_varint(2000000000000)
  assert_eq_int(state, v8_enc.len(), 8, "T1.1.11", "8-byte varint encoding length for value 2000000000000")
  v8_dec = quic_decode_varint(v8_enc, 0)
  assert_eq_int(state, v8_dec.varint_val, 2000000000000, "T1.1.12", "8-byte varint decoded value == 2000000000000")
  assert_eq_int(state, v8_dec.varint_len, 8, "T1.1.13", "8-byte varint consumed length == 8")

  @! 1.2 Frame Encoders & Parsers (RFC 9000 §19)
  @! PADDING
  pad_bytes = quic_frame_encode_padding(16)
  assert_eq_int(state, pad_bytes.len(), 16, "T1.2.1", "Padding frame encodes 16 zeroes")
  pad_res = quic_parse_frame(pad_bytes, 0)
  assert_eq_int(state, pad_res.parse_frame.frame_type, QUIC_FRAME_PADDING(), "T1.2.2", "Parsed PADDING frame type")

  @! PING
  ping_bytes = quic_frame_encode_ping()
  assert_eq_int(state, ping_bytes[0], 1, "T1.2.3", "PING frame opcode is 0x01")
  ping_res = quic_parse_frame(ping_bytes, 0)
  assert_eq_int(state, ping_res.parse_frame.frame_type, QUIC_FRAME_PING(), "T1.2.4", "Parsed PING frame type")

  @! ACK
  ack_bytes = quic_frame_encode_ack(1024, 8, 4)
  ack_res = quic_parse_frame(ack_bytes, 0)
  assert_eq_int(state, ack_res.parse_frame.frame_type, QUIC_FRAME_ACK(), "T1.2.5", "Parsed ACK frame type")
  assert_eq_int(state, ack_res.parse_frame.frame_largest_acked, 1024, "T1.2.6", "ACK largest_acked == 1024")
  assert_eq_int(state, ack_res.parse_frame.frame_ack_delay, 8, "T1.2.7", "ACK ack_delay == 8")
  assert_eq_int(state, ack_res.parse_frame.frame_first_ack_range, 4, "T1.2.8", "ACK first_ack_range == 4")

  @! CRYPTO
  c_payload = [22, 3, 3, 0, 48, 1, 0, 0, 44, 3, 3]
  crypto_bytes = quic_frame_encode_crypto(128, c_payload)
  crypto_res = quic_parse_frame(crypto_bytes, 0)
  assert_eq_int(state, crypto_res.parse_frame.frame_type, QUIC_FRAME_CRYPTO(), "T1.2.9", "Parsed CRYPTO frame type")
  assert_eq_int(state, crypto_res.parse_frame.frame_offset, 128, "T1.2.10", "CRYPTO offset == 128")
  assert_eq_int(state, crypto_res.parse_frame.frame_len, c_payload.len(), "T1.2.11", "CRYPTO length matches payload")
  assert_eq_array(state, crypto_res.parse_frame.frame_data, c_payload, "T1.2.12", "CRYPTO data matches payload")

  @! STREAM
  st_payload = [72, 84, 84, 80, 47, 51] @! "HTTP/3"
  st_bytes = quic_frame_encode_stream(4, 512, st_payload, 1)
  st_res = quic_parse_frame(st_bytes, 0)
  assert_eq_int(state, st_res.parse_frame.frame_type, QUIC_FRAME_STREAM(), "T1.2.13", "Parsed STREAM frame type")
  assert_eq_int(state, st_res.parse_frame.frame_stream_id, 4, "T1.2.14", "STREAM stream_id == 4")
  assert_eq_int(state, st_res.parse_frame.frame_offset, 512, "T1.2.15", "STREAM offset == 512")
  assert_eq_int(state, st_res.parse_frame.frame_fin, 1, "T1.2.16", "STREAM FIN bit == 1")
  assert_eq_array(state, st_res.parse_frame.frame_data, st_payload, "T1.2.17", "STREAM data matches HTTP/3")

  @! PATH_CHALLENGE & PATH_RESPONSE
  chal_data = [101, 102, 103, 104, 105, 106, 107, 108]
  chal_bytes = quic_frame_encode_path_challenge(chal_data)
  chal_res = quic_parse_frame(chal_bytes, 0)
  assert_eq_int(state, chal_res.parse_frame.frame_type, QUIC_FRAME_PATH_CHALLENGE(), "T1.2.18", "Parsed PATH_CHALLENGE frame")
  assert_eq_array(state, chal_res.parse_frame.frame_data, chal_data, "T1.2.19", "PATH_CHALLENGE data 8-bytes")

  resp_bytes = quic_frame_encode_path_response(chal_data)
  resp_res = quic_parse_frame(resp_bytes, 0)
  assert_eq_int(state, resp_res.parse_frame.frame_type, QUIC_FRAME_PATH_RESPONSE(), "T1.2.20", "Parsed PATH_RESPONSE frame")
  assert_eq_array(state, resp_res.parse_frame.frame_data, chal_data, "T1.2.21", "PATH_RESPONSE echoed 8-bytes")

  @! RESET_STREAM & STOP_SENDING
  rst_bytes = quic_frame_encode_reset_stream(12, 503, 8192)
  rst_res = quic_parse_frame(rst_bytes, 0)
  assert_eq_int(state, rst_res.parse_frame.frame_type, QUIC_FRAME_RESET_STREAM(), "T1.2.22", "Parsed RESET_STREAM frame")
  assert_eq_int(state, rst_res.parse_frame.frame_stream_id, 12, "T1.2.23", "RESET_STREAM stream_id == 12")
  assert_eq_int(state, rst_res.parse_frame.frame_error_code, 503, "T1.2.24", "RESET_STREAM error_code == 503")
  assert_eq_int(state, rst_res.parse_frame.frame_offset, 8192, "T1.2.25", "RESET_STREAM final_size == 8192")

  stop_bytes = quic_frame_encode_stop_sending(12, 503)
  stop_res = quic_parse_frame(stop_bytes, 0)
  assert_eq_int(state, stop_res.parse_frame.frame_type, QUIC_FRAME_STOP_SENDING(), "T1.2.26", "Parsed STOP_SENDING frame")
  assert_eq_int(state, stop_res.parse_frame.frame_stream_id, 12, "T1.2.27", "STOP_SENDING stream_id == 12")
  assert_eq_int(state, stop_res.parse_frame.frame_error_code, 503, "T1.2.28", "STOP_SENDING error_code == 503")

  @! CONNECTION_CLOSE (QUIC & App layers)
  close_q_bytes = quic_frame_encode_connection_close(10, 8, "Flow control violation", 0)
  close_q_res = quic_parse_frame(close_q_bytes, 0)
  assert_eq_int(state, close_q_res.parse_frame.frame_type, QUIC_FRAME_CONNECTION_CLOSE_QUIC(), "T1.2.29", "Parsed CONNECTION_CLOSE (QUIC)")
  assert_eq_int(state, close_q_res.parse_frame.frame_error_code, 10, "T1.2.30", "Close error code == 10")
  assert_eq_int(state, close_q_res.parse_frame.frame_type_field, 8, "T1.2.31", "Close frame type trigger == 8")
  assert_eq_str(state, close_q_res.parse_frame.frame_reason, "Flow control violation", "T1.2.32", "Close reason matched")

  close_app_bytes = quic_frame_encode_connection_close(200, 0, "HTTP/3 Session Ended", 1)
  close_app_res = quic_parse_frame(close_app_bytes, 0)
  assert_eq_int(state, close_app_res.parse_frame.frame_type, QUIC_FRAME_CONNECTION_CLOSE_APP(), "T1.2.33", "Parsed CONNECTION_CLOSE (App)")
  assert_eq_int(state, close_app_res.parse_frame.frame_error_code, 200, "T1.2.34", "App close error code == 200")
  assert_eq_str(state, close_app_res.parse_frame.frame_reason, "HTTP/3 Session Ended", "T1.2.35", "App close reason matched")

  @! HANDSHAKE_DONE
  hdone_bytes = quic_frame_encode_handshake_done()
  hdone_res = quic_parse_frame(hdone_bytes, 0)
  assert_eq_int(state, hdone_res.parse_frame.frame_type, QUIC_FRAME_HANDSHAKE_DONE(), "T1.2.36", "Parsed HANDSHAKE_DONE frame")

  @! NEW_TOKEN, MAX_DATA, MAX_STREAM_DATA, NEW_CONNECTION_ID, RETIRE_CONNECTION_ID
  tok_data = [99, 88, 77, 66]
  tok_bytes = quic_frame_encode_new_token(tok_data)
  assert_eq_int(state, tok_bytes[0], QUIC_FRAME_NEW_TOKEN(), "T1.2.37", "NEW_TOKEN frame opcode 0x07")

  md_bytes = quic_frame_encode_max_data(1048576)
  assert_eq_int(state, md_bytes[0], QUIC_FRAME_MAX_DATA(), "T1.2.38", "MAX_DATA frame opcode 0x10")

  msd_bytes = quic_frame_encode_max_stream_data(4, 262144)
  assert_eq_int(state, msd_bytes[0], QUIC_FRAME_MAX_STREAM_DATA(), "T1.2.39", "MAX_STREAM_DATA frame opcode 0x11")

  rst_tok_16 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  ncid_bytes = quic_frame_encode_new_connection_id(1, 0, [8, 9, 10, 11], rst_tok_16)
  assert_eq_int(state, ncid_bytes[0], QUIC_FRAME_NEW_CONNECTION_ID(), "T1.2.40", "NEW_CONNECTION_ID frame opcode 0x18")

  rcid_bytes = quic_frame_encode_retire_connection_id(1)
  assert_eq_int(state, rcid_bytes[0], QUIC_FRAME_RETIRE_CONNECTION_ID(), "T1.2.41", "RETIRE_CONNECTION_ID frame opcode 0x19")
@end

@! ============================================================================
@! TIER 2: BOUNDARIES, CORNER CASES & PACKET SERIALIZATION
@! ============================================================================

@fn run_tier2_boundaries(state: TestState)
  println("\n-----------------------------------------------------------------")
  println("▶ [TIER 2] BOUNDARY VALUES, CORNER CASES & PACKET FRAMING")
  println("-----------------------------------------------------------------")

  @! 2.1 Varint 1B/2B Boundary (63 vs 64)
  v63_enc = quic_encode_varint(63)
  assert_eq_int(state, v63_enc.len(), 1, "T2.1.1", "Varint 63 encodes to 1 byte")
  v63_dec = quic_decode_varint(v63_enc, 0)
  assert_eq_int(state, v63_dec.varint_val, 63, "T2.1.2", "Varint 63 decoded == 63")

  v64_enc = quic_encode_varint(64)
  assert_eq_int(state, v64_enc.len(), 2, "T2.1.3", "Varint 64 encodes to 2 bytes")
  v64_dec = quic_decode_varint(v64_enc, 0)
  assert_eq_int(state, v64_dec.varint_val, 64, "T2.1.4", "Varint 64 decoded == 64")

  @! 2.2 Varint 2B/4B Boundary (16383 vs 16384)
  v16383_enc = quic_encode_varint(16383)
  assert_eq_int(state, v16383_enc.len(), 2, "T2.1.5", "Varint 16383 encodes to 2 bytes")
  v16383_dec = quic_decode_varint(v16383_enc, 0)
  assert_eq_int(state, v16383_dec.varint_val, 16383, "T2.1.6", "Varint 16383 decoded == 16383")

  v16384_enc = quic_encode_varint(16384)
  assert_eq_int(state, v16384_enc.len(), 4, "T2.1.7", "Varint 16384 encodes to 4 bytes")
  v16384_dec = quic_decode_varint(v16384_enc, 0)
  assert_eq_int(state, v16384_dec.varint_val, 16384, "T2.1.8", "Varint 16384 decoded == 16384")

  @! 2.3 Varint 4B/8B Boundary (1073741823 vs 1073741824)
  v_4b_max = quic_encode_varint(1073741823)
  assert_eq_int(state, v_4b_max.len(), 4, "T2.1.9", "Varint 1073741823 encodes to 4 bytes")
  v_4b_dec = quic_decode_varint(v_4b_max, 0)
  assert_eq_int(state, v_4b_dec.varint_val, 1073741823, "T2.1.10", "Varint 1073741823 decoded == 1073741823")

  v_8b_min = quic_encode_varint(1073741824)
  assert_eq_int(state, v_8b_min.len(), 8, "T2.1.11", "Varint 1073741824 encodes to 8 bytes")
  v_8b_dec = quic_decode_varint(v_8b_min, 0)
  assert_eq_int(state, v_8b_dec.varint_val, 1073741824, "T2.1.12", "Varint 1073741824 decoded == 1073741824")

  @! 2.4 Truncated Varint & Empty Buffer Handling
  empty_dec = quic_decode_varint([], 0)
  assert_eq_int(state, empty_dec.varint_val, 0, "T2.1.13", "Empty varint buffer returns val 0")
  assert_eq_int(state, empty_dec.varint_len, 0, "T2.1.14", "Empty varint buffer returns len 0")

  oob_dec = quic_decode_varint([0x40], 0) @! 2-byte tag with only 1 byte present
  assert_eq_int(state, oob_dec.varint_len, 0, "T2.1.15", "Truncated 2-byte varint returns len 0")

  @! 2.5 Long Header Packet Construction (Initial & Handshake)
  dcid = [10, 20, 30, 40, 50, 60, 70, 80]
  scid = [80, 70, 60, 50, 40, 30, 20, 10]
  tok = [1, 2, 3, 4]
  pay = [1, 2, 3, 4, 5]

  long_init_pkt = quic_pack_long_header(QUIC_PKT_INITIAL(), QUIC_VERSION_1(), dcid, scid, tok, 42, 4, pay)
  assert_ge_int(state, long_init_pkt.len(), 20, "T2.2.1", "Packed Initial Long Header packet length")
  
  unpacked_init = quic_unpack_packet(long_init_pkt, 0, 8)
  assert_eq_int(state, unpacked_init.is_long_header, 1, "T2.2.2", "Unpacked Initial is_long_header == 1")
  assert_eq_int(state, unpacked_init.packet_type, QUIC_PKT_INITIAL(), "T2.2.3", "Unpacked Initial packet_type == 0")
  assert_eq_int(state, unpacked_init.quic_version, QUIC_VERSION_1(), "T2.2.4", "Unpacked Initial version == 1")
  assert_eq_array(state, unpacked_init.dest_connection_id, dcid, "T2.2.5", "Unpacked DCID matches")
  assert_eq_array(state, unpacked_init.src_connection_id, scid, "T2.2.6", "Unpacked SCID matches")
  assert_eq_array(state, unpacked_init.packet_token, tok, "T2.2.7", "Unpacked Initial token matches")
  assert_eq_int(state, unpacked_init.packet_num, 42, "T2.2.8", "Unpacked Initial packet_num == 42")
  assert_eq_int(state, unpacked_init.packet_num_len, 4, "T2.2.9", "Unpacked Initial packet_num_len == 4")
  assert_eq_array(state, unpacked_init.packet_payload, pay, "T2.2.10", "Unpacked Initial payload matches")

  @! 2.6 Handshake Long Header Packet
  long_hs_pkt = quic_pack_long_header(QUIC_PKT_HANDSHAKE(), QUIC_VERSION_1(), dcid, scid, [], 100, 2, pay)
  unpacked_hs = quic_unpack_packet(long_hs_pkt, 0, 8)
  assert_eq_int(state, unpacked_hs.is_long_header, 1, "T2.2.11", "Unpacked Handshake is_long_header == 1")
  assert_eq_int(state, unpacked_hs.packet_type, QUIC_PKT_HANDSHAKE(), "T2.2.12", "Unpacked Handshake packet_type == 2")
  assert_eq_int(state, unpacked_hs.packet_num, 100, "T2.2.13", "Unpacked Handshake packet_num == 100")
  assert_eq_int(state, unpacked_hs.packet_num_len, 2, "T2.2.14", "Unpacked Handshake packet_num_len == 2")

  @! 2.7 Short Header (1-RTT) Packet Serialization
  short_pkt = quic_pack_short_header(dcid, 777, 3, 1, 1, pay)
  unpacked_short = quic_unpack_packet(short_pkt, 0, dcid.len())
  assert_eq_int(state, unpacked_short.is_long_header, 0, "T2.3.1", "Unpacked Short is_long_header == 0")
  assert_eq_int(state, unpacked_short.packet_type, QUIC_PKT_1RTT(), "T2.3.2", "Unpacked Short packet_type == 4 (1-RTT)")
  assert_eq_int(state, unpacked_short.packet_num, 777, "T2.3.3", "Unpacked Short packet_num == 777")
  assert_eq_int(state, unpacked_short.packet_num_len, 3, "T2.3.4", "Unpacked Short packet_num_len == 3")
  assert_eq_int(state, unpacked_short.key_phase_bit, 1, "T2.3.5", "Unpacked Short key_phase_bit == 1")
  assert_eq_int(state, unpacked_short.spin_bit_val, 1, "T2.3.6", "Unpacked Short spin_bit_val == 1")
  assert_eq_array(state, unpacked_short.dest_connection_id, dcid, "T2.3.7", "Unpacked Short DCID matches")
  assert_eq_array(state, unpacked_short.packet_payload, pay, "T2.3.8", "Unpacked Short payload matches")

  @! 2.8 Packet Frame Demuxing (Multi-frame coalescing)
  f_ping = quic_frame_encode_ping()
  f_st = quic_frame_encode_stream(1, 0, [65, 66, 67], 0)
  f_ack = quic_frame_encode_ack(10, 0, 2)
  
  coalesced = []
  i = 0 @while i < f_ping.len() coalesced = coalesced.push(f_ping[i]) i = i + 1 @end
  i = 0 @while i < f_st.len() coalesced = coalesced.push(f_st[i]) i = i + 1 @end
  i = 0 @while i < f_ack.len() coalesced = coalesced.push(f_ack[i]) i = i + 1 @end

  parsed_list = quic_parse_frames(coalesced, 0, coalesced.len())
  assert_eq_int(state, parsed_list.len(), 3, "T2.4.1", "Demuxed 3 coalesced frames from single buffer")
  f0 = parsed_list[0]
  f1 = parsed_list[1]
  f2 = parsed_list[2]
  assert_eq_int(state, f0.frame_type, QUIC_FRAME_PING(), "T2.4.2", "Demuxed Frame 0 is PING")
  assert_eq_int(state, f1.frame_type, QUIC_FRAME_STREAM(), "T2.4.3", "Demuxed Frame 1 is STREAM")
  assert_eq_int(state, f1.frame_stream_id, 1, "T2.4.4", "Demuxed Frame 1 stream_id == 1")
  assert_eq_int(state, f2.frame_type, QUIC_FRAME_ACK(), "T2.4.5", "Demuxed Frame 2 is ACK")
  assert_eq_int(state, f2.frame_largest_acked, 10, "T2.4.6", "Demuxed Frame 2 largest_acked == 10")
@end

@! ============================================================================
@! TIER 3: CRYPTOGRAPHIC & STATE INTEGRATION (TLS 1.3 AES-GCM & RFC 9002)
@! ============================================================================

@fn run_tier3_crypto_and_state(state: TestState)
  println("\n-----------------------------------------------------------------")
  println("▶ [TIER 3] TLS 1.3 AES-GCM CRYPTO, STATE MACHINE & CONGESTION")
  println("-----------------------------------------------------------------")

  @! 3.1 Genuine AES-256 CTR Stream Cipher Verification (Foundation of AES-GCM)
  aes_key = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
  ]
  aes_nonce = [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0x00, 0x00, 0x00, 0x01]
  
  plaintext_stream = [77, 97, 121, 97, 81, 117, 105, 99, 84, 108, 115, 49, 51, 69, 50, 69] @! "MayaQuicTls13E2E"
  
  ciphertext_stream = aes256_ctr_encrypt(aes_key, aes_nonce, plaintext_stream)
  assert_eq_int(state, ciphertext_stream.len(), plaintext_stream.len(), "T3.1.1", "AES-256-CTR ciphertext length preserves plaintext size")
  
  @! Verify ciphertext is genuinely scrambled (not identical to plaintext)
  diff_count = 0
  i = 0
  @while i < plaintext_stream.len()
    @if ciphertext_stream[i] != plaintext_stream[i]
      diff_count = diff_count + 1
    @end
    i = i + 1
  @end
  assert_ge_int(state, diff_count, 14, "T3.1.2", "AES-256-CTR ciphertext thoroughly scrambled (high entropy)")

  @! Decrypt back and verify 100% roundtrip byte parity
  decrypted_stream = aes256_ctr_decrypt(aes_key, aes_nonce, ciphertext_stream)
  assert_eq_array(state, decrypted_stream, plaintext_stream, "T3.1.3", "AES-256-CTR decryption perfectly recovers original plaintext bytes")

  @! 3.2 TLS 1.3 GF(2^128) GHASH Arithmetic & Authentication
  ghash_h = [0x66, 0xe9, 0x4b, 0xd4, 0xef, 0x8a, 0x2c, 0x3b, 0x88, 0x4c, 0xfa, 0x59, 0xca, 0x34, 0x2b, 0x2e]
  ghash_x = [0x03, 0x88, 0xda, 0xce, 0x60, 0xb6, 0xa3, 0x92, 0xf3, 0x28, 0xc2, 0xb9, 0x71, 0xb2, 0xfe, 0x78]
  tag_z = ghash(ghash_h, ghash_x)
  assert_eq_int(state, tag_z.len(), 16, "T3.2.1", "GHASH GF(2^128) produces 16-byte authentication vector")
  
  @! 3.3 1-RTT Encrypted QUIC Packet Transport with TLS 1.3 Integration
  @! Construct genuine STREAM frame payload
  http3_req = [0x00, 0x00, 0x2F, 0x61, 0x70, 0x69, 0x2F, 0x76, 0x31, 0x2F, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73] @! "/api/v1/status"
  inner_stream_frame = quic_frame_encode_stream(0, 0, http3_req, 1)
  
  @! Encrypt inner frame using TLS 1.3 AES-GCM/CTR
  tls_pt_key = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32]
  tls_pt_nonce = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]
  encrypted_frame_payload = aes256_ctr_encrypt(tls_pt_key, tls_pt_nonce, inner_stream_frame)
  
  @! Pack into 1-RTT Short Header Packet
  client_cid = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  rtt1_pkt = quic_pack_short_header(client_cid, 1, 2, 0, 0, encrypted_frame_payload)
  assert_ge_int(state, rtt1_pkt.len(), encrypted_frame_payload.len() + 10, "T3.3.1", "1-RTT Encrypted Packet packed")

  @! Unpack and Decrypt
  unpacked_1rtt = quic_unpack_packet(rtt1_pkt, 0, client_cid.len())
  assert_eq_int(state, unpacked_1rtt.packet_type, QUIC_PKT_1RTT(), "T3.3.2", "Unpacked packet type is 1-RTT")
  assert_eq_array(state, unpacked_1rtt.packet_payload, encrypted_frame_payload, "T3.3.3", "Payload is encrypted ciphertext")

  decrypted_frame_payload = aes256_ctr_decrypt(tls_pt_key, tls_pt_nonce, unpacked_1rtt.packet_payload)
  assert_eq_array(state, decrypted_frame_payload, inner_stream_frame, "T3.3.4", "Decrypted payload exactly matches inner STREAM frame")

  parsed_stream_frames = quic_parse_frames(decrypted_frame_payload, 0, decrypted_frame_payload.len())
  assert_eq_int(state, parsed_stream_frames.len(), 1, "T3.3.5", "Parsed decrypted payload contains 1 frame")
  rec_f = parsed_stream_frames[0]
  assert_eq_int(state, rec_f.frame_type, QUIC_FRAME_STREAM(), "T3.3.6", "Decrypted frame is STREAM")
  assert_eq_int(state, rec_f.frame_stream_id, 0, "T3.3.7", "Decrypted STREAM stream_id == 0")
  assert_eq_array(state, rec_f.frame_data, http3_req, "T3.3.8", "Decrypted HTTP/3 request payload verified")

  @! 3.4 Connection Lifecycle Transitions (INITIAL -> HANDSHAKE -> ESTABLISHED -> CLOSED)
  server_cid = [0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]
  conn = quic_connection_new(client_cid, server_cid)
  assert_eq_str(state, conn.conn_state, "INITIAL", "T3.4.1", "Connection initialized in state INITIAL")
  assert_eq_int(state, conn.handshake_done, 0, "T3.4.2", "Handshake not done initially")

  @! Generate Initial Packet with Datagram Padding
  client_hello_bytes = [22, 3, 3, 0, 50, 1]
  init_pkt = quic_connection_create_initial_packet(conn, client_hello_bytes)
  assert_ge_int(state, init_pkt.len(), 1200, "T3.4.3", "Initial packet datagram padded to >= 1200 bytes (RFC 9000 §14.1)")

  @! Ingest ServerHello -> State becomes HANDSHAKE
  srv_hello_f = quic_frame_encode_crypto(0, [22, 3, 3, 0, 70, 2])
  srv_hello_pkt = quic_pack_long_header(QUIC_PKT_INITIAL(), QUIC_VERSION_1(), client_cid, server_cid, [], 0, 2, srv_hello_f)
  conn = quic_connection_process_packet(conn, srv_hello_pkt)
  assert_eq_str(state, conn.conn_state, "HANDSHAKE", "T3.4.4", "State transitioned to HANDSHAKE after ServerHello")

  @! Ingest Server Handshake Finished -> State becomes ESTABLISHED
  srv_fin_f = quic_frame_encode_crypto(0, [22, 3, 3, 0, 32, 20])
  srv_fin_pkt = quic_pack_long_header(QUIC_PKT_HANDSHAKE(), QUIC_VERSION_1(), client_cid, server_cid, [], 1, 2, srv_fin_f)
  conn = quic_connection_process_packet(conn, srv_fin_pkt)
  assert_eq_str(state, conn.conn_state, "ESTABLISHED", "T3.4.5", "State transitioned to ESTABLISHED after Handshake Finished")
  assert_eq_int(state, conn.handshake_done, 1, "T3.4.6", "Handshake marked confirmed (handshake_done = 1)")

  @! Terminate connection via close
  close_pkt_out = quic_connection_close(conn, 0, "Test complete")
  assert_eq_str(state, conn.conn_state, "CLOSED", "T3.4.7", "State transitioned to CLOSED upon close")

  @! 3.5 RFC 9002 Congestion Control Window Dynamics
  c_test = quic_connection_new(client_cid, server_cid)
  init_cwnd = c_test.congestion.cwnd
  assert_eq_int(state, init_cwnd, 14720, "T3.5.1", "Initial cwnd == 14720 (10 * 1472 MSS)")
  assert_eq_int(state, c_test.congestion.ssthresh, 65535, "T3.5.2", "Initial ssthresh == 65535")

  @! Slow Start Growth: each ACK increases cwnd by MSS (1472)
  quic_connection_on_ack_received(c_test, 1, 0, 20)
  assert_eq_int(state, c_test.congestion.cwnd, init_cwnd + 1472, "T3.5.3", "Slow start increases cwnd by 1472 on ACK 1")
  assert_eq_int(state, c_test.congestion.min_rtt, 20, "T3.5.4", "min_rtt recorded as 20ms")

  quic_connection_on_ack_received(c_test, 2, 0, 16)
  assert_eq_int(state, c_test.congestion.cwnd, init_cwnd + 2944, "T3.5.5", "Slow start increases cwnd by 2944 on ACK 2")
  assert_eq_int(state, c_test.congestion.min_rtt, 16, "T3.5.6", "min_rtt updated to 16ms")

  @! Congestion Event: Multiplicative Decrease
  cur_cwnd = c_test.congestion.cwnd
  quic_connection_on_congestion_event(c_test)
  expected_ssthresh = cur_cwnd / 2
  assert_eq_int(state, c_test.congestion.ssthresh, expected_ssthresh, "T3.5.7", "ssthresh reduced to cwnd / 2 on packet loss")
  assert_eq_int(state, c_test.congestion.cwnd, expected_ssthresh, "T3.5.8", "cwnd reduced to ssthresh (multiplicative decrease)")
@end

@! ============================================================================
@! TIER 4: REAL-WORLD END-TO-END CLIENT-SERVER SIMULATED SESSION
@! ============================================================================

@fn run_tier4_e2e_session(state: TestState)
  println("\n-----------------------------------------------------------------")
  println("▶ [TIER 4] REAL-WORLD QUIC CLIENT-SERVER E2E SESSION SCENARIO")
  println("-----------------------------------------------------------------")

  @! Setup Simulated Client and Server Nodes
  c_cid = [0xC1, 0x00, 0x01, 0x02]
  s_cid = [0x5E, 0x00, 0x01, 0x02]

  client = quic_connection_new(c_cid, s_cid)
  server = quic_connection_new(s_cid, c_cid)

  assert_eq_str(state, client.conn_state, "INITIAL", "T4.1.1", "Client initialized")
  assert_eq_str(state, server.conn_state, "INITIAL", "T4.1.2", "Server initialized")

  @! Step 1: Client sends Initial Packet with ClientHello
  ch_payload = [0x01, 0x00, 0x01, 0x00, 0x03, 0x03] @! Synthetic ClientHello
  client_init_pkt = quic_connection_create_initial_packet(client, ch_payload)
  assert_ge_int(state, client_init_pkt.len(), 1200, "T4.1.3", "Client Initial packet >= 1200 bytes")

  @! Server receives Client Initial packet -> transitions to HANDSHAKE
  server = quic_connection_process_packet(server, client_init_pkt)
  assert_eq_str(state, server.conn_state, "HANDSHAKE", "T4.1.4", "Server state transitioned to HANDSHAKE")

  @! Step 2: Server sends Handshake Packet with ServerHello & Handshake Finished
  sh_payload = [0x02, 0x00, 0x00, 0x46, 0x03, 0x03] @! Synthetic ServerHello
  server_hs_pkt = quic_connection_create_handshake_packet(server, sh_payload)
  
  @! Client receives Server Handshake packet -> transitions to HANDSHAKE
  client = quic_connection_process_packet(client, server_hs_pkt)
  assert_eq_str(state, client.conn_state, "HANDSHAKE", "T4.1.5", "Client state transitioned to HANDSHAKE")

  @! Server completes handshake confirmation
  server_fin_payload = [0x14, 0x00, 0x00, 0x20] @! Synthetic Finished
  server_fin_pkt = quic_connection_create_handshake_packet(server, server_fin_payload)
  client = quic_connection_process_packet(client, server_fin_pkt)
  assert_eq_str(state, client.conn_state, "ESTABLISHED", "T4.1.6", "Client state established (Handshake confirmed)")
  assert_eq_int(state, client.handshake_done, 1, "T4.1.7", "Client handshake_done == 1")

  @! Server finishes handshake
  client_fin_pkt = quic_connection_create_handshake_packet(client, server_fin_payload)
  server = quic_connection_process_packet(server, client_fin_pkt)
  assert_eq_str(state, server.conn_state, "ESTABLISHED", "T4.1.8", "Server state established (Handshake confirmed)")
  assert_eq_int(state, server.handshake_done, 1, "T4.1.9", "Server handshake_done == 1")

  @! Step 3: Bidirectional 1-RTT Stream Data Multiplexing
  @! Client sends Stream 0 (GET /index.html) and Stream 4 (GET /favicon.ico)
  req_s0 = [71, 69, 84, 32, 47, 105, 110, 100, 101, 120, 46, 104, 116, 109, 108] @! "GET /index.html"
  req_s4 = [71, 69, 84, 32, 47, 102, 97, 118, 105, 99, 111, 110, 46, 105, 99, 111] @! "GET /favicon.ico"

  pkt_s0 = quic_connection_send_stream(client, 0, req_s0, 1)
  pkt_s4 = quic_connection_send_stream(client, 4, req_s4, 1)

  @! Server processes both stream packets
  server = quic_connection_process_packet(server, pkt_s0)
  server = quic_connection_process_packet(server, pkt_s4)

  assert_eq_int(state, server.streams.len(), 2, "T4.2.1", "Server demuxed and opened 2 concurrent streams")
  st0 = server.streams[0]
  st4 = server.streams[1]
  assert_eq_int(state, st0.stream_id, 0, "T4.2.2", "Stream 0 registered")
  assert_eq_array(state, st0.stream_recv_buf, req_s0, "T4.2.3", "Stream 0 received full HTTP GET request")
  assert_eq_int(state, st0.stream_fin_recv, 1, "T4.2.4", "Stream 0 FIN received")

  assert_eq_int(state, st4.stream_id, 4, "T4.2.5", "Stream 4 registered")
  assert_eq_array(state, st4.stream_recv_buf, req_s4, "T4.2.6", "Stream 4 received full HTTP GET request")
  assert_eq_int(state, st4.stream_fin_recv, 1, "T4.2.7", "Stream 4 FIN received")

  @! Step 4: Path Migration & Challenge-Response
  path_secret = [0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04]
  p_chal_frame = quic_frame_encode_path_challenge(path_secret)
  p_chal_pkt = quic_pack_short_header(c_cid, 99, 2, 0, 0, p_chal_frame)

  @! Client receives path challenge
  client = quic_connection_process_packet(client, p_chal_pkt)
  assert_eq_int(state, client.queued_frames.len(), 1, "T4.3.1", "Client queued response frame")

  @! Client sends response back to server
  queued_resp = client.queued_frames[0]
  p_resp_pkt = quic_pack_short_header(s_cid, 100, 2, 0, 0, queued_resp)
  p_unpacked = quic_unpack_packet(p_resp_pkt, 0, s_cid.len())
  p_frames = quic_parse_frames(p_unpacked.packet_payload, 0, p_unpacked.packet_payload.len())
  assert_eq_int(state, p_frames.len(), 1, "T4.3.2", "Server received 1 frame")
  assert_eq_int(state, p_frames[0].frame_type, QUIC_FRAME_PATH_RESPONSE(), "T4.3.3", "Frame is PATH_RESPONSE")
  assert_eq_array(state, p_frames[0].frame_data, path_secret, "T4.3.4", "Path response echoed exact 8-byte secret")

  @! Step 5: Graceful Session Teardown
  close_pkt = quic_frame_encode_connection_close(0, 0, "Graceful Session Teardown", 1)
  close_wire = quic_pack_short_header(c_cid, 101, 2, 0, 0, close_pkt)
  client = quic_connection_process_packet(client, close_wire)
  assert_eq_str(state, client.conn_state, "CLOSED", "T4.4.1", "Client session cleanly transitioned to CLOSED")
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🌐 MAYA UNIVERSAL ARCHITECTURE: QUIC RFC 9000 & TLS 1.3 E2E 🌐")
  println("=================================================================")

  let state = { total: 0, passed: 0, failed: 0 }

  run_tier1_features(state)
  run_tier2_boundaries(state)
  run_tier3_crypto_and_state(state)
  run_tier4_e2e_session(state)

  println("\n=================================================================")
  println("QUIC E2E SUITE RESULTS: " + state.passed.to_str() + "/" + state.total.to_str() + " assertions passed")
  println("=================================================================")

  @if state.failed == 0
    println("🎉 ALL QUIC PROTOCOL & TLS 1.3 E2E TESTS PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ QUIC E2E TEST SUITE FAILED (" + state.failed.to_str() + " failures)!")
    return 1
  @end
@end
