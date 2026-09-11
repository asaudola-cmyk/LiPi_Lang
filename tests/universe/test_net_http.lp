@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: PURE MAYA HTTP/1.1 CLIENT & SERVER (universe/net/http)
@! File: tests/universe/test_net_http.maya
@! ============================================================================

import "universe/net/http"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/net/http (HTTP/1.1 Protocol)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: HTTP GET Request Formatting
  @! --------------------------------------------------------------------------
  total = total + 1
  headers = [
    { name: "Host", value: "localhost:8080" },
    { name: "User-Agent", value: "Maya-Pure-Client/1.0" },
    { name: "Accept", value: "application/json" }
  ]
  get_req = http_format_request("GET", "/api/v1/resource", headers, "")
  @if contains(get_req, "GET /api/v1/resource HTTP/1.1\r\n") == 1 && contains(get_req, "Host: localhost:8080\r\n") == 1
    passed = passed + 1
    println("  [PASS] Test 1: HTTP GET request formatting verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: HTTP GET request formatting failed -> Got: " + get_req)
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: HTTP POST Request Formatting with Body & Content-Length Header
  @! --------------------------------------------------------------------------
  total = total + 1
  body = "{\"action\": \"ping\", \"id\": 101}"
  post_headers = [
    { name: "Host", value: "localhost:8080" },
    { name: "Content-Type", value: "application/json" }
  ]
  post_req = http_format_request("POST", "/api/v1/events", post_headers, body)
  @if contains(post_req, "POST /api/v1/events HTTP/1.1\r\n") == 1 && contains(post_req, "Content-Length: " + body.len().to_str()) == 1 && contains(post_req, "\r\n\r\n" + body) == 1
    passed = passed + 1
    println("  [PASS] Test 2: HTTP POST request formatting with body & Content-Length verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: HTTP POST request formatting failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: HTTP Response Parsing — Status Line & Headers
  @! --------------------------------------------------------------------------
  total = total + 1
  raw_resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\nServer: MayaServer\r\n\r\nHello World!"
  parsed_resp = http_parse_response(raw_resp)
  @if parsed_resp.status_code == 200 && parsed_resp.status_text == "OK" && parsed_resp.body == "Hello World!"
    passed = passed + 1
    println("  [PASS] Test 3: HTTP response status code (200 OK) and body parsing verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: HTTP response parsing failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: HTTP Response Parsing — 404 Not Found
  @! --------------------------------------------------------------------------
  total = total + 1
  raw_404 = "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found"
  parsed_404 = http_parse_response(raw_404)
  @if parsed_404.status_code == 404 && parsed_404.status_text == "Not Found" && parsed_404.body == "Not Found"
    passed = passed + 1
    println("  [PASS] Test 4: HTTP 404 Not Found status line parsing verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: HTTP 404 Not Found parsing failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: HTTP Response Formatting (Server Helper)
  @! --------------------------------------------------------------------------
  total = total + 1
  server_resp = http_format_response(200, "application/json", "{\"status\":\"ok\"}")
  @if contains(server_resp, "HTTP/1.1 200 OK\r\n") == 1 && contains(server_resp, "Content-Type: application/json\r\n") == 1 && contains(server_resp, "Content-Length: 15\r\n") == 1
    passed = passed + 1
    println("  [PASS] Test 5: http_format_response(200, JSON) verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: http_format_response failed -> Got: " + server_resp)
  @end

  @! --------------------------------------------------------------------------
  @! Test 6: HTTP Chunked Transfer Decoding
  @! --------------------------------------------------------------------------
  total = total + 1
  chunked_body = "4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n"
  decoded_chunk = http_decode_chunked(chunked_body)
  @if decoded_chunk == "Wikipedia"
    passed = passed + 1
    println("  [PASS] Test 6: HTTP Transfer-Encoding: chunked decoding verified (\"Wikipedia\")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: Chunked decoding failed -> Got: " + decoded_chunk)
  @end

  println("-----------------------------------------------------------------")
  println("HTTP Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/net/http E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/net/http E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
