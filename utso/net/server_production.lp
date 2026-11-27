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
    pconn_write_buf
    pconn_ws_frag
    pconn_ws_opcode
    pconn_ws_path
    pconn_closed
    pconn_last_active_ms
    pconn_close_after_write
    pconn_tls_session
    pconn_tls_raw_buf

struct ProdRoute
    proute_method
    proute_path
    proute_fn

struct ProdWsRoute
    pws_path
    pws_fn

struct ProdRadixNode
    prn_segment
    prn_is_param
    prn_is_wild
    prn_children
    prn_handlers // DICT0 mapping HTTP method -> handler_fn

fn prod_radix_node_new seg is_param is_wild
    return ProdRadixNode(seg, is_param, is_wild, list(), dict())

fn prod_radix_insert root: ProdRadixNode method path handler_fn
    // WHY: Inserts route segments into a prefix/radix trie (O(depth) lookup instead of O(N) linear scan!)
    // Supports exact segments, ":param" dynamic segments, and "*" catch-all wildcards.
    if root == 0 return 0 end
    if path == "*"
        root.prn_is_wild = 1
        root.prn_handlers[method] = handler_fn
        return 1
    end
    segs = string_split(path, "/")
    cur = root
    si = 0
    while si < len(segs)
        seg = get(segs, si)
        if len(seg) > 0
            is_p = 0
            is_w = 0
            if char_at(seg, 0) == ":" is_p = 1 end
            if seg == "*" is_w = 1 end
            found = 0
            ci = 0
            while ci < cur.prn_children.len()
                ch = cur.prn_children[ci]
                if ch.prn_segment == seg
                    found = ch
                    break
                end
                ci = ci + 1
            end
            if found == 0
                found = prod_radix_node_new(seg, is_p, is_w)
                push(cur.prn_children, found)
            end
            cur = found
        end
        si = si + 1
    end
    cur.prn_handlers[method] = handler_fn
    return 1

fn _prod_radix_match_rec node: ProdRadixNode segs idx method
    if node == 0 return 0 end
    while idx < len(segs) and len(get(segs, idx)) == 0
        idx = idx + 1
    end
    if idx >= len(segs)
        if has_key(node.prn_handlers, method) == 1
            return node.prn_handlers[method]
        end
        if has_key(node.prn_handlers, "*") == 1
            return node.prn_handlers["*"]
        end
        return 0
    end
    cur_seg = get(segs, idx)
    // Priority 1: Exact static segment match
    ci = 0
    while ci < node.prn_children.len()
        ch = node.prn_children[ci]
        if ch.prn_is_param == 0 and ch.prn_is_wild == 0 and ch.prn_segment == cur_seg
            r = _prod_radix_match_rec(ch, segs, idx + 1, method)
            if r != 0 return r end
        end
        ci = ci + 1
    end
    // Priority 2: ":param" segment match
    ci = 0
    while ci < node.prn_children.len()
        ch = node.prn_children[ci]
        if ch.prn_is_param == 1
            r = _prod_radix_match_rec(ch, segs, idx + 1, method)
            if r != 0 return r end
        end
        ci = ci + 1
    end
    // Priority 3: "*" wildcard child match
    ci = 0
    while ci < node.prn_children.len()
        ch = node.prn_children[ci]
        if ch.prn_is_wild == 1
            if has_key(ch.prn_handlers, method) == 1 return ch.prn_handlers[method] end
            if has_key(ch.prn_handlers, "*") == 1 return ch.prn_handlers["*"] end
        end
        ci = ci + 1
    end
    if node.prn_is_wild == 1
        if has_key(node.prn_handlers, method) == 1 return node.prn_handlers[method] end
        if has_key(node.prn_handlers, "*") == 1 return node.prn_handlers["*"] end
    end
    return 0

fn prod_radix_match root: ProdRadixNode method path
    if root == 0 return 0 end
    segs = string_split(path, "/")
    h = _prod_radix_match_rec(root, segs, 0, method)
    if h != 0 return h end
    if root.prn_is_wild == 1
        if has_key(root.prn_handlers, method) == 1 return root.prn_handlers[method] end
        if has_key(root.prn_handlers, "*") == 1 return root.prn_handlers["*"] end
    end
    return 0

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
        n = syscall(44, fd, ptr + sent, total - sent, 16384, 0, 0)
        if n == (0 - 88)
            n = syscall(SYS_WRITE, fd, ptr + sent, total - sent, 0, 0, 0)
        end
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
//   [9]: conns_by_fd (O(1) DICT0 map: fd -> ProdConn)
//   [10]: reusable 8KB read buffer (zero per-tick mmap/munmap!)
//   [11]: reusable 16B epoll_event scratch buffer (zero per-ctl mmap/munmap!)
//   [12]: radix_root (O(depth) ProdRadixNode HTTP router)
//   [13]: tls_handshake_hook (optional legacy accept hook fn(client_fd) -> ok)
//   [14]: idle_timeout_ms (0 = disabled; >0 auto-reaps idle Slowloris connections in prod_server_tick)
//   [15]: last_sweep_ms (timestamp of last automatic idle sweep)
//   [16]: max_read_bytes (per-connection read buffer cap, default 1048576 = 1 MiB -> 413 Payload Too Large)
//   [17]: tls_engine (optional in-process TLS 1.3 Tls13RecordEngine)
//   [18]: tls_accept_fn (fn(client_fd, engine) -> Tls13Session or 0)
//   [19]: tls_decrypt_fn (fn(session, wire_rec_bytes) -> plaintext_str)
//   [20]: tls_encrypt_fn (fn(session, plaintext_str) -> wire_bytes_list)
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
    push(srv, list())                      // [6] http_routes
    push(srv, list())                      // [7] ws_routes
    push(srv, list())                      // [8] active ProdConn list
    push(srv, dict())                      // [9] O(1) conns_by_fd DICT0
    push(srv, prod_malloc(8192))           // [10] reusable 8KB read buffer
    push(srv, prod_malloc(16))             // [11] reusable 16B epoll_ctl event buffer
    push(srv, prod_radix_node_new("", 0, 0)) // [12] Radix/Trie HTTP router root
    push(srv, 0)                           // [13] optional TLS accept hook
    push(srv, 0)                           // [14] idle_timeout_ms (0 = off until configured)
    push(srv, clock_ms())                  // [15] last_sweep_ms
    push(srv, 1048576)                     // [16] max_read_bytes (1 MiB default DoS cap)
    push(srv, 0)                           // [17] tls_engine
    push(srv, 0)                           // [18] tls_accept_fn
    push(srv, 0)                           // [19] tls_decrypt_fn
    push(srv, 0)                           // [20] tls_encrypt_fn
    return srv

