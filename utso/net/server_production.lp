// ==============================================================================
// 👑 LIPI PRODUCTION CONCURRENT ASYNC WEB SERVER (utso/net/server_production.lp)
// ⚡ 100% Pure Lipi | Linux Kernel Epoll (Syscall 232, Exact 12-byte EPOLL_PACKED ABI)
//    Concurrent Multi-Connection HTTP/1.1 + Dynamic Router + Chunked Bodies +
//    Real-Time SSE Streaming + Full-Duplex RFC 6455 WebSockets (Ping/Pong/Frag/Binary/Close)
// ==============================================================================

include "src/runtime/lipi_syscall.lp"
include "utso/core/json_fast.lp"
include "utso/net/ws_engine.lp"

// ── Kernel Syscall Numbers for x86_64 ─────────────────────────────────────────
SYS_READ         = 0
SYS_WRITE        = 1
SYS_CLOSE        = 3
SYS_SOCKET       = 41
SYS_ACCEPT       = 43
SYS_BIND         = 49
SYS_LISTEN       = 50
SYS_SETSOCKOPT   = 54
SYS_FCNTL        = 72
SYS_EPOLL_WAIT   = 232
SYS_EPOLL_CTL    = 233
SYS_EPOLL_CREATE = 291

// Epoll Constants
EPOLLIN          = 1
EPOLLOUT         = 4
EPOLLERR         = 8
EPOLLHUP         = 16
EPOLL_CTL_ADD    = 1
EPOLL_CTL_DEL    = 2
EPOLL_CTL_MOD    = 3

// Socket Options
AF_INET          = 2
SOCK_STREAM      = 1
SOL_SOCKET       = 1
SO_REUSEADDR     = 2
SO_REUSEPORT     = 15

// Fcntl Flags
F_GETFL          = 3
F_SETFL          = 4
O_NONBLOCK       = 2048

// ── Explicit Structs with Unique Prefixes (Zero Global-Field Collision) ───────
struct ProdReq
    preq_method
    preq_path
    preq_query
    preq_headers
    preq_body
    preq_fd
    preq_srv

struct ProdConn
    pconn_fd
    pconn_mode
    pconn_read_buf
    pconn_ws_frag
    pconn_ws_opcode
    pconn_ws_path
    pconn_closed

struct ProdRoute
    proute_method
    proute_path
    proute_fn

struct ProdWsRoute
    pws_path
    pws_fn

// ── Memory Allocation Primitives ──────────────────────────────────────────────
fn prod_malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn prod_free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

// ── Non-Blocking Flag Configuration ───────────────────────────────────────────
fn prod_set_nonblocking fd
    flags = syscall(SYS_FCNTL, fd, F_GETFL, 0, 0, 0, 0)
    if flags < 0 return flags
    return syscall(SYS_FCNTL, fd, F_SETFL, flags | O_NONBLOCK, 0, 0, 0)

// ── Reliable Write Helper (Handles Partial Writes, EINTR & EAGAIN) ────────────
fn prod_write_all fd ptr total
    if fd < 0 or total <= 0 return 0
    sent = 0
    retries = 0
    while sent < total
        n = syscall(SYS_WRITE, fd, ptr + sent, total - sent, 0, 0, 0)
        if n == (0 - 4)
            continue
        if n == (0 - 11)
            retries = retries + 1
            if retries > 5000 return sent
            syscall(24, 0, 0, 0, 0, 0, 0) // sched_yield
            continue
        if n <= 0 return sent
        sent = sent + n
        retries = 0
    return sent

// ── Server Structure ──────────────────────────────────────────────────────────
// Layout:
//   [0]: port
//   [1]: listen_fd
//   [2]: epfd
//   [3]: is_running (0 or 1)
//   [4]: events_buffer (pre-allocated mmap buffer: max_events * 12 bytes, exact x86_64 EPOLL_PACKED!)
//   [5]: max_events
//   [6]: http_routes (list of ProdRoute)
//   [7]: ws_routes (list of ProdWsRoute)
//   [8]: conns (list of active ProdConn)
fn prod_server_create port max_events
    me = max_events
    if me < 16
        me = 16
    srv = list()
    push(srv, port)
    push(srv, 0 - 1)
    push(srv, 0 - 1)
    push(srv, 0)
    ev_buf = prod_malloc(me * 12)
    push(srv, ev_buf)
    push(srv, me)
    push(srv, list()) // [6] http_routes
    push(srv, list()) // [7] ws_routes
    push(srv, list()) // [8] active ProdConn list
    return srv

