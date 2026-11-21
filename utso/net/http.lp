@! ============================================================================
@! LIPI UNIVERSE NET — PURE LIPI HTTP/1.1 CLIENT & SERVER (utso/net/http)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! RFC 7230 / RFC 7231 Compliant HTTP/1.1 Protocol Engine
@! ============================================================================

import "utso/net/tcp"
import "utso/core/string"
import "utso/net/tls/tls13"

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

@struct HttpTlsRecord
  tls_rec_ok: i64
  tls_rec_type: i64
  tls_rec_hdr: array
  tls_rec_body: array
@end

@struct HttpTlsPlain
  tls_pt_ok: i64
  tls_pt_type: i64
  tls_pt_data: array
@end

@struct HttpTlsServerHello
  tls_sh_ok: i64
  tls_sh_pub: array
  tls_sh_cipher: i64
  tls_sh_is_hrr: i64
  tls_sh_cookie: array
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

@! WHY: Strips CR (13), LF (10), and NUL (0) bytes from request targets and header lines to block CRLF response/request splitting.
@fn _http_strip_crlf(s)
  out = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch != 13 && ch != 10 && ch != 0
      out = str_concat(out, str_substr(s, i, i + 1))
    @end
    i = i + 1
  @end
  return out
@end

@fn _http_sanitize_header_name(s)
  out = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch != 13 && ch != 10 && ch != 0 && ch != 58 && ch != 32 && ch != 9
      out = str_concat(out, str_substr(s, i, i + 1))
    @end
    i = i + 1
  @end
  return out
@end

@fn http_format_request(method, path, headers, body)
  @if path == "" path = "/" @end
  safe_method = _http_strip_crlf(method)
  safe_path = _http_strip_crlf(path)
  @if safe_path == "" safe_path = "/" @end
  req = str_concat(safe_method, str_concat(" ", str_concat(safe_path, " HTTP/1.1\r\n")))

  has_content_length = 0
  i = 0
  hlen = headers.len()
  @while i < hlen
    h = headers[i]
    h_name = _http_sanitize_header_name(h.name)
    h_val = _http_strip_crlf(h.value)
    @if h_name == "Content-Length" || h_name == "content-length"
      has_content_length = 1
    @end
    @if h_name != ""
      req = str_concat(req, str_concat(h_name, str_concat(": ", str_concat(h_val, "\r\n"))))
    @end
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
  reason = _http_strip_crlf(http_status_reason(status_code))
  content_type = "text/plain"

  @if str_contains(content_type_or_reason, "/") == 1
    content_type = _http_strip_crlf(content_type_or_reason)
  @elif content_type_or_reason != ""
    reason = _http_strip_crlf(content_type_or_reason)
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
      semi_pos = str_index_of(line_str, ";")
      @if semi_pos >= 0
        line_str = str_substr(line_str, 0, semi_pos)
      @end
      line_str = str_trim(line_str)
      pos = line_end + 1

      @if str_len(line_str) > 0
        chunk_size = parse_hex_int(line_str)
        @if chunk_size <= 0 || pos + chunk_size > blen
          pos = blen @! Final chunk (0) or truncated/malformed chunk boundary
        @else
          payload_end = pos + chunk_size
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
  content_len = -1
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

          h_lower = str_to_lower(h_name)
          @if h_lower == "transfer-encoding" && contains(str_to_lower(h_val), "chunked") == 1
            is_chunked = 1
          @elif h_lower == "content-length" && content_len < 0
            content_len = parse_int_str(h_val)
          @end
        @end
      @end
    @end
  @end

  @if is_chunked == 1
    body = http_decode_chunked(body_str)
  @elif content_len >= 0 && content_len < str_len(body_str)
    body = str_substr(body_str, 0, content_len)
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
@! 6B. Pure Sovereign TLS 1.3 Client Engine for HTTPS (RFC 8446 + X25519 + AES-GCM)
@! ----------------------------------------------------------------------------

@fn _http_tls_rand32()
  buf = lipi_alloc(32)
  @if buf <= 0 return [] @end
  got = syscall(318, buf, 32, 0, 0, 0, 0)
  out = []
  @if got == 32
    i = 0
    @while i < 32
      out = out.push(sys_peek8(buf + i) & 255)
      i = i + 1
    @end
  @end
  lipi_free_sized(buf, 32)
  return out
@end

@fn _http_tls_slice(arr, start_idx, end_idx)
  out = []
  n = arr.len()
  @if end_idx > n end_idx = n @end
  i = start_idx
  @while i < end_idx
    out = out.push(arr[i] & 255)
    i = i + 1
  @end
  return out