fn prod_server_set_tls_hook srv tls_fn
    list_set(srv, 13, tls_fn)
    return 1

fn prod_server_set_idle_timeout srv idle_ms
    // WHY: Enables automatic Slowloris / idle keep-alive reaping inside prod_server_tick.
    list_set(srv, 14, idle_ms)
    return 1

fn prod_server_set_max_read_bytes srv max_bytes
    // WHY: Configures per-connection read buffer ceiling (returns 413 Payload Too Large on overflow).
    if max_bytes < 128
        max_bytes = 128
    end
    list_set(srv, 16, max_bytes)
    return 1

fn prod_server_attach_tls_driver srv tls_engine accept_fn decrypt_fn encrypt_fn
    // WHY: Wires a real in-process RFC 8446 TLS 1.3 record engine directly into the epoll reactor
    // with zero compile-time bloat for plain-HTTP servers.
    list_set(srv, 17, tls_engine)
    list_set(srv, 18, accept_fn)
    list_set(srv, 19, decrypt_fn)
    list_set(srv, 20, encrypt_fn)
    return 1

fn prod_route_add srv method path handler_fn
    routes = get(srv, 6)
    push(routes, ProdRoute(method, path, handler_fn))
    prod_radix_insert(get(srv, 12), method, path, handler_fn)
    return 1

fn prod_ws_route_add srv path ws_handler_fn
    ws_routes = get(srv, 7)
    push(ws_routes, ProdWsRoute(path, ws_handler_fn))
    return 1

// ── Exact Linux x86_64 EPOLL_PACKED (12-byte) Registration & Modification ─────
fn prod_epoll_ctl_buf epfd op fd mask ev_scratch
    ev = ev_scratch
    own = 0
    if ev <= 0
        ev = prod_malloc(16)
        own = 1
    end
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
    res = syscall(SYS_EPOLL_CTL, epfd, op, fd, ev, 0, 0)
    if own == 1 prod_free(ev, 16) end
    return res

fn prod_epoll_add epfd fd mask
    return prod_epoll_ctl_buf(epfd, EPOLL_CTL_ADD, fd, mask, 0)

fn prod_epoll_mod epfd fd mask
    return prod_epoll_ctl_buf(epfd, EPOLL_CTL_MOD, fd, mask, 0)

fn prod_epoll_del epfd fd
    return syscall(SYS_EPOLL_CTL, epfd, EPOLL_CTL_DEL, fd, 0, 0, 0)

// ── Non-Blocking Per-Connection Write Queue (Zero-Spin EPOLLOUT Backpressure) ──
fn _prod_conn_enqueue_raw srv epfd c: ProdConn ptr total
    // WHY: Low-level non-blocking write queue for already-framed wire bytes (plaintext or TLS ciphertext).
    // Uses SYS_sendto (44) + MSG_NOSIGNAL (0x4000) so disconnected peers never kill the server via SIGPIPE.
    if c == 0 or c.pconn_closed == 1 or total <= 0 return 0 end
    off = 0
    if buf_len(c.pconn_write_buf) == 0
        while off < total
            n = syscall(44, c.pconn_fd, ptr + off, total - off, 16384, 0, 0)
            if n == (0 - 88)
                n = syscall(SYS_WRITE, c.pconn_fd, ptr + off, total - off, 0, 0, 0)
            end
            if n == (0 - 4) continue end
            if n > 0
                off = off + n
            elif n == (0 - 11)
                break
            else
                _prod_close_conn(srv, epfd, c)
                return 0 - 1
            end
        end
    end
    if off < total
        buf_write_mem(c.pconn_write_buf, ptr + off, total - off)
        if epfd >= 0
            prod_epoll_ctl_buf(epfd, EPOLL_CTL_MOD, c.pconn_fd, EPOLLIN | EPOLLOUT, get(srv, 11))
        end
    end
    return total

