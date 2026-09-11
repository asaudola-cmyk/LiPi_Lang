@! ============================================================================
@! MAYA UNIVERSE WEB — ROUTER & URL EMPIRICAL UNIT TEST SUITE
@! tests/universe/test_web_router.maya
@! ============================================================================

import "universe/web/url"
import "universe/web/router"
import "universe/web/context"
import "universe/web/app"
import "universe/core/string"

@fn h_root(req, res)
  res_text(res, "ROOT_PAGE")
  return res
@end

@fn h_user(req, res)
  uid = req_param(req, "id", "")
  res_text(res, "USER:" + uid)
  return res
@end

@fn h_user_post(req, res)
  res_status(res, 201)
  res_text(res, "USER_CREATED")
  return res
@end

@fn h_file(req, res)
  fpath = req_param(req, "filepath", "")
  res_text(res, "FILE:" + fpath)
  return res
@end

@fn h_nested(req, res)
  uid = req_param(req, "uid", "")
  pid = req_param(req, "pid", "")
  res_text(res, "UID:" + uid + " PID:" + pid)
  return res
@end

@fn h_static_specific(req, res)
  res_text(res, "SPECIFIC_STATIC")
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Web Framework Router & URL Parser Verification")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! 1. URL Percent-Decoding Tests
  @! --------------------------------------------------------------------------
  total = total + 1
  d1 = url_decode("Hello%20World%21%2F%3A")
  @if d1 == "Hello World!/:"
    passed = passed + 1
    println("  [PASS] Test 1: Comprehensive URL percent-decoding")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: url_decode failed -> Got: " + d1)
  @end

  total = total + 1
  d2 = url_decode("100%pure%ZZ%2")
  @if d2 == "100%pure%ZZ%2"
    passed = passed + 1
    println("  [PASS] Test 2: Tolerant handling of malformed percent escapes")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: malformed url_decode failed -> Got: " + d2)
  @end

  total = total + 1
  d3 = url_decode("q=maya+programming+language")
  @if d3 == "q=maya programming language"
    passed = passed + 1
    println("  [PASS] Test 3: Plus sign converted to space in URL decoding")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: plus sign decode failed -> Got: " + d3)
  @end

  @! --------------------------------------------------------------------------
  @! 2. URL Component Encoding Tests
  @! --------------------------------------------------------------------------
  total = total + 1
  e1 = url_encode_component("hello world!")
  @if e1 == "hello%20world%21"
    passed = passed + 1
    println("  [PASS] Test 4: URL component encoding")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: url_encode_component failed -> Got: " + e1)
  @end

  @! --------------------------------------------------------------------------
  @! 3. Query String Parser Tests
  @! --------------------------------------------------------------------------
  total = total + 1
  q_str = "?user=john%20doe&role=admin&active"
  qp = url_parse_query(q_str)
  v_user = url_query_get(qp, "user", "")
  v_role = url_query_get(qp, "role", "")
  v_active = url_query_get(qp, "active", "none")
  has_user = url_query_has(qp, "user")
  has_none = url_query_has(qp, "missing")

  @if v_user == "john doe" && v_role == "admin" && v_active == "" && has_user == 1 && has_none == 0
    passed = passed + 1
    println("  [PASS] Test 5: Query string parsing & lookup helpers")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: url_parse_query failed")
  @end

  total = total + 1
  qp_multi = url_parse_query("tag=web&tag=rest&tag=maya")
  tags = url_query_get_all(qp_multi, "tag")
  @if tags.len() == 3 && tags[0] == "web" && tags[1] == "rest" && tags[2] == "maya"
    passed = passed + 1
    println("  [PASS] Test 6: Multi-valued query keys (tag=web&tag=rest)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: url_query_get_all failed -> len=" + tags.len().to_str())
  @end

  @! --------------------------------------------------------------------------
  @! 4. Full URL Parser Tests
  @! --------------------------------------------------------------------------
  total = total + 1
  u_parsed = url_parse("https://api.maya.dev:8443/v1/users?search=alex#section2")
  @if u_parsed.protocol == "https" && u_parsed.host == "api.maya.dev" && u_parsed.port == 8443 && u_parsed.path == "/v1/users" && u_parsed.fragment == "section2"
    passed = passed + 1
    println("  [PASS] Test 7: Full URL parser with protocol, host, port, path, query, fragment")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: url_parse failed -> host=" + u_parsed.host + " port=" + u_parsed.port.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! 5. Prefix Trie Router Tests
  @! --------------------------------------------------------------------------
  app = web_new()
  app_get(app, "/", h_root)
  app_get(app, "/users/:id", h_user)
  app_post(app, "/users", h_user_post)
  app_get(app, "/users/active", h_static_specific)
  app_get(app, "/users/:uid/posts/:pid", h_nested)
  app_get(app, "/static/*filepath", h_file)

  v1 = app_group(app, "/api/v1")
  group_get(v1, "/profile/:id", h_user)
  group_post(v1, "/profile", h_user_post)

  @! Test 8: Exact Static Route Matching
  total = total + 1
  r8 = app_handle_raw_request(app, "GET / HTTP/1.1\r\n\r\n")
  @if contains(r8, "HTTP/1.1 200 OK") == 1 && contains(r8, "ROOT_PAGE") == 1
    passed = passed + 1
    println("  [PASS] Test 8: Exact static route matching & method dispatch")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: Root route failed -> " + r8)
  @end

  @! Test 9: 405 Method Not Allowed with Allow Header
  total = total + 1
  r9 = app_handle_raw_request(app, "PUT /users HTTP/1.1\r\n\r\n")
  @if contains(r9, "HTTP/1.1 405 Method Not Allowed") == 1 && contains(r9, "Allow: POST") == 1
    passed = passed + 1
    println("  [PASS] Test 9: 405 Method Not Allowed with Allow header generation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: 405 Allow header failed -> " + r9)
  @end

  @! Test 10: Multi-Variable Parametric Route Matching & Extraction
  total = total + 1
  r10 = app_handle_raw_request(app, "GET /users/alice%20smith/posts/42 HTTP/1.1\r\n\r\n")
  @if contains(r10, "HTTP/1.1 200 OK") == 1 && contains(r10, "UID:alice smith PID:42") == 1
    passed = passed + 1
    println("  [PASS] Test 10: Multi-variable parametric route matching & extraction")
  @else
    failed = failed + 1
    println("  [FAIL] Test 10: Multi-param failed -> " + r10)
  @end

  @! Test 11: Wildcard Catch-All Path Matching (*filepath)
  total = total + 1
  r11 = app_handle_raw_request(app, "GET /static/images/icons/logo%20dark.png HTTP/1.1\r\n\r\n")
  @if contains(r11, "HTTP/1.1 200 OK") == 1 && contains(r11, "FILE:images/icons/logo dark.png") == 1
    passed = passed + 1
    println("  [PASS] Test 11: Wildcard catch-all path matching (*filepath)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 11: Wildcard failed -> " + r11)
  @end

  @! Test 12: Precedence Ordering: static > param > wildcard
  total = total + 1
  r12 = app_handle_raw_request(app, "GET /users/active HTTP/1.1\r\n\r\n")
  @if contains(r12, "HTTP/1.1 200 OK") == 1 && contains(r12, "SPECIFIC_STATIC") == 1
    passed = passed + 1
    println("  [PASS] Test 12: Precedence ordering: static > param > wildcard")
  @else
    failed = failed + 1
    println("  [FAIL] Test 12: Precedence failed -> " + r12)
  @end

  @! Test 13: Redundant slashes & query strings normalized
  total = total + 1
  r13 = app_handle_raw_request(app, "GET ///users//999/?sort=asc HTTP/1.1\r\n\r\n")
  @if contains(r13, "HTTP/1.1 200 OK") == 1 && contains(r13, "USER:999") == 1
    passed = passed + 1
    println("  [PASS] Test 13: Redundant slashes & query strings properly normalized in routing")
  @else
    failed = failed + 1
    println("  [FAIL] Test 13: Slashes normalization failed -> " + r13)
  @end

  @! Test 14: Route Grouping Prefix Helper
  total = total + 1
  r14 = app_handle_raw_request(app, "GET /api/v1/profile/master_user HTTP/1.1\r\n\r\n")
  @if contains(r14, "HTTP/1.1 200 OK") == 1 && contains(r14, "USER:master_user") == 1
    passed = passed + 1
    println("  [PASS] Test 14: Route grouping prefix helper (/api/v1/profile)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 14: Route group failed -> " + r14)
  @end

  @! Test 15: 404 Not Found on Unmapped Path
  total = total + 1
  r15 = app_handle_raw_request(app, "GET /non/existent/path HTTP/1.1\r\n\r\n")
  @if contains(r15, "HTTP/1.1 404 Not Found") == 1
    passed = passed + 1
    println("  [PASS] Test 15: 404 Not Found on unmapped path")
  @else
    failed = failed + 1
    println("  [FAIL] Test 15: 404 fallback failed -> " + r15)
  @end

  println("-----------------------------------------------------------------")
  println("Router & URL Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Web Router & URL Parser Verification PASSED (" + passed.to_str() + "/" + total.to_str() + ")")
    return 0
  @else
    println("✗ Web Router & URL Parser Verification FAILED")
    return 1
  @end
@end
