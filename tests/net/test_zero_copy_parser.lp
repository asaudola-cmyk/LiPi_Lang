@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ZERO-COPY NETWORK PARSER TEST SUITE
@! File: tests/net/test_zero_copy_parser.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/net/zero_copy"

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

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA ZERO-COPY IN-PLACE NETWORK PARSER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Zero-Copy Byte Span Slicing & Equality
  println("▶ Section 1: In-Place Byte Span Slicing & Direct Offset Comparison...")
  total_tests = total_tests + 1
  raw_stream = "POST /api/v1/trade HTTP/1.1\r\nHost: maya.network\r\nContent-Type: application/json\r\n\r\n{\"symbol\":\"MAYA\",\"qty\":1000}"
  
  span_m = span_new(raw_stream, 0, 4)
  ok1 = assert_true(span_equals_str(span_m, "POST"), "Span equals 'POST' via direct character comparisons")
  
  span_h = span_new(raw_stream, 35, 12)
  ok2 = assert_true(span_equals_str(span_h, "maya.network"), "Span equals 'maya.network' without string copy")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Zero-copy byte span slicing and in-place matching verified")
  @end

  @! SECTION 2: Full HTTP Request Zero-Copy Parsing
  println("▶ Section 2: Zero-Allocation HTTP/1.1 Method, URI & Header Extraction...")
  total_tests = total_tests + 1
  parsed = zero_copy_parse_http_request(raw_stream)
  
  ok1 = assert_true(span_equals_str(parsed.method_span, "POST"), "Parsed method is 'POST'")
  ok2 = assert_true(span_equals_str(parsed.uri_span, "/api/v1/trade"), "Parsed URI is '/api/v1/trade'")
  ok3 = assert_true(span_equals_str(parsed.version_span, "HTTP/1.1"), "Parsed Version is 'HTTP/1.1'")
  ok4 = assert_eq_int(parsed.headers.len(), 2, "Extracted 2 headers")
  ok5 = assert_true(span_equals_str(parsed.body_span, "{\"symbol\":\"MAYA\",\"qty\":1000}"), "Body span matched exactly")
  ok6 = assert_eq_int(parsed.alloc_count, 0, "Parser made strictly 0 heap memory allocations (alloc_count = 0)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complete zero-copy HTTP parsing with 0 heap allocations verified")
  @end

  println("=================================================================")
  println("📊 ZERO-COPY PARSER TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 2 ZERO-COPY NETWORK PARSER TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ZERO-COPY TESTS FAILED")
    return 1
  @end
@end