fn prod_conn_enqueue_write srv epfd c: ProdConn ptr total
    // WHY: Encrypts outgoing payload transparently into RFC 8446 TLS 1.3 AEAD records when the
    // connection carries an active TLS session, then enqueues via zero-spin EPOLLOUT backpressure!
    if c == 0 or c.pconn_closed == 1 or total <= 0 return 0 end
    if c.pconn_tls_session != 0 and srv != 0 and srv.len() > 20
        enc_fn = get(srv, 20)
        if enc_fn != 0
            pt_str = bytes_to_str(ptr, total)
            wire_bytes = enc_fn(c.pconn_tls_session, pt_str)
            wlen = len(wire_bytes)
            if wlen <= 0 return 0 end
            wbuf = buf_new(wlen)
            wi = 0
            while wi < wlen
                buf_write_byte(wbuf, get(wire_bytes, wi) & 255)
                wi = wi + 1
            end
            res = _prod_conn_enqueue_raw(srv, epfd, c, buf_ptr(wbuf), buf_len(wbuf))
            buf_free(wbuf)
            return res
        end
    end
    return _prod_conn_enqueue_raw(srv, epfd, c, ptr, total)

fn prod_conn_flush_writes srv epfd c: ProdConn
    if c == 0 or c.pconn_closed == 1 return 0 end
    wlen = buf_len(c.pconn_write_buf)
    if wlen <= 0 return 0 end
    wptr = buf_ptr(c.pconn_write_buf)
    sent = 0
    fatal_err = 0
    while sent < wlen
        n = syscall(44, c.pconn_fd, wptr + sent, wlen - sent, 16384, 0, 0)
        if n == (0 - 88)
            n = syscall(SYS_WRITE, c.pconn_fd, wptr + sent, wlen - sent, 0, 0, 0)
        end
        if n == (0 - 4) continue end
        if n > 0
            sent = sent + n
        elif n == (0 - 11)
            break
        else
            fatal_err = 1
            break
        end
    end
    if sent > 0
        _prod_buf_consume(c.pconn_write_buf, sent)
    end
    if fatal_err == 1
        _prod_close_conn(srv, epfd, c)
        return 0 - 1
    end
    if buf_len(c.pconn_write_buf) == 0
        if c.pconn_close_after_write == 1
            _prod_close_conn(srv, epfd, c)
        elif epfd >= 0
            prod_epoll_ctl_buf(epfd, EPOLL_CTL_MOD, c.pconn_fd, EPOLLIN, get(srv, 11))
        end
    end
    return sent

fn _prod_compact_conns srv
    // WHY: Reclaims closed ProdConn entries from srv[8] so long-running servers have O(active) memory.
    conns = get(srv, 8)
    if conns == 0 return 0 end
    alive = list()
    i = 0
    while i < conns.len()
        c = conns[i]
        if c != 0 and c.pconn_closed == 0
            push(alive, c)
        end
        i = i + 1
    end
    list_set(srv, 8, alive)
    return alive.len()

fn prod_server_sweep_idle srv max_idle_ms
    // WHY: Closes idle keep-alive / Slowloris sockets exceeding max_idle_ms and compacts dead slots.
    if max_idle_ms <= 0 return 0 end
    now = clock_ms()
    epfd = get(srv, 2)
    conns = get(srv, 8)
    closed_cnt = 0
    dead_seen = 0
    i = 0
    while i < conns.len()
        c = conns[i]
        if c.pconn_closed == 1
            dead_seen = dead_seen + 1
        elif c.pconn_last_active_ms > 0 and (now - c.pconn_last_active_ms) > max_idle_ms
            _prod_close_conn(srv, epfd, c)
            closed_cnt = closed_cnt + 1
            dead_seen = dead_seen + 1
        end
        i = i + 1
    end
    if dead_seen > 0
        _prod_compact_conns(srv)
    end
    return closed_cnt

fn prod_server_run_workers port max_events worker_count setup_fn max_ticks tick_ms
    // WHY: Complete multi-process SO_REUSEPORT worker pool driver: forks `worker_count`
    // independent epoll reactors sharing `port`, invokes `setup_fn(srv)` in each worker,
    // runs `max_ticks` reactor iterations, and cleanly reaps child PIDs in parent!
    pids = prod_server_spawn_workers(port, max_events, worker_count)
    srv = prod_server_create(port, max_events)
    if setup_fn != 0
        setup_fn(srv)
    end
    lrc = prod_server_listen(srv)
    if lrc < 0
        prod_server_close(srv)
        return lrc
    end
    t = 0
    while max_ticks <= 0 or t < max_ticks
        prod_server_tick(srv, tick_ms)
        t = t + 1
    end
    prod_server_close(srv)
    if pids.len() > 0
        pi = 0
        while pi < pids.len()
            // wait4(pid, 0, 0, 0) = Linux SYS_wait4 (61)
            syscall(61, pids[pi], 0, 0, 0, 0, 0)
            pi = pi + 1
        end
    end
    return 0

fn prod_server_spawn_workers port max_events worker_count
    // WHY: Multi-core SO_REUSEPORT worker pool via direct Linux SYS_fork (57).
    // Returns list of child PIDs in parent (or empty list inside child worker after binding port).
    pids = list()
    w = 1
    while w < worker_count
        pid = syscall(57, 0, 0, 0, 0, 0, 0)
        if pid == 0
            return pids // Child worker continues independently on SO_REUSEPORT
        elif pid > 0
            push(pids, pid)
        end
        w = w + 1
    end
    return pids

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
    if status_code == 413 return "HTTP/1.1 413 Payload Too Large\r\n"
    if status_code == 500 return "HTTP/1.1 500 Internal Server Error\r\n"
    return "HTTP/1.1 " + str(status_code) + " OK\r\n"

