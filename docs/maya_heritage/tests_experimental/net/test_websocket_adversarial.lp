// @! RUN: %maya %file
// @! EXPECT: 🎉 ALL 7 WEBSOCKET & CRYPTO ADVERSARIAL TEST SUITES PASSED! 🎉
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: net, websocket, adversarial, rfc6455, fragmentation, limits

@! ============================================================================
@! MAYA WEBSOCKET & CRYPTO ADVERSARIAL STRESS TEST SUITE
@! File: tests/net/test_websocket_adversarial.maya
@! Empirical challenger test harness for Phase 4 Web Subsystem
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/net/websocket"

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
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

@fn main()
  println("=================================================================")
  println("⚡ MAYA RFC 6455 WEBSOCKET & CRYPTO ADVERSARIAL STRESS SUITE ⚡")
  println("=================================================================")

  total_suites = 0
  passed_suites = 0

  @! ----------------------------------------------------------------------------
  @! SUITE 1: SHA-1 Multi-Block & Critical Boundary Stress Testing
  @! ----------------------------------------------------------------------------
  println("▶ Suite 1: SHA-1 Multi-Block Schedules & Buffer Boundary Invariants...")
  total_suites = total_suites + 1
  s1_ok = 1

  @! 1.1 Boundary: 55 bytes ('a' * 55) -> exactly 1 block after 0x80 and 8-byte length
  s55 = make_repeated_string("a", 55)
  h55 = sha1_hex_string(s55)
  @if assert_eq_str(h55, "c1c8bbdc22796e28c0e15163d20899b65621d65a", "SHA-1 55-byte boundary (1 block)") == 0
    s1_ok = 0
  @end

  @! 1.2 Boundary: 56 bytes ('a' * 56) -> spills into 2 blocks (56 + 1 + 8 > 64)
  s56 = make_repeated_string("a", 56)
  h56 = sha1_hex_string(s56)
  @if assert_eq_str(h56, "c2db330f6083854c99d4b5bfb6e8f29f201be699", "SHA-1 56-byte boundary (2 blocks)") == 0
    s1_ok = 0
  @end

  @! 1.3 Boundary: 64 bytes ('a' * 64) -> exactly one 64-byte block, padding in next block
  s64 = make_repeated_string("a", 64)
  h64 = sha1_hex_string(s64)
  @if assert_eq_str(h64, "0098ba824b5c16427bd7a1122a5a442a25ec644d", "SHA-1 64-byte full block boundary") == 0
    s1_ok = 0
  @end

  @! 1.4 Boundary: 65 bytes ('a' * 65) -> 1 full block + 1 byte in second block
  s65 = make_repeated_string("a", 65)
  h65 = sha1_hex_string(s65)
  @if assert_eq_str(h65, "11655326c708d70319be2610e8a57d9a5b959d3b", "SHA-1 65-byte boundary") == 0
    s1_ok = 0
  @end

  @! 1.5 Boundary: 119 bytes ('a' * 119) -> 2 blocks boundary
  s119 = make_repeated_string("a", 119)
  h119 = sha1_hex_string(s119)
  @if assert_eq_str(h119, "ee971065aaa017e0632a8ca6c77bb3bf8b1dfc56", "SHA-1 119-byte 2-block boundary") == 0
    s1_ok = 0
  @end

  @! 1.6 Boundary: 120 bytes ('a' * 120) -> spills into 3 blocks
  s120 = make_repeated_string("a", 120)
  h120 = sha1_hex_string(s120)
  @if assert_eq_str(h120, "f34c1488385346a55709ba056ddd08280dd4c6d6", "SHA-1 120-byte 3-block boundary") == 0
    s1_ok = 0
  @end

  @! 1.7 Boundary: 128 bytes ('a' * 128) -> exactly 2 blocks
  s128 = make_repeated_string("a", 128)
  h128 = sha1_hex_string(s128)
  @if assert_eq_str(h128, "ad5b3fdbcb526778c2839d2f151ea753995e26a0", "SHA-1 128-byte 2-full-block boundary") == 0
    s1_ok = 0
  @end

  @! 1.8 500-byte string schedule stress
  s500 = make_repeated_string("a", 500)
  h500 = sha1_hex_string(s500)
  @if assert_eq_str(h500, "e62ca5609e96073ffdc80ad480510d6de0a13f3e", "SHA-1 500-byte multi-block schedule") == 0
    s1_ok = 0
  @end

  @! 1.9 1000-byte string schedule stress
  s1000 = make_repeated_string("a", 1000)
  h1000 = sha1_hex_string(s1000)
  @if assert_eq_str(h1000, "291e9a6c66994949b57ba5e650361e98fc36b1ba", "SHA-1 1000-byte multi-block schedule") == 0
    s1_ok = 0
  @end

  @! 1.10 Binary hash with embedded nulls and 0xFF
  bin_data = [0, 255, 0, 255, 128, 64, 32, 16, 8, 4, 2, 1, 0]
  h_bin = sha1_hex(bin_data)
  @if assert_eq_str(h_bin, "58c526f6f039c972c8ebd650ea0c13e7d30da2a6", "SHA-1 binary array with 0x00 and 0xFF") == 0
    s1_ok = 0
  @end

  @! 1.11 Streaming incremental hash matches one-shot hash
  ctx = sha1_init()
  st_i = 0
  @while st_i < 70
    ctx = sha1_update(ctx, [97]) @! 'a'
    st_i = st_i + 1
  @end
  stream_digest = sha1_final(ctx)
  stream_hex = ""
  sh_i = 0
  @while sh_i < stream_digest.len()
    stream_hex = stream_hex + sha1_byte_to_hex(stream_digest[sh_i] & 255)
    sh_i = sh_i + 1
  @end
  s70 = make_repeated_string("a", 70)
  oneshot_hex = sha1_hex_string(s70)
  @if assert_eq_str(stream_hex, oneshot_hex, "SHA-1 1-byte incremental stream equals one-shot hash") == 0
    s1_ok = 0
  @end

  @if s1_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 2: RFC 4648 Base64 Binary Invariance & Padding Stress
  @! ----------------------------------------------------------------------------
  println("▶ Suite 2: RFC 4648 Base64 Codec Padding & Binary Byte Stress...")
  total_suites = total_suites + 1
  s2_ok = 1

  @! 2.1 Remainder 0 (No padding)
  enc0 = base64_encode([1, 2, 3, 4, 5, 6])
  dec0 = base64_decode(enc0)
  @if assert_eq_int(dec0.len(), 6, "Base64 0-pad decode length") == 0 || assert_eq_int(dec0[0], 1, "Base64 0-pad byte 0") == 0 || assert_eq_int(dec0[5], 6, "Base64 0-pad byte 5") == 0
    s2_ok = 0
  @end

  @! 2.2 Remainder 1 (2 pad '=' characters)
  enc1 = base64_encode([72]) @! 'H' -> "SA=="
  @if assert_eq_str(enc1, "SA==", "Base64 2-pad encoding 'H' -> 'SA=='") == 0
    s2_ok = 0
  @end
  dec1 = base64_decode(enc1)
  @if assert_eq_int(dec1.len(), 1, "Base64 2-pad decode length") == 0 || assert_eq_int(dec1[0], 72, "Base64 2-pad byte 0") == 0
    s2_ok = 0
  @end

  @! 2.3 Remainder 2 (1 pad '=' character)
  enc2 = base64_encode([72, 101]) @! 'He' -> "SGU="
  @if assert_eq_str(enc2, "SGU=", "Base64 1-pad encoding 'He' -> 'SGU='") == 0
    s2_ok = 0
  @end
  dec2 = base64_decode(enc2)
  @if assert_eq_int(dec2.len(), 2, "Base64 1-pad decode length") == 0 || assert_eq_int(dec2[1], 101, "Base64 1-pad byte 1") == 0
    s2_ok = 0
  @end

  @! 2.4 Binary array with nulls & extreme bytes: [0, 255, 0, 255, 128, 64, 32, 16, 8, 4, 2, 1, 0]
  enc_bin = base64_encode(bin_data)
  @if assert_eq_str(enc_bin, "AP8A/4BAIBAIBAIBAA==", "Base64 encode binary array with nulls and 0xFF") == 0
    s2_ok = 0
  @end
  dec_bin = base64_decode(enc_bin)
  @if assert_eq_int(dec_bin.len(), bin_data.len(), "Base64 decode binary array length") == 0
    s2_ok = 0
  @else
    b_match = 1
    chk_i = 0
    @while chk_i < bin_data.len()
      @if dec_bin[chk_i] != bin_data[chk_i]
        b_match = 0
      @end
      chk_i = chk_i + 1
    @end
    @if assert_eq_int(b_match, 1, "Base64 roundtrip binary exact byte match") == 0
      s2_ok = 0
    @end
  @end

  @! 2.5 All 256 byte values roundtrip
  all_256 = []
  a_i = 0
  @while a_i < 256
    all_256 = all_256.push(a_i)
    a_i = a_i + 1
  @end
  enc_256 = base64_encode(all_256)
  dec_256 = base64_decode(enc_256)
  @if assert_eq_int(dec_256.len(), 256, "Base64 256 full byte range roundtrip length") == 0
    s2_ok = 0
  @else
    full_match = 1
    f_i = 0
    @while f_i < 256
      @if dec_256[f_i] != f_i
        full_match = 0
      @end
      f_i = f_i + 1
    @end
    @if assert_eq_int(full_match, 1, "Base64 0..255 all byte values preserved perfectly") == 0
      s2_ok = 0
    @end
  @end

  @if s2_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 3: RFC 6455 Handshake & HTTP Request Parser Stress
  @! ----------------------------------------------------------------------------
  println("▶ Suite 3: RFC 6455 Handshake Acceptance & Parser Adversarial Stress...")
  total_suites = total_suites + 1
  s3_ok = 1

  @! 3.1 Random 16-byte nonce Base64 keys
  k1_acc = generate_accept_key("AQIDBAUGBwgJCgsMDQ4PEA==")
  @if assert_eq_str(k1_acc, "C/0nmHhBztSRGR1CwL6Tf4ZjwpY=", "Handshake Accept Key for binary nonce 1") == 0
    s3_ok = 0
  @end

  k2_acc = generate_accept_key("dGVzdGtleTEyMzQ1Njc4OQ==")
  @if assert_eq_str(k2_acc, "t7Ygrscr4enmqbR+yDY3RMEyo7M=", "Handshake Accept Key for 'testkey123456789'") == 0
    s3_ok = 0
  @end

  @! 3.2 Handshake Parser: Mixed case header names & query string paths
  req_adv = "GET /ws/live?stream=audio&codec=opus HTTP/1.1\r\n"
  req_adv = req_adv + "HOST: socket.maya.org\r\n"
  req_adv = req_adv + "UPGRADE: websocket\r\n"
  req_adv = req_adv + "CONNECTION: Upgrade, keep-alive\r\n"
  req_adv = req_adv + "SEC-WEBSOCKET-KEY:  AQIDBAUGBwgJCgsMDQ4PEA==  \r\n"
  req_adv = req_adv + "SEC-WEBSOCKET-VERSION: 13\r\n\r\n"

  parsed_adv = ws_parse_http_handshake_request(req_adv)
  @if assert_eq_int(parsed_adv.is_valid, 1, "Handshake parser accepts mixed-case headers") == 0 || assert_eq_str(parsed_adv.path, "/ws/live?stream=audio&codec=opus", "Handshake parser extracts query path") == 0 || assert_eq_str(parsed_adv.sec_ws_key, "AQIDBAUGBwgJCgsMDQ4PEA==", "Handshake parser trims whitespace from key") == 0
    s3_ok = 0
  @end

  @! 3.3 Handshake Parser: Invalid request without Sec-WebSocket-Key
  req_invalid = "GET /ws HTTP/1.1\r\nHost: socket.maya.org\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
  parsed_inv = ws_parse_http_handshake_request(req_invalid)
  @if assert_eq_int(parsed_inv.is_valid, 0, "Handshake parser rejects request missing Sec-WebSocket-Key") == 0
    s3_ok = 0
  @end

  @if s3_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 4: Frame Codec Extended Lengths & Boundary Stress (16-bit & 64-bit)
  @! ----------------------------------------------------------------------------
  println("▶ Suite 4: Frame Codec Extended Lengths & Boundary Stress...")
  total_suites = total_suites + 1
  s4_ok = 1

  @! 4.1 Boundary length: 125 bytes (Maximum 7-bit payload length)
  p125 = []
  i = 0
  @while i < 125
    p125 = p125.push(i % 100)
    i = i + 1
  @end
  enc_125 = ws_build_binary_frame(p125, 0, [0, 0, 0, 0])
  @if assert_eq_int(enc_125[1] & 127, 125, "Frame length indicator for 125 bytes is 125 (7-bit)") == 0
    s4_ok = 0
  @end
  dec_125 = ws_decode_frame(enc_125)
  @if assert_eq_int(dec_125.payload_len, 125, "Decoded 125-byte frame length") == 0
    s4_ok = 0
  @end

  @! 4.2 Boundary length: 126 bytes (Minimum 16-bit payload length)
  p126 = []
  i = 0
  @while i < 126
    p126 = p126.push(i % 100)
    i = i + 1
  @end
  enc_126 = ws_build_binary_frame(p126, 0, [0, 0, 0, 0])
  @if assert_eq_int(enc_126[1] & 127, 126, "Frame length indicator for 126 bytes is 126 (16-bit)") == 0
    s4_ok = 0
  @end
  dec_126 = ws_decode_frame(enc_126)
  @if assert_eq_int(dec_126.payload_len, 126, "Decoded 126-byte frame length") == 0
    s4_ok = 0
  @end

  @! 4.3 Boundary length: 65535 bytes (Maximum 16-bit payload length)
  @! Test synthetic 16-bit frame with length 65535
  fake_65535_header = [130, 126, 255, 255] @! Opcode 2, len 65535, unmasked
  @! Truncated test for 65535 without payload
  dec_trunc = ws_decode_frame(fake_65535_header)
  @if assert_eq_int(dec_trunc.is_valid, 0, "Truncated 65535-byte frame safely rejected") == 0
    s4_ok = 0
  @end

  @! 4.4 64-bit Extended Length Frame: 65536 bytes header verification
  @! Construct 64-bit length header for 65536 bytes (0x0000000000010000)
  fake_65536_header = [130, 127, 0, 0, 0, 0, 0, 1, 0, 0]
  dec_65536_trunc = ws_decode_frame(fake_65536_header)
  @if assert_eq_int(dec_65536_trunc.is_valid, 0, "Truncated 65536-byte 64-bit frame safely rejected") == 0
    s4_ok = 0
  @end

  @! 4.5 RFC 6455 §5.2 MSB violation in 64-bit length MUST be rejected
  @! Set bit 63 in 64-bit length (0x8000000000000000)
  invalid_msb_header = [130, 127, 128, 0, 0, 0, 0, 0, 0, 0]
  dec_msb = ws_decode_frame(invalid_msb_header)
  @if assert_eq_int(dec_msb.is_valid, 0, "64-bit length with MSB=1 rejected per RFC 6455 Section 5.2") == 0
    s4_ok = 0
  @end

  @! 4.6 Header underflow / malformed frame handling
  dec_empty = ws_decode_frame([])
  @if assert_eq_int(dec_empty.is_valid, 0, "Empty raw byte array rejected") == 0
    s4_ok = 0
  @end

  dec_one = ws_decode_frame([129])
  @if assert_eq_int(dec_one.is_valid, 0, "1-byte raw frame rejected") == 0
    s4_ok = 0
  @end

  @if s4_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 5: Masking & Unmasking Symmetrical Fuzzing
  @! ----------------------------------------------------------------------------
  println("▶ Suite 5: Masking / Unmasking Mathematical Symmetry & Fuzzing...")
  total_suites = total_suites + 1
  s5_ok = 1

  mask1 = [170, 85, 204, 51] @! 0xAA, 0x55, 0xCC, 0x33
  data_orig = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]
  masked_d = ws_mask_payload(data_orig, mask1)
  unmasked_d = ws_unmask_payload(masked_d, mask1)
  @if assert_eq_int(unmasked_d.len(), data_orig.len(), "Unmasked length matches original") == 0
    s5_ok = 0
  @else
    eq_d = 1
    d_i = 0
    @while d_i < data_orig.len()
      @if unmasked_d[d_i] != data_orig[d_i]
        eq_d = 0
      @end
      d_i = d_i + 1
    @end
    @if assert_eq_int(eq_d, 1, "XOR masking and unmasking is perfectly symmetrical") == 0
      s5_ok = 0
    @end
  @end

  @! Masking with all-zero mask is identity
  zero_mask = [0, 0, 0, 0]
  masked_zero = ws_mask_payload(data_orig, zero_mask)
  @if assert_eq_int(masked_zero[0], data_orig[0], "Zero mask identity transformation byte 0") == 0 || assert_eq_int(masked_zero[5], data_orig[5], "Zero mask identity transformation byte 5") == 0
    s5_ok = 0
  @end

  @if s5_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 6: Multi-Frame Fragmentation & Interleaved Control Frames (RFC 6455 §5.4)
  @! ----------------------------------------------------------------------------
  println("▶ Suite 6: Multi-Frame Fragmentation & Interleaved Control Frames (RFC 6455 §5.4)...")
  total_suites = total_suites + 1
  s6_ok = 1

  assembler = ws_fragment_assembler_new()

  @! Step 1: Initial Text fragment (FIN=0, Opcode=Text, Payload="Alpha-")
  f1_bytes = ws_encode_frame(0, ws_op_text(), 0, [0, 0, 0, 0], [65, 108, 112, 104, 97, 45])
  f1 = ws_decode_frame(f1_bytes)
  assembler = assembler.feed(f1)
  @if assert_eq_int(assembler.in_progress, 1, "Assembler enters in_progress state on FIN=0") == 0 || assert_eq_int(assembler.initial_opcode, ws_op_text(), "Assembler locks initial opcode to Text (1)") == 0
    s6_ok = 0
  @end

  @! Step 2: Interleaved Ping Control Frame (FIN=1, Opcode=Ping, Payload=[99, 100])
  @! RFC 6455 §5.4: Control frames MAY be injected in the middle of a fragmented message.
  ping_bytes = ws_encode_frame(1, ws_op_ping(), 0, [0, 0, 0, 0], [99, 100])
  ping_f = ws_decode_frame(ping_bytes)
  assembler = assembler.feed(ping_f)
  ping_res = assembler.completed_frame
  @if assert_eq_int(ping_res.opcode, ws_op_ping(), "Interleaved Ping dispatched immediately") == 0 || assert_eq_int(assembler.in_progress, 1, "Assembler maintains fragmented stream in progress after Ping") == 0
    s6_ok = 0
  @end

  @! Step 3: Continuation fragment (FIN=0, Opcode=Continuation, Payload="Beta-")
  f2_bytes = ws_encode_frame(0, ws_op_continuation(), 0, [0, 0, 0, 0], [66, 101, 116, 97, 45])
  f2 = ws_decode_frame(f2_bytes)
  assembler = assembler.feed(f2)
  @if assert_eq_int(assembler.in_progress, 1, "Assembler remains in progress after middle continuation") == 0
    s6_ok = 0
  @end

  @! Step 4: Interleaved Pong Control Frame (FIN=1, Opcode=Pong, Payload=[101])
  pong_bytes = ws_encode_frame(1, ws_op_pong(), 0, [0, 0, 0, 0], [101])
  pong_f = ws_decode_frame(pong_bytes)
  assembler = assembler.feed(pong_f)
  pong_res = assembler.completed_frame
  @if assert_eq_int(pong_res.opcode, ws_op_pong(), "Interleaved Pong dispatched immediately") == 0 || assert_eq_int(assembler.in_progress, 1, "Assembler maintains fragmented stream in progress after Pong") == 0
    s6_ok = 0
  @end

  @! Step 5: Final Continuation fragment (FIN=1, Opcode=Continuation, Payload="Gamma")
  f3_bytes = ws_encode_frame(1, ws_op_continuation(), 0, [0, 0, 0, 0], [71, 97, 109, 109, 97])
  f3 = ws_decode_frame(f3_bytes)
  assembler = assembler.feed(f3)
  final_res = assembler.completed_frame
  @if assert_eq_int(assembler.in_progress, 0, "Assembler completes stream on FIN=1") == 0 || assert_eq_int(final_res.fin, 1, "Completed frame FIN bit == 1") == 0 || assert_eq_int(final_res.opcode, ws_op_text(), "Completed frame Opcode restored to Text (1)") == 0 || assert_eq_str(final_res.payload_text, "Alpha-Beta-Gamma", "Completed frame payload correctly assembled across interleaved control frames") == 0
    s6_ok = 0
  @end

  @if s6_ok == 1
    passed_suites = passed_suites + 1
  @end

  @! ----------------------------------------------------------------------------
  @! SUITE 7: WebSocket Close Status Codes & RFC 6455 Reason Extraction
  @! ----------------------------------------------------------------------------
  println("▶ Suite 7: WebSocket Close Status Codes & Reasons...")
  total_suites = total_suites + 1
  s7_ok = 1

  c_bytes = ws_build_close_frame(ws_close_protocol_error(), "Protocol Violation: RSV non-zero", 0, [0, 0, 0, 0])
  dec_c = ws_decode_frame(c_bytes)
  c_payload = ws_parse_close_payload(dec_c.payload_bytes)
  @if assert_eq_int(c_payload.status_code, 1002, "Close status code 1002 Protocol Error") == 0 || assert_eq_str(c_payload.reason, "Protocol Violation: RSV non-zero", "Close reason payload extracted") == 0
    s7_ok = 0
  @end

  @! Empty Close Frame defaults to 1005 (No Status Received)
  empty_c_payload = ws_parse_close_payload([])
  @if assert_eq_int(empty_c_payload.status_code, 1005, "Empty close payload defaults to 1005") == 0
    s7_ok = 0
  @end

  @if s7_ok == 1
    passed_suites = passed_suites + 1
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL STRESS RESULTS: " + passed_suites.to_str() + " / " + total_suites.to_str() + " suites passed")
  println("=================================================================")
  @if passed_suites == total_suites
    println("🎉 ALL 7 WEBSOCKET & CRYPTO ADVERSARIAL TEST SUITES PASSED! 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL STRESS SUITE DETECTED FAILURES")
    return 1
  @end
@end
