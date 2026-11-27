@! ============================================================================
@! LIPI UNIVERSE NET — PURE LIPI HTTP/1.1 CLIENT & SERVER (utso/net/http)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! RFC 7230 / RFC 7231 Compliant HTTP/1.1 Protocol Engine
@! ============================================================================

import "utso/net/tcp"
import "utso/core/string"
import "utso/core/deflate"
import "utso/net/tls/tls13"

@! ----------------------------------------------------------------------------
@! 0. HTTP Protocol Models
@! WHY: Explicit struct definitions provide deterministic O(1) field offsets across all compilation units
@! ----------------------------------------------------------------------------

@struct HttpHeader
  name: string
  value: string
@end

@struct HttpUrl
  protocol: string
  host: string
  port: i64
  path: string
@end

@struct HttpTlsAppKeys
  c_key: array
  c_iv: array
  s_key: array
  s_iv: array
  master_secret: array
@end

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

@fn _http_hdr_name(h: HttpHeader) return h.name @end
@fn _http_hdr_value(h: HttpHeader) return h.value @end

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
  tls_sh_has_psk: i64
  tls_sh_psk_id: i64
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
@fn _http_raw_ptr(x) return x @end

@fn _http_strip_crlf(s)
  ss = str(s)
  n = str_len(ss)
  @if n == 0 return "" @end
  b = buf_new(n)
  i = 0
  @while i < n
    ch = mem_byte_read(ss, i) & 255
    @if ch != 13 && ch != 10 && ch != 0
      buf_write_byte(b, ch)
    @end
    i = i + 1
  @end
  out = buf_to_str(b)
  buf_free(b)
  return out
@end

@fn _http_sanitize_header_name(s)
  ss = str(s)
  n = str_len(ss)
  @if n == 0 return "" @end
  b = buf_new(n)
  i = 0
  @while i < n
    ch = mem_byte_read(ss, i) & 255
    @if ch != 13 && ch != 10 && ch != 0 && ch != 58 && ch != 32 && ch != 9
      buf_write_byte(b, ch)
    @end
    i = i + 1
  @end
  out = buf_to_str(b)
  buf_free(b)
  return out
@end

@fn http_format_request(method, path, headers, body)
  // WHY: O(N) ByteBuffer wire assembly (eliminates O(N^2) str_concat heap churn on large headers/bodies!)
  @if path == "" path = "/" @end
  safe_method = _http_strip_crlf(method)
  safe_path = _http_strip_crlf(path)
  @if safe_path == "" safe_path = "/" @end
  blen = str_len(body)
  bb = buf_new(256 + blen)
  buf_write_str(bb, safe_method)
  buf_write_str(bb, " ")
  buf_write_str(bb, safe_path)
  buf_write_str(bb, " HTTP/1.1\r\n")

  has_content_length = 0
  i = 0
  hlen = headers.len()
  @while i < hlen
    h = headers[i]
    h_name = _http_sanitize_header_name(_http_hdr_name(h))
    h_val = _http_strip_crlf(_http_hdr_value(h))
    @if h_name == "Content-Length" || h_name == "content-length"
      has_content_length = 1
    @end
    @if h_name != ""
      buf_write_str(bb, h_name)
      buf_write_str(bb, ": ")
      buf_write_str(bb, h_val)
      buf_write_str(bb, "\r\n")
    @end
    i = i + 1
  @end

  @if blen > 0 && has_content_length == 0
    buf_write_str(bb, "Content-Length: ")
    buf_write_str(bb, to_str(blen))
    buf_write_str(bb, "\r\n")
  @end

  buf_write_str(bb, "\r\n")
  @if blen > 0
    buf_write_str(bb, body)
  @end

  req = buf_to_str(bb)
  buf_free(bb)
  return req
@end

@! ----------------------------------------------------------------------------
@! 3. HTTP/1.1 Response Formatter (Server Helper — O(N) ByteBuffer)
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
  bb = buf_new(256 + blen)
  buf_write_str(bb, "HTTP/1.1 ")
  buf_write_str(bb, to_str(status_code))
  buf_write_str(bb, " ")
  buf_write_str(bb, reason)
  buf_write_str(bb, "\r\nContent-Type: ")
  buf_write_str(bb, content_type)
  buf_write_str(bb, "\r\nContent-Length: ")
  buf_write_str(bb, to_str(blen))
  buf_write_str(bb, "\r\nConnection: close\r\n\r\n")
  @if blen > 0
    buf_write_str(bb, body)
  @end

  resp = buf_to_str(bb)
  buf_free(bb)
  return resp
@end

@! ----------------------------------------------------------------------------
@! 4. HTTP Transfer-Encoding: Chunked Decoder
@! ----------------------------------------------------------------------------

@fn http_decode_chunked(raw_body)
  rb = str(raw_body)
  rbp = _http_raw_ptr(rb)
  blen = str_len(rb)
  @if blen == 0 return "" @end
  out_b = buf_new(blen)
  pos = 0

  @while pos < blen
    @! Find end of chunk header line (\r\n or \n)
    line_end = -1
    i = pos
    @while i < blen
      ch = mem_byte_read(rbp, i) & 255
      @if ch == 10 @! '\n'
        line_end = i
        break
      @end
      i = i + 1
    @end

    @if line_end == -1
      break
    @else
      line_str = bytes_to_str(rbp + pos, line_end - pos)
      semi_pos = str_index_of(line_str, ";")
      @if semi_pos >= 0
        line_str = str_substr(line_str, 0, semi_pos)
      @end
      line_str = str_trim(line_str)
      pos = line_end + 1

      @if str_len(line_str) > 0
        chunk_size = parse_hex_int(line_str)
        @if chunk_size <= 0 || pos + chunk_size > blen
          break
        @else
          buf_write_mem(out_b, rbp + pos, chunk_size)
          pos = pos + chunk_size
          @if pos < blen && (mem_byte_read(rbp, pos) & 255) == 13
            pos = pos + 1
          @end
          @if pos < blen && (mem_byte_read(rbp, pos) & 255) == 10
            pos = pos + 1
          @end
        @end
      @end
    @end
  @end

  result = buf_to_str(out_b)
  buf_free(out_b)
  return result
@end

@! ----------------------------------------------------------------------------
@! 5. HTTP/1.1 Response Parser Engine
@! ----------------------------------------------------------------------------

@fn http_parse_response(raw_http_str: string) -> HttpResponse
  status_code = 0
  status_text = ""
  version = "HTTP/1.1"
  headers = []
  body = ""

  raw_len = str_len(raw_http_str)
  @if raw_len == 0
    return HttpResponse(0, "Empty Response", version, headers, "")
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
  content_enc = ""
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
          headers = headers.push(HttpHeader(h_name, h_val))

          h_lower = str_to_lower(h_name)
          @if h_lower == "transfer-encoding" && contains(str_to_lower(h_val), "chunked") == 1
            is_chunked = 1
          @elif h_lower == "content-length" && content_len < 0
            content_len = parse_int_str(h_val)
          @elif h_lower == "content-encoding"
            ce_part = str_to_lower(str_trim(h_val))
            @if ce_part != ""
              @if content_enc == ""
                content_enc = ce_part
              @else
                content_enc = content_enc + ", " + ce_part
              @end
            @end
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

  @if content_enc != "" && content_enc != "identity"
    dec_res = deflate_decompress_http(content_enc, body)
    @if dec_res.dr_ok == 1
      body = dec_res.dr_data
    @end
  @end

  return HttpResponse(status_code, status_text, version, headers, body)
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

