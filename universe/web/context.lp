@! ============================================================================
@! LIPI UNIVERSE WEB — HTTP CONTEXT, REQUEST & RESPONSE (universe/web/context.lp)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! RFC 7230 / RFC 7231 Compliant Request / Response / Context Engine
@! ============================================================================

import "universe/core/string"
import "universe/core/json"
import "universe/web/url"
import "universe/web/router"

@! ----------------------------------------------------------------------------
@! 1. HTTP Status Codes & Reason Phrase Resolver
@! ----------------------------------------------------------------------------

@fn http_status_reason(status_code)
  @if status_code == 100 return "Continue" @end
  @if status_code == 101 return "Switching Protocols" @end
  @if status_code == 200 return "OK" @end
  @if status_code == 201 return "Created" @end
  @if status_code == 202 return "Accepted" @end
  @if status_code == 204 return "No Content" @end
  @if status_code == 301 return "Moved Permanently" @end
  @if status_code == 302 return "Found" @end
  @if status_code == 304 return "Not Modified" @end
  @if status_code == 307 return "Temporary Redirect" @end
  @if status_code == 308 return "Permanent Redirect" @end
  @if status_code == 400 return "Bad Request" @end
  @if status_code == 401 return "Unauthorized" @end
  @if status_code == 403 return "Forbidden" @end
  @if status_code == 404 return "Not Found" @end
  @if status_code == 405 return "Method Not Allowed" @end
  @if status_code == 408 return "Request Timeout" @end
  @if status_code == 409 return "Conflict" @end
  @if status_code == 413 return "Payload Too Large" @end
  @if status_code == 415 return "Unsupported Media Type" @end
  @if status_code == 418 return "I'm a teapot" @end
  @if status_code == 422 return "Unprocessable Entity" @end
  @if status_code == 429 return "Too Many Requests" @end
  @if status_code == 500 return "Internal Server Error" @end
  @if status_code == 501 return "Not Implemented" @end
  @if status_code == 502 return "Bad Gateway" @end
  @if status_code == 503 return "Service Unavailable" @end
  @if status_code == 504 return "Gateway Timeout" @end
  @if status_code >= 200 && status_code < 300 return "OK" @end
  @if status_code >= 300 && status_code < 400 return "Redirect" @end
  @if status_code >= 400 && status_code < 500 return "Client Error" @end
  @if status_code >= 500 && status_code < 600 return "Server Error" @end
  return "OK"
@end

@! ----------------------------------------------------------------------------
@! 2. Data Structures (Domain-Prefixed Unambiguous Field Names)
@! ----------------------------------------------------------------------------

@struct HttpHeader
  name: string
  value: string
@end

@struct HttpRequest
  req_method: string
  req_path: string
  req_query_string: string
  req_query_params: array
  req_path_params: array
  req_headers: array
  req_body: string
  req_client_ip: string
  req_json_body: any
@end

@struct HttpResponse
  res_status_code: i64
  res_status_text: string
  res_headers: array
  res_body: string
  res_content_type: string
  res_aborted: i64
@end

@struct ContextStoreItem
  store_key: string
  store_val: any
@end

@struct HttpContext
  ctx_req: any
  ctx_res: any
  ctx_handlers: array
  ctx_handler_idx: i64
  ctx_store: array
  ctx_is_aborted: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Web JSON Parser Helper
@! ----------------------------------------------------------------------------

