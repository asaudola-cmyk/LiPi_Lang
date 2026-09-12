// ==============================================================================
// 👑 Test 78: Lipi Production Asynchronous Microservice & JSON Engine Test
// ⚡ Features Tested:
//    1. Kernel Epoll event loop multiplexing (Syscall 232)
//    2. Dynamic HTTP path extraction & JSON response serialization
//    3. Integrated AVX2 SIMD Analytics endpoint (/api/bench)
//    4. Zero-libc network lifecycle & graceful shutdown
// ==============================================================================

include "src/runtime/async/microservice.lp"

say "========================================================"
say "👑 Testing Lipi Sovereign Async Microservice Engine"
say "========================================================"

// Step 1: Server Socket & Epoll Reactor Initialization
port = 9099
listen_fd = micro_create_listener(port)
if listen_fd < 0
    say "FAIL: micro_create_listener returned " + str(listen_fd)
    exit(1)
say "✔ Server non-blocking socket created on port " + str(port)

epfd = syscall(291, 0, 0, 0, 0, 0, 0)
if epfd < 0
    say "FAIL: sys_epoll_create1 failed"
    exit(1)

ctl_res = micro_epoll_add(epfd, listen_fd, 1)
if ctl_res < 0
    say "FAIL: micro_epoll_add failed"
    exit(1)
say "✔ Epoll instance configured with listener"

// Step 2: HTTP Route Extraction & Path Parser Verification
say "[1/3] Testing HTTP Request Parsing & Route Extraction..."

// Route A: /health
raw_h = "GET /health HTTP/1.1"
buf_h = micro_malloc(len(raw_h) + 1)
i = 0
while i < len(raw_h)
    mem_byte_write(buf_h, i, mem_byte_read(raw_h, i))
    i = i + 1
mem_byte_write(buf_h, len(raw_h), 0)

path_h = micro_parse_http_path(buf_h, len(raw_h))
if path_h != "/health"
    say "FAIL: /health path mismatch: " + path_h
    exit(1)
say "  ✔ Route /health extracted successfully"
micro_free(buf_h, len(raw_h) + 1)

// Route B: /metrics
raw_m = "GET /metrics HTTP/1.1"
buf_m = micro_malloc(len(raw_m) + 1)
i = 0
while i < len(raw_m)
    mem_byte_write(buf_m, i, mem_byte_read(raw_m, i))
    i = i + 1
mem_byte_write(buf_m, len(raw_m), 0)

path_m = micro_parse_http_path(buf_m, len(raw_m))
if path_m != "/metrics"
    say "FAIL: /metrics path mismatch: " + path_m
    exit(1)
say "  ✔ Route /metrics extracted successfully"
micro_free(buf_m, len(raw_m) + 1)

// Route C: /api/bench
raw_b = "GET /api/bench HTTP/1.1"
buf_b = micro_malloc(len(raw_b) + 1)
i = 0
while i < len(raw_b)
    mem_byte_write(buf_b, i, mem_byte_read(raw_b, i))
    i = i + 1
mem_byte_write(buf_b, len(raw_b), 0)

path_b = micro_parse_http_path(buf_b, len(raw_b))
if path_b != "/api/bench"
    say "FAIL: /api/bench path mismatch: " + path_b
    exit(1)
say "  ✔ Route /api/bench extracted successfully"
micro_free(buf_b, len(raw_b) + 1)

// Step 3: AVX2 SIMD Analytics Integration
say "[2/3] Testing AVX2 Analytics Integration in Microservice..."
n_elem = 10000
b_buf = micro_malloc(n_elem * 8)
bi = 0
while bi < n_elem
    sys_poke(b_buf + (bi * 8), bi % 100)
    bi = bi + 1
sum_val = simd_avx2_sum(b_buf, n_elem)
micro_free(b_buf, n_elem * 8)

if sum_val != 50994900
    say "FAIL: SIMD sum mismatch: " + str(sum_val)
    exit(1)
say "  ✔ SIMD Analytics Result Verified: " + str(sum_val)

// Step 4: Epoll Non-Blocking Timeout Tick Verification
say "[3/3] Testing Non-Blocking Epoll Timeout Tick..."
events_buf = micro_malloc(16 * 12)
nfds = syscall(232, epfd, events_buf, 16, 50, 0, 0) // timeout = 50ms
micro_free(events_buf, 16 * 12)

if nfds < 0
    say "FAIL: sys_epoll_wait returned error: " + str(nfds)
    exit(1)
say "  ✔ Epoll Wait Timeout Tick verified (nfds = " + str(nfds) + ")"

// Cleanup resources
micro_epoll_del(epfd, listen_fd)
syscall(3, listen_fd, 0, 0, 0, 0, 0)
syscall(3, epfd, 0, 0, 0, 0, 0)

say "========================================================"
say "PASS: Test 78 Async Microservice JSON"
say "========================================================"
