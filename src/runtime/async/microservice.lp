// ==============================================================================
// 👑 LIPI PRODUCTION ASYNCHRONOUS MICROSERVICE & JSON ENGINE (src/runtime/async/microservice.lp)
// ⚡ 100% Pure Lipi | Linux Kernel Epoll (Syscall 232) | Zero Libc / Zero Dependencies
// ==============================================================================
//
// WHY: Modern microservices in enterprise infrastructures (FinTech, Real-time APIs)
//      demand sub-millisecond response latency with predictable zero-GC pauses.
//      This module provides an event-driven HTTP/1.1 microservice server with native
//      JSON response construction, non-blocking I/O multiplexing, and robust error handling.
// ==============================================================================

include "src/runtime/lipi_syscall.lp"
include "src/runtime/lipi_arena.lp"

// ── Kernel Memory Allocator Primitives ────────────────────────────────────────
fn micro_malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn micro_free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

// ── Non-Blocking Socket Flag Configuration ───────────────────────────────────
// WHY: Sets O_NONBLOCK (0x800 = 2048) on file descriptors to prevent epoll worker stalls
fn micro_set_nonblocking fd
    flags = syscall(72, fd, 3, 0, 0, 0, 0) // F_GETFL = 3
    if flags < 0
        return flags
    return syscall(72, fd, 4, flags + 2048, 0, 0, 0) // F_SETFL = 4, O_NONBLOCK = 2048

// ── Server Socket Initialization ─────────────────────────────────────────────
// WHY: Binds and listens on 0.0.0.0:port with SO_REUSEADDR enabled
fn micro_create_listener port
    s_fd = syscall(41, 2, 1, 0, 0, 0, 0) // sys_socket(AF_INET=2, SOCK_STREAM=1, 0)
    if s_fd < 0
        return 0 - 1

    // sys_setsockopt(s_fd, SOL_SOCKET=1, SO_REUSEADDR=2, &1, 4)
    opt_buf = micro_malloc(8)
    mem_byte_write(opt_buf, 0, 1)
    mem_byte_write(opt_buf, 1, 0)
    mem_byte_write(opt_buf, 2, 0)
    mem_byte_write(opt_buf, 3, 0)
    syscall(54, s_fd, 1, 2, opt_buf, 4, 0)
    micro_free(opt_buf, 8)

    // sockaddr_in layout (16 bytes)
    addr_buf = micro_malloc(16)
    i = 0
    while i < 16
        mem_byte_write(addr_buf, i, 0)
        i = i + 1

    // AF_INET = 2
    mem_byte_write(addr_buf, 0, 2)
    mem_byte_write(addr_buf, 1, 0)

    // htons(port): network byte order
    p_hi = (port / 256) % 256
    p_lo = port % 256
    mem_byte_write(addr_buf, 2, p_hi)
    mem_byte_write(addr_buf, 3, p_lo)

    b_res = syscall(49, s_fd, addr_buf, 16, 0, 0, 0) // sys_bind
    micro_free(addr_buf, 16)
    if b_res < 0
        syscall(3, s_fd, 0, 0, 0, 0, 0) // close
        return 0 - 2

    l_res = syscall(50, s_fd, 256, 0, 0, 0, 0) // sys_listen(backlog=256)
    if l_res < 0
        syscall(3, s_fd, 0, 0, 0, 0, 0)
        return 0 - 3

    micro_set_nonblocking(s_fd)
    return s_fd

