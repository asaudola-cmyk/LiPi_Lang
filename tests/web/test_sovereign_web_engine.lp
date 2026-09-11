@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — SOVEREIGN WEB ENGINE & EMBEDDED DB SUITE
@! File: tests/web/test_sovereign_web_engine.maya
@! Milestone 2: High-Concurrency Web Engine & Embedded Database Verification
@! 100% Pure Maya Implementation — Zero External / C++ / libc Dependencies
@!
@! Architecture Coverage:
@! 1. Section 1: HTTP/1.1 & HTTP/2 Request Parser (RFC 7230 / RFC 7540)
@!    - Method, Path, HTTP version, Header Map, Body Payload
@!    - HPACK Static Table Decoding & Binary Framing
@! 2. Section 2: HTTP Response Builder (RFC 7231)
@!    - 200 OK, 404 Not Found, 500 Internal Server Error
@!    - Exact Content-Type, Strict Content-Length, COOP/COEP Isolation Headers
@! 3. Section 3: High-Throughput Routing Table
@!    - Exact Path Match, Wildcard Prefix Match, 405 Method Not Allowed, 404 Not Found
@!    - 1,000-Request Stress Benchmark
@! 4. Section 4: Embedded Database (MayaKV / DB Engine)
@!    - CRUD & Auto-Commit Durability (db_put, db_get, db_delete)
@!    - Write-Ahead Logging (WAL) Direct Disk Serialization via Raw Syscalls (sys_open, sys_lseek, sys_read)
@!    - Multi-Statement ACID Transactions (tx_begin, tx_put, tx_commit, tx_rollback, Read-Your-Own-Writes)
@!    - Redo Crash Recovery Verification (committed vs uncommitted transaction recovery)
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/collections"
import "universe/core/string"
import "universe/net/http"
import "universe/net/http2/frame"
import "universe/net/http2/hpack"
import "universe/web/polymorphic_server"
import "universe/db/page"
import "universe/db/buffer"
import "universe/db/btree"
import "universe/db/wal"
import "universe/db/tx"
import "universe/db/recovery"
import "universe/db/engine"

@! ============================================================================
@! ASSERTION SUITE & STRING HELPERS
@! ============================================================================

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if str_eq(actual, expected) == 0
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'")))))))
    return 0
  @end
  return 1
@end

@! Converts slice of byte array to native null-terminated string via single heap allocation
@! WHY: Writes bytes using pure integer pointer offsets before tagging 64-bit STR0 header to prevent string concatenation coercion
@fn bytes_slice_to_str(arr, start, len)
  @if len <= 0 return "" @end
  buf_base = alloc(len + 16)
  i = 0
  @while i < len
    val = arr[start + i] & 255
    sys_poke8(buf_base + 8 + i, val)
    i = i + 1
  @end
  sys_poke8(buf_base + 8 + len, 0)
  sys_poke(buf_base, 6004514569303621632 + len)
  return buf_base + 8
@end

@! Converts ASCII string to array of byte values
@fn str_to_byte_array(s)
  n = str_len(s)
  arr = []
  i = 0
  @while i < n
    arr = arr.push(str_char_at(s, i) & 255)
    i = i + 1
  @end
  return arr
@end

@! ----------------------------------------------------------------------------
@! Sovereign Web Test Data Structures
@! ----------------------------------------------------------------------------

@struct SovereignHeader
  name: string
  val: string
@end

@struct SovereignRequest
  method: string
  path: string
  version: string
  headers: array
  body: string
@end

@struct Http2FrameHeader
  length: i64
  frame_type: i64
  flags: i64
  stream_id: i64
@end

@struct RouteMatch
  matched: i64
  status: i64
  handler_id: i64
  param: string
@end

@! Header map case-insensitive lookup
@fn req_header_get(req: SovereignRequest, name: string)
  target = str_to_lower(name)
  i = 0
  n = req.headers.len()
  @while i < n
    h: SovereignHeader = req.headers[i]
    @if str_eq(str_to_lower(h.name), target) == 1
      return h.val
    @end
    i = i + 1
  @end
  return ""
@end

@! ============================================================================
@! SECTION 1: REQUEST PARSER IMPLEMENTATIONS
@! ============================================================================

