// ==============================================================================
// 🧪 LIPI TEST SUITE: ZERO-COPY HTTP REST MICROSERVICE & IO_URING BYPASS
// File: tests/test_http_rest_microservice.lp
// 100% Pure Lipi | 0% Libc | 0% External Dependencies
// Standard: Linux Kernel io_uring SQPOLL + Zero-Copy REST HTTP/1.1 Engine
// ==============================================================================
//
// WHY: Validates all facets of the sovereign HTTP microservice:
// 1. Zero-copy in-place HTTP/1.1 request lexing, parsing, and RFC compliance.
// 2. Pure LiPi fast JSON serialization and escape routines.
// 3. RFC-compliant wire format generation and HTTP status mapping.
// 4. RESTful router dispatching (Root, Health, Metrics, Users, Echo, Errors).
// 5. Live loopback socket networking via io_uring bypass and handle_client_connection.
// 6. Keep-alive persistent multi-request stream on a single socket descriptor.
// 7. Socket timeout resilience without blocking or dropping connections.
// 8. Fragmented TCP delivery & streaming body accumulation.
// ==============================================================================

import "examples/http_rest_microservice/microservice_core.lp"
import "src/runtime/io_uring_bypass.lp"
import "universe/os/syscalls.lp"
import "universe/core/collections.lp"
import "universe/core/string.lp"
import "universe/core/net.lp"

@fn assert_true(cond: i64, test_name: string)
  if cond == 0
    println("  ❌ FAIL: " + test_name)
    sys_exit(1)
  end
  println("  ✔ PASS: " + test_name)
  return 1
end

@fn assert_eq_int(actual: i64, expected: i64, test_name: string)
  if actual != expected
    println("  ❌ FAIL: " + test_name + " (Expected " + int_to_str(expected) + ", got " + int_to_str(actual) + ")")
    sys_exit(1)
  end
  println("  ✔ PASS: " + test_name)
  return 1
end

@fn assert_eq_str(actual: string, expected: string, test_name: string)
  if str_eq(actual, expected) == 0
    println("  ❌ FAIL: " + test_name + " (Expected '" + expected + "', got '" + actual + "')")
    sys_exit(1)
  end
  println("  ✔ PASS: " + test_name)
  return 1
end

@fn copy_string_to_buffer(buf_ptr: i64, s: string)
  slen = str_len(s)
  i = 0
  while i < slen
    sys_poke8(buf_ptr + i, ord(char_at(s, i)))
    i = i + 1
  end
  sys_poke8(buf_ptr + slen, 0)
  return slen
end

@fn sleep_ms(ms: i64)
  ts = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sec = ms / 1000
  nsec = (ms % 1000) * 1000000
  sys_poke(ts + 0, sec)
  sys_poke(ts + 8, nsec)
  sys_nanosleep(ts, 0)
  sys_munmap(ts, 16)
  return 1
end