@end

@fn _http_tls_write_exact(fd, byte_arr)
  n = byte_arr.len()
  @if fd < 0 || n <= 0 return 0 @end
  buf = lipi_alloc(n)
  @if buf <= 0 return -1 @end
  i = 0
  @while i < n
    sys_poke8(buf + i, byte_arr[i] & 255)
    i = i + 1
  @end
  sent = 0
  @while sent < n
    w = sys_write(fd, buf + sent, n - sent)
    @if w <= 0
      lipi_free_sized(buf, n)
      return -1
    @end
    sent = sent + w
  @end
  lipi_free_sized(buf, n)
  return sent
@end

@fn _http_tls_read_exact(fd, count)
  @if fd < 0 || count <= 0 return [] @end
  buf = lipi_alloc(count)
  @if buf <= 0 return [] @end
  got = 0
  @while got < count
    r = sys_read(fd, buf + got, count - got)
    @if r <= 0
      lipi_free_sized(buf, count)
      return []
    @end
    got = got + r
  @end
  out = []
  i = 0
  @while i < count
    out = out.push(sys_peek8(buf + i) & 255)
    i = i + 1
  @end
  lipi_free_sized(buf, count)
  return out
@end

@fn _http_tls_read_record(fd) -> HttpTlsRecord
  hdr = _http_tls_read_exact(fd, 5)
  @if hdr.len() != 5
    return { tls_rec_ok: 0, tls_rec_type: 0, tls_rec_hdr: [], tls_rec_body: [] }
  @end
  rec_len = ((hdr[3] & 255) * 256) | (hdr[4] & 255)
  @if rec_len <= 0 || rec_len > 16640
    return { tls_rec_ok: 0, tls_rec_type: hdr[0] & 255, tls_rec_hdr: hdr, tls_rec_body: [] }
  @end
  body = _http_tls_read_exact(fd, rec_len)
  @if body.len() != rec_len
    return { tls_rec_ok: 0, tls_rec_type: hdr[0] & 255, tls_rec_hdr: hdr, tls_rec_body: [] }
  @end
  return { tls_rec_ok: 1, tls_rec_type: hdr[0] & 255, tls_rec_hdr: hdr, tls_rec_body: body }
@end

@fn _http_tls_make_nonce(iv12, seq)
  hi = (seq / 4294967296) & 4294967295
  lo = seq & 4294967295
  return [
    iv12[0] & 255,
    iv12[1] & 255,
    iv12[2] & 255,
    iv12[3] & 255,
    (iv12[4] & 255) ^ ((hi / 16777216) & 255),
    (iv12[5] & 255) ^ ((hi / 65536) & 255),
    (iv12[6] & 255) ^ ((hi / 256) & 255),
    (iv12[7] & 255) ^ (hi & 255),
    (iv12[8] & 255) ^ ((lo / 16777216) & 255),
    (iv12[9] & 255) ^ ((lo / 65536) & 255),
    (iv12[10] & 255) ^ ((lo / 256) & 255),
    (iv12[11] & 255) ^ (lo & 255)
  ]
@end

@fn _http_tls_wrap_aead_record_suite(cipher, key, iv, seq, inner_type, plain_bytes)
  inner = []
  i = 0
  n = plain_bytes.len()
  @while i < n
    inner = inner.push(plain_bytes[i] & 255)
    i = i + 1
  @end
  inner = inner.push(inner_type & 255)
  ct_len = inner.len() + 16
  hdr = [23, 3, 3, (ct_len / 256) & 255, ct_len & 255]
  nonce = _http_tls_make_nonce(iv, seq)
  ct_and_tag = []
  @if cipher == 4867
    ct_and_tag = tls_chacha20_poly1305_encrypt_raw(key, nonce, inner, hdr)
  @else
    ct_and_tag = tls_aes_gcm_encrypt_raw(key, nonce, inner, hdr)
  @end
  return tls_append_bytes(hdr, ct_and_tag)
@end

@fn _http_tls_wrap_aead_record(key, iv, seq, inner_type, plain_bytes)
  return _http_tls_wrap_aead_record_suite(4865, key, iv, seq, inner_type, plain_bytes)
@end

