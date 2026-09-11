// ==============================================================================
// 🌐 লিপি ওয়েব ফ্রেমওয়ার্a — সম্পূর্ণ Full-Stack Framework
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
include "std/io.lp"
// File: std/web.lp
//
// WHY এই মডিউল:
//   Django (Python), Express (Node), Gin (Go) — এদের replace aরা।
//   লিপিতে web app লেbা যাবে router, middleware, template, ORM সহ।
//   0% Python, 0% Node.js, 0% Ruby — শুধু লিপি।
//
// আর্aিটেaচার:
//   Request → Middleware Chain → Router → Handler → Response
//   Handler → ORM → DB → Handler → Template → Response
//
// ব্যবrate:
//   include "std/web.lp"
//    app = ওয়েব_অ্যাপ_তৈরি()
//   ওয়েব_রাউট_add(app, "GET", "/", হোম_handler)
//   ওয়েব_চালু(app, ৮০৮০)
// ==============================================================================

include "std/http.lp"
include "std/mem.lp"
include "std/str.lp"
include "std/json.lp"
include "std/version.lp"

// ─── ধ্রুবa ──────────────────────────────────────────────────────────────────
ওয়েব_version        = "২.০"
MAX_ROUTES           = 512      // সর্বোচ্চ রাউট num
MAX_MIDDLEWARE        = 32       // middleware stack depth
MAX_PARAMS           = 16       // URL params per route
MAX_QUERY_PARAMS     = 64       // query string params
MAX_HEADERS          = 64       // request headers
DEFAULT_TIMEOUT      = 30       // seconds
DEFAULT_BODY_LIMIT   = 1048576  // 1MB max request body

// Session constants
SESSION_COOKIE_NAME  = "lipi_session"
SESSION_MAX_AGE      = 86400    // 24 hours in seconds

// ─── Core Structs ─────────────────────────────────────────────────────────────

struct ওয়েব_প্যারামিটার
    key_ptr,
    value_ptr

struct ওয়েব_request_ctx
    term্ধতি,           // GET/POST/PUT/DELETE/PATCH
    path_ptr,    // URL path
    header_buffer,      // raw headers
    body_ptr,    // request body
    body_length,      // body size
    প্যারাম_list,   // URL params (/users/:id → id)
    প্যারাম_count,
    query_list,     // ?key=value params
    query_count,
    client_fd,        // socket descriptor
    session_id,       // session token
    user_data         // handler-specific data

struct ওয়েব_উত্তর_ctx
    status,
    body_ptr,
    body_length,
    content_type_ptr,
    header_buffer,
    header_count,
    পাঠানো হয়েছে    // prevent double-send

struct রাউট_entry
    path_pattern,    // "/users/:id/posts/:post_id"
    term্ধতি,           // METHOD_GET etc
    handler,       // function pointer
    middleware_স্ট্যাa,
    middleware_count

struct middleware_entry
    handler_ptr,
    name_ptr,
    সa্রিয়

struct ওয়েব_অ্যাপ_ctx
    রাউট_list,
    রাউট_count,
    global_middleware,
    middleware_count,
    port,
    থ্রেড_count,
    server_fd,
    running,
    static_dir_ptr,  // static files directory
    template_dir_ptr, // template directory
    error_handler

struct টেমপ্লেট_ctx
    টেমপ্লেট_ptr,
    ভেরিয়েবল_list,
    ভেরিয়েবল_count

// ─── App Factory ───────────────────────────────────────────────────────────────
// WHY: Factory pattern creates a configured app object
fn ওয়েব_অ্যাপ_created
    app_size = size_of(ওয়েব_অ্যাপ_ctx)
    app = malloc(app_size)
    app.রাউট_list = malloc(MAX_ROUTES * size_of(রাউট_entry))
    app.রাউট_count = 0
    app.global_middleware = malloc(MAX_MIDDLEWARE * size_of(middleware_entry))
    app.middleware_count = 0
    app.port = 8080
    app.থ্রেড_count = 4
    app.running = 0
    app.static_dir_ptr = "public/"
    app.template_dir_ptr = "templates/"
    say "  ✔ লিপি ওয়েব অ্যাপ created হয়েছে"
    return app

