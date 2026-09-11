@! ============================================================================
@! MAYA UNIVERSE NET — PURE MAYA HTTP/1.1 CLIENT & SERVER (universe/net/http)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! RFC 7230 / RFC 7231 Compliant HTTP/1.1 Protocol Engine
@! ============================================================================

import "universe/net/tcp"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 0. HTTP Protocol Models
@! WHY: Explicit struct definitions provide deterministic O(1) field offsets across all compilation units
@! ----------------------------------------------------------------------------

@struct HttpResponse
  status_code: i64
  status_text: string
  version: string
  headers: array
  body: string
@end

@struct HttpRequest
  method: string
  path: string
  version: string
  headers: array
  body: string
@end

@! ----------------------------------------------------------------------------
@! 1. HTTP Status Codes & Reason Phrase Helpers
@! ----------------------------------------------------------------------------

@fn http_status_reason(status_code)
  @if status_code == 200 return "OK" @end
  @if status_code == 201 return "Created" @end
  @if status_code == 202 return "Accepted" @end
  @if status_code == 204 return "No Content" @end
  @if status_code == 301 return "Moved Permanently" @end
  @if status_code == 302 return "Found" @end
  @if status_code == 304 return "Not Modified" @end
  @if status_code == 400 return "Bad Request" @end
  @if status_code == 401 return "Unauthorized" @end
  @if status_code == 403 return "Forbidden" @end
  @if status_code == 404 return "Not Found" @end
  @if status_code == 405 return "Method Not Allowed" @end
  @if status_code == 408 return "Request Timeout" @end
  @if status_code == 418 return "I'm a teapot" @end
  @if status_code == 500 return "Internal Server Error" @end
  @if status_code == 501 return "Not Implemented" @end
  @if status_code == 502 return "Bad Gateway" @end
  @if status_code == 503 return "Service Unavailable" @end
  @if status_code >= 200 && status_code < 300 return "OK" @end
  @if status_code >= 400 && status_code < 500 return "Client Error" @end
  @if status_code >= 500 && status_code < 600 return "Server Error" @end
  return "OK"
@end

@fn hex_char_to_int(ch)
  @if ch >= 48 && ch <= 57 return ch - 48 @end
  @if ch >= 97 && ch <= 102 return ch - 97 + 10 @end
  @if ch >= 65 && ch <= 70 return ch - 65 + 10 @end
  return -1
@end

@fn parse_hex_int(hex_str)
  val = 0
  i = 0
  hlen = str_len(hex_str)
  @while i < hlen
    ch = str_char_at(hex_str, i)
    digit = hex_char_to_int(ch)
    @if digit >= 0
      val = (val * 16) + digit
    @else
      @! Stop on non-hex character (e.g. semicolon in chunk extensions)
      i = hlen
    @end
    i = i + 1
  @end
  return val
@end

@! ----------------------------------------------------------------------------
@! 2. HTTP/1.1 Request Formatter (RFC 7230 Wire Format)
@! ----------------------------------------------------------------------------

@fn http_format_request(method, path, headers, body)
  @if path == "" path = "/" @end
  req = str_concat(method, str_concat(" ", str_concat(path, " HTTP/1.1\r\n")))

  has_content_length = 0
  i = 0
  hlen = headers.len()
  @while i < hlen
    h = headers[i]
    @if h.name == "Content-Length" || h.name == "content-length"
      has_content_length = 1
    @end
    req = str_concat(req, str_concat(h.name, str_concat(": ", str_concat(h.value, "\r\n"))))
    i = i + 1
  @end

  blen = str_len(body)
  @if blen > 0 && has_content_length == 0
    req = str_concat(req, str_concat("Content-Length: ", str_concat(to_str(blen), "\r\n")))
  @end

  req = str_concat(req, "\r\n")
  @if blen > 0
    req = str_concat(req, body)
  @end

  return req
@end