fn prod_send_response_conn srv epfd c: ProdConn status_code content_type body
    // WHY: Formats HTTP/1.1 response into ByteBuffer and enqueues via non-blocking EPOLLOUT write queue!
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
    end
    prod_conn_enqueue_write(srv, epfd, c, buf_ptr(b), buf_len(b))
    buf_free(b)
    return 1
end

fn prod_send_json_response_conn srv epfd c: ProdConn status_code json_payload
    return prod_send_response_conn(srv, epfd, c, status_code, "application/json; charset=utf-8", json_payload)
end

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

fn prod_sse_start_conn srv epfd c: ProdConn
    // WHY: Non-blocking, TLS-1.3-transparent SSE stream initializer routed through prod_conn_enqueue_write.
    if c == 0 or c.pconn_closed == 1 return 0 end
    hdr = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream; charset=utf-8\r\nCache-Control: no-cache\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
    prod_conn_enqueue_write(srv, epfd, c, _prod_raw_ptr(hdr), len(hdr))
    return 1
end

fn prod_sse_send_chunk_conn srv epfd c: ProdConn data
    if c == 0 or c.pconn_closed == 1 return 0 end
    ds = str(data)
    dlen = len(ds)
    if dlen <= 0 return 0 end
    hex_sz = _prod_int_to_hex(dlen)
    b = buf_new(dlen + 16)
    buf_write_str(b, hex_sz)
    buf_write_str(b, "\r\n")
    buf_write_mem(b, ds, dlen)
    buf_write_str(b, "\r\n")
    prod_conn_enqueue_write(srv, epfd, c, buf_ptr(b), buf_len(b))
    buf_free(b)
    return dlen
end

fn prod_sse_send_event_conn srv epfd c: ProdConn event_name data
    payload = ""
    if len(event_name) > 0
        payload = "event: " + event_name + "\n"
    end
    payload = payload + "data: " + str(data) + "\n\n"
    return prod_sse_send_chunk_conn(srv, epfd, c, payload)
end

fn prod_sse_end_conn srv epfd c: ProdConn
    if c == 0 or c.pconn_closed == 1 return 0 end
    term = "0\r\n\r\n"
    prod_conn_enqueue_write(srv, epfd, c, _prod_raw_ptr(term), 5)
    if buf_len(c.pconn_write_buf) > 0
        c.pconn_close_after_write = 1
    else
        _prod_close_conn(srv, epfd, c)
    end
    return 1
end

fn prod_sse_start_req req: ProdReq
    if req == 0 or req.preq_srv == 0 return prod_sse_start(req.preq_fd) end
    c = _prod_find_conn(req.preq_srv, req.preq_fd)
    if c == 0 return prod_sse_start(req.preq_fd) end
    return prod_sse_start_conn(req.preq_srv, get(req.preq_srv, 2), c)
end

fn prod_sse_send_chunk_req req: ProdReq data
    if req == 0 or req.preq_srv == 0 return prod_sse_send_chunk(req.preq_fd, data) end
    c = _prod_find_conn(req.preq_srv, req.preq_fd)
    if c == 0 return prod_sse_send_chunk(req.preq_fd, data) end
    return prod_sse_send_chunk_conn(req.preq_srv, get(req.preq_srv, 2), c, data)
end

fn prod_sse_send_event_req req: ProdReq event_name data
    if req == 0 or req.preq_srv == 0 return 0 end
    c = _prod_find_conn(req.preq_srv, req.preq_fd)
    if c == 0 return 0 end
    return prod_sse_send_event_conn(req.preq_srv, get(req.preq_srv, 2), c, event_name, data)
end

fn prod_sse_end_req req: ProdReq
    if req == 0 or req.preq_srv == 0 return prod_sse_end(req.preq_fd) end
    c = _prod_find_conn(req.preq_srv, req.preq_fd)
    if c == 0 return prod_sse_end(req.preq_fd) end
    return prod_sse_end_conn(req.preq_srv, get(req.preq_srv, 2), c)
end

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

fn prod_ws_encode_server_frame_buf opcode data_ptr plen fin
    // WHY: Encodes RFC 6455 unmasked server->client frame into an O(N) ByteBuffer so it can be
    // transparently encrypted over TLS 1.3 (WSS) and queued via non-blocking EPOLLOUT backpressure.
    b = buf_new(16 + plen)
    b0 = opcode & 15
    if fin != 0
        b0 = b0 | 128
    end
    buf_write_byte(b, b0)
    if plen <= 125
        buf_write_byte(b, plen & 127)
    elif plen <= 65535
        buf_write_byte(b, 126)
        buf_write_byte(b, (plen >> 8) & 255)
        buf_write_byte(b, plen & 255)
    else
        buf_write_byte(b, 127)
        buf_write_byte(b, (plen >> 56) & 255)
        buf_write_byte(b, (plen >> 48) & 255)
        buf_write_byte(b, (plen >> 40) & 255)
        buf_write_byte(b, (plen >> 32) & 255)
        buf_write_byte(b, (plen >> 24) & 255)
        buf_write_byte(b, (plen >> 16) & 255)
        buf_write_byte(b, (plen >> 8) & 255)
        buf_write_byte(b, plen & 255)
    end
    if plen > 0 and data_ptr != 0
        buf_write_mem(b, data_ptr, plen)
    end
    return b
end