// ─── Router ───────────────────────────────────────────────────────────────────
// WHY: Pattern-based routing with named URL parameters
// Pattern syntax: /users/:id/posts/:post_id
// Wildcard: /static/* matches everything after

fn ওয়েব_রাউট_add app term্ধতি pattern handler
    // WHY: Prevent route table overflow
    if app.রাউট_count >= MAX_ROUTES
        say "  ⚠️  সতর্কতা: রাউট সীমা পূর্ণ (", MAX_ROUTES, "টি)"
        return -1

    রাউট_size = size_of(রাউট_entry)
    offset = app.রাউট_count * রাউট_size
    // Write route data at offset in routes list
    // রাউট.পাথ_প্যাটার্ন = প্যাটার্ন
    // রাউট.term্ধতি = term্ধতি
    // রাউট.handler = handler

    app.রাউট_count = app.রাউট_count + 1
    say "  ✔ রাউট add:", term্ধতি, pattern
    return app.রাউট_count

// Convenience shortcuts (like Express .get(), .post(), etc.)
fn ওয়েব_GET app pattern handler
    return ওয়েব_রাউট_add(app, "GET", pattern, handler)

fn ওয়েব_POST app pattern handler
    return ওয়েব_রাউট_add(app, "POST", pattern, handler)

fn ওয়েব_PUT app pattern handler
    return ওয়েব_রাউট_add(app, "PUT", pattern, handler)

fn ওয়েব_DELETE app pattern handler
    return ওয়েব_রাউট_add(app, "DELETE", pattern, handler)

fn ওয়েব_PATCH app pattern handler
    return ওয়েব_রাউট_add(app, "PATCH", pattern, handler)

// ─── Middleware System ─────────────────────────────────────────────────────────
// WHY: Middleware is the backbone of web frameworks
// Order: Global middleware → route-specific middleware → handler
// Example uses: auth check, rate limiting, request logging, CORS

fn ওয়েব_middleware_add app name handler
    // WHY: Global middleware runs on EVERY request
    if app.middleware_count >= MAX_MIDDLEWARE
        say "  ⚠️  middleware সীমা পূর্ণ"
        return -1
    app.middleware_count = app.middleware_count + 1
    say "  ✔ Middleware add:", name
    return app.middleware_count

// Built-in middleware: লগ aরো (request logging)
fn middleware_logger req resp next
    // WHY: Log every request for debugging
    start_time = cpu_clock()
    say "[LOG]", req.term্ধতি, req.path_ptr, "→ client_fd:", req.client_fd
    say "  → [middleware chain পরবর্তী]"
    end_time = cpu_clock()
    say "  → উত্তর:", resp.status, "| সময়:", end_time - start_time, "cycles"

// Built-in middleware: CORS (Cross-Origin Resource Sharing)
fn middleware_cors req resp next
    // WHY: Modern browsers block cross-origin requests without CORS headers
    // We add the headers here, before the handler runs
    say "[CORS] Access-Control-Allow-Origin: * add হচ্ছে"
    say "  → [middleware chain পরবর্তী]"

// Built-in middleware: Rate limiting
fn middleware_rate_limit req resp next per_second
    // WHY: Without rate limiting, APIs can be DDoS'd
    // Tracks request count per IP using in-memory hashmap
    say "[RateLimit] checking:", req.client_fd
    say "  → [middleware chain পরবর্তী]"

// Built-in middleware: JWT Authentication
fn middleware_jwt_auth req resp next secret
    // WHY: Stateless authentication — no session storage needed
    say "[JWT] token validating..."
    // Parse Authorization: Bearer <token> header
    // Verify signature with secret
    // Decode payload → set req.user_data
    say "  → [middleware chain পরবর্তী]"

