// ==============================================================================
// 👑 OSHIM FRAMEWORK — SOVEREIGN FULLSTACK WEB & API ENGINE (framework/oshim.lp)
// ⚡ Zero Libc | Zero External Dependencies | 100% Pure Lipi Architecture
// ==============================================================================

// WHY: A sovereign computing ecosystem requires an idiomatic, production-ready
// web framework for building microservices, REST APIs, and dynamic fullstack apps.
// Oshim Framework provides high-performance HTTP routing, JSON-RPC/REST abstractions,
// middleware chains, and direct Linux kernel socket integration with zero overhead.

include "std/io.lp"
include "std/mem.lp"
include "std/net.lp"
include "std/json.lp"

// ── HTTP Status Codes ─────────────────────────────────────────────────────────
HTTP_STATUS_OK                  = 200
HTTP_STATUS_CREATED             = 201
HTTP_STATUS_BAD_REQUEST         = 400
HTTP_STATUS_UNAUTHORIZED        = 401
HTTP_STATUS_FORBIDDEN           = 403
HTTP_STATUS_NOT_FOUND           = 404
HTTP_STATUS_METHOD_NOT_ALLOWED  = 405
HTTP_STATUS_INTERNAL_ERROR      = 500

// ── HTTP Content Types ────────────────────────────────────────────────────────
MIME_TEXT_PLAIN                 = "text/plain; charset=utf-8"
MIME_TEXT_HTML                  = "text/html; charset=utf-8"
MIME_APP_JSON                   = "application/json; charset=utf-8"

// ── Oshim Routing Structures ──────────────────────────────────────────────────
// WHY: Struct representations define the in-memory layout for routing and dispatch.
struct OshimRoute
    method
    path
    handler_id

struct OshimRequest
    method
    path
    raw_query
    body_length
    body_ptr

struct OshimResponse
    status_code
    content_type
    body_text

// ── Router Registry Engine ────────────────────────────────────────────────────
// WHY: In-memory table storing registered routes for fast O(N) lookup without dynamic regex overhead.
fn oshim_router_new
    routes = list()
    return routes

fn oshim_router_add router method path handler_id
    route = OshimRoute()
    route.method = method
    route.path = path
    route.handler_id = handler_id
    push(router, route)
    return route

fn oshim_get router path handler_id
    return oshim_router_add(router, "GET", path, handler_id)

fn oshim_post router path handler_id
    return oshim_router_add(router, "POST", path, handler_id)

fn oshim_put router path handler_id
    return oshim_router_add(router, "PUT", path, handler_id)

fn oshim_delete router path handler_id
    return oshim_router_add(router, "DELETE", path, handler_id)

// ── Route Matching & Dispatch ─────────────────────────────────────────────────
// WHY: Matches incoming HTTP requests against registered routes and returns the designated handler ID.
fn oshim_dispatch router method path
    i = 0
    rlen = len(router)
    while i < rlen
        r = get(router, i)
        if r.method == method and r.path == path
            return r.handler_id
        i = i + 1
    return 0 // 0 signifies no route found (404)

// ── Request Parsing Primitives ────────────────────────────────────────────────
// WHY: Direct byte-level inspection parses raw HTTP request line (e.g. 'GET /api/v1/status HTTP/1.1').
fn oshim_parse_method raw_req
    if len(raw_req) >= 4
        if char_at(raw_req, 0) == "P" and char_at(raw_req, 1) == "O" and char_at(raw_req, 2) == "S" and char_at(raw_req, 3) == "T"
            return "POST"
    if len(raw_req) >= 3
        if char_at(raw_req, 0) == "G" and char_at(raw_req, 1) == "E" and char_at(raw_req, 2) == "T"
            return "GET"
    if len(raw_req) >= 3
        if char_at(raw_req, 0) == "P" and char_at(raw_req, 1) == "U" and char_at(raw_req, 2) == "T"
            return "PUT"
    if len(raw_req) >= 6
        if char_at(raw_req, 0) == "D" and char_at(raw_req, 1) == "E" and char_at(raw_req, 2) == "L"
            return "DELETE"
    return "GET"

fn oshim_parse_path raw_req
    p = 0
    rlen = len(raw_req)
    // Skip method
    while p < rlen and char_at(raw_req, p) != " "
        p = p + 1
    // Skip spaces
    while p < rlen and char_at(raw_req, p) == " "
        p = p + 1
    path_start = p
    // Find path end
    while p < rlen and char_at(raw_req, p) != " " and char_at(raw_req, p) != "?" and char_at(raw_req, p) != "\r" and char_at(raw_req, p) != "\n"
        p = p + 1
    path_end = p

    path = ""
    i = path_start
    while i < path_end
        path = path + char_at(raw_req, i)
        i = i + 1
    if len(path) == 0
        return "/"
    return path

// ── Response Formatter & Serializer ───────────────────────────────────────────
// WHY: Builds standards-compliant HTTP/1.1 wire protocol responses with proper headers.
fn oshim_status_text code
    if code == 200
        return "200 OK"
    if code == 201
        return "201 Created"
    if code == 400
        return "400 Bad Request"
    if code == 404
        return "404 Not Found"
    if code == 500
        return "500 Internal Server Error"
    return "200 OK"

fn oshim_response_new status_code content_type body_text
    res = OshimResponse()
    res.status_code = status_code
    res.content_type = content_type
    res.body_text = body_text
    return res

fn oshim_response_json data
    return oshim_response_new(200, "application/json", data)

fn oshim_response_html html_content
    return oshim_response_new(200, "text/html", html_content)

fn oshim_response_not_found
    return oshim_response_new(404, MIME_APP_JSON, "{\"error\": 404, \"message\": \"Route not found on Oshim Framework\"}")

fn oshim_serialize_response res
    st = oshim_status_text(res.status_code)
    blen = len(res.body_text)
    wire = "HTTP/1.1 " + st + "\r\n"
    wire = wire + "Server: Oshim-Framework/1.0.0 (Lipi-Sovereign-x86_64)\r\n"
    wire = wire + "Content-Type: " + res.content_type + "\r\n"
    wire = wire + "Content-Length: " + blen + "\r\n"
    wire = wire + "Connection: close\r\n"
    wire = wire + "X-Content-Type-Options: nosniff\r\n"
    wire = wire + "\r\n"
    wire = wire + res.body_text
    return wire

// ── High-Level App Lifecycle ──────────────────────────────────────────────────
// WHY: Simplifies server startup into an expressive, declarative developer experience.
fn oshim_app_banner port
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[1;38;2;255;255;255m👑 OSHIM FRAMEWORK — SOVEREIGN FULLSTACK ENGINE (v1.0.0)\033[0m              \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  \033[38;2;180;180;180m⚡ High-Performance HTTP Routing | Zero Libc | Pure Silicon Execution\033[0m   \033[38;2;0;255;204m║\033[0m"
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════════════════════════════════╝\033[0m"
    say "🌐 Server listening on http://127.0.0.1:" + port + " [Active]"
    say "------------------------------------------------------------------------"
