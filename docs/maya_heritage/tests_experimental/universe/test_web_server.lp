@! ============================================================================
@! MAYA UNIVERSE WEB — SOVEREIGN WEB SERVER LIVE TCP E2E TEST SUITE
@! tests/universe/test_web_server.maya
@! ============================================================================

import "universe/net/http"
import "universe/net/tcp"
import "universe/os/process"
import "universe/os/syscalls"
import "universe/web/context"
import "universe/web/middleware"
import "universe/web/server"
import "universe/web/app"
import "universe/core/string"

@fn h_root(req, res)
  res_status(res, 200)
  res_html(res, "<h1>Maya Sovereign Web Server Active</h1>")
  return res
@end

@fn h_echo(req, res)
  res_status(res, 201)
  res_json(res, "{\"status\":\"created\",\"received\":" + req.req_body + "}")
  return res
@end

@fn h_item(req, res)
  iid = req_param(req, "id", "unknown")
  res_status(res, 200)
  res_json(res, "{\"item_id\":\"" + iid + "\",\"in_stock\":true,\"currency\":\"USD\"}")
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Sovereign TCP Web Server Live E2E Verification")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  app = web_new()
  app_use(app, middleware_cors_handler)

  app_get(app, "/", h_root)
  app_post(app, "/api/echo", h_echo)

  v1 = app_group(app, "/api/v1")
  group_get(v1, "/items/:id", h_item)

  srv = web_server_new(app)
  base_pid = process_getpid()
  port = 35000 + (base_pid % 5000)

  @! Fork child server process
  srv_pid = process_fork()
  @if srv_pid == 0
    @! Child server process: serve 5 requests then exit cleanly
    web_server_listen_limited(srv, "127.0.0.1", port, 5)
    exit(0)
  @end

  @! Allow server socket to bind and listen
  ts = { sec: 0, nsec: 200000000 }
  sys_nanosleep(ts, 0) @! 200ms
  url_base = "http://127.0.0.1:" + port.to_str()

  @! --------------------------------------------------------------------------
  @! 1. Live TCP GET /
  @! --------------------------------------------------------------------------
  total = total + 1
  r1 = http_get(url_base + "/")
  @if r1.status_code == 200 && contains(r1.body, "<h1>Maya Sovereign Web Server Active</h1>") == 1
    passed = passed + 1
    println("  [PASS] Test 1: Live TCP GET / returned 200 OK HTML")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: Live TCP GET / failed -> status=" + r1.status_code.to_str() + " body=" + r1.body)
  @end

  @! --------------------------------------------------------------------------
  @! 2. Live TCP POST /api/echo
  @! --------------------------------------------------------------------------
  total = total + 1
  post_payload = "{\"sensor_id\":\"TEMP_01\",\"reading\":23.5}"
  post_hdrs = [{ name: "Content-Type", value: "application/json" }]
  r2 = http_post(url_base + "/api/echo", post_hdrs, post_payload)
  @if r2.status_code == 201 && contains(r2.body, "\"status\":\"created\"") == 1 && contains(r2.body, "TEMP_01") == 1
    passed = passed + 1
    println("  [PASS] Test 2: Live TCP POST /api/echo returned 201 Created and JSON payload")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: Live TCP POST failed -> status=" + r2.status_code.to_str() + " body=" + r2.body)
  @end

  @! --------------------------------------------------------------------------
  @! 3. Live TCP Route Group with Param Extraction
  @! --------------------------------------------------------------------------
  total = total + 1
  r3 = http_get(url_base + "/api/v1/items/m3-silicon-chip")
  @if r3.status_code == 200 && contains(r3.body, "\"item_id\":\"m3-silicon-chip\"") == 1 && contains(r3.body, "\"in_stock\":true") == 1
    passed = passed + 1
    println("  [PASS] Test 3: Live TCP GET /api/v1/items/:id returned extracted route parameters")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: Live TCP GET route group failed -> status=" + r3.status_code.to_str() + " body=" + r3.body)
  @end

  @! --------------------------------------------------------------------------
  @! 4. Live TCP 404 Not Found
  @! --------------------------------------------------------------------------
  total = total + 1
  r4 = http_get(url_base + "/unmapped/nonexistent/service")
  @if r4.status_code == 404 && contains(r4.body, "404 Not Found") == 1
    passed = passed + 1
    println("  [PASS] Test 4: Live TCP GET on unmapped route returned 404 Not Found")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: Live TCP 404 test failed -> status=" + r4.status_code.to_str() + " body=" + r4.body)
  @end

  @! --------------------------------------------------------------------------
  @! 5. Live TCP 405 Method Not Allowed with Allow Header
  @! --------------------------------------------------------------------------
  total = total + 1
  @! Send POST to root route (which only accepts GET)
  r5 = http_post(url_base + "/", post_hdrs, "")
  has_allow = 0
  i = 0
  @while i < r5.headers.len()
    h = r5.headers[i]
    @if str_to_lower(h.name) == "allow" && contains(h.value, "GET") == 1
      has_allow = 1
    @end
    i = i + 1
  @end

  @if r5.status_code == 405 && has_allow == 1
    passed = passed + 1
    println("  [PASS] Test 5: Live TCP POST on GET-only route returned 405 with Allow header")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: Live TCP 405 test failed -> status=" + r5.status_code.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! 6. Clean Server Child Process Termination
  @! --------------------------------------------------------------------------
  total = total + 1
  srv_st = process_wait(srv_pid)
  srv_ex = (srv_st / 256) & 255
  @if srv_ex == 0
    passed = passed + 1
    println("  [PASS] Test 6: Web server child process terminated cleanly with exit code 0")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: Server process exited with abnormal exit code " + srv_ex.to_str())
  @end

  println("-----------------------------------------------------------------")
  println("Server E2E Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Sovereign Web Server Live E2E Verification PASSED (" + passed.to_str() + "/" + total.to_str() + ")")
    return 0
  @else
    println("✗ Sovereign Web Server Live E2E Verification FAILED")
    return 1
  @end
@end