fn prod_ws_send_frame_conn srv epfd c: ProdConn opcode data_ptr plen fin
    if c == 0 or c.pconn_closed == 1 return 0 end
    b = prod_ws_encode_server_frame_buf(opcode, data_ptr, plen, fin)
    res = prod_conn_enqueue_write(srv, epfd, c, buf_ptr(b), buf_len(b))
    buf_free(b)
    return res
end

fn prod_ws_send_text_conn srv epfd c: ProdConn msg
    ms = str(msg)
    return prod_ws_send_frame_conn(srv, epfd, c, 1, _prod_raw_ptr(ms), len(ms), 1)
end

fn prod_ws_send_binary_conn srv epfd c: ProdConn data_ptr data_len
    return prod_ws_send_frame_conn(srv, epfd, c, 2, data_ptr, data_len, 1)
end

fn prod_ws_send_pong_conn srv epfd c: ProdConn payload_ptr payload_len
    plen = payload_len
    if plen > 125 plen = 125 end
    return prod_ws_send_frame_conn(srv, epfd, c, 10, payload_ptr, plen, 1)
end

fn prod_ws_send_close_conn srv epfd c: ProdConn status_code
    if c == 0 or c.pconn_closed == 1 return 0 end
    code = status_code
    if code <= 0 code = 1000 end
    cb = prod_malloc(8)
    mem_byte_write(cb, 0, (code >> 8) & 255)
    mem_byte_write(cb, 1, code & 255)
    res = prod_ws_send_frame_conn(srv, epfd, c, 8, cb, 2, 1)
    prod_free(cb, 8)
    return res
end

fn prod_ws_send_fd srv fd opcode payload plen
    // WHY: Lets custom WebSocket handlers push non-blocking WS / TLS 1.3 WSS frames by fd!
    c = _prod_find_conn(srv, fd)
    if c == 0 return 0 end
    return prod_ws_send_frame_conn(srv, get(srv, 2), c, opcode, _prod_raw_ptr(payload), plen, 1)
end

fn prod_ws_send_text_fd srv fd msg
    ms = str(msg)
    return prod_ws_send_fd(srv, fd, 1, ms, len(ms))
end

fn prod_send_ws_upgrade_response_conn srv epfd c: ProdConn client_key
    // WHY: Enqueues HTTP/1.1 101 WebSocket Upgrade via prod_conn_enqueue_write so WSS over TLS 1.3
    // encrypts the 101 Switching Protocols handshake and never blocks the epoll event loop!
    if c == 0 or c.pconn_closed == 1 return 0 end
    use_key = client_key
    if len(use_key) == 0
        use_key = "dGhlIHNhbXBsZSBub25jZQ=="
    end
    accept_tok = ws_compute_accept_key(use_key)
    resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept_tok + "\r\n\r\n"
    prod_conn_enqueue_write(srv, epfd, c, _prod_raw_ptr(resp), len(resp))
    return 1
end

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

// ── Per-Connection Table Management (O(1) DICT0 Lookup by FD) ─────────────────
fn _prod_find_conn srv fd
    cmap = get(srv, 9)
    if cmap != 0 and has_key(cmap, fd) == 1
        c = cmap[fd]
        if c != 0 and c.pconn_closed == 0
            return c
        end
    end
    return 0

fn _prod_add_conn_tls srv fd tls_sess
    conns = get(srv, 8)
    cmap = get(srv, 9)
    raw_b = 0
    if tls_sess != 0
        raw_b = buf_new(4096)
    end
    c = ProdConn(fd, 0, buf_new(4096), buf_new(1024), buf_new(256), 0, "/", 0, clock_ms(), 0, tls_sess, raw_b)
    push(conns, c)
    if cmap != 0
        cmap[fd] = c
    end
    return c

fn _prod_add_conn srv fd
    return _prod_add_conn_tls(srv, fd, 0)

fn _prod_close_conn srv epfd c: ProdConn
    if c == 0 or c.pconn_closed == 1 return 0
    c.pconn_closed = 1
    cmap = get(srv, 9)
    if cmap != 0 and has_key(cmap, c.pconn_fd) == 1
        del_key(cmap, c.pconn_fd)
    end
    prod_epoll_del(epfd, c.pconn_fd)
    syscall(SYS_CLOSE, c.pconn_fd, 0, 0, 0, 0, 0)
    if c.pconn_read_buf != 0
        buf_free(c.pconn_read_buf)
        c.pconn_read_buf = 0
    if c.pconn_write_buf != 0
        buf_free(c.pconn_write_buf)
        c.pconn_write_buf = 0
    if c.pconn_ws_frag != 0
        buf_free(c.pconn_ws_frag)
        c.pconn_ws_frag = 0
    if c.pconn_tls_raw_buf != 0
        buf_free(c.pconn_tls_raw_buf)
        c.pconn_tls_raw_buf = 0
    end
    c.pconn_tls_session = 0
    // Periodically compact closed zombies if dead list outgrows active map
    conns = get(srv, 8)
    if conns != 0 and conns.len() > 64
        _prod_compact_conns(srv)
    end
    return 0

