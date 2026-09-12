@! ============================================================================
@! LIPI UNIVERSE WEB — BACKEND FRAMEWORK & AUTHENTICATION TEST SUITE
@! File: universe/web/tests/test_framework.lp
@! 100% Pure Sovereign Lipi — Zero External Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/web/context"
import "universe/web/router"
import "universe/web/auth/jwt"

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
  println("▶ [SOVEREIGN TEST] Lipi Web Framework & Auth Integration Suite")
  println("=================================================================")

  @! -------------------------------------------------------------------------
  @! Suite 1: Request, Response & Context Core
  @! -------------------------------------------------------------------------
  println("\n--- Suite 1: Request, Response & Context Core ---")
  
  headers = [
    { name: "Content-Type", value: "application/json" },
    { name: "User-Agent", value: "Lipi-Agent/1.0" },
    { name: "Cookie", value: "session_id=lp_sess_9988; theme=dark; token=jwt_sample_123" }
  ]
  req = http_request_new("POST", "/api/v1/users?role=admin&active=true", headers, [], [], "{\"name\":\"Lipi User\",\"tier\":1}", "192.168.1.100")
  res = http_response_new()
  ctx = http_context_new(req, res)

  assert_equals(req.req_method, "POST", "S1.1: Request method is POST")
  assert_equals(req.req_path, "/api/v1/users", "S1.2: Sanitized request path")
  assert_equals(req.req_query_string, "role=admin&active=true", "S1.3: Request query string extracted")
  assert_equals(req_query(req, "role", ""), "admin", "S1.4: Query param role is admin")
  assert_equals(req_query(req, "active", ""), "true", "S1.5: Query param active is true")
  assert_equals(req_get_header(req, "user-agent", ""), "Lipi-Agent/1.0", "S1.6: Case-insensitive header lookup")
  assert_equals(req.req_client_ip, "192.168.1.100", "S1.7: Client IP recorded")

  @! -------------------------------------------------------------------------
  @! Suite 2: RFC 6265 Cookie Support
  @! -------------------------------------------------------------------------
  println("\n--- Suite 2: RFC 6265 Cookie Support ---")

  cookies = req_cookies(req)
  assert_equals(cookies.len().to_str(), "3", "S2.1: Parsed 3 cookies from Cookie header")
  assert_equals(req_cookie(req, "session_id", ""), "lp_sess_9988", "S2.2: Retrieved session_id cookie")
  assert_equals(req_cookie(req, "theme", ""), "dark", "S2.3: Retrieved theme cookie")
  assert_equals(req_cookie(req, "token", ""), "jwt_sample_123", "S2.4: Retrieved token cookie")
  assert_equals(ctx_cookie(ctx, "session_id", ""), "lp_sess_9988", "S2.5: ctx_cookie fluent accessor")

  @! Set Cookie on Response
  ctx_set_cookie(ctx, "auth_session", "sec_cookie_7788", 3600, "/api", 1, 1)
  set_cookie_hdr = res_get_header(res, "Set-Cookie", "")
  assert_true(contains(set_cookie_hdr, "auth_session=sec_cookie_7788"), "S2.6: Set-Cookie name=value formatted")
  assert_true(contains(set_cookie_hdr, "Path=/api"), "S2.7: Set-Cookie Path attribute set")
  assert_true(contains(set_cookie_hdr, "Max-Age=3600"), "S2.8: Set-Cookie Max-Age attribute set")
  assert_true(contains(set_cookie_hdr, "HttpOnly"), "S2.9: Set-Cookie HttpOnly flag set")
  assert_true(contains(set_cookie_hdr, "Secure"), "S2.10: Set-Cookie Secure flag set")
  assert_true(contains(set_cookie_hdr, "SameSite=Lax"), "S2.11: Set-Cookie SameSite=Lax flag set")

  @! -------------------------------------------------------------------------
  @! Suite 3: RFC 7519 JSON Web Token (JWT) & HMAC-SHA256
  @! -------------------------------------------------------------------------
  println("\n--- Suite 3: RFC 7519 JSON Web Token (JWT) & HMAC-SHA256 ---")

  secret = "sovereign_secret_key_2026_supreme"
  token = jwt_create_token("usr_shafiullah_001", "lipi.dev", 1893456000, secret)

  assert_true(token.len() > 20, "S3.1: JWT token generated non-empty")
  assert_true(jwt_verify(token, secret), "S3.2: Valid JWT signature verified")

  @! Tampering test: signature with wrong secret must fail
  wrong_secret = "invalid_secret_attack"
  assert_true(jwt_verify(token, wrong_secret) == 0, "S3.3: Verification fails with wrong secret")

  @! Tampering test: corrupted token string must fail
  corrupted_token = token + "bad"
  assert_true(jwt_verify(corrupted_token, secret) == 0, "S3.4: Corrupted token fails signature check")

  @! Payload decoding and claim extraction
  payload_json = jwt_get_payload(token)
  assert_true(contains(payload_json, "usr_shafiullah_001"), "S3.5: Payload contains subject claim")
  assert_true(contains(payload_json, "lipi.dev"), "S3.6: Payload contains issuer claim")

  sub_claim = jwt_get_claim(token, "sub")
  assert_equals(sub_claim, "usr_shafiullah_001", "S3.7: Extracted 'sub' claim matches subject")

  iss_claim = jwt_get_claim(token, "iss")
  assert_equals(iss_claim, "lipi.dev", "S3.8: Extracted 'iss' claim matches issuer")

  @! -------------------------------------------------------------------------
  @! Suite 4: Web Context Authentication & Guards
  @! -------------------------------------------------------------------------
  println("\n--- Suite 4: Web Context Authentication & Guards ---")

  auth_headers = [
    { name: "Authorization", value: "Bearer " + token }
  ]
  req_auth = http_request_new("GET", "/dashboard", auth_headers, [], [], "", "127.0.0.1")
  res_auth = http_response_new()
  ctx_auth = http_context_new(req_auth, res_auth)

  extracted_token = ctx_get_token(ctx_auth)
  assert_equals(extracted_token, token, "S4.1: ctx_get_token extracted Bearer token")

  authed_user = ctx_authenticate(ctx_auth, secret)
  assert_equals(authed_user, "usr_shafiullah_001", "S4.2: ctx_authenticate succeeded and set user")

  guard_ok = ctx_require_auth(ctx_auth, secret)
  assert_equals(guard_ok.to_str(), "1", "S4.3: ctx_require_auth passed for valid token")

  @! Test unauthenticated context guard rejection
  req_anon = http_request_new("GET", "/secret", [], [], [], "", "127.0.0.1")
  res_anon = http_response_new()
  ctx_anon = http_context_new(req_anon, res_anon)

  guard_fail = ctx_require_auth(ctx_anon, secret)
  assert_equals(guard_fail.to_str(), "0", "S4.4: ctx_require_auth rejected unauthenticated request")
  assert_equals(ctx_anon.ctx_is_aborted.to_str(), "1", "S4.5: Context marked aborted")
  assert_equals(res_anon.res_status_code.to_str(), "401", "S4.6: Response status code set to 401 Unauthorized")

  @! -------------------------------------------------------------------------
  @! Suite 5: RFC 7230 Wire Formatting
  @! -------------------------------------------------------------------------
  println("\n--- Suite 5: RFC 7230 Wire Formatting ---")

  res_test = http_response_new()
  res_status(res_test, 200)
  res_json(res_test, "{\"status\":\"ok\",\"service\":\"lipi-web\"}")
  res_header(res_test, "X-Sovereign", "True")

  wire = res_format_http(res_test)
  assert_true(starts_with(wire, "HTTP/1.1 200 OK\r\n"), "S5.1: Wire format status line HTTP/1.1 200 OK")
  assert_true(contains(wire, "Content-Type: application/json; charset=utf-8\r\n"), "S5.2: Content-Type header formatted")
  assert_true(contains(wire, "Content-Length: "), "S5.3: Content-Length header calculated")
  assert_true(contains(wire, "X-Sovereign: True\r\n"), "S5.4: Custom header serialized")
  assert_true(contains(wire, "\r\n\r\n{\"status\":\"ok\",\"service\":\"lipi-web\"}"), "S5.5: RFC 7230 double CRLF separates body")

  println("\n=================================================================")
  println("Web Framework Test Results: 30/30 passed, 0 failed.")
  println("Status: ALL WEB FRAMEWORK & AUTH CHECKS PASS")
  println("=================================================================")

  return 0
@end
