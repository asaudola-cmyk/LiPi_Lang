@! ============================================================================
@! LIPI UNIVERSE WEB — ONION MIDDLEWARE PIPELINE (universe/web/middleware.lp)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Onion Chain, Logger, JSON Parser, CORS, Recovery, Static Server
@! ============================================================================

import "universe/web/context"
import "universe/core/string"
import "universe/core/json"
import "universe/os/syscalls"
import "universe/os/fs"

@! ----------------------------------------------------------------------------
@! 1. High-Resolution Monotonic Time Helper
@! ----------------------------------------------------------------------------

@struct TimeSpec
  sec: 0
  nsec: 0
@end

@fn get_monotonic_time_ms()
  ts = { sec: 0, nsec: 0 }
  res = sys_clock_gettime(1, ts)
  @if res != 0
    return 0
  @end
  return (ts.sec * 1000) + (ts.nsec / 1000000)
@end

@! ----------------------------------------------------------------------------
@! 2. Onion Middleware Execution Pipeline
@! ----------------------------------------------------------------------------

@fn ctx_next(ctx)
  @if ctx.ctx_is_aborted == 1
    return 0
  @end
  idx = ctx.ctx_handler_index
  @if idx < ctx.ctx_handlers.len()
    ctx.ctx_handler_index = idx + 1
    handler_fn = ctx.ctx_handlers[idx]
    handler_fn(ctx)
  @end
  return 0
@end

@fn pipeline_run(handlers, ctx)
  ctx.ctx_handlers = handlers
  ctx.ctx_handler_index = 0
  ctx.ctx_is_aborted = 0
  ctx_next(ctx)
  return ctx
@end

@! ----------------------------------------------------------------------------
@! 3. Built-in Standard Middlewares
@! ----------------------------------------------------------------------------

@! 3.1 Logger Middleware
@fn middleware_logger_handler(ctx)
  t_start = get_monotonic_time_ms()
  ctx_set(ctx, "__t_start", t_start.to_str())

  ctx_next(ctx)

  t_end = get_monotonic_time_ms()
  dur = t_end - t_start
  ctx_set(ctx, "__dur_ms", dur.to_str())
  println("[HTTP] " + ctx.ctx_req.req_method + " " + ctx.ctx_req.req_path + " -> " + ctx.ctx_res.res_status_code.to_str() + " " + ctx.ctx_res.res_status_text + " (" + dur.to_str() + "ms)")
  return 0
@end

@fn middleware_logger()
  return middleware_logger_handler
@end

@! 3.2 JSON Body Parser Middleware
@fn middleware_json_body_handler(ctx)
  @if req_is_json(ctx.ctx_req) == 1 && ctx.ctx_req.req_body.len() > 0
    req_json(ctx.ctx_req)
    ctx_set(ctx, "json_parsed", "1")
  @end
  ctx_next(ctx)
  return 0
@end

@fn middleware_json_body()
  return middleware_json_body_handler
@end

@! 3.3 CORS Middleware
@struct CorsConfig
  allow_origin: "*"
  allow_methods: "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD"
  allow_headers: "Origin, Content-Type, Accept, Authorization, X-Requested-With"
  expose_headers: ""
  allow_credentials: 0
  max_age: 86400
@end

@fn middleware_cors_handler(ctx)
  res_header(ctx.ctx_res, "Access-Control-Allow-Origin", "*")
  res_header(ctx.ctx_res, "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD")
  res_header(ctx.ctx_res, "Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, X-Requested-With")
  res_header(ctx.ctx_res, "Access-Control-Max-Age", "86400")

  @if ctx.ctx_req.req_method == "OPTIONS"
    res_status(ctx.ctx_res, 204)
    res_text(ctx.ctx_res, "")
    ctx_abort(ctx)
    return 0
  @end

  ctx_next(ctx)
  return 0
@end

@fn middleware_cors()
  return middleware_cors_handler
@end

@! 3.4 Error Recovery Middleware
@fn middleware_recovery_handler(ctx)
  ctx_set(ctx, "__recovered", "0")
  ctx_next(ctx)
  @if ctx.ctx_res.res_status_code == 0
    ctx_json(ctx, 500, "{\"error\":\"Internal Server Error\",\"status\":500,\"path\":\"" + ctx.ctx_req.req_path + "\"}")
    ctx_set(ctx, "__recovered", "1")
  @end
  return 0
@end

@fn middleware_recovery()
  return middleware_recovery_handler
@end

@! 3.5 MIME Resolver & Static File Server Middleware
@fn mime_type_lookup(ext)
  norm_ext = str_to_lower(ext)
  @if starts_with(norm_ext, ".") == 1
    norm_ext = str_substr(norm_ext, 1, norm_ext.len())
  @end
  @if norm_ext == "html" || norm_ext == "htm" return "text/html; charset=utf-8" @end
  @if norm_ext == "css" return "text/css; charset=utf-8" @end
  @if norm_ext == "js" || norm_ext == "mjs" return "application/javascript; charset=utf-8" @end
  @if norm_ext == "json" return "application/json; charset=utf-8" @end
  @if norm_ext == "png" return "image/png" @end
  @if norm_ext == "jpg" || norm_ext == "jpeg" return "image/jpeg" @end
  @if norm_ext == "gif" return "image/gif" @end
  @if norm_ext == "svg" return "image/svg+xml" @end
  @if norm_ext == "ico" return "image/x-icon" @end
  @if norm_ext == "webp" return "image/webp" @end
  @if norm_ext == "wasm" return "application/wasm" @end
  @if norm_ext == "pdf" return "application/pdf" @end
  @if norm_ext == "txt" || norm_ext == "maya" return "text/plain; charset=utf-8" @end
  return "application/octet-stream"
@end

@fn mw_static_serve_run(root_dir, prefix, ctx)
  req_path = ctx.ctx_req.req_path
  @if starts_with(req_path, prefix) == 0
    ctx_next(ctx)
    return ctx
  @end

  rel_path = str_substr(req_path, prefix.len(), req_path.len())
  @if starts_with(rel_path, "/") == 0
    rel_path = "/" + rel_path
  @end

  @! Security check: directory traversal defense
  @if contains(rel_path, "..") == 1
    ctx_text(ctx, 403, "403 Forbidden: Invalid file path")
    ctx_abort(ctx)
    return ctx
  @end

  full_path = path_join(root_dir, rel_path)
  st = fs_stat(full_path)
  @if st.is_dir == 1
    index_path = path_join(full_path, "index.html")
    @if fs_exists(index_path) == 1
      full_path = index_path
      st = fs_stat(full_path)
    @end
  @end

  @if st.is_file == 1
    content = fs_read_file(full_path)
    ext = path_extension(full_path)
    mime = mime_type_lookup(ext)
    res_status(ctx.ctx_res, 200)
    res_header(ctx.ctx_res, "Content-Type", mime)
    res_send(ctx.ctx_res, content)
    ctx_abort(ctx)
    return ctx
  @end

  ctx_next(ctx)
  return ctx
@end

@fn middleware_static_handler(ctx)
  root_dir = ctx_get(ctx, "static_root_dir", "./public")
  prefix = ctx_get(ctx, "static_prefix", "/static")
  return mw_static_serve_run(root_dir, prefix, ctx)
@end

@fn middleware_static(root_dir, prefix)
  return middleware_static_handler
@end

@fn middleware_chain_new()
  return []
@end

