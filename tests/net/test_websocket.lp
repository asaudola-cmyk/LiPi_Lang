// @! RUN: %maya %file
// @! EXPECT: 🎉 ALL 6 WEBSOCKET & CRYPTO TEST SUITES PASSED! 🎉
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: net, websocket, rfc6455, sha1, base64

@! ============================================================================
@! MAYA WEBSOCKET RFC 6455 COMPREHENSIVE PROTOCOL TEST SUITE
@! File: tests/net/test_websocket.maya
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

@fn main()
  println("=================================================================")
  println("🌐 MAYA RFC 6455 WEBSOCKET & CRYPTO COMPREHENSIVE TEST SUITE 🌐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: FIPS 180-1 / RFC 3174 SHA-1 Vectors
  println("▶ Section 1: FIPS 180-1 SHA-1 Cryptographic Hash Vectors...")
  total_tests = total_tests + 1
  s1 = assert_eq_str(sha1_hex_string(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709", "SHA-1 empty string")
  s2 = assert_eq_str(sha1_hex_string("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d", "SHA-1 'abc'")
  s3 = assert_eq_str(sha1_hex_string("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"), "84983e441c3bd26ebaae4aa1f95129e5e54670f1", "SHA-1 multi-block string")
  @if s1 == 1 && s2 == 1 && s3 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 2: RFC 4648 Base64 Codec Vectors
  println("▶ Section 2: RFC 4648 Base64 Encoding & Decoding Vectors...")
  total_tests = total_tests + 1
  b1 = assert_eq_str(base64_encode_string("foo"), "Zm9v", "Base64 encode 'foo'")
  b2 = assert_eq_str(base64_encode_string("foobar"), "Zm9vYmFy", "Base64 encode 'foobar'")
  b3 = assert_eq_str(base64_decode_to_string("Zm9vYmFy"), "foobar", "Base64 decode 'Zm9vYmFy' -> 'foobar'")
  b4 = assert_eq_str(base64_decode_to_string("bWF5YQ=="), "maya", "Base64 decode with '==' padding")
  @if b1 == 1 && b2 == 1 && b3 == 1 && b4 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 3: RFC 6455 Handshake Accept Key Generation
  println("▶ Section 3: RFC 6455 Handshake Sec-WebSocket-Accept Vectors...")
  total_tests = total_tests + 1
  h1 = assert_eq_str(generate_accept_key("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "RFC 6455 Sec-WebSocket-Accept Vector 1")
  h2 = assert_eq_str(generate_accept_key("x3JJHMbDL1EzLkh9GBhXDw=="), "HSmrc0sMlYUkAGmm5OPpG2HaGWk=", "RFC 6455 Sec-WebSocket-Accept Vector 2")

  req_str = "GET /chat HTTP/1.1\r\nHost: server.example.com\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
  parsed_req = ws_parse_http_handshake_request(req_str)
  h3 = assert_eq_int(parsed_req.is_valid, 1, "HTTP Upgrade request validity")
  h4 = assert_eq_str(parsed_req.path, "/chat", "HTTP Upgrade request path")
  h5 = assert_eq_str(parsed_req.sec_ws_key, "dGhlIHNhbXBsZSBub25jZQ==", "HTTP Upgrade Sec-WebSocket-Key extracted")

  resp_str = ws_build_handshake_response(parsed_req.sec_ws_key)
  h6 = assert_true(str_index_of(resp_str, "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") >= 0, "HTTP 101 response contains valid accept key")
  @if h1 == 1 && h2 == 1 && h3 == 1 && h4 == 1 && h5 == 1 && h6 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 4: RFC 6455 Frame Codec (Decode & Encode)
  println("▶ Section 4: RFC 6455 Frame Decoding & Encoding Vectors...")
  total_tests = total_tests + 1

  @! Unmasked Text "Hello" (RFC 6455 Section 5.7 example)
  unmasked_hello = [129, 5, 72, 101, 108, 108, 111]
  f1 = ws_decode_frame(unmasked_hello)
  f1_ok1 = assert_eq_int(f1.fin, 1, "Unmasked text FIN bit")
  f1_ok2 = assert_eq_int(f1.opcode, ws_op_text(), "Unmasked text Opcode == 1")
  f1_ok3 = assert_eq_int(f1.masked, 0, "Unmasked text Masked == 0")
  f1_ok4 = assert_eq_int(f1.payload_len, 5, "Unmasked text payload length == 5")
  f1_ok5 = assert_eq_str(f1.payload_text, "Hello", "Unmasked text payload string")

  @! Masked Text "Hello" with key [55, 250, 33, 61] (RFC 6455 Section 5.7 example)
  masked_hello = [129, 133, 55, 250, 33, 61, 127, 159, 77, 81, 88]
  f2 = ws_decode_frame(masked_hello)
  f2_ok1 = assert_eq_int(f2.fin, 1, "Masked text FIN bit")
  f2_ok2 = assert_eq_int(f2.opcode, ws_op_text(), "Masked text Opcode == 1")
  f2_ok3 = assert_eq_int(f2.masked, 1, "Masked text Masked == 1")
  f2_ok4 = assert_eq_str(f2.payload_text, "Hello", "Masked text unmasked payload string")

  @! Encode unmasked text frame
  enc_text = ws_build_text_frame("Hello", 0, [0, 0, 0, 0])
  f3_ok = assert_eq_int(enc_text.len(), 7, "Encoded unmasked text frame length")

  @! 16-bit Extended Payload Length (300 bytes)
  large_payload = []
  lp_i = 0
  @while lp_i < 300
    large_payload = large_payload.push((lp_i % 256) & 255)
    lp_i = lp_i + 1
  @end
  enc_large = ws_build_binary_frame(large_payload, 0, [0, 0, 0, 0])
  f4_ok1 = assert_eq_int(enc_large[1] & 127, 126, "16-bit extended length indicator (126)")
  dec_large = ws_decode_frame(enc_large)
  f4_ok2 = assert_eq_int(dec_large.payload_len, 300, "Decoded 16-bit extended payload length")

  @if f1_ok1 == 1 && f1_ok2 == 1 && f1_ok3 == 1 && f1_ok4 == 1 && f1_ok5 == 1 && f2_ok1 == 1 && f2_ok2 == 1 && f2_ok3 == 1 && f2_ok4 == 1 && f3_ok == 1 && f4_ok1 == 1 && f4_ok2 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 5: Control Frames (Ping, Pong, Close)
  println("▶ Section 5: Control Frames (Ping, Pong, Close)...")
  total_tests = total_tests + 1

  ping_frame_bytes = ws_build_ping_frame([1, 2, 3, 4], 0, [0, 0, 0, 0])
  dec_ping = ws_decode_frame(ping_frame_bytes)
  c1 = assert_eq_int(dec_ping.opcode, ws_op_ping(), "Decoded Ping frame opcode")
  c2 = assert_eq_int(dec_ping.payload_len, 4, "Decoded Ping payload length")

  pong_frame_bytes = ws_build_pong_frame(dec_ping.payload_bytes, 0, [0, 0, 0, 0])
  dec_pong = ws_decode_frame(pong_frame_bytes)
  c3 = assert_eq_int(dec_pong.opcode, ws_op_pong(), "Decoded Pong frame opcode")

  close_frame_bytes = ws_build_close_frame(ws_close_normal(), "Normal Closure", 0, [0, 0, 0, 0])
  dec_close = ws_decode_frame(close_frame_bytes)
  c4 = assert_eq_int(dec_close.opcode, ws_op_close(), "Decoded Close frame opcode")
  close_info = ws_parse_close_payload(dec_close.payload_bytes)
  c5 = assert_eq_int(close_info.status_code, ws_close_normal(), "Close status code 1000")
  c6 = assert_eq_str(close_info.reason, "Normal Closure", "Close reason string")

  @if c1 == 1 && c2 == 1 && c3 == 1 && c4 == 1 && c5 == 1 && c6 == 1
    passed_tests = passed_tests + 1
  @end

  @! SECTION 6: Message Fragmentation Reassembly
  println("▶ Section 6: Multi-Frame Message Fragmentation & Reassembly...")
  total_tests = total_tests + 1

  assembler = ws_fragment_assembler_new()

  @! Chunk 1: FIN=0, Opcode=Text, Payload="Hello "
  f_chunk1_bytes = ws_encode_frame(0, ws_op_text(), 0, [0, 0, 0, 0], [72, 101, 108, 108, 111, 32])
  f_chunk1 = ws_decode_frame(f_chunk1_bytes)
  assembler = assembler.feed(f_chunk1)
  res1 = assembler.completed_frame
  fr1_ok = assert_eq_int(res1.fin, 0, "Chunk 1 in-progress assembly")

  @! Chunk 2: FIN=1, Opcode=Continuation, Payload="World!"
  f_chunk2_bytes = ws_encode_frame(1, ws_op_continuation(), 0, [0, 0, 0, 0], [87, 111, 114, 108, 100, 33])
  f_chunk2 = ws_decode_frame(f_chunk2_bytes)
  assembler = assembler.feed(f_chunk2)
  res2 = assembler.completed_frame
  fr2_ok1 = assert_eq_int(res2.fin, 1, "Chunk 2 completes assembly (FIN=1)")
  fr2_ok2 = assert_eq_int(res2.opcode, ws_op_text(), "Reassembled opcode restored to Text (1)")
  fr2_ok3 = assert_eq_str(res2.payload_text, "Hello World!", "Reassembled text message payload")

  @if fr1_ok == 1 && fr2_ok1 == 1 && fr2_ok2 == 1 && fr2_ok3 == 1
    passed_tests = passed_tests + 1
  @end

  println("=================================================================")
  println("📊 WEBSOCKET TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 6 WEBSOCKET & CRYPTO TEST SUITES PASSED! 🎉")
    return 0
  @else
    println("❌ SOME WEBSOCKET TESTS FAILED")
    return 1
  @end
@end