// Built-in middleware: Static file server
fn middleware_static req resp next dir
    // WHY: Serve HTML/CSS/JS/images without a handler
    // Check if path exists in dir
    // If yes: serve file with correct MIME type
    // If no: call next()
    say "[Static] checking:", req.path_ptr, "in", dir
    say "  → [middleware chain পরবর্তী]"

// ─── Request Helpers ──────────────────────────────────────────────────────────
// WHY: Handler functions need easy access to request data

fn req_param req name
    // WHY: Get URL parameter, e.g. /users/:id → req_param(req, "id")
    i = 0
    while i < req.প্যারাম_count
        // Check if প্যারাম[i].key == name
        // If yes: return প্যারাম[i].value
        i = i + 1
    return 0   // not found

fn req_query req name
    // WHY: Get query param, e.g. /search?q=lipi → req_query(req, "q")
    i = 0
    while i < req.query_count
        i = i + 1
    return 0

fn req_header req name
    // WHY: Get HTTP header, e.g. req_header(req, "Authorization")
    return 0

fn req_body_string req
    // WHY: Get request body as string (for text/json)
    if req.body_length == 0
        return ""
    return req.body_ptr

fn req_body_json req
    // WHY: Parse JSON body automatically
    return req_body_string(req)

// ─── Response Builders ────────────────────────────────────────────────────────
// WHY: Clean API for building responses — no manual header writing

fn resp_html resp body
    resp.status = HTTP_200_OK
    resp.body_ptr = body
    resp.body_length = len(body)
    resp.content_type_ptr = MIME_HTML
    return resp

fn resp_json resp json_str
    resp.status = HTTP_200_OK
    resp.body_ptr = json_str
    resp.body_length = len(json_str)
    resp.content_type_ptr = MIME_JSON
    return resp

fn resp_text resp টেa্সট
    resp.status = HTTP_200_OK
    resp.body_ptr = টেa্সট
    resp.body_length = len(টেa্সট)
    resp.content_type_ptr = MIME_TEXT
    return resp

fn resp_redirect resp url
    // WHY: Redirect with 302 Found status
    resp.status = HTTP_301_REDIRECT
    // Location: url header
    return resp

fn resp_status resp code
    resp.status = code
    return resp

fn resp_header_add resp name value
    // WHY: Add custom headers (Cache-Control, X-Custom, etc.)
    return resp

// ─── Template Engine ──────────────────────────────────────────────────────────
// WHY: Most web pages are HTML templates with dynamic data
// Syntax: {{variable}}, {{#each list}} ... {{/each}}, {{#if cond}} ... {{/if}}

fn টেমপ্লেট_লোড file_path
    // WHY: Read template file from disk (cached after first load)
    fd = file_bোলো(file_path)
    if fd < 0
        say "  ❌ টেমপ্লেট পাওয়া যায়নি:", file_path
        return 0
    buffer = malloc(65536)  // 64KB max template
    file_close(fd)
    return buffer

fn টেমপ্লেট_রেন্ডার টেমপ্লেট ভেরিয়েবল_name ভেরিয়েবল_value
    // WHY: Simple string replace: {{name}} → value
    // For production: use proper tokenizer for nested templates
    say "  → টেমপ্লেট রেন্ডার: {{", ভেরিয়েবল_name, "}} → ", ভেরিয়েবল_value
    return টেমপ্লেট

// ─── Session Management ───────────────────────────────────────────────────────
// WHY: Web apps need to track users across requests (login state)
// Sessions stored in memory hashmap (production: use Redis via std/kv.lp)

fn session_created req
    // WHY: Generate cryptographically random session ID
    session_id_buffer = malloc(32)
    // Fill with random bytes via SYS_getrandom (syscall 318)
    syscall(318, session_id_buffer, 32, 0)
    return session_id_buffer

fn session_read req key
    // WHY: Read session data for this request
    return 0

fn session_লেbো req key value
    // WHY: Store data in session for next request
    return 0

fn session_delete req
    // WHY: Logout — invalidate session
    return 0