@fn http_parse_url(url) -> HttpUrl
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

  return HttpUrl(proto, host, port, path)
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
    // WHY: Use SYS_sendto (44) with MSG_NOSIGNAL (0x4000=16384) so writing to a peer-closed
    // pooled TLS socket returns -EPIPE instead of killing the client process with SIGPIPE (141)!
    w = syscall(44, fd, buf + sent, n - sent, 16384, 0, 0)
    @if w == (0 - 4)
      continue
    @end
    @if w == (0 - 88)
      w = sys_write(fd, buf + sent, n - sent)
    @end
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
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  @if (sh_hs[0] & 255) != 2
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  is_hrr = _http_tls_is_hrr_random(sh_hs)
  sid_len = sh_hs[38] & 255
  cipher_off = 39 + sid_len
  pos = cipher_off + 3
  @if pos + 2 > n
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  cipher = ((sh_hs[cipher_off] & 255) * 256) | (sh_hs[cipher_off + 1] & 255)
  @if cipher != 4865 && cipher != 4866 && cipher != 4867
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  ext_tot = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
  pos = pos + 2
  ext_end = pos + ext_tot
  @if ext_end > n ext_end = n @end

  has_tls13 = 0
  server_pub = []
  cookie = []
  hrr_grp_ok = 1
  has_psk = 0
  psk_id = 0
  @while pos + 4 <= ext_end
    et = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
    el = ((sh_hs[pos + 2] & 255) * 256) | (sh_hs[pos + 3] & 255)
    pos = pos + 4
    @if pos + el > ext_end break @end
    @if et == 43 && el == 2
      @if (sh_hs[pos] & 255) == 3 && (sh_hs[pos + 1] & 255) == 4
        has_tls13 = 1
      @end
    @elif et == 41 && el == 2
      has_psk = 1
      psk_id = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
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
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  @if is_hrr == 1
    @if hrr_grp_ok != 1
      return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
    @end
    return HttpTlsServerHello(1, server_pub, cipher, 1, cookie, 0, 0)
  @end
  @if server_pub.len() != 32
    return HttpTlsServerHello(0, [], 0, 0, [], 0, 0)
  @end
  return HttpTlsServerHello(1, server_pub, cipher, 0, [], has_psk, psk_id)
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

@fn _http_tls_extract_cert_chain(cert_hs)
  n = cert_hs.len()
  @if n < 12 return [] @end
  ctx_len = cert_hs[4] & 255
  list_off = 5 + ctx_len
  @if list_off + 3 > n return [] @end
  list_len = ((cert_hs[list_off] & 255) * 65536) | ((cert_hs[list_off + 1] & 255) * 256) | (cert_hs[list_off + 2] & 255)
  pos = list_off + 3
  list_end = pos + list_len
  @if list_end > n return [] @end
  chain = []
  @while pos + 5 <= list_end
    cert_len = ((cert_hs[pos] & 255) * 65536) | ((cert_hs[pos + 1] & 255) * 256) | (cert_hs[pos + 2] & 255)
    pos = pos + 3
    @if cert_len <= 0 || pos + cert_len + 2 > list_end
      return []
    @end
    chain = chain.push(_http_tls_slice(cert_hs, pos, pos + cert_len))
    pos = pos + cert_len
    ext_len = ((cert_hs[pos] & 255) * 256) | (cert_hs[pos + 1] & 255)
    pos = pos + 2 + ext_len
    @if pos > list_end return [] @end
  @end
  return chain
@end

@fn _http_tls_extract_cert_der(cert_hs)
  chain = _http_tls_extract_cert_chain(cert_hs)
  @if chain.len() == 0 return [] @end
  return chain[0]
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
    return HttpTlsAppKeys(
      tls13_hkdf_expand_label_384(c_app, "key", [], 32),
      tls13_hkdf_expand_label_384(c_app, "iv", [], 12),
      tls13_hkdf_expand_label_384(s_app, "key", [], 32),
      tls13_hkdf_expand_label_384(s_app, "iv", [], 12),
      master
    )
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
  return HttpTlsAppKeys(
    tls13_hkdf_expand_label(c_app, "key", [], klen),
    tls13_hkdf_expand_label(c_app, "iv", [], 12),
    tls13_hkdf_expand_label(s_app, "key", [], klen),
    tls13_hkdf_expand_label(s_app, "iv", [], 12),
    master
  )
@end

@fn _http_is_chunked_complete_bytes(raw_resp, start_off, rlen)
  // WHY: Walks RFC 9112 chunked transfer framing byte-by-byte using exact raw byte reads so
  // binary gzip/deflate chunks containing embedded 0x00 NUL bytes, chunk extensions, and trailers
  // are accurately framed without string truncation or false-positive terminator matches.
  pos = start_off
  @while pos < rlen
    nl = 0 - 1
    i = pos
    @while i < rlen
      @if (mem_byte_read(raw_resp, i) & 255) == 10
        nl = i
        break
      @end
      i = i + 1
    @end
    @if nl < 0 return 0 @end
    // Parse hex chunk size before optional ';' extension / '\r'
    csz = 0
    saw_hex = 0
    j = pos
    @while j < nl
      b = mem_byte_read(raw_resp, j) & 255
      @if b == 59 || b == 13
        break
      @elif b >= 48 && b <= 57
        csz = (csz * 16) + (b - 48)
        saw_hex = 1
      @elif b >= 97 && b <= 102
        csz = (csz * 16) + (b - 87)
        saw_hex = 1
      @elif b >= 65 && b <= 70
        csz = (csz * 16) + (b - 55)
        saw_hex = 1
      @elif b != 32 && b != 9
        return 0
      @end
      j = j + 1
    @end
    @if saw_hex == 0 return 0 @end
    pos = nl + 1
    @if csz == 0
      // Terminal 0-length chunk: wait for final empty CRLF/LF line ending optional trailers
      @while pos < rlen
        b0 = mem_byte_read(raw_resp, pos) & 255
        @if b0 == 10
          return 1
        @elif b0 == 13 && pos + 1 < rlen && (mem_byte_read(raw_resp, pos + 1) & 255) == 10
          return 1
        @end
        // Skip trailer line
        tl = 0 - 1
        k = pos
        @while k < rlen
          @if (mem_byte_read(raw_resp, k) & 255) == 10
            tl = k
            break
          @end
          k = k + 1
        @end
        @if tl < 0 return 0 @end
        pos = tl + 1
      @end
      return 0
    @end
    // Skip chunk payload bytes + trailing CRLF (or LF)
    pos = pos + csz
    @if pos >= rlen return 0 @end
    @if (mem_byte_read(raw_resp, pos) & 255) == 13
      @if pos + 1 >= rlen return 0 @end
      pos = pos + 2
    @elif (mem_byte_read(raw_resp, pos) & 255) == 10
      pos = pos + 1
    @else
      return 0
    @end
  @end
  return 0
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
    hl = str_to_lower(_http_hdr_name(h))
    hv = _http_hdr_value(h)
    @if hl == "transfer-encoding" && contains(str_to_lower(hv), "chunked") == 1
      is_chunked = 1
    @elif hl == "content-length" && clen < 0
      clen = parse_int_str(hv)
    @end
    hi = hi + 1
  @end
  body_have = rlen - (hend + sep)
  @if is_chunked == 1
    return _http_is_chunked_complete_bytes(raw_resp, hend + sep, rlen)
  @end
  @if clen >= 0 && body_have >= clen
    return 1
  @end
  return 0
@end

@struct HttpTlsSession
  hts_ok: i64
  hts_fd: i64
  hts_cipher: i64
  hts_c_key: array
  hts_c_iv: array
  hts_s_key: array
  hts_s_iv: array
  hts_c_seq: i64
  hts_s_seq: i64
  hts_host: string
  hts_res_master: array
  hts_resumed: i64
@end

global g_http_last_tls_resumed = 0

@fn http_last_tls_was_resumed()
  return g_http_last_tls_resumed
@end

@fn _http_tls_session_invalid() -> HttpTlsSession
  return HttpTlsSession(0, 0 - 1, 0, [], [], [], [], 0, 0, "", [], 0)
@end

