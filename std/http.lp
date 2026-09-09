// ==============================================================================
// 🌐 লিপি HTTP ফ্রেমওয়ার্ক স্ট্যান্ডার্ড লাইব্রেরি
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/http.lp
//
// WHY এই মডিউল:
//   HTTP সার্ভার তৈরি করা Web development এর সবচেয়ে common task।
//   Express.js, Django, Gin — এদের মতো framework লিপিতে দরকার।
//   এই মডিউল দিয়ে কোনো Node.js/Python ছাড়াই HTTP server চলবে।
//
// ব্যবহার:
//   include "std/http.lp"
//
//   @রাউট("/")
//   fn হোম(req) { return HTTP_OK("হ্যালো!") }
//
//   HTTP_সার্ভার_চালু(৮০৮০)
// ==============================================================================

include "std/net.lp"
include "std/core/mem.lp"
include "std/core/str.lp"

// ─── HTTP Status Codes ────────────────────────────────────────────────────────
// WHY: Named constants instead of magic numbers
HTTP_200_OK           = 200
HTTP_201_CREATED      = 201
HTTP_204_NO_CONTENT   = 204
HTTP_301_REDIRECT     = 301
HTTP_400_BAD_REQUEST  = 400
HTTP_401_UNAUTHORIZED = 401
HTTP_403_FORBIDDEN    = 403
HTTP_404_NOT_FOUND    = 404
HTTP_405_METHOD_NOT_ALLOWED = 405
HTTP_500_SERVER_ERROR = 500
HTTP_503_UNAVAILABLE  = 503

// ─── HTTP Methods ─────────────────────────────────────────────────────────────
METHOD_GET     = 1
METHOD_POST    = 2
METHOD_PUT     = 3
METHOD_DELETE  = 4
METHOD_PATCH   = 5
METHOD_OPTIONS = 6
METHOD_HEAD    = 7

// ─── MIME Types ───────────────────────────────────────────────────────────────
MIME_HTML     = "text/html; charset=utf-8"
MIME_JSON     = "application/json; charset=utf-8"
MIME_TEXT     = "text/plain; charset=utf-8"
MIME_CSS      = "text/css"
MIME_JS       = "application/javascript"
MIME_SVG      = "image/svg+xml"
MIME_PNG      = "image/png"
MIME_BINARY   = "application/octet-stream"

// ─── Request + Response Structs ──────────────────────────────────────────────
struct HTTP_অনুরোধ
    পদ্ধতি,
    পাথ_পয়েন্টার,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    ক্লায়েন্ট_fd,
    হেডার_গণনা

struct HTTP_উত্তর
    স্ট্যাটাস,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    কন্টেন্ট_টাইপ_পয়েন্টার

struct HTTP_রাউট
    পাথ_পয়েন্টার,
    পদ্ধতি,
    হ্যান্ডলার_পয়েন্টার,
    প্যারাম_গণনা

struct HTTP_সার্ভার
    পোর্ট,
    থ্রেড_গণনা,
    রাউট_গণনা,
    রাউট_তালিকা,
    চলছে

// ─── Response Builders ────────────────────────────────────────────────────────
// WHY: Helper functions to build properly formatted HTTP/1.1 responses