@! ----------------------------------------------------------------------------
@! 3. HTTP/1.1 Response Formatter (Server Helper)
@! ----------------------------------------------------------------------------

@fn http_format_response(status_code, content_type_or_reason, body)
  reason = http_status_reason(status_code)
  content_type = "text/plain"

  @if str_contains(content_type_or_reason, "/") == 1
    content_type = content_type_or_reason
  @elif content_type_or_reason != ""
    reason = content_type_or_reason
  @end

  blen = str_len(body)
  resp = str_concat("HTTP/1.1 ", str_concat(to_str(status_code), str_concat(" ", str_concat(reason, "\r\n"))))
  resp = str_concat(resp, str_concat("Content-Type: ", str_concat(content_type, "\r\n")))
  resp = str_concat(resp, str_concat("Content-Length: ", str_concat(to_str(blen), "\r\n")))
  resp = str_concat(resp, "Connection: close\r\n\r\n")
  @if blen > 0
    resp = str_concat(resp, body)
  @end

  return resp
@end

@! ----------------------------------------------------------------------------
@! 4. HTTP Transfer-Encoding: Chunked Decoder
@! ----------------------------------------------------------------------------

@fn http_decode_chunked(raw_body)
  result = ""
  pos = 0
  blen = str_len(raw_body)

  @while pos < blen
    @! Find end of chunk header line (\r\n or \n)
    line_end = -1
    i = pos
    @while i < blen
      ch = str_char_at(raw_body, i)
      @if ch == 10 @! '\n'
        line_end = i
        i = blen
      @end
      i = i + 1
    @end

    @if line_end == -1
      pos = blen @! Incomplete chunk header, break
    @else
      line_str = str_substr(raw_body, pos, line_end)
      line_str = str_trim(line_str)
      pos = line_end + 1

      @if str_len(line_str) > 0
        chunk_size = parse_hex_int(line_str)
        @if chunk_size == 0
          pos = blen @! Final chunk encountered
        @else
          payload_end = pos + chunk_size
          @if payload_end > blen payload_end = blen @end

          chunk_payload = str_substr(raw_body, pos, payload_end)
          result = str_concat(result, chunk_payload)
          pos = payload_end

          @! Consume trailing \r and/or \n after chunk payload
          @if pos < blen && str_char_at(raw_body, pos) == 13 @! '\r'
            pos = pos + 1
          @end
          @if pos < blen && str_char_at(raw_body, pos) == 10 @! '\n'
            pos = pos + 1
          @end
        @end
      @end
    @end
  @end

  return result
@end

@! ----------------------------------------------------------------------------
@! 5. HTTP/1.1 Response Parser Engine
@! ----------------------------------------------------------------------------