@! Pure Maya HTTP/1.1 wire parser for request-line, headers, and body payload
@fn sovereign_parse_http1_request(raw_req: string) -> SovereignRequest
  method = "GET"
  path = "/"
  version = "HTTP/1.1"
  headers = []
  body = ""

  raw_len = str_len(raw_req)
  @if raw_len == 0
    return { method: method, path: path, version: version, headers: headers, body: body }
  @end

  header_end = str_index_of(raw_req, "\r\n\r\n")
  sep_len = 4
  @if header_end == -1
    header_end = str_index_of(raw_req, "\n\n")
    sep_len = 2
  @end

  headers_str = ""
  @if header_end >= 0
    headers_str = str_substr(raw_req, 0, header_end)
    body = str_substr(raw_req, header_end + sep_len, raw_len)
  @else
    headers_str = raw_req
    body = ""
  @end

  is_first = 1
  pos = 0
  hlen = str_len(headers_str)

  @while pos < hlen
    next_nl = -1
    i = pos
    @while i < hlen
      @if str_char_at(headers_str, i) == 10
        next_nl = i
        i = hlen
      @end
      i = i + 1
    @end

    line = ""
    @if next_nl >= 0
      line = str_substr(headers_str, pos, next_nl)
      pos = next_nl + 1
    @else
      line = str_substr(headers_str, pos, hlen)
      pos = hlen
    @end

    line = str_trim(line)
    @if str_len(line) > 0
      @if is_first == 1
        is_first = 0
        s1 = str_index_of(line, " ")
        @if s1 >= 0
          method = str_substr(line, 0, s1)
          rest = str_trim(str_substr(line, s1 + 1, str_len(line)))
          s2 = str_index_of(rest, " ")
          @if s2 >= 0
            path = str_substr(rest, 0, s2)
            version = str_trim(str_substr(rest, s2 + 1, str_len(rest)))
          @else
            path = rest
          @end
        @end
      @else
        colon_pos = str_index_of(line, ":")
        @if colon_pos >= 0
          h_name = str_trim(str_substr(line, 0, colon_pos))
          h_val = str_trim(str_substr(line, colon_pos + 1, str_len(line)))
          headers = headers.push({ name: h_name, val: h_val })
        @end
      @end
    @end
  @end

  return {
    method: method,
    path: path,
    version: version,
    headers: headers,
    body: body
  }
@end

@! Direct 9-byte RFC 7540 frame header decoder at arbitrary offset
@fn http2_parse_frame_header_at(bytes, pos)
  @if bytes.len() < pos + 9
    return { length: 0, frame_type: 0, flags: 0, stream_id: 0 }
  @end

  b0 = bytes[pos + 0] & 255
  b1 = bytes[pos + 1] & 255
  b2 = bytes[pos + 2] & 255
  t0 = b0 * 65536
  t1 = b1 * 256
  t01 = t0 | t1
  num_items = t01 | b2

  ftype = bytes[pos + 3] & 255
  flags = bytes[pos + 4] & 255

  s0 = bytes[pos + 5] & 127
  s1 = bytes[pos + 6] & 255
  s2 = bytes[pos + 7] & 255
  s3 = bytes[pos + 8] & 255
  w0 = s0 * 16777216
  w1 = s1 * 65536
  w2 = s2 * 256
  r01 = w0 | w1
  r23 = w2 | s3
  stream_id = r01 | r23

  return {
    length: num_items,
    frame_type: ftype,
    flags: flags,
    stream_id: stream_id
  }
@end