@fn _http_tls_unwrap_aead_record_suite(cipher, key, iv, seq, rec_hdr, rec_body) -> HttpTlsPlain
  @if rec_hdr.len() != 5 || rec_body.len() < 17
    return { tls_pt_ok: 0, tls_pt_type: 0, tls_pt_data: [] }
  @end
  nonce = _http_tls_make_nonce(iv, seq)
  inner = []
  @if cipher == 4867
    inner = tls_chacha20_poly1305_decrypt_raw(key, nonce, rec_body, rec_hdr)
  @else
    inner = tls_aes_gcm_decrypt_raw(key, nonce, rec_body, rec_hdr)
  @end
  end_idx = inner.len()
  @if end_idx == 0
    return { tls_pt_ok: 0, tls_pt_type: 0, tls_pt_data: [] }
  @end
  @while end_idx > 0 && (inner[end_idx - 1] & 255) == 0
    end_idx = end_idx - 1
  @end
  @if end_idx == 0
    return { tls_pt_ok: 0, tls_pt_type: 0, tls_pt_data: [] }
  @end
  inner_type = inner[end_idx - 1] & 255
  payload = _http_tls_slice(inner, 0, end_idx - 1)
  return { tls_pt_ok: 1, tls_pt_type: inner_type, tls_pt_data: payload }
@end

@fn _http_tls_unwrap_aead_record(key, iv, seq, rec_hdr, rec_body) -> HttpTlsPlain
  return _http_tls_unwrap_aead_record_suite(4865, key, iv, seq, rec_hdr, rec_body)
@end