@fn web_json_parse(raw_str)
  pairs = []
  num_items = str_len(raw_str)
  i = 0
  @while i < num_items
    ch = str_char_at(raw_str, i)
    @if ch == 34 @! '"'
      k_start = i + 1
      j = k_start
      @while j < num_items && str_char_at(raw_str, j) != 34
        j = j + 1
      @end
      key = str_substr(raw_str, k_start, j)
      i = j + 1
      @while i < num_items && (str_char_at(raw_str, i) == 32 || str_char_at(raw_str, i) == 58 || str_char_at(raw_str, i) == 9 || str_char_at(raw_str, i) == 10 || str_char_at(raw_str, i) == 13)
        i = i + 1
      @end
      @if i < num_items
        v_ch = str_char_at(raw_str, i)
        @if v_ch == 34 @! string
          v_start = i + 1
          v_end = v_start
          @while v_end < num_items && str_char_at(raw_str, v_end) != 34
            v_end = v_end + 1
          @end
          val_str = str_substr(raw_str, v_start, v_end)
          pairs = pairs.push({ key: key, value: val_str })
          i = v_end + 1
        @elif (v_ch >= 48 && v_ch <= 57) || v_ch == 45 @! number
          v_start = i
          v_end = v_start
          @while v_end < num_items && ((str_char_at(raw_str, v_end) >= 48 && str_char_at(raw_str, v_end) <= 57) || str_char_at(raw_str, v_end) == 46 || str_char_at(raw_str, v_end) == 45)
            v_end = v_end + 1
          @end
          val_num = str_substr(raw_str, v_start, v_end)
          pairs = pairs.push({ key: key, value: val_num })
          i = v_end
        @elif v_ch == 116 @! 't' (true)
          pairs = pairs.push({ key: key, value: "true" })
          i = i + 4
        @elif v_ch == 102 @! 'f' (false)
          pairs = pairs.push({ key: key, value: "false" })
          i = i + 5
        @elif v_ch == 110 @! 'n' (null)
          pairs = pairs.push({ key: key, value: "" })
          i = i + 4
        @else
          i = i + 1
        @end
      @end
    @else
      i = i + 1
    @end
  @end
  return pairs
@end

@! ----------------------------------------------------------------------------
@! 4. HttpRequest API & Constructors
@! ----------------------------------------------------------------------------

@fn http_request_new(method, path, headers, query, params, body, client_ip)
  @if client_ip == "" client_ip = "127.0.0.1" @end
  q_idx = str_index_of(path, "?")
  clean_path = path
  q_str = ""
  @if q_idx >= 0
    clean_path = str_substr(path, 0, q_idx)
    q_str = str_substr(path, q_idx + 1, str_len(path))
  @end

  q_pairs = query
  @if q_pairs.len() == 0
    @if str_len(q_str) > 0
      q_pairs = url_parse_query(q_str)
    @else
      q_pairs = []
    @end
  @end

  return {
    req_method: str_to_upper(str_trim(method)),
    req_path: clean_path,
    req_query_string: q_str,
    req_query_params: q_pairs,
    req_path_params: params,
    req_headers: headers,
    req_body: body,
    req_client_ip: client_ip,
    req_json_body: []
  }
@end

@fn req_new(method, path, headers, body, client_ip)
  return http_request_new(method, path, headers, [], [], body, client_ip)
@end

@fn req_get_header(req, name, default_val)
  target = str_to_lower(str_trim(name))
  i = 0
  num_items = req.req_headers.len()
  @while i < num_items
    h = req.req_headers[i]
    @if str_to_lower(h.name) == target
      return h.value
    @end
    i = i + 1
  @end
  return default_val
@end

@fn req_header(req, name, default_val)
  return req_get_header(req, name, default_val)
@end

@fn req_query(req, name, default_val)
  return url_query_get(req.req_query_params, name, default_val)
@end

@fn req_query_all(req, name)
  return url_query_get_all(req.req_query_params, name)
@end

@fn req_has_query(req, name)
  return url_query_has(req.req_query_params, name)
@end

@fn req_param(req, name, default_val)
  return router_param_get(req.req_path_params, name, default_val)
@end

@fn req_has_param(req, name)
  val = router_param_get(req.req_path_params, name, "")
  @if val != "" return 1 @end
  return 0
@end

@fn req_json(req)
  @if req.req_json_body.len() > 0
    return req.req_json_body
  @end
  @if str_len(req.req_body) > 0
    req.req_json_body = web_json_parse(req.req_body)
  @end
  return req.req_json_body
@end

@fn req_json_get(req, key, default_val)
  parsed = req_json(req)
  @if parsed.len() == 0 return default_val @end
  i = 0
  num_items = parsed.len()
  @while i < num_items
    p = parsed[i]
    @if p.key == key
      return p.value
    @end
    i = i + 1
  @end
  return default_val
@end

@fn req_content_type(req)
  return req_get_header(req, "Content-Type", "")
@end

@fn req_is_json(req)
  ct = str_to_lower(req_content_type(req))
  return contains(ct, "application/json")
@end