fn _prod_drain_tls_records srv c: ProdConn
    // WHY: Unwraps all complete RFC 8446 TLS 1.3 records queued in pconn_tls_raw_buf into pconn_read_buf.
    if c == 0 or c.pconn_tls_session == 0 or c.pconn_tls_raw_buf == 0 return 0 end
    dec_fn = get(srv, 19)
    if dec_fn == 0 return 0 end
    while c.pconn_closed == 0
        av = buf_len(c.pconn_tls_raw_buf)
        if av < 5 break end
        rp = buf_ptr(c.pconn_tls_raw_buf)
        ctype = mem_byte_read(rp, 0) & 255
        rlen = ((mem_byte_read(rp, 3) & 255) * 256) | (mem_byte_read(rp, 4) & 255)
        if rlen > 32768
            return 0 - 1
        end
        tot = 5 + rlen
        if av < tot break end
        if ctype == 20
            // Ignore TLS 1.3 middlebox compatibility ChangeCipherSpec record
            _prod_buf_consume(c.pconn_tls_raw_buf, tot)
            continue
        end
        if ctype == 21
            // Plaintext TLS Alert record: close connection cleanly
            _prod_buf_consume(c.pconn_tls_raw_buf, tot)
            return 0 - 1
        end
        rec = list()
        ri = 0
        while ri < tot
            push(rec, mem_byte_read(rp, ri) & 255)
            ri = ri + 1
        end
        _prod_buf_consume(c.pconn_tls_raw_buf, tot)
        pt = dec_fn(c.pconn_tls_session, rec)
        if is_str(pt) == 1
            pt_len = len(pt)
            if pt_len == 0
                // WHY: AEAD decrypt failure or close_notify on legacy string decryptor closes connection.
                return 0 - 1
            end
            buf_write_mem(c.pconn_read_buf, pt, pt_len)
        else
            // WHY: Status-aware decryptor [status, payload]: -1 = AEAD failure/close_notify (close!),
            // 0 = benign post-handshake (e.g. KeyUpdate(0)), 1 = decrypted application payload,
            // 2 = server KeyUpdate(0) encrypted wire byte list to enqueue directly on socket.
            d_st = get(pt, 0)
            if d_st < 0
                return 0 - 1
            end
            if d_st == 1
                d_txt = get(pt, 1)
                d_len = len(d_txt)
                if d_len > 0
                    buf_write_mem(c.pconn_read_buf, d_txt, d_len)
                end
            elif d_st == 2
                ku_wire = get(pt, 1)
                ku_n = len(ku_wire)
                if ku_n > 0
                    ku_b = buf_new(ku_n)
                    ki = 0
                    while ki < ku_n
                        buf_write_byte(ku_b, get(ku_wire, ki) & 255)
                        ki = ki + 1
                    end
                    _prod_conn_enqueue_raw(srv, get(srv, 2), c, buf_ptr(ku_b), buf_len(ku_b))
                    buf_free(ku_b)
                end
            end
        end
    end
    return 1

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
    // Default echo if no custom WebSocket route registered (non-blocking + TLS 1.3 WSS safe!)
    prod_ws_send_frame_conn(srv, get(srv, 2), c, opcode, _prod_raw_ptr(payload), plen, 1)
    return 1

fn _prod_process_ws_frames srv epfd c: ProdConn
    while c.pconn_closed == 0
        av = buf_len(c.pconn_read_buf)
        if av < 2 break
        fr = ws_parse_frame(buf_ptr(c.pconn_read_buf), av, 1)
        if fr.ws_ok == 0 break
        if fr.ws_ok < 0
            prod_ws_send_close_conn(srv, epfd, c, 1002)
            if buf_len(c.pconn_write_buf) > 0
                c.pconn_close_after_write = 1
            else
                _prod_close_conn(srv, epfd, c)
            end
            break
        _prod_buf_consume(c.pconn_read_buf, fr.ws_consumed)
        op = fr.ws_opcode
        if op == 8
            // RFC 6455 Close handshake: enqueue non-blocking Close (TLS 1.3 safe) and flush before shutdown
            prod_ws_send_close_conn(srv, epfd, c, 1000)
            if buf_len(c.pconn_write_buf) > 0
                c.pconn_close_after_write = 1
            else
                _prod_close_conn(srv, epfd, c)
            end
            break
        elif op == 9
            // RFC 6455 Ping -> automatic non-blocking Pong (TLS 1.3 WSS safe) with exact echoed payload
            prod_ws_send_pong_conn(srv, epfd, c, _prod_raw_ptr(fr.ws_payload), fr.ws_payload_len)
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

fn _prod_validate_framing_headers hdr_str
    // WHY: RFC 9112 §6.3 HTTP request smuggling defense: rejects requests containing BOTH
    // Transfer-Encoding AND Content-Length, conflicting duplicate Content-Length headers,
    // or non-numeric Content-Length values with 400 Bad Request.
    // Returns [ok, is_chunked, content_length].
    lines = string_split(hdr_str, "\n")
    has_te = 0
    is_chunked = 0
    cl_count = 0
    cl_val = 0
    i = 1
    while i < len(lines)
        ln = str_trim(get(lines, i))
        colon = str_index_of(ln, ":")
        if colon > 0
            hn = _prod_to_lower_ascii(str_trim(str_sub(ln, 0, colon)))
            hv = str_trim(str_sub(ln, colon + 1, len(ln)))
            if hn == "transfer-encoding"
                has_te = 1
                if str_contains(_prod_to_lower_ascii(hv), "chunked") == 1
                    is_chunked = 1
                end
            elif hn == "content-length"
                // WHY: Guard against 64-bit signed integer wrap (> 15 digits) as well as non-digits!
                if len(hv) == 0 or len(hv) > 15
                    return [0, 0, 0]
                end
                // Validate strict non-negative ASCII digits only
                ci = 0
                cur_cl = 0
                while ci < len(hv)
                    ch = mem_byte_read(hv, ci) & 255
                    if ch < 48 or ch > 57
                        return [0, 0, 0]
                    end
                    cur_cl = (cur_cl * 10) + (ch - 48)
                    ci = ci + 1
                end
                if cl_count > 0 and cur_cl != cl_val
                    return [0, 0, 0]
                end
                cl_val = cur_cl
                cl_count = cl_count + 1
            end
        end
        i = i + 1
    end
    // WHY: RFC 9112 §6.3 forbids BOTH Transfer-Encoding + Content-Length AND any request
    // Transfer-Encoding whose final encoding is not `chunked` (classic TE smuggling vectors).
    if has_te == 1 and (cl_count > 0 or is_chunked == 0)
        return [0, 0, 0]
    end
    return [1, is_chunked, cl_val]