@fn _http_tls_is_hrr_random(sh_hs)
  @if sh_hs.len() < 38 return 0 @end
  magic = [
    207, 33, 173, 116, 229, 154, 97, 17,
    190, 29, 140, 2, 30, 101, 184, 145,
    194, 162, 17, 22, 122, 187, 140, 94,
    7, 158, 9, 226, 200, 168, 51, 156
  ]
  i = 0
  @while i < 32
    @if (sh_hs[6 + i] & 255) != magic[i]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn _http_tls_parse_server_hello(sh_hs) -> HttpTlsServerHello
  n = sh_hs.len()
  @if n < 44
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  @if (sh_hs[0] & 255) != 2
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  is_hrr = _http_tls_is_hrr_random(sh_hs)
  sid_len = sh_hs[38] & 255
  cipher_off = 39 + sid_len
  pos = cipher_off + 3
  @if pos + 2 > n
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  cipher = ((sh_hs[cipher_off] & 255) * 256) | (sh_hs[cipher_off + 1] & 255)
  @if cipher != 4865 && cipher != 4866 && cipher != 4867
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  ext_tot = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
  pos = pos + 2
  ext_end = pos + ext_tot
  @if ext_end > n ext_end = n @end

  has_tls13 = 0
  server_pub = []
  cookie = []
  hrr_grp_ok = 1
  @while pos + 4 <= ext_end
    et = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
    el = ((sh_hs[pos + 2] & 255) * 256) | (sh_hs[pos + 3] & 255)
    pos = pos + 4
    @if pos + el > ext_end break @end
    @if et == 43 && el == 2
      @if (sh_hs[pos] & 255) == 3 && (sh_hs[pos + 1] & 255) == 4
        has_tls13 = 1
      @end
    @elif et == 44 && el >= 2
      ck_len = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
      @if 2 + ck_len <= el
        cookie = _http_tls_slice(sh_hs, pos + 2, pos + 2 + ck_len)
      @end
    @elif et == 51 && el == 2 && is_hrr == 1
      grp = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
      @if grp != 29 hrr_grp_ok = 0 @end
    @elif et == 51 && el >= 4
      grp = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
      kl = ((sh_hs[pos + 2] & 255) * 256) | (sh_hs[pos + 3] & 255)
      @if grp == 29 && kl == 32 && el >= 4 + 32
        server_pub = _http_tls_slice(sh_hs, pos + 4, pos + 36)
      @end
    @end
    pos = pos + el
  @end

  @if has_tls13 != 1
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  @if is_hrr == 1
    @if hrr_grp_ok != 1
      return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
    @end
    return { tls_sh_ok: 1, tls_sh_pub: server_pub, tls_sh_cipher: cipher, tls_sh_is_hrr: 1, tls_sh_cookie: cookie }
  @end
  @if server_pub.len() != 32
    return { tls_sh_ok: 0, tls_sh_pub: [], tls_sh_cipher: 0, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
  @end
  return { tls_sh_ok: 1, tls_sh_pub: server_pub, tls_sh_cipher: cipher, tls_sh_is_hrr: 0, tls_sh_cookie: [] }
@end

@fn _http_tls_build_ch_with_cookie(host, client_pub, cookie_bytes)
  ch = tls13_build_client_hello(host, client_pub)
  @if ch.wire_bytes.len() < 46 return [] @end
  @if cookie_bytes.len() == 0 return ch.wire_bytes @end
  hs = _http_tls_slice(ch.wire_bytes, 5, ch.wire_bytes.len())
  n = hs.len()
  @if n < 42 return [] @end
  sid_len = hs[38] & 255
  p = 39 + sid_len
  @if p + 2 > n return [] @end
  cs_len = ((hs[p] & 255) * 256) | (hs[p + 1] & 255)
  p = p + 2 + cs_len
  @if p + 1 > n return [] @end
  cm_len = hs[p] & 255
  p = p + 1 + cm_len
  @if p + 2 > n return [] @end
  ext_tot = ((hs[p] & 255) * 256) | (hs[p + 1] & 255)
  ck_ext_len = 4 + 2 + cookie_bytes.len()
  new_ext_tot = ext_tot + ck_ext_len
  hs[p] = (new_ext_tot / 256) & 255
  hs[p + 1] = new_ext_tot & 255

  hs = hs.push(0)
  hs = hs.push(44)
  ck_pay_len = 2 + cookie_bytes.len()
  hs = hs.push((ck_pay_len / 256) & 255)
  hs = hs.push(ck_pay_len & 255)
  hs = hs.push((cookie_bytes.len() / 256) & 255)
  hs = hs.push(cookie_bytes.len() & 255)
  hs = tls_append_bytes(hs, cookie_bytes)

  body_len = hs.len() - 4
  hs[1] = (body_len / 65536) & 255
  hs[2] = (body_len / 256) & 255
  hs[3] = body_len & 255
  rec_len = hs.len()
  wire = [22, 3, 1, (rec_len / 256) & 255, rec_len & 255]
  return tls_append_bytes(wire, hs)
@end

@fn _http_tls_read_server_hello(fd)
  sh_buf = []
  tries = 0
  @while tries < 8
    rec = _http_tls_read_record(fd)
    @if rec.tls_rec_ok != 1 return [] @end
    @if rec.tls_rec_type == 20
      tries = tries + 1
      continue
    @end
    @if rec.tls_rec_type != 22
      return []
    @end
    sh_buf = tls_append_bytes(sh_buf, rec.tls_rec_body)
    @if sh_buf.len() >= 4
      msg_len = 4 + (((sh_buf[1] & 255) * 65536) | ((sh_buf[2] & 255) * 256) | (sh_buf[3] & 255))
      @if msg_len > 16384 return [] @end
      @if sh_buf.len() >= msg_len
        return _http_tls_slice(sh_buf, 0, msg_len)
      @end
    @end
    tries = tries + 1
  @end
  return []
@end

@fn _http_tls_ct_bytes_equal(a, b)
  @if a.len() != b.len() return 0 @end
  diff = 0
  i = 0
  @while i < a.len()
    diff = diff | ((a[i] & 255) ^ (b[i] & 255))
    i = i + 1
  @end
  @if diff == 0 return 1 @end
  return 0
@end

@fn _http_tls_extract_cert_der(cert_hs)
  n = cert_hs.len()
  @if n < 12 return [] @end
  ctx_len = cert_hs[4] & 255
  list_off = 5 + ctx_len
  @if list_off + 6 >= n return [] @end
  ent_off = list_off + 3
  cert_len = ((cert_hs[ent_off] & 255) * 65536) | ((cert_hs[ent_off + 1] & 255) * 256) | (cert_hs[ent_off + 2] & 255)
  @if cert_len <= 0 || ent_off + 3 + cert_len > n
    return []
  @end
  return _http_tls_slice(cert_hs, ent_off + 3, ent_off + 3 + cert_len)
@end

@fn _http_tls_hash_transcript(cipher, transcript)
  @if cipher == 4866
    return sha384_hash_bytes(transcript)
  @end
  return sha256_hash_bytes(transcript)
@end

@fn _http_tls_derive_hs_keys_for_cipher(cipher, shared, thash1)
  @if cipher == 4866
    return tls13_derive_handshake_keys_384(shared, thash1)
  @end
  keys = tls13_derive_handshake_keys(shared, thash1)
  @if cipher == 4867
    keys.client_write_key = tls13_hkdf_expand_label(keys.client_handshake_traffic_secret, "key", [], 32)
    keys.server_write_key = tls13_hkdf_expand_label(keys.server_handshake_traffic_secret, "key", [], 32)
  @end
  return keys
@end

@fn _http_tls_derive_app_keys_for_cipher(cipher, hs_keys, fin_hash)
  @if cipher == 4866
    zero48 = []
    zi = 0
    @while zi < 48
      zero48 = zero48.push(0)
      zi = zi + 1
    @end
    empty_h = sha384_hash_bytes([])
    derived_hs = tls13_hkdf_expand_label_384(hs_keys.handshake_secret, "derived", empty_h, 48)
    master = tls13_hkdf_extract_384(derived_hs, zero48)
    c_app = tls13_hkdf_expand_label_384(master, "c ap traffic", fin_hash, 48)
    s_app = tls13_hkdf_expand_label_384(master, "s ap traffic", fin_hash, 48)
    return {
      c_key: tls13_hkdf_expand_label_384(c_app, "key", [], 32),
      c_iv: tls13_hkdf_expand_label_384(c_app, "iv", [], 12),
      s_key: tls13_hkdf_expand_label_384(s_app, "key", [], 32),
      s_iv: tls13_hkdf_expand_label_384(s_app, "iv", [], 12)
    }
  @end
  zero32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  empty_h = sha256_hash_bytes([])
  derived_hs = tls13_hkdf_expand_label(hs_keys.handshake_secret, "derived", empty_h, 32)
  master = tls13_hkdf_extract(derived_hs, zero32)
  c_app = tls13_hkdf_expand_label(master, "c ap traffic", fin_hash, 32)
  s_app = tls13_hkdf_expand_label(master, "s ap traffic", fin_hash, 32)
  klen = 16
  @if cipher == 4867
    klen = 32
  @end
  return {
    c_key: tls13_hkdf_expand_label(c_app, "key", [], klen),
    c_iv: tls13_hkdf_expand_label(c_app, "iv", [], 12),
    s_key: tls13_hkdf_expand_label(s_app, "key", [], klen),
    s_iv: tls13_hkdf_expand_label(s_app, "iv", [], 12)
  }
@end

@fn _http_is_wire_response_complete(raw_resp)
  rlen = str_len(raw_resp)
  @if rlen == 0 return 0 @end
  hend = str_index_of(raw_resp, "\r\n\r\n")
  sep = 4
  @if hend < 0
    hend = str_index_of(raw_resp, "\n\n")
    sep = 2
  @end
  @if hend < 0 return 0 @end

  parsed = http_parse_response(str_substr(raw_resp, 0, hend + sep))
  hi = 0
  is_chunked = 0
  clen = -1
  @while hi < parsed.headers.len()
    h = parsed.headers[hi]
    hl = str_to_lower(h.name)
    @if hl == "transfer-encoding" && contains(str_to_lower(h.value), "chunked") == 1
      is_chunked = 1
    @elif hl == "content-length" && clen < 0
      clen = parse_int_str(h.value)
    @end
    hi = hi + 1
  @end
  body_have = rlen - (hend + sep)
  @if is_chunked == 1
    body_part = str_substr(raw_resp, hend + sep, rlen)
    @if contains(body_part, "\r\n0\r\n\r\n") == 1 || starts_with(body_part, "0\r\n\r\n") == 1
      return 1
    @end
    return 0
  @end
  @if clen >= 0 && body_have >= clen
    return 1
  @end
  return 0
@end

@fn _http_tls_exchange(stream, host, req_str)
  c_priv = _http_tls_rand32()
  @if c_priv.len() != 32 return "" @end
  c_pub = x25519_public_key(c_priv)
  ch = tls13_build_client_hello(host, c_pub)
  @if ch.wire_bytes.len() < 46 return "" @end
  ch_hs = _http_tls_slice(ch.wire_bytes, 5, ch.wire_bytes.len())

  @if _http_tls_write_exact(stream.fd, ch.wire_bytes) <= 0
    return ""
  @end

  sh_hs = _http_tls_read_server_hello(stream.fd)
  @if sh_hs.len() == 0 return "" @end

  sh_info = _http_tls_parse_server_hello(sh_hs)
  @if sh_info.tls_sh_ok != 1 return "" @end
  cipher = sh_info.tls_sh_cipher

  hs_transcript = []
  @if sh_info.tls_sh_is_hrr == 1
    h1 = _http_tls_hash_transcript(cipher, ch_hs)
    msg_hash = [254, 0, 0, h1.len() & 255]
    msg_hash = tls_append_bytes(msg_hash, h1)
    c_priv = _http_tls_rand32()
    @if c_priv.len() != 32 return "" @end
    c_pub = x25519_public_key(c_priv)
    ch2_wire = _http_tls_build_ch_with_cookie(host, c_pub, sh_info.tls_sh_cookie)
    @if ch2_wire.len() < 46 return "" @end
    ch2_hs = _http_tls_slice(ch2_wire, 5, ch2_wire.len())
    @if _http_tls_write_exact(stream.fd, ch2_wire) <= 0 return "" @end
    sh2_hs = _http_tls_read_server_hello(stream.fd)
    @if sh2_hs.len() == 0 return "" @end
    sh_info = _http_tls_parse_server_hello(sh2_hs)
    @if sh_info.tls_sh_ok != 1 || sh_info.tls_sh_is_hrr == 1 || sh_info.tls_sh_cipher != cipher
      return ""
    @end
    hs_transcript = tls_append_bytes(hs_transcript, msg_hash)
    hs_transcript = tls_append_bytes(hs_transcript, sh_hs)
    hs_transcript = tls_append_bytes(hs_transcript, ch2_hs)
    hs_transcript = tls_append_bytes(hs_transcript, sh2_hs)
  @else
    hs_transcript = tls_append_bytes(hs_transcript, ch_hs)
    hs_transcript = tls_append_bytes(hs_transcript, sh_hs)
  @end

  shared = x25519_shared_secret(c_priv, sh_info.tls_sh_pub)
  @if shared.len() != 32 return "" @end
  thash1 = _http_tls_hash_transcript(cipher, hs_transcript)
  hs_keys = _http_tls_derive_hs_keys_for_cipher(cipher, shared, thash1)

  @! Consume server encrypted handshake flight through Certificate, CertificateVerify, Finished
  hs_buf = []
  s_hs_seq = 0
  got_server_finished = 0
  got_cert = 0
  got_cert_verify = 0
  cert_der = []
  flight_steps = 0
  @while got_server_finished == 0 && flight_steps < 64
    flight_steps = flight_steps + 1
    rec = _http_tls_read_record(stream.fd)
    @if rec.tls_rec_ok != 1 return "" @end
    @if rec.tls_rec_type == 20
      continue
    @end
    @if rec.tls_rec_type != 23
      return ""
    @end
    unwrapped = _http_tls_unwrap_aead_record_suite(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, rec.tls_rec_hdr, rec.tls_rec_body)
    @if unwrapped.tls_pt_ok != 1 return "" @end
    s_hs_seq = s_hs_seq + 1
    @if unwrapped.tls_pt_type == 21
      return ""
    @end
    @if unwrapped.tls_pt_type != 22
      return ""
    @end
    hs_buf = tls_append_bytes(hs_buf, unwrapped.tls_pt_data)

    pos = 0
    @while pos + 4 <= hs_buf.len()
      ht = hs_buf[pos] & 255
      hl = ((hs_buf[pos + 1] & 255) * 65536) | ((hs_buf[pos + 2] & 255) * 256) | (hs_buf[pos + 3] & 255)
      @if pos + 4 + hl > hs_buf.len()
        break
      @end
      msg = _http_tls_slice(hs_buf, pos, pos + 4 + hl)
      pos = pos + 4 + hl
      @if ht == 11
        cert_der = _http_tls_extract_cert_der(msg)
        @if cert_der.len() == 0 || tls13_verify_x509_cert_chain(cert_der, host) != 1
          return ""
        @end
        got_cert = 1
      @elif ht == 15
        @if got_cert != 1 || msg.len() < 8
          return ""
        @end
        sig_alg = ((msg[4] & 255) * 256) | (msg[5] & 255)
        sig_len = ((msg[6] & 255) * 256) | (msg[7] & 255)
        @if 8 + sig_len != msg.len()
          return ""
        @end
        sig_bytes = _http_tls_slice(msg, 8, 8 + sig_len)
        cv_hash = _http_tls_hash_transcript(cipher, hs_transcript)
        @if tls13_verify_certificate_verify(cert_der, cv_hash, sig_alg, sig_bytes) != 1
          return ""
        @end
        got_cert_verify = 1
      @elif ht == 20
        @if got_cert != 1 || got_cert_verify != 1
          return ""
        @end
        expected_hl = 32
        @if cipher == 4866 expected_hl = 48 @end
        @if hl != expected_hl return "" @end
        s_fin_key = []
        expected_fin = []
        @if cipher == 4866
          s_fin_key = tls13_hkdf_expand_label_384(hs_keys.server_handshake_traffic_secret, "finished", [], 48)
          expected_fin = tls13_hmac_sha384(s_fin_key, sha384_hash_bytes(hs_transcript))
        @else
          s_fin_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "finished", [], 32)
          expected_fin = tls13_hmac_sha256(s_fin_key, sha256_hash_bytes(hs_transcript))
        @end
        actual_fin = _http_tls_slice(msg, 4, 4 + expected_hl)
        @if _http_tls_ct_bytes_equal(actual_fin, expected_fin) != 1
          return ""
        @end
        hs_transcript = tls_append_bytes(hs_transcript, msg)
        got_server_finished = 1
        break
      @end
      hs_transcript = tls_append_bytes(hs_transcript, msg)
    @end
    hs_buf = _http_tls_slice(hs_buf, pos, hs_buf.len())
  @end

  @if got_server_finished != 1 || got_cert != 1 || got_cert_verify != 1
    return ""
  @end

  @! Derive RFC 8446 Application Traffic Secrets & Keys
  fin_hash = _http_tls_hash_transcript(cipher, hs_transcript)
  app_keys = _http_tls_derive_app_keys_for_cipher(cipher, hs_keys, fin_hash)

  @! Send encrypted Client Finished + HTTP request
  c_verify = []
  c_fin_hdr = [20, 0, 0, 32]
  @if cipher == 4866
    c_fin_key = tls13_hkdf_expand_label_384(hs_keys.client_handshake_traffic_secret, "finished", [], 48)
    c_verify = tls13_hmac_sha384(c_fin_key, fin_hash)
    c_fin_hdr = [20, 0, 0, 48]
  @else
    c_fin_key = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "finished", [], 32)
    c_verify = tls13_hmac_sha256(c_fin_key, fin_hash)
  @end
  c_fin_msg = tls_append_bytes(c_fin_hdr, c_verify)
  c_fin_rec = _http_tls_wrap_aead_record_suite(cipher, hs_keys.client_write_key, hs_keys.client_write_iv, 0, 22, c_fin_msg)
  @if _http_tls_write_exact(stream.fd, c_fin_rec) <= 0 return "" @end

  req_bytes = tls_string_to_bytes(req_str)
  req_rec = _http_tls_wrap_aead_record_suite(cipher, app_keys.c_key, app_keys.c_iv, 0, 23, req_bytes)
  @if _http_tls_write_exact(stream.fd, req_rec) <= 0 return "" @end

  @! Receive encrypted HTTPS response records
  raw_resp = ""
  s_app_seq = 0
  @while 1 == 1
    rec = _http_tls_read_record(stream.fd)
    @if rec.tls_rec_ok != 1
      break
    @end
    @if rec.tls_rec_type == 21
      break
    @end
    @if rec.tls_rec_type != 23
      return ""
    @end
    dec = _http_tls_unwrap_aead_record_suite(cipher, app_keys.s_key, app_keys.s_iv, s_app_seq, rec.tls_rec_hdr, rec.tls_rec_body)
    @if dec.tls_pt_ok != 1
      return ""
    @end
    s_app_seq = s_app_seq + 1
    @if dec.tls_pt_type == 21
      break
    @elif dec.tls_pt_type == 23
      raw_resp = string_concat(raw_resp, tls_bytes_to_string(dec.tls_pt_data))
      @if _http_is_wire_response_complete(raw_resp) == 1
        break
      @end
    @end
  @end

  return raw_resp
