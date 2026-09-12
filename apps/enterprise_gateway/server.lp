// ==============================================================================
// 👑 LIPI ENTERPRISE ASYNCHRONOUS GATEWAY & REST MICROSERVICE
// ⚡ File: apps/enterprise_gateway/server.lp
//
// WHY: Demonstrates a 100% sovereign, zero-libc enterprise microservice server
//      built entirely in pure Lipi. Provides sub-millisecond REST API routing,
//      kernel Epoll multiplexing, in-memory KV caching, and AVX2 SIMD acceleration.
//
// 100% Pure Lipi | 0% C | 0% GCC | 0% Libc | 0% Python | Linux Syscalls
// ==============================================================================

import "universe/lipi_universe"
import "universe/db/kv"

// ── Low-Level Memory Helpers ──────────────────────────────────────────────────
fn gw_malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn gw_free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

// ── Socket Non-Blocking Configuration ─────────────────────────────────────────
// WHY: Prevents worker threads from blocking indefinitely when reading incomplete frames.
fn gw_set_nonblocking fd
    flags = syscall(72, fd, 3, 0, 0, 0, 0) // F_GETFL = 3
    if flags < 0 return flags
    return syscall(72, fd, 4, flags + 2048, 0, 0, 0) // F_SETFL = 4, O_NONBLOCK = 2048

// ── Production Server Socket Setup ────────────────────────────────────────────
// WHY: Creates TCP socket with SO_REUSEADDR to avoid \"Address already in use\" traps.
fn gw_create_listener port
    s_fd = syscall(41, 2, 1, 0, 0, 0, 0) // sys_socket(AF_INET=2, SOCK_STREAM=1, 0)
    if s_fd < 0 return 0 - 1

    // sys_setsockopt(s_fd, SOL_SOCKET=1, SO_REUSEADDR=2, &1, 4)
    opt_buf = gw_malloc(8)
    mem_byte_write(opt_buf, 0, 1)
    mem_byte_write(opt_buf, 1, 0)
    mem_byte_write(opt_buf, 2, 0)
    mem_byte_write(opt_buf, 3, 0)
    syscall(54, s_fd, 1, 2, opt_buf, 4, 0)
    gw_free(opt_buf, 8)

    // sockaddr_in (16 bytes)
    addr_buf = gw_malloc(16)
    i = 0
    while i < 16
        mem_byte_write(addr_buf, i, 0)
        i = i + 1

    mem_byte_write(addr_buf, 0, 2) // AF_INET
    mem_byte_write(addr_buf, 1, 0)

    // htons(port)
    p_hi = (port / 256) % 256
    p_lo = port % 256
    mem_byte_write(addr_buf, 2, p_hi)
    mem_byte_write(addr_buf, 3, p_lo)

    b_res = syscall(49, s_fd, addr_buf, 16, 0, 0, 0) // sys_bind
    gw_free(addr_buf, 16)
    if b_res < 0
        syscall(3, s_fd, 0, 0, 0, 0, 0)
        return 0 - 2

    l_res = syscall(50, s_fd, 512, 0, 0, 0, 0) // sys_listen(backlog=512)
    if l_res < 0
        syscall(3, s_fd, 0, 0, 0, 0, 0)
        return 0 - 3

    gw_set_nonblocking(s_fd)
    return s_fd

// ── Epoll Reactor Multiplexing ────────────────────────────────────────────────
fn gw_epoll_add epfd fd events_mask
    ev_buf = gw_malloc(16)
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
    gw_free(ev_buf, 16)
    return res

fn gw_epoll_del epfd fd
    return syscall(233, epfd, 2, fd, 0, 0, 0) // EPOLL_CTL_DEL = 2