@fn http_parse_response(raw_http_str: string)
  status_code = 0
  status_text = ""
  version = "HTTP/1.1"
  headers = []
  body = ""

  raw_len = str_len(raw_http_str)
  @if raw_len == 0
    return { status_code: 0, status_text: "Empty Response", version: version, headers: headers, body: "" }
  @end

  @! Find header/body delimiter (\r\n\r\n or \n\n)
  header_end = str_index_of(raw_http_str, "\r\n\r\n")
  sep_len = 4
  @if header_end == -1
    header_end = str_index_of(raw_http_str, "\n\n")
    sep_len = 2
  @end

  headers_str = ""
  body_str = ""
  @if header_end >= 0
    headers_str = str_substr(raw_http_str, 0, header_end)
    body_str = str_substr(raw_http_str, header_end + sep_len, raw_len)
  @else
    headers_str = raw_http_str
    body_str = ""
  @end

  @! Parse Status Line and Headers line-by-line
  is_first_line = 1
  is_chunked = 0
  pos = 0
  hlen = str_len(headers_str)

  @while pos < hlen
    next_nl = -1
    i = pos
    @while i < hlen
      @if str_char_at(headers_str, i) == 10 @! '\n'
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
      @if is_first_line == 1
        is_first_line = 0
        @! Parse status line: e.g. "HTTP/1.1 200 OK" or "HTTP/1.1 404 Not Found"
        space1 = str_index_of(line, " ")
        @if space1 >= 0
          version = str_substr(line, 0, space1)
          rest1 = str_substr(line, space1 + 1, str_len(line))
          space2 = str_index_of(rest1, " ")
          @if space2 >= 0
            code_str = str_substr(rest1, 0, space2)
            status_code = parse_int_str(code_str)
            status_text = str_substr(rest1, space2 + 1, str_len(rest1))
          @else
            status_code = parse_int_str(rest1)
            status_text = http_status_reason(status_code)
          @end
        @end
      @else
        @! Parse header line: "Name: Value"
        colon_pos = str_index_of(line, ":")
        @if colon_pos >= 0
          h_name = str_trim(str_substr(line, 0, colon_pos))
          h_val = str_trim(str_substr(line, colon_pos + 1, str_len(line)))
          headers = headers.push({ name: h_name, value: h_val })

          @if str_to_lower(h_name) == "transfer-encoding" && contains(str_to_lower(h_val), "chunked") == 1
            is_chunked = 1
          @end
        @end
      @end
    @end
  @end

  @if is_chunked == 1
    body = http_decode_chunked(body_str)
  @else
    body = body_str
  @end

  return {
    status_code: status_code,
    status_text: status_text,
    version: version,
    headers: headers,
    body: body
  }
@end

@fn parse_int_str(s)
  val = 0
  i = 0
  slen = str_len(s)
  @while i < slen
    ch = str_char_at(s, i)
    @if ch >= 48 && ch <= 57
      val = (val * 10) + (ch - 48)
    @end
    i = i + 1
  @end
  return val
@end

@! ----------------------------------------------------------------------------
@! 6. HTTP URL Parser
@! ----------------------------------------------------------------------------

@fn http_parse_url(url)
  proto = "http"
  host = "localhost"
  port = 80
  path = "/"

  rem = url
  @if starts_with(rem, "http://") == 1
    rem = str_substr(rem, 7, str_len(rem))
  @elif starts_with(rem, "https://") == 1
    rem = str_substr(rem, 8, str_len(rem))
    proto = "https"
    port = 443
  @end

  slash_pos = str_index_of(rem, "/")
  host_port = ""
  @if slash_pos >= 0
    host_port = str_substr(rem, 0, slash_pos)
    path = str_substr(rem, slash_pos, str_len(rem))
  @else
    host_port = rem
    path = "/"
  @end

  colon_pos = str_index_of(host_port, ":")
  @if colon_pos >= 0
    host = str_substr(host_port, 0, colon_pos)
    port_str = str_substr(host_port, colon_pos + 1, str_len(host_port))
    port = parse_int_str(port_str)
  @else
    host = host_port
  @end

  @if host == "" host = "localhost" @end

  return {
    protocol: proto,
    host: host,
    port: port,
    path: path
  }
@end

@! ----------------------------------------------------------------------------
@! 7. High-Level HTTP Client API (GET & POST)
@! ----------------------------------------------------------------------------

@fn http_get(url)
  u = http_parse_url(url)
  stream = tcp_stream_connect(u.host, u.port)
  @if stream.fd < 0
    return { status_code: 0, status_text: "Connection failed", version: "HTTP/1.1", headers: [], body: "" }
  @end

  host_hdr = u.host
  @if u.port != 80 && u.port != 443
    host_hdr = string_concat(host_hdr, string_concat(":", int_to_str(u.port)))
  @end

  req_headers = [
    { name: "Host", value: host_hdr },
    { name: "User-Agent", value: "Maya-Universe-Client/1.0" },
    { name: "Accept", value: "*/*" },
    { name: "Connection", value: "close" }
  ]

  req = http_format_request("GET", u.path, req_headers, "")
  tcp_stream_write(stream, req)

  raw_resp = ""
  @while 1 == 1
    chunk = tcp_stream_read(stream, 4096)
    @if chunk == "" || str_len(chunk) == 0
      break
    @end
    raw_resp = string_concat(raw_resp, chunk)
  @end

  tcp_stream_close(stream)
  return http_parse_response(raw_resp)