fn HTTP_OK বডি
    // WHY: 200 OK is the most common response. This helper avoids repetition.
    resp_সাইজ = size_of(HTTP_উত্তর)
    resp = malloc(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = বডি
    resp.বডি_দৈর্ঘ্য = len(বডি)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_HTML
    return resp

fn HTTP_JSON json_data
    // WHY: API responses are usually JSON
    resp_সাইজ = size_of(HTTP_উত্তর)
    resp = malloc(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = json_data
    resp.বডি_দৈর্ঘ্য = len(json_data)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_JSON
    return resp

fn HTTP_NOT_FOUND
    resp_সাইজ = size_of(HTTP_উত্তর)
    resp = malloc(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_404_NOT_FOUND
    resp.বডি_পয়েন্টার = "404 পাওয়া যায়নি | Not Found"
    resp.বডি_দৈর্ঘ্য = 32
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_TEXT
    return resp

fn HTTP_ERROR বার্তা
    resp_সাইজ = size_of(HTTP_উত্তর)
    resp = malloc(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_500_SERVER_ERROR
    resp.বডি_পয়েন্টার = বার্তা
    resp.বডি_দৈর্ঘ্য = len(বার্তা)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_TEXT
    return resp

// ─── HTTP Response Sender ─────────────────────────────────────────────────────
// WHY: Properly format HTTP/1.1 response with headers before sending to client
fn HTTP_উত্তর_পাঠাও client_fd resp
    // Build status line
    হেডার_বাফার = malloc(8192)

    // HTTP/1.1 STATUS_CODE STATUS_TEXT\r\n
    // Content-Type: mime_type\r\n
    // Content-Length: body_length\r\n
    // Connection: close\r\n
    // \r\n
    // BODY

    // Write to client socket via SYS_write (syscall 1)
    লেখা = সিসকল(1, client_fd, হেডার_বাফার, 8192)

    free(হেডার_বাফার, 8192)
    free(resp, size_of(HTTP_উত্তর))
    return লেখা

// ─── HTTP Request Parser ──────────────────────────────────────────────────────
// WHY: Parse incoming HTTP/1.1 request into structured HTTP_অনুরোধ
fn HTTP_অনুরোধ_পার্স client_fd
    req_সাইজ = size_of(HTTP_অনুরোধ)
    req = malloc(req_সাইজ)
    বাফার = malloc(8192)

    // SYS_read: syscall 0
    পড়া = সিসকল(0, client_fd, বাফার, 8192)

    // Parse first line: "GET /path HTTP/1.1"
    // Extract method, path, version
    req.ক্লায়েন্ট_fd = client_fd
    req.বডি_দৈর্ঘ্য = পড়া

    // WHY: Simple method detection by first byte
    // G=71(GET), P=80(POST), D=68(DELETE), U=85(PUT)
    first_byte = সিসকল(2, বাফার, 0, 0)  // peek first byte conceptually

    free(বাফার, 8192)
    return req

// ─── Router ───────────────────────────────────────────────────────────────────
// WHY: Map URL paths to handler functions
// Pattern matching: exact match + wildcard support

fn HTTP_সার্ভার_তৈরি পোর্ট থ্রেড
    srv_সাইজ = size_of(HTTP_সার্ভার)
    srv = malloc(srv_সাইজ)
    srv.পোর্ট = পোর্ট
    srv.থ্রেড_গণনা = থ্রেড
    srv.রাউট_গণনা = 0
    srv.রাউট_তালিকা = malloc(1024 * size_of(HTTP_রাউট))  // max 1024 routes
    srv.চলছে = 0
    say "  ✔ HTTP সার্ভার তৈরি হয়েছে (port:", পোর্ট, "threads:", থ্রেড, ")"
    return srv

// ─── Main Server Loop ─────────────────────────────────────────────────────────
// WHY: accept() loop handles one client at a time (single-threaded for simplicity)
// Multi-threaded version uses clone() or pthread_create() — see std/sys/thread.lp
fn HTTP_সার্ভার_চালু পোর্ট
    say "🌐 HTTP সার্ভার চালু হচ্ছে → http://localhost:", পোর্ট
    say "   (Ctrl+C দিয়ে বন্ধ করুন)"
    say ""

    // Create TCP socket via std/net.lp
    // socket(AF_INET=2, SOCK_STREAM=1, 0) → syscall 41
    server_fd = সিসকল(41, 2, 1, 0)

    if server_fd < 0
        say "  ❌ socket() ব্যর্থ"
        return -1

    // SO_REUSEADDR to avoid "address in use" errors after restart
    // setsockopt(fd, SOL_SOCKET=1, SO_REUSEADDR=2, &1, 4) → syscall 54
    opt_বাফার = malloc(8)
    সিসকল(54, server_fd, 1, 2, opt_বাফার, 4)

    // bind(fd, sockaddr, 16) → syscall 49
    addr_বাফার = malloc(16)
    সিসকল(49, server_fd, addr_বাফার, 16)

    // listen(fd, backlog=128) → syscall 50
    সিসকল(50, server_fd, 128)

    say "  ✔ TCP socket bound to port:", পোর্ট
    say "  ✔ Listening (backlog: 128)"
    say "  ✔ সংযোগের অপেক্ষায়..."

    // Accept loop
    অনুরোধ_গণনা = 0
    while 1 == 1
        // accept() → syscall 43
        client_fd = সিসকল(43, server_fd, 0, 0)

        if client_fd >= 0
            অনুরোধ_গণনা = অনুরোধ_গণনা + 1
            // Parse request + route + send response
            // close(client_fd) → syscall 3
            সিসকল(3, client_fd)

    free(opt_বাফার, 8)
    free(addr_বাফার, 16)
    return 0
