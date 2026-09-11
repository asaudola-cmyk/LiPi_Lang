@! ============================================================================
@! ADVERSARIAL STRESS TEST: PURE MAYA HTTP ENGINE (test_adv_net_http.maya)
@! Tests:
@! 1. Multi-header request parsing with irregular whitespace and casing
@! 2. Malformed request resilience (empty, garbage, missing version, no colon)
@! 3. Case-insensitive header handling (RFC 7230)
@! 4. Complex multi-chunk Transfer-Encoding decoding (with chunk extensions)
@! 5. HTTP URL parsing boundary and corner cases
@! 6. Request/Response serialization invariants
@! ============================================================================

import "universe/net/http"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [ADVERSARIAL STRESS SUITE] universe/net/http")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: Multi-Header Parsing & Irregular Whitespace
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Multi-Header Request Parsing")

  raw_multi_req = "GET /api/v2/items?filter=active HTTP/1.1\r\n"
  raw_multi_req = raw_multi_req + "Host:   api.maya-lang.org:8080\r\n"
  raw_multi_req = raw_multi_req + "User-Agent: MayaAdversarialBot/2.0\r\n"
  raw_multi_req = raw_multi_req + "Accept: application/json, text/plain\r\n"
  raw_multi_req = raw_multi_req + "X-Custom-Trace-ID: trace-987654321\r\n"
  raw_multi_req = raw_multi_req + "X-Maya-Auth: Bearer secret_token_xyz\r\n"
  raw_multi_req = raw_multi_req + "Cache-Control: no-cache, no-store\r\n"
  raw_multi_req = raw_multi_req + "X-Empty-Header:\r\n"
  raw_multi_req = raw_multi_req + "\r\n"

  parsed_multi = http_parse_request(raw_multi_req)

  total = total + 1
  @if parsed_multi.method == "GET" && parsed_multi.path == "/api/v2/items?filter=active" && parsed_multi.version == "HTTP/1.1"
    passed = passed + 1
    println("  [PASS] HT1.1: Request line parsed correctly (GET /api/v2/items?filter=active HTTP/1.1)")
  @else
    failed = failed + 1
    println("  [FAIL] HT1.1: Request line parse error: method=" + parsed_multi.method + ", path=" + parsed_multi.path)
  @end

  total = total + 1
  @if parsed_multi.headers.len() >= 7
    passed = passed + 1
    println("  [PASS] HT1.2: Multi-header array contains 7+ headers (actual: " + parsed_multi.headers.len().to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] HT1.2: Multi-header count insufficient: " + parsed_multi.headers.len().to_str())
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Malformed Request Tolerance
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Malformed Request Tolerance")

  total = total + 1
  empty_req = http_parse_request("")
  @if empty_req.headers.len() == 0 && empty_req.body == ""
    passed = passed + 1
    println("  [PASS] HT2.1: Empty request parsed safely without crash")
  @else
    failed = failed + 1
    println("  [FAIL] HT2.1: Empty request parse returned invalid state")
  @end

  total = total + 1
  garbage_req = "THIS IS COMPLETELY INVALID HTTP GARBAGE WITHOUT PROTOCOL"
  parsed_garb = http_parse_request(garbage_req)
  @if parsed_garb.method == "THIS" && parsed_garb.body == ""
    passed = passed + 1
    println("  [PASS] HT2.2: Non-HTTP garbage request handled gracefully")
  @else
    failed = failed + 1
    println("  [FAIL] HT2.2: Garbage request handling unexpected: method=" + parsed_garb.method)
  @end

  total = total + 1
  no_colon_hdr = "POST /submit HTTP/1.1\r\nInvalidHeaderNoColonValue\r\nValid: True\r\n\r\nhello"
  parsed_nc = http_parse_request(no_colon_hdr)
  @if parsed_nc.method == "POST" && parsed_nc.body == "hello" && parsed_nc.headers.len() == 1
    passed = passed + 1
    println("  [PASS] HT2.3: Header lines lacking colon skipped safely without drops of valid headers")
  @else
    failed = failed + 1
    println("  [FAIL] HT2.3: No-colon header parsing issue: hdr count=" + parsed_nc.headers.len().to_str() + ", body=" + parsed_nc.body)
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: Case-Insensitive Header & Transfer-Encoding Parsing
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Case-Insensitive Headers & Chunked Transfer")

  raw_chunked_resp = "HTTP/1.1 200 OK\r\n"
  raw_chunked_resp = raw_chunked_resp + "content-type: text/plain; charset=utf-8\r\n"
  raw_chunked_resp = raw_chunked_resp + "TRANSFER-ENCODING: CHUNKED\r\n"
  raw_chunked_resp = raw_chunked_resp + "connection: close\r\n"
  raw_chunked_resp = raw_chunked_resp + "\r\n"
  raw_chunked_resp = raw_chunked_resp + "7\r\n"
  raw_chunked_resp = raw_chunked_resp + "Mozilla\r\n"
  raw_chunked_resp = raw_chunked_resp + "9\r\n"
  raw_chunked_resp = raw_chunked_resp + "Developer\r\n"
  raw_chunked_resp = raw_chunked_resp + "7\r\n"
  raw_chunked_resp = raw_chunked_resp + "Network\r\n"
  raw_chunked_resp = raw_chunked_resp + "0\r\n"
  raw_chunked_resp = raw_chunked_resp + "\r\n"

  parsed_resp = http_parse_response(raw_chunked_resp)

  total = total + 1
  @if parsed_resp.status_code == 200 && parsed_resp.status_text == "OK"
    passed = passed + 1
    println("  [PASS] HT3.1: Response status 200 OK parsed successfully")
  @else
    failed = failed + 1
    println("  [FAIL] HT3.1: Status code parse error: " + parsed_resp.status_code.to_str())
  @end

  total = total + 1
  @if parsed_resp.body == "MozillaDeveloperNetwork"
    passed = passed + 1
    println("  [PASS] HT3.2: TRANSFER-ENCODING: CHUNKED (uppercase) decoded: " + parsed_resp.body)
  @else
    failed = failed + 1
    println("  [FAIL] HT3.2: Chunked decoding failed: actual='" + parsed_resp.body + "'")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Complex Multi-Chunk Transfer-Encoding Decoding
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Complex Multi-Chunk Decoding & Extensions")

  @! 5 chunks:
  @! Chunk 1: 4 ("Maya")
  @! Chunk 2: 1 (" ")
  @! Chunk 3: 9;ext=test_ext ("Language!")
  @! Chunk 4: 2 (": ")
  @! Chunk 5: 11 ("Native Syscalls!!", 17 bytes = 0x11)
  @! Chunk 6: 0 ("")
  complex_chunked = "4\r\n"
  complex_chunked = complex_chunked + "Maya\r\n"
  complex_chunked = complex_chunked + "1\r\n"
  complex_chunked = complex_chunked + " \r\n"
  complex_chunked = complex_chunked + "9;ext=test_ext\r\n"
  complex_chunked = complex_chunked + "Language!\r\n"
  complex_chunked = complex_chunked + "2\r\n"
  complex_chunked = complex_chunked + ": \r\n"
  complex_chunked = complex_chunked + "11\r\n"
  complex_chunked = complex_chunked + "Native Syscalls!!\r\n"
  complex_chunked = complex_chunked + "0\r\n"
  complex_chunked = complex_chunked + "\r\n"
  complex_chunked = complex_chunked + "IGNORABLE_TRAILING_DATA"

  decoded_body = http_decode_chunked(complex_chunked)
  expected_decoded = "Maya Language!: Native Syscalls!!"

  total = total + 1
  @if decoded_body == expected_decoded
    passed = passed + 1
    println("  [PASS] HT4.1: Complex multi-chunk payload with extension and hex lengths decoded accurately")
  @else
    failed = failed + 1
    println("  [FAIL] HT4.1: Multi-chunk decoding mismatch: len=" + decoded_body.len().to_str() + ", expected len=" + expected_decoded.len().to_str())
    println("         Actual:   " + decoded_body)
    println("         Expected: " + expected_decoded)
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: HTTP URL Parsing Boundaries
  @! --------------------------------------------------------------------------
  println("▶ Section 5: HTTP URL Parsing Boundaries")

  u1 = http_parse_url("http://127.0.0.1:9090/v1/query?q=maya#hash")
  total = total + 1
  @if u1.protocol == "http" && u1.host == "127.0.0.1" && u1.port == 9090 && u1.path == "/v1/query?q=maya#hash"
    passed = passed + 1
    println("  [PASS] HT5.1: http URL with port and query/hash parsed")
  @else
    failed = failed + 1
    println("  [FAIL] HT5.1: URL parse failed for u1: host=" + u1.host + ", port=" + u1.port.to_str() + ", path=" + u1.path)
  @end

  u2 = http_parse_url("https://secure.maya-lang.org")
  total = total + 1
  @if u2.protocol == "https" && u2.host == "secure.maya-lang.org" && u2.port == 443 && u2.path == "/"
    passed = passed + 1
    println("  [PASS] HT5.2: https default port (443) and root path ('/') populated")
  @else
    failed = failed + 1
    println("  [FAIL] HT5.2: HTTPS URL parse failed: host=" + u2.host + ", port=" + u2.port.to_str() + ", path=" + u2.path)
  @end

  u3 = http_parse_url("")
  total = total + 1
  @if u3.host == "localhost" && u3.port == 80 && u3.path == "/"
    passed = passed + 1
    println("  [PASS] HT5.3: Empty URL defaulted to localhost:80/")
  @else
    failed = failed + 1
    println("  [FAIL] HT5.3: Empty URL parse failed: host=" + u3.host)
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 6: Request/Response Serialization Invariants
  @! --------------------------------------------------------------------------
  println("▶ Section 6: Request and Response Serialization Invariants")

  hdrs = [
    { name: "Content-Type", value: "application/json" },
    { name: "Authorization", value: "Bearer 12345" }
  ]
  body_payload = "{\"status\":\"ok\",\"code\":200}"

  formatted_req = http_format_request("POST", "/api/data", hdrs, body_payload)

  total = total + 1
  has_cl = contains(formatted_req, "Content-Length: 26")
  has_ct = contains(formatted_req, "Content-Type: application/json")
  starts_post = starts_with(formatted_req, "POST /api/data HTTP/1.1\r\n")

  @if has_cl == 1 && has_ct == 1 && starts_post == 1
    passed = passed + 1
    println("  [PASS] HT6.1: http_format_request automatically injected Content-Length (26) and structured wire bytes")
  @else
    failed = failed + 1
    println("  [FAIL] HT6.1: http_format_request output incorrect:\n" + formatted_req)
  @end

  resp_204 = http_format_response(204, "", "")
  total = total + 1
  @if contains(resp_204, "HTTP/1.1 204 No Content") == 1 && contains(resp_204, "Content-Length: 0") == 1
    passed = passed + 1
    println("  [PASS] HT6.2: http_format_response(204) populated 'No Content' reason phrase and 0 length")
  @else
    failed = failed + 1
    println("  [FAIL] HT6.2: http_format_response(204) output invalid: " + resp_204)
  @end

  resp_503 = http_format_response(503, "Service Unavailable", "Overloaded")
  total = total + 1
  @if contains(resp_503, "HTTP/1.1 503 Service Unavailable") == 1 && contains(resp_503, "Overloaded") == 1
    passed = passed + 1
    println("  [PASS] HT6.3: http_format_response(503) verified")
  @else
    failed = failed + 1
    println("  [FAIL] HT6.3: http_format_response(503) output invalid: " + resp_503)
  @end

  @! --------------------------------------------------------------------------
  @! Summary
  @! --------------------------------------------------------------------------
  println("=================================================================")
  println("ADVERSARIAL HTTP SUITE SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if failed == 0
    println("✓ ALL HTTP ADVERSARIAL TESTS PASSED")
    return 0
  @else
    println("✗ SOME HTTP ADVERSARIAL TESTS FAILED (" + failed.to_str() + " failures)")
    return 1
  @end
@end