end

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

        // Check WebSocket Upgrade (non-blocking + TLS 1.3 WSS transparent via prod_conn_enqueue_write!)
        if prod_is_websocket_upgrade(p, hend) == 1
            ws_k = ws_extract_key(hdr_s + "\r\n")
            prod_send_ws_upgrade_response_conn(srv, epfd, c, ws_k)
            _prod_buf_consume(c.pconn_read_buf, body_off)
            c.pconn_mode = 1
            c.pconn_ws_path = path
            _prod_process_ws_frames(srv, epfd, c)
            break

        // Determine body framing (Transfer-Encoding: chunked vs Content-Length) with RFC 9112 smuggling guard
        fr_chk = _prod_validate_framing_headers(hdr_s)
        if get(fr_chk, 0) != 1
            prod_send_response_conn(srv, epfd, c, 400, "text/plain; charset=utf-8", "Bad Request")
            _prod_buf_consume(c.pconn_read_buf, av)
            if buf_len(c.pconn_write_buf) > 0
                c.pconn_close_after_write = 1
            else
                _prod_close_conn(srv, epfd, c)
            end
            break
        end
        body_str = ""
        total_req_bytes = body_off
        if get(fr_chk, 1) == 1
            chk = _prod_decode_chunked_check(p + body_off, body_av)
            if get(chk, 0) == 0
                // Wait for remaining chunks
                break
            total_req_bytes = body_off + get(chk, 1)
            body_str = get(chk, 2)
        else
            clen = get(fr_chk, 2)
            if body_av < clen
                // Wait for full Content-Length body across non-blocking reads
                break
            if clen > 0
                body_str = bytes_to_str(p + body_off, clen)
            total_req_bytes = body_off + clen

        _prod_buf_consume(c.pconn_read_buf, total_req_bytes)

        // Dynamic O(depth) Radix/Trie Route Dispatch (fallback to legacy list if needed)
        req = ProdReq(method, path, query, hdr_s, body_str, c.pconn_fd, srv)
        matched = 0
        rhfn = prod_radix_match(get(srv, 12), method, path)
        if rhfn != 0
            matched = 1
            res = rhfn(req)
            if is_str(res) == 1
                prod_send_response_conn(srv, epfd, c, 200, "text/plain; charset=utf-8", res)
            end
        else
            routes = get(srv, 6)
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
                            prod_send_response_conn(srv, epfd, c, 200, "text/plain; charset=utf-8", res)
                        end
                    end
                    break
                end
                ri = ri + 1
            end
        end

        if matched == 0
            // WHY: Preserve built-in /health & /metrics probes, but return RFC 9110 404 Not Found
            // on all unmatched routes instead of returning a misleading 200 OK.
            if path == "/health"
                prod_send_json_response_conn(srv, epfd, c, 200, "{\"status\":\"UP\",\"server\":\"Lipi-Production\"}")
            elif path == "/metrics"
                prod_send_json_response_conn(srv, epfd, c, 200, "{\"uptime_cycles\":1000000,\"status\":200}")
            else
                prod_send_json_response_conn(srv, epfd, c, 404, "{\"error\":\"Not Found\"}")
            end
        end

        conn_hdr = _prod_to_lower_ascii(_prod_extract_hdr_value(hdr_s, "connection"))
        if conn_hdr == "close"
            if buf_len(c.pconn_write_buf) > 0
                c.pconn_close_after_write = 1
            else
                _prod_close_conn(srv, epfd, c)
            end
            break
        end
    return 0

