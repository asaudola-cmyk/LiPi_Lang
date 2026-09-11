@! ============================================================================
@! MAYA UNIVERSE WEB — FAST PREFIX TRIE ROUTER (universe/web/router.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Supports Static Segments, :param Variables, *wildcard Catch-Alls,
@! HTTP Method Dispatch, 404 Not Found, 405 Method Not Allowed with Allow Header,
@! and Composable Route Grouping
@! ============================================================================

import "universe/core/string"
import "universe/web/url"

@! ----------------------------------------------------------------------------
@! 1. Constants & Discriminators
@! ----------------------------------------------------------------------------

@fn NODE_STATIC() return 0 @end
@fn NODE_PARAM() return 1 @end
@fn NODE_WILDCARD() return 2 @end

@struct RouteParamItem
  param_key: ""
  param_value: ""
@end

@struct RouteHandlerItem
  method: ""
  handler_id: 0
@end

@struct LookupChildResult
  found: 0
  child: 0
  index: 0
@end

@struct RouteMatch
  matched: 0
  status_code: 404
  handler_index: 0
  params: 0
  allowed_methods: ""
@end

@struct TrieNode
  segment: ""
  node_type: 0
  param_name: ""
  node_handlers: 0
  node_children: 0
@end

@struct Router
  root: 0
@end

@struct RouteGroup
  group_router: 0
  group_prefix: ""
@end

@! ----------------------------------------------------------------------------
@! 2. Node & Router Construction
@! ----------------------------------------------------------------------------

@fn trie_node_new(segment, node_type, param_name)
  return {
    segment: segment,
    node_type: node_type,
    param_name: param_name,
    node_handlers: [],
    node_children: []
  }
@end

@fn router_new()
  root = trie_node_new("", NODE_STATIC(), "")
  return { root: root }
@end

@! Splits path into sanitized segments, discarding redundant/trailing slashes
@fn path_split_segments(path)
  segments = []
  plen = path.len()
  pos = 0
  @while pos < plen
    @while pos < plen && str_char_at(path, pos) == 47 @! '/'
      pos = pos + 1
    @end
    @if pos >= plen
      break
    @end
    next_slash = pos
    @while next_slash < plen && str_char_at(path, next_slash) != 47 @! '/'
      next_slash = next_slash + 1
    @end
    seg = str_substr(path, pos, next_slash)
    segments = segments.push(seg)
    pos = next_slash
  @end
  return segments
@end

@fn node_find_child(node, segment, node_type)
  i = 0
  clen = node.node_children.len()
  @while i < clen
    child = node.node_children[i]
    @if child.node_type == node_type && child.segment == segment
      return { found: 1, child: child, index: i }
    @end
    i = i + 1
  @end
  return { found: 0, child: 0, index: -1 }
@end

@! Inserts child into node.node_children maintaining priority order: STATIC < PARAM < WILDCARD
@fn node_add_child_sorted(parent, new_child)
  new_children = []
  inserted = 0
  i = 0
  clen = parent.node_children.len()
  @while i < clen
    c = parent.node_children[i]
    @if inserted == 0 && new_child.node_type < c.node_type
      new_children = new_children.push(new_child)
      inserted = 1
    @end
    new_children = new_children.push(c)
    i = i + 1
  @end
  @if inserted == 0
    new_children = new_children.push(new_child)
  @end
  parent.node_children = new_children
@end

@! ----------------------------------------------------------------------------
@! 3. Route Registration (`router_add`)
@! ----------------------------------------------------------------------------

@fn router_add(router, method, path, handler_id)
  norm_method = str_to_upper(str_trim(method))
  segments = path_split_segments(path)
  curr = router.root

  i = 0
  slen = segments.len()
  @while i < slen
    seg = segments[i]
    node_type = NODE_STATIC()
    param_name = ""

    @if starts_with(seg, ":") == 1
      node_type = NODE_PARAM()
      param_name = str_substr(seg, 1, seg.len())
    @elif starts_with(seg, "*") == 1
      node_type = NODE_WILDCARD()
      param_name = str_substr(seg, 1, seg.len())
    @end

    lookup = node_find_child(curr, seg, node_type)
    child = 0
    @if lookup.found == 1
      child = lookup.child
    @else
      child = trie_node_new(seg, node_type, param_name)
      node_add_child_sorted(curr, child)
    @end

    curr = child
    @if node_type == NODE_WILDCARD()
      i = slen @! Wildcard consumes rest of route pattern
    @end
    i = i + 1
  @end

  new_handlers = []
  found_method = 0
  h_idx = 0
  hlen = curr.node_handlers.len()
  @while h_idx < hlen
    h = curr.node_handlers[h_idx]
    @if h.method == norm_method
      new_handlers = new_handlers.push({ method: norm_method, handler_id: handler_id })
      found_method = 1
    @else
      new_handlers = new_handlers.push(h)
    @end
    h_idx = h_idx + 1
  @end

  @if found_method == 0
    new_handlers = new_handlers.push({ method: norm_method, handler_id: handler_id })
  @end

  curr.node_handlers = new_handlers
@end

@! ----------------------------------------------------------------------------
@! 4. Route Matching (`router_match`)
@! ----------------------------------------------------------------------------

@fn format_allowed_methods(handlers)
  allowed = ""
  i = 0
  hlen = handlers.len()
  @while i < hlen
    h = handlers[i]
    @if allowed == ""
      allowed = h.method
    @else
      allowed = allowed + ", " + h.method
    @end
    i = i + 1
  @end
  return allowed
@end

@fn match_handler_in_node(node, method, params)
  allowed_str = format_allowed_methods(node.node_handlers)
  i = 0
  hlen = node.node_handlers.len()
  @while i < hlen
    h = node.node_handlers[i]
    @if h.method == method
      return {
        matched: 1,
        status_code: 200,
        handler_index: h.handler_id,
        params: params,
        allowed_methods: allowed_str
      }
    @end
    i = i + 1
  @end

  @if hlen > 0
    return {
      matched: 0,
      status_code: 405,
      handler_index: 0,
      params: params,
      allowed_methods: allowed_str
    }
  @end

  return {
    matched: 0,
    status_code: 404,
    handler_index: 0,
    params: [],
    allowed_methods: ""
  }
@end

@fn match_recursive(node, segments, seg_idx, current_params, method)
  slen = segments.len()
  @if seg_idx == slen
    res = match_handler_in_node(node, method, current_params)
    @if res.status_code == 200 || res.status_code == 405
      return res
    @end

    c_idx = 0
    clen = node.node_children.len()
    @while c_idx < clen
      child = node.node_children[c_idx]
      @if child.node_type == NODE_WILDCARD()
        new_params = current_params.push({ param_key: child.param_name, param_value: "" })
        return match_handler_in_node(child, method, new_params)
      @end
      c_idx = c_idx + 1
    @end

    return res
  @end

  curr_seg = segments[seg_idx]
  fallback_405_found = 0
  fallback_405_match = { matched: 0, status_code: 405, handler_index: 0, params: [], allowed_methods: "" }

  c_idx = 0
  clen = node.node_children.len()
  @while c_idx < clen
    child = node.node_children[c_idx]

    @if child.node_type == NODE_STATIC()
      @if child.segment == curr_seg
        res = match_recursive(child, segments, seg_idx + 1, current_params, method)
        @if res.status_code == 200
          return res
        @elif res.status_code == 405 && fallback_405_found == 0
          fallback_405_found = 1
          fallback_405_match = res
        @end
      @end
    @elif child.node_type == NODE_PARAM()
      param_val = url_decode(curr_seg)
      new_params = current_params.push({ param_key: child.param_name, param_value: param_val })
      res = match_recursive(child, segments, seg_idx + 1, new_params, method)
      @if res.status_code == 200
        return res
      @elif res.status_code == 405 && fallback_405_found == 0
        fallback_405_found = 1
        fallback_405_match = res
      @end
    @elif child.node_type == NODE_WILDCARD()
      wildcard_path = ""
      w_i = seg_idx
      @while w_i < slen
        @if wildcard_path == ""
          wildcard_path = segments[w_i]
        @else
          wildcard_path = wildcard_path + "/" + segments[w_i]
        @end
        w_i = w_i + 1
      @end
      param_val = url_decode(wildcard_path)
      new_params = current_params.push({ param_key: child.param_name, param_value: param_val })
      res = match_handler_in_node(child, method, new_params)
      @if res.status_code == 200
        return res
      @elif res.status_code == 405 && fallback_405_found == 0
        fallback_405_found = 1
        fallback_405_match = res
      @end
    @end

    c_idx = c_idx + 1
  @end

  @if fallback_405_found == 1
    return fallback_405_match
  @end

  return {
    matched: 0,
    status_code: 404,
    handler_index: 0,
    params: [],
    allowed_methods: ""
  }
@end

@fn router_match(router, method, path)
  norm_method = str_to_upper(str_trim(method))
  q_idx = str_index_of(path, "?")
  raw_path = path
  @if q_idx >= 0
    raw_path = str_substr(path, 0, q_idx)
  @end

  segments = path_split_segments(raw_path)
  return match_recursive(router.root, segments, 0, [], norm_method)
@end

@fn router_param_get(params, name, default_val)
  i = 0
  plen = params.len()
  @while i < plen
    p = params[i]
    @if p.param_key == name
      return p.param_value
    @end
    i = i + 1
  @end
  return default_val
@end

@! ----------------------------------------------------------------------------
@! 5. Route Grouping DSL
@! ----------------------------------------------------------------------------

@fn router_group(router, prefix)
  norm_prefix = prefix
  @if starts_with(norm_prefix, "/") == 0
    norm_prefix = "/" + norm_prefix
  @end
  @if ends_with(norm_prefix, "/") == 1 && norm_prefix.len() > 1
    norm_prefix = str_substr(norm_prefix, 0, norm_prefix.len() - 1)
  @end
  return { group_router: router, group_prefix: norm_prefix }
@end

@fn group_add(group, method, subpath, handler_id)
  full_path = group.group_prefix
  @if starts_with(subpath, "/") == 1
    full_path = full_path + subpath
  @else
    full_path = full_path + "/" + subpath
  @end
  router_add(group.group_router, method, full_path, handler_id)
@end

@fn group_get(group, subpath, handler_id) return group_add(group, "GET", subpath, handler_id) @end
@fn group_post(group, subpath, handler_id) return group_add(group, "POST", subpath, handler_id) @end
@fn group_put(group, subpath, handler_id) return group_add(group, "PUT", subpath, handler_id) @end
@fn group_delete(group, subpath, handler_id) return group_add(group, "DELETE", subpath, handler_id) @end
@fn group_patch(group, subpath, handler_id) return group_add(group, "PATCH", subpath, handler_id) @end
@fn group_options(group, subpath, handler_id) return group_add(group, "OPTIONS", subpath, handler_id) @end
@fn group_head(group, subpath, handler_id) return group_add(group, "HEAD", subpath, handler_id) @end