@fn _http_tls_connect_session(stream: TcpStream, host) -> HttpTlsSession
  // WHY: Performs a full RFC 8446 TLS 1.3 client handshake (X25519 + PSK 1-RTT Resumption + HRR + X.509 + Finished)
  // and returns a persistent HttpTlsSession whose application traffic keys, AEAD sequence numbers,
  // and resumption_master_secret enable both Keep-Alive reuse and cross-connection PSK resumption!
  c_priv = _http_tls_rand32()
  @if c_priv.len() != 32 return _http_tls_session_invalid() @end
  c_pub = x25519_public_key(c_priv)
  cached_t = tls13_cache_lookup_ticket(host, "http/1.1")
  ch = 0
  @if cached_t != 0
    ch = tls13_build_client_hello_psk(host, c_pub, [], cached_t)
  @else
    ch = tls13_build_client_hello(host, c_pub)
  @end
  @if ch.wire_bytes.len() < 46 return _http_tls_session_invalid() @end
  ch_hs = _http_tls_slice(ch.wire_bytes, 5, ch.wire_bytes.len())

  @if _http_tls_write_exact(stream.tcp_fd, ch.wire_bytes) <= 0
    return _http_tls_session_invalid()
  @end

  sh_hs = _http_tls_read_server_hello(stream.tcp_fd)
  @if sh_hs.len() == 0 return _http_tls_session_invalid() @end

  sh_info = _http_tls_parse_server_hello(sh_hs)
  @if sh_info.tls_sh_ok != 1 return _http_tls_session_invalid() @end
  cipher = sh_info.tls_sh_cipher

  hs_transcript = []
  used_psk = 0
  @if sh_info.tls_sh_is_hrr == 1
    h1 = _http_tls_hash_transcript(cipher, ch_hs)
    msg_hash = [254, 0, 0, h1.len() & 255]
    msg_hash = tls_append_bytes(msg_hash, h1)
    c_priv = _http_tls_rand32()
    @if c_priv.len() != 32 return _http_tls_session_invalid() @end
    c_pub = x25519_public_key(c_priv)
    ch2_wire = _http_tls_build_ch_with_cookie(host, c_pub, sh_info.tls_sh_cookie)
    @if ch2_wire.len() < 46 return _http_tls_session_invalid() @end
    ch2_hs = _http_tls_slice(ch2_wire, 5, ch2_wire.len())
    @if _http_tls_write_exact(stream.tcp_fd, ch2_wire) <= 0 return _http_tls_session_invalid() @end
    sh2_hs = _http_tls_read_server_hello(stream.tcp_fd)
    @if sh2_hs.len() == 0 return _http_tls_session_invalid() @end
    sh_info = _http_tls_parse_server_hello(sh2_hs)
    @if sh_info.tls_sh_ok != 1 || sh_info.tls_sh_is_hrr == 1 || sh_info.tls_sh_cipher != cipher
      return _http_tls_session_invalid()
    @end
    hs_transcript = tls_append_bytes(hs_transcript, msg_hash)
    hs_transcript = tls_append_bytes(hs_transcript, sh_hs)
    hs_transcript = tls_append_bytes(hs_transcript, ch2_hs)
    hs_transcript = tls_append_bytes(hs_transcript, sh2_hs)
  @else
    hs_transcript = tls_append_bytes(hs_transcript, ch_hs)
    hs_transcript = tls_append_bytes(hs_transcript, sh_hs)
    @if sh_info.tls_sh_has_psk == 1
      // RFC 8446 §4.2.11: Abort if server returns unsolicited PSK, out-of-range identity, or mismatched cipher
      @if cached_t == 0 || sh_info.tls_sh_psk_id != 0 || cipher != cached_t.tst_cipher
        return _http_tls_session_invalid()
      @end
      used_psk = 1
    @end
  @end

  shared = x25519_shared_secret(c_priv, sh_info.tls_sh_pub)
  @if shared.len() != 32 return _http_tls_session_invalid() @end
  thash1 = _http_tls_hash_transcript(cipher, hs_transcript)
  hs_keys = 0
  @if used_psk == 1
    hs_keys = tls13_derive_psk_handshake_keys(cached_t.tst_psk, shared, thash1, cipher)
  @else
    hs_keys = _http_tls_derive_hs_keys_for_cipher(cipher, shared, thash1)
  @end

  @! Consume server encrypted handshake flight through EncryptedExtensions, [Cert, CertVerify], Finished
  hs_buf = []
  s_hs_seq = 0
  got_server_finished = 0
  got_cert = 0
  got_cert_verify = 0
  cert_der = []
  flight_steps = 0
  @while got_server_finished == 0 && flight_steps < 64
    flight_steps = flight_steps + 1
    rec = _http_tls_read_record(stream.tcp_fd)
    @if rec.tls_rec_ok != 1 return _http_tls_session_invalid() @end
    @if rec.tls_rec_type == 20
      continue
    @end
    @if rec.tls_rec_type != 23
      return _http_tls_session_invalid()
    @end
    unwrapped = _http_tls_unwrap_aead_record_suite(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, rec.tls_rec_hdr, rec.tls_rec_body)
    @if unwrapped.tls_pt_ok != 1 return _http_tls_session_invalid() @end
    s_hs_seq = s_hs_seq + 1
    @if unwrapped.tls_pt_type == 21
      return _http_tls_session_invalid()
    @end
    @if unwrapped.tls_pt_type != 22
      return _http_tls_session_invalid()
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
        cert_chain = _http_tls_extract_cert_chain(msg)
        @if cert_chain.len() == 0 || tls13_verify_x509_cert_chain_list(cert_chain, host) != 1
          return _http_tls_session_invalid()
        @end
        cert_der = cert_chain[0]
        got_cert = 1
      @elif ht == 15
        @if got_cert != 1 || msg.len() < 8
          return _http_tls_session_invalid()
        @end
        sig_alg = ((msg[4] & 255) * 256) | (msg[5] & 255)
        sig_len = ((msg[6] & 255) * 256) | (msg[7] & 255)
        @if 8 + sig_len != msg.len()
          return _http_tls_session_invalid()
        @end
        sig_bytes = _http_tls_slice(msg, 8, 8 + sig_len)
        cv_hash = _http_tls_hash_transcript(cipher, hs_transcript)
        @if tls13_verify_certificate_verify(cert_der, cv_hash, sig_alg, sig_bytes) != 1
          return _http_tls_session_invalid()
        @end
        got_cert_verify = 1
      @elif ht == 20
        @if used_psk == 0 && (got_cert != 1 || got_cert_verify != 1)
          return _http_tls_session_invalid()
        @end
        expected_hl = 32
        @if cipher == 4866 expected_hl = 48 @end
        @if hl != expected_hl return _http_tls_session_invalid() @end
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
          return _http_tls_session_invalid()
        @end
        hs_transcript = tls_append_bytes(hs_transcript, msg)
        got_server_finished = 1
        break
      @end
      hs_transcript = tls_append_bytes(hs_transcript, msg)
    @end
    hs_buf = _http_tls_slice(hs_buf, pos, hs_buf.len())
  @end

  @if got_server_finished != 1 || (used_psk == 0 && (got_cert != 1 || got_cert_verify != 1))
    return _http_tls_session_invalid()
  @end

  @! Derive RFC 8446 Application Traffic Secrets & Keys
  fin_hash = _http_tls_hash_transcript(cipher, hs_transcript)
  app_keys = _http_tls_derive_app_keys_for_cipher(cipher, hs_keys, fin_hash)

  @! Send encrypted Client Finished
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
  @if _http_tls_write_exact(stream.tcp_fd, c_fin_rec) <= 0 return _http_tls_session_invalid() @end

  @! Derive RFC 8446 §7.1 resumption_master_secret over H(ClientHello..ClientFinished)
  full_tr = tls_append_bytes(hs_transcript, c_fin_msg)
  res_thash = _http_tls_hash_transcript(cipher, full_tr)
  res_master = tls13_derive_resumption_master_secret(cipher, app_keys.master_secret, res_thash)
  g_http_last_tls_resumed = used_psk

  return HttpTlsSession(1, stream.tcp_fd, cipher, app_keys.c_key, app_keys.c_iv, app_keys.s_key, app_keys.s_iv, 0, 0, host, res_master, used_psk)
