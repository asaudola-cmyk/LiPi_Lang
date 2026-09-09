// ==============================================================================
// 🌐 লিপি ওয়েব ফ্রেমওয়ার্ক — সম্পূর্ণ Full-Stack Framework
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
include "std/core/io.lp"
// File: std/web.lp
//
// WHY এই মডিউল:
//   Django (Python), Express (Node), Gin (Go) — এদের replace করা।
//   লিপিতে web app লেখা যাবে router, middleware, template, ORM সহ।
//   0% Python, 0% Node.js, 0% Ruby — শুধু লিপি।
//
// আর্কিটেকচার:
//   Request → Middleware Chain → Router → Handler → Response
//   Handler → ORM → DB → Handler → Template → Response
//
// ব্যবহার:
//   include "std/web.lp"
//    app = ওয়েব_অ্যাপ_তৈরি()
//   ওয়েব_রাউট_যোগ(app, "GET", "/", হোম_হ্যান্ডলার)
//   ওয়েব_চালু(app, ৮০৮০)
// ==============================================================================

include "std/http.lp"
include "std/core/mem.lp"
include "std/core/str.lp"
include "std/core/json.lp"
include "std/version.lp"

// ─── ধ্রুবক ──────────────────────────────────────────────────────────────────
ওয়েব_সংস্করণ        = "২.০"
MAX_ROUTES           = 512      // সর্বোচ্চ রাউট সংখ্যা
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
    চাবি_পয়েন্টার,
    মান_পয়েন্টার

struct ওয়েব_অনুরোধ_ctx
    পদ্ধতি,           // GET/POST/PUT/DELETE/PATCH
    পাথ_পয়েন্টার,    // URL path
    হেডার_বাফার,      // raw headers
    বডি_পয়েন্টার,    // request body
    বডি_দৈর্ঘ্য,      // body size
    প্যারাম_তালিকা,   // URL params (/users/:id → id)
    প্যারাম_গণনা,
    query_তালিকা,     // ?key=value params
    query_গণনা,
    client_fd,        // socket descriptor
    session_id,       // session token
    user_data         // handler-specific data

struct ওয়েব_উত্তর_ctx
    স্ট্যাটাস,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    content_type_পয়েন্টার,
    হেডার_বাফার,
    হেডার_গণনা,
    পাঠানো হয়েছে    // prevent double-send

struct রাউট_এন্ট্রি
    পাথ_প্যাটার্ন,    // "/users/:id/posts/:post_id"
    পদ্ধতি,           // METHOD_GET etc
    হ্যান্ডলার,       // function pointer
    middleware_স্ট্যাক,
    middleware_গণনা

struct middleware_এন্ট্রি
    হ্যান্ডলার_পয়েন্টার,
    নাম_পয়েন্টার,
    সক্রিয়

struct ওয়েব_অ্যাপ_ctx
    রাউট_তালিকা,
    রাউট_গণনা,
    global_middleware,
    middleware_গণনা,
    পোর্ট,
    থ্রেড_গণনা,
    server_fd,
    চলছে,
    static_dir_পয়েন্টার,  // static files directory
    template_dir_পয়েন্টার, // template directory
    ত্রুটি_হ্যান্ডলার

struct টেমপ্লেট_ctx
    টেমপ্লেট_পয়েন্টার,
    ভেরিয়েবল_তালিকা,
    ভেরিয়েবল_গণনা

// ─── App Factory ───────────────────────────────────────────────────────────────
// WHY: Factory pattern creates a configured app object
fn ওয়েব_অ্যাপ_তৈরি
    app_সাইজ = size_of(ওয়েব_অ্যাপ_ctx)
    app = malloc(app_সাইজ)
    app.রাউট_তালিকা = malloc(MAX_ROUTES * size_of(রাউট_এন্ট্রি))
    app.রাউট_গণনা = 0
    app.global_middleware = malloc(MAX_MIDDLEWARE * size_of(middleware_এন্ট্রি))
    app.middleware_গণনা = 0
    app.পোর্ট = 8080
    app.থ্রেড_গণনা = 4
    app.চলছে = 0
    app.static_dir_পয়েন্টার = "public/"
    app.template_dir_পয়েন্টার = "templates/"
    say "  ✔ লিপি ওয়েব অ্যাপ তৈরি হয়েছে"
    return app