@end

@! ----------------------------------------------------------------------------
@! 7. High-Level HTTP Client API (GET & POST over HTTP & HTTPS TLS 1.3)
@! ----------------------------------------------------------------------------

@fn _http_build_client_headers(u, extra_headers)
  has_host = 0
  has_conn = 0
  req_hdrs = []
  i = 0
  @while i < extra_headers.len()
    h = extra_headers[i]
    @if h.name == "Host" || h.name == "host" has_host = 1 @end
    @if h.name == "Connection" || h.name == "connection" has_conn = 1 @end
    req_hdrs = req_hdrs.push(h)
    i = i + 1
  @end
  @if has_host == 0
    host_hdr = u.host
    @if u.port != 80 && u.port != 443
      host_hdr = string_concat(host_hdr, string_concat(":", int_to_str(u.port)))
    @end
    req_hdrs = req_hdrs.push({ name: "Host", value: host_hdr })
  @end
  req_hdrs = req_hdrs.push({ name: "User-Agent", value: "LiPi-Universe-Client/1.0" })
  req_hdrs = req_hdrs.push({ name: "Accept", value: "*/*" })
  @if has_conn == 0
    req_hdrs = req_hdrs.push({ name: "Connection", value: "close" })
  @end
  return req_hdrs
@end

@fn _http_resolve_redirect(base_u, loc)
  @if starts_with(loc, "http://") == 1 || starts_with(loc, "https://") == 1
    return loc
  @end
  port_part = ""
  @if base_u.port != 80 && base_u.port != 443
    port_part = string_concat(":", int_to_str(base_u.port))
  @end
  @if starts_with(loc, "//") == 1
    return string_concat(base_u.protocol, string_concat(":", loc))
  @end
  prefix = string_concat(base_u.protocol, string_concat("://", string_concat(base_u.host, port_part)))
  @if starts_with(loc, "/") == 1
    return string_concat(prefix, loc)
  @end
  return string_concat(prefix, string_concat("/", loc))