@end

@fn _http_tls_session_exchange(sess: HttpTlsSession, req_str)
  // WHY: Sends one HTTP/1.1 request and reads one framed HTTP/1.1 response over an established
  // RFC 8446 TLS 1.3 session while advancing monotonic client/server AEAD record nonces.
  @if sess == 0 || sess.hts_ok != 1 || sess.hts_fd < 0 return "" @end
  cipher = sess.hts_cipher
  req_bytes = tls_string_to_bytes(req_str)
  rlen = req_bytes.len()
  @if rlen == 0
    req_rec = _http_tls_wrap_aead_record_suite(cipher, sess.hts_c_key, sess.hts_c_iv, sess.hts_c_seq, 23, req_bytes)
    @if _http_tls_write_exact(sess.hts_fd, req_rec) <= 0
      sess.hts_ok = 0
      return ""
    @end
    sess.hts_c_seq = sess.hts_c_seq + 1
  @else
    roff = 0
    @while roff < rlen
      rstop = roff + 16384
      @if rstop > rlen rstop = rlen @end
      rchunk = _http_tls_slice(req_bytes, roff, rstop)
      req_rec = _http_tls_wrap_aead_record_suite(cipher, sess.hts_c_key, sess.hts_c_iv, sess.hts_c_seq, 23, rchunk)
      @if _http_tls_write_exact(sess.hts_fd, req_rec) <= 0
        sess.hts_ok = 0
        return ""
      @end
      sess.hts_c_seq = sess.hts_c_seq + 1
      roff = rstop
    @end
  @end

  @! Receive encrypted HTTPS response records into O(N) ByteBuffer
  resp_buf = buf_new(4096)
  ph_buf = []
  @while 1 == 1
    rec = _http_tls_read_record(sess.hts_fd)
    @if rec.tls_rec_ok != 1
      sess.hts_ok = 0
      break
    @end
    @if rec.tls_rec_type == 20
      continue
    @end
    @if rec.tls_rec_type == 21
      sess.hts_ok = 0
      break
    @end
    @if rec.tls_rec_type != 23
      sess.hts_ok = 0
      buf_free(resp_buf)
      return ""
    @end
    dec = _http_tls_unwrap_aead_record_suite(cipher, sess.hts_s_key, sess.hts_s_iv, sess.hts_s_seq, rec.tls_rec_hdr, rec.tls_rec_body)
    @if dec.tls_pt_ok != 1
      sess.hts_ok = 0
      buf_free(resp_buf)
      return ""
    @end
    sess.hts_s_seq = sess.hts_s_seq + 1
    @if dec.tls_pt_type == 21
      sess.hts_ok = 0
      break
    @elif dec.tls_pt_type == 22
      // Capture post-handshake RFC 8446 NewSessionTicket (type 4) across coalesced OR fragmented TLS records
      ph_buf = tls_append_bytes(ph_buf, dec.tls_pt_data)
      ph_pos = 0
      @while ph_pos + 4 <= ph_buf.len()
        ph_t = ph_buf[ph_pos] & 255
        ph_l = ((ph_buf[ph_pos + 1] & 255) << 16) | ((ph_buf[ph_pos + 2] & 255) << 8) | (ph_buf[ph_pos + 3] & 255)
        @if ph_pos + 4 + ph_l > ph_buf.len() break @end
        @if ph_t == 4 && sess.hts_res_master.len() > 0
          nst_msg = _http_tls_slice(ph_buf, ph_pos, ph_pos + 4 + ph_l)
          tls13_parse_new_session_ticket(nst_msg, cipher, sess.hts_res_master, sess.hts_host, "http/1.1")
        @end
        ph_pos = ph_pos + 4 + ph_l
      @end
      @if ph_pos > 0
        ph_buf = _http_tls_slice(ph_buf, ph_pos, ph_buf.len())
      @end
      continue
    @elif dec.tls_pt_type == 23
      pt_arr = dec.tls_pt_data
      pt_i = 0
      pt_n = pt_arr.len()
      @while pt_i < pt_n
        buf_write_byte(resp_buf, pt_arr[pt_i] & 255)
        pt_i = pt_i + 1
      @end
      @if _http_is_wire_response_complete(buf_to_str(resp_buf)) == 1
        break
      @end
    @end
  @end

  raw_resp = buf_to_str(resp_buf)
  buf_free(resp_buf)
  return raw_resp
@end

@fn _http_tls_exchange(stream: TcpStream, host, req_str)
  sess = _http_tls_connect_session(stream, host)
  @if sess.hts_ok != 1 return "" @end
  return _http_tls_session_exchange(sess, req_str)
@end

@! ----------------------------------------------------------------------------
@! 7. High-Level HTTP Client API (GET & POST over HTTP & HTTPS TLS 1.3)
@! ----------------------------------------------------------------------------

@fn _http_build_client_headers(u: HttpUrl, extra_headers)
  has_host = 0
  has_conn = 0
  has_ae = 0
  req_hdrs = []
  i = 0
  @while i < extra_headers.len()
    h = extra_headers[i]
    hn = str_to_lower(_http_hdr_name(h))
    @if hn == "host" has_host = 1 @end
    @if hn == "connection" has_conn = 1 @end
    @if hn == "accept-encoding" has_ae = 1 @end
    req_hdrs = req_hdrs.push(h)
    i = i + 1
  @end
  @if has_host == 0
    host_hdr = u.host
    @if u.port != 80 && u.port != 443
      host_hdr = string_concat(host_hdr, string_concat(":", int_to_str(u.port)))
    @end
    req_hdrs = req_hdrs.push(HttpHeader("Host", host_hdr))
  @end
  req_hdrs = req_hdrs.push(HttpHeader("User-Agent", "LiPi-Universe-Client/1.0"))
  req_hdrs = req_hdrs.push(HttpHeader("Accept", "*/*"))
  @if has_ae == 0
    req_hdrs = req_hdrs.push(HttpHeader("Accept-Encoding", "gzip, deflate"))
  @end
  @if has_conn == 0
    req_hdrs = req_hdrs.push(HttpHeader("Connection", "close"))
  @end
  return req_hdrs
@end

@fn _http_resolve_redirect(base_u: HttpUrl, loc)
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
    @if str_to_lower(_http_hdr_name(h)) == name_lower
      return _http_hdr_value(h)
    @end
    i = i + 1
  @end
  return ""
@end

@fn _http_execute_single_to(method, url, extra_headers, body, timeout_ms) -> HttpResponse
  u = http_parse_url(url)
  stream = tcp_stream_connect(u.host, u.port)
  @if stream.tcp_fd < 0
    return HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
  @end
  @if timeout_ms > 0
    tcp_set_timeout_ms(stream.tcp_fd, timeout_ms)
  @end

  req_hdrs = _http_build_client_headers(u, extra_headers)
  req = http_format_request(method, u.path, req_hdrs, body)
  raw_resp = ""
  @if u.protocol == "https"
    raw_resp = _http_tls_exchange(stream, u.host, req)
    tcp_stream_close(stream)
    @if raw_resp == ""
      return HttpResponse(0, "TLS handshake failed", "HTTP/1.1", [], "")
    @end
    return http_parse_response(raw_resp)
  @end

  tcp_stream_write(stream, req)
  raw_resp = _http_read_framed_response_fd(stream.tcp_fd)
  tcp_stream_close(stream)
  return http_parse_response(raw_resp)
@end

@fn _http_execute_single(method, url, extra_headers, body) -> HttpResponse
  return _http_execute_single_to(method, url, extra_headers, body, 0)
@end