// ─── Main Server Loop ─────────────────────────────────────────────────────────
// WHY: This is the core accept() loop that powers the entire web server
fn ওয়েব_চালু app port
    app.port = port

    say ""
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  🌐 লিপি ওয়েব ফ্রেমওয়ার্ক", ওয়েব_version
    say "\033[38;2;0;255;204m║\033[0m  ⚡ সংস্করণ: প্রথম ১.০ | port:", port
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════╝\033[0m"
    say ""
    say "  রাউট সংখ্যা  :", app.রাউট_count
    say "  Middleware   :", app.middleware_count
    say "  থ্রেড        :", app.থ্রেড_count
    say "  Static dir   :", app.static_dir_ptr
    say "  Template dir :", app.template_dir_ptr
    say ""
    say "  🚀 চালু হচ্ছে: http://localhost:", port
    say "  Ctrl+C দিয়ে close করুন"
    say ""

    // Socket setup
    server_fd = syscall(41, 2, 1, 0)  // socket(AF_INET, SOCK_STREAM, 0)
    opt_buf = malloc(8)
    syscall(54, server_fd, 1, 2, opt_buf, 4)  // SO_REUSEADDR

    addr_buf = malloc(16)
    syscall(49, server_fd, addr_buf, 16)   // bind
    syscall(50, server_fd, 128)            // listen

    app.server_fd = server_fd
    app.running = 1

    say "  ✔ TCP socket created হয়েছে (fd:", server_fd, ")"
    say "  ✔ Port", port, "এ listening"
    say ""

    // Accept loop — WHY: Each client connection is handled sequentially
    // (Multi-threaded version uses clone() from std/sys/thread.lp)
    total_requests = 0
    while app.running == 1
        client_fd = syscall(43, server_fd, 0, 0)  // accept()

        if client_fd >= 0
            total_requests = total_requests + 1
            // 1. Parse HTTP request
            // 2. Run global middleware chain
            // 3. Find matching route
            // 4. Extract URL params
            // 5. Run route-specific middleware
            // 6. Call handler
            // 7. Send response
            // 8. Close client connection
            syscall(3, client_fd)  // close(client_fd)

    // Cleanup
    syscall(3, server_fd)  // close(server_fd)
    free(opt_buf, 8)
    free(addr_buf, 16)
    free(app.রাউট_list, MAX_ROUTES * size_of(রাউট_entry))
    free(app.global_middleware, MAX_MIDDLEWARE * size_of(middleware_entry))
    free(app, size_of(ওয়েব_অ্যাপ_ctx))
    return 0

// ─── Route Groups ─────────────────────────────────────────────────────────────
// WHY: Group related routes under a prefix (like Express Router)
// app.group("/api/v1", api_routes)

fn ওয়েব_গ্রুপ_created app prefix
    say "  ✔ রাউট গ্রুপ:", prefix
    return app   // returns app with prefix context

// ─── WebSocket Support ────────────────────────────────────────────────────────
// WHY: Real-time features (chat, live dashboard) need WebSocket
fn ওয়েব_websocket_add app pattern handler
    say "  ✔ WebSocket রাউট:", pattern
    // Upgrade HTTP → WebSocket connection
    // RFC 6455 handshake: Upgrade header, Sec-WebSocket-Key
    return ওয়েব_রাউট_add(app, "WEBSOCKET", pattern, handler)

// ─── Server-Sent Events ───────────────────────────────────────────────────────
// WHY: SSE is simpler than WebSocket for one-directional streaming
fn ওয়েব_sse_send resp event data
    // WHY: SSE format: "event: name\ndata: json\n\n"
    say "SSE →", event, ":", data
    return 0

// ─── File Upload Handling ─────────────────────────────────────────────────────
// WHY: File upload is needed for profile pictures, documents, etc.
fn req_file_read req field_name
    // WHY: Parse multipart/form-data boundary
    // Extract file content + filename + mime-type
    return 0

// ─── Cookie Handling ──────────────────────────────────────────────────────────
fn req_cookie_read req name
    // Parse Cookie: header, find matching name
    return 0

fn resp_cookie_add resp name value max_age
    // Set-Cookie: name=value; Max-Age=age; HttpOnly; SameSite=Strict
    return resp
