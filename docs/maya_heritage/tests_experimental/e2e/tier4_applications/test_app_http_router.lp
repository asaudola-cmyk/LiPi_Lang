@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: HTTP REST FRAMEWORK & TRIE ROUTER
@! File: tests/e2e/tier4_applications/test_app_http_router.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct ParamEntry
  key: ""
  val: ""
@end

@struct HandlerEntry
  method: ""
  handler_id: 0
@end

@struct RouteNode
  segment: ""
  node_type: 0   @! 0=Static, 1=Param, 2=Wildcard
  param_name: ""
  handlers: 0
  children: 0
@end

@struct RouteMatch
  status: 0      @! 200, 404, 405
  handler_id: 0
  allow_header: ""
  params: 0
@end

@fn node_new(seg, n_type, p_name)
  return {
    segment: seg,
    node_type: n_type,
    param_name: p_name,
    handlers: [],
    children: []
  }
@end

@fn split_path(path)
  segs = []
  len = str_len(path)
  pos = 0
  @while pos < len
    @while pos < len && char_at(path, pos) == char_code("/")
      pos = pos + 1
    @end
    @if pos >= len
      break
    @end
    next_slash = pos
    @while next_slash < len && char_at(path, next_slash) != char_code("/")
      next_slash = next_slash + 1
    @end
    s = str_substr(path, pos, next_slash)
    segs.push(s)
    pos = next_slash
  @end
  return segs
@end

@fn add_route(root, method, path, handler_id)
  segs = split_path(path)
  curr = root
  i = 0
  slen = segs.len()

  @while i < slen
    seg = segs[i]
    n_type = 0
    p_name = ""

    @if string_starts_with(seg, ":") == 1
      n_type = 1  @! Param
      p_name = str_substr(seg, 1, str_len(seg))
    @elif string_starts_with(seg, "*") == 1
      n_type = 2  @! Wildcard
      p_name = str_substr(seg, 1, str_len(seg))
    @end

    @! Search matching child
    found_child = 0
    c_idx = 0
    ch_len = curr.children.len()
    @while c_idx < ch_len
      child = curr.children[c_idx]
      @if n_type == 0 && child.node_type == 0 && child.segment == seg
        found_child = child
        break
      @elif n_type == 1 && child.node_type == 1
        found_child = child
        break
      @elif n_type == 2 && child.node_type == 2
        found_child = child
        break
      @end
      c_idx = c_idx + 1
    @end

    @if found_child == 0
      new_child = node_new(seg, n_type, p_name)
      curr.children.push(new_child)
      curr = new_child
    @else
      curr = found_child
    @end

    @if n_type == 2  @! Wildcard consumes rest of path
      break
    @end

    i = i + 1
  @end

  curr.handlers.push({ method: method, handler_id: handler_id })
  return root
@end

@fn lookup_route(root, method, path)
  segs = split_path(path)
  curr = root
  extracted_params = []
  i = 0
  slen = segs.len()

  @while i < slen
    seg = segs[i]
    next_node = 0

    @! 1. Try exact static match first
    c = 0
    num_c = curr.children.len()
    @while c < num_c
      ch = curr.children[c]
      @if ch.node_type == 0 && ch.segment == seg
        next_node = ch
        break
      @end
      c = c + 1
    @end

    @! 2. Try param node if no static
    @if next_node == 0
      c = 0
      @while c < num_c
        ch = curr.children[c]
        @if ch.node_type == 1  @! Param
          next_node = ch
          extracted_params.push({ key: ch.param_name, val: seg })
          break
        @end
        c = c + 1
      @end
    @end

    @! 3. Try wildcard node if no param
    @if next_node == 0
      c = 0
      @while c < num_c
        ch = curr.children[c]
        @if ch.node_type == 2  @! Wildcard
          next_node = ch
          @! Wildcard captures remaining path from here
          rest_path = ""
          w_idx = i
          @while w_idx < slen
            @if w_idx > i
              rest_path = rest_path + "/"
            @end
            rest_path = rest_path + segs[w_idx]
            w_idx = w_idx + 1
          @end
          extracted_params.push({ key: ch.param_name, val: rest_path })
          i = slen  @! consume all
          break
        @end
        c = c + 1
      @end
    @end

    @if next_node == 0
      return { status: 404, handler_id: 0, allow_header: "", params: [] }
    @end

    curr = next_node
    i = i + 1
  @end

  @! Check handlers on matched node
  @if curr.handlers.len() == 0
    return { status: 404, handler_id: 0, allow_header: "", params: [] }
  @end

  allow_methods = ""
  h_idx = 0
  h_len = curr.handlers.len()
  matched_h = 0

  @while h_idx < h_len
    h = curr.handlers[h_idx]
    @if h_idx > 0
      allow_methods = allow_methods + ", "
    @end
    allow_methods = allow_methods + h.method

    @if h.method == method
      matched_h = h.handler_id
    @end
    h_idx = h_idx + 1
  @end

  @if matched_h != 0
    return { status: 200, handler_id: matched_h, allow_header: allow_methods, params: extracted_params }
  @else
    return { status: 405, handler_id: 0, allow_header: allow_methods, params: [] }
  @end