@! ----------------------------------------------------------------------------
@! 5. HttpResponse API & Fluent Builders
@! ----------------------------------------------------------------------------

@fn http_response_new()
  return {
    res_status_code: 200,
    res_status_text: "OK",
    res_headers: [],
    res_body: "",
    res_content_type: "text/plain; charset=utf-8",
    res_aborted: 0
  }
@end

@fn res_new()
  return http_response_new()
@end

@fn res_status(res, code)
  res.res_status_code = code
  res.res_status_text = http_status_reason(code)
  return res
@end

@fn res_header(res, name, value)
  new_headers = []
  target = str_to_lower(str_trim(name))
  found = 0
  i = 0
  num_items = res.res_headers.len()
  @while i < num_items
    h = res.res_headers[i]
    @if str_to_lower(h.name) == target
      new_headers = new_headers.push({ name: name, value: value })
      found = 1
    @else
      new_headers = new_headers.push(h)
    @end
    i = i + 1
  @end
  @if found == 0
    new_headers = new_headers.push({ name: name, value: value })
  @end
  res.res_headers = new_headers
  @if target == "content-type"
    res.res_content_type = value
  @end
  return res
@end

@fn res_get_header(res, name, default_val)
  target = str_to_lower(str_trim(name))
  i = 0
  num_items = res.res_headers.len()
  @while i < num_items
    h = res.res_headers[i]
    @if str_to_lower(h.name) == target
      return h.value
    @end
    i = i + 1
  @end
  return default_val
@end

@fn res_text(res, text_content)
  @if res.res_status_code == 0 res.res_status_code = 200 @end
  res.res_body = text_content
  res.res_content_type = "text/plain; charset=utf-8"
  res_header(res, "Content-Type", res.res_content_type)
  return res
@end

@fn res_json(res, json_content)
  @if res.res_status_code == 0 res.res_status_code = 200 @end
  @if json_content == "" || json_content.len() == 0
    res.res_body = "{}"
  @else
    res.res_body = json_content
  @end
  res.res_content_type = "application/json; charset=utf-8"
  res_header(res, "Content-Type", res.res_content_type)
  return res
@end

@fn res_html(res, html_content)
  @if res.res_status_code == 0 res.res_status_code = 200 @end
  res.res_body = html_content
  res.res_content_type = "text/html; charset=utf-8"
  res_header(res, "Content-Type", res.res_content_type)
  return res
@end

@fn res_redirect(res, location_url, code)
  @if code == 0 code = 302 @end
  res_status(res, code)
  res_header(res, "Location", location_url)
  res.res_body = ""
  return res
@end

@fn res_send(res, body_content)
  @if res.res_status_code == 0 res.res_status_code = 200 @end
  res.res_body = body_content
  return res
@end

@fn res_cookie(res, name, value, max_age, path, http_only, secure)
  cookie_str = name + "=" + value
  @if path != ""
    cookie_str = cookie_str + "; Path=" + path
  @else
    cookie_str = cookie_str + "; Path=/"
  @end
  @if max_age > 0
    cookie_str = cookie_str + "; Max-Age=" + max_age.to_str()
  @end
  @if http_only == 1
    cookie_str = cookie_str + "; HttpOnly"
  @end
  @if secure == 1
    cookie_str = cookie_str + "; Secure"
  @end
  cookie_str = cookie_str + "; SameSite=Lax"
  return res_header(res, "Set-Cookie", cookie_str)
@end

@! ----------------------------------------------------------------------------
@! 6. Response Wire Serialization (RFC 7230 Wire Format)
@! ----------------------------------------------------------------------------