// ── HTTP Method & Path Parser ─────────────────────────────────────────────────
fn gw_parse_method_and_path req_buf req_len
    if req_len < 6 return list()

    is_get = 0
    is_post = 0
    start_path = 0

    // Check GET
    if mem_byte_read(req_buf, 0) == 71 and mem_byte_read(req_buf, 1) == 69 and mem_byte_read(req_buf, 2) == 84 and mem_byte_read(req_buf, 3) == 32
        is_get = 1
        start_path = 4
    // Check POST
    elif mem_byte_read(req_buf, 0) == 80 and mem_byte_read(req_buf, 1) == 79 and mem_byte_read(req_buf, 2) == 83 and mem_byte_read(req_buf, 3) == 84 and mem_byte_read(req_buf, 4) == 32
        is_post = 1
        start_path = 5
    else
        return list()

    path = ""
    p = start_path
    while p < req_len
        b = mem_byte_read(req_buf, p)
        if b == 32 or b == 63 or b == 13 or b == 10
            break
        path = path + chr(b)
        p = p + 1

    res = list()
    if is_get == 1
        push(res, "GET")
    else
        push(res, "POST")
    push(res, path)
    return res

// ── JSON Response Dispatcher ──────────────────────────────────────────────────
fn gw_send_json client_fd status_code body_str
    status_text = "200 OK"
    if status_code == 201 status_text = "201 Created"
    elif status_code == 400 status_text = "400 Bad Request"
    elif status_code == 404 status_text = "404 Not Found"
    elif status_code == 500 status_text = "500 Internal Server Error"

    body_len = len(body_str)
    header = "HTTP/1.1 " + status_text + "\r\n"
    header = header + "Content-Type: application/json\r\n"
    header = header + "Connection: close\r\n"
    header = header + "Server: Lipi-Enterprise-Gateway/2.5\r\n"
    header = header + "Content-Length: " + str(body_len) + "\r\n\r\n"

    full_resp = header + body_str
    r_len = len(full_resp)
    syscall(1, client_fd, full_resp, r_len, 0, 0, 0) // sys_write
    return 0

