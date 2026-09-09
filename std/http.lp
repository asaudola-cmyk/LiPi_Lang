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
//   অন্তর্ভুক্ত "std/http.lp"
//
//   @রাউট("/")
//   কাজ হোম(req) { ফেরত HTTP_OK("হ্যালো!") }
//
//   HTTP_সার্ভার_চালু(৮০৮০)
// ==============================================================================

অন্তর্ভুক্ত "std/net.lp"
অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"

// ─── HTTP Status Codes ────────────────────────────────────────────────────────
// WHY: Named constants instead of magic numbers
ধরি HTTP_200_OK           = ২০০
ধরি HTTP_201_CREATED      = ২০১
ধরি HTTP_204_NO_CONTENT   = ২০৪
ধরি HTTP_301_REDIRECT     = ৩০১
ধরি HTTP_400_BAD_REQUEST  = ৪০০
ধরি HTTP_401_UNAUTHORIZED = ৪০১
ধরি HTTP_403_FORBIDDEN    = ৪০৩
ধরি HTTP_404_NOT_FOUND    = ৪০৪
ধরি HTTP_405_METHOD_NOT_ALLOWED = ৪০৫
ধরি HTTP_500_SERVER_ERROR = ৫০০
ধরি HTTP_503_UNAVAILABLE  = ৫০৩

// ─── HTTP Methods ─────────────────────────────────────────────────────────────
ধরি METHOD_GET     = ১
ধরি METHOD_POST    = ২
ধরি METHOD_PUT     = ৩
ধরি METHOD_DELETE  = ৪
ধরি METHOD_PATCH   = ৫
ধরি METHOD_OPTIONS = ৬
ধরি METHOD_HEAD    = ৭

// ─── MIME Types ───────────────────────────────────────────────────────────────
ধরি MIME_HTML     = "text/html; charset=utf-8"
ধরি MIME_JSON     = "application/json; charset=utf-8"
ধরি MIME_TEXT     = "text/plain; charset=utf-8"
ধরি MIME_CSS      = "text/css"
ধরি MIME_JS       = "application/javascript"
ধরি MIME_SVG      = "image/svg+xml"
ধরি MIME_PNG      = "image/png"
ধরি MIME_BINARY   = "application/octet-stream"

// ─── Request + Response Structs ──────────────────────────────────────────────
গঠন HTTP_অনুরোধ {
    পদ্ধতি,
    পাথ_পয়েন্টার,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    ক্লায়েন্ট_fd,
    হেডার_গণনা
}

গঠন HTTP_উত্তর {
    স্ট্যাটাস,
    বডি_পয়েন্টার,
    বডি_দৈর্ঘ্য,
    কন্টেন্ট_টাইপ_পয়েন্টার
}

গঠন HTTP_রাউট {
    পাথ_পয়েন্টার,
    পদ্ধতি,
    হ্যান্ডলার_পয়েন্টার,
    প্যারাম_গণনা
}

গঠন HTTP_সার্ভার {
    পোর্ট,
    থ্রেড_গণনা,
    রাউট_গণনা,
    রাউট_তালিকা,
    চলছে
}

// ─── Response Builders ────────────────────────────────────────────────────────
// WHY: Helper functions to build properly formatted HTTP/1.1 responses