@fn _http_execute_to(method, url, extra_headers, body, timeout_ms) -> HttpResponse
  cur_method = method
  cur_url = url
  cur_body = body
  hop = 0
  resp = HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
  @while hop < 6
    resp = _http_execute_single_to(cur_method, cur_url, extra_headers, cur_body, timeout_ms)
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

@fn _http_execute(method, url, extra_headers, body) -> HttpResponse
  return _http_execute_to(method, url, extra_headers, body, 0)
@end

@fn http_get(url) -> HttpResponse
  return _http_execute("GET", url, [], "")
@end

@fn http_post(url, headers, body) -> HttpResponse
  return _http_execute("POST", url, headers, body)
@end

@fn http_put(url, headers, body) -> HttpResponse
  return _http_execute("PUT", url, headers, body)
@end

@fn http_delete(url, headers) -> HttpResponse
  return _http_execute("DELETE", url, headers, "")
@end

@fn http_patch(url, headers, body) -> HttpResponse
  return _http_execute("PATCH", url, headers, body)
@end

@fn http_request_with_timeout(method, url, headers, body, timeout_ms) -> HttpResponse
  return _http_execute_to(method, url, headers, body, timeout_ms)
@end

@! ── Keep-Alive Connection Pool & Cancellable Request Context ─────────────────
@struct HttpCancelToken
  hct_cancelled: i64
  hct_deadline_ms: i64
@end

@fn http_cancel_token_new(timeout_ms)
  dl = 0
  @if timeout_ms > 0 dl = clock_ms() + timeout_ms @end
  return { hct_cancelled: 0, hct_deadline_ms: dl }
@end

@fn http_cancel_trigger(tok: HttpCancelToken)
  @if tok != 0 tok.hct_cancelled = 1 @end
  return 1
@end

@fn http_cancel_is_aborted(tok: HttpCancelToken)
  @if tok == 0 return 0 @end
  @if tok.hct_cancelled != 0 return 1 @end
  @if tok.hct_deadline_ms > 0 && clock_ms() >= tok.hct_deadline_ms return 1 @end
  return 0
@end

@fn http_socket_set_timeout_ms(fd, timeout_ms)
  // WHY: Configures Linux SO_RCVTIMEO (20) & SO_SNDTIMEO (21) with struct timeval {tv_sec, tv_usec}.
  @if fd < 0 || timeout_ms <= 0 return 0 @end
  tv = malloc(16)
  @if tv <= 0 return 0 @end
  mem_write(tv, 0, timeout_ms / 1000)
  mem_write(tv, 8, (timeout_ms % 1000) * 1000)
  syscall(54, fd, 1, 20, tv, 16, 0)
  syscall(54, fd, 1, 21, tv, 16, 0)
  free(tv, 16)
  return 1
@end

@struct HttpConnPool
  hcp_max_idle: i64
  hcp_keys: array
  hcp_fds: array
  hcp_ts: array
  hcp_tls: array
@end

@fn http_pool_new(max_idle)
  mi = max_idle
  @if mi <= 0 mi = 16 @end
  return { hcp_max_idle: mi, hcp_keys: [], hcp_fds: [], hcp_ts: [], hcp_tls: [] }
@end

@fn http_pool_acquire(pool: HttpConnPool, host_port_key)
  @if pool == 0 return 0 - 1 @end
  i = 0
  n = pool.hcp_keys.len()
  @while i < n
    @if pool.hcp_keys[i] == host_port_key && pool.hcp_fds[i] >= 0 && pool.hcp_tls[i] == 0
      fd = pool.hcp_fds[i]
      list_set(pool.hcp_fds, i, 0 - 1)
      return fd
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn http_pool_release(pool: HttpConnPool, host_port_key, fd)
  @if pool == 0 || fd < 0 return 0 @end
  i = 0
  n = pool.hcp_keys.len()
  @while i < n
    @if pool.hcp_fds[i] < 0
      list_set(pool.hcp_keys, i, host_port_key)
      list_set(pool.hcp_fds, i, fd)
      list_set(pool.hcp_ts, i, clock_ms())
      list_set(pool.hcp_tls, i, 0)
      return 1
    @end
    i = i + 1
  @end
  @if n < pool.hcp_max_idle
    pool.hcp_keys = pool.hcp_keys.push(host_port_key)
    pool.hcp_fds = pool.hcp_fds.push(fd)
    pool.hcp_ts = pool.hcp_ts.push(clock_ms())
    pool.hcp_tls = pool.hcp_tls.push(0)
    return 1
  @end
  syscall(3, fd, 0, 0, 0, 0, 0)
  return 0
@end

@fn http_pool_acquire_tls(pool: HttpConnPool, host_port_key) -> HttpTlsSession
  @if pool == 0 return _http_tls_session_invalid() @end
  i = 0
  n = pool.hcp_keys.len()
  @while i < n
    @if pool.hcp_keys[i] == host_port_key && pool.hcp_fds[i] >= 0 && pool.hcp_tls[i] != 0
      sess = pool.hcp_tls[i]
      list_set(pool.hcp_fds, i, 0 - 1)
      list_set(pool.hcp_tls, i, 0)
      return sess
    @end
    i = i + 1
  @end
  return _http_tls_session_invalid()
@end

@fn http_pool_release_tls(pool: HttpConnPool, host_port_key, sess: HttpTlsSession)
  @if pool == 0 || sess == 0 || sess.hts_ok != 1 || sess.hts_fd < 0
    @if sess != 0 && sess.hts_fd >= 0
      syscall(3, sess.hts_fd, 0, 0, 0, 0, 0)
    @end
    return 0
  @end
  i = 0
  n = pool.hcp_keys.len()
  @while i < n
    @if pool.hcp_fds[i] < 0
      list_set(pool.hcp_keys, i, host_port_key)
      list_set(pool.hcp_fds, i, sess.hts_fd)
      list_set(pool.hcp_ts, i, clock_ms())
      list_set(pool.hcp_tls, i, sess)
      return 1
    @end
    i = i + 1
  @end
  @if n < pool.hcp_max_idle
    pool.hcp_keys = pool.hcp_keys.push(host_port_key)
    pool.hcp_fds = pool.hcp_fds.push(sess.hts_fd)
    pool.hcp_ts = pool.hcp_ts.push(clock_ms())
    pool.hcp_tls = pool.hcp_tls.push(sess)
    return 1
  @end
  syscall(3, sess.hts_fd, 0, 0, 0, 0, 0)
  return 0
@end

@fn http_pool_close_all(pool: HttpConnPool)
  @if pool == 0 return 0 @end
  i = 0
  @while i < pool.hcp_fds.len()
    @if pool.hcp_fds[i] >= 0
      syscall(3, pool.hcp_fds[i], 0, 0, 0, 0, 0)
      list_set(pool.hcp_fds, i, 0 - 1)
    @end
    @if i < pool.hcp_tls.len()
      list_set(pool.hcp_tls, i, 0)
    @end
    i = i + 1
  @end
  return 1
@end

@fn _http_read_framed_response_fd(fd)
  // WHY: O(N) ByteBuffer HTTP/1.1 response reader supporting both Content-Length and
  // Transfer-Encoding: chunked without O(N^2) buf_to_str() copies per read chunk,
  // enabling true HTTP/1.1 keep-alive connection reuse without waiting for TCP EOF!
  acc = buf_new(4096)
  rbuf = lipi_alloc(8192)
  @if rbuf <= 0
    buf_free(acc)
    return ""
  @end
  hdr_end = 0 - 1
  sep_len = 4
  clen = 0 - 1
  is_chunked = 0
  @while 1 == 1
    nr = sys_read(fd, rbuf, 8192)
    @if nr == (0 - 4) continue @end
    @if nr <= 0 break @end
    buf_write_mem(acc, rbuf, nr)
    @if hdr_end < 0
      hdr_end = _http_buf_find_hdr_end(acc)
      sep_len = 4
      @if hdr_end >= 0
        hdr_s = bytes_to_str(buf_ptr(acc), hdr_end + sep_len)
        head_r = http_parse_response(hdr_s)
        te_v = _http_find_header_value(head_r.headers, "transfer-encoding")
        @if te_v != "" && contains(str_to_lower(te_v), "chunked") == 1
          is_chunked = 1
        @else
          cl_v = _http_find_header_value(head_r.headers, "content-length")
          @if cl_v != ""
            clen = parse_int_str(cl_v)
          @end
        @end
      @end
    @end
    @if hdr_end >= 0
      body_off = hdr_end + sep_len
      have_b = buf_len(acc) - body_off
      @if is_chunked == 1
        tail_s = bytes_to_str(buf_ptr(acc) + body_off, have_b)
        @if contains(tail_s, "\r\n0\r\n\r\n") == 1 || starts_with(tail_s, "0\r\n\r\n") == 1
          break
        @end
      @elif clen >= 0 && have_b >= clen
        break
      @end
    @end
  @end
  lipi_free_sized(rbuf, 8192)
  raw_r = buf_to_str(acc)
  buf_free(acc)
  return raw_r