// ── Main Server Dispatcher Loop ───────────────────────────────────────────────
fn start_gateway_server port max_requests
    listen_fd = gw_create_listener(port)
    if listen_fd < 0
        say "FAIL: Unable to bind listener on port " + str(port)
        return 0 - 1

    epfd = syscall(291, 0, 0, 0, 0, 0, 0) // sys_epoll_create1
    if epfd < 0
        syscall(3, listen_fd, 0, 0, 0, 0, 0)
        say "FAIL: sys_epoll_create1 failed"
        return 0 - 2

    gw_epoll_add(epfd, listen_fd, 1)

    // In-memory Database Store initialization
    kv_db = KV_create(256)
    KV_set(kv_db, "user:1", "Shafiullah (Admin)")
    KV_set(kv_db, "user:2", "Lipi Developer")

    say "=================================================================="
    say "👑 LIPI ENTERPRISE ASYNCHRONOUS GATEWAY ACTIVE"
    say "=================================================================="
    say "  • Host Port     : 0.0.0.0:" + str(port)
    say "  • Epoll Engine  : Linux Kernel Epoll (Syscall 232)"
    say "  • KV Cache      : In-Memory Sovereign Hash Store"
    say "  • Acceleration  : AVX2 256-Bit SIMD Kernel"
    say "  • Memory Model  : Zero-GC / Sovereign Arena"
    say "=================================================================="

    max_events = 32
    event_size = 12
    events_buf = gw_malloc(max_events * event_size)
    req_buf = gw_malloc(8192)
    client_addr_buf = gw_malloc(32)

    served = 0
    start_time = clock_ms()

    while served < max_requests
        nfds = syscall(232, epfd, events_buf, max_events, 2000, 0, 0)
        if nfds < 0 break

        ei = 0
        while ei < nfds
            ev_off = ei * event_size
            curr_fd = mem_byte_read(events_buf, ev_off + 8) + (mem_byte_read(events_buf, ev_off + 9) * 256)

            if curr_fd == listen_fd
                addr_len_buf = gw_malloc(8)
                mem_byte_write(addr_len_buf, 0, 16)
                c_fd = syscall(43, listen_fd, client_addr_buf, addr_len_buf, 0, 0, 0) // sys_accept
                gw_free(addr_len_buf, 8)

                if c_fd >= 0
                    gw_set_nonblocking(c_fd)
                    gw_epoll_add(epfd, c_fd, 1)
            else
                n_read = syscall(0, curr_fd, req_buf, 8192, 0, 0, 0)
                if n_read > 0
                    parsed = gw_parse_method_and_path(req_buf, n_read)
                    if len(parsed) >= 2
                        method = get(parsed, 0)
                        path = get(parsed, 1)

                        // Route 1: GET /health
                        if path == "/health" or path == "/api/health"
                            body = "{\"status\":\"UP\",\"engine\":\"Lipi Sovereign Enterprise\",\"version\":\"2.5.0\",\"uptime_ms\":" + str(clock_ms() - start_time) + "}"
                            gw_send_json(curr_fd, 200, body)

                        // Route 2: GET /api/v1/metrics
                        elif path == "/api/v1/metrics"
                            body = "{\"uptime_ms\":" + str(clock_ms() - start_time) + ",\"requests_served\":" + str(served + 1) + ",\"arch\":\"x86_64\",\"zero_libc\":true}"
                            gw_send_json(curr_fd, 200, body)

                        // Route 3: GET /api/v1/users (Explicit method check prevents collision with POST)
                        elif method == "GET" and path == "/api/v1/users"
                            u1 = KV_get(kv_db, "user:1")
                            u2 = KV_get(kv_db, "user:2")
                            body = "{\"users\":[{\"id\":1,\"name\":\"" + u1 + "\"},{\"id\":2,\"name\":\"" + u2 + "\"}]}"
                            gw_send_json(curr_fd, 200, body)

                        // Route 4: POST /api/v1/users
                        elif method == "POST" and path == "/api/v1/users"
                            new_id = served + 100
                            token = crypto_sha256_hex("user_token_" + str(new_id))
                            KV_set(kv_db, "user:" + str(new_id), "User_" + str(new_id))
                            body = "{\"success\":true,\"id\":" + str(new_id) + ",\"token\":\"" + token + "\",\"message\":\"User stored in sovereign KV\"}"
                            gw_send_json(curr_fd, 201, body)

                        // Route 5: GET /api/v1/simd/bench
                        elif path == "/api/v1/simd/bench"
                            t0 = cpu_clock()
                            n_elem = 10000
                            simd_buf = gw_malloc(n_elem * 8)
                            si = 0
                            while si < n_elem
                                sys_poke(simd_buf + (si * 8), (si % 50) + 1)
                                si = si + 1
                            total = simd_avx2_sum(simd_buf, n_elem)
                            gw_free(simd_buf, n_elem * 8)
                            t1 = cpu_clock()
                            body = "{\"benchmark\":\"Live AVX2 SIMD Vector Sum\",\"elements\":" + str(n_elem) + ",\"sum\":" + str(total) + ",\"cpu_cycles\":" + str(t1 - t0) + "}"
                            gw_send_json(curr_fd, 200, body)

                        else
                            body = "{\"error\":\"Endpoint not found\",\"path\":\"" + path + "\",\"code\":404}"
                            gw_send_json(curr_fd, 404, body)

                        served = served + 1
                    else
                        gw_send_json(curr_fd, 400, "{\"error\":\"Bad Request\"}")

                // Clean socket close & epoll deregister
                gw_epoll_del(epfd, curr_fd)
                syscall(3, curr_fd, 0, 0, 0, 0, 0)

            ei = ei + 1

    say "✔ Enterprise Gateway processed " + str(served) + " requests cleanly. Shutting down."

    // Teardown
    KV_free(kv_db)
    gw_free(events_buf, max_events * event_size)
    gw_free(req_buf, 8192)
    gw_free(client_addr_buf, 32)
    syscall(3, listen_fd, 0, 0, 0, 0, 0)
    syscall(3, epfd, 0, 0, 0, 0, 0)
    return served

fn main()
    args = argv()
    port = 8999
    max_reqs = 1000
    if len(args) >= 2
        port = str_to_int(get(args, 1))
    if len(args) >= 3
        max_reqs = str_to_int(get(args, 2))
    start_gateway_server(port, max_reqs)
    return 0

main()
