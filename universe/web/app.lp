@! ============================================================================
@! LIPI UNIVERSE WEB — APPLICATION DEVELOPER API (universe/web/app.lp)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Application Container, Route Registration, Groups, Pipeline Dispatcher
@! ============================================================================

import "universe/web/url"
import "universe/web/router"
import "universe/web/context"
import "universe/web/middleware"
import "universe/net/http"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Data Structures
@! ----------------------------------------------------------------------------

@struct WebApp
  router: 0
  app_middlewares: 0
  app_handlers: 0
@end

@struct AppGroup
  group_app: 0
  group_prefix: ""
@end

@! ----------------------------------------------------------------------------
@! 2. Application Constructor & Middleware Registration
@! ----------------------------------------------------------------------------

@fn web_new()
  return {
    router: router_new(),
    app_middlewares: [],
    app_handlers: []
  }
@end

@fn web_app_create()
  // WHY: Canonical alias matching web_app_create convention
  return web_new()
@end

@fn লিপি_নতুন_অ্যাপ()
  return web_new()
@end

@fn app_use(app, mw_fn)
  app.app_middlewares = app.app_middlewares.push(mw_fn)
@end

@! ----------------------------------------------------------------------------
@! 3. Route Registration
@! ----------------------------------------------------------------------------

@fn app_register(app, method, path, handler_fn)
  h_idx = app.app_handlers.len()
  app.app_handlers = app.app_handlers.push(handler_fn)
  router_add(app.router, method, path, h_idx)
@end

@fn app_get(app, path, handler_fn)
  app_register(app, "GET", path, handler_fn)
@end

@fn app_post(app, path, handler_fn)
  app_register(app, "POST", path, handler_fn)
@end

@fn app_put(app, path, handler_fn)
  app_register(app, "PUT", path, handler_fn)
@end

@fn app_delete(app, path, handler_fn)
  app_register(app, "DELETE", path, handler_fn)
@end

@fn app_patch(app, path, handler_fn)
  app_register(app, "PATCH", path, handler_fn)
@end

@fn app_options(app, path, handler_fn)
  app_register(app, "OPTIONS", path, handler_fn)
@end

@fn app_head(app, path, handler_fn)
  app_register(app, "HEAD", path, handler_fn)
@end

@! ----------------------------------------------------------------------------
@! 4. Route Grouping DSL
@! ----------------------------------------------------------------------------

@fn app_group(app, prefix)
  p = prefix
  @if starts_with(p, "/") == 0 p = "/" + p @end
  @if ends_with(p, "/") == 1 && p.len() > 1
    p = str_substr(p, 0, p.len() - 1)
  @end
  return { group_app: app, group_prefix: p }
@end

@fn group_get(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_get(group.group_app, full, handler_fn)
@end

@fn group_post(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_post(group.group_app, full, handler_fn)
@end

@fn group_put(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_put(group.group_app, full, handler_fn)
@end

@fn group_delete(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_delete(group.group_app, full, handler_fn)
@end

@fn group_patch(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_patch(group.group_app, full, handler_fn)
@end

@fn group_options(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_options(group.group_app, full, handler_fn)
@end

@fn group_head(group, subpath, handler_fn)
  full = group.group_prefix
  @if starts_with(subpath, "/") == 1 full = full + subpath
  @else full = full + "/" + subpath @end
  app_head(group.group_app, full, handler_fn)
@end

@! ----------------------------------------------------------------------------
@! 5. Request Pipeline Dispatcher
@! ----------------------------------------------------------------------------

@fn app_route_dispatch_middleware(ctx)
  app = ctx.ctx_app
  @if app == 0
    return 0
  @end

  req = ctx.ctx_req
  res = ctx.ctx_res

  @! Route Matching
  m = router_match(app.router, req.req_method, req.req_path)
  @if m.status_code == 404
    res_status(res, 404)
    res_text(res, "404 Not Found")
    return 0
  @elif m.status_code == 405
    res_status(res, 405)
    res_header(res, "Allow", m.allowed_methods)
    res_text(res, "405 Method Not Allowed")
    return 0
  @end

  req.req_path_params = m.params

  @! Route Handler Execution
  h_idx = m.handler_index
  @if h_idx >= 0 && h_idx < app.app_handlers.len()
    handler_fn = app.app_handlers[h_idx]
    handler_fn(req, res)
  @else
    res_status(res, 500)
    res_text(res, "500 Internal Error: Invalid Handler Index")
  @end

  return 0
@end

@fn app_dispatch(app, req)
  res = res_new()

  handlers = []
  i = 0
  hlen = app.app_middlewares.len()
  @while i < hlen
    handlers = handlers.push(app.app_middlewares[i])
    i = i + 1
  @end
  handlers = handlers.push(app_route_dispatch_middleware)

  ctx = {
    ctx_req: req,
    ctx_res: res,
    ctx_handlers: handlers,
    ctx_handler_index: 0,
    ctx_is_aborted: 0,
    ctx_store: [],
    ctx_app: app
  }

  ctx_next(ctx)
  return res
@end

@fn app_handle_raw_request(app, raw_str)
  parsed = http_parse_request(raw_str)
  req = req_new(parsed.method, parsed.path, parsed.headers, parsed.body, "127.0.0.1")
  res = app_dispatch(app, req)
  return res_format_http(res)
@end
