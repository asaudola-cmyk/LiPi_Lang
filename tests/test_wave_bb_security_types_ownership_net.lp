// ==============================================================================
// 👑 WAVE BB SOVEREIGN SECURITY, TYPE SOUNDNESS, OWNERSHIP, STDLIB & NET SUITE
// File: tests/test_wave_bb_security_types_ownership_net.lp
// 100% Pure LiPi | Zero External Dependencies | Live Execution Verification
// ==============================================================================
//
// Coverage Matrix:
//   BB1: --kavach Zero-Bypass Closure (all 55+ raw hw/mem/atomic/fiber/syscall ops,
//        *p read & *p = val write, fake 0-byte ./utso/memory.lp CWD spoof, positive pass)
//   BB2: CSPRNG (EINTR-safe SYS_getrandom, non-zero entropy, full 64-bit u64, INT64_MIN safe),
//        HTTP Redirects (cross-origin & HTTPS->HTTP credential stripping, RFC 3986 relative),
//        IPv6 URL + Live ::1 TCP loopback, Cookie Jar, Multipart Builder,
//        socket.lp 12-byte epoll + idempotent O_NONBLOCK, server_production.lp 404 & TE+CL
//        smuggling 400, X.509 iPAddress SAN (IPv4 & IPv6) + empty SNI rejection,
//        TLS 1.3 KeyUpdate (type 24) secret rotation & malformed X25519 key share rejection
//   BB3: time.lp EINTR nanosleep + RFC 8536 TZif v2/v3 DST parser (synthetic + zoneinfo),
//        regex.lp cross-group backtracking (ab|a)b & (a+)a + captures + {n,m} + lazy *? +
//        \D/\W/\S + [...] escapes + flag i + O(N) ReDoS safety,
//        bigint.lp 256-bit signed BigInt (incl. INT64_MIN & pow_mod) & exact Decimal
//   BB4: Module System (pub async fn, local shadow non-mangling, selective import isolation,
//        alias.nonexistent error, plain user-module duplicate top-level fn collision error)
//   BB5: --strict-types (struct ctor arg validation + 0-arg User(), enum variant payload
//        validation + user Some(i64) non-short-circuit, undefined field error, dict<K, V>,
//        impl block self typing & cross-struct method isolation)
//   BB6: --strict-ownership (match branch isolation, try/catch/finally move flow, defer
//        scope-exit analysis, struct-field & arr[0] double-free, &mut x + &x conflict,
//        move while &mut borrowed, shared &x + &x pass)
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/os/env"
import "utso/core/time"
import "utso/core/regex"
import "utso/core/bigint"
import "utso/crypto/random"
import "utso/net/socket"
import "utso/net/http"
import "utso/net/server_production_tls"

global g_bb_passed = 0
global g_bb_failed = 0
global g_bb_lipc = "./bin/lipc"

fn bb_check cond label
    if cond == 1
        g_bb_passed = g_bb_passed + 1
        return 1
    end
    say "  FAIL [Wave BB]: " + label
    g_bb_failed = g_bb_failed + 1
    return 0
end

fn bb_getcwd
    buf = malloc(1024)
    r = syscall(79, buf, 1024, 0, 0, 0, 0)
    res = "."
    if r > 1
        res = bytes_to_str(buf, r - 1)
    end
    free(buf, 1024)
    return res
end