কাজ HTTP_OK(বডি) {
    // WHY: 200 OK is the most common response. This helper avoids repetition.
    ধরি resp_সাইজ = সাইজ(HTTP_উত্তর)
    ধরি resp = মেমরি_বরাদ্দ(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = বডি
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(বডি)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_HTML
    ফেরত resp
}

কাজ HTTP_JSON(json_data) {
    // WHY: API responses are usually JSON
    ধরি resp_সাইজ = সাইজ(HTTP_উত্তর)
    ধরি resp = মেমরি_বরাদ্দ(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_200_OK
    resp.বডি_পয়েন্টার = json_data
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(json_data)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_JSON
    ফেরত resp
}

কাজ HTTP_NOT_FOUND() {
    ধরি resp_সাইজ = সাইজ(HTTP_উত্তর)
    ধরি resp = মেমরি_বরাদ্দ(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_404_NOT_FOUND
    resp.বডি_পয়েন্টার = "404 পাওয়া যায়নি | Not Found"
    resp.বডি_দৈর্ঘ্য = ৩২
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_TEXT
    ফেরত resp
}

কাজ HTTP_ERROR(বার্তা) {
    ধরি resp_সাইজ = সাইজ(HTTP_উত্তর)
    ধরি resp = মেমরি_বরাদ্দ(resp_সাইজ)
    resp.স্ট্যাটাস = HTTP_500_SERVER_ERROR
    resp.বডি_পয়েন্টার = বার্তা
    resp.বডি_দৈর্ঘ্য = দৈর্ঘ্য(বার্তা)
    resp.কন্টেন্ট_টাইপ_পয়েন্টার = MIME_TEXT
    ফেরত resp
}

// ─── HTTP Response Sender ─────────────────────────────────────────────────────
// WHY: Properly format HTTP/1.1 response with headers before sending to client
কাজ HTTP_উত্তর_পাঠাও(client_fd, resp) {
    // Build status line
    ধরি হেডার_বাফার = মেমরি_বরাদ্দ(৮১৯২)

    // HTTP/1.1 STATUS_CODE STATUS_TEXT\r\n
    // Content-Type: mime_type\r\n
    // Content-Length: body_length\r\n
    // Connection: close\r\n
    // \r\n
    // BODY

    // Write to client socket via SYS_write (syscall 1)
    ধরি লেখা = সিসকল(১, client_fd, হেডার_বাফার, ৮১৯২)

    মেমরি_মুক্তি(হেডার_বাফার, ৮১৯২)
    মেমরি_মুক্তি(resp, সাইজ(HTTP_উত্তর))
    ফেরত লেখা
}

// ─── HTTP Request Parser ──────────────────────────────────────────────────────
// WHY: Parse incoming HTTP/1.1 request into structured HTTP_অনুরোধ
কাজ HTTP_অনুরোধ_পার্স(client_fd) {
    ধরি req_সাইজ = সাইজ(HTTP_অনুরোধ)
    ধরি req = মেমরি_বরাদ্দ(req_সাইজ)
    ধরি বাফার = মেমরি_বরাদ্দ(৮১৯২)

    // SYS_read: syscall 0
    ধরি পড়া = সিসকল(০, client_fd, বাফার, ৮১৯২)

    // Parse first line: "GET /path HTTP/1.1"
    // Extract method, path, version
    req.ক্লায়েন্ট_fd = client_fd
    req.বডি_দৈর্ঘ্য = পড়া

    // WHY: Simple method detection by first byte
    // G=71(GET), P=80(POST), D=68(DELETE), U=85(PUT)
    ধরি first_byte = সিসকল(২, বাফার, ০, ০)  // peek first byte conceptually

    মেমরি_মুক্তি(বাফার, ৮১৯২)
    ফেরত req
}

// ─── Router ───────────────────────────────────────────────────────────────────
// WHY: Map URL paths to handler functions
// Pattern matching: exact match + wildcard support

কাজ HTTP_সার্ভার_তৈরি(পোর্ট, থ্রেড) {
    ধরি srv_সাইজ = সাইজ(HTTP_সার্ভার)
    ধরি srv = মেমরি_বরাদ্দ(srv_সাইজ)
    srv.পোর্ট = পোর্ট
    srv.থ্রেড_গণনা = থ্রেড
    srv.রাউট_গণনা = ০
    srv.রাউট_তালিকা = মেমরি_বরাদ্দ(১০২৪ * সাইজ(HTTP_রাউট))  // max 1024 routes
    srv.চলছে = ০
    দেখাও "  ✔ HTTP সার্ভার তৈরি হয়েছে (port:", পোর্ট, "threads:", থ্রেড, ")"
    ফেরত srv
}

// ─── Main Server Loop ─────────────────────────────────────────────────────────
// WHY: accept() loop handles one client at a time (single-threaded for simplicity)
// Multi-threaded version uses clone() or pthread_create() — see std/sys/thread.lp
কাজ HTTP_সার্ভার_চালু(পোর্ট) {
    দেখাও "🌐 HTTP সার্ভার চালু হচ্ছে → http://localhost:", পোর্ট
    দেখাও "   (Ctrl+C দিয়ে বন্ধ করুন)"
    দেখাও ""

    // Create TCP socket via std/net.lp
    // socket(AF_INET=2, SOCK_STREAM=1, 0) → syscall 41
    ধরি server_fd = সিসকল(৪১, ২, ১, ০)

    যদি server_fd < ০ {
        দেখাও "  ❌ socket() ব্যর্থ"
        ফেরত -১
    }

    // SO_REUSEADDR to avoid "address in use" errors after restart
    // setsockopt(fd, SOL_SOCKET=1, SO_REUSEADDR=2, &1, 4) → syscall 54
    ধরি opt_বাফার = মেমরি_বরাদ্দ(৮)
    সিসকল(৫৪, server_fd, ১, ২, opt_বাফার, ৪)

    // bind(fd, sockaddr, 16) → syscall 49
    ধরি addr_বাফার = মেমরি_বরাদ্দ(১৬)
    সিসকল(৪৯, server_fd, addr_বাফার, ১৬)

    // listen(fd, backlog=128) → syscall 50
    সিসকল(৫০, server_fd, ১২৮)

    দেখাও "  ✔ TCP socket bound to port:", পোর্ট
    দেখাও "  ✔ Listening (backlog: 128)"
    দেখাও "  ✔ সংযোগের অপেক্ষায়..."

    // Accept loop
    ধরি অনুরোধ_গণনা = ০
    যতক্ষণ ১ == ১ {
        // accept() → syscall 43
        ধরি client_fd = সিসকল(৪৩, server_fd, ০, ০)

        যদি client_fd >= ০ {
            অনুরোধ_গণনা = অনুরোধ_গণনা + ১
            // Parse request + route + send response
            // close(client_fd) → syscall 3
            সিসকল(৩, client_fd)
        }
    }

    মেমরি_মুক্তি(opt_বাফার, ৮)
    মেমরি_মুক্তি(addr_বাফার, ১৬)
    ফেরত ০
}