@end

@fn get_param(match_obj, key_name)
  i = 0
  len = match_obj.params.len()
  @while i < len
    @if match_obj.params[i].key == key_name
      return match_obj.params[i].val
    @end
    i = i + 1
  @end
  return ""
@end

@fn build_http_response(status_code, body, content_type)
  status_line = "HTTP/1.1 200 OK\r\n"
  @if status_code == 404
    status_line = "HTTP/1.1 404 Not Found\r\n"
  @elif status_code == 405
    status_line = "HTTP/1.1 405 Method Not Allowed\r\n"
  @end

  headers = status_line + "Content-Type: " + content_type + "\r\n" + "Content-Length: " + int_to_str(str_len(body)) + "\r\n\r\n"
  return headers + body
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 1: HTTP Web Framework & Prefix Trie Router")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  root = node_new("", 0, "")

  @! Register 10 routes:
  root = add_route(root, "GET", "/", 1)
  root = add_route(root, "GET", "/health", 2)
  root = add_route(root, "GET", "/api/v1/users", 3)
  root = add_route(root, "POST", "/api/v1/users", 4)
  root = add_route(root, "GET", "/api/v1/users/:id", 5)
  root = add_route(root, "PUT", "/api/v1/users/:id", 6)
  root = add_route(root, "DELETE", "/api/v1/users/:id", 7)
  root = add_route(root, "GET", "/api/v1/users/:id/posts/:post_id", 8)
  root = add_route(root, "GET", "/static/*filepath", 9)
  root = add_route(root, "POST", "/api/v1/auth/login", 10)

  @! T4.1.1: Static Route Dispatch (Root & Health)
  total = total + 1
  m_root = lookup_route(root, "GET", "/")
  m_health = lookup_route(root, "GET", "/health")

  @if m_root.status == 200 && m_root.handler_id == 1 && m_health.status == 200 && m_health.handler_id == 2
    passed = passed + 1
    println("  [PASS] T4.1.1: Static root ('/') and health ('/health') routes resolved to handlers 1 & 2")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.1: Static routes failed")
  @end

  @! T4.1.2: Single URL Param Extraction (/api/v1/users/:id)
  total = total + 1
  m_user = lookup_route(root, "GET", "/api/v1/users/42")
  user_id = get_param(m_user, "id")

  @if m_user.status == 200 && m_user.handler_id == 5 && user_id == "42"
    passed = passed + 1
    println("  [PASS] T4.1.2: Param extraction from /api/v1/users/42 (handler=5, id=\"42\")")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.2: User param route failed: id=" + user_id)
  @end

  @! T4.1.3: Multi-Param Nested Route (/api/v1/users/:id/posts/:post_id)
  total = total + 1
  m_post = lookup_route(root, "GET", "/api/v1/users/42/posts/101")
  u_id = get_param(m_post, "id")
  p_id = get_param(m_post, "post_id")

  @if m_post.status == 200 && m_post.handler_id == 8 && u_id == "42" && p_id == "101"
    passed = passed + 1
    println("  [PASS] T4.1.3: Multi-param nested route (handler=8, id=\"42\", post_id=\"101\")")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.3: Multi-param route failed")
  @end

  @! T4.1.4: Catch-All Wildcard Route (/static/*filepath)
  total = total + 1
  m_static = lookup_route(root, "GET", "/static/css/theme/dark.css")
  fp = get_param(m_static, "filepath")

  @if m_static.status == 200 && m_static.handler_id == 9 && fp == "css/theme/dark.css"
    passed = passed + 1
    println("  [PASS] T4.1.4: Wildcard route extracted entire subpath (filepath=\"css/theme/dark.css\")")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.4: Wildcard route failed: fp=" + fp)
  @end

  @! T4.1.5: 405 Method Not Allowed with Allow Header & 404 Not Found
  total = total + 1
  m_405 = lookup_route(root, "PATCH", "/api/v1/auth/login")
  m_404 = lookup_route(root, "GET", "/nonexistent/path")

  resp_200 = build_http_response(200, "{\"status\":\"ok\"}", "application/json")

  @if m_405.status == 405 && m_405.allow_header == "POST" && m_404.status == 404 && string_starts_with(resp_200, "HTTP/1.1 200 OK") == 1
    passed = passed + 1
    println("  [PASS] T4.1.5: 405 with 'Allow: POST', 404 rejection, and RFC 7230 response serializer")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1.5: Status codes/serializer verification failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 1 (HTTP Web Framework & Trie Router) PASSED")
    return 0
  @else
    println("✗ Scenario 1 (HTTP Web Framework & Trie Router) FAILED")
    return 1
  @end
@end