@end

@fn http_post(url, headers, body)
  u = http_parse_url(url)
  stream = tcp_stream_connect(u.host, u.port)
  @if stream.fd < 0
    return { status_code: 0, status_text: "Connection failed", version: "HTTP/1.1", headers: [], body: "" }
  @end

  has_host = 0
  has_conn = 0
  i = 0
  @while i < headers.len()
    h = headers[i]
    @if h.name == "Host" || h.name == "host" has_host = 1 @end
    @if h.name == "Connection" || h.name == "connection" has_conn = 1 @end
    i = i + 1
  @end

  req_hdrs = headers
  @if has_host == 0
    host_hdr = u.host
    @if u.port != 80 && u.port != 443
      host_hdr = string_concat(host_hdr, string_concat(":", int_to_str(u.port)))
    @end
    req_hdrs = req_hdrs.push({ name: "Host", value: host_hdr })
  @end
  @if has_conn == 0
    req_hdrs = req_hdrs.push({ name: "Connection", value: "close" })
  @end

  req = http_format_request("POST", u.path, req_hdrs, body)
  tcp_stream_write(stream, req)

  raw_resp = ""
  @while 1 == 1
    chunk = tcp_stream_read(stream, 4096)
    @if chunk == "" || str_len(chunk) == 0
      break
    @end
    raw_resp = string_concat(raw_resp, chunk)
  @end

  tcp_stream_close(stream)
  return http_parse_response(raw_resp)
@end

@! ----------------------------------------------------------------------------
@! 8. HTTP Server Engine & Request Dispatcher
@! ----------------------------------------------------------------------------

@fn http_parse_request(raw_req: string)
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
      @if str_char_at(headers_str, i) == 10 @! '\n'
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
        @! "GET /api/v1 HTTP/1.1"
        s1 = str_index_of(line, " ")
        @if s1 >= 0
          method = str_substr(line, 0, s1)
          rest = str_substr(line, s1 + 1, str_len(line))
          s2 = str_index_of(rest, " ")
          @if s2 >= 0
            path = str_substr(rest, 0, s2)
            version = str_substr(rest, s2 + 1, str_len(rest))
          @else
            path = rest
          @end
        @end
      @else
        colon_pos = str_index_of(line, ":")
        @if colon_pos >= 0
          h_name = str_trim(str_substr(line, 0, colon_pos))
          h_val = str_trim(str_substr(line, colon_pos + 1, str_len(line)))
          headers = headers.push({ name: h_name, value: h_val })
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

@fn http_server_listen(host, port, handler_fn)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    println("HTTP Server failed to bind on " + host + ":" + port.to_str())
    return -1
  @end

  println("🚀 Maya HTTP Server listening on http://" + host + ":" + port.to_str())

  @while 1 == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      raw_req = tcp_stream_read(stream, 4096)
      @if str_len(raw_req) > 0
        req = http_parse_request(raw_req)
        resp_obj = handler_fn(req)

        formatted_resp = ""
        @if resp_obj == "" || str_len(resp_obj) >= 0
          @! String response body returned by handler
          formatted_resp = http_format_response(200, "text/html", resp_obj)
        @else
          @! Struct response returned by handler
          s_code = resp_obj.status_code
          @if s_code == 0 s_code = 200 @end
          c_type = resp_obj.content_type
          @if c_type == "" c_type = "text/html" @end
          formatted_resp = http_format_response(s_code, c_type, resp_obj.body)
        @end

        tcp_stream_write(stream, formatted_resp)
      @end
      tcp_stream_close(stream)
    @end
  @end

  tcp_close(listener.fd)
  return 0
@end