@end

@fn http_pool_request(pool: HttpConnPool, method, url, extra_headers, body) -> HttpResponse
  // WHY: Executes an HTTP/1.1 or HTTPS (TLS 1.3) request over a pooled persistent Keep-Alive
  // connection (caching live HttpTlsSession traffic keys & AEAD sequence counters for https://),
  // automatically reconnecting once if a pooled idle socket/session was closed by the peer.
  u = http_parse_url(url)
  ka_hdrs = []
  has_conn = 0
  hi = 0
  @while hi < extra_headers.len()
    h = extra_headers[hi]
    hn = _http_hdr_name(h)
    @if hn == "Connection" || hn == "connection" has_conn = 1 @end
    ka_hdrs = ka_hdrs.push(h)
    hi = hi + 1
  @end
  @if has_conn == 0
    ka_hdrs = ka_hdrs.push(HttpHeader("Connection", "keep-alive"))
  @end
  req_hdrs = _http_build_client_headers(u, ka_hdrs)
  req_str = http_format_request(method, u.path, req_hdrs, body)

  @if u.protocol == "https"
    tls_key = string_concat("https://", string_concat(u.host, string_concat(":", int_to_str(u.port))))
    t_attempt = 0
    @while t_attempt < 2
      sess = http_pool_acquire_tls(pool, tls_key)
      t_reused = 1
      @if sess.hts_ok != 1 || sess.hts_fd < 0
        t_reused = 0
        t_st = tcp_stream_connect(u.host, u.port)
        @if t_st.tcp_fd < 0
          return HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
        @end
        http_socket_set_timeout_ms(t_st.tcp_fd, 10000)
        sess = _http_tls_connect_session(t_st, u.host)
        @if sess.hts_ok != 1
          tcp_stream_close(t_st)
          return HttpResponse(0, "TLS handshake failed", "HTTP/1.1", [], "")
        @end
      @else
        http_socket_set_timeout_ms(sess.hts_fd, 10000)
      @end

      raw_t_resp = _http_tls_session_exchange(sess, req_str)
      @if str_len(raw_t_resp) == 0 && t_reused == 1 && t_attempt == 0
        syscall(3, sess.hts_fd, 0, 0, 0, 0, 0)
        t_attempt = t_attempt + 1
        continue
      @end
      t_resp = http_parse_response(raw_t_resp)
      t_srv_conn = str_to_lower(_http_find_header_value(t_resp.headers, "connection"))
      @if t_resp.status_code > 0 && sess.hts_ok == 1 && t_srv_conn != "close"
        http_pool_release_tls(pool, tls_key, sess)
      @else
        syscall(3, sess.hts_fd, 0, 0, 0, 0, 0)
      @end
      return t_resp
    @end
    return HttpResponse(0, "TLS connection failed", "HTTP/1.1", [], "")
  @end

  key = string_concat(u.host, string_concat(":", int_to_str(u.port)))
  req_len = str_len(req_str)
  req_ptr = _http_raw_ptr(req_str)

  attempt = 0
  @while attempt < 2
    fd = http_pool_acquire(pool, key)
    reused = 1
    @if fd < 0
      reused = 0
      st = tcp_stream_connect(u.host, u.port)
      fd = st.tcp_fd
    @end
    @if fd < 0
      return HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
    @end
    http_socket_set_timeout_ms(fd, 10000)

    sent = 0
    w_ok = 1
    @while sent < req_len
      w = syscall(44, fd, req_ptr + sent, req_len - sent, 16384, 0, 0)
      @if w == (0 - 4) continue @end
      @if w == (0 - 88) w = sys_write(fd, req_ptr + sent, req_len - sent) @end
      @if w <= 0
        w_ok = 0
        break
      @end
      sent = sent + w
    @end

    raw_resp = ""
    @if w_ok == 1
      raw_resp = _http_read_framed_response_fd(fd)
    @end
    @if str_len(raw_resp) == 0 && reused == 1 && attempt == 0
      syscall(3, fd, 0, 0, 0, 0, 0)
      attempt = attempt + 1
      continue
    @end
    resp = http_parse_response(raw_resp)
    srv_conn = str_to_lower(_http_find_header_value(resp.headers, "connection"))
    @if resp.status_code > 0 && srv_conn != "close"
      http_pool_release(pool, key, fd)
    @else
      syscall(3, fd, 0, 0, 0, 0, 0)
    @end
    return resp
  @end
  return HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
@end

@fn http_request_cancellable(method, url, headers, body, tok: HttpCancelToken) -> HttpResponse
  @if http_cancel_is_aborted(tok) == 1
    return { status_code: 499, status_text: "Cancelled", version: "HTTP/1.1", headers: [], body: "" }
  @end
  rem = 5000
  @if tok != 0 && tok.hct_deadline_ms > 0
    rem = tok.hct_deadline_ms - clock_ms()
    @if rem <= 0
      return { status_code: 408, status_text: "Request Timeout", version: "HTTP/1.1", headers: [], body: "" }
    @end
  @end
  return _http_execute_to(method, url, headers, body, rem)
@end

@! ----------------------------------------------------------------------------
@! 7b. Real-Time Incremental Streaming HTTP & HTTPS (TLS 1.3) SSE Client
@! ----------------------------------------------------------------------------

@struct HttpStreamState
  hs_buf: i64
  hs_chunked: i64
  hs_clen: i64
  hs_body_got: i64
  hs_cstate: i64
  hs_cneed: i64
  hs_done: i64
  hs_aborted: i64
  hs_headers_done: i64
  hs_status_code: i64
  hs_status_text: string
  hs_version: string
  hs_headers: array
  hs_content_enc: string
  hs_comp_buf: i64
  hs_flushed_comp: i64
@end

@fn _http_stream_deliver_chunk(st: HttpStreamState, chunk_s, on_chunk_fn)
  @if st.hs_content_enc != "" && st.hs_content_enc != "identity"
    @if st.hs_comp_buf == 0
      st.hs_comp_buf = buf_new(4096)
    @end
    @if str_len(chunk_s) > 0
      buf_write_mem(st.hs_comp_buf, chunk_s, str_len(chunk_s))
    @end
    return 0
  @end
  @if on_chunk_fn != 0
    rc = on_chunk_fn(chunk_s)
    @if rc == (0 - 1)
      st.hs_aborted = 1
      return 0 - 1
    @end
  @end
  return 0
@end

@fn _http_stream_flush_compressed(st: HttpStreamState, on_chunk_fn)
  @if st.hs_flushed_comp == 1 || st.hs_comp_buf == 0
    return 0
  @end
  st.hs_flushed_comp = 1
  raw_c = buf_to_str(st.hs_comp_buf)
  buf_free(st.hs_comp_buf)
  st.hs_comp_buf = 0
  @if str_len(raw_c) == 0 || on_chunk_fn == 0 || st.hs_aborted == 1
    return 0
  @end
  dec = deflate_decompress_http(st.hs_content_enc, raw_c)
  @if dec.dr_ok == 1
    on_chunk_fn(dec.dr_data)
  @else
    on_chunk_fn(raw_c)
  @end
  return 0