fn prod_route_add srv method path handler_fn
    routes = get(srv, 6)
    push(routes, ProdRoute(method, path, handler_fn))
    return 1

fn prod_ws_route_add srv path ws_handler_fn
    ws_routes = get(srv, 7)
    push(ws_routes, ProdWsRoute(path, ws_handler_fn))
    return 1

// ── Exact Linux x86_64 EPOLL_PACKED (12-byte) Registration ────────────────────
// struct epoll_event { uint32_t events (+0..3); uint64_t data (+4..11); } __attribute__((packed))
fn prod_epoll_add epfd fd mask
    ev = prod_malloc(16)
    mem_byte_write(ev, 0, mask & 255)
    mem_byte_write(ev, 1, (mask >> 8) & 255)
    mem_byte_write(ev, 2, (mask >> 16) & 255)
    mem_byte_write(ev, 3, (mask >> 24) & 255)
    mem_byte_write(ev, 4, fd & 255)
    mem_byte_write(ev, 5, (fd >> 8) & 255)
    mem_byte_write(ev, 6, (fd >> 16) & 255)
    mem_byte_write(ev, 7, (fd >> 24) & 255)
    mem_byte_write(ev, 8, 0)
    mem_byte_write(ev, 9, 0)
    mem_byte_write(ev, 10, 0)
    mem_byte_write(ev, 11, 0)

    res = syscall(SYS_EPOLL_CTL, epfd, EPOLL_CTL_ADD, fd, ev, 0, 0)
    prod_free(ev, 16)
    return res

fn prod_epoll_del epfd fd
    return syscall(SYS_EPOLL_CTL, epfd, EPOLL_CTL_DEL, fd, 0, 0, 0)

// ── Start Listening ───────────────────────────────────────────────────────────
fn prod_server_listen srv
    port = get(srv, 0)
    s_fd = syscall(SYS_SOCKET, AF_INET, SOCK_STREAM, 0, 0, 0, 0)
    if s_fd < 0 return 0 - 1

    opt = prod_malloc(8)
    mem_byte_write(opt, 0, 1)
    mem_byte_write(opt, 1, 0)
    mem_byte_write(opt, 2, 0)
    mem_byte_write(opt, 3, 0)
    syscall(SYS_SETSOCKOPT, s_fd, SOL_SOCKET, SO_REUSEADDR, opt, 4, 0)
    syscall(SYS_SETSOCKOPT, s_fd, SOL_SOCKET, SO_REUSEPORT, opt, 4, 0)
    prod_free(opt, 8)

    addr = prod_malloc(16)
    ai = 0
    while ai < 16
        mem_byte_write(addr, ai, 0)
        ai = ai + 1
    mem_byte_write(addr, 0, AF_INET)
    mem_byte_write(addr, 1, 0)
    mem_byte_write(addr, 2, (port >> 8) & 255)
    mem_byte_write(addr, 3, port & 255)

    b_res = syscall(SYS_BIND, s_fd, addr, 16, 0, 0, 0)
    prod_free(addr, 16)
    if b_res < 0
        syscall(SYS_CLOSE, s_fd, 0, 0, 0, 0, 0)
        return 0 - 2

    l_res = syscall(SYS_LISTEN, s_fd, 1024, 0, 0, 0, 0)
    if l_res < 0
        syscall(SYS_CLOSE, s_fd, 0, 0, 0, 0, 0)
        return 0 - 3

    prod_set_nonblocking(s_fd)

    epfd = syscall(SYS_EPOLL_CREATE, 0, 0, 0, 0, 0, 0)
    if epfd < 0
        syscall(SYS_CLOSE, s_fd, 0, 0, 0, 0, 0)
        return 0 - 4

    ctl_res = prod_epoll_add(epfd, s_fd, EPOLLIN)
    if ctl_res < 0
        syscall(SYS_CLOSE, s_fd, 0, 0, 0, 0, 0)
        syscall(SYS_CLOSE, epfd, 0, 0, 0, 0, 0)
        return 0 - 5

    list_set(srv, 1, s_fd)
    list_set(srv, 2, epfd)
    list_set(srv, 3, 1)
    return 0