// ── Epoll Reactor Control ────────────────────────────────────────────────────
// Epoll event layout on Linux x86_64: 12 bytes
// offset 0: events (uint32)
// offset 4: pad/alignment (uint32)
// offset 8: data.fd (int32)
fn micro_epoll_add epfd fd events_mask
    ev_buf = micro_malloc(16)
    mem_byte_write(ev_buf, 0, events_mask % 256)
    mem_byte_write(ev_buf, 1, (events_mask / 256) % 256)
    mem_byte_write(ev_buf, 2, 0)
    mem_byte_write(ev_buf, 3, 0)
    mem_byte_write(ev_buf, 4, 0)
    mem_byte_write(ev_buf, 5, 0)
    mem_byte_write(ev_buf, 6, 0)
    mem_byte_write(ev_buf, 7, 0)
    mem_byte_write(ev_buf, 8, fd % 256)
    mem_byte_write(ev_buf, 9, (fd / 256) % 256)
    mem_byte_write(ev_buf, 10, (fd / 65536) % 256)
    mem_byte_write(ev_buf, 11, 0)

    res = syscall(233, epfd, 1, fd, ev_buf, 0, 0) // EPOLL_CTL_ADD = 1
    micro_free(ev_buf, 16)
    return res

fn micro_epoll_del epfd fd
    return syscall(233, epfd, 2, fd, 0, 0, 0) // EPOLL_CTL_DEL = 2

// ── HTTP Request Path Parser ─────────────────────────────────────────────────
// WHY: Extracts path substring from HTTP request line: "GET /path HTTP/1.1"
fn micro_parse_http_path req_buf req_len
    if req_len < 10 return ""
    // Check "GET "
    b0 = mem_byte_read(req_buf, 0)
    b1 = mem_byte_read(req_buf, 1)
    b2 = mem_byte_read(req_buf, 2)
    b3 = mem_byte_read(req_buf, 3)
    if b0 != 71 or b1 != 69 or b2 != 84 or b3 != 32 // "GET "
        return "UNKNOWN"

    // WHY: Scan for path between index 4 and next delimiter (space, ?, CR, LF)
    //      Accumulates characters into a typed Lipi string object for accurate string comparison.
    path_str = ""
    p = 4
    while p < req_len
        b = mem_byte_read(req_buf, p)
        if b == 32 or b == 63 or b == 13 or b == 10 // Space, ?, CR, LF
            break
        path_str = path_str + chr(b)
        p = p + 1

    if len(path_str) == 0
        return "/"

    return path_str

// ── HTTP Response Dispatcher ─────────────────────────────────────────────────
// WHY: Generates standards-compliant HTTP/1.1 response with application/json
fn micro_send_json client_fd status_code body_str
    status_text = "200 OK"
    if status_code == 404 status_text = "404 Not Found"
    elif status_code == 500 status_text = "500 Internal Server Error"

    body_len = len(body_str)
    header = "HTTP/1.1 " + status_text + "\r\n"
    header = header + "Content-Type: application/json\r\n"
    header = header + "Connection: close\r\n"
    header = header + "Server: Lipi-Sovereign-Async\r\n"
    header = header + "Content-Length: " + str(body_len) + "\r\n\r\n"

    full_resp = header + body_str
    r_len = len(full_resp)
    // WHY: Zero-copy direct memory write from string buffer to socket fd
    syscall(1, client_fd, full_resp, r_len, 0, 0, 0) // sys_write
    return 0