@end

@fn _http_buf_consume(b, count)
  cur_len = buf_len(b)
  @if count <= 0 return 0 @end
  @if count >= cur_len
    buf_clear(b)
    return 0
  @end
  rem = cur_len - count
  p = buf_ptr(b)
  i = 0
  @while i < rem
    mem_byte_write(p, i, mem_byte_read(p, count + i))
    i = i + 1
  @end
  @! Rebuild clean length in-place via temporary copy slice
  tail = bytes_to_str(p, rem)
  buf_clear(b)
  buf_write_mem(b, tail, rem)
  return 0
@end

@fn _http_buf_find_hdr_end(b)
  p = buf_ptr(b)
  n = buf_len(b)
  i = 0
  @while i + 3 < n
    @if (mem_byte_read(p, i) & 255) == 13 && (mem_byte_read(p, i + 1) & 255) == 10 && (mem_byte_read(p, i + 2) & 255) == 13 && (mem_byte_read(p, i + 3) & 255) == 10
      return i
    @end
    i = i + 1
  @end
  return 0 - 1
@end

@fn _http_stream_feed(st: HttpStreamState, data_ptr, data_len, on_chunk_fn)
  @if data_len > 0
    buf_write_mem(st.hs_buf, data_ptr, data_len)
  @end

  @while st.hs_done == 0 && st.hs_aborted == 0
    @if st.hs_headers_done == 0
      hend = _http_buf_find_hdr_end(st.hs_buf)
      sep = 4
      @if hend < 0
        @! Also support bare \n\n delimiter
        p0 = buf_ptr(st.hs_buf)
        n0 = buf_len(st.hs_buf)
        k = 0
        @while k + 1 < n0
          @if (mem_byte_read(p0, k) & 255) == 10 && (mem_byte_read(p0, k + 1) & 255) == 10
            hend = k
            sep = 2
            break
          @end
          k = k + 1
        @end
      @end
      @if hend < 0
        break
      @end
      hdr_raw = bytes_to_str(buf_ptr(st.hs_buf), hend + sep)
      parsed = http_parse_response(hdr_raw)
      st.hs_status_code = parsed.status_code
      st.hs_status_text = parsed.status_text
      st.hs_version = parsed.version
      st.hs_headers = parsed.headers
      hi = 0
      @while hi < parsed.headers.len()
        h = parsed.headers[hi]
        hl = str_to_lower(_http_hdr_name(h))
        hv = _http_hdr_value(h)
        @if hl == "transfer-encoding" && contains(str_to_lower(hv), "chunked") == 1
          st.hs_chunked = 1
        @elif hl == "content-length" && st.hs_clen < 0
          st.hs_clen = parse_int_str(hv)
        @elif hl == "content-encoding"
          ce_s = str_to_lower(str_trim(hv))
          @if ce_s != ""
            @if st.hs_content_enc == ""
              st.hs_content_enc = ce_s
            @else
              st.hs_content_enc = st.hs_content_enc + ", " + ce_s
            @end
          @end
        @end
        hi = hi + 1
      @end
      _http_buf_consume(st.hs_buf, hend + sep)
      st.hs_headers_done = 1
    @end

    @if st.hs_headers_done == 1
      @if st.hs_chunked == 1
        @if st.hs_cstate == 0
          p = buf_ptr(st.hs_buf)
          n = buf_len(st.hs_buf)
          nl = 0 - 1
          i = 0
          @while i < n
            @if (mem_byte_read(p, i) & 255) == 10
              nl = i
              break
            @end
            i = i + 1
          @end
          @if nl < 0 break @end
          line_s = bytes_to_str(p, nl)
          semi = str_index_of(line_s, ";")
          @if semi >= 0 line_s = str_substr(line_s, 0, semi) @end
          line_s = str_trim(line_s)
          _http_buf_consume(st.hs_buf, nl + 1)
          @if str_len(line_s) == 0 continue @end
          csz = parse_hex_int(line_s)
          @if csz <= 0
            st.hs_done = 1
            break
          @end
          st.hs_cneed = csz
          st.hs_cstate = 1
        @elif st.hs_cstate == 1
          av = buf_len(st.hs_buf)
          @if av <= 0 break @end
          take = av
          @if take > st.hs_cneed take = st.hs_cneed @end
          chunk_s = bytes_to_str(buf_ptr(st.hs_buf), take)
          _http_buf_consume(st.hs_buf, take)
          st.hs_cneed = st.hs_cneed - take
          st.hs_body_got = st.hs_body_got + take
          @if _http_stream_deliver_chunk(st, chunk_s, on_chunk_fn) == (0 - 1)
            break
          @end
          @if st.hs_cneed == 0
            st.hs_cstate = 2
          @end
        @else
          av = buf_len(st.hs_buf)
          @if av <= 0 break @end
          b0 = mem_byte_read(buf_ptr(st.hs_buf), 0) & 255
          @if b0 == 13
            @if av < 2 break @end
            b1 = mem_byte_read(buf_ptr(st.hs_buf), 1) & 255
            @if b1 == 10
              _http_buf_consume(st.hs_buf, 2)
            @else
              _http_buf_consume(st.hs_buf, 1)
            @end
          @elif b0 == 10
            _http_buf_consume(st.hs_buf, 1)
          @end
          st.hs_cstate = 0
        @end
      @else
        av = buf_len(st.hs_buf)
        @if av <= 0
          @if st.hs_clen == 0 st.hs_done = 1 @end
          break
        @end
        take = av
        @if st.hs_clen >= 0
          rem = st.hs_clen - st.hs_body_got
          @if take > rem take = rem @end
        @end
        @if take > 0
          chunk_s = bytes_to_str(buf_ptr(st.hs_buf), take)
          _http_buf_consume(st.hs_buf, take)
          st.hs_body_got = st.hs_body_got + take
          @if _http_stream_deliver_chunk(st, chunk_s, on_chunk_fn) == (0 - 1)
            break
          @end
        @end
        @if st.hs_clen >= 0 && st.hs_body_got >= st.hs_clen
          st.hs_done = 1
          break
        @end
      @end
    @end
  @end
  @if st.hs_done == 1
    _http_stream_flush_compressed(st, on_chunk_fn)
  @end
  return 0
@end

