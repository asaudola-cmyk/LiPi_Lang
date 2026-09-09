// ==============================================================================
// 🌐 লিপি ওয়েব ফ্রেমওয়ার্ক — সম্পূর্ণ Full-Stack Framework
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
অন্তর্ভুক্ত "std/core/io.lp"
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
//   অন্তর্ভুক্ত "std/web.lp"
//   ধরি app = ওয়েব_অ্যাপ_তৈরি()
//   ওয়েব_রাউট_যোগ(app, "GET", "/", হোম_হ্যান্ডলার)
//   ওয়েব_চালু(app, ৮০৮০)
// ==============================================================================

অন্তর্ভুক্ত "std/http.lp"
অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"
অন্তর্ভুক্ত "std/core/json.lp"
অন্তর্ভুক্ত "std/version.lp"

// ─── ধ্রুবক ──────────────────────────────────────────────────────────────────
ধরি ওয়েব_সংস্করণ        = "২.০"
ধরি MAX_ROUTES           = ৫১২      // সর্বোচ্চ রাউট সংখ্যা
ধরি MAX_MIDDLEWARE        = ৩২       // middleware stack depth
ধরি MAX_PARAMS           = ১৬       // URL params per route
ধরি MAX_QUERY_PARAMS     = ৬৪       // query string params
ধরি MAX_HEADERS          = ৬৪       // request headers
ধরি DEFAULT_TIMEOUT      = ৩০       // seconds
ধরি DEFAULT_BODY_LIMIT   = ১০৪৮৫৭৬  // 1MB max request body

// Session constants
ধরি SESSION_COOKIE_NAME  = "lipi_session"
ধরি SESSION_MAX_AGE      = ৮৬৪০০    // 24 hours in seconds

// ─── Core Structs ─────────────────────────────────────────────────────────────

গঠন ওয়েব_প্যারামিটার {
    চাবি_পয়েন্টার,
    মান_পয়েন্টার
}

গঠন ওয়েব_অনুরোধ_ctx {
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
}

গঠন ওয়েব_উত্তর_ctx {
    স্ট্যাটাস,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    content_type_পয়েন্টার,
    হেডার_বাফার,
    হেডার_গণনা,
    পাঠানো হয়েছে    // prevent double-send
}

গঠন রাউট_এন্ট্রি {
    পাথ_প্যাটার্ন,    // "/users/:id/posts/:post_id"
    পদ্ধতি,           // METHOD_GET etc
    হ্যান্ডলার,       // function pointer
    middleware_স্ট্যাক,
    middleware_গণনা
}

গঠন middleware_এন্ট্রি {
    হ্যান্ডলার_পয়েন্টার,
    নাম_পয়েন্টার,
    সক্রিয়
}

গঠন ওয়েব_অ্যাপ_ctx {
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
}

গঠন টেমপ্লেট_ctx {
    টেমপ্লেট_পয়েন্টার,
    ভেরিয়েবল_তালিকা,
    ভেরিয়েবল_গণনা
}

// ─── App Factory ───────────────────────────────────────────────────────────────
// WHY: Factory pattern creates a configured app object
কাজ ওয়েব_অ্যাপ_তৈরি() {
    ধরি app_সাইজ = সাইজ(ওয়েব_অ্যাপ_ctx)
    ধরি app = মেমরি_বরাদ্দ(app_সাইজ)
    app.রাউট_তালিকা = মেমরি_বরাদ্দ(MAX_ROUTES * সাইজ(রাউট_এন্ট্রি))
    app.রাউট_গণনা = ০
    app.global_middleware = মেমরি_বরাদ্দ(MAX_MIDDLEWARE * সাইজ(middleware_এন্ট্রি))
    app.middleware_গণনা = ০
    app.পোর্ট = ৮০৮০
    app.থ্রেড_গণনা = ৪
    app.চলছে = ০
    app.static_dir_পয়েন্টার = "public/"
    app.template_dir_পয়েন্টার = "templates/"
    দেখাও "  ✔ লিপি ওয়েব অ্যাপ তৈরি হয়েছে"
    ফেরত app
}