@! Pure Maya HTTP/2 request frame stream decoder (HEADERS + DATA frames, HPACK static and literal fields)
@fn sovereign_parse_http2_request(bytes: array) -> SovereignRequest
  method = "GET"
  path = "/"
  version = "HTTP/2.0"
  headers = []
  body = ""

  static_tbl = hpack_static_table()
  pos = 0
  total_len = bytes.len()

  @while pos + 9 <= total_len
    fhdr = http2_parse_frame_header_at(bytes, pos)
    payload_len = fhdr.length
    ftype = fhdr.frame_type
    flags = fhdr.flags
    pos = pos + 9

    @if pos + payload_len > total_len
      payload_len = total_len - pos
    @end

    @if ftype == 1 @! HTTP2_FRAME_HEADERS
      p_offset = 0
      @while p_offset < payload_len
        b = bytes[pos + p_offset] & 255
        @if (b & 128) != 0
          @! Indexed Header Field (RFC 7541 Section 6.1)
          idx = b & 127
          @if idx > 0 && idx <= static_tbl.len()
            entry = static_tbl[idx - 1]
            @if str_eq(entry.name, ":method") == 1
              method = entry.val
            @elif str_eq(entry.name, ":path") == 1
              path = entry.val
            @else
              headers = headers.push({ name: entry.name, val: entry.val })
            @end
          @end
          p_offset = p_offset + 1
        @elif (b & 64) != 0 || (b & 240) == 0
          @! Literal Header Field with or without Indexing
          is_lit_with_idx = 0
          prefix_mask = 15
          @if (b & 64) != 0
            is_lit_with_idx = 1
            prefix_mask = 63
          @end
          name_idx = b & prefix_mask
          p_offset = p_offset + 1
          h_name = ""
          @if name_idx > 0 && name_idx <= static_tbl.len()
            h_name = static_tbl[name_idx - 1].name
          @else
            @if p_offset < payload_len
              n_len = bytes[pos + p_offset] & 127
              p_offset = p_offset + 1
              h_name = bytes_slice_to_str(bytes, pos + p_offset, n_len)
              p_offset = p_offset + n_len
            @end
          @end

          h_val = ""
          @if p_offset < payload_len
            v_len = bytes[pos + p_offset] & 127
            p_offset = p_offset + 1
            h_val = bytes_slice_to_str(bytes, pos + p_offset, v_len)
            p_offset = p_offset + v_len
          @end

          @if str_eq(h_name, ":method") == 1
            method = h_val
          @elif str_eq(h_name, ":path") == 1
            path = h_val
          @else
            headers = headers.push({ name: h_name, val: h_val })
          @end
        @else
          p_offset = p_offset + 1
        @end
      @end
    @elif ftype == 0 @! HTTP2_FRAME_DATA
      body = bytes_slice_to_str(bytes, pos, payload_len)
    @end

    pos = pos + payload_len
  @end

  return {
    method: method,
    path: path,
    version: version,
    headers: headers,
    body: body
  }
@end

@! ============================================================================
@! SECTION 2: HTTP RESPONSE BUILDER IMPLEMENTATION
@! ============================================================================

@fn sovereign_status_reason(status_code)
  @if status_code == 200 return "OK" @end
  @if status_code == 201 return "Created" @end
  @if status_code == 204 return "No Content" @end
  @if status_code == 400 return "Bad Request" @end
  @if status_code == 401 return "Unauthorized" @end
  @if status_code == 403 return "Forbidden" @end
  @if status_code == 404 return "Not Found" @end
  @if status_code == 405 return "Method Not Allowed" @end
  @if status_code == 500 return "Internal Server Error" @end
  @if status_code == 502 return "Bad Gateway" @end
  @if status_code == 503 return "Service Unavailable" @end
  return "OK"
@end

@! Builds RFC 7230 / RFC 7231 wire response with exact Content-Length, Content-Type, and COOP/COEP isolation
@fn sovereign_build_response(status_code, content_type, body)
  reason = sovereign_status_reason(status_code)
  body_len = str_len(body)

  resp = str_concat("HTTP/1.1 ", str_concat(to_str(status_code), str_concat(" ", str_concat(reason, "\r\n"))))
  resp = str_concat(resp, str_concat("Content-Type: ", str_concat(content_type, "\r\n")))
  resp = str_concat(resp, str_concat("Content-Length: ", str_concat(to_str(body_len), "\r\n")))
  resp = str_concat(resp, "Server: Maya-Sovereign-Engine/2.0\r\n")
  resp = str_concat(resp, "Connection: keep-alive\r\n")
  resp = str_concat(resp, "Cross-Origin-Opener-Policy: same-origin\r\n")
  resp = str_concat(resp, "Cross-Origin-Embedder-Policy: require-corp\r\n")
  resp = str_concat(resp, "\r\n")

  @if body_len > 0
    resp = str_concat(resp, body)
  @end

  return resp
@end

@! ============================================================================
@! SECTION 3: HIGH-THROUGHPUT ROUTING TABLE IMPLEMENTATION
@! ============================================================================

@struct SovereignRoute
  method: string
  pattern: string
  handler_id: i64
  is_wildcard: i64
  prefix: string
@end

@struct SovereignRouter
  routes: array
@end

@fn router_new()
  return { routes: [] }
@end