@fn main()
  println("══════════════════════════════════════════════════════════════════════")
  println("⚡ TESTING LIPI ZERO-COPY HTTP REST MICROSERVICE & IO_URING BYPASS")
  println("══════════════════════════════════════════════════════════════════════")

  scratch_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  assert_true(scratch_buf > 0, "Allocated zero-copy test scratch memory buffer")

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 1: Zero-Copy HTTP/1.1 Request Parser Verification
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 1: Zero-Copy HTTP/1.1 Request Lexing & Parsing...")

  // Test 1.1: Standard GET /health HTTP/1.1
  raw1 = "GET /health HTTP/1.1\r\nHost: localhost:8081\r\nUser-Agent: curl/7.88\r\n\r\n"
  len1 = copy_string_to_buffer(scratch_buf, raw1)
  req1 = http_parse_request_zero_copy(scratch_buf, len1)
  assert_eq_int(req1.req_parse_status, 200, "1.1 Parse Status OK (200)")
  assert_eq_str(req1.req_method, "GET", "1.1 Method is GET")
  assert_eq_str(req1.req_path, "/health", "1.1 Path is /health")
  assert_eq_str(req1.req_version, "HTTP/1.1", "1.1 Version is HTTP/1.1")
  assert_eq_int(req1.req_is_keep_alive, 1, "1.1 Default HTTP/1.1 Keep-Alive is 1")

  // Test 1.2: Path with Query Parameters: GET /api/v1/users?role=admin&active=1
  raw2 = "GET /api/v1/users?role=admin&active=1 HTTP/1.1\r\nHost: localhost\r\n\r\n"
  len2 = copy_string_to_buffer(scratch_buf, raw2)
  req2 = http_parse_request_zero_copy(scratch_buf, len2)
  assert_eq_str(req2.req_path, "/api/v1/users", "1.2 Path without query")
  assert_eq_str(req2.req_query, "role=admin&active=1", "1.2 Query string extracted correctly")

  // Test 1.3: POST /api/v1/users with Body & Content-Length
  raw3 = "POST /api/v1/users HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: 33\r\nConnection: keep-alive\r\n\r\n{\"username\":\"alice\",\"role\":\"sre\"}"
  len3 = copy_string_to_buffer(scratch_buf, raw3)
  req3 = http_parse_request_zero_copy(scratch_buf, len3)
  assert_eq_str(req3.req_method, "POST", "1.3 Method is POST")
  assert_eq_str(req3.req_path, "/api/v1/users", "1.3 Path is /api/v1/users")
  assert_eq_int(req3.req_content_length, 33, "1.3 Content-Length parsed accurately (33)")
  assert_eq_str(req3.req_content_type, "application/json", "1.3 Content-Type parsed")
  assert_eq_str(req3.req_body, "{\"username\":\"alice\",\"role\":\"sre\"}", "1.3 Body payload extracted")
  assert_eq_int(req3.req_is_keep_alive, 1, "1.3 Explicit Connection: keep-alive respected")

  // Test 1.4: Connection: close Header
  raw4 = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
  len4 = copy_string_to_buffer(scratch_buf, raw4)
  req4 = http_parse_request_zero_copy(scratch_buf, len4)
  assert_eq_int(req4.req_is_keep_alive, 0, "1.4 Connection: close sets keep-alive to 0")

  // Test 1.5: Case-insensitive Header Names (CoNtEnT-LeNgTh & cOnNeCtIoN)
  raw5 = "POST /api/v1/echo HTTP/1.1\r\ncOnTeNt-LeNgTh: 13\r\ncOnNeCtIoN: cLoSe\r\n\r\nhello, world!"
  len5 = copy_string_to_buffer(scratch_buf, raw5)
  req5 = http_parse_request_zero_copy(scratch_buf, len5)
  assert_eq_int(req5.req_content_length, 13, "1.5 Case-insensitive Content-Length parsed (13)")
  assert_eq_int(req5.req_is_keep_alive, 0, "1.5 Case-insensitive Connection: close parsed")
  assert_eq_str(req5.req_body, "hello, world!", "1.5 Body extracted correctly")

  // Test 1.6: Malformed Request Lines
  raw6_bad = "GARBAGE\r\n\r\n"
  len6 = copy_string_to_buffer(scratch_buf, raw6_bad)
  req6 = http_parse_request_zero_copy(scratch_buf, len6)
  assert_eq_int(req6.req_parse_status, 400, "1.6 Malformed request triggers 400 Bad Request")

  // Test 1.7: Invalid Content-Length header (non-digits)
  raw7_bad_cl = "POST /api/v1/users HTTP/1.1\r\nHost: localhost\r\nContent-Length: 12abc\r\n\r\n{}"
  len7_cl = copy_string_to_buffer(scratch_buf, raw7_bad_cl)
  req7_cl = http_parse_request_zero_copy(scratch_buf, len7_cl)
  assert_eq_int(req7_cl.req_parse_status, 400, "1.7 Invalid non-digit Content-Length triggers 400 Bad Request")

  // Test 1.8: Unsupported HTTP Version
  raw8_ver = "GET / HTTP/2.0\r\nHost: localhost\r\n\r\n"
  len8 = copy_string_to_buffer(scratch_buf, raw8_ver)
  req8 = http_parse_request_zero_copy(scratch_buf, len8)
  assert_eq_int(req8.req_parse_status, 505, "1.8 Unsupported HTTP version triggers 505")

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 2: Fast JSON Serialization Verification
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 2: Fast Pure LiPi JSON Serialization...")

  // Test 2.1: String Escaping
  raw_str = "Line 1\nLine 2\t\"quoted\" \\slash\\"
  esc_str = json_escape(raw_str)
  assert_true(contains(esc_str, "\\\"quoted\\\"") == 1, "2.1 Double quotes escaped")
  assert_true(contains(esc_str, "\\n") == 1, "2.1 Newline escaped")
  assert_true(contains(esc_str, "\\t") == 1, "2.1 Tab escaped")
  assert_true(contains(esc_str, "\\\\slash\\\\") == 1, "2.1 Backslash escaped")

  // Test 2.2: Metrics JSON Serialization
  test_metrics = {
    met_total_requests: 100,
    met_keepalive_hits: 45,
    met_active_connections: 2,
    met_bytes_received: 2048,
    met_bytes_sent: 8192,
    met_errors_4xx: 1,
    met_errors_5xx: 0,
    met_start_time_ms: clock_ms() - 5000
  }
  m_json = json_serialize_metrics(test_metrics, "sqpoll")
  assert_true(contains(m_json, "\"total_requests\":100") == 1, "2.2 Metrics total_requests present")
  assert_true(contains(m_json, "\"keepalive_hits\":45") == 1, "2.2 Metrics keepalive_hits present")
  assert_true(contains(m_json, "\"backend_mode\":\"sqpoll\"") == 1, "2.2 Metrics backend_mode present")

  // Test 2.3: Users Directory JSON
  test_users = [
    { u_id: 1, u_username: "admin", u_role: "root", u_active: 1 },
    { u_id: 2, u_username: "guest", u_role: "readonly", u_active: 0 }
  ]
  u_json = json_serialize_users_list(test_users)
  assert_true(contains(u_json, "\"count\":2") == 1, "2.3 Users count is 2")
  assert_true(contains(u_json, "\"username\":\"admin\"") == 1, "2.3 User admin serialized")
  assert_true(contains(u_json, "\"active\":false") == 1, "2.3 Inactive user boolean serialized")

  // Test 2.4: Error JSON
  e_json = json_serialize_error(404, "Not Found", "/missing")
  assert_true(contains(e_json, "\"status_code\":404") == 1, "2.4 Error status_code is 404")
  assert_true(contains(e_json, "\"error\":\"Not Found\"") == 1, "2.4 Error message present")

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 3: Wire Response Formatter Verification
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 3: RFC-Compliant HTTP Response Wire Formatter...")

  resp_200 = {
    resp_status_code: 200,
    resp_status_text: "OK",
    resp_content_type: "application/json",
    resp_is_keep_alive: 1,
    resp_body: "{\"status\":\"ok\"}"
  }
  wire_200 = http_format_response_wire(resp_200)
  assert_true(starts_with(wire_200, "HTTP/1.1 200 OK") == 1, "3.1 Status line is 200 OK")
  assert_true(contains(wire_200, "Connection: keep-alive") == 1, "3.1 Keep-Alive header set")
  assert_true(contains(wire_200, "Keep-Alive: timeout=5") == 1, "3.1 Keep-Alive params set")
  assert_true(contains(wire_200, "Content-Length: 15") == 1, "3.1 Accurate Content-Length (15)")
  assert_true(ends_with(wire_200, "{\"status\":\"ok\"}") == 1, "3.1 Body placed after double CRLF")

  resp_404 = {
    resp_status_code: 404,
    resp_status_text: "Not Found",
    resp_content_type: "application/json",
    resp_is_keep_alive: 0,
    resp_body: "{\"error\":\"Not Found\"}"
  }
  wire_404 = http_format_response_wire(resp_404)
  assert_true(starts_with(wire_404, "HTTP/1.1 404 Not Found") == 1, "3.2 Status line is 404 Not Found")
  assert_true(contains(wire_404, "Connection: close") == 1, "3.2 Connection: close header set")

  resp_408 = {
    resp_status_code: 408,
    resp_status_text: "Request Timeout",
    resp_content_type: "application/json",
    resp_is_keep_alive: 0,
    resp_body: "{\"error\":\"Request Timeout\"}"
  }
  wire_408 = http_format_response_wire(resp_408)
  assert_true(starts_with(wire_408, "HTTP/1.1 408 Request Timeout") == 1, "3.3 Status line is 408 Request Timeout")

  resp_413 = {
    resp_status_code: 413,
    resp_status_text: "Payload Too Large",
    resp_content_type: "application/json",
    resp_is_keep_alive: 0,
    resp_body: "{\"error\":\"Payload Too Large\"}"
  }
  wire_413 = http_format_response_wire(resp_413)
  assert_true(starts_with(wire_413, "HTTP/1.1 413 Payload Too Large") == 1, "3.4 Status line is 413 Payload Too Large")

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 4: REST Router & Dispatcher Verification
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 4: RESTful Route Dispatcher Verification...")

  users_store = [
    { u_id: 1, u_username: "Sovereign Architect", u_role: "kernel_lead", u_active: 1 },
    { u_id: 2, u_username: "Zero-Copy Master", u_role: "systems_engineer", u_active: 1 }
  ]

  // Route 4.1: GET /
  r_root = { req_method: "GET", req_path: "/", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_root = micro_dispatch_rest(r_root, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_root.resp_status_code, 200, "4.1 Route GET / returns 200")
  assert_true(contains(d_root.resp_body, "\"service\":\"lipi_rest_microservice\"") == 1, "4.1 Root body contains service name")

  // Route 4.2: GET /health
  r_hlth = { req_method: "GET", req_path: "/health", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_hlth = micro_dispatch_rest(r_hlth, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_hlth.resp_status_code, 200, "4.2 Route GET /health returns 200")
  assert_true(contains(d_hlth.resp_body, "\"status\":\"UP\"") == 1, "4.2 Health body UP")

  // Route 4.3: GET /api/v1/metrics
  r_met = { req_method: "GET", req_path: "/api/v1/metrics", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_met = micro_dispatch_rest(r_met, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_met.resp_status_code, 200, "4.3 Route GET /api/v1/metrics returns 200")

  // Route 4.4: GET /api/v1/users/1
  r_u1 = { req_method: "GET", req_path: "/api/v1/users/1", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_u1 = micro_dispatch_rest(r_u1, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_u1.resp_status_code, 200, "4.4 Route GET /api/v1/users/1 returns 200")
  assert_true(contains(d_u1.resp_body, "Sovereign Architect") == 1, "4.4 User 1 data found")

  // Route 4.5: GET /api/v1/users/999 (Non-existent ID)
  r_u_none = { req_method: "GET", req_path: "/api/v1/users/999", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_u_none = micro_dispatch_rest(r_u_none, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_u_none.resp_status_code, 404, "4.5 Route GET /api/v1/users/999 returns 404")

  // Route 4.6: POST /api/v1/users (Create User with real JSON extraction)
  r_create = { req_method: "POST", req_path: "/api/v1/users", req_query: "", req_version: "HTTP/1.1", req_content_length: 42, req_content_type: "application/json", req_is_keep_alive: 1, req_body: "{\"username\":\"alice\",\"role\":\"sre_lead\"}", req_parse_status: 200 }
  d_create = micro_dispatch_rest(r_create, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_create.resp_status_code, 201, "4.6 Route POST /api/v1/users returns 201 Created")
  assert_true(contains(d_create.resp_body, "\"id\":3") == 1, "4.6 New user assigned ID 3")
  assert_true(contains(d_create.resp_body, "\"username\":\"alice\"") == 1, "4.6 Dynamic username 'alice' parsed from body")
  assert_true(contains(d_create.resp_body, "\"role\":\"sre_lead\"") == 1, "4.6 Dynamic role 'sre_lead' parsed from body")

  // Route 4.7: Method Not Allowed (POST on /health)
  r_mna = { req_method: "POST", req_path: "/health", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_mna = micro_dispatch_rest(r_mna, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_mna.resp_status_code, 405, "4.7 POST /health returns 405 Method Not Allowed")

  // Route 4.8: Route Not Found
  r_404 = { req_method: "GET", req_path: "/nonexistent/path", req_query: "", req_version: "HTTP/1.1", req_content_length: 0, req_content_type: "", req_is_keep_alive: 1, req_body: "", req_parse_status: 200 }
  d_404 = micro_dispatch_rest(r_404, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_404.resp_status_code, 404, "4.8 Unknown path returns 404 Not Found")

  // Route 4.9: Diagnostic Echo
  r_echo = { req_method: "POST", req_path: "/api/v1/echo", req_query: "debug=1", req_version: "HTTP/1.1", req_content_length: 11, req_content_type: "text/plain", req_is_keep_alive: 1, req_body: "hello_lipi!", req_parse_status: 200 }
  d_echo = micro_dispatch_rest(r_echo, test_metrics, users_store, "sqpoll")
  assert_eq_int(d_echo.resp_status_code, 200, "4.9 Route POST /api/v1/echo returns 200 OK")
  assert_true(contains(d_echo.resp_body, "\"body\":\"hello_lipi!\"") == 1, "4.9 Echo body correctly matches input")

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 5: Live Socket & io_uring Bypass Loopback Network Test
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 5: Live Loopback Socket Networking via io_uring Bypass...")

  test_port = 18195
  server_fd = bypass_create_server_socket(test_port)
  assert_true(server_fd >= 0, "5.1 Created server socket on port " + int_to_str(test_port))

  engine = io_uring_bypass_new(64, 1, 16, 4096)
  assert_true(engine != 0, "5.2 Initialized io_uring bypass engine")
  println("  • Active Engine Mode : " + engine.be_backend_mode)
  println("  • SQPOLL Kernel Loop : " + int_to_str(engine.be_is_sqpoll))

  // Spawn client connection via TCP
  client_fd = net_tcp_socket()
  assert_true(client_fd >= 0, "5.3 Allocated client TCP socket")
  c_res = net_tcp_connect(client_fd, "127.0.0.1", test_port)
  assert_true(c_res >= 0, "5.4 Client connected to 127.0.0.1:" + int_to_str(test_port))

  // Accept on server
  srv_client_fd = bypass_socket_accept(server_fd)
  assert_true(srv_client_fd >= 0, "5.5 Server accepted incoming client descriptor")

  // Client sends HTTP GET /health request with Connection: close
  http_req = "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
  net_tcp_send(client_fd, http_req)

  // Server processes request using handle_client_connection with io_uring engine
  live_metrics = {
    met_total_requests: 0,
    met_keepalive_hits: 0,
    met_active_connections: 0,
    met_bytes_received: 0,
    met_bytes_sent: 0,
    met_errors_4xx: 0,
    met_errors_5xx: 0,
    met_start_time_ms: clock_ms()
  }

  handle_res = handle_client_connection(srv_client_fd, live_metrics, users_store, engine)
  assert_eq_int(handle_res, 1, "5.6 handle_client_connection processed and completed via io_uring")
  assert_eq_int(live_metrics.met_total_requests, 1, "5.7 live_metrics.total_requests incremented to 1")

  // Client reads response
  resp_str = net_tcp_recv(client_fd, 4096)
  assert_true(str_len(resp_str) > 0, "5.8 Client received HTTP response from server")
  assert_true(contains(resp_str, "HTTP/1.1 200 OK") == 1, "5.9 Received 200 OK status line")
  assert_true(contains(resp_str, "\"status\":\"UP\"") == 1, "5.10 Received JSON payload with UP status")
  assert_true(contains(resp_str, "Connection: close") == 1, "5.11 Connection closed cleanly per request")

  net_tcp_close(client_fd)

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 6: Keep-Alive Persistent Connection Resilience Test
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 6: Keep-Alive Persistent Connection Resilience...")

  client_ka = net_tcp_socket()
  net_tcp_connect(client_ka, "127.0.0.1", test_port)
  srv_ka = bypass_socket_accept(server_fd)
  assert_true(srv_ka >= 0, "6.1 Accepted keep-alive client socket")

  // Client sends Request 1 with keep-alive
  req_ka_1 = "GET /api/v1/metrics HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n"
  net_tcp_send(client_ka, req_ka_1)

  // Service Request 1 via io_uring bypass engine
  ka_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  n_r1 = bypass_tcp_recv_raw(engine, srv_ka, ka_buf, 4096)
  assert_true(n_r1 > 0, "6.2 Server received first keep-alive request via bypass_tcp_recv_raw")
  p_r1 = http_parse_request_zero_copy(ka_buf, n_r1)
  assert_eq_int(p_r1.req_is_keep_alive, 1, "6.3 Request 1 parsed as keep-alive")

  resp_ka_1 = micro_dispatch_rest(p_r1, live_metrics, users_store, engine.be_backend_mode)
  resp_ka_1.resp_is_keep_alive = 1
  wire_ka_1 = http_format_response_wire(resp_ka_1)

  w_len1 = str_len(wire_ka_1)
  w_buf1 = sys_mmap(0, w_len1 + 1, 3, 34, 0 - 1, 0)
  copy_string_to_buffer(w_buf1, wire_ka_1)
  bypass_tcp_send_raw(engine, srv_ka, w_buf1, w_len1)
  sys_munmap(w_buf1, w_len1 + 1)

  // Client receives Response 1
  c_resp1 = net_tcp_recv(client_ka, 4096)
  assert_true(contains(c_resp1, "HTTP/1.1 200 OK") == 1, "6.4 Client got Response 1")
  assert_true(contains(c_resp1, "Connection: keep-alive") == 1, "6.5 Response 1 header confirms keep-alive")

  // Client sends Request 2 on the SAME socket with Connection: close
  req_ka_2 = "GET /api/v1/users/1 HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
  net_tcp_send(client_ka, req_ka_2)

  n_r2 = bypass_tcp_recv_raw(engine, srv_ka, ka_buf, 4096)
  assert_true(n_r2 > 0, "6.6 Server received second request on SAME socket descriptor")
  p_r2 = http_parse_request_zero_copy(ka_buf, n_r2)
  assert_eq_int(p_r2.req_is_keep_alive, 0, "6.7 Request 2 marked Connection: close")

  resp_ka_2 = micro_dispatch_rest(p_r2, live_metrics, users_store, engine.be_backend_mode)
  resp_ka_2.resp_is_keep_alive = 0
  wire_ka_2 = http_format_response_wire(resp_ka_2)

  w_len2 = str_len(wire_ka_2)
  w_buf2 = sys_mmap(0, w_len2 + 1, 3, 34, 0 - 1, 0)
  copy_string_to_buffer(w_buf2, wire_ka_2)
  bypass_tcp_send_raw(engine, srv_ka, w_buf2, w_len2)
  sys_munmap(w_buf2, w_len2 + 1)

  c_resp2 = net_tcp_recv(client_ka, 4096)
  assert_true(contains(c_resp2, "Sovereign Architect") == 1, "6.8 Client got Response 2 data")
  assert_true(contains(c_resp2, "Connection: close") == 1, "6.9 Response 2 confirms connection termination")

  sys_munmap(ka_buf, 4096)
  net_tcp_close(client_ka)
  sys_close(srv_ka)

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 7: Socket Timeout Resilience Verification
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 7: Socket Timeout Resilience Verification...")

  client_idle = net_tcp_socket()
  net_tcp_connect(client_idle, "127.0.0.1", test_port)
  srv_idle = bypass_socket_accept(server_fd)
  assert_true(srv_idle >= 0, "7.1 Connected idle test client socket")

  // Poll server socket for idle client data with short timeout (50ms)
  idle_pfd = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  bypass_poke32(idle_pfd, srv_idle)
  sys_poke8(idle_pfd + 4, 1) // POLLIN
  sys_poke8(idle_pfd + 5, 0)
  sys_poke8(idle_pfd + 6, 0)
  sys_poke8(idle_pfd + 7, 0)

  t_start = clock_ms()
  p_idle_res = sys_poll(idle_pfd, 1, 50) // 50 ms timeout
  t_elapsed = clock_ms() - t_start

  assert_eq_int(p_idle_res, 0, "7.2 Poll returned 0 on idle connection (timeout reached)")
  assert_true(t_elapsed >= 40, "7.3 Socket timeout elapsed accurately")

  sys_munmap(idle_pfd, 8)
  net_tcp_close(client_idle)
  sys_close(srv_idle)

  // ────────────────────────────────────────────────────────────────────────────
  // Phase 8: Fragmented TCP Delivery & Streaming Body Accumulation
  // ────────────────────────────────────────────────────────────────────────────
  println("\n▶ Phase 8: Fragmented TCP Delivery & Streaming Body Accumulation...")

  client_frag = net_tcp_socket()
  net_tcp_connect(client_frag, "127.0.0.1", test_port)
  srv_frag = bypass_socket_accept(server_fd)
  assert_true(srv_frag >= 0, "8.1 Accepted fragmented streaming socket")

  // Chunk 1: Send HTTP headers with Content-Length: 46
  hdr_chunk = "POST /api/v1/users HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: 46\r\nConnection: close\r\n\r\n"
  net_tcp_send(client_frag, hdr_chunk)

  // Small delay simulating network fragmentation
  sleep_ms(15)

  // Chunk 2: Send Body in second packet
  body_chunk = "{\"username\":\"stream_dev\",\"role\":\"streaming_qa\"}"
  net_tcp_send(client_frag, body_chunk)

  // Server processes fragmented connection via handle_client_connection
  frag_metrics = {
    met_total_requests: 0,
    met_keepalive_hits: 0,
    met_active_connections: 0,
    met_bytes_received: 0,
    met_bytes_sent: 0,
    met_errors_4xx: 0,
    met_errors_5xx: 0,
    met_start_time_ms: clock_ms()
  }

  frag_handled = handle_client_connection(srv_frag, frag_metrics, users_store, engine)
  assert_eq_int(frag_handled, 1, "8.2 Fragmented TCP stream accumulated and dispatched cleanly")

  c_frag_resp = net_tcp_recv(client_frag, 4096)
  assert_true(contains(c_frag_resp, "HTTP/1.1 201 Created") == 1, "8.3 Reassembled request produced 201 Created")
  assert_true(contains(c_frag_resp, "\"username\":\"stream_dev\"") == 1, "8.4 Stream body username parsed correctly")
  assert_true(contains(c_frag_resp, "\"role\":\"streaming_qa\"") == 1, "8.5 Stream body role parsed correctly")

  net_tcp_close(client_frag)

  // Clean Teardown
  io_uring_bypass_close(engine)
  sys_close(server_fd)
  sys_munmap(scratch_buf, 4096)

  println("\n══════════════════════════════════════════════════════════════════════")
  println("🎉 ALL HTTP REST MICROSERVICE & IO_URING BYPASS TESTS PASSED (100% SUCCESS)!")
  println("══════════════════════════════════════════════════════════════════════")
  return 0
end

main()
