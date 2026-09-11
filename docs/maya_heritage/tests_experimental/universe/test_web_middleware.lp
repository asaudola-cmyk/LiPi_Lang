@! ============================================================================
@! MAYA UNIVERSE WEB — ONION MIDDLEWARE & CORS EMPIRICAL TEST SUITE
@! tests/universe/test_web_middleware.maya
@! ============================================================================

import "universe/web/context"
import "universe/web/middleware"
import "universe/web/app"
import "universe/core/string"
import "universe/core/json"

@fn mw_tracker_1(ctx)
  prev = ctx_get(ctx, "trace", "")
  @if prev == ""
    ctx_set(ctx, "trace", "mw1_in")
  @else
    ctx_set(ctx, "trace", prev + "->mw1_in")
  @end

  ctx_next(ctx)

  p2 = ctx_get(ctx, "trace", "")
  ctx_set(ctx, "trace", p2 + "->mw1_out")
  res_header(ctx.ctx_res, "X-Trace", ctx_get(ctx, "trace", ""))
  return 0
@end

@fn mw_tracker_2(ctx)
  prev = ctx_get(ctx, "trace", "")
  ctx_set(ctx, "trace", prev + "->mw2_in")

  ctx_next(ctx)

  p2 = ctx_get(ctx, "trace", "")
  ctx_set(ctx, "trace", p2 + "->mw2_out")
  return 0
@end

@fn mw_auth_guard(ctx)
  token = req_header(ctx.ctx_req, "Authorization", "")
  @if token != "Bearer super-secret-key"
    res_status(ctx.ctx_res, 401)
    res_text(ctx.ctx_res, "401 Unauthorized: Invalid Token")
    ctx_abort(ctx)
    return 0
  @end
  ctx_next(ctx)
  return 0
@end

@fn h_echo_trace(req, res)
  res_status(res, 200)
  res_text(res, "HANDLER_EXECUTED")
  return res
@end

@fn h_secure_data(req, res)
  res_status(res, 200)
  res_json(res, "{\"secure_data\":\"vault_payload\",\"authorized\":true}")
  return res
@end

@fn h_json_reader(req, res)
  u_name = req_json_get(req, "username", "anonymous")
  u_role = req_json_get(req, "role", "guest")
  res_status(res, 200)
  res_json(res, "{\"user\":\"" + u_name + "\",\"role\":\"" + u_role + "\"}")
  return res
@end

@fn mw_post_status_modifier(ctx)
  ctx_next(ctx)
  h_status = ctx.ctx_res.res_status_code
  res_header(ctx.ctx_res, "X-Handler-Status", h_status.to_str())
  return 0
@end