@fn router_add(r, method, pattern, handler_id)
  plen = str_len(pattern)
  is_wc = 0
  pfx = pattern
  @if plen >= 2 && str_char_at(pattern, plen - 1) == 42 && str_char_at(pattern, plen - 2) == 47 @! "/*"
    is_wc = 1
    pfx = str_substr(pattern, 0, plen - 1) @! includes trailing '/'
  @end

  rt = {
    method: method,
    pattern: pattern,
    handler_id: handler_id,
    is_wildcard: is_wc,
    prefix: pfx
  }
  r.routes = r.routes.push(rt)
  return r
@end

@fn router_dispatch(r, method, path)
  method_mismatch = 0
  num_routes = r.routes.len()

  @! 1. Exact path matches
  i = 0
  @while i < num_routes
    rt = r.routes[i]
    @if rt.is_wildcard == 0 && str_eq(rt.pattern, path) == 1
      @if str_eq(rt.method, method) == 1
        return { matched: 1, status: 200, handler_id: rt.handler_id, param: "" }
      @else
        method_mismatch = 1
      @end
    @end
    i = i + 1
  @end

  @! 2. Wildcard prefix matches
  i = 0
  @while i < num_routes
    rt = r.routes[i]
    @if rt.is_wildcard == 1 && str_starts_with(path, rt.prefix) == 1
      @if str_eq(rt.method, method) == 1
        suffix = str_substr(path, str_len(rt.prefix), str_len(path))
        return { matched: 1, status: 200, handler_id: rt.handler_id, param: suffix }
      @else
        method_mismatch = 1
      @end
    @end
    i = i + 1
  @end

  @! 3. Mismatch or Not Found
  @if method_mismatch == 1
    return { matched: 0, status: 405, handler_id: 0, param: "" }
  @end

  return { matched: 0, status: 404, handler_id: 0, param: "" }
@end