// ── Microservice Core Event Engine ───────────────────────────────────────────
// WHY: Runs the high-concurrency epoll loop, serving requests up to max_requests
fn microservice_run port max_requests
    listen_fd = micro_create_listener(port)
    if listen_fd < 0
        say "FAIL: Unable to bind listener on port " + str(port)
        return 0 - 1

    epfd = syscall(291, 0, 0, 0, 0, 0, 0) // sys_epoll_create1
    if epfd < 0
        say "FAIL: Unable to create epoll instance"
        syscall(3, listen_fd, 0, 0, 0, 0, 0)
        return 0 - 2

    // Add listening socket with EPOLLIN (1)
    micro_epoll_add(epfd, listen_fd, 1)

    say "👑 Lipi Sovereign Microservice running on 0.0.0.0:" + str(port)
    say "  • Max Request Threshold: " + str(max_requests)
    say "  • Architecture: Non-blocking Linux Epoll (Syscall 232)"

    max_events = 16
    event_size = 12
    events_buf = micro_malloc(max_events * event_size)
    req_buf = micro_malloc(4096)
    client_addr_buf = micro_malloc(32)

    served = 0
    running = 1
    start_time = clock_ms()

    while running == 1 and served < max_requests
        nfds = syscall(232, epfd, events_buf, max_events, 2000, 0, 0) // timeout = 2000ms
        if nfds < 0
            break

        ei = 0
        while ei < nfds
            ev_off = ei * event_size
            ev_flags = mem_byte_read(events_buf, ev_off)
            fd_lo = mem_byte_read(events_buf, ev_off + 8)
            fd_hi = mem_byte_read(events_buf, ev_off + 9)
            curr_fd = fd_lo + (fd_hi * 256)

            if curr_fd == listen_fd
                // Accept incoming client connection
                addr_len_buf = micro_malloc(8)
                mem_byte_write(addr_len_buf, 0, 16)
                c_fd = syscall(43, listen_fd, client_addr_buf, addr_len_buf, 0, 0, 0) // sys_accept
                micro_free(addr_len_buf, 8)

                if c_fd >= 0
                    micro_set_nonblocking(c_fd)
                    micro_epoll_add(epfd, c_fd, 1) // Add with EPOLLIN
            else
                // Read client request
                n_read = syscall(0, curr_fd, req_buf, 4096, 0, 0, 0) // sys_read
                if n_read > 0
                    path = micro_parse_http_path(req_buf, n_read)

                    // Route 1: /health
                    if path == "/health" or path == "/api/health"
                        body = "{\"status\":\"UP\",\"engine\":\"Lipi Sovereign\",\"version\":\"1.0\"}"
                        micro_send_json(curr_fd, 200, body)
                    // Route 2: /metrics
                    elif path == "/metrics" or path == "/api/metrics"
                        uptime = clock_ms() - start_time
                        body = "{\"uptime_ms\":" + str(uptime) + ",\"requests_served\":" + str(served + 1) + ",\"arch\":\"x86_64\"}"
                        micro_send_json(curr_fd, 200, body)
                    // Route 3: /api/bench (Vectorized SIMD Analytics Endpoint)
                    elif path == "/api/bench"
                        t0 = cpu_clock()
                        // 10,000 element calculation
                        n_elem = 10000
                        b_buf = micro_malloc(n_elem * 8)
                        bi = 0
                        while bi < n_elem
                            sys_poke(b_buf + (bi * 8), bi % 100)
                            bi = bi + 1
                        sum_val = simd_avx2_sum(b_buf, n_elem)
                        micro_free(b_buf, n_elem * 8)
                        t1 = cpu_clock()
                        body = "{\"benchmark\":\"AVX2 Vector Scan\",\"elements\":" + str(n_elem) + ",\"sum\":" + str(sum_val) + ",\"cycles\":" + str(t1 - t0) + "}"
                        micro_send_json(curr_fd, 200, body)
                    // Default: 404 Not Found
                    else
                        body = "{\"error\":\"Route Not Found\",\"path\":\"" + path + "\",\"code\":404}"
                        micro_send_json(curr_fd, 404, body)

                    served = served + 1

                // Cleanly remove from epoll and close client socket
                micro_epoll_del(epfd, curr_fd)
                syscall(3, curr_fd, 0, 0, 0, 0, 0) // sys_close

            ei = ei + 1

    say "✔ Served " + str(served) + " requests cleanly. Shutting down microservice."

    // Cleanup resources
    micro_free(events_buf, max_events * event_size)
    micro_free(req_buf, 4096)
    micro_free(client_addr_buf, 32)
    syscall(3, listen_fd, 0, 0, 0, 0, 0)
    syscall(3, epfd, 0, 0, 0, 0, 0)
    return served
