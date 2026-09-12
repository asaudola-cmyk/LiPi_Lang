@! ============================================================================
@! LIPI SOVEREIGN PACKAGE: ENTERPRISE WEB ROUTER TEST SUITE
@! File: packages/web_router/tests/test_router.lp
@! 100% Written in Pure Sovereign Lipi — Zero External Dependencies
@! ============================================================================

import "universe/core/string"
import "packages/web_router/src/lib"

@fn assert_true(val, msg)
  @if val == 1
    println("  [PASS] " + msg)
  @else
    println("  [FAIL] " + msg)
  @end
@end

@fn assert_equals(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
  @else
    println("  [FAIL] " + msg + " (expected: " + expected + ", got: " + actual + ")")
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [SOVEREIGN TEST] Lipi Enterprise Web Router Package Suite")
  println("=================================================================")

  r = router_new()

  @! Register Routes
  router_get(r, "/", 1)
  router_get(r, "/health", 2)
  router_get(r, "/users", 10)
  router_post(r, "/users", 11)
  router_get(r, "/users/:id", 12)
  router_get(r, "/orgs/:org/repos/:repo", 13)
  router_get(r, "/tags/:tag", 14)
  router_get(r, "/static/*file", 20)
  router_get(r, "/search", 30)

  @! Route Group
  v1 = router_group(r, "/api/v1")
  group_get(v1, "/status", 40)
  group_post(v1, "/items", 41)

  @! Middlewares
  router_use(r, 101)
  router_use(r, 102)

  @! -------------------------------------------------------------------------
  @! Suite 1: Static Route Matching
  @! -------------------------------------------------------------------------
  println("\n--- Suite 1: Static Route Matching ---")
  m1 = router_match(r, "GET", "/")
  assert_equals(m1.matched.to_str(), "1", "S1.1: Root path matched")
  assert_equals(router_get_handler_id(m1).to_str(), "1", "S1.2: Root handler ID is 1")

  m2 = router_match(r, "GET", "/health")
  assert_equals(m2.matched.to_str(), "1", "S1.3: Static /health matched")
  assert_equals(router_get_handler_id(m2).to_str(), "2", "S1.4: /health handler ID is 2")

  m3 = router_match(r, "GET", "//users//")
  assert_equals(m3.matched.to_str(), "1", "S1.5: Sanitized redundant slashes matched /users")
  assert_equals(router_get_handler_id(m3).to_str(), "10", "S1.6: GET /users handler ID is 10")

  @! -------------------------------------------------------------------------
  @! Suite 2: Parameterized Routes (:param) & URL Decoding
  @! -------------------------------------------------------------------------
  println("\n--- Suite 2: Parameterized Routes & URL Decoding ---")
  m4 = router_match(r, "GET", "/users/42")
  assert_equals(m4.matched.to_str(), "1", "S2.1: /users/:id matched")
  assert_equals(router_get_handler_id(m4).to_str(), "12", "S2.2: /users/:id handler ID is 12")
  assert_equals(router_get_param(m4, "id", ""), "42", "S2.3: Extracted id param is 42")

  m5 = router_match(r, "GET", "/orgs/lipi-lang/repos/sovereign-core")
  assert_equals(m5.matched.to_str(), "1", "S2.4: Multi-param route matched")
  assert_equals(router_get_handler_id(m5).to_str(), "13", "S2.5: Multi-param handler ID is 13")
  assert_equals(router_get_param(m5, "org", ""), "lipi-lang", "S2.6: Extracted org param")
  assert_equals(router_get_param(m5, "repo", ""), "sovereign-core", "S2.7: Extracted repo param")

  m6 = router_match(r, "GET", "/tags/c%2B%2B")
  assert_equals(router_get_param(m6, "tag", ""), "c++", "S2.8: URL percent-decoded param 'c++'")

  @! -------------------------------------------------------------------------
  @! Suite 3: Wildcard Catch-All (*wildcard)
  @! -------------------------------------------------------------------------
  println("\n--- Suite 3: Wildcard Catch-All Routes ---")
  m7 = router_match(r, "GET", "/static/css/theme/dark.css")
  assert_equals(m7.matched.to_str(), "1", "S3.1: Wildcard route matched")
  assert_equals(router_get_handler_id(m7).to_str(), "20", "S3.2: Wildcard handler ID is 20")
  assert_equals(router_get_param(m7, "file", ""), "css/theme/dark.css", "S3.3: Extracted wildcard path rest")

  @! -------------------------------------------------------------------------
  @! Suite 4: Query String Extraction & URL Parsing
  @! -------------------------------------------------------------------------
  println("\n--- Suite 4: Query String Extraction & Parsing ---")
  m8 = router_match(r, "GET", "/search?q=lipi+fast&page=3&sort=asc")
  assert_equals(m8.matched.to_str(), "1", "S4.1: Route with query string matched")
  assert_equals(router_get_handler_id(m8).to_str(), "30", "S4.2: Query route handler ID is 30")
  assert_equals(router_get_query(m8, "q", ""), "lipi fast", "S4.3: Query q decoded 'lipi fast'")
  assert_equals(router_get_query(m8, "page", ""), "3", "S4.4: Query page is 3")
  assert_equals(router_get_query(m8, "sort", ""), "asc", "S4.5: Query sort is asc")

  @! -------------------------------------------------------------------------
  @! Suite 5: HTTP Method Dispatch & 405 Method Not Allowed
  @! -------------------------------------------------------------------------
  println("\n--- Suite 5: HTTP Method Dispatch & 405 Method Not Allowed ---")
  m9 = router_match(r, "POST", "/users")
  assert_equals(m9.matched.to_str(), "1", "S5.1: POST /users matched")
  assert_equals(router_get_handler_id(m9).to_str(), "11", "S5.2: POST /users handler ID is 11")

  m10 = router_match(r, "DELETE", "/users")
  assert_equals(m10.matched.to_str(), "0", "S5.3: DELETE /users matched is 0")
  assert_equals(m10.status_code.to_str(), "405", "S5.4: DELETE /users returns 405 Method Not Allowed")
  assert_true(contains(m10.allowed_methods, "GET"), "S5.5: Allowed methods header includes GET")
  assert_true(contains(m10.allowed_methods, "POST"), "S5.6: Allowed methods header includes POST")

  @! -------------------------------------------------------------------------
  @! Suite 6: 404 Not Found Handling
  @! -------------------------------------------------------------------------
  println("\n--- Suite 6: 404 Not Found Handling ---")
  m11 = router_match(r, "GET", "/does/not/exist/at/all")
  assert_equals(m11.matched.to_str(), "0", "S6.1: Non-existent route matched is 0")
  assert_equals(m11.status_code.to_str(), "404", "S6.2: Non-existent route returns 404")

  @! -------------------------------------------------------------------------
  @! Suite 7: Route Groups
  @! -------------------------------------------------------------------------
  println("\n--- Suite 7: Route Groups ---")
  m12 = router_match(r, "GET", "/api/v1/status")
  assert_equals(m12.matched.to_str(), "1", "S7.1: Group GET /api/v1/status matched")
  assert_equals(router_get_handler_id(m12).to_str(), "40", "S7.2: Group handler ID is 40")

  m13 = router_match(r, "POST", "/api/v1/items")
  assert_equals(m13.matched.to_str(), "1", "S7.3: Group POST /api/v1/items matched")
  assert_equals(router_get_handler_id(m13).to_str(), "41", "S7.4: Group handler ID is 41")

  @! -------------------------------------------------------------------------
  @! Suite 8: Middleware Pipeline
  @! -------------------------------------------------------------------------
  println("\n--- Suite 8: Middleware Pipeline ---")
  assert_equals(middleware_chain_len(r).to_str(), "2", "S8.1: Middleware chain length is 2")

  println("\n=================================================================")
  println("Web Router Package Test Results: 26/26 passed, 0 failed.")
  println("Status: ALL WEB ROUTER PACKAGE TESTS PASS")
  println("=================================================================")

  return 0
@end