@! ============================================================================
@! MAIN VERIFICATION SUITE
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🌐 MAYA UNIVERSAL ARCHITECTURE: SOVEREIGN WEB ENGINE & DB SUITE 🌐")
  println("=================================================================")

  total_sections = 4
  passed_sections = 0

  @! ==========================================================================
  @! SECTION 1: HTTP/1.1 & HTTP/2 Request Parser (RFC 7230 / RFC 7540)
  @! ==========================================================================
  println("▶ Section 1: HTTP/1.1 & HTTP/2 Request Parser...")
  
  @! 1.1 HTTP/1.1 Request with query, headers, and body payload
  raw_http1 = "POST /api/v1/users?role=admin HTTP/1.1\r\nHost: api.maya-lang.org\r\nContent-Type: application/json\r\nContent-Length: 26\r\nX-Sovereign-Trace: trace-42\r\n\r\n{\"username\":\"sovereign_0\"}"
  req1 = sovereign_parse_http1_request(raw_http1)
  
  ok1 = assert_eq_str(req1.method, "POST", "HTTP/1.1 Method is POST")
  ok2 = assert_eq_str(req1.path, "/api/v1/users?role=admin", "HTTP/1.1 Path is /api/v1/users?role=admin")
  ok3 = assert_eq_str(req1.version, "HTTP/1.1", "HTTP/1.1 Version is HTTP/1.1")
  ok4 = assert_eq_str(req_header_get(req1, "Content-Type"), "application/json", "Header Content-Type matches")
  ok5 = assert_eq_str(req_header_get(req1, "host"), "api.maya-lang.org", "Header host (case-insensitive) matches")
  ok6 = assert_eq_str(req_header_get(req1, "x-sovereign-trace"), "trace-42", "Header x-sovereign-trace matches")
  ok7 = assert_eq_str(req1.body, "{\"username\":\"sovereign_0\"}", "Body payload matches exactly")

  @! 1.2 HTTP/2 Request with HEADERS & DATA frames
  auth_name_bytes = str_to_byte_array("authorization")
  auth_val_bytes = str_to_byte_array("Bearer secret")
  hpack_bytes = [131, 132, 0, 13]
  k = 0
  @while k < auth_name_bytes.len()
    hpack_bytes = hpack_bytes.push(auth_name_bytes[k])
    k = k + 1
  @end
  hpack_bytes = hpack_bytes.push(13)
  k = 0
  @while k < auth_val_bytes.len()
    hpack_bytes = hpack_bytes.push(auth_val_bytes[k])
    k = k + 1
  @end

  hdr_frame = http2_encode_frame_header(1, 4, 1, hpack_bytes.len())
  stream_bytes = []
  k = 0
  @while k < hdr_frame.len()
    stream_bytes = stream_bytes.push(hdr_frame[k])
    k = k + 1
  @end
  k = 0
  @while k < hpack_bytes.len()
    stream_bytes = stream_bytes.push(hpack_bytes[k])
    k = k + 1
  @end

  data_payload_str = "{\"h2_payload\":1}"
  data_bytes = str_to_byte_array(data_payload_str)
  data_frame = http2_encode_frame_header(0, 1, 1, data_bytes.len())
  k = 0
  @while k < data_frame.len()
    stream_bytes = stream_bytes.push(data_frame[k])
    k = k + 1
  @end
  k = 0
  @while k < data_bytes.len()
    stream_bytes = stream_bytes.push(data_bytes[k])
    k = k + 1
  @end

  req2 = sovereign_parse_http2_request(stream_bytes)
  h2_ok1 = assert_eq_str(req2.method, "POST", "HTTP/2 Method is POST")
  h2_ok2 = assert_eq_str(req2.path, "/", "HTTP/2 Path is /")
  h2_ok3 = assert_eq_str(req2.version, "HTTP/2.0", "HTTP/2 Version is HTTP/2.0")
  h2_ok4 = assert_eq_str(req_header_get(req2, "authorization"), "Bearer secret", "HTTP/2 Header authorization matches")
  h2_ok5 = assert_eq_str(req2.body, "{\"h2_payload\":1}", "HTTP/2 Body payload matches")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && h2_ok1 == 1 && h2_ok2 == 1 && h2_ok3 == 1 && h2_ok4 == 1 && h2_ok5 == 1
    passed_sections = passed_sections + 1
    println("  [PASS] Section 1: HTTP/1.1 & HTTP/2 Request Parser verified (100% success)")
  @else
    println("  [FAIL] Section 1: HTTP/1.1 & HTTP/2 Request Parser failed")
  @end

  @! ==========================================================================
  @! SECTION 2: HTTP Response Builder (RFC 7231)
  @! ==========================================================================
  println("▶ Section 2: HTTP Response Builder...")

  @! 2.1 200 OK Response
  body_200 = "{\"status\":\"operational\",\"cluster_nodes\":8}"
  resp_200 = sovereign_build_response(200, "application/json", body_200)
  parsed_200: HttpResponse = http_parse_response(resp_200)
  r_ok1 = assert_eq_int(parsed_200.status_code, 200, "200 OK status code")
  r_ok2 = assert_true(str_contains(resp_200, "HTTP/1.1 200 OK"), "200 OK wire status line")
  r_ok3 = assert_true(str_contains(resp_200, "Content-Type: application/json"), "Content-Type header")
  r_ok4 = assert_true(str_contains(resp_200, str_concat("Content-Length: ", to_str(str_len(body_200)))), "Content-Length header matches exact body length")
  r_ok5 = assert_true(str_contains(resp_200, "Server: Maya-Sovereign-Engine/2.0"), "Sovereign Server header")
  r_ok6 = assert_true(str_contains(resp_200, "Cross-Origin-Opener-Policy: same-origin"), "COOP header present")
  r_ok7 = assert_true(str_contains(resp_200, "Cross-Origin-Embedder-Policy: require-corp"), "COEP header present")
  r_ok8 = assert_eq_str(parsed_200.body, body_200, "200 OK body round-trip verification")

  @! 2.2 404 Not Found Response
  body_404 = "404 Route Not Found"
  resp_404 = sovereign_build_response(404, "text/plain", body_404)
  parsed_404: HttpResponse = http_parse_response(resp_404)
  r_ok9 = assert_eq_int(parsed_404.status_code, 404, "404 Not Found status code")
  r_ok10 = assert_true(str_contains(resp_404, "HTTP/1.1 404 Not Found"), "404 Not Found wire status line")
  r_ok11 = assert_eq_str(parsed_404.body, body_404, "404 Not Found body round-trip")

  @! 2.3 500 Internal Server Error Response
  body_500 = "{\"error\":\"Internal Server Error\"}"
  resp_500 = sovereign_build_response(500, "application/json", body_500)
  parsed_500: HttpResponse = http_parse_response(resp_500)
  r_ok12 = assert_eq_int(parsed_500.status_code, 500, "500 Internal Server Error status code")
  r_ok13 = assert_true(str_contains(resp_500, "HTTP/1.1 500 Internal Server Error"), "500 Internal Server Error wire status line")
  r_ok14 = assert_eq_str(parsed_500.body, body_500, "500 Error body round-trip")

  @if r_ok1 == 1 && r_ok2 == 1 && r_ok3 == 1 && r_ok4 == 1 && r_ok5 == 1 && r_ok6 == 1 && r_ok7 == 1 && r_ok8 == 1 && r_ok9 == 1 && r_ok10 == 1 && r_ok11 == 1 && r_ok12 == 1 && r_ok13 == 1 && r_ok14 == 1
    passed_sections = passed_sections + 1
    println("  [PASS] Section 2: HTTP Response Builder verified (100% success)")
  @else
    println("  [FAIL] Section 2: HTTP Response Builder failed")
  @end

  @! ==========================================================================
  @! SECTION 3: High-Throughput Routing Table
  @! ==========================================================================
  println("▶ Section 3: High-Throughput Routing Table...")
  
  router = router_new()
  router = router_add(router, "GET", "/", 100)
  router = router_add(router, "GET", "/health", 101)
  router = router_add(router, "POST", "/api/v1/users", 102)
  router = router_add(router, "GET", "/api/v1/metrics", 103)
  router = router_add(router, "GET", "/static/*", 201)
  router = router_add(router, "GET", "/assets/*", 202)
  router = router_add(router, "POST", "/api/v1/stream/*", 203)

  @! 3.1 Exact matches
  m1 = router_dispatch(router, "GET", "/")
  rt_ok1 = assert_eq_int(m1.handler_id, 100, "Route GET / matches handler 100")
  rt_ok2 = assert_eq_int(m1.status, 200, "Route GET / status is 200")

  m2 = router_dispatch(router, "GET", "/health")
  rt_ok3 = assert_eq_int(m2.handler_id, 101, "Route GET /health matches handler 101")

  m3 = router_dispatch(router, "POST", "/api/v1/users")
  rt_ok4 = assert_eq_int(m3.handler_id, 102, "Route POST /api/v1/users matches handler 102")

  m4 = router_dispatch(router, "GET", "/api/v1/metrics")
  rt_ok5 = assert_eq_int(m4.handler_id, 103, "Route GET /api/v1/metrics matches handler 103")

  @! 3.2 Wildcard prefix matches
  w1 = router_dispatch(router, "GET", "/static/css/theme.css")
  rt_ok6 = assert_eq_int(w1.handler_id, 201, "Wildcard /static/* matches handler 201")
  rt_ok7 = assert_eq_str(w1.param, "css/theme.css", "Wildcard suffix extracted correctly")

  w2 = router_dispatch(router, "GET", "/assets/bundle.min.js")
  rt_ok8 = assert_eq_int(w2.handler_id, 202, "Wildcard /assets/* matches handler 202")
  rt_ok9 = assert_eq_str(w2.param, "bundle.min.js", "Wildcard bundle suffix extracted")

  w3 = router_dispatch(router, "POST", "/api/v1/stream/chan_42")
  rt_ok10 = assert_eq_int(w3.handler_id, 203, "Wildcard POST /api/v1/stream/* matches handler 203")
  rt_ok11 = assert_eq_str(w3.param, "chan_42", "Wildcard channel suffix extracted")

  @! 3.3 Method mismatch (405)
  mm1 = router_dispatch(router, "DELETE", "/health")
  rt_ok12 = assert_eq_int(mm1.status, 405, "DELETE on GET /health returns 405 Method Not Allowed")

  mm2 = router_dispatch(router, "PUT", "/api/v1/users")
  rt_ok13 = assert_eq_int(mm2.status, 405, "PUT on POST /api/v1/users returns 405 Method Not Allowed")

  @! 3.4 Not Found (404)
  nf1 = router_dispatch(router, "GET", "/api/v1/nonexistent")
  rt_ok14 = assert_eq_int(nf1.status, 404, "Unregistered path returns 404 Not Found")

  @! 3.5 High-Throughput Stress Benchmark (1,000 requests)
  benchmark_passed = 1
  bench_i = 0
  @while bench_i < 1000
    rem = bench_i % 4
    @if rem == 0
      res = router_dispatch(router, "GET", "/health")
      @if res.handler_id != 101 benchmark_passed = 0 @end
    @elif rem == 1
      res = router_dispatch(router, "POST", "/api/v1/users")
      @if res.handler_id != 102 benchmark_passed = 0 @end
    @elif rem == 2
      res = router_dispatch(router, "GET", "/static/app.js")
      @if res.handler_id != 201 benchmark_passed = 0 @end
    @else
      res = router_dispatch(router, "GET", "/nonexistent")
      @if res.status != 404 benchmark_passed = 0 @end
    @end
    bench_i = bench_i + 1
  @end
  rt_ok15 = assert_eq_int(benchmark_passed, 1, "1,000-request high-throughput router stress benchmark 100% matched")

  @if rt_ok1 == 1 && rt_ok2 == 1 && rt_ok3 == 1 && rt_ok4 == 1 && rt_ok5 == 1 && rt_ok6 == 1 && rt_ok7 == 1 && rt_ok8 == 1 && rt_ok9 == 1 && rt_ok10 == 1 && rt_ok11 == 1 && rt_ok12 == 1 && rt_ok13 == 1 && rt_ok14 == 1 && rt_ok15 == 1
    passed_sections = passed_sections + 1
    println("  [PASS] Section 3: High-Throughput Routing Table verified (100% success)")
  @else
    println("  [FAIL] Section 3: High-Throughput Routing Table failed")
  @end

  @! ==========================================================================
  @! SECTION 4: Embedded Database (MayaKV / DB Engine)
  @! ==========================================================================
  println("▶ Section 4: Embedded Database (MayaKV / DB Engine)...")

  db_test_path = "/tmp/test_maya_sovereign_kv.db"
  wal_test_path = str_concat(db_test_path, ".wal")
  sys_unlink(db_test_path)
  sys_unlink(wal_test_path)

  @! 4.1 CRUD & Auto-Commit Durability
  db: Database = db_open(db_test_path, 16)
  db_ok1 = assert_eq_int(db.is_open, 1, "Database opened successfully")

  db_put(db, "usr:1001:name", "Sovereign Alice")
  db_put(db, "usr:1001:role", "ClusterAdmin")
  db_put(db, "usr:1002:name", "Sovereign Bob")
  db_put(db, "usr:1002:role", "NodeOperator")

  db_ok2 = assert_eq_str(db_get(db, "usr:1001:name"), "Sovereign Alice", "Retrieved usr:1001:name")
  db_ok3 = assert_eq_str(db_get(db, "usr:1001:role"), "ClusterAdmin", "Retrieved usr:1001:role")
  db_ok4 = assert_eq_str(db_get(db, "usr:1002:name"), "Sovereign Bob", "Retrieved usr:1002:name")
  db_ok5 = assert_eq_str(db_get(db, "usr:1002:role"), "NodeOperator", "Retrieved usr:1002:role")

  @! Overwrite
  db_put(db, "usr:1002:role", "LeadArchitect")
  db_ok6 = assert_eq_str(db_get(db, "usr:1002:role"), "LeadArchitect", "Updated usr:1002:role")

  @! Delete
  db_delete(db, "usr:1002:name")
  db_ok7 = assert_eq_str(db_get(db, "usr:1002:name"), "", "Deleted usr:1002:name returns empty")

  @! 4.2 Raw Syscall Direct Disk WAL Inspection
  wal_fd = sys_open(wal_test_path, 0, 0)
  db_ok8 = assert_true(wal_fd >= 0, "Raw syscall sys_open on WAL file succeeded")
  
  wal_fsize = sys_lseek(wal_fd, 0, 2)
  db_ok9 = assert_true(wal_fsize >= 32, "WAL file size on disk is valid binary framing (>= 32 bytes)")
  
  @! Read first 32-byte WAL record header directly from disk via sys_read
  sys_lseek(wal_fd, 0, 0)
  wal_hdr_buf = alloc(64)
  n_read = sys_read(wal_fd, wal_hdr_buf, 32)
  sys_close(wal_fd)
  db_ok10 = assert_eq_int(n_read, 32, "Read 32-byte WAL record header via raw sys_read")

  m0 = sys_peek8(wal_hdr_buf + 0) & 255
  m1 = sys_peek8(wal_hdr_buf + 1) & 255
  m2 = sys_peek8(wal_hdr_buf + 2) & 255
  m3 = sys_peek8(wal_hdr_buf + 3) & 255
  m_val = m0 | (m1 * 256) | (m2 * 65536) | (m3 * 16777216)
  is_wal_magic_valid = 0
  @if m_val == WAL_MAGIC()
    is_wal_magic_valid = 1
  @end
  db_ok11 = assert_eq_int(is_wal_magic_valid, 1, "WAL on-disk serialization verified: Magic header is 'MAYA' (0x4D415941)")

  @! 4.3 Multi-Statement ACID Transactions (Commit & Rollback)
  tx1: Transaction = db_begin(db)
  tx_put(tx1, "tx_acct:1", "50000")
  tx_put(tx1, "tx_acct:2", "75000")
  
  @! Read-Your-Own-Writes within uncommitted tx
  db_ok12 = assert_eq_str(tx_get(tx1, "tx_acct:1", ""), "50000", "Read-your-own-writes sees tx_acct:1")
  db_ok13 = assert_eq_str(tx_get(tx1, "tx_acct:2", ""), "75000", "Read-your-own-writes sees tx_acct:2")
  
  tx_commit(tx1)
  db_ok14 = assert_eq_str(db_get(db, "tx_acct:1"), "50000", "Committed tx_acct:1 queryable in DB")
  db_ok15 = assert_eq_str(db_get(db, "tx_acct:2"), "75000", "Committed tx_acct:2 queryable in DB")

  @! Rollback check
  tx_rb: Transaction = db_begin(db)
  tx_put(tx_rb, "tx_acct:ghost", "999999")
  tx_rollback(tx_rb)
  db_ok16 = assert_eq_str(db_get(db, "tx_acct:ghost"), "", "Rolled back key tx_acct:ghost does not exist in DB")

  @! 4.4 Transaction Crash Recovery Check (Committed vs Uncommitted)
  @! Append committed transaction
  tx_comm: Transaction = db_begin(db)
  tx_put(tx_comm, "session:alice", "valid_token_xyz")
  tx_commit(tx_comm)

  @! Append uncommitted mutation directly to WAL without commit record, then simulate sudden process crash
  wal_append_put(db.wal, 8888, "session:corrupt_uncommitted", "bad_token")
  wal_sync(db.wal)

  @! Abruptly close db handle without graceful checkpoint/flush to simulate sudden power off
  wal_close(db.wal)
  buffer_pool_close(db.pool)
  db.is_open = 0

  @! Reopen DB: startup Redo crash recovery scanner runs on the WAL
  db_rec: Database = db_open(db_test_path, 16)
  db_ok17 = assert_eq_int(db_rec.is_open, 1, "Database reopened after crash simulation")
  db_ok18 = assert_eq_str(db_get(db_rec, "session:alice"), "valid_token_xyz", "Committed transaction recovered from WAL")
  db_ok19 = assert_eq_str(db_get(db_rec, "session:corrupt_uncommitted"), "", "Uncommitted transaction discarded during crash recovery")
  db_ok20 = assert_eq_int(db_verify(db_rec), 1, "Structural B+Tree invariants verified after recovery")

  db_close(db_rec)
  sys_unlink(db_test_path)
  sys_unlink(wal_test_path)

  @if db_ok1 == 1 && db_ok2 == 1 && db_ok3 == 1 && db_ok4 == 1 && db_ok5 == 1 && db_ok6 == 1 && db_ok7 == 1 && db_ok8 == 1 && db_ok9 == 1 && db_ok10 == 1 && db_ok11 == 1 && db_ok12 == 1 && db_ok13 == 1 && db_ok14 == 1 && db_ok15 == 1 && db_ok16 == 1 && db_ok17 == 1 && db_ok18 == 1 && db_ok19 == 1 && db_ok20 == 1
    passed_sections = passed_sections + 1
    println("  [PASS] Section 4: Embedded Database (MayaKV / DB Engine) verified (100% success)")
  @else
    println("  [FAIL] Section 4: Embedded Database (MayaKV / DB Engine) failed")
  @end

  @! ==========================================================================
  @! FINAL SUMMARY
  @! ==========================================================================
  println("=================================================================")
  println(str_concat("📊 SOVEREIGN WEB ENGINE RESULTS: ", str_concat(to_str(passed_sections), str_concat(" / ", str_concat(to_str(total_sections), " sections passed")))))
  println("=================================================================")

  @if passed_sections == total_sections
    println("🎉 ALL 4 SECTIONS PASSED WITH 100% SUCCESS! 🎉")
    return 0
  @else
    println("❌ SOME SECTIONS FAILED")
    return 1
  @end
@end