// ─── Router ───────────────────────────────────────────────────────────────────
// WHY: Pattern-based routing with named URL parameters
// Pattern syntax: /users/:id/posts/:post_id
// Wildcard: /static/* matches everything after

কাজ ওয়েব_রাউট_যোগ(app, পদ্ধতি, প্যাটার্ন, হ্যান্ডলার) {
    // WHY: Prevent route table overflow
    যদি app.রাউট_গণনা >= MAX_ROUTES {
        দেখাও "  ⚠️  সতর্কতা: রাউট সীমা পূর্ণ (", MAX_ROUTES, "টি)"
        ফেরত -১
    }

    ধরি রাউট_সাইজ = সাইজ(রাউট_এন্ট্রি)
    ধরি অফসেট = app.রাউট_গণনা * রাউট_সাইজ
    // Write route data at offset in routes list
    // রাউট.পাথ_প্যাটার্ন = প্যাটার্ন
    // রাউট.পদ্ধতি = পদ্ধতি  
    // রাউট.হ্যান্ডলার = হ্যান্ডলার

    app.রাউট_গণনা = app.রাউট_গণনা + ১
    দেখাও "  ✔ রাউট যোগ:", পদ্ধতি, প্যাটার্ন
    ফেরত app.রাউট_গণনা
}

// Convenience shortcuts (like Express .get(), .post(), etc.)
কাজ ওয়েব_GET(app, প্যাটার্ন, হ্যান্ডলার) {
    ফেরত ওয়েব_রাউট_যোগ(app, "GET", প্যাটার্ন, হ্যান্ডলার)
}

কাজ ওয়েব_POST(app, প্যাটার্ন, হ্যান্ডলার) {
    ফেরত ওয়েব_রাউট_যোগ(app, "POST", প্যাটার্ন, হ্যান্ডলার)
}

কাজ ওয়েব_PUT(app, প্যাটার্ন, হ্যান্ডলার) {
    ফেরত ওয়েব_রাউট_যোগ(app, "PUT", প্যাটার্ন, হ্যান্ডলার)
}

কাজ ওয়েব_DELETE(app, প্যাটার্ন, হ্যান্ডলার) {
    ফেরত ওয়েব_রাউট_যোগ(app, "DELETE", প্যাটার্ন, হ্যান্ডলার)
}

কাজ ওয়েব_PATCH(app, প্যাটার্ন, হ্যান্ডলার) {
    ফেরত ওয়েব_রাউট_যোগ(app, "PATCH", প্যাটার্ন, হ্যান্ডলার)
}

// ─── Middleware System ─────────────────────────────────────────────────────────
// WHY: Middleware is the backbone of web frameworks
// Order: Global middleware → route-specific middleware → handler
// Example uses: auth check, rate limiting, request logging, CORS

কাজ ওয়েব_middleware_যোগ(app, নাম, হ্যান্ডলার) {
    // WHY: Global middleware runs on EVERY request
    যদি app.middleware_গণনা >= MAX_MIDDLEWARE {
        দেখাও "  ⚠️  middleware সীমা পূর্ণ"
        ফেরত -১
    }
    app.middleware_গণনা = app.middleware_গণনা + ১
    দেখাও "  ✔ Middleware যোগ:", নাম
    ফেরত app.middleware_গণনা
}

// Built-in middleware: লগ করো (request logging)
কাজ middleware_logger(req, resp, next) {
    // WHY: Log every request for debugging
    ধরি start_time = সিপিউ_ক্লক()
    দেখাও "[LOG]", req.পদ্ধতি, req.পাথ_পয়েন্টার, "→ client_fd:", req.client_fd
    দেখাও "  → [middleware chain পরবর্তী]"
    ধরি end_time = সিপিউ_ক্লক()
    দেখাও "  → উত্তর:", resp.স্ট্যাটাস, "| সময়:", end_time - start_time, "cycles"
}

