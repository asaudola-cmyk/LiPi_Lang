@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: WEBSOCKET RFC 6455 & CRYPTO HARDENING
@! File: tests/net/stress_test_websocket.maya
@! Empirical verification of multi-block SHA-1, Base64 arbitrary binary,
@! handshake edge cases, and frame decoder boundary / fragmentation conditions.
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("    [PASS] " + msg)
    return 1
  @else
    println("    [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("    [PASS] " + msg)
    return 1
  @else
    println("    [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("    [FAIL] Assertion failed: " + msg)
    return 0
  @end
  println("    [PASS] " + msg)
  return 1
@end

@fn make_repeated_string(ch: string, count: i64) -> string
  res = ""
  i = 0
  @while i < count
    res = res + ch
    i = i + 1
  @end
  return res
@end

@fn make_byte_sequence(count: i64) -> array
  arr = []
  i = 0
  @while i < count
    arr = arr.push((i % 256) & 255)
    i = i + 1
  @end
  return arr
@end

@fn main()
  println("================================================================================")
  println("🔥 ADVERSARIAL STRESS TEST: RFC 6455 WEBSOCKET & CRYPTO ENGINE 🔥")
  println("================================================================================")

  total_suites = 0
  passed_suites = 0

  @! ============================================================================
  @! SUITE 1: SHA-1 Multi-Block & Boundary Stress Testing
  @! ============================================================================
  println("▶ [Suite 1] SHA-1 Multi-Block Schedule & Boundary Stress...")
  total_suites = total_suites + 1
  s1_ok = 1

  @! 1.1 Single byte
  v_1a = sha1_hex_string("a")
  @if assert_eq_str(v_1a, "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8", "SHA-1 ('a', 1 byte)") == 0
    s1_ok = 0
  @end

  @! 1.2 Boundary 55 bytes (1 byte before 56-byte threshold)
  s_55 = make_repeated_string("A", 55)
  v_55 = sha1_hex_string(s_55)
  @if assert_eq_str(v_55, "5021b3d42aa093bffc34eedd7a1455f3624bc552", "SHA-1 ('A' * 55 bytes, exact 1-block threshold)") == 0
    s1_ok = 0
  @end

  @! 1.3 Boundary 56 bytes (crosses into 2nd block for padding)
  s_56 = make_repeated_string("A", 56)
  v_56 = sha1_hex_string(s_56)
  @if assert_eq_str(v_56, "6b45e3cf1eb3324b9fd4df3b83d89c4c2c4ca896", "SHA-1 ('A' * 56 bytes, triggers 2-block transition)") == 0
    s1_ok = 0
  @end

  @! 1.4 Boundary 63 bytes & 64 bytes (exact 1 full block)
  s_63 = make_repeated_string("A", 63)
  v_63 = sha1_hex_string(s_63)
  @if assert_eq_str(v_63, "0ec86b3f3ac34ad860fa8da56bcca03a54018049", "SHA-1 ('A' * 63 bytes)") == 0
    s1_ok = 0
  @end

  s_64 = make_repeated_string("A", 64)
  v_64 = sha1_hex_string(s_64)
  @if assert_eq_str(v_64, "30b86e44e6001403827a62c58b08893e77cf121f", "SHA-1 ('A' * 64 bytes, exact 1 block)") == 0
    s1_ok = 0
  @end

  @! 1.5 Boundary 65 bytes (crosses into block 2)
  s_65 = make_repeated_string("A", 65)
  v_65 = sha1_hex_string(s_65)
  @if assert_eq_str(v_65, "826b7e7a7af8a529ae1c7443c23bf185c0ad440c", "SHA-1 ('A' * 65 bytes, 2nd block start)") == 0
    s1_ok = 0
  @end

  @! 1.6 Boundary 119 bytes & 120 bytes (2-block boundary)
  s_119 = make_repeated_string("A", 119)
  v_119 = sha1_hex_string(s_119)
  @if assert_eq_str(v_119, "293e3964d2b4d4ba9d21991b8388283b4f09b935", "SHA-1 ('A' * 119 bytes)") == 0
    s1_ok = 0
  @end

  s_120 = make_repeated_string("A", 120)
  v_120 = sha1_hex_string(s_120)
  @if assert_eq_str(v_120, "a1298700a534e357b7130c74e277fe5428d43baf", "SHA-1 ('A' * 120 bytes, triggers 3-block transition)") == 0
    s1_ok = 0
  @end

  @! 1.7 Stress 500 bytes and 1000 bytes
  s_500 = make_repeated_string("A", 500)
  v_500 = sha1_hex_string(s_500)
  @if assert_eq_str(v_500, "a585706fac090f4198d5502c4760d1b4ca6e201c", "SHA-1 ('A' * 500 bytes, 8 blocks)") == 0
    s1_ok = 0
  @end

  s_1000 = make_repeated_string("A", 1000)
  v_1000 = sha1_hex_string(s_1000)
  @if assert_eq_str(v_1000, "3ae3644d6777a1f56a1defeabc74af9c4b313e49", "SHA-1 ('A' * 1000 bytes, 16 blocks)") == 0
    s1_ok = 0
  @end

  @! 1.8 Full 256 byte binary sequence (0..255)
  seq_256 = make_byte_sequence(256)
  v_256 = sha1_hex(seq_256)
  @if assert_eq_str(v_256, "4916d6bdb7f78e6803698cab32d1586ea457dfc8", "SHA-1 (all 256 raw byte values 0x00..0xFF)") == 0
    s1_ok = 0
  @end

  @! 1.9 Streaming incremental API verification (byte-by-byte update)
  ctx = sha1_init()
  c_i = 0
  @while c_i < 256
    ctx = sha1_update(ctx, [c_i])
    c_i = c_i + 1
  @end
  stream_digest = sha1_final(ctx)
  stream_hex = ""
  sh_i = 0
  @while sh_i < stream_digest.len()
    stream_hex = stream_hex + sha1_byte_to_hex(stream_digest[sh_i])
    sh_i = sh_i + 1
  @end
  @if assert_eq_str(stream_hex, "4916d6bdb7f78e6803698cab32d1586ea457dfc8", "SHA-1 streaming 256 single-byte updates matches one-shot") == 0
    s1_ok = 0
  @end

  @if s1_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUITE 2: Base64 Arbitrary Binary, Padding & Round-Trip Stress
  @! ============================================================================
  println("▶ [Suite 2] Base64 Arbitrary Binary, Padding & Round-Trip Stress...")
  total_suites = total_suites + 1
  s2_ok = 1

  @! 2.1 Padding variations
  @! 0 pad chars (len % 3 == 0)
  enc_0pad = base64_encode([0, 0, 0])
  @if assert_eq_str(enc_0pad, "AAAA", "Base64 encode [0, 0, 0] (0 pad chars)") == 0
    s2_ok = 0
  @end
  enc_ff0 = base64_encode([255, 255, 255])
  @if assert_eq_str(enc_ff0, "////", "Base64 encode [255, 255, 255] (0 pad chars)") == 0
    s2_ok = 0
  @end

  @! 1 pad char (len % 3 == 2)
  enc_1pad = base64_encode([0, 0])
  @if assert_eq_str(enc_1pad, "AAA=", "Base64 encode [0, 0] (1 pad char '=')") == 0
    s2_ok = 0
  @end
  enc_ff1 = base64_encode([255, 255])
  @if assert_eq_str(enc_ff1, "//8=", "Base64 encode [255, 255] (1 pad char '=')") == 0
    s2_ok = 0
  @end
  enc_plus = base64_encode([250, 0])
  @if assert_eq_str(enc_plus, "+gA=", "Base64 encode [250, 0] produces '+' and 1 pad char") == 0
    s2_ok = 0
  @end

  @! 2.2 2 pad chars (len % 3 == 1)
  enc_2pad = base64_encode([0])
  @if assert_eq_str(enc_2pad, "AA==", "Base64 encode [0] (2 pad chars '==')") == 0
    s2_ok = 0
  @end
  enc_ff2 = base64_encode([255])
  @if assert_eq_str(enc_ff2, "/w==", "Base64 encode [255] (2 pad chars '==')") == 0
    s2_ok = 0
  @end

  @! 2.3 256-Byte Arbitrary Binary Round-Trip
  enc_256 = base64_encode(seq_256)
  dec_256 = base64_decode(enc_256)
  @if assert_eq_int(dec_256.len(), 256, "Base64 decoded 256-byte sequence length") == 0
    s2_ok = 0
  @end

  roundtrip_match = 1
  chk_i = 0
  @while chk_i < 256
    @if dec_256[chk_i] != chk_i
      roundtrip_match = 0
    @end
    chk_i = chk_i + 1
  @end
  @if assert_true(roundtrip_match, "Base64 256-byte binary array round-trip byte-perfect equality (0x00..0xFF)") == 0
    s2_ok = 0
  @end

  @! 2.4 Base64 decoder with internal whitespace / newlines
  dirty_b64 = "Z m 9 v\r\n Y m F y"
  clean_dec = base64_decode_to_string(dirty_b64)
  @if assert_eq_str(clean_dec, "foobar", "Base64 decode handles embedded spaces and CRLF") == 0
    s2_ok = 0
  @end

  @if s2_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUITE 3: RFC 6455 Handshake & Sec-WebSocket-Accept Edge Cases
  @! ============================================================================
  println("▶ [Suite 3] RFC 6455 Handshake & Sec-WebSocket-Accept Edge Cases...")
  total_suites = total_suites + 1
  s3_ok = 1

  @! 3.1 Known handshake key derivations
  acc1 = generate_accept_key("dGhlIHNhbXBsZSBub25jZQ==")
  @if assert_eq_str(acc1, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "Accept key for standard nonce 1") == 0
    s3_ok = 0
  @end

  acc2 = generate_accept_key("x3JJHMbDL1EzLkh9GBhXDw==")
  @if assert_eq_str(acc2, "HSmrc0sMlYUkAGmm5OPpG2HaGWk=", "Accept key for standard nonce 2") == 0
    s3_ok = 0
  @end

  acc3 = generate_accept_key("AQIDBAUGBwgJCgsMDQ4PEA==")
  @if assert_eq_str(acc3, "C/0nmHhBztSRGR1CwL6Tf4ZjwpY=", "Accept key for sequential bytes key") == 0
    s3_ok = 0
  @end

  acc4 = generate_accept_key("MDEyMzQ1Njc4OTAxMjM0NQ==")
  @if assert_eq_str(acc4, "P3+O+KTP1uy8Ci2UqcLCOLcCw8Q=", "Accept key for ASCII digits key") == 0
    s3_ok = 0
  @end

  @! 3.2 Handshake request parser: Case-insensitivity & whitespace handling
  complex_req = "GET /ws/v1/chat?room=general&token=xyz HTTP/1.1\r\nHOST: example.com\r\nUPGRADE: websocket\r\nCONNECTION: Upgrade\r\nSEC-WEBSOCKET-KEY:   AQIDBAUGBwgJCgsMDQ4PEA==   \r\nSEC-WEBSOCKET-VERSION: 13\r\n\r\n"
  parsed_complex = ws_parse_http_handshake_request(complex_req)
  @if assert_eq_int(parsed_complex.is_valid, 1, "Handshake parses uppercase headers and trimmed values") == 0
    s3_ok = 0
  @end
  @if assert_eq_str(parsed_complex.path, "/ws/v1/chat?room=general&token=xyz", "Handshake preserves URL path and query string") == 0
    s3_ok = 0
  @end
  @if assert_eq_str(parsed_complex.sec_ws_key, "AQIDBAUGBwgJCgsMDQ4PEA==", "Handshake extracts trimmed Sec-WebSocket-Key") == 0
    s3_ok = 0
  @end

  @! 3.3 Handshake missing Sec-WebSocket-Key -> rejected
  invalid_req = "GET /chat HTTP/1.1\r\nHost: example.com\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
  parsed_inv = ws_parse_http_handshake_request(invalid_req)
  @if assert_eq_int(parsed_inv.is_valid, 0, "Handshake without Sec-WebSocket-Key is flagged invalid") == 0
    s3_ok = 0
  @end

  @if s3_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUITE 4: Frame Codec Extended Lengths & Boundary Stress
  @! ============================================================================
  println("▶ [Suite 4] Frame Codec Extended Lengths & Boundary Stress...")
  total_suites = total_suites + 1
  s4_ok = 1

  @! 4.1 Boundary: 125-byte payload (max 7-bit length)
  p_125 = make_byte_sequence(125)
  f_125 = ws_build_binary_frame(p_125, 0, [0, 0, 0, 0])
  @if assert_eq_int(f_125[1] & 127, 125, "125-byte payload encoded in 7-bit length") == 0
    s4_ok = 0
  @end
  d_125 = ws_decode_frame(f_125)
  @if assert_eq_int(d_125.payload_len, 125, "125-byte payload decoded length") == 0
    s4_ok = 0
  @end

  @! 4.2 Boundary: 126-byte payload (min 16-bit extended length)
  p_126 = make_byte_sequence(126)
  f_126 = ws_build_binary_frame(p_126, 0, [0, 0, 0, 0])
  @if assert_eq_int(f_126[1] & 127, 126, "126-byte payload encoded with length indicator 126") == 0
    s4_ok = 0
  @end
  d_126 = ws_decode_frame(f_126)
  @if assert_eq_int(d_126.payload_len, 126, "126-byte payload decoded length") == 0
    s4_ok = 0
  @end

  @! 4.3 1000-byte payload (16-bit extended length)
  p_1000 = make_byte_sequence(1000)
  f_1000 = ws_build_binary_frame(p_1000, 1, [10, 20, 30, 40])
  d_1000 = ws_decode_frame(f_1000)
  @if assert_eq_int(d_1000.payload_len, 1000, "1000-byte masked payload decoded length") == 0
    s4_ok = 0
  @end
  @if assert_eq_int(d_1000.payload_bytes[999], (999 % 256) & 255, "1000-byte masked payload unmasked last byte matches") == 0
    s4_ok = 0
  @end

  @! 4.4 64-bit Extended Length Frame parsing (70000 bytes header simulation)
  raw_64bit_full = []
  raw_64bit_full = raw_64bit_full.push(130)
  raw_64bit_full = raw_64bit_full.push(127)
  raw_64bit_full = raw_64bit_full.push(0)
  raw_64bit_full = raw_64bit_full.push(0)
  raw_64bit_full = raw_64bit_full.push(0)
  raw_64bit_full = raw_64bit_full.push(0)
  raw_64bit_full = raw_64bit_full.push(0)
  raw_64bit_full = raw_64bit_full.push(1)
  raw_64bit_full = raw_64bit_full.push(17)
  raw_64bit_full = raw_64bit_full.push(112)
  p_70k = make_byte_sequence(70000)
  k_i = 0
  @while k_i < 70000
    raw_64bit_full = raw_64bit_full.push(p_70k[k_i])
    k_i = k_i + 1
  @end
  d_64bit = ws_decode_frame(raw_64bit_full)
  @if assert_eq_int(d_64bit.is_valid, 1, "64-bit extended length frame decoded validly") == 0
    s4_ok = 0
  @end
  @if assert_eq_int(d_64bit.payload_len, 70000, "64-bit frame payload length == 70000") == 0
    s4_ok = 0
  @end

  @! 4.5 64-bit Extended Length Frame with MSB set -> must be rejected per RFC 6455 §5.2
  raw_64bit_invalid = [
    130, 127,
    128, 0, 0, 0, 0, 0, 0, 1,
    0
  ]
  d_msb = ws_decode_frame(raw_64bit_invalid)
  @if assert_eq_int(d_msb.is_valid, 0, "64-bit frame with MSB set is rejected") == 0
    s4_ok = 0
  @end

  @if s4_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUITE 5: Masking, Unmasking & Incomplete Frame Resiliency
  @! ============================================================================
  println("▶ [Suite 5] Masking, Unmasking & Incomplete Frame Resiliency...")
  total_suites = total_suites + 1
  s5_ok = 1

  @! 5.1 Adversarial mask keys
  raw_data = [0, 255, 128, 64, 32, 16, 8, 4]

  @! Identity mask [0, 0, 0, 0]
  mask_zero = [0, 0, 0, 0]
  masked_z = ws_mask_payload(raw_data, mask_zero)
  @if assert_eq_int(masked_z[1], 255, "Identity mask preserves 0xFF") == 0
    s5_ok = 0
  @end

  @! Inversion mask [255, 255, 255, 255]
  mask_inv = [255, 255, 255, 255]
  masked_inv = ws_mask_payload(raw_data, mask_inv)
  @if assert_eq_int(masked_inv[0], 255, "Inversion mask flips 0x00 to 0xFF") == 0
    s5_ok = 0
  @end
  @if assert_eq_int(masked_inv[1], 0, "Inversion mask flips 0xFF to 0x00") == 0
    s5_ok = 0
  @end

  unmasked_inv = ws_unmask_payload(masked_inv, mask_inv)
  @if assert_eq_int(unmasked_inv[0], 0, "Unmask restores original byte 0") == 0
    s5_ok = 0
  @end
  @if assert_eq_int(unmasked_inv[1], 255, "Unmask restores original byte 1") == 0
    s5_ok = 0
  @end

  @! 5.2 Decoder rejection on truncated inputs
  d_trunc1 = ws_decode_frame([129])
  @if assert_eq_int(d_trunc1.is_valid, 0, "Decoder rejects 1-byte truncated header") == 0
    s5_ok = 0
  @end

  d_trunc2 = ws_decode_frame([129, 126, 1])
  @if assert_eq_int(d_trunc2.is_valid, 0, "Decoder rejects truncated 16-bit length header") == 0
    s5_ok = 0
  @end

  d_trunc3 = ws_decode_frame([129, 129, 55, 250])
  @if assert_eq_int(d_trunc3.is_valid, 0, "Decoder rejects truncated mask key") == 0
    s5_ok = 0
  @end

  d_trunc4 = ws_decode_frame([129, 10, 1, 2, 3, 4, 5])
  @if assert_eq_int(d_trunc4.is_valid, 0, "Decoder rejects truncated payload") == 0
    s5_ok = 0
  @end

  @if s5_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUITE 6: Interleaved Control Frames in Fragmented Message Sequences
  @! ============================================================================
  println("▶ [Suite 6] Interleaved Control Frames in Fragmented Messages...")
  total_suites = total_suites + 1
  s6_ok = 1

  assembler = ws_fragment_assembler_new()

  @! Step 1: Fragment 1 (Text, FIN=0, Payload="Alpha ")
  f1_bytes = ws_encode_frame(0, ws_op_text(), 0, [0, 0, 0, 0], [65, 108, 112, 104, 97, 32])
  f1 = ws_decode_frame(f1_bytes)
  assembler = assembler.feed(f1)
  r1 = assembler.completed_frame
  @if assert_eq_int(r1.fin, 0, "Fragment 1 initiates assembly (FIN=0)") == 0
    s6_ok = 0
  @end

  @! Step 2: Interleaved Ping Control Frame (FIN=1, Opcode=9, Payload="ping1")
  ping_bytes = ws_encode_frame(1, ws_op_ping(), 0, [0, 0, 0, 0], [112, 105, 110, 103, 49])
  ping_frame = ws_decode_frame(ping_bytes)
  assembler = assembler.feed(ping_frame)
  r_ping = assembler.completed_frame
  @if assert_eq_int(r_ping.opcode, ws_op_ping(), "Interleaved Ping is returned immediately") == 0
    s6_ok = 0
  @end
  @if assert_eq_int(assembler.in_progress, 1, "Fragmentation assembly state is preserved across Ping") == 0
    s6_ok = 0
  @end

  @! Step 3: Fragment 2 (Continuation, FIN=0, Payload="Beta ")
  f2_bytes = ws_encode_frame(0, ws_op_continuation(), 0, [0, 0, 0, 0], [66, 101, 116, 97, 32])
  f2 = ws_decode_frame(f2_bytes)
  assembler = assembler.feed(f2)
  r2 = assembler.completed_frame
  @if assert_eq_int(r2.fin, 0, "Fragment 2 continues assembly (FIN=0)") == 0
    s6_ok = 0
  @end

  @! Step 4: Interleaved Pong Control Frame (FIN=1, Opcode=10, Payload="pong1")
  pong_bytes = ws_encode_frame(1, ws_op_pong(), 0, [0, 0, 0, 0], [112, 111, 110, 103, 49])
  pong_frame = ws_decode_frame(pong_bytes)
  assembler = assembler.feed(pong_frame)
  r_pong = assembler.completed_frame
  @if assert_eq_int(r_pong.opcode, ws_op_pong(), "Interleaved Pong is returned immediately") == 0
    s6_ok = 0
  @end
  @if assert_eq_int(assembler.in_progress, 1, "Fragmentation assembly state is preserved across Pong") == 0
    s6_ok = 0
  @end

  @! Step 5: Fragment 3 (Continuation, FIN=1, Payload="Gamma")
  f3_bytes = ws_encode_frame(1, ws_op_continuation(), 0, [0, 0, 0, 0], [71, 97, 109, 109, 97])
  f3 = ws_decode_frame(f3_bytes)
  assembler = assembler.feed(f3)
  r_final = assembler.completed_frame
  @if assert_eq_int(r_final.fin, 1, "Final fragment completes assembly (FIN=1)") == 0
    s6_ok = 0
  @end
  @if assert_eq_int(r_final.opcode, ws_op_text(), "Assembled message opcode restored to Text (1)") == 0
    s6_ok = 0
  @end
  @if assert_eq_str(r_final.payload_text, "Alpha Beta Gamma", "Reassembled text message payload across interleaved control frames") == 0
    s6_ok = 0
  @end
  @if assert_eq_int(assembler.in_progress, 0, "Assembler state reset to idle after completion") == 0
    s6_ok = 0
  @end

  @if s6_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ============================================================================
  @! SUMMARY & VERDICT
  @! ============================================================================
  println("================================================================================")
  println("📊 ADVERSARIAL STRESS RESULTS: " + passed_suites.to_str() + " / " + total_suites.to_str() + " suites passed")
  println("================================================================================")

  @if passed_suites == total_suites
    println("🏆 VERDICT: APPROVE — ALL ADVERSARIAL & EDGE CASE STRESS TESTS PASSED! 🏆")
    return 0
  @else
    println("💥 VERDICT: REQUEST_CHANGES — REGRESSIONS OR FAILURES DETECTED 💥")
    return 1
  @end
@end