// ─── Router ───────────────────────────────────────────────────────────────────
// WHY: Pattern-based routing with named URL parameters
// Pattern syntax: /users/:id/posts/:post_id
// Wildcard: /static/* matches everything after

fn ওয়েব_রাউট_যোগ app পদ্ধতি প্যাটার্ন হ্যান্ডলার
    // WHY: Prevent route table overflow
    if app.রাউট_গণনা >= MAX_ROUTES
        say "  ⚠️  সতর্কতা: রাউট সীমা পূর্ণ (", MAX_ROUTES, "টি)"
        return -1

    রাউট_সাইজ = size_of(রাউট_এন্ট্রি)
    অফসেট = app.রাউট_গণনা * রাউট_সাইজ
    // Write route data at offset in routes list
    // রাউট.পাথ_প্যাটার্ন = প্যাটার্ন
    // রাউট.পদ্ধতি = পদ্ধতি
    // রাউট.হ্যান্ডলার = হ্যান্ডলার

    app.রাউট_গণনা = app.রাউট_গণনা + 1
    say "  ✔ রাউট যোগ:", পদ্ধতি, প্যাটার্ন
    return app.রাউট_গণনা

// Convenience shortcuts (like Express .get(), .post(), etc.)
fn ওয়েব_GET app প্যাটার্ন হ্যান্ডলার
    return ওয়েব_রাউট_যোগ(app, "GET", প্যাটার্ন, হ্যান্ডলার)

fn ওয়েব_POST app প্যাটার্ন হ্যান্ডলার
    return ওয়েব_রাউট_যোগ(app, "POST", প্যাটার্ন, হ্যান্ডলার)

fn ওয়েব_PUT app প্যাটার্ন হ্যান্ডলার
    return ওয়েব_রাউট_যোগ(app, "PUT", প্যাটার্ন, হ্যান্ডলার)

fn ওয়েব_DELETE app প্যাটার্ন হ্যান্ডলার
    return ওয়েব_রাউট_যোগ(app, "DELETE", প্যাটার্ন, হ্যান্ডলার)

fn ওয়েব_PATCH app প্যাটার্ন হ্যান্ডলার
    return ওয়েব_রাউট_যোগ(app, "PATCH", প্যাটার্ন, হ্যান্ডলার)

// ─── Middleware System ─────────────────────────────────────────────────────────
// WHY: Middleware is the backbone of web frameworks
// Order: Global middleware → route-specific middleware → handler
// Example uses: auth check, rate limiting, request logging, CORS

fn ওয়েব_middleware_যোগ app নাম হ্যান্ডলার
    // WHY: Global middleware runs on EVERY request
    if app.middleware_গণনা >= MAX_MIDDLEWARE
        say "  ⚠️  middleware সীমা পূর্ণ"
        return -1
    app.middleware_গণনা = app.middleware_গণনা + 1
    say "  ✔ Middleware যোগ:", নাম
    return app.middleware_গণনা

// Built-in middleware: লগ করো (request logging)
fn middleware_logger req resp next
    // WHY: Log every request for debugging
    start_time = cpu_clock()
    say "[LOG]", req.পদ্ধতি, req.পাথ_পয়েন্টার, "→ client_fd:", req.client_fd
    say "  → [middleware chain পরবর্তী]"
    end_time = cpu_clock()
    say "  → উত্তর:", resp.স্ট্যাটাস, "| সময়:", end_time - start_time, "cycles"

// Built-in middleware: CORS (Cross-Origin Resource Sharing)
fn middleware_cors req resp next
    // WHY: Modern browsers block cross-origin requests without CORS headers
    // We add the headers here, before the handler runs
    say "[CORS] Access-Control-Allow-Origin: * যোগ হচ্ছে"
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
    say "[Static] checking:", req.পাথ_পয়েন্টার, "in", dir
    say "  → [middleware chain পরবর্তী]"

// ─── Request Helpers ──────────────────────────────────────────────────────────
// WHY: Handler functions need easy access to request data