@fn h_status_setter(req, res)
  res_status(res, 202)
  res_text(res, "ACCEPTED_PAYLOAD")
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Web Framework Middleware & Context Verification")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! 1. HttpRequest & HttpResponse Unit Abstractions
  @! --------------------------------------------------------------------------
  req_hdrs = [
    { name: "Content-Type", value: "application/json" },
    { name: "X-Client-ID", value: "client-99" }
  ]
  req_obj = req_new("GET", "/test?query=alpha&page=2", req_hdrs, "{\"msg\":\"hi\"}", "127.0.0.1")
  
  total = total + 1
  h_ct = req_get_header(req_obj, "content-type", "")
  h_cid = req_get_header(req_obj, "X-CLIENT-ID", "")
  q_page = req_query(req_obj, "page", "1")
  is_j = req_is_json(req_obj)

  @if h_ct == "application/json" && h_cid == "client-99" && q_page == "2" && is_j == 1
    passed = passed + 1
    println("  [PASS] Test 1: HttpRequest case-insensitive headers & query lookup")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: HttpRequest header/query inspection failed")
  @end

  total = total + 1
  res_obj = res_new()
  res_status(res_obj, 201)
  res_header(res_obj, "X-Custom-Header", "Maya-V1")
  res_cookie(res_obj, "session_id", "abc123xyz", 3600, "/", 1, 1)
  res_json(res_obj, "{\"created\":true}")
  wire_str = http_response_to_wire(res_obj)

  @if res_obj.res_status_code == 201 && contains(wire_str, "HTTP/1.1 201 Created") == 1 && contains(wire_str, "Set-Cookie: session_id=abc123xyz") == 1 && contains(wire_str, "X-Custom-Header: Maya-V1") == 1
    passed = passed + 1
    println("  [PASS] Test 2: HttpResponse fluent builder & wire serialization")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: HttpResponse wire generation failed -> " + wire_str)
  @end

  @! --------------------------------------------------------------------------
  @! 2. Onion Middleware Execution Pipeline (Inward -> Outward Order)
  @! --------------------------------------------------------------------------
  app_onion = web_new()
  app_use(app_onion, mw_tracker_1)
  app_use(app_onion, mw_tracker_2)
  app_get(app_onion, "/trace", h_echo_trace)

  total = total + 1
  r_onion = app_handle_raw_request(app_onion, "GET /trace HTTP/1.1\r\n\r\n")
  @if contains(r_onion, "X-Trace: mw1_in->mw2_in->mw2_out->mw1_out") == 1 && contains(r_onion, "HANDLER_EXECUTED") == 1
    passed = passed + 1
    println("  [PASS] Test 3: Onion pipeline inward & outward execution order")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: Onion execution order failed -> " + r_onion)
  @end

  @! --------------------------------------------------------------------------
  @! 3. CORS Middleware & OPTIONS Preflight Short-Circuit
  @! --------------------------------------------------------------------------
  app_cors = web_new()
  app_use(app_cors, middleware_cors_handler)
  app_get(app_cors, "/api/data", h_echo_trace)

  total = total + 1
  r_cors_get = app_handle_raw_request(app_cors, "GET /api/data HTTP/1.1\r\n\r\n")
  @if contains(r_cors_get, "Access-Control-Allow-Origin: *") == 1 && contains(r_cors_get, "Access-Control-Allow-Methods:") == 1 && contains(r_cors_get, "HANDLER_EXECUTED") == 1
    passed = passed + 1
    println("  [PASS] Test 4: CORS header injection on standard requests")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: CORS header injection failed -> " + r_cors_get)
  @end

  total = total + 1
  r_cors_opt = app_handle_raw_request(app_cors, "OPTIONS /api/data HTTP/1.1\r\n\r\n")
  @if contains(r_cors_opt, "HTTP/1.1 204 No Content") == 1 && contains(r_cors_opt, "Access-Control-Allow-Origin: *") == 1 && contains(r_cors_opt, "HANDLER_EXECUTED") == 0
    passed = passed + 1
    println("  [PASS] Test 5: CORS OPTIONS preflight short-circuit (204 No Content)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: CORS OPTIONS preflight failed -> " + r_cors_opt)
  @end

  @! --------------------------------------------------------------------------
  @! 4. Authentication Guard Middleware
  @! --------------------------------------------------------------------------
  app_auth = web_new()
  app_use(app_auth, mw_auth_guard)
  app_get(app_auth, "/secure", h_secure_data)

  total = total + 1
  r_unauth = app_handle_raw_request(app_auth, "GET /secure HTTP/1.1\r\n\r\n")
  @if contains(r_unauth, "HTTP/1.1 401 Unauthorized") == 1 && contains(r_unauth, "401 Unauthorized: Invalid Token") == 1
    passed = passed + 1
    println("  [PASS] Test 6: Auth guard aborts unauthenticated request (401)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: Auth guard unauth failed -> " + r_unauth)
  @end

  total = total + 1
  r_auth = app_handle_raw_request(app_auth, "GET /secure HTTP/1.1\r\nAuthorization: Bearer super-secret-key\r\n\r\n")
  @if contains(r_auth, "HTTP/1.1 200 OK") == 1 && contains(r_auth, "\"secure_data\":\"vault_payload\"") == 1
    passed = passed + 1
    println("  [PASS] Test 7: Auth guard allows valid token through to route handler")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: Auth guard auth failed -> " + r_auth)
  @end

  @! --------------------------------------------------------------------------
  @! 5. JSON Body Parser Middleware
  @! --------------------------------------------------------------------------
  app_json = web_new()
  app_use(app_json, middleware_json_body_handler)
  app_post(app_json, "/api/login", h_json_reader)

  total = total + 1
  req_body_str = "{\"username\":\"arch_guru\",\"role\":\"admin\"}"
  req_json_msg = "POST /api/login HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: " + req_body_str.len().to_str() + "\r\n\r\n" + req_body_str
  r_json = app_handle_raw_request(app_json, req_json_msg)

  @if contains(r_json, "HTTP/1.1 200 OK") == 1 && contains(r_json, "\"user\":\"arch_guru\"") == 1 && contains(r_json, "\"role\":\"admin\"") == 1
    passed = passed + 1
    println("  [PASS] Test 8: JSON body parser deserializes payload into request object")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: JSON body parser failed -> " + r_json)
  @end

  @! --------------------------------------------------------------------------
  @! 6. Static File Server & MIME Resolution
  @! --------------------------------------------------------------------------
  total = total + 1
  m_html = mime_type_lookup(".html")
  m_css = mime_type_lookup("css")
  m_js = mime_type_lookup("js")
  m_json = mime_type_lookup("json")
  m_png = mime_type_lookup("png")
  m_wasm = mime_type_lookup("wasm")
  m_bin = mime_type_lookup("unknown_ext")

  @if m_html == "text/html; charset=utf-8" && m_css == "text/css; charset=utf-8" && m_js == "application/javascript; charset=utf-8" && m_png == "image/png" && m_wasm == "application/wasm" && m_bin == "application/octet-stream"
    passed = passed + 1
    println("  [PASS] Test 9: MIME type resolver for standard web asset formats")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: MIME type lookup failed")
  @end

  total = total + 1
  ctx_dummy_req = req_new("GET", "/static/../secrets.env", [], "", "127.0.0.1")
  ctx_dummy_res = res_new()
  ctx_static = http_context_new(ctx_dummy_req, ctx_dummy_res)
  mw_static_serve_run("/var/www", "/static", ctx_static)

  @if ctx_static.ctx_is_aborted == 1 && ctx_static.ctx_res.res_status_code == 403
    passed = passed + 1
    println("  [PASS] Test 10: Static file middleware directory traversal defense (403 Forbidden)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 10: Path traversal guard failed")
  @end

  @! --------------------------------------------------------------------------
  @! 7. Onion Outward Unwind Inspects Handler Status & Mutates Response
  @! --------------------------------------------------------------------------
  app_status = web_new()
  app_use(app_status, mw_post_status_modifier)
  app_get(app_status, "/status-test", h_status_setter)

  total = total + 1
  r_status = app_handle_raw_request(app_status, "GET /status-test HTTP/1.1\r\n\r\n")
  @if contains(r_status, "HTTP/1.1 202 Accepted") == 1 && contains(r_status, "X-Handler-Status: 202") == 1 && contains(r_status, "ACCEPTED_PAYLOAD") == 1
    passed = passed + 1
    println("  [PASS] Test 11: Onion middleware post-processing captures handler response status & response mutation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 11: Onion outward post-processing failed -> " + r_status)
  @end

  @! --------------------------------------------------------------------------
  @! 8. middleware_static Helper & middleware_chain_new API Verification
  @! --------------------------------------------------------------------------
  total = total + 1
  chain = middleware_chain_new()
  static_fn = middleware_static("/var/www", "/static")
  app_static = web_new()
  app_use(app_static, static_fn)
  r_stat_traversal = app_handle_raw_request(app_static, "GET /static/../secrets.env HTTP/1.1\r\n\r\n")

  @if chain.len() == 0 && contains(r_stat_traversal, "HTTP/1.1 403 Forbidden") == 1
    passed = passed + 1
    println("  [PASS] Test 12: middleware_static helper & middleware_chain_new verification")
  @else
    failed = failed + 1
    println("  [FAIL] Test 12: middleware_static helper failed -> " + r_stat_traversal)
  @end

  println("-----------------------------------------------------------------")
  println("Middleware Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Web Middleware & Context Verification PASSED (" + passed.to_str() + "/" + total.to_str() + ")")
    return 0
  @else
    println("✗ Web Middleware & Context Verification FAILED")
    return 1
  @end
@end