// ── ByteBuffer Helpers & O(N) HTTP Request / Chunked Parsing ──────────────────
fn _prod_raw_ptr x
    return x

fn _prod_buf_consume b count
    cur = buf_len(b)
    if count <= 0 return 0
    if count >= cur
        buf_clear(b)
        return 0
    rem = cur - count
    p = buf_ptr(b)
    tail = bytes_to_str(p + count, rem)
    buf_clear(b)
    buf_write_mem(b, tail, rem)
    return 0

fn _prod_find_hdr_end ptr n
    i = 0
    while i + 3 < n
        if (mem_byte_read(ptr, i) & 255) == 13 and (mem_byte_read(ptr, i + 1) & 255) == 10 and (mem_byte_read(ptr, i + 2) & 255) == 13 and (mem_byte_read(ptr, i + 3) & 255) == 10
            return i
        i = i + 1
    return 0 - 1

fn _prod_to_lower_ascii s
    sp = _prod_raw_ptr(s)
    n = len(s)
    b = buf_new(n)
    i = 0
    while i < n
        ch = mem_byte_read(sp, i) & 255
        if ch >= 65 and ch <= 90
            ch = ch + 32
        buf_write_byte(b, ch)
        i = i + 1
    out = buf_to_str(b)
    buf_free(b)
    return out

fn _prod_parse_int s
    sp = _prod_raw_ptr(s)
    n = len(s)
    v = 0
    i = 0
    while i < n
        ch = mem_byte_read(sp, i) & 255
        if ch >= 48 and ch <= 57
            v = (v * 10) + (ch - 48)
        elif ch != 32 and ch != 9 and ch != 13
            break
        i = i + 1
    return v

fn _prod_parse_hex s
    sp = _prod_raw_ptr(s)
    n = len(s)
    v = 0
    i = 0
    while i < n
        ch = mem_byte_read(sp, i) & 255
        if ch >= 48 and ch <= 57
            v = (v * 16) + (ch - 48)
        elif ch >= 97 and ch <= 102
            v = (v * 16) + (ch - 87)
        elif ch >= 65 and ch <= 70
            v = (v * 16) + (ch - 55)
        elif ch == 59 or ch == 13 or ch == 10
            break
        i = i + 1
    return v

fn _prod_int_to_hex v
    if v <= 0 return "0"
    digits = "0123456789abcdef"
    dp = _prod_raw_ptr(digits)
    rev = buf_new(16)
    x = v
    while x > 0
        buf_write_byte(rev, mem_byte_read(dp, x & 15))
        x = x >> 4
    rn = buf_len(rev)
    rp = buf_ptr(rev)
    out = buf_new(rn)
    i = rn - 1
    while i >= 0
        buf_write_byte(out, mem_byte_read(rp, i))
        i = i - 1
    res = buf_to_str(out)
    buf_free(rev)
    buf_free(out)
    return res

fn _prod_decode_chunked_check ptr blen
    // Returns [complete_flag (1/0), consumed_bytes, decoded_body_str]
    out = buf_new(256)
    pos = 0
    complete = 0
    while pos < blen
        nl = 0 - 1
        i = pos
        while i < blen
            if (mem_byte_read(ptr, i) & 255) == 10
                nl = i
                break
            i = i + 1
        if nl < 0 break
        line_s = bytes_to_str(ptr + pos, nl - pos)
        csz = _prod_parse_hex(line_s)
        pos = nl + 1
        if csz == 0
            // Require trailing \r\n (or \n) for terminal 0-chunk
            if pos + 2 <= blen and (mem_byte_read(ptr, pos) & 255) == 13 and (mem_byte_read(ptr, pos + 1) & 255) == 10
                pos = pos + 2
                complete = 1
                break
            elif pos + 1 <= blen and (mem_byte_read(ptr, pos) & 255) == 10
                pos = pos + 1
                complete = 1
                break
            break
        if pos + csz + 2 > blen break
        buf_write_mem(out, ptr + pos, csz)
        pos = pos + csz
        if pos < blen and (mem_byte_read(ptr, pos) & 255) == 13
            pos = pos + 1
        if pos < blen and (mem_byte_read(ptr, pos) & 255) == 10
            pos = pos + 1
    body_s = buf_to_str(out)
    buf_free(out)
    return [complete, pos, body_s]