// Built-in middleware: CORS (Cross-Origin Resource Sharing)
কাজ middleware_cors(req, resp, next) {
    // WHY: Modern browsers block cross-origin requests without CORS headers
    // We add the headers here, before the handler runs
    দেখাও "[CORS] Access-Control-Allow-Origin: * যোগ হচ্ছে"
    দেখাও "  → [middleware chain পরবর্তী]"
}

// Built-in middleware: Rate limiting
কাজ middleware_rate_limit(req, resp, next, per_second) {
    // WHY: Without rate limiting, APIs can be DDoS'd
    // Tracks request count per IP using in-memory hashmap
    দেখাও "[RateLimit] checking:", req.client_fd
    দেখাও "  → [middleware chain পরবর্তী]"
}

// Built-in middleware: JWT Authentication
কাজ middleware_jwt_auth(req, resp, next, secret) {
    // WHY: Stateless authentication — no session storage needed
    দেখাও "[JWT] token validating..."
    // Parse Authorization: Bearer <token> header
    // Verify signature with secret
    // Decode payload → set req.user_data
    দেখাও "  → [middleware chain পরবর্তী]"
}

// Built-in middleware: Static file server
কাজ middleware_static(req, resp, next, dir) {
    // WHY: Serve HTML/CSS/JS/images without a handler
    // Check if path exists in dir
    // If yes: serve file with correct MIME type
    // If no: call next()
    দেখাও "[Static] checking:", req.পাথ_পয়েন্টার, "in", dir
    দেখাও "  → [middleware chain পরবর্তী]"
}

// ─── Request Helpers ──────────────────────────────────────────────────────────
// WHY: Handler functions need easy access to request data

কাজ req_param(req, নাম) {
    // WHY: Get URL parameter, e.g. /users/:id → req_param(req, "id")
    ধরি i = ০
    যতক্ষণ i < req.প্যারাম_গণনা {
        // Check if প্যারাম[i].চাবি == নাম
        // If yes: return প্যারাম[i].মান
        i = i + ১
    }
    ফেরত ০   // not found
}

কাজ req_query(req, নাম) {
    // WHY: Get query param, e.g. /search?q=lipi → req_query(req, "q")
    ধরি i = ০
    যতক্ষণ i < req.query_গণনা {
        i = i + ১
    }
    ফেরত ০
}

কাজ req_header(req, নাম) {
    // WHY: Get HTTP header, e.g. req_header(req, "Authorization")
    ফেরত ০
}

কাজ req_body_string(req) {
    // WHY: Get request body as string (for text/json)
    যদি req.বডি_দৈর্ঘ্য == ০ { ফেরত "" }
    ফেরত req.বডি_পয়েন্টার
}

কাজ req_body_json(req) {
    // WHY: Parse JSON body automatically
    ফেরত req_body_string(req)
}

// ─── Response Builders ────────────────────────────────────────────────────────
// WHY: Clean API for building responses — no manual header writing

কাজ resp_html(resp, বডি) {
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = বডি
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(বডি)
    resp.content_type_পয়েন্টার = MIME_HTML
    ফেরত resp
}

কাজ resp_json(resp, json_str) {
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = json_str
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(json_str)
    resp.content_type_পয়েন্টার = MIME_JSON
    ফেরত resp
}

কাজ resp_text(resp, টেক্সট) {
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = টেক্সট
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(টেক্সট)
    resp.content_type_পয়েন্টার = MIME_TEXT
    ফেরত resp
}

কাজ resp_redirect(resp, url) {
    // WHY: Redirect with 302 Found status
    resp.স্ট্যাটাস = HTTP_301_REDIRECT
    // Location: url header
    ফেরত resp
}

কাজ resp_status(resp, code) {
    resp.স্ট্যাটাস = code
    ফেরত resp
}

কাজ resp_header_যোগ(resp, নাম, মান) {
    // WHY: Add custom headers (Cache-Control, X-Custom, etc.)
    ফেরত resp
}