// ── Epoll Reactor Tick (Multi-Connection Non-Blocking, TLS 1.3 + Idle Reaper + 413 Guard) ──
fn prod_server_tick srv timeout_ms
    epfd = get(srv, 2)
    listen_fd = get(srv, 1)
    ev_buf = get(srv, 4)
    max_events = get(srv, 5)
    rbuf = get(srv, 10)
    ev_scratch = get(srv, 11)
    tls_hook = get(srv, 13)
    idle_ms = get(srv, 14)
    max_read_b = get(srv, 16)
    tls_eng = get(srv, 17)
    tls_acc = get(srv, 18)

    nfds = syscall(SYS_EPOLL_WAIT, epfd, ev_buf, max_events, timeout_ms, 0, 0)
    if nfds == (0 - 4)
        nfds = syscall(SYS_EPOLL_WAIT, epfd, ev_buf, max_events, timeout_ms, 0, 0)
    end

    // Automatic Slowloris / idle keep-alive reaper
    if idle_ms > 0
        now_sw = clock_ms()
        last_sw = get(srv, 15)
        sweep_iv = idle_ms / 2
        if sweep_iv < 10 sweep_iv = 10 end
        if sweep_iv > 500 sweep_iv = 500 end
        if (now_sw - last_sw) >= sweep_iv
            prod_server_sweep_idle(srv, idle_ms)
            list_set(srv, 15, now_sw)
        end
    end

    if nfds <= 0 return nfds

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
                if client_fd == (0 - 4) continue end
                if client_fd < 0 break
                tls_sess = 0
                if tls_eng != 0 and tls_acc != 0
                    // Enforce 5s handshake SO_RCVTIMEO/SO_SNDTIMEO before blocking TLS accept
                    tv_hs = malloc(16)
                    if tv_hs > 0
                        mem_write(tv_hs, 0, 5)
                        mem_write(tv_hs, 8, 0)
                        syscall(54, client_fd, 1, 20, tv_hs, 16, 0)
                        syscall(54, client_fd, 1, 21, tv_hs, 16, 0)
                        free(tv_hs, 16)
                    end
                    tls_sess = tls_acc(client_fd, tls_eng)
                    if tls_sess == 0
                        syscall(SYS_CLOSE, client_fd, 0, 0, 0, 0, 0)
                        continue
                    end
                elif tls_hook != 0
                    if tls_hook(client_fd) <= 0
                        syscall(SYS_CLOSE, client_fd, 0, 0, 0, 0, 0)
                        continue
                    end
                end
                prod_set_nonblocking(client_fd)
                prod_epoll_ctl_buf(epfd, EPOLL_CTL_ADD, client_fd, EPOLLIN, ev_scratch)
                _prod_add_conn_tls(srv, client_fd, tls_sess)
        else
            c = _prod_find_conn(srv, c_fd)
            if c == 0
                c = _prod_add_conn(srv, c_fd)
            c.pconn_last_active_ms = clock_ms()
            if (ev_mask & EPOLLOUT) != 0 and c.pconn_closed == 0
                prod_conn_flush_writes(srv, epfd, c)
            end
            if (ev_mask & (EPOLLERR | EPOLLHUP)) != 0 and (ev_mask & EPOLLIN) == 0
                _prod_close_conn(srv, epfd, c)
            elif (ev_mask & EPOLLIN) != 0 and c.pconn_closed == 0
                // Drain non-blocking socket until EAGAIN (-11) or EOF (0) enforcing max_read_bytes cap
                closed_now = 0
                overflowed = 0
                while 1 == 1
                    nread = syscall(SYS_READ, c_fd, rbuf, 8192, 0, 0, 0)
                    if nread > 0
                        if c.pconn_tls_session != 0 and c.pconn_tls_raw_buf != 0
                            if max_read_b > 0 and (buf_len(c.pconn_tls_raw_buf) + nread) > max_read_b
                                overflowed = 1
                                break
                            end
                            buf_write_mem(c.pconn_tls_raw_buf, rbuf, nread)
                        else
                            if max_read_b > 0 and (buf_len(c.pconn_read_buf) + nread) > max_read_b
                                overflowed = 1
                                break
                            end
                            buf_write_mem(c.pconn_read_buf, rbuf, nread)
                        end
                    elif nread == 0
                        closed_now = 1
                        break
                    elif nread == (0 - 4)
                        continue
                    else
                        break
                if overflowed == 1
                    prod_send_response_conn(srv, epfd, c, 413, "text/plain; charset=utf-8", "Payload Too Large")
                    if buf_len(c.pconn_write_buf) > 0
                        c.pconn_close_after_write = 1
                    else
                        _prod_close_conn(srv, epfd, c)
                    end
                    i = i + 1
                    continue
                end
                if c.pconn_tls_session != 0
                    if _prod_drain_tls_records(srv, c) < 0
                        _prod_close_conn(srv, epfd, c)
                        i = i + 1
                        continue
                    end
                    if max_read_b > 0 and buf_len(c.pconn_read_buf) > max_read_b
                        prod_send_response_conn(srv, epfd, c, 413, "text/plain; charset=utf-8", "Payload Too Large")
                        if buf_len(c.pconn_write_buf) > 0
                            c.pconn_close_after_write = 1
                        else
                            _prod_close_conn(srv, epfd, c)
                        end
                        i = i + 1
                        continue
                    end
                end
                if c.pconn_mode == 0
                    _prod_process_http(srv, epfd, c)
                elif c.pconn_mode == 1
                    _prod_process_ws_frames(srv, epfd, c)
                if closed_now == 1 and c.pconn_closed == 0
                    if buf_len(c.pconn_write_buf) > 0
                        c.pconn_close_after_write = 1
                    else
                        _prod_close_conn(srv, epfd, c)
                    end
                end
        i = i + 1
    return nfds

// ── Graceful Shutdown ─────────────────────────────────────────────────────────
fn prod_server_close srv
    listen_fd = get(srv, 1)
    epfd = get(srv, 2)
    ev_buf = get(srv, 4)
    max_events = get(srv, 5)
    conns = get(srv, 8)
    rbuf = get(srv, 10)
    ev_scratch = get(srv, 11)

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
    if rbuf > 0
        prod_free(rbuf, 8192)
        list_set(srv, 10, 0)
    if ev_scratch > 0
        prod_free(ev_scratch, 16)
        list_set(srv, 11, 0)

    list_set(srv, 3, 0)
    return 0