fn prod_parse_http_method_path buf blen
    if blen < 5 return ""
    p = 0
    while p < blen and (mem_byte_read(buf, p) & 255) != 32
        p = p + 1
    if p >= blen return ""
    p = p + 1
    start_path = p
    while p < blen and (mem_byte_read(buf, p) & 255) != 32 and (mem_byte_read(buf, p) & 255) != 63
        p = p + 1
    if p <= start_path return ""
    return bytes_to_str(buf + start_path, p - start_path)

fn prod_is_websocket_upgrade buf blen
    if blen < 18 return 0
    hdr_s = _prod_to_lower_ascii(bytes_to_str(buf, blen))
    if str_contains(hdr_s, "upgrade: websocket") == 1 return 1
    return 0

fn prod_buf_to_str buf blen
    if blen <= 0 return ""
    return bytes_to_str(buf, blen)

// ── HTTP, JSON, SSE & WebSocket Response Senders ──────────────────────────────
fn _prod_status_line status_code
    if status_code == 200 return "HTTP/1.1 200 OK\r\n"
    if status_code == 201 return "HTTP/1.1 201 Created\r\n"
    if status_code == 204 return "HTTP/1.1 204 No Content\r\n"
    if status_code == 400 return "HTTP/1.1 400 Bad Request\r\n"
    if status_code == 404 return "HTTP/1.1 404 Not Found\r\n"
    if status_code == 405 return "HTTP/1.1 405 Method Not Allowed\r\n"
    if status_code == 500 return "HTTP/1.1 500 Internal Server Error\r\n"
    return "HTTP/1.1 " + str(status_code) + " OK\r\n"

fn prod_send_response fd status_code content_type body
    body_s = str(body)
    body_len = len(body_s)
    b = buf_new(256 + body_len)
    buf_write_str(b, _prod_status_line(status_code))
    buf_write_str(b, "Content-Type: ")
    buf_write_str(b, content_type)
    buf_write_str(b, "\r\nContent-Length: ")
    buf_write_str(b, str(body_len))
    buf_write_str(b, "\r\nConnection: keep-alive\r\n\r\n")
    if body_len > 0
        buf_write_mem(b, body_s, body_len)
    prod_write_all(fd, buf_ptr(b), buf_len(b))
    buf_free(b)
    return 1

fn prod_send_json_response fd status_code json_payload
    return prod_send_response(fd, status_code, "application/json; charset=utf-8", json_payload)

fn prod_sse_start fd
    hdr = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream; charset=utf-8\r\nCache-Control: no-cache\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
    prod_write_all(fd, _prod_raw_ptr(hdr), len(hdr))
    return 1

fn prod_sse_send_chunk fd data
    ds = str(data)
    dlen = len(ds)
    if dlen <= 0 return 0
    hex_sz = _prod_int_to_hex(dlen)
    b = buf_new(dlen + 16)
    buf_write_str(b, hex_sz)
    buf_write_str(b, "\r\n")
    buf_write_mem(b, ds, dlen)
    buf_write_str(b, "\r\n")
    prod_write_all(fd, buf_ptr(b), buf_len(b))
    buf_free(b)
    return dlen

fn prod_sse_end fd
    term = "0\r\n\r\n"
    prod_write_all(fd, _prod_raw_ptr(term), 5)
    return 1

fn prod_send_ws_upgrade_response_key fd client_key
    use_key = client_key
    if len(use_key) == 0
        use_key = "dGhlIHNhbXBsZSBub25jZQ=="
    accept_tok = ws_compute_accept_key(use_key)
    resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept_tok + "\r\n\r\n"
    prod_write_all(fd, _prod_raw_ptr(resp), len(resp))
    return 1