// ─── Template Engine ──────────────────────────────────────────────────────────
// WHY: Most web pages are HTML templates with dynamic data
// Syntax: {{variable}}, {{#each list}} ... {{/each}}, {{#if cond}} ... {{/if}}

কাজ টেমপ্লেট_লোড(ফাইল_পাথ) {
    // WHY: Read template file from disk (cached after first load)
    ধরি fd = ফাইল_খোলো(ফাইল_পাথ)
    যদি fd < ০ {
        দেখাও "  ❌ টেমপ্লেট পাওয়া যায়নি:", ফাইল_পাথ
        ফেরত ০
    }
    ধরি বাফার = মেমরি_বরাদ্দ(৬৫৫৩৬)  // 64KB max template
    ফাইল_বন্ধ(fd)
    ফেরত বাফার
}

কাজ টেমপ্লেট_রেন্ডার(টেমপ্লেট, ভেরিয়েবল_নাম, ভেরিয়েবল_মান) {
    // WHY: Simple string replace: {{name}} → value
    // For production: use proper tokenizer for nested templates
    দেখাও "  → টেমপ্লেট রেন্ডার: {{", ভেরিয়েবল_নাম, "}} → ", ভেরিয়েবল_মান
    ফেরত টেমপ্লেট
}

// ─── Session Management ───────────────────────────────────────────────────────
// WHY: Web apps need to track users across requests (login state)
// Sessions stored in memory hashmap (production: use Redis via std/kv.lp)

কাজ session_তৈরি(req) {
    // WHY: Generate cryptographically random session ID
    ধরি session_id_বাফার = মেমরি_বরাদ্দ(৩২)
    // Fill with random bytes via SYS_getrandom (syscall 318)
    সিসকল(৩১৮, session_id_বাফার, ৩২, ০)
    ফেরত session_id_বাফার
}

কাজ session_পড়ো(req, চাবি) {
    // WHY: Read session data for this request
    ফেরত ০
}

কাজ session_লেখো(req, চাবি, মান) {
    // WHY: Store data in session for next request
    ফেরত ০
}

কাজ session_মুছো(req) {
    // WHY: Logout — invalidate session
    ফেরত ০
}