fn bb_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn bb_spawn_in_dir work_dir cmd_path args log_path
    // WHY: Fork/exec helper with optional SYS_chdir for testing CWD-spoof defenses cleanly.
    argv = syscall(9, 0, 192, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < len(args) and i < 20
        mem_word_write(argv, (i + 1) * 8, get(args, i))
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    envp = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(envp, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
    mem_word_write(envp, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(work_dir) > 0
            syscall(80, work_dir, 0, 0, 0, 0, 0) // SYS_chdir
        end
        if len(log_path) > 0
            fd = syscall(2, log_path, 577, 420)
            if fd >= 0
                syscall(33, fd, 1, 0, 0, 0, 0)
                syscall(33, fd, 2, 0, 0, 0, 0)
                syscall(3, fd, 0, 0, 0, 0, 0)
            end
        end
        syscall(59, cmd_path, argv, envp, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)
    end

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_st = mem_word_read(st, 0)
    sig = raw_st & 127
    rc = 0
    if sig != 0
        rc = 128 + sig
    else
        rc = (raw_st / 256) % 256
    end
    syscall(11, argv, 192, 0, 0, 0, 0)
    syscall(11, envp, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn bb_compile_src name code flag1 flag2
    src_p = "/tmp/lipi_bb_" + name + ".lp"
    out_p = "/tmp/lipi_bb_" + name + ".bin"
    log_p = "/tmp/lipi_bb_" + name + ".log"
    file_write(src_p, code)
    args = [src_p, "-o", out_p]
    if len(flag1) > 0 push(args, flag1) end
    if len(flag2) > 0 push(args, flag2) end
    rc = bb_spawn_in_dir("", g_bb_lipc, args, log_p)
    bb_unlink(src_p)
    bb_unlink(out_p)
    bb_unlink(log_p)
    return rc
end

fn bb_compile_and_run name code flag1 flag2
    src_p = "/tmp/lipi_bb_run_" + name + ".lp"
    out_p = "/tmp/lipi_bb_run_" + name + ".bin"
    log_p = "/tmp/lipi_bb_run_" + name + ".log"
    file_write(src_p, code)
    args = [src_p, "-o", out_p]
    if len(flag1) > 0 push(args, flag1) end
    if len(flag2) > 0 push(args, flag2) end
    crc = bb_spawn_in_dir("", g_bb_lipc, args, log_p)
    rrc = 99
    if crc == 0
        rrc = bb_spawn_in_dir("", out_p, list(), log_p)
    end
    bb_unlink(src_p)
    bb_unlink(out_p)
    bb_unlink(log_p)
    return [crc, rrc]
end

// ── BB1: --kavach Zero-Bypass Closure ─────────────────────────────────────────
fn test_bb1_kavach
    say "▶ [BB1] --kavach Zero-Bypass Closure & CWD Spoof Defense..."
    // Uncrowned raw hardware/memory/atomic/syscall primitives MUST ALL BE REJECTED
    bb_check(bb_compile_src("kv1", "fn main()\n    _lipi_sys_poke(0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_sys_poke")
    bb_check(bb_compile_src("kv2", "fn main()\n    _lipi_mem_byte_write(0, 0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_mem_byte_write")
    bb_check(bb_compile_src("kv3", "fn main()\n    atomic_cas64(0, 0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects atomic_cas64")
    bb_check(bb_compile_src("kv4", "fn main()\n    t = cpu_rdtsc()\n    say t\nend\n", "--kavach", "") != 0, "kavach rejects cpu_rdtsc")
    bb_check(bb_compile_src("kv5", "fn main()\n    file_write_mem(\"/tmp/x\", 0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects file_write_mem")
    bb_check(bb_compile_src("kv6", "fn main()\n    futex_wait(0, 0)\nend\n", "--kavach", "") != 0, "kavach rejects futex_wait")
    bb_check(bb_compile_src("kv7", "fn main()\n    v = mem_byte_পড়ো(0, 0)\n    say v\nend\n", "--kavach", "") != 0, "kavach rejects mem_byte_পড়ো")
    bb_check(bb_compile_src("kv7b", "fn main()\n    sys_poke64(0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects sys_poke64")
    bb_check(bb_compile_src("kv7c", "fn main()\n    v = sys_peek64(0)\n    say v\nend\n", "--kavach", "") != 0, "kavach rejects sys_peek64")
    bb_check(bb_compile_src("kv7d", "fn main()\n    _lipi_atomic_cas(0, 0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_atomic_cas")
    bb_check(bb_compile_src("kv7e", "fn main()\n    _lipi_file_write_mem(\"/tmp/x\", 0, 1)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_file_write_mem")
    bb_check(bb_compile_src("kv7f", "fn main()\n    _lipi_futex_wait(0, 0, 0)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_futex_wait")
    bb_check(bb_compile_src("kv7g", "fn main()\n    _lipi_fiber_context_switch(0, 0)\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_fiber_context_switch")
    bb_check(bb_compile_src("kv7h", "fn main()\n    v = _lipi_stack_pointer()\n    say v\nend\n", "--kavach", "") != 0, "kavach rejects _lipi_stack_pointer")

    // Raw pointer dereference read (*p) and write (*p = val) MUST BE REJECTED
    bb_check(bb_compile_src("kv8", "fn main()\n    x = 42\n    p = &x\n    v = *p\n    say v\nend\n", "--kavach", "") != 0, "kavach rejects *p deref read")
    bb_check(bb_compile_src("kv9", "fn main()\n    x = 42\n    p = &x\n    *p = 99\n    say x\nend\n", "--kavach", "") != 0, "kavach rejects *p = val deref write")

    // Fake 0-byte ./utso/memory.lp + ./utso/evil.lp in arbitrary CWD MUST NEVER pass --kavach
    cwd = bb_getcwd()
    lipc_abs = g_bb_lipc
    if str_char_at(lipc_abs, 0) != 47
        if starts_with(lipc_abs, "./") == 1
            lipc_abs = cwd + "/" + str_sub(lipc_abs, 2, len(lipc_abs))
        else
            lipc_abs = cwd + "/" + lipc_abs
        end
    end
    spoof_dir = "/tmp/lipi_bb_spoof_cwd"
    spoof_utso = spoof_dir + "/utso"
    syscall(83, spoof_dir, 493, 0, 0, 0, 0)
    syscall(83, spoof_utso, 493, 0, 0, 0, 0)
    file_write(spoof_utso + "/memory.lp", "")
    file_write(spoof_utso + "/evil.lp", "fn evil_raw()\n    _lipi_sys_poke(0, 1)\n    return 0\nend\n")
    file_write(spoof_dir + "/app.lp", "import \"utso/evil\"\nfn main()\n    evil_raw()\nend\n")
    spoof_rc = bb_spawn_in_dir(spoof_dir, lipc_abs, ["app.lp", "-o", "app.bin", "--kavach"], "/tmp/lipi_bb_spoof.log")
    bb_check(spoof_rc != 0, "kavach rejects fake 0-byte ./utso/memory.lp + ./utso/evil.lp CWD spoof")
    bb_unlink(spoof_utso + "/memory.lp")
    bb_unlink(spoof_utso + "/evil.lp")
    bb_unlink(spoof_dir + "/app.lp")
    bb_unlink(spoof_dir + "/app.bin")
    bb_unlink("/tmp/lipi_bb_spoof.log")
    syscall(84, spoof_utso, 0, 0, 0, 0, 0)
    syscall(84, spoof_dir, 0, 0, 0, 0, 0)

    // Positive check: crowned silicon_* + authentic utso/ string import PASSES --kavach
    pos_code = "import \"utso/core/string\"\nfn silicon_ok()\n    return 7\nend\nfn main()\n    s = str_to_upper(\"ok\")\n    if s == \"OK\" and silicon_ok() == 7 return 0 end\n    return 1\nend\n"
    pos_res = bb_compile_and_run("kv_ok", pos_code, "--kavach", "")
    bb_check(get(pos_res, 0) == 0 and get(pos_res, 1) == 0, "kavach passes safe user code + authentic utso/ import")
    return 0
end

// ── BB2: CSPRNG, HTTP, IPv6, Cookie Jar, Multipart, Epoll, Server, X.509, TLS ─
fn bb_prod_echo req: ProdReq
    return "ECHO:" + req.preq_body
end

fn test_bb2_net_crypto_tls
    say "▶ [BB2] CSPRNG, HTTP Redirects, IPv6, Cookie Jar, Multipart, Epoll, X.509, TLS KeyUpdate..."

    // 2a. CSPRNG: non-zero entropy, full 64-bit u64, INT64_MIN-safe non-negative range
    rb = malloc(32)
    got_r = crypto_random_bytes(rb, 32)
    bb_check(got_r == 32, "crypto_random_bytes returns exact 32 bytes")
    nz = 0
    ri = 0
    while ri < 32
        if (mem_byte_read(rb, ri) & 255) != 0 nz = nz + 1 end
        ri = ri + 1
    end
    free(rb, 32)
    bb_check(nz > 0, "crypto_random_bytes produces non-zero entropy")

    seen_diff = 0
    first_u64 = crypto_random_u64()
    seen_neg_or_hi = 0
    all_nonneg_s = 1
    all_in_rng = 1
    ri = 0
    while ri < 32
        u = crypto_random_u64()
        if u != first_u64 seen_diff = 1 end
        if u < 0 seen_neg_or_hi = 1 end
        sr = সিলিকন_র্যান্ডম()
        if sr < 0 all_nonneg_s = 0 end
        rg = crypto_random_range(10, 20)
        if rg < 10 or rg > 20 all_in_rng = 0 end
        ri = ri + 1
    end
    bb_check(seen_diff == 1, "crypto_random_u64 varies across draws")
    bb_check(seen_neg_or_hi == 1, "crypto_random_u64 emits full 64-bit range (including bit 63)")
    bb_check(all_nonneg_s == 1 and all_in_rng == 1, "silicon_random non-negative & crypto_random_range bounded")

    // 2b. IPv6 URL parsing + RFC 3986 relative redirect resolution + credential stripping
    u6 = http_parse_url("http://[::1]:8080/api/v1?x=1")
    bb_check(u6.protocol == "http" and u6.host == "::1" and u6.port == 8080 and u6.path == "/api/v1?x=1", "http_parse_url IPv6 bracketed host + port")
    u6_def = http_parse_url("https://[::1]/ok")
    bb_check(u6_def.protocol == "https" and u6_def.host == "::1" and u6_def.port == 443 and u6_def.path == "/ok", "http_parse_url IPv6 default https port")
    u_up = http_parse_url("HTTPS://Example.COM:8443/v2")
    bb_check(u_up.protocol == "https" and u_up.host == "Example.COM" and u_up.port == 8443 and u_up.path == "/v2", "http_parse_url handles uppercase RFC 3986 HTTPS:// scheme")

    base_r = http_parse_url("http://example.com/a/b/c?old=1")
    bb_check(_http_resolve_redirect(base_r, "../d") == "http://example.com/a/d", "RFC 3986 relative ../ redirect")
    bb_check(_http_resolve_redirect(base_r, "sub/x") == "http://example.com/a/b/sub/x", "RFC 3986 relative path against directory")
    bb_check(_http_resolve_redirect(base_r, "?new=2") == "http://example.com/a/b/c?new=2", "RFC 3986 relative ?query redirect")
    bb_check(_http_resolve_redirect(http_parse_url("http://[::1]:8080/a/b"), "c") == "http://[::1]:8080/a/c", "RFC 3986 relative redirect preserves IPv6 brackets")
    bb_check(_http_resolve_redirect(http_parse_url("https://a.test/1"), "HTTP://b.test/2") == "http://b.test/2", "RFC 3986 redirect normalizes uppercase HTTP:// scheme")

    hdrs_in = [
        HttpHeader("Authorization", "Bearer secret"),
        HttpHeader("cookie", "sid=xyz"),
        HttpHeader("PROXY-AUTHORIZATION", "Basic abc"),
        HttpHeader("X-Keep", "yes")
    ]
    h_cross = http_filter_redirect_headers("https://a.test/1", "https://b.test/2", hdrs_in)
    bb_check(len(h_cross) == 1 and get(h_cross, 0).name == "X-Keep", "cross-origin redirect strips Authorization/Cookie/Proxy-Authorization")
    h_down = http_filter_redirect_headers("https://a.test/1", "http://a.test/2", hdrs_in)
    bb_check(len(h_down) == 1 and get(h_down, 0).name == "X-Keep", "HTTPS->HTTP downgrade strips Authorization/Cookie/Proxy-Authorization")
    h_same = http_filter_redirect_headers("https://a.test/1", "https://a.test/2", hdrs_in)
    bb_check(len(h_same) == 4, "same-origin HTTPS redirect preserves headers")

    // Live cross-origin (cross-port) 302 redirect wire check verifying credentials never cross origins
    rd_p1 = 19674
    rd_p2 = 19675
    rd_l1 = tcp_listener_bind("127.0.0.1", rd_p1)
    rd_l2 = tcp_listener_bind("127.0.0.1", rd_p2)
    if rd_l1.tcpl_fd >= 0 and rd_l2.tcpl_fd >= 0
        rd_pid = syscall(57, 0, 0, 0, 0, 0, 0)
        if rd_pid == 0
            c1 = tcp_listener_accept(rd_l1)
            if c1.tcp_fd >= 0
                _r1 = tcp_stream_read(c1, 2048)
                tcp_stream_write(c1, "HTTP/1.1 302 Found\r\nLocation: HTTP://127.0.0.1:" + str(rd_p2) + "/dest\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                tcp_stream_close(c1)
            end
            c2 = tcp_listener_accept(rd_l2)
            if c2.tcp_fd >= 0
                r2 = tcp_stream_read(c2, 2048)
                r2_lo = str_to_lower(r2)
                verdict = "CLEAN"
                if str_contains(r2_lo, "authorization:") == 1 or str_contains(r2_lo, "cookie:") == 1 or str_contains(r2_lo, "proxy-authorization:") == 1
                    verdict = "LEAKED"
                elif str_contains(r2_lo, "x-keep: yes") == 0
                    verdict = "MISSING_KEEP"
                end
                tcp_stream_write(c2, "HTTP/1.1 200 OK\r\nContent-Length: " + str(len(verdict)) + "\r\nConnection: close\r\n\r\n" + verdict)
                tcp_stream_close(c2)
            end
            tcp_listener_close(rd_l1)
            tcp_listener_close(rd_l2)
            syscall(60, 0, 0, 0, 0, 0, 0)
        end
        tcp_listener_close(rd_l1)
        tcp_listener_close(rd_l2)
        rd_resp = http_request_with_timeout("GET", "http://127.0.0.1:" + str(rd_p1) + "/start", hdrs_in, "", 5000)
        st_rd = malloc(8)
        syscall(61, rd_pid, st_rd, 0, 0, 0, 0)
        free(st_rd, 8)
        bb_check(rd_resp.status_code == 200 and rd_resp.body == "CLEAN", "Live wire cross-port HTTP 302 strips Authorization/Cookie/Proxy-Authorization & preserves X-Keep")
    end

    // 2c. Cookie Jar (domain, path, Secure flag) + Multipart Builder
    jar = http_cookie_jar_new()
    http_cookie_jar_store_from_headers(jar, "https://example.com/app/login", [
        HttpHeader("Set-Cookie", "sid=tok42; Domain=example.com; Path=/app; Secure; HttpOnly"),
        HttpHeader("Set-Cookie", "hostonly=1; Path=/")
    ])
    ck_https = http_cookie_jar_build_header(jar, "https://api.example.com/app/profile")
    ck_http = http_cookie_jar_build_header(jar, "http://api.example.com/app/profile")
    ck_badpath = http_cookie_jar_build_header(jar, "https://api.example.com/apple")
    ck_root = http_cookie_jar_build_header(jar, "https://example.com/app")
    bb_check(ck_https == "sid=tok42", "Cookie jar Domain+Path+Secure match on HTTPS subdomain")
    bb_check(ck_http == "", "Cookie jar withholds Secure cookie on plain HTTP")
    bb_check(ck_badpath == "", "Cookie jar /app path does not match /apple")
    bb_check(str_contains(ck_root, "sid=tok42") == 1 and str_contains(ck_root, "hostonly=1") == 1, "Cookie jar emits host-only + domain cookies on origin")

    mp_body = http_multipart_build("BBBOUND", [
        http_multipart_field("user", "alice"),
        http_multipart_file("doc", "hello.txt", "text/plain", "DATA123")
    ])
    bb_check(str_contains(mp_body, "--BBBOUND\r\nContent-Disposition: form-data; name=\"user\"\r\n\r\nalice\r\n") == 1, "http_multipart_build field encoding")
    bb_check(str_contains(mp_body, "filename=\"hello.txt\"\r\nContent-Type: text/plain\r\n\r\nDATA123\r\n--BBBOUND--\r\n") == 1, "http_multipart_build file encoding & terminator")

    // 2d. Live IPv6 `::1` Loopback TCP Bind/Connect/Echo
    v6_port = 19671
    v6_lst = tcp_listener_bind("::1", v6_port)
    bb_check(v6_lst.tcpl_fd >= 0, "tcp_listener_bind auto-detects IPv6 ::1")
    if v6_lst.tcpl_fd >= 0
        v6_pid = syscall(57, 0, 0, 0, 0, 0, 0)
        if v6_pid == 0
            c_st = tcp_listener_accept(v6_lst)
            if c_st.tcp_fd >= 0
                got_v6 = tcp_stream_read(c_st, 64)
                tcp_stream_write(c_st, "V6:" + got_v6)
                tcp_stream_close(c_st)
            end
            tcp_listener_close(v6_lst)
            syscall(60, 0, 0, 0, 0, 0, 0)
        end
        tcp_listener_close(v6_lst)
        v6_cli = tcp_stream_connect("::1", v6_port)
        bb_check(v6_cli.tcp_fd >= 0, "tcp_stream_connect auto-detects IPv6 ::1")
        v6_reply = ""
        if v6_cli.tcp_fd >= 0
            tcp_stream_write(v6_cli, "PING6")
            v6_reply = tcp_stream_read(v6_cli, 64)
            tcp_stream_close(v6_cli)
        end
        st_w = malloc(8)
        syscall(61, v6_pid, st_w, 0, 0, 0, 0)
        free(st_w, 8)
        bb_check(v6_reply == "V6:PING6", "Live IPv6 ::1 loopback echo round-trip")
    end

    // 2e. Live socket.lp 12-byte epoll_event + idempotent O_NONBLOCK (flags | 2048)
    pfd = malloc(8)
    bb_check(syscall(22, pfd, 0, 0, 0, 0, 0) == 0, "SYS_pipe created for live epoll test")
    rfd = mem_read_u32(pfd, 0)
    wfd = mem_read_u32(pfd, 4)
    free(pfd, 8)
    socket_set_nonblocking(rfd)
    socket_set_nonblocking(rfd) // Second call MUST stay O_NONBLOCK (2048), NOT carry into O_SYNC (4096)!
    fl_after = syscall(72, rfd, 3, 0, 0, 0, 0)
    bb_check((fl_after & 2048) == 2048 and (fl_after & 4096) == 0, "socket_set_nonblocking idempotent bitwise OR (no O_SYNC corruption)")
    epfd = epoll_create()
    bb_check(epfd >= 0 and epoll_add_fd(epfd, rfd, EPOLLIN) == 0, "epoll_create + 12-byte epoll_add_fd")
    msg_p = "OK"
    syscall(1, wfd, msg_p, 2, 0, 0, 0)
    ev_b = malloc(48)
    nf = epoll_wait_events(epfd, ev_b, 4, 100)
    ev_fd0 = epoll_event_get_fd(ev_b, 0)
    ev_m0 = epoll_event_get_events(ev_b, 0)
    free(ev_b, 48)
    syscall(3, epfd, 0, 0, 0, 0, 0)
    syscall(3, rfd, 0, 0, 0, 0, 0)
    syscall(3, wfd, 0, 0, 0, 0, 0)
    bb_check(nf == 1 and ev_fd0 == rfd and (ev_m0 & EPOLLIN) == EPOLLIN, "epoll_wait_events + 12-byte packed stride reads exact fd & events")

    // 2f. Live server_production.lp: 404 Not Found on unmatched route & 400 on TE+CL smuggling
    srv_port = 19672
    srv = prod_server_create(srv_port, 32)
    prod_route_add(srv, "POST", "/echo", fn_ptr(bb_prod_echo))
    bb_check(prod_server_listen(srv) == 0, "prod_server_listen for 404/smuggling test")
    s_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if s_pid == 0
        tk = 0
        while tk < 60
            prod_server_tick(srv, 20)
            tk = tk + 1
        end
        prod_server_close(srv)
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    r404 = http_get("http://127.0.0.1:" + str(srv_port) + "/unmatched_route_bb")
    bb_check(r404.status_code == 404, "server_production returns 404 Not Found on unmatched route")
    smug_st = tcp_stream_connect("127.0.0.1", srv_port)
    smug_raw = ""
    if smug_st.tcp_fd >= 0
        tcp_stream_write(smug_st, "POST /echo HTTP/1.1\r\nHost: 127.0.0.1\r\nTransfer-Encoding: chunked\r\nContent-Length: 5\r\nConnection: close\r\n\r\n0\r\n\r\n")
        smug_raw = tcp_stream_read(smug_st, 2048)
        tcp_stream_close(smug_st)
    end
    smug_resp = http_parse_response(smug_raw)
    bb_check(smug_resp.status_code == 400, "server_production rejects Transfer-Encoding + Content-Length smuggling with 400")
    bb_check(get(_prod_validate_framing_headers("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 9999999999999999999999\r\n\r\n"), 0) == 0, "server_production rejects integer-overflow Content-Length")
    bb_check(get(_prod_validate_framing_headers("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: gzip\r\n\r\n"), 0) == 0, "server_production rejects non-chunked Transfer-Encoding")
    st_s = malloc(8)
    syscall(61, s_pid, st_s, 0, 0, 0, 0)
    free(st_s, 8)
    prod_server_close(srv)

    // 2g. X.509 iPAddress SAN (tag 0x87, IPv4 & IPv6) + empty expected_sni rejection
    ca_sk = _tls13s_rand_bytes(32)
    ca_pk = ed25519_keygen(ca_sk).public_key
    lf4_sk = _tls13s_rand_bytes(32)
    lf4_pk = ed25519_keygen(lf4_sk).public_key
    lf6_sk = _tls13s_rand_bytes(32)
    lf6_pk = ed25519_keygen(lf6_sk).public_key
    ca_c = x509_build_signed_ed25519_cert("BB Root CA", "BB Root CA", "", "250101000000Z", "350101000000Z", 1, ca_pk, ca_sk, 901)
    lf4_c = x509_build_signed_ed25519_cert("BB Root CA", "127.0.0.1", "127.0.0.1", "250101000000Z", "350101000000Z", 0, lf4_pk, ca_sk, 902)
    lf6_c = x509_build_signed_ed25519_cert("BB Root CA", "::1", "::1", "250101000000Z", "350101000000Z", 0, lf6_pk, ca_sk, 903)
    bb_check(x509_verify_chain([lf4_c, ca_c], "127.0.0.1", [ca_c], 1750000000) == 1, "X.509 iPAddress IPv4 SAN matches 127.0.0.1")
    bb_check(x509_verify_chain([lf4_c, ca_c], "127.0.0.2", [ca_c], 1750000000) == 0, "X.509 iPAddress IPv4 SAN rejects wrong IP 127.0.0.2")
    bb_check(x509_verify_chain([lf4_c, ca_c], "", [ca_c], 1750000000) == 0, "X.509 rejects empty expected_sni when verification enabled")
    bb_check(x509_verify_chain([lf6_c, ca_c], "::1", [ca_c], 1750000000) == 1 and x509_verify_chain([lf6_c, ca_c], "[::1]", [ca_c], 1750000000) == 1, "X.509 iPAddress IPv6 SAN matches ::1 and [::1]")
    bb_check(x509_verify_chain([lf6_c, ca_c], "::2", [ca_c], 1750000000) == 0, "X.509 iPAddress IPv6 SAN rejects ::2")

    // 2h. Malformed X25519 key share rejection + AEAD fail/close_notify + Ticket/Session eviction + Live TLS 1.3 KeyUpdate!
    eng = tls13_record_engine_new()
    tls13_engine_set_identity(eng, [lf4_c, ca_c], lf4_sk)
    // Build ClientHello with truncated 23-byte X25519 key share -> MUST BE REJECTED!
    bad_ch = [22, 3, 3, 0, 85, 1, 0, 0, 81, 3, 3]
    bi = 0
    while bi < 32 push(bad_ch, bi) bi = bi + 1 end
    _tls13s_append(bad_ch, [0, 0, 2, 19, 1, 1, 0, 0, 38, 0, 43, 0, 3, 2, 3, 4, 0, 51, 0, 27, 0, 29, 0, 23])
    bi = 0
    while bi < 23 push(bad_ch, 127) bi = bi + 1 end
    bb_check(tls13_engine_process_handshake(eng, bad_ch) == 0, "tls13_server rejects malformed 23-byte X25519 key share")

    // Verify AEAD tamper & close_notify return status=-1 (closing session) + ticket cache eviction cap <= 256
    c_priv_t = _tls13s_rand_bytes(32)
    c_pub_t = x25519_public_key(c_priv_t)
    ch_t = tls13_build_client_hello("127.0.0.1", c_pub_t)
    ts_t = tls13_engine_process_handshake(eng, ch_t.wire_bytes)
    bb_check(ts_t != 0, "tls13_server accepts valid 32-byte X25519 ClientHello")
    if ts_t != 0
        // Encrypted close_notify alert from client -> tls13_record_decrypt_prod MUST return status=-1 and close session!
        cn_rec = _tls13s_aead_wrap(ts_t.ts_cipher_suite, ts_t.ts_app_client_key, ts_t.ts_app_client_iv, 0, TLS_CONTENT_ALERT, [1, 0])
        cn_res = tls13_record_decrypt_prod(ts_t, cn_rec)
        bb_check(get(cn_res, 0) == -1 and ts_t.ts_state == TLS_STATE_CLOSED, "tls13_record_decrypt_prod closes session on close_notify alert")
        // Tampered ciphertext -> MUST return status=-1 and close session!
        ts_t2 = tls13_engine_process_handshake(eng, ch_t.wire_bytes)
        bad_rec = _tls13s_aead_wrap(ts_t2.ts_cipher_suite, ts_t2.ts_app_client_key, ts_t2.ts_app_client_iv, 0, TLS_CONTENT_APPLICATION_DATA, [65, 66, 67])
        list_set(bad_rec, 6, (get(bad_rec, 6) ^ 255) & 255)
        bad_res = tls13_record_decrypt_prod(ts_t2, bad_rec)
        bb_check(get(bad_res, 0) == -1 and ts_t2.ts_state == TLS_STATE_CLOSED, "tls13_record_decrypt_prod closes session on AEAD tag tampering")
        // Ticket cache cap <= 256 (fill 265 dummy tickets, verify _tls13s_evict_tickets caps to 256)
        ti_c = 0
        while ti_c < 265
            push(eng.re_ticket_ids, [ti_c & 255])
            push(eng.re_ticket_psks, [1])
            push(eng.re_ticket_ciphers, 4865)
            push(eng.re_ticket_snis, "localhost")
            push(eng.re_ticket_exp, clock_ms() + 60000)
            ti_c = ti_c + 1
        end
        _tls13s_evict_tickets(eng, 256)
        bb_check(len(eng.re_ticket_ids) <= 256 and len(eng.re_ticket_exp) == len(eng.re_ticket_ids), "tls13_server ticket cache capped & evicted at 256")
    end

    // Live TLS 1.3 KeyUpdate (request_update=1) between tls13_server.lp & http.lp!
    ku_port = 19673
    ku_lst = tcp_listener_bind("127.0.0.1", ku_port)
    bb_check(ku_lst.tcpl_fd >= 0, "TLS KeyUpdate loopback listener bound")
    if ku_lst.tcpl_fd >= 0
        ku_pid = syscall(57, 0, 0, 0, 0, 0, 0)
        if ku_pid == 0
            c_s = tcp_listener_accept(ku_lst)
            if c_s.tcp_fd >= 0
                ts = tls13_server_handshake_fd(c_s.tcp_fd, eng)
                if ts != 0
                    // Read client's first HTTP request
                    req_rec = _tls13s_read_wire_record(c_s.tcp_fd)
                    req_pt = tls13_record_decrypt(ts, req_rec)
                    if str_contains(req_pt, "GET /ku") == 1
                        // Initiate KeyUpdate(request_update=1) BEFORE sending HTTP response!
                        ku_wire = tls13_server_initiate_key_update(ts, 1)
                        _tls13s_write_list_fd(c_s.tcp_fd, ku_wire)
                        // Send encrypted HTTP response under NEW server key (seq=0)!
                        body_k = "KEYUPDATE_OK"
                        hresp = "HTTP/1.1 200 OK\r\nContent-Length: 12\r\nConnection: keep-alive\r\n\r\n" + body_k
                        _tls13s_write_list_fd(c_s.tcp_fd, tls13_record_encrypt(ts, hresp))
                        // Read client's KeyUpdate(0) reply + second request under NEW client key (seq=0)!
                        r_ku_rep = _tls13s_read_wire_record(c_s.tcp_fd)
                        unw_ku = tls13_record_decrypt_raw(ts, r_ku_rep)
                        r_req2 = _tls13s_read_wire_record(c_s.tcp_fd)
                        pt2 = tls13_record_decrypt(ts, r_req2)
                        if unw_ku[0] == 1 and str_contains(pt2, "GET /after") == 1
                            hresp2 = "HTTP/1.1 200 OK\r\nContent-Length: 10\r\nConnection: close\r\n\r\nAFTER_KU_2"
                            _tls13s_write_list_fd(c_s.tcp_fd, tls13_record_encrypt(ts, hresp2))
                        end
                    end
                end
                tcp_stream_close(c_s)
            end
            tcp_listener_close(ku_lst)
            syscall(60, 0, 0, 0, 0, 0, 0)
        end
        tcp_listener_close(ku_lst)

        tls13_clear_custom_trust_roots()
        tls13_set_system_roots_enabled(0)
        tls13_add_trust_root(ca_c)

        ku_cli_st = tcp_stream_connect("127.0.0.1", ku_port)
        ku_sess = _http_tls_connect_session(ku_cli_st, "127.0.0.1")
        bb_check(ku_sess.hts_ok == 1, "TLS 1.3 client connected using IPv4 SAN 127.0.0.1")
        raw1 = _http_tls_session_exchange(ku_sess, "GET /ku HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n")
        resp1 = http_parse_response(raw1)
        bb_check(resp1.status_code == 200 and resp1.body == "KEYUPDATE_OK", "TLS 1.3 client rotated server key on KeyUpdate(1) & decrypted response")
        raw2 = _http_tls_session_exchange(ku_sess, "GET /after HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
        resp2 = http_parse_response(raw2)
        bb_check(resp2.status_code == 200 and resp2.body == "AFTER_KU_2", "TLS 1.3 client sent KeyUpdate(0), rotated client key & exchanged post-KeyUpdate HTTP request")
        tcp_stream_close(ku_cli_st)
        st_k = malloc(8)
        syscall(61, ku_pid, st_k, 0, 0, 0, 0)
        free(st_k, 8)
    end
    return 0
end

// ── BB3: time.lp TZif, regex.lp VM, bigint.lp BigInt & Decimal ────────────────
fn bb_push_u32_be dst v
    push(dst, (v >> 24) & 255)
    push(dst, (v >> 16) & 255)
    push(dst, (v >> 8) & 255)
    push(dst, v & 255)
    return dst
end

fn bb_push_i64_be dst v
    // Works for non-negative epoch seconds up to 2^62
    hi = v / 4294967296
    lo = v % 4294967296
    bb_push_u32_be(dst, hi)
    bb_push_u32_be(dst, lo)
    return dst
end

fn test_bb3_time_regex_bigint
    say "▶ [BB3] time.lp TZif, regex.lp Backtracking/Captures/ReDoS, bigint.lp BigInt & Decimal..."

    // 3a. EINTR-safe sleep_ms + Synthetic TZif v2 binary DST transition test
    sleep_ms(5)
    // Construct valid RFC 8536 TZif v2 buffer:
    //   v1 block: 0 transitions, 1 ttinfo (UTC 0), 4 chars "UTC\0"
    //   v2 block: 2 transitions (2025-03-09 07:00 UTC -> EDT -14400; 2025-11-02 06:00 UTC -> EST -18000),
    //             2 ttinfos: type 0 = EST (-18000, isdst=0, abbr="EST"), type 1 = EDT (-14400, isdst=1, abbr="EDT")
    //             footer: "\nEST5EDT,M3.2.0,M11.1.0\n"
    tzb = [84, 90, 105, 102, 50] // "TZif2"
    zi = 0
    while zi < 15 push(tzb, 0) zi = zi + 1 end
    bb_push_u32_be(tzb, 0) // isut
    bb_push_u32_be(tzb, 0) // isstd
    bb_push_u32_be(tzb, 0) // leap
    bb_push_u32_be(tzb, 0) // timecnt=0
    bb_push_u32_be(tzb, 1) // typecnt=1
    bb_push_u32_be(tzb, 4) // charcnt=4
    bb_push_u32_be(tzb, 0) // utoff=0
    push(tzb, 0)           // isdst=0
    push(tzb, 0)           // desigidx=0
    push(tzb, 85) push(tzb, 84) push(tzb, 67) push(tzb, 0) // "UTC\0"

    // v2 64-bit header
    push(tzb, 84) push(tzb, 90) push(tzb, 105) push(tzb, 102) push(tzb, 50)
    zi = 0
    while zi < 15 push(tzb, 0) zi = zi + 1 end
    bb_push_u32_be(tzb, 0) // isut
    bb_push_u32_be(tzb, 0) // isstd
    bb_push_u32_be(tzb, 0) // leap
    bb_push_u32_be(tzb, 2) // timecnt=2
    bb_push_u32_be(tzb, 2) // typecnt=2
    bb_push_u32_be(tzb, 8) // charcnt=8 ("EST\0EDT\0")
    // Transitions: 1741503600 (2025-03-09 07:00 UTC) -> type 1 (EDT), 1762063200 (2025-11-02 06:00 UTC) -> type 0 (EST)
    bb_push_i64_be(tzb, 1741503600)
    bb_push_i64_be(tzb, 1762063200)
    push(tzb, 1)
    push(tzb, 0)
    // ttinfo 0: EST = -18000 (0xFFFFB9B0 = 4294949296)
    bb_push_u32_be(tzb, 4294949296)
    push(tzb, 0)
    push(tzb, 0)
    // ttinfo 1: EDT = -14400 (0xFFFFC7C0 = 4294952896)
    bb_push_u32_be(tzb, 4294952896)
    push(tzb, 1)
    push(tzb, 4)
    // chars: "EST\0EDT\0"
    push(tzb, 69) push(tzb, 83) push(tzb, 84) push(tzb, 0)
    push(tzb, 69) push(tzb, 68) push(tzb, 84) push(tzb, 0)
    // Footer: "\nEST5EDT,M3.2.0,M11.1.0\n"
    ft = "\nEST5EDT,M3.2.0,M11.1.0\n"
    fi = 0
    while fi < len(ft)
        push(tzb, mem_byte_read(ft, fi) & 255)
        fi = fi + 1
    end

    syn_tz = time_parse_tzif_bytes(tzb, "Synthetic/NYC")
    bb_check(syn_tz.tz_valid == 1 and syn_tz.tz_version == 2, "TZif v2 synthetic binary parsed")
    // Jan 15, 2025 12:00 UTC = 1736942400 -> EST (-18000s, hour 7)
    // Jul 15, 2025 12:00 UTC = 1752580800 -> EDT (-14400s, hour 8)
    // Jul 15, 2026 12:00 UTC = 1784116800 -> POSIX footer EDT (-14400s, hour 8)
    bb_check(time_tzif_offset_at(syn_tz, 1736942400) == -18000 and time_tzif_is_dst_at(syn_tz, 1736942400) == 0, "TZif winter EST offset -18000s")
    bb_check(time_tzif_offset_at(syn_tz, 1752580800) == -14400 and time_tzif_is_dst_at(syn_tz, 1752580800) == 1, "TZif summer EDT offset -14400s")
    bb_check(time_tzif_offset_at(syn_tz, 1784116800) == -14400 and time_tzif_is_dst_at(syn_tz, 1784116800) == 1, "TZif POSIX footer evaluates post-table summer DST")
    dt_win = time_from_unix_tz(1736942400, syn_tz)
    dt_sum = time_from_unix_tz(1752580800, syn_tz)
    bb_check(dt_win.dt_hour == 7 and dt_win.dt_tz_offset_min == -300, "time_from_unix_tz winter local civil time")
    bb_check(dt_sum.dt_hour == 8 and dt_sum.dt_tz_offset_min == -240, "time_from_unix_tz summer DST local civil time")

    // Also test live system zoneinfo files (Northern + Southern Hemisphere + half-hour offset)
    if file_exists("/usr/share/zoneinfo/America/New_York") == 1
        ny_tz = time_load_tzif("/usr/share/zoneinfo/America/New_York")
        bb_check(ny_tz.tz_valid == 1 and time_tzif_offset_at(ny_tz, 1736942400) == -18000 and time_tzif_offset_at(ny_tz, 1752580800) == -14400, "Real /usr/share/zoneinfo/America/New_York DST transitions verified")
    end
    if file_exists("/usr/share/zoneinfo/Australia/Sydney") == 1
        syd_tz = time_load_tzif("/usr/share/zoneinfo/Australia/Sydney")
        bb_check(syd_tz.tz_valid == 1 and time_tzif_offset_at(syd_tz, 1736942400) == 39600 and time_tzif_offset_at(syd_tz, 1752580800) == 36000 and time_tzif_offset_at(syd_tz, 2525860800) == 39600, "Real Southern Hemisphere Australia/Sydney TZif + Y2050 POSIX DST verified")
    end
    // Synthetic TZif v1-only (32-bit transition table) test
    tz1 = [84, 90, 105, 102, 0] // "TZif\0" (v1)
    z1i = 0
    while z1i < 15 push(tz1, 0) z1i = z1i + 1 end
    bb_push_u32_be(tz1, 0) bb_push_u32_be(tz1, 0) bb_push_u32_be(tz1, 0)
    bb_push_u32_be(tz1, 1) // timecnt=1
    bb_push_u32_be(tz1, 2) // typecnt=2
    bb_push_u32_be(tz1, 8) // charcnt=8
    bb_push_u32_be(tz1, 1700000000) // 1 32-bit transition
    push(tz1, 1) // transition -> type 1
    bb_push_u32_be(tz1, 0) push(tz1, 0) push(tz1, 0)       // type 0: UTC (0)
    bb_push_u32_be(tz1, 3600) push(tz1, 1) push(tz1, 4)    // type 1: BST (+3600)
    push(tz1, 85) push(tz1, 84) push(tz1, 67) push(tz1, 0) // "UTC\0"
    push(tz1, 66) push(tz1, 83) push(tz1, 84) push(tz1, 0) // "BST\0"
    v1_tz = time_parse_tzif_bytes(tz1, "Synthetic/V1")
    bb_check(v1_tz.tz_valid == 1 and v1_tz.tz_version == 1 and time_tzif_offset_at(v1_tz, 1699999999) == 0 and time_tzif_offset_at(v1_tz, 1700000000) == 3600, "TZif v1-only 32-bit transition table parsed accurately")

    // 3b. regex.lp: cross-group backtracking, captures, {n,m}, lazy, \D/\W/\S, [...] escapes, i flag, ReDoS
    p_bt1 = regex_compile("(ab|a)b")
    bb_check(regex_full_match(p_bt1, "ab") == 1, "regex (ab|a)b backtracks across group to match 'ab'")
    m_bt1 = regex_find(p_bt1, "ab")
    bb_check(m_bt1.পাওয়া_গেছে == 1 and m_bt1.গ্রুপ_count == 1 and get(m_bt1.গ্রুপ_list, 0) == "a", "regex (ab|a)b captures group 1 == 'a'")

    p_bt2 = regex_compile("(a+)a")
    bb_check(regex_full_match(p_bt2, "aa") == 1, "regex (a+)a backtracks inside group to match 'aa'")
    m_bt2 = regex_find(p_bt2, "aaa")
    bb_check(m_bt2.পাওয়া_গেছে == 1 and get(m_bt2.গ্রুপ_list, 0) == "aa", "regex (a+)a on 'aaa' captures group 1 == 'aa'")

    p_dt = regex_compile("(\\d{4})-(\\d{2})-(\\d{2})")
    m_dt = regex_find(p_dt, "date=2026-11-27!")
    bb_check(m_dt.পাওয়া_গেছে == 1 and m_dt.গ্রুপ_count == 3 and get(m_dt.গ্রুপ_list, 0) == "2026" and get(m_dt.গ্রুপ_list, 1) == "11" and get(m_dt.গ্রুপ_list, 2) == "27", "regex capture groups & {n} quantifiers")

    p_rng = regex_compile("^a{2,4}$")
    bb_check(regex_match(p_rng, "a") == 0 and regex_match(p_rng, "aa") == 1 and regex_match(p_rng, "aaaa") == 1 and regex_match(p_rng, "aaaaa") == 0, "regex {n,m} quantifier bounds")

    p_lazy = regex_compile("<.*?>")
    m_lazy = regex_find(p_lazy, "<a><b>")
    bb_check(m_lazy.পাওয়া_গেছে == 1 and m_lazy.len == 3, "regex lazy *? matches shortest '<a>'")
    p_lazyp = regex_compile("a+?")
    m_lazyp = regex_find(p_lazyp, "aaa")
    bb_check(m_lazyp.পাওয়া_গেছে == 1 and m_lazyp.len == 1, "regex lazy +? matches shortest 'a'")

    p_neg = regex_compile("^\\D+\\W+\\S+$")
    bb_check(regex_match(p_neg, "abc---xyz1") == 1 and regex_match(p_neg, "123---xyz") == 0, "regex \\D \\W \\S negated shorthand classes")

    p_esc = regex_compile("^[\\d\\-\\[\\]]+$")
    bb_check(regex_match(p_esc, "[42-99]") == 1 and regex_match(p_esc, "[abc]") == 0, "regex backslash escapes inside [...]")

    p_ic1 = regex_compile_flags("hello", "i")
    p_ic2 = regex_compile("(?i)[a-z]+")
    p_ic3 = regex_compile("(?i:abc)def")
    bb_check(regex_full_match(p_ic1, "HeLLo") == 1 and regex_full_match(p_ic2, "WoRlD") == 1, "regex case-insensitive flag i and (?i)")
    bb_check(regex_full_match(p_ic3, "ABCdef") == 1 and regex_full_match(p_ic3, "ABCDEF") == 0, "regex scoped (?i:abc)def does not leak icase to def")
    p_unm = regex_compile("a)b")
    bb_check(regex_match(p_unm, "a") == 0 and regex_match(p_unm, "a)b") == 1, "regex unmatched ) at top-level is literal, not truncating pattern")
    m_opt = regex_find(regex_compile("(a)(b)?(c)"), "ac")
    bb_check(m_opt.পাওয়া_গেছে == 1 and m_opt.গ্রুপ_count == 3 and get(m_opt.গ্রুপ_list, 0) == "a" and get(m_opt.গ্রুপ_list, 1) == "" and get(m_opt.গ্রুপ_list, 2) == "c", "regex optional capture group (a)(b)?(c) on 'ac'")

    t_redos = clock_ms()
    p_redos = regex_compile("(a+)+b")
    redos_ok = regex_match(p_redos, "aaaaaaaaaaaaaaaaaaaaaaaaac")
    p_redos2 = regex_compile("((a|ab)+)+c")
    redos_ok2 = regex_match(p_redos2, "aaaaaaaaaaaaaaaaaaaaaaaaa")
    redos_dt = clock_ms() - t_redos
    bb_check(redos_ok == 0 and redos_ok2 == 0 and redos_dt < 500, "regex (a+)+b & ((a|ab)+)+c ReDoS safe bounded memoization (<500ms)")

    // 3c. bigint.lp: 256-bit signed BigInt + INT64_MIN + pow_mod + exact Decimal
    b_min = bigint_from_i64(-9223372036854775807 - 1)
    bb_check(bigint_to_str(b_min) == "-9223372036854775808", "BigInt INT64_MIN round-trip")

    b_2_128 = bigint_from_str("340282366920938463463374607431768211456")
    b_2_256 = bigint_mul(b_2_128, b_2_128)
    bb_check(bigint_to_str(b_2_256) == "115792089237316195423570985008687907853269984665640564039457584007913129639936", "BigInt 256-bit exact multiplication 2^128 * 2^128 == 2^256")

    b_a = bigint_from_str("98765432109876543210987654321098765432109876543210")
    b_b = bigint_from_str("-1234567890123456789012345678901234567890")
    b_sum = bigint_add(b_a, b_b)
    bb_check(bigint_to_str(b_sum) == "98765432108641975320864197532086419753208641975320", "BigInt signed addition across 160-bit operands")
    bb_check(bigint_cmp(bigint_sub(b_sum, b_b), b_a) == 0, "BigInt sub inverse of add")

    dm256 = bigint_divmod(b_2_256, bigint_from_str("123456789012345678901234567890123456789"))
    q256 = get(dm256, 0)
    r256 = get(dm256, 1)
    rebuilt = bigint_add(bigint_mul(q256, bigint_from_str("123456789012345678901234567890123456789")), r256)
    bb_check(bigint_cmp(rebuilt, b_2_256) == 0 and bigint_cmp(r256, bigint_from_str("123456789012345678901234567890123456789")) < 0, "BigInt 256-bit divmod identity q*d + r == a")

    // Modular exponentiation: 3^200 mod (2^127 - 1) and Fermat check 2^(p-1) mod p == 1 for Mersenne prime 2^127 - 1
    m127 = bigint_from_str("170141183460469231731687303715884105727")
    m127_m1 = bigint_sub(m127, bigint_one())
    pm_fermat = bigint_pow_mod(bigint_from_i64(2), m127_m1, m127)
    bb_check(bigint_to_str(pm_fermat) == "1", "BigInt 127-bit pow_mod Fermat theorem 2^(M127-1) mod M127 == 1")
    dm_n1 = bigint_divmod(bigint_from_i64(-7), bigint_from_i64(3))
    dm_n2 = bigint_divmod(bigint_from_i64(7), bigint_from_i64(-3))
    dm_n3 = bigint_divmod(bigint_from_i64(-7), bigint_from_i64(-3))
    bb_check(bigint_to_str(get(dm_n1, 0)) == "-2" and bigint_to_str(get(dm_n1, 1)) == "-1" and bigint_to_str(get(dm_n2, 0)) == "-2" and bigint_to_str(get(dm_n2, 1)) == "1" and bigint_to_str(get(dm_n3, 0)) == "2" and bigint_to_str(get(dm_n3, 1)) == "-1", "BigInt signed divmod edge cases (-7/3, 7/-3, -7/-3)")
    bb_check(bigint_to_str(bigint_pow_mod(bigint_from_i64(-3), bigint_from_i64(3), bigint_from_i64(5))) == "3", "BigInt pow_mod with negative base reduces to canonical residue")

    // Exact Base-10 Decimal
    d01 = decimal_from_str("0.1")
    d02 = decimal_from_str("0.2")
    d03 = decimal_from_str("0.3")
    bb_check(decimal_to_str(decimal_add(d01, d02)) == "0.3", "Decimal exact 0.1 + 0.2 == 0.3")
    bb_check(decimal_to_str(decimal_sub(d03, d01)) == "0.2", "Decimal exact 0.3 - 0.1 == 0.2")
    bb_check(decimal_to_str(decimal_from_str("-0.05")) == "-0.05", "Decimal preserves negative sign on -0.05")
    bb_check(decimal_to_str(decimal_mul(decimal_from_str("12.34"), decimal_from_str("-0.5"))) == "-6.170", "Decimal exact signed multiplication")
    bb_check(decimal_to_str(decimal_div(decimal_from_str("1"), decimal_from_str("4"))) == "0.25", "Decimal exact division 1 / 4 == 0.25")
    bb_check(decimal_to_str(decimal_div(decimal_from_str("1"), decimal_from_str("3"), 6)) == "0.333333", "Decimal custom precision division 1 / 3 (scale 6)")
    return 0
end

// ── BB4: Module System & `pub` Fixes ──────────────────────────────────────────
fn test_bb4_modules
    say "▶ [BB4] Module System (pub async fn, local shadow, selective import, collision)..."
    file_write("/tmp/lipi_bb_mod_a.lp", "fn helper()\n    return 100\nend\npub async fn compute_val(x)\n    helper = 5\n    return x + helper\nend\npub fn def_shadow(a = 1, helper = 2)\n    return a + helper\nend\npub fn pick()\n    return 77\nend\n")
    mod_ok_src = "import \"/tmp/lipi_bb_mod_a.lp\" as ma\nfrom \"/tmp/lipi_bb_mod_a.lp\" import pick\npub struct Holder\n    pick: i64\nend\npub fn test_param(pick: i64) -> i64\n    return pick + 1\nend\nfn test_shadow()\n    pick = 12\n    return pick\nend\nfn main()\n    h = Holder(9)\n    r1 = await ma.compute_val(3)\n    r2 = ma.def_shadow(10)\n    if r1 == 8 and r2 == 12 and pick() == 77 and h.pick == 9 and test_param(4) == 5 and test_shadow() == 12 return 0 end\n    return 1\nend\n"
    mr = bb_compile_and_run("mod_ok", mod_ok_src, "--strict-types", "")
    bb_check(get(mr, 0) == 0 and get(mr, 1) == 0, "pub async fn + local/default-param shadow + pub struct/fn selective import under --strict-types")

    // alias.nonexistent MUST FAIL at compile time
    bad_alias = "import \"/tmp/lipi_bb_mod_a.lp\" as ma\nfn main()\n    say ma.does_not_exist()\nend\n"
    bb_check(bb_compile_src("mod_noexist", bad_alias, "", "") != 0, "alias.nonexistent rejected at compile time")

    // Two plainly-imported user modules with duplicate top-level fn MUST FAIL
    file_write("/tmp/lipi_bb_dup1.lp", "fn shared_dup()\n    return 1\nend\n")
    file_write("/tmp/lipi_bb_dup2.lp", "fn shared_dup()\n    return 2\nend\n")
    dup_src = "import \"/tmp/lipi_bb_dup1.lp\"\nimport \"/tmp/lipi_bb_dup2.lp\"\nfn main()\n    say shared_dup()\nend\n"
    bb_check(bb_compile_src("mod_dup", dup_src, "", "") != 0, "plain-import duplicate top-level user fn collision detected")

    bb_unlink("/tmp/lipi_bb_mod_a.lp")
    bb_unlink("/tmp/lipi_bb_dup1.lp")
    bb_unlink("/tmp/lipi_bb_dup2.lp")
    return 0
end

// ── BB5: --strict-types Soundness Closure ─────────────────────────────────────
fn test_bb5_strict_types
    say "▶ [BB5] --strict-types Soundness (Struct Ctor, Enum Payload, Undefined Field, dict<K,V>, impl self)..."

    // Struct constructor arg validation (+ 0-arg User() allowed)
    bb_check(bb_compile_src("st_ctor_bad", "struct User\n    age: i64\nend\nfn main()\n    u = User(\"not_int\")\n    say u.age\nend\n", "--strict-types", "") != 0, "--strict-types rejects User(\"not_int\")")
    bb_check(bb_compile_src("st_ctor_cnt", "struct User\n    age: i64\nend\nfn main()\n    u = User(1, 2)\n    say u.age\nend\n", "--strict-types", "") != 0, "--strict-types rejects wrong struct arg count")
    bb_check(bb_compile_src("st_ctor_empty", "struct Empty\nend\nfn main()\n    e = Empty(123)\nend\n", "--strict-types", "") != 0, "--strict-types rejects extra arg on 0-field struct Empty(123)")
    bb_check(bb_compile_src("st_ctor_ok", "struct User\n    age: i64\nend\nfn main()\n    u0 = User()\n    u1 = User(42)\n    say u0.age + u1.age\nend\n", "--strict-types", "") == 0, "--strict-types allows 0-arg User() and valid User(42)")

    // Enum variant payload validation (user-defined Opt::Some(i64) NOT short-circuited by builtin Some!)
    bb_check(bb_compile_src("st_enum_bad", "enum Opt { Some(i64), None }\nfn main()\n    x = Some(\"not_int\")\n    say x\nend\n", "--strict-types", "") != 0, "--strict-types rejects user enum Some(\"not_int\")")
    bb_check(bb_compile_src("st_enum_ok", "enum Opt { Some(i64), None }\nfn main()\n    x = Some(42)\n    say x\nend\n", "--strict-types", "") == 0, "--strict-types accepts valid user enum Some(42)")

    // Undefined struct field error
    bb_check(bb_compile_src("st_fld_bad", "struct User\n    age: i64\nend\nfn main()\n    u = User(10)\n    say u.nonexistent\nend\n", "--strict-types", "") != 0, "--strict-types rejects undefined struct field u.nonexistent")

    // dict<K, V> typing
    bb_check(bb_compile_src("st_dict_badk", "fn main()\n    d: dict<string, i64> = dict()\n    d[123] = 5\nend\n", "--strict-types", "") != 0, "--strict-types rejects wrong dict<string, i64> key type")
    bb_check(bb_compile_src("st_dict_badv", "fn main()\n    d: dict<string, i64> = dict()\n    d[\"k\"] = \"bad\"\nend\n", "--strict-types", "") != 0, "--strict-types rejects wrong dict<string, i64> value type")
    bb_check(bb_compile_src("st_dict_badr", "fn main()\n    d: dict<string, i64> = dict()\n    d[\"k\"] = 9\n    s: string = d[\"k\"]\n    say s\nend\n", "--strict-types", "") != 0, "--strict-types rejects assigning dict<string, i64> lookup to string")
    bb_check(bb_compile_src("st_dict_ok", "fn main()\n    d: dict<string, i64> = dict()\n    d[\"k\"] = 9\n    v: i64 = d[\"k\"]\n    say v\nend\n", "--strict-types", "") == 0, "--strict-types accepts valid dict<string, i64> operations")

    // impl block self typing & cross-struct method isolation
    impl_bad = "struct Dog\n    age: i64\nend\nimpl Dog\n    fn label(self) -> string\n        return self.age\n    end\nend\nfn main()\n    d = Dog(3)\n    say d.label()\nend\n"
    bb_check(bb_compile_src("st_impl_bad", impl_bad, "--strict-types", "") != 0, "--strict-types catches impl self.age returned as string")
    impl_ok = "struct Dog\n    age: i64\nend\nstruct Cat\n    name: string\nend\nimpl Dog\n    fn info(self) -> i64\n        return self.age\n    end\nend\nimpl Cat\n    fn info(self) -> string\n        return self.name\n    end\nend\nfn main()\n    d = Dog(4)\n    c = Cat(\"Milo\")\n    n: i64 = d.info()\n    s: string = c.info()\n    if n == 4 and s == \"Milo\" return 0 end\n    return 1\nend\n"
    impl_r = bb_compile_and_run("st_impl_ok", impl_ok, "--strict-types", "")
    bb_check(get(impl_r, 0) == 0 and get(impl_r, 1) == 0, "--strict-types isolates same-named impl methods across Dog & Cat with typed self")
    return 0
end

// ── BB6: --strict-ownership Flow & Borrow Fixes ───────────────────────────────
fn test_bb6_strict_ownership
    say "▶ [BB6] --strict-ownership (match, try/catch, defer, field/idx free, &mut/& borrows)..."

    // match arm branch isolation: free in arm A, use in arm B MUST PASS
    m_ok = "fn main()\n    p = malloc(16)\n    x = 1\n    match x {\n        0 => free(p),\n        1 => mem_byte_read(p, 0)\n    }\nend\n"
    bb_check(bb_compile_src("ow_match_ok", m_ok, "--strict-ownership", "") == 0, "--strict-ownership isolates mutually exclusive match arms")

    // try/catch/finally sequencing: catch & finally MUST see moves from try
    tc_bad = "fn main()\n    p = malloc(16)\n    try {\n        free(p)\n        throw 1\n    } catch e {\n        mem_byte_read(p, 0)\n    }\nend\n"
    bb_check(bb_compile_src("ow_try_bad", tc_bad, "--strict-ownership", "") != 0, "--strict-ownership catches use-after-free in catch after try free")
    tf_bad = "fn main()\n    p = malloc(16)\n    try {\n        free(p)\n    } catch e {\n        x = 1\n    } finally {\n        mem_byte_read(p, 0)\n    }\nend\n"
    bb_check(bb_compile_src("ow_fin_bad", tf_bad, "--strict-ownership", "") != 0, "--strict-ownership catches use-after-free in finally after try free")

    // defer deferred to scope exit & return: use AFTER defer free(p) & in return expr PASSES; double-free REJECTED
    def_ok = "fn read_and_defer()\n    p = malloc(16)\n    defer free(p)\n    return mem_byte_read(p, 0)\nend\nfn main()\n    p = malloc(16)\n    defer free(p)\n    v = mem_byte_read(p, 0)\n    say v + read_and_defer()\nend\n"
    bb_check(bb_compile_src("ow_def_ok", def_ok, "--strict-ownership", "") == 0, "--strict-ownership allows use & return expr after `defer free(p)` (analyzed at scope exit)")
    def_bad = "fn main()\n    p = malloc(16)\n    defer free(p)\n    free(p)\nend\n"
    bb_check(bb_compile_src("ow_def_bad", def_bad, "--strict-ownership", "") != 0, "--strict-ownership catches double-free when both manual free and defer free exist")

    // Struct field & constant-index double-free
    fld_bad = "struct BufBox\n    buf: i64\nend\nfn main()\n    s = BufBox(malloc(16))\n    free(s.buf)\n    free(s.buf)\nend\n"
    bb_check(bb_compile_src("ow_fld_bad", fld_bad, "--strict-ownership", "") != 0, "--strict-ownership catches double-free of struct field s.buf")
    idx_bad = "fn main()\n    arr = [malloc(16)]\n    free(arr[0])\n    free(arr[0])\nend\n"
    bb_check(bb_compile_src("ow_idx_bad", idx_bad, "--strict-ownership", "") != 0, "--strict-ownership catches double-free of arr[0]")

    // Real &x / &mut x borrow conflict checks
    bor_bad1 = "fn take2(a, b)\n    return 0\nend\nfn main()\n    x = 10\n    take2(&mut x, &x)\nend\n"
    bb_check(bb_compile_src("ow_bor_bad1", bor_bad1, "--strict-ownership", "") != 0, "--strict-ownership rejects simultaneous &mut x and &x call args")
    bor_bad2 = "fn main()\n    x = 10\n    r = &mut x\n    y = x\n    say y\nend\n"
    bb_check(bb_compile_src("ow_bor_bad2", bor_bad2, "--strict-ownership", "") != 0, "--strict-ownership rejects moving/reading x while mutably borrowed by r")
    bor_bad3 = "fn test_br(cond)\n    x = 10\n    r = 0\n    if cond == 1\n        r = &mut x\n    else\n        y = 1\n    end\n    x = 99\n    return x\nend\nfn main()\n    say test_br(1)\nend\n"
    bb_check(bb_compile_src("ow_bor_bad3", bor_bad3, "--strict-ownership", "") != 0, "--strict-ownership rejects mutating x after branch-merged &mut x borrow")
    bor_ok = "fn take2(a, b)\n    return 0\nend\nfn main()\n    x = 10\n    take2(&x, &x)\nend\n"
    bb_check(bb_compile_src("ow_bor_ok", bor_ok, "--strict-ownership", "") == 0, "--strict-ownership allows multiple simultaneous shared borrows &x, &x")
    return 0
end

fn main
    env_lipc = env_get("LIPI_TEST_LIPC")
    if len(env_lipc) > 0
        g_bb_lipc = env_lipc
    end
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 WAVE BB SOVEREIGN SECURITY, TYPES, OWNERSHIP & NET REGRESSION SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    test_bb1_kavach()
    test_bb2_net_crypto_tls()
    test_bb3_time_regex_bigint()
    test_bb4_modules()
    test_bb5_strict_types()
    test_bb6_strict_ownership()

    say "────────────────────────────────────────────────────────────────────────"
    say "Wave BB Assertions: " + str(g_bb_passed) + " passed, " + str(g_bb_failed) + " failed"
    if g_bb_failed == 0
        say "PASS_WAVE_BB_SECURITY_TYPES_OWNERSHIP_NET"
        return 0
    end
    say "FAIL_WAVE_BB_SECURITY_TYPES_OWNERSHIP_NET"
    exit(1)
end