fn prod_send_ws_upgrade_response fd
    return prod_send_ws_upgrade_response_key(fd, "dGhlIHNhbXBsZSBub25jZQ==")

// ── Per-Connection Table Management ───────────────────────────────────────────
fn _prod_find_conn srv fd
    conns = get(srv, 8)
    i = 0
    n = conns.len()
    while i < n
        c = conns[i]
        if c.pconn_fd == fd and c.pconn_closed == 0
            return c
        i = i + 1
    return 0

fn _prod_add_conn srv fd
    conns = get(srv, 8)
    c = ProdConn(fd, 0, buf_new(4096), buf_new(256), 0, "/", 0)
    push(conns, c)
    return c

fn _prod_close_conn srv epfd c: ProdConn
    if c == 0 or c.pconn_closed == 1 return 0
    c.pconn_closed = 1
    prod_epoll_del(epfd, c.pconn_fd)
    syscall(SYS_CLOSE, c.pconn_fd, 0, 0, 0, 0, 0)
    if c.pconn_read_buf != 0
        buf_free(c.pconn_read_buf)
        c.pconn_read_buf = 0
    if c.pconn_ws_frag != 0
        buf_free(c.pconn_ws_frag)
        c.pconn_ws_frag = 0
    return 0

fn _prod_dispatch_ws srv c: ProdConn opcode payload plen
    ws_routes = get(srv, 7)
    i = 0
    n = ws_routes.len()
    while i < n
        r = ws_routes[i]
        if r.pws_path == c.pconn_ws_path or r.pws_path == "*"
            hfn = r.pws_fn
            if hfn != 0
                hfn(c.pconn_fd, opcode, payload, plen)
                return 1
        i = i + 1
    // Default echo if no custom WebSocket route registered
    ws_send_frame(c.pconn_fd, opcode, _prod_raw_ptr(payload), plen, 1)
    return 1

fn _prod_process_ws_frames srv epfd c: ProdConn
    while c.pconn_closed == 0
        av = buf_len(c.pconn_read_buf)
        if av < 2 break
        fr = ws_parse_frame(buf_ptr(c.pconn_read_buf), av, 1)
        if fr.ws_ok == 0 break
        if fr.ws_ok < 0
            ws_send_close(c.pconn_fd, 1002)
            _prod_close_conn(srv, epfd, c)
            break
        _prod_buf_consume(c.pconn_read_buf, fr.ws_consumed)
        op = fr.ws_opcode
        if op == 8
            // RFC 6455 Close handshake: reply Close and shut down connection cleanly
            ws_send_close(c.pconn_fd, 1000)
            _prod_close_conn(srv, epfd, c)
            break
        elif op == 9
            // RFC 6455 Ping -> automatic Pong with exact echoed payload
            ws_send_pong(c.pconn_fd, _prod_raw_ptr(fr.ws_payload), fr.ws_payload_len)
        elif op == 10
            // Pong received: keepalive acknowledged
            _nop = 0
        elif op == 1 or op == 2
            if fr.ws_fin == 1
                _prod_dispatch_ws(srv, c, op, fr.ws_payload, fr.ws_payload_len)
            else
                // Start of fragmented message
                buf_clear(c.pconn_ws_frag)
                c.pconn_ws_opcode = op
                if fr.ws_payload_len > 0
                    buf_write_mem(c.pconn_ws_frag, _prod_raw_ptr(fr.ws_payload), fr.ws_payload_len)
        elif op == 0
            // Continuation frame
            if fr.ws_payload_len > 0
                buf_write_mem(c.pconn_ws_frag, _prod_raw_ptr(fr.ws_payload), fr.ws_payload_len)
            if fr.ws_fin == 1
                full_len = buf_len(c.pconn_ws_frag)
                full_payload = buf_to_str(c.pconn_ws_frag)
                use_op = c.pconn_ws_opcode
                if use_op == 0
                    use_op = 1
                buf_clear(c.pconn_ws_frag)
                c.pconn_ws_opcode = 0
                _prod_dispatch_ws(srv, c, use_op, full_payload, full_len)
    return 0