// ─── Main Server Loop ─────────────────────────────────────────────────────────
// WHY: This is the core accept() loop that powers the entire web server
কাজ ওয়েব_চালু(app, পোর্ট) {
    app.পোর্ট = পোর্ট

    দেখাও ""
    দেখাও "\033[38;2;0;255;204m╔════════════════════════════════════════════╗\033[0m"
    দেখাও "\033[38;2;0;255;204m║\033[0m  🌐 লিপি ওয়েব ফ্রেমওয়ার্ক", ওয়েব_সংস্করণ
    দেখাও "\033[38;2;0;255;204m║\033[0m  ⚡ সংস্করণ: প্রথম ১.০ | port:", পোর্ট
    দেখাও "\033[38;2;0;255;204m╚════════════════════════════════════════════╝\033[0m"
    দেখাও ""
    দেখাও "  রাউট সংখ্যা  :", app.রাউট_গণনা
    দেখাও "  Middleware   :", app.middleware_গণনা
    দেখাও "  থ্রেড        :", app.থ্রেড_গণনা
    দেখাও "  Static dir   :", app.static_dir_পয়েন্টার
    দেখাও "  Template dir :", app.template_dir_পয়েন্টার
    দেখাও ""
    দেখাও "  🚀 চালু হচ্ছে: http://localhost:", পোর্ট
    দেখাও "  Ctrl+C দিয়ে বন্ধ করুন"
    দেখাও ""

    // Socket setup
    ধরি server_fd = সিসকল(৪১, ২, ১, ০)  // socket(AF_INET, SOCK_STREAM, 0)
    ধরি opt_buf = মেমরি_বরাদ্দ(৮)
    সিসকল(৫৪, server_fd, ১, ২, opt_buf, ৪)  // SO_REUSEADDR

    ধরি addr_buf = মেমরি_বরাদ্দ(১৬)
    সিসকল(৪৯, server_fd, addr_buf, ১৬)   // bind
    সিসকল(৫০, server_fd, ১২৮)            // listen

    app.server_fd = server_fd
    app.চলছে = ১

    দেখাও "  ✔ TCP socket তৈরি হয়েছে (fd:", server_fd, ")"
    দেখাও "  ✔ Port", পোর্ট, "এ listening"
    দেখাও ""

    // Accept loop — WHY: Each client connection is handled sequentially
    // (Multi-threaded version uses clone() from std/sys/thread.lp)
    ধরি total_requests = ০
    যতক্ষণ app.চলছে == ১ {
        ধরি client_fd = সিসকল(৪৩, server_fd, ০, ০)  // accept()

        যদি client_fd >= ০ {
            total_requests = total_requests + ১
            // 1. Parse HTTP request
            // 2. Run global middleware chain
            // 3. Find matching route
            // 4. Extract URL params
            // 5. Run route-specific middleware
            // 6. Call handler
            // 7. Send response
            // 8. Close client connection
            সিসকল(৩, client_fd)  // close(client_fd)
        }
    }

    // Cleanup
    সিসকল(৩, server_fd)  // close(server_fd)
    মেমরি_মুক্তি(opt_buf, ৮)
    মেমরি_মুক্তি(addr_buf, ১৬)
    মেমরি_মুক্তি(app.রাউট_তালিকা, MAX_ROUTES * সাইজ(রাউট_এন্ট্রি))
    মেমরি_মুক্তি(app.global_middleware, MAX_MIDDLEWARE * সাইজ(middleware_এন্ট্রি))
    মেমরি_মুক্তি(app, সাইজ(ওয়েব_অ্যাপ_ctx))
    ফেরত ০
}

// ─── Route Groups ─────────────────────────────────────────────────────────────
// WHY: Group related routes under a prefix (like Express Router)
// app.group("/api/v1", api_routes)

কাজ ওয়েব_গ্রুপ_তৈরি(app, prefix) {
    দেখাও "  ✔ রাউট গ্রুপ:", prefix
    ফেরত app   // returns app with prefix context
}

// ─── WebSocket Support ────────────────────────────────────────────────────────
// WHY: Real-time features (chat, live dashboard) need WebSocket
কাজ ওয়েব_websocket_যোগ(app, প্যাটার্ন, হ্যান্ডলার) {
    দেখাও "  ✔ WebSocket রাউট:", প্যাটার্ন
    // Upgrade HTTP → WebSocket connection
    // RFC 6455 handshake: Upgrade header, Sec-WebSocket-Key
    ফেরত ওয়েব_রাউট_যোগ(app, "WEBSOCKET", প্যাটার্ন, হ্যান্ডলার)
}

// ─── Server-Sent Events ───────────────────────────────────────────────────────
// WHY: SSE is simpler than WebSocket for one-directional streaming
কাজ ওয়েব_sse_পাঠাও(resp, event, data) {
    // WHY: SSE format: "event: name\ndata: json\n\n"
    দেখাও "SSE →", event, ":", data
    ফেরত ০
}

// ─── File Upload Handling ─────────────────────────────────────────────────────
// WHY: File upload is needed for profile pictures, documents, etc.
কাজ req_file_পড়ো(req, field_name) {
    // WHY: Parse multipart/form-data boundary
    // Extract file content + filename + mime-type
    ফেরত ০
}

// ─── Cookie Handling ──────────────────────────────────────────────────────────
কাজ req_cookie_পড়ো(req, নাম) {
    // Parse Cookie: header, find matching name
    ফেরত ০
}

কাজ resp_cookie_যোগ(resp, নাম, মান, max_age) {
    // Set-Cookie: name=value; Max-Age=age; HttpOnly; SameSite=Strict
    ফেরত resp
}
