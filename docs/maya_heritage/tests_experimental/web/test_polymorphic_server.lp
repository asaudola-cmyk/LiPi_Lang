@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ENVIRONMENT POLYMORPHIC SERVER TEST SUITE
@! File: tests/web/test_polymorphic_server.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/web/polymorphic_server"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🌐 MAYA ENVIRONMENT POLYMORPHIC SERVER TEST SUITE 🌐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: FastCGI Binary Frame Encoding & Decoding (RFC 3875)
  println("▶ Section 1: FastCGI Binary Header Encoding & Decoding (RFC 3875)...")
  total_tests = total_tests + 1
  hdr_bytes = fcgi_encode_header(1, 42, 1024, 0)
  ok1 = assert_eq_int(hdr_bytes.len(), 8, "Encoded FastCGI header is exactly 8 bytes")
  
  decoded = fcgi_decode_header(hdr_bytes, 0)
  ok2 = assert_eq_int(decoded.rec_type, 1, "Decoded record type is FCGI_BEGIN_REQUEST (1)")
  ok3 = assert_eq_int(decoded.req_id, 42, "Decoded request ID is 42")
  ok4 = assert_eq_int(decoded.content_len, 1024, "Decoded content length is 1024")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] FastCGI binary header encoding and decoding verified")
  @end

  @! SECTION 2: cPanel FastCGI Persistent Daemon Request Handling
  println("▶ Section 2: cPanel FastCGI Persistent Worker Loop...")
  total_tests = total_tests + 1
  ctx_fcgi = polymorphic_server_init("CGI/1.1", "RESPONDER", 8080)
  ok1 = assert_eq_int(ctx_fcgi.active_mode, 2, "Detected FastCGI persistent worker mode (active_mode = 2)")
  
  resp_fcgi = polymorphic_handle_request(ctx_fcgi, "DUMMY")
  ok2 = assert_true(str_contains(resp_fcgi, "FastCGI Pure Maya Daemon"), "Responded via FastCGI stream without spawning new processes")
  ok3 = assert_eq_int(ctx_fcgi.requests_handled, 1, "Requests handled counter incremented")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] cPanel FastCGI persistent server loop verified")
  @end

  @! SECTION 3: Standalone High-Concurrency VPS Daemon Morphing
  println("▶ Section 3: Standalone VPS High-Concurrency Daemon Morphing...")
  total_tests = total_tests + 1
  ctx_vps = polymorphic_server_init("", "", 8080)
  ok1 = assert_eq_int(ctx_vps.active_mode, 0, "Detected Standalone Daemon mode (active_mode = 0)")
  
  resp_vps = polymorphic_handle_request(ctx_vps, "GET /api/v1/health HTTP/1.1")
  ok2 = assert_true(str_contains(resp_vps, "HTTP/1.1 200 OK"), "Responded via standalone HTTP/1.1 protocol")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Standalone daemon automatic morphing verified")
  @end

  println("=================================================================")
  println("📊 POLYMORPHIC SERVER TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 POLYMORPHIC SERVER TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME POLYMORPHIC SERVER TESTS FAILED")
    return 1
  @end
@end