@fn res_format_http(res)
  reason = http_status_reason(res.res_status_code)
  status_line = "HTTP/1.1 " + res.res_status_code.to_str() + " " + reason + "\r\n"

  has_ct = 0
  has_cl = 0
  has_conn = 0
  has_server = 0

  headers_block = ""
  i = 0
  num_items = res.res_headers.len()
  @while i < num_items
    h = res.res_headers[i]
    h_lower = str_to_lower(h.name)
    @if h_lower == "content-type" has_ct = 1 @end
    @if h_lower == "content-length" has_cl = 1 @end
    @if h_lower == "connection" has_conn = 1 @end
    @if h_lower == "server" has_server = 1 @end
    headers_block = headers_block + h.name + ": " + h.value + "\r\n"
    i = i + 1
  @end

  @if has_server == 0
    headers_block = headers_block + "Server: Maya-Pure-Web/1.0\r\n"
  @end
  @if has_ct == 0 && res.res_content_type != ""
    headers_block = headers_block + "Content-Type: " + res.res_content_type + "\r\n"
  @end
  @if has_cl == 0
    headers_block = headers_block + "Content-Length: " + res.res_body.len().to_str() + "\r\n"
  @end
  @if has_conn == 0
    headers_block = headers_block + "Connection: close\r\n"
  @end

  return status_line + headers_block + "\r\n" + res.res_body
@end

@fn http_response_to_wire(res)
  return res_format_http(res)
@end

@! ----------------------------------------------------------------------------
@! 7. HttpContext API
@! ----------------------------------------------------------------------------

@fn http_context_new(req, res)
  return {
    ctx_req: req,
    ctx_res: res,
    ctx_handlers: [],
    ctx_handler_index: 0,
    ctx_is_aborted: 0,
    ctx_store: [],
    ctx_app: 0
  }
@end

@fn ctx_abort(ctx)
  ctx.ctx_is_aborted = 1
  ctx.ctx_res.res_aborted = 1
  return ctx
@end

@fn ctx_abort_with_status(ctx, code, body)
  res_status(ctx.ctx_res, code)
  res_send(ctx.ctx_res, body)
  ctx_abort(ctx)
  return ctx
@end

@fn ctx_abort_with_json(ctx, code, json_val)
  res_status(ctx.ctx_res, code)
  res_json(ctx.ctx_res, json_val)
  ctx_abort(ctx)
  return ctx
@end

@fn ctx_set(ctx, key, val)
  new_store = []
  found = 0
  i = 0
  num_items = ctx.ctx_store.len()
  @while i < num_items
    item = ctx.ctx_store[i]
    @if item.store_key == key
      new_store = new_store.push({ store_key: key, store_val: val })
      found = 1
    @else
      new_store = new_store.push(item)
    @end
    i = i + 1
  @end
  @if found == 0
    new_store = new_store.push({ store_key: key, store_val: val })
  @end
  ctx.ctx_store = new_store
  return ctx
@end

@fn ctx_get(ctx, key, default_val)
  i = 0
  num_items = ctx.ctx_store.len()
  @while i < num_items
    item = ctx.ctx_store[i]
    @if item.store_key == key
      return item.store_val
    @end
    i = i + 1
  @end
  return default_val
@end

@fn ctx_has(ctx, key)
  i = 0
  num_items = ctx.ctx_store.len()
  @while i < num_items
    item = ctx.ctx_store[i]
    @if item.store_key == key
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn ctx_status(ctx, code)
  res_status(ctx.ctx_res, code)
  return ctx
@end

@fn ctx_header(ctx, name, val)
  res_header(ctx.ctx_res, name, val)
  return ctx
@end

@fn ctx_text(ctx, status_code, text_content)
  res_status(ctx.ctx_res, status_code)
  res_text(ctx.ctx_res, text_content)
  return ctx
@end

@fn ctx_json(ctx, status_code, json_content)
  res_status(ctx.ctx_res, status_code)
  res_json(ctx.ctx_res, json_content)
  return ctx
@end

@fn ctx_html(ctx, status_code, html_content)
  res_status(ctx.ctx_res, status_code)
  res_html(ctx.ctx_res, html_content)
  return ctx
@end

@fn ctx_redirect(ctx, url, code)
  res_redirect(ctx.ctx_res, url, code)
  return ctx
@end

@fn ctx_param(ctx, name, default_val)
  return req_param(ctx.ctx_req, name, default_val)
@end

@fn ctx_query(ctx, name, default_val)
  return req_query(ctx.ctx_req, name, default_val)
@end

@fn ctx_get_header(ctx, name, default_val)
  return req_get_header(ctx.ctx_req, name, default_val)
@end

@fn ctx_json_body(ctx)
  return req_json(ctx.ctx_req)
@end

@fn ctx_json_get(ctx, key, default_val)
  return req_json_get(ctx.ctx_req, key, default_val)
@end