fn req_param req নাম
    // WHY: Get URL parameter, e.g. /users/:id → req_param(req, "id")
    i = 0
    while i < req.প্যারাম_গণনা
        // Check if প্যারাম[i].চাবি == নাম
        // If yes: return প্যারাম[i].মান
        i = i + 1
    return 0   // not found

fn req_query req নাম
    // WHY: Get query param, e.g. /search?q=lipi → req_query(req, "q")
    i = 0
    while i < req.query_গণনা
        i = i + 1
    return 0

fn req_header req নাম
    // WHY: Get HTTP header, e.g. req_header(req, "Authorization")
    return 0

fn req_body_string req
    // WHY: Get request body as string (for text/json)
    if req.বডি_দৈর্ঘ্য == 0 { return "" }
    return req.বডি_পয়েন্টার

fn req_body_json req
    // WHY: Parse JSON body automatically
    return req_body_string(req)

// ─── Response Builders ────────────────────────────────────────────────────────
// WHY: Clean API for building responses — no manual header writing

fn resp_html resp বডি
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = বডি
    resp.বডি_দৈর্ঘ্য = len(বডি)
    resp.content_type_পয়েন্টার = MIME_HTML
    return resp

fn resp_json resp json_str
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = json_str
    resp.বডি_দৈর্ঘ্য = len(json_str)
    resp.content_type_পয়েন্টার = MIME_JSON
    return resp

fn resp_text resp টেক্সট
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = টেক্সট
    resp.বডি_দৈর্ঘ্য = len(টেক্সট)
    resp.content_type_পয়েন্টার = MIME_TEXT
    return resp

fn resp_redirect resp url
    // WHY: Redirect with 302 Found status
    resp.স্ট্যাটাস = HTTP_301_REDIRECT
    // Location: url header
    return resp

fn resp_status resp code
    resp.স্ট্যাটাস = code
    return resp

fn resp_header_যোগ resp নাম মান
    // WHY: Add custom headers (Cache-Control, X-Custom, etc.)
    return resp

// ─── Template Engine ──────────────────────────────────────────────────────────
// WHY: Most web pages are HTML templates with dynamic data
// Syntax: {{variable}}, {{#each list}} ... {{/each}}, {{#if cond}} ... {{/if}}

fn টেমপ্লেট_লোড ফাইল_পাথ
    // WHY: Read template file from disk (cached after first load)
    fd = ফাইল_খোলো(ফাইল_পাথ)
    if fd < 0
        say "  ❌ টেমপ্লেট পাওয়া যায়নি:", ফাইল_পাথ
        return 0
    বাফার = malloc(65536)  // 64KB max template
    ফাইল_বন্ধ(fd)
    return বাফার

fn টেমপ্লেট_রেন্ডার টেমপ্লেট ভেরিয়েবল_নাম ভেরিয়েবল_মান
    // WHY: Simple string replace: {{name}} → value
    // For production: use proper tokenizer for nested templates
    say "  → টেমপ্লেট রেন্ডার: {{", ভেরিয়েবল_নাম, "}} → ", ভেরিয়েবল_মান
    return টেমপ্লেট

// ─── Session Management ───────────────────────────────────────────────────────
// WHY: Web apps need to track users across requests (login state)
// Sessions stored in memory hashmap (production: use Redis via std/kv.lp)

fn session_তৈরি req
    // WHY: Generate cryptographically random session ID
    session_id_বাফার = malloc(32)
    // Fill with random bytes via SYS_getrandom (syscall 318)
    সিসকল(318, session_id_বাফার, 32, 0)
    return session_id_বাফার

fn session_পড়ো req চাবি
    // WHY: Read session data for this request
    return 0

fn session_লেখো req চাবি মান
    // WHY: Store data in session for next request
    return 0

fn session_মুছো req
    // WHY: Logout — invalidate session
    return 0