@end

@fn _http_find_header_value(headers, name_lower)
  i = 0
  @while i < headers.len()
    h = headers[i]
    @if str_to_lower(h.name) == name_lower
      return h.value
    @end
    i = i + 1
  @end
  return ""
@end

@fn _http_execute_single(method, url, extra_headers, body)
  u = http_parse_url(url)
  stream = tcp_stream_connect(u.host, u.port)
  @if stream.fd < 0
    return { status_code: 0, status_text: "Connection failed", version: "HTTP/1.1", headers: [], body: "" }
  @end

  req_hdrs = _http_build_client_headers(u, extra_headers)
  req = http_format_request(method, u.path, req_hdrs, body)
  raw_resp = ""
  @if u.protocol == "https"
    raw_resp = _http_tls_exchange(stream, u.host, req)
    tcp_stream_close(stream)
    @if raw_resp == ""
      return { status_code: 0, status_text: "TLS handshake failed", version: "HTTP/1.1", headers: [], body: "" }
    @end
    return http_parse_response(raw_resp)
  @end

  tcp_stream_write(stream, req)
  @while 1 == 1
    chunk = tcp_stream_read(stream, 4096)
    @if chunk == "" || str_len(chunk) == 0
      break
    @end
    raw_resp = string_concat(raw_resp, chunk)
    @if _http_is_wire_response_complete(raw_resp) == 1
      break
    @end
  @end

  tcp_stream_close(stream)
  return http_parse_response(raw_resp)