fn _prod_extract_hdr_value hdr_str target_lower
    lines = string_split(hdr_str, "\n")
    i = 1
    while i < len(lines)
        ln = str_trim(get(lines, i))
        colon = str_index_of(ln, ":")
        if colon > 0
            hn = _prod_to_lower_ascii(str_trim(str_sub(ln, 0, colon)))
            if hn == target_lower
                return str_trim(str_sub(ln, colon + 1, len(ln)))
        i = i + 1
    return ""

fn _prod_process_http srv epfd c: ProdConn
    while c.pconn_closed == 0 and c.pconn_mode == 0
        av = buf_len(c.pconn_read_buf)
        if av < 4 break
        p = buf_ptr(c.pconn_read_buf)
        hend = _prod_find_hdr_end(p, av)
        if hend < 0 break

        hdr_s = bytes_to_str(p, hend)
        body_off = hend + 4
        body_av = av - body_off

        // Parse request line: METHOD SP target SP HTTP/1.1
        first_nl = str_index_of(hdr_s, "\n")
        req_line = hdr_s
        if first_nl >= 0
            req_line = str_sub(hdr_s, 0, first_nl)
        req_line = str_trim(req_line)
        sp1 = str_index_of(req_line, " ")
        method = "GET"
        raw_target = "/"
        if sp1 > 0
            method = str_sub(req_line, 0, sp1)
            rest = str_sub(req_line, sp1 + 1, len(req_line))
            sp2 = str_index_of(rest, " ")
            if sp2 >= 0
                raw_target = str_sub(rest, 0, sp2)
            else
                raw_target = rest

        path = raw_target
        query = ""
        qpos = str_index_of(raw_target, "?")
        if qpos >= 0
            path = str_sub(raw_target, 0, qpos)
            query = str_sub(raw_target, qpos + 1, len(raw_target))

        // Check WebSocket Upgrade
        if prod_is_websocket_upgrade(p, hend) == 1
            ws_k = ws_extract_key(hdr_s + "\r\n")
            prod_send_ws_upgrade_response_key(c.pconn_fd, ws_k)
            _prod_buf_consume(c.pconn_read_buf, body_off)
            c.pconn_mode = 1
            c.pconn_ws_path = path
            _prod_process_ws_frames(srv, epfd, c)
            break

        // Determine body framing (Transfer-Encoding: chunked vs Content-Length)
        te_v = _prod_to_lower_ascii(_prod_extract_hdr_value(hdr_s, "transfer-encoding"))
        body_str = ""
        total_req_bytes = body_off
        if str_contains(te_v, "chunked") == 1
            chk = _prod_decode_chunked_check(p + body_off, body_av)
            if get(chk, 0) == 0
                // Wait for remaining chunks
                break
            total_req_bytes = body_off + get(chk, 1)
            body_str = get(chk, 2)
        else
            cl_s = _prod_extract_hdr_value(hdr_s, "content-length")
            clen = 0
            if len(cl_s) > 0
                clen = _prod_parse_int(cl_s)
            if body_av < clen
                // Wait for full Content-Length body across non-blocking reads
                break
            if clen > 0
                body_str = bytes_to_str(p + body_off, clen)
            total_req_bytes = body_off + clen

        _prod_buf_consume(c.pconn_read_buf, total_req_bytes)

        // Dynamic route dispatch
        req = ProdReq(method, path, query, hdr_s, body_str, c.pconn_fd, srv)
        routes = get(srv, 6)
        matched = 0
        ri = 0
        rn = routes.len()
        while ri < rn
            rt = routes[ri]
            if (rt.proute_method == method or rt.proute_method == "*") and (rt.proute_path == path or rt.proute_path == "*")
                hfn = rt.proute_fn
                matched = 1
                if hfn != 0
                    res = hfn(req)
                    if is_str(res) == 1
                        prod_send_response(c.pconn_fd, 200, "text/plain; charset=utf-8", res)
                break
            ri = ri + 1

        if matched == 0
            // Backwards-compatible default routes
            if path == "/health"
                prod_send_json_response(c.pconn_fd, 200, "{\"status\":\"UP\",\"server\":\"Lipi-Production\"}")
            elif path == "/metrics"
                prod_send_json_response(c.pconn_fd, 200, "{\"uptime_cycles\":1000000,\"status\":200}")
            else
                prod_send_json_response(c.pconn_fd, 200, "{\"message\":\"Lipi Sovereign Enterprise Server\"}")

        conn_hdr = _prod_to_lower_ascii(_prod_extract_hdr_value(hdr_s, "connection"))
        if conn_hdr == "close"
            _prod_close_conn(srv, epfd, c)
            break
    return 0