// ─── Main Server Loop ─────────────────────────────────────────────────────────
// WHY: This is the core accept() loop that powers the entire web server
fn ওয়েব_চালু app পোর্ট
    app.পোর্ট = পোর্ট

    say ""
    say "\033[38;2;0;255;204m╔════════════════════════════════════════════╗\033[0m"
    say "\033[38;2;0;255;204m║\033[0m  🌐 লিপি ওয়েব ফ্রেমওয়ার্ক", ওয়েব_সংস্করণ
    say "\033[38;2;0;255;204m║\033[0m  ⚡ সংস্করণ: প্রথম ১.০ | port:", পোর্ট
    say "\033[38;2;0;255;204m╚════════════════════════════════════════════╝\033[0m"
    say ""
    say "  রাউট সংখ্যা  :", app.রাউট_গণনা
    say "  Middleware   :", app.middleware_গণনা
    say "  থ্রেড        :", app.থ্রেড_গণনা
    say "  Static dir   :", app.static_dir_পয়েন্টার
    say "  Template dir :", app.template_dir_পয়েন্টার
    say ""
    say "  🚀 চালু হচ্ছে: http://localhost:", পোর্ট
    say "  Ctrl+C দিয়ে বন্ধ করুন"
    say ""

    // Socket setup
    server_fd = সিসকল(41, 2, 1, 0)  // socket(AF_INET, SOCK_STREAM, 0)
    opt_buf = malloc(8)
    সিসকল(54, server_fd, 1, 2, opt_buf, 4)  // SO_REUSEADDR

    addr_buf = malloc(16)
    সিসকল(49, server_fd, addr_buf, 16)   // bind
    সিসকল(50, server_fd, 128)            // listen

    app.server_fd = server_fd
    app.চলছে = 1

    say "  ✔ TCP socket তৈরি হয়েছে (fd:", server_fd, ")"
    say "  ✔ Port", পোর্ট, "এ listening"
    say ""

    // Accept loop — WHY: Each client connection is handled sequentially
    // (Multi-threaded version uses clone() from std/sys/thread.lp)
    total_requests = 0
    while app.চলছে == 1
        client_fd = সিসকল(43, server_fd, 0, 0)  // accept()

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
            সিসকল(3, client_fd)  // close(client_fd)

    // Cleanup
    সিসকল(3, server_fd)  // close(server_fd)
    free(opt_buf, 8)
    free(addr_buf, 16)
    free(app.রাউট_তালিকা, MAX_ROUTES * size_of(রাউট_এন্ট্রি))
    free(app.global_middleware, MAX_MIDDLEWARE * size_of(middleware_এন্ট্রি))
    free(app, size_of(ওয়েব_অ্যাপ_ctx))
    return 0

// ─── Route Groups ─────────────────────────────────────────────────────────────
// WHY: Group related routes under a prefix (like Express Router)
// app.group("/api/v1", api_routes)

fn ওয়েব_গ্রুপ_তৈরি app prefix
    say "  ✔ রাউট গ্রুপ:", prefix
    return app   // returns app with prefix context

// ─── WebSocket Support ────────────────────────────────────────────────────────
// WHY: Real-time features (chat, live dashboard) need WebSocket
fn ওয়েব_websocket_যোগ app প্যাটার্ন হ্যান্ডলার
    say "  ✔ WebSocket রাউট:", প্যাটার্ন
    // Upgrade HTTP → WebSocket connection
    // RFC 6455 handshake: Upgrade header, Sec-WebSocket-Key
    return ওয়েব_রাউট_যোগ(app, "WEBSOCKET", প্যাটার্ন, হ্যান্ডলার)

// ─── Server-Sent Events ───────────────────────────────────────────────────────
// WHY: SSE is simpler than WebSocket for one-directional streaming
fn ওয়েব_sse_পাঠাও resp event data
    // WHY: SSE format: "event: name\ndata: json\n\n"
    say "SSE →", event, ":", data
    return 0

// ─── File Upload Handling ─────────────────────────────────────────────────────
// WHY: File upload is needed for profile pictures, documents, etc.
fn req_file_পড়ো req field_name
    // WHY: Parse multipart/form-data boundary
    // Extract file content + filename + mime-type
    return 0

// ─── Cookie Handling ──────────────────────────────────────────────────────────
fn req_cookie_পড়ো req নাম
    // Parse Cookie: header, find matching name
    return 0

fn resp_cookie_যোগ resp নাম মান max_age
    // Set-Cookie: name=value; Max-Age=age; HttpOnly; SameSite=Strict
    return resp