@fn _http_tls_exchange_stream(stream: TcpStream, host, req_str, st: HttpStreamState, on_chunk_fn)
  // WHY: Reuses _http_tls_connect_session so streaming HTTPS gets full TLS 1.3 PSK 1-RTT
  // resumption, post-handshake NewSessionTicket capture, and transparent gzip/deflate decoding.
  sess = _http_tls_connect_session(stream, host)
  @if sess.hts_ok != 1 return 0 @end
  cipher = sess.hts_cipher

  req_bytes = tls_string_to_bytes(req_str)
  rlen = req_bytes.len()
  c_app_seq = sess.hts_c_seq
  roff = 0
  @while roff < rlen
    rstop = roff + 16384
    @if rstop > rlen rstop = rlen @end
    rchunk = _http_tls_slice(req_bytes, roff, rstop)
    req_rec = _http_tls_wrap_aead_record_suite(cipher, sess.hts_c_key, sess.hts_c_iv, c_app_seq, 23, rchunk)
    @if _http_tls_write_exact(stream.tcp_fd, req_rec) <= 0 return 0 @end
    c_app_seq = c_app_seq + 1
    roff = rstop
  @end

  s_app_seq = sess.hts_s_seq
  ph_buf = []
  @while st.hs_done == 0 && st.hs_aborted == 0
    rec = _http_tls_read_record(stream.tcp_fd)
    @if rec.tls_rec_ok != 1 break @end
    @if rec.tls_rec_type == 20 continue @end
    @if rec.tls_rec_type == 21 break @end
    @if rec.tls_rec_type != 23 return 0 @end
    dec = _http_tls_unwrap_aead_record_suite(cipher, sess.hts_s_key, sess.hts_s_iv, s_app_seq, rec.tls_rec_hdr, rec.tls_rec_body)
    @if dec.tls_pt_ok != 1 return 0 @end
    s_app_seq = s_app_seq + 1
    @if dec.tls_pt_type == 21
      break
    @elif dec.tls_pt_type == 22
      ph_buf = tls_append_bytes(ph_buf, dec.tls_pt_data)
      ph_pos = 0
      @while ph_pos + 4 <= ph_buf.len()
        ph_t = ph_buf[ph_pos] & 255
        ph_l = ((ph_buf[ph_pos + 1] & 255) << 16) | ((ph_buf[ph_pos + 2] & 255) << 8) | (ph_buf[ph_pos + 3] & 255)
        @if ph_pos + 4 + ph_l > ph_buf.len() break @end
        @if ph_t == 4 && sess.hts_res_master.len() > 0
          nst_msg = _http_tls_slice(ph_buf, ph_pos, ph_pos + 4 + ph_l)
          tls13_parse_new_session_ticket(nst_msg, cipher, sess.hts_res_master, sess.hts_host, "http/1.1")
        @end
        ph_pos = ph_pos + 4 + ph_l
      @end
      @if ph_pos > 0
        ph_buf = _http_tls_slice(ph_buf, ph_pos, ph_buf.len())
      @end
      continue
    @elif dec.tls_pt_type == 23
      pt_str = tls_bytes_to_string(dec.tls_pt_data)
      _http_stream_feed(st, _http_raw_ptr(pt_str), str_len(pt_str), on_chunk_fn)
    @end
  @end
  _http_stream_flush_compressed(st, on_chunk_fn)
  return 1
@end

@fn http_request_stream(method, url, extra_headers, body, on_chunk_fn) -> HttpResponse
  // WHY: Real-time incremental SSE / chunked streaming client for both HTTP and HTTPS TLS 1.3.
  // Invokes on_chunk_fn(chunk_str) immediately upon arrival without waiting for full body EOF,
  // and transparently inflates Content-Encoding: gzip/deflate when returned by the server.
  u = http_parse_url(url)
  stream = tcp_stream_connect(u.host, u.port)
  @if stream.tcp_fd < 0
    return HttpResponse(0, "Connection failed", "HTTP/1.1", [], "")
  @end
  req_hdrs = _http_build_client_headers(u, extra_headers)
  req = http_format_request(method, u.path, req_hdrs, body)

  st = HttpStreamState(buf_new(4096), 0, 0 - 1, 0, 0, 0, 0, 0, 0, 0, "", "HTTP/1.1", [], "", 0, 0)
  @if u.protocol == "https"
    ok = _http_tls_exchange_stream(stream, u.host, req, st, on_chunk_fn)
    tcp_stream_close(stream)
    _http_stream_flush_compressed(st, on_chunk_fn)
    buf_free(st.hs_buf)
    @if ok != 1 && st.hs_status_code == 0
      return HttpResponse(0, "TLS handshake failed", "HTTP/1.1", [], "")
    @end
    return HttpResponse(st.hs_status_code, st.hs_status_text, st.hs_version, st.hs_headers, "")
  @end

  tcp_stream_write(stream, req)
  rbuf = lipi_alloc(8192)
  @while st.hs_done == 0 && st.hs_aborted == 0
    n = sys_read(stream.tcp_fd, rbuf, 8192)
    @if n == (0 - 4) continue @end
    @if n <= 0 break @end
    _http_stream_feed(st, rbuf, n, on_chunk_fn)
  @end
  _http_stream_flush_compressed(st, on_chunk_fn)
  lipi_free_sized(rbuf, 8192)
  tcp_stream_close(stream)
  buf_free(st.hs_buf)
  return HttpResponse(st.hs_status_code, st.hs_status_text, st.hs_version, st.hs_headers, "")
@end

@fn http_post_stream(url, headers, body, on_chunk_fn) -> HttpResponse
  return http_request_stream("POST", url, headers, body, on_chunk_fn)
@end

@fn http_get_stream(url, headers, on_chunk_fn) -> HttpResponse
  return http_request_stream("GET", url, headers, "", on_chunk_fn)
@end

@! ----------------------------------------------------------------------------
@! 8. HTTP Server Engine & Request Dispatcher
@! ----------------------------------------------------------------------------

@fn http_parse_request(raw_req: string) -> HttpRequest
  method = "GET"
  path = "/"
  version = "HTTP/1.1"
  headers = []
  body = ""

  raw_len = str_len(raw_req)
  @if raw_len == 0
    return HttpRequest(method, path, version, headers, body)
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
          headers = headers.push(HttpHeader(h_name, h_val))
        @end
      @end
    @end
  @end

  @! Decode Transfer-Encoding: chunked request bodies transparently
  te_val = _http_find_header_value(headers, "transfer-encoding")
  @if te_val != "" && contains(str_to_lower(te_val), "chunked") == 1
    body = http_decode_chunked(body)
  @end

  return HttpRequest(method, path, version, headers, body)
@end

@fn _http_read_full_request(stream: TcpStream)
  // WHY: O(N) ByteBuffer request reader supporting arbitrary body sizes and chunked requests.
  acc = buf_new(4096)
  rbuf = lipi_alloc(8192)
  header_end = -1
  sep_len = 4
  req_clen = -1
  is_chunked = 0
  @while 1 == 1
    nr = sys_read(stream.tcp_fd, rbuf, 8192)
    @if nr == (0 - 4) continue @end
    @if nr <= 0 break @end
    buf_write_mem(acc, rbuf, nr)
    @if header_end < 0
      header_end = _http_buf_find_hdr_end(acc)
      sep_len = 4
      @if header_end < 0
        p0 = buf_ptr(acc)
        n0 = buf_len(acc)
        k = 0
        @while k + 1 < n0
          @if (mem_byte_read(p0, k) & 255) == 10 && (mem_byte_read(p0, k + 1) & 255) == 10
            header_end = k
            sep_len = 2
            break
          @end
          k = k + 1
        @end
      @end
      @if header_end >= 0
        hdr_s = bytes_to_str(buf_ptr(acc), header_end + sep_len)
        req_head = http_parse_request(hdr_s)
        te_v = _http_find_header_value(req_head.headers, "transfer-encoding")
        @if te_v != "" && contains(str_to_lower(te_v), "chunked") == 1
          is_chunked = 1
        @else
          cl_val = _http_find_header_value(req_head.headers, "content-length")
          @if cl_val != ""
            req_clen = parse_int_str(cl_val)
          @else
            req_clen = 0
          @end
        @end
      @end
    @end
    @if header_end >= 0
      body_off = header_end + sep_len
      have_body = buf_len(acc) - body_off
      @if is_chunked == 1
        body_tail = bytes_to_str(buf_ptr(acc) + body_off, have_body)
        @if contains(body_tail, "\r\n0\r\n\r\n") == 1 || starts_with(body_tail, "0\r\n\r\n") == 1
          break
        @end
      @elif req_clen >= 0 && have_body >= req_clen
        break
      @end
    @end
  @end
  lipi_free_sized(rbuf, 8192)
  raw_req = buf_to_str(acc)
  buf_free(acc)
  return raw_req
@end

@fn http_server_listen(host, port, handler_fn)
  listener = tcp_listener_bind(host, port)
  @if listener.tcpl_fd < 0
    println("HTTP Server failed to bind on " + host + ":" + port.to_str())
    return -1
  @end

  // WHY: Sovereign startup banner for native LiPi HTTP server
  println("🚀 LiPi HTTP Server listening on http://" + host + ":" + port.to_str())

  @while 1 == 1
    stream = tcp_listener_accept(listener)
    @if stream.tcp_fd >= 0
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

  tcp_close(listener.tcpl_fd)
  return 0
@end