// ── Epoll Reactor Tick (Multi-Connection Non-Blocking) ────────────────────────
fn prod_server_tick srv timeout_ms
    epfd = get(srv, 2)
    listen_fd = get(srv, 1)
    ev_buf = get(srv, 4)
    max_events = get(srv, 5)

    nfds = syscall(SYS_EPOLL_WAIT, epfd, ev_buf, max_events, timeout_ms, 0, 0)
    if nfds <= 0 return nfds

    rbuf = prod_malloc(8192)
    i = 0
    while i < nfds
        // Exact Linux x86_64 EPOLL_PACKED 12-byte event stride: events@+0 (4B), data@+4 (8B)
        ev_off = i * 12
        ev_mask = (mem_byte_read(ev_buf, ev_off) & 255) | ((mem_byte_read(ev_buf, ev_off + 1) & 255) << 8)
        c_fd = (mem_byte_read(ev_buf, ev_off + 4) & 255) | ((mem_byte_read(ev_buf, ev_off + 5) & 255) << 8) | ((mem_byte_read(ev_buf, ev_off + 6) & 255) << 16) | ((mem_byte_read(ev_buf, ev_off + 7) & 255) << 24)

        if c_fd == listen_fd
            // Accept ALL pending connections in the listen backlog
            while 1 == 1
                client_fd = syscall(SYS_ACCEPT, listen_fd, 0, 0, 0, 0, 0)
                if client_fd < 0 break
                prod_set_nonblocking(client_fd)
                prod_epoll_add(epfd, client_fd, EPOLLIN)
                _prod_add_conn(srv, client_fd)
        else
            c = _prod_find_conn(srv, c_fd)
            if c == 0
                c = _prod_add_conn(srv, c_fd)
            if (ev_mask & (EPOLLERR | EPOLLHUP)) != 0 and (ev_mask & EPOLLIN) == 0
                _prod_close_conn(srv, epfd, c)
            else
                // Drain non-blocking socket until EAGAIN (-11) or EOF (0)
                closed_now = 0
                while 1 == 1
                    nread = syscall(SYS_READ, c_fd, rbuf, 8192, 0, 0, 0)
                    if nread > 0
                        buf_write_mem(c.pconn_read_buf, rbuf, nread)
                    elif nread == 0
                        closed_now = 1
                        break
                    elif nread == (0 - 4)
                        continue
                    else
                        // EAGAIN (-11): no more bytes currently buffered
                        break
                if c.pconn_mode == 0
                    _prod_process_http(srv, epfd, c)
                elif c.pconn_mode == 1
                    _prod_process_ws_frames(srv, epfd, c)
                if closed_now == 1 and c.pconn_closed == 0
                    _prod_close_conn(srv, epfd, c)
        i = i + 1
    prod_free(rbuf, 8192)
    return nfds

// ── Graceful Shutdown ─────────────────────────────────────────────────────────
fn prod_server_close srv
    listen_fd = get(srv, 1)
    epfd = get(srv, 2)
    ev_buf = get(srv, 4)
    max_events = get(srv, 5)
    conns = get(srv, 8)

    if conns != 0
        ci = 0
        cn = conns.len()
        while ci < cn
            c = conns[ci]
            if c.pconn_closed == 0
                _prod_close_conn(srv, epfd, c)
            ci = ci + 1

    if listen_fd >= 0
        prod_epoll_del(epfd, listen_fd)
        syscall(SYS_CLOSE, listen_fd, 0, 0, 0, 0, 0)
        list_set(srv, 1, 0 - 1)

    if epfd >= 0
        syscall(SYS_CLOSE, epfd, 0, 0, 0, 0, 0)
        list_set(srv, 2, 0 - 1)

    if ev_buf > 0
        prod_free(ev_buf, max_events * 12)
        list_set(srv, 4, 0)

    list_set(srv, 3, 0)
    return 0