@end

@fn _http_execute(method, url, extra_headers, body)
  cur_method = method
  cur_url = url
  cur_body = body
  hop = 0
  resp = { status_code: 0, status_text: "Connection failed", version: "HTTP/1.1", headers: [], body: "" }
  @while hop < 6
    resp = _http_execute_single(cur_method, cur_url, extra_headers, cur_body)
    sc = resp.status_code
    @if sc == 301 || sc == 302 || sc == 303 || sc == 307 || sc == 308
      loc = _http_find_header_value(resp.headers, "location")
      @if loc == "" break @end
      cur_url = _http_resolve_redirect(http_parse_url(cur_url), loc)
      @if sc == 301 || sc == 302 || sc == 303
        cur_method = "GET"
        cur_body = ""
      @end
      hop = hop + 1
    @else
      break
    @end
  @end
  return resp
@end

@fn http_get(url)
  return _http_execute("GET", url, [], "")
@end

@fn http_post(url, headers, body)
  return _http_execute("POST", url, headers, body)
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

@fn _http_read_full_request(stream)
  raw_req = ""
  header_end = -1
  sep_len = 4
  req_clen = -1
  reads = 0
  @while reads < 256
    chunk = tcp_stream_read(stream, 4096)
    @if chunk == "" || str_len(chunk) == 0
      break
    @end
    raw_req = string_concat(raw_req, chunk)
    reads = reads + 1
    @if header_end < 0
      header_end = str_index_of(raw_req, "\r\n\r\n")
      sep_len = 4
      @if header_end < 0
        header_end = str_index_of(raw_req, "\n\n")
        sep_len = 2
      @end
      @if header_end >= 0
        req_head = http_parse_request(str_substr(raw_req, 0, header_end + sep_len))
        cl_val = _http_find_header_value(req_head.headers, "content-length")
        @if cl_val != ""
          req_clen = parse_int_str(cl_val)
        @else
          req_clen = 0
        @end
      @end
    @end
    @if header_end >= 0 && req_clen >= 0
      have_body = str_len(raw_req) - (header_end + sep_len)
      @if have_body >= req_clen
        break
      @end
    @end
  @end
  return raw_req
@end

@fn http_server_listen(host, port, handler_fn)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    println("HTTP Server failed to bind on " + host + ":" + port.to_str())
    return -1
  @end

  // WHY: Sovereign startup banner for native LiPi HTTP server
  println("🚀 LiPi HTTP Server listening on http://" + host + ":" + port.to_str())

  @while 1 == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      raw_req = _http_read_full_request(stream)
      @if str_len(raw_req) > 0
        req = http_parse_request(raw_req)
        resp_obj = handler_fn(req)

        formatted_resp = ""
        @if is_str(resp_obj) == 1
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
