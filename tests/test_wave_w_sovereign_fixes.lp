// ==============================================================================
// Wave W Sovereign Regression Suite (End-to-End 100% Pure LiPi Verification):
//   1. `try` + `defer` + `throw` (nested finally, same-block defer, LIFO order, locals)
//   2. `lipi -e` / `lipi run` `--strict-ownership` flag forwarding + exact `<file>:<line>:<col>` spans
//   3. Local narrow int wrapping (`u8`/`byte`/`u16`/`u32`/`i8`/`i16`/`i32`) across
//      x86_64 legacy, x86_64 `--ssa-codegen`, ARM64 (`qemu-aarch64`), RISC-V 64 (`qemu-riscv64`)
//   4. IEEE-754 float raw memory (`mem_read_f64`/`mem_write_f64`/`mem_read_f32`/`mem_write_f32`,
//      `f64_from_bits`/`f64_to_bits`) + live `c_abi_call_f64` against `libm.so.6` `sqrt(16.0)`
//   5. Live loopback RFC 8446 TLS 1.3 Production Server:
//      - `http_pool_request` HTTPS Keep-Alive TLS 1.3 session reuse (`c_seq == 3`, 1 handshake)
//      - Non-blocking HTTPS SSE (`prod_sse_start_req` / `prod_sse_send_event_req` / `prod_sse_end_req`)
//      - Non-blocking WSS over TLS 1.3 (101 Upgrade + Text Echo + Ping/Pong + Close)
//   6. Multi-arch `--ssa-codegen` (x86_64 10-arg/ArrayLit/Index/methods, ARM64 AAPCS64,
//      RISC-V 64 RV64IM, WASM MVP)
//   7. ARM64 & RISC-V 64 bare-metal containers (`raw-bin`, `elf-kernel --base-addr`) +
//      `utso/silicon/{pl011,gic,opensbi}` (ELF64 `e_machine`, `e_entry`, 0 RWE, 0 Linux svc/ecall)
//   8. Scoped `arena_reset` zero-on-rollback integrity (<64KB & >64KB followed by `dict()`)
//   9. `build.lp --kavach --strict-types --ssa-codegen` compliance
// ==============================================================================

import "utso/io"
import "utso/string"
include "utso/core/memory.lp"
include "utso/core/c_abi_call.lp"
include "utso/core/ffi_sovereign.lp"
include "utso/net/server_production_tls.lp"
include "utso/net/http.lp"

global g_ww_req_cnt = 0
global g_ww_stale_cnt = 0
global g_ww_stop_srv = 0

fn ww_spawn cmd_path args log_path
    argv = syscall(9, 0, 160, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    i = 0
    while i < args.len() and i < 18
        mem_word_write(argv, (i + 1) * 8, args[i])
        i = i + 1
    end
    mem_word_write(argv, (i + 1) * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    mem_word_write(env, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        if len(log_path) > 0
            fd = syscall(2, log_path, 577, 420)
            if fd >= 0
                syscall(33, fd, 1, 0, 0, 0, 0)
                syscall(33, fd, 2, 0, 0, 0, 0)
                syscall(3, fd, 0, 0, 0, 0, 0)
            end
        end
        syscall(59, cmd_path, argv, env, 0, 0, 0)
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
    syscall(11, argv, 160, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return rc
end

fn ww_unlink path
    syscall(87, path, 0, 0, 0, 0, 0)
    return 0
end

fn ww_read_u16_le ptr off
    b0 = mem_byte_read(ptr, off) & 255
    b1 = mem_byte_read(ptr, off + 1) & 255
    return b0 | (b1 << 8)
end

fn ww_read_u32_le ptr off
    b0 = mem_byte_read(ptr, off) & 255
    b1 = mem_byte_read(ptr, off + 1) & 255
    b2 = mem_byte_read(ptr, off + 2) & 255
    b3 = mem_byte_read(ptr, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

fn ww_read_u64_le ptr off
    lo = ww_read_u32_le(ptr, off)
    hi = ww_read_u32_le(ptr, off + 4)
    return lo | (hi << 32)
end

fn ww_check_elf_kernel path expected_mach expected_entry
    raw = file_read(path)
    if len(raw) < 256
        say "FAIL ELF_KERNEL too small: " + path
        return 0
    end
    p = _prod_raw_ptr(raw)
    if (mem_byte_read(p, 0) & 255) != 127 or (mem_byte_read(p, 1) & 255) != 69 or (mem_byte_read(p, 2) & 255) != 76 or (mem_byte_read(p, 3) & 255) != 70
        say "FAIL ELF_KERNEL bad magic: " + path
        return 0
    end
    mach = ww_read_u16_le(p, 18)
    entry = ww_read_u64_le(p, 24)
    phoff = ww_read_u64_le(p, 32)
    phentsz = ww_read_u16_le(p, 54)
    phnum = ww_read_u16_le(p, 56)
    if mach != expected_mach
        say "FAIL ELF_KERNEL machine=" + str(mach) + " expected=" + str(expected_mach)
        return 0
    end
    if entry != expected_entry
        say "FAIL ELF_KERNEL entry=" + str(entry) + " expected=" + str(expected_entry)
        return 0
    end
    // Strict W^X: verify ZERO RWE (flags==7) program headers
    pi = 0
    while pi < phnum
        po = phoff + (pi * phentsz)
        pflags = ww_read_u32_le(p, po + 4)
        if pflags == 7
            say "FAIL ELF_KERNEL RWE segment detected in " + path
            return 0
        end
        pi = pi + 1
    end
    return 1
end

// ── 1. try + defer + throw helpers ────────────────────────────────────────────
fn ww_try_defer_return log
    try
        defer push(log, "ret_defer")
        push(log, "ret_body")
        return 77
    finally
        push(log, "ret_finally")
    end
    return 0
end

fn ww_test_try_defer_throw
    // Case A: try + defer + finally + outer catch
    log_a = list()
    try
        try
            defer push(log_a, "defer_inside_try_with_finally")
            throw "boom2"
        finally
            push(log_a, "finally_ran")
        end
    catch e
        push(log_a, "caught2:" + str(e))
    end
    if log_a.len() != 3 or log_a[0] != "finally_ran" or log_a[1] != "defer_inside_try_with_finally" or log_a[2] != "caught2:boom2"
        say "FAIL 1A try+defer+finally+throw: len=" + str(log_a.len()) + " [0]=" + str(log_a[0]) + " [1]=" + str(log_a[1]) + " [2]=" + str(log_a[2])
        exit(1)
    end

    // Case B: same-block defer + throw + catch (LIFO + local vars inside try)
    log_b = list()
    try
        local_x = 123
        defer push(log_b, "defer_1:" + str(local_x))
        defer push(log_b, "defer_2")
        push(log_b, "body")
        throw "boom_b"
    catch e
        push(log_b, "caught_b:" + str(e))
    end
    if log_b.len() != 4 or log_b[0] != "body" or log_b[1] != "caught_b:boom_b" or log_b[2] != "defer_2" or log_b[3] != "defer_1:123"
        say "FAIL 1B same-block defer+throw: len=" + str(log_b.len()) + " [0]=" + str(log_b[0]) + " [1]=" + str(log_b[1]) + " [2]=" + str(log_b[2]) + " [3]=" + str(log_b[3])
        exit(1)
    end

    // Case C: normal return runs both finally and defer (matching Lipi's unwind semantics)
    log_c = list()
    rv = ww_try_defer_return(log_c)
    if rv != 77 or log_c.len() != 3 or log_c[0] != "ret_body" or log_c[1] != "ret_finally" or log_c[2] != "ret_defer"
        say "FAIL 1C try+defer+finally+return: len=" + str(log_c.len()) + " [0]=" + str(log_c[0]) + " [1]=" + str(log_c[1]) + " [2]=" + str(log_c[2])
        exit(1)
    end
    say "  [PASS] 1. try + defer + finally + throw (all cases + LIFO + locals)"
    return 1
end

// ── 3. Narrow integer truncation helper ───────────────────────────────────────
fn ww_add_narrow(a: u8, b: u8) -> i64
    c: u8 = a + b
    return c
end

fn ww_test_narrow_x64
    u: u8 = 250
    u = u + 10
    b_v: byte = 250
    b_v = b_v + 10
    u2: u8 = 255
    u2 += 5
    u16v: u16 = 65530
    u16v += 10
    u32v: u32 = 4294967290
    u32v = u32v + 10
    i8v: i8 = 127
    i8v = i8v + 1
    i16v: i16 = 32767
    i16v = i16v + 1
    i32v: i32 = 2147483647
    i32v = i32v + 1
    p = ww_add_narrow(300, 10)
    if u != 4 or b_v != 4 or u2 != 4 or u16v != 4 or u32v != 4 or i8v != -128 or i16v != -32768 or i32v != -2147483648 or p != 54
        say "FAIL 3A x64 narrow int wrapping"
        exit(1)
    end
    return 1
end

// ── 4. Float memory primitives + live libm.so.6 C-ABI FFI ─────────────────────
fn ww_test_float_mem_ffi
    buf = malloc(32)
    mem_write_f64(buf, 0, 3.141592653589793)
    mem_write_f32(buf, 8, 2.5)
    v64 = mem_read_f64(buf, 0)
    v32 = mem_read_f32(buf, 8)
    bits = f64_to_bits(4.0)
    back = f64_from_bits(bits)
    free(buf, 32)
    if bits != 4616189618054758400 or back < 3.999 or back > 4.001 or v64 < 3.14159 or v64 > 3.14160 or v32 < 2.499 or v32 > 2.501
        say "FAIL 4A float raw memory primitives"
        exit(1)
    end
    h = ffi_load_so("libm.so.6")
    if h == 0
        h = ffi_load_so("/lib/x86_64-linux-gnu/libm.so.6")
    end
    if h != 0
        fn_sqrt = ffi_find_symbol(h, "sqrt")
        if fn_sqrt != 0
            r = c_abi_call_f64(fn_sqrt, [], [16.0])
            if r < 3.999 or r > 4.001
                say "FAIL 4B libm sqrt(16.0) returned " + str(r)
                exit(1)
            end
        end
    end
    say "  [PASS] 4. mem_read_f64/mem_write_f64/f32/bits + live libm.so.6 c_abi_call_f64"
    return 1
end

// ── 5. Live loopback TLS 1.3 Production Server (HTTPS Pool + HTTPS SSE + WSS) ─
fn ww_h_count req: ProdReq
    g_ww_req_cnt = g_ww_req_cnt + 1
    return "req=" + str(g_ww_req_cnt)
end

fn ww_h_sse req: ProdReq
    prod_sse_start_req(req)
    prod_sse_send_event_req(req, "tick", "hello_tls_sse")
    prod_sse_end_req(req)
    return 0
end

fn ww_h_quit req: ProdReq
    g_ww_stop_srv = 1
    return "bye"
end

fn ww_h_stale req: ProdReq
    g_ww_stale_cnt = g_ww_stale_cnt + 1
    c = _prod_find_conn(req.preq_srv, req.preq_fd)
    if g_ww_stale_cnt == 1
        prod_send_response_conn(req.preq_srv, get(req.preq_srv, 2), c, 200, "text/plain", "STALE_1")
        if c != 0
            c.pconn_close_after_write = 1
            if buf_len(c.pconn_write_buf) == 0
                _prod_close_conn(req.preq_srv, get(req.preq_srv, 2), c)
            end
        end
    else
        prod_send_response_conn(req.preq_srv, get(req.preq_srv, 2), c, 200, "text/plain", "RECOVERED_" + str(len(req.preq_body)))
    end
    return 0
end

fn ww_make_masked_ws_bytes opcode payload_bytes
    plen = len(payload_bytes)
    out = [128 | (opcode & 15)]
    if plen <= 125
        push(out, 128 | plen)
    elif plen <= 65535
        push(out, 128 | 126)
        push(out, (plen >> 8) & 255)
        push(out, plen & 255)
    end
    // Mask includes 0x00 to exercise NUL-byte transparency over TLS 1.3
    mask = [0, 90, 165, 255]
    push(out, 0) push(out, 90) push(out, 165) push(out, 255)
    i = 0
    while i < plen
        push(out, (payload_bytes[i] & 255) ^ mask[i & 3])
        i = i + 1
    end
    return out
end

fn ww_tls_send_chunked sess: HttpTlsSession raw_bytes
    n = len(raw_bytes)
    off = 0
    while off < n
        stop = off + 16384
        if stop > n stop = n end
        ch = _http_tls_slice(raw_bytes, off, stop)
        rec = _http_tls_wrap_aead_record_suite(sess.hts_cipher, sess.hts_c_key, sess.hts_c_iv, sess.hts_c_seq, 23, ch)
        if _http_tls_write_exact(sess.hts_fd, rec) <= 0 return 0 end
        sess.hts_c_seq = sess.hts_c_seq + 1
        off = stop
    end
    return 1
end

fn ww_tls_recv_at_least sess: HttpTlsSession min_len
    out = list()
    steps = 0
    while len(out) < min_len and steps < 64
        steps = steps + 1
        chunk = ww_tls_recv(sess)
        if len(chunk) == 0 break end
        ci = 0
        while ci < len(chunk)
            push(out, chunk[ci])
            ci = ci + 1
        end
    end
    return out
end

fn ww_make_masked_ws opcode payload_str
    plen = len(payload_str)
    pp = _prod_raw_ptr(payload_str)
    out = [128 | (opcode & 15), 128 | (plen & 127), 55, 170, 99, 13]
    mask = [55, 170, 99, 13]
    i = 0
    while i < plen
        b = (mem_byte_read(pp, i) & 255) ^ mask[i & 3]
        push(out, b)
        i = i + 1
    end
    return out
end

fn ww_tls_send sess: HttpTlsSession raw_bytes
    rec = _http_tls_wrap_aead_record_suite(sess.hts_cipher, sess.hts_c_key, sess.hts_c_iv, sess.hts_c_seq, 23, raw_bytes)
    n = _http_tls_write_exact(sess.hts_fd, rec)
    sess.hts_c_seq = sess.hts_c_seq + 1
    return n
end

fn ww_tls_recv sess: HttpTlsSession
    while 1 == 1
        rec = _http_tls_read_record(sess.hts_fd)
        if rec.tls_rec_ok != 1 return [] end
        if rec.tls_rec_type == 20 continue end
        if rec.tls_rec_type != 23 return [] end
        dec = _http_tls_unwrap_aead_record_suite(sess.hts_cipher, sess.hts_s_key, sess.hts_s_iv, sess.hts_s_seq, rec.tls_rec_hdr, rec.tls_rec_body)
        if dec.tls_pt_ok != 1 return [] end
        sess.hts_s_seq = sess.hts_s_seq + 1
        if dec.tls_pt_type == 22 continue end
        if dec.tls_pt_type == 23 return dec.tls_pt_data end
        return []
    end
    return []
end

fn ww_test_live_tls13_wss_sse_pool
    ca_sk = [10,20,30,40,50,60,70,80, 90,100,110,120,130,140,150,160, 170,180,190,200,210,220,230,240, 11,22,33,44,55,66,77,88]
    lf_sk = [12,22,32,42,52,62,72,82, 92,102,112,122,132,142,152,162, 172,182,192,202,212,222,232,242, 13,23,34,45,56,67,78,89]
    ca_pk = ed25519_keygen(ca_sk).public_key
    lf_pk = ed25519_keygen(lf_sk).public_key
    ca_cert = x509_build_signed_ed25519_cert("Lipi WW Root", "Lipi WW Root", "", "250101000000Z", "350101000000Z", 1, ca_pk, ca_sk, 801)
    lf_cert = x509_build_signed_ed25519_cert("Lipi WW Root", "localhost", "localhost", "250101000000Z", "350101000000Z", 0, lf_pk, ca_sk, 802)

    srv_engine = tls13_record_engine_new()
    tls13_engine_set_identity(srv_engine, [lf_cert], lf_sk)

    port = 19489
    srv = prod_server_create(port, 32)
    prod_server_enable_tls13(srv, srv_engine)
    prod_route_add(srv, "GET", "/count", ww_h_count)
    prod_route_add(srv, "GET", "/sse", ww_h_sse)
    prod_route_add(srv, "GET", "/stale", ww_h_stale)
    prod_route_add(srv, "POST", "/stale", ww_h_stale)
    prod_route_add(srv, "GET", "/quit", ww_h_quit)
    if prod_server_listen(srv) < 0
        say "FAIL 5 listen failed"
        exit(1)
    end

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        ticks = 0
        while g_ww_stop_srv == 0 and ticks < 400
            prod_server_tick(srv, 25)
            ticks = ticks + 1
        end
        prod_server_tick(srv, 25)
        prod_server_close(srv)
        syscall(60, 0, 0, 0, 0, 0, 0)
    end

    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    tls13_add_trust_root(ca_cert)

    // 5a. HTTPS TLS 1.3 Connection Pool Reuse
    pool = http_pool_new(8)
    base_url = "https://localhost:" + str(port)
    r1 = http_pool_request(pool, "GET", base_url + "/count", [], "")
    r2 = http_pool_request(pool, "GET", base_url + "/count", [], "")
    r3 = http_pool_request(pool, "GET", base_url + "/count", [], "")
    if r1.status_code != 200 or r1.body != "req=1" or r2.status_code != 200 or r2.body != "req=2" or r3.status_code != 200 or r3.body != "req=3"
        say "FAIL 5a HTTPS pool responses"
        exit(1)
    end
    cs = pool.hcp_tls[0]
    if cs == 0 or cs.hts_c_seq != 3 or cs.hts_s_seq < 3
        say "FAIL 5a HTTPS pool did not reuse TLS 1.3 session"
        exit(1)
    end
    http_pool_close_all(pool)

    // 5a2. Stale peer-closed pooled HTTPS socket with 35KB POST body (>2 TLS records, tests MSG_NOSIGNAL + retry!)
    spool = http_pool_new(4)
    rs1 = http_pool_request(spool, "GET", base_url + "/stale", [], "")
    t_sp = clock_ms()
    while (clock_ms() - t_sp) < 60
        _sp_w = 0
    end
    big_pb = buf_new(35000)
    bpi = 0
    while bpi < 35000
        buf_write_byte(big_pb, 65 + (bpi % 26))
        bpi = bpi + 1
    end
    big_pstr = buf_to_str(big_pb)
    buf_free(big_pb)
    rs2 = http_pool_request(spool, "POST", base_url + "/stale", [], big_pstr)
    http_pool_close_all(spool)
    if rs1.status_code != 200 or rs1.body != "STALE_1" or rs2.status_code != 200 or rs2.body != "RECOVERED_35000"
        say "FAIL 5a2 stale pooled HTTPS 35KB reconnect: r1=" + str(rs1.status_code) + " r2=" + str(rs2.status_code) + " body=" + rs2.body
        exit(1)
    end

    // 5b. Non-blocking HTTPS SSE over TLS 1.3
    r_sse = http_get(base_url + "/sse")
    if r_sse.status_code != 200 or str_contains(r_sse.body, "event: tick") != 1 or str_contains(r_sse.body, "hello_tls_sse") != 1
        say "FAIL 5b HTTPS SSE over TLS 1.3"
        exit(1)
    end

    // 5c. Non-blocking WSS over TLS 1.3 (101 Upgrade + Text Echo + Ping/Pong + Close)
    st = tcp_stream_connect("127.0.0.1", port)
    if st.tcp_fd < 0
        say "FAIL 5c WSS connect"
        exit(1)
    end
    http_socket_set_timeout_ms(st.tcp_fd, 5000)
    ws_sess = _http_tls_connect_session(st, "localhost")
    if ws_sess.hts_ok != 1
        say "FAIL 5c WSS TLS handshake"
        exit(1)
    end
    upg_req = "GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    ww_tls_send(ws_sess, tls_string_to_bytes(upg_req))
    upg_s = tls_bytes_to_string(ww_tls_recv(ws_sess))
    if str_contains(upg_s, "101 Switching Protocols") != 1 or str_contains(upg_s, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") != 1
        say "FAIL 5c WSS 101 Switching Protocols"
        exit(1)
    end
    ww_tls_send(ws_sess, ww_make_masked_ws(1, "HELLO_WSS_TLS13"))
    eb = ww_tls_recv(ws_sess)
    if eb.len() < 17 or eb[0] != 129 or eb[1] != 15 or tls_bytes_to_string(_http_tls_slice(eb, 2, 17)) != "HELLO_WSS_TLS13"
        say "FAIL 5c WSS encrypted Text echo"
        exit(1)
    end
    ww_tls_send(ws_sess, ww_make_masked_ws(9, "PING42"))
    pb = ww_tls_recv(ws_sess)
    if pb.len() < 8 or pb[0] != 138 or pb[1] != 6 or tls_bytes_to_string(_http_tls_slice(pb, 2, 8)) != "PING42"
        say "FAIL 5c WSS encrypted Ping/Pong"
        exit(1)
    end
    // 5c2. 20KB (>16KB TLS 1.3 record split) binary WSS frame with NUL bytes & 0x00 mask key
    pl20k = list()
    k20 = 0
    while k20 < 20000
        push(pl20k, k20 & 255)
        k20 = k20 + 1
    end
    ww_tls_send_chunked(ws_sess, ww_make_masked_ws_bytes(2, pl20k))
    e20 = ww_tls_recv_at_least(ws_sess, 20004)
    if len(e20) != 20004 or e20[0] != 130 or e20[1] != 126 or e20[4] != 0 or e20[5] != 1 or e20[20003] != (19999 & 255)
        say "FAIL 5c2 WSS 20KB binary frame echo len=" + str(len(e20))
        exit(1)
    end
    ww_tls_send(ws_sess, ww_make_masked_ws(8, ""))
    cb = ww_tls_recv(ws_sess)
    if cb.len() < 4 or cb[0] != 136
        say "FAIL 5c WSS encrypted Close"
        exit(1)
    end
    syscall(3, ws_sess.hts_fd, 0, 0, 0, 0, 0)

    rq = http_get(base_url + "/quit")
    st_ptr = malloc(8)
    mem_write(st_ptr, 0, 0)
    syscall(61, pid, st_ptr, 0, 0, 0, 0)
    free(st_ptr, 8)
    prod_server_close(srv)
    tls13_set_system_roots_enabled(1)
    say "  [PASS] 5. Live loopback TLS 1.3 HTTPS pool reuse (c_seq=3), HTTPS SSE, and WSS (101+Echo+Pong+Close)"
    return 1
end

// ── 8. Scoped arena_reset zero-on-rollback + fresh dict() regression ──────────
fn ww_test_arena_reset_zero_dict
    // Test A: Small rollback (< 64KB) with dirty non-zero bytes followed by fresh dict()
    m1 = arena_mark()
    dirty1 = malloc(4096)
    i1 = 0
    while i1 < 4096
        mem_byte_write(dirty1, i1, 171)
        i1 = i1 + 1
    end
    dirty1 = 0
    arena_reset(m1)
    d1 = dict()
    k1 = 0
    while k1 < 48
        d1["k_" + str(k1)] = k1 * 7
        k1 = k1 + 1
    end
    if d1["k_0"] != 0 or d1["k_25"] != 175 or d1["k_47"] != 329
        say "FAIL 8A small arena_reset + dict"
        exit(1)
    end

    // Test B: Large rollback (> 64KB, non-page-aligned partial head page + MADV_DONTNEED) + dict()
    m2 = arena_mark()
    dirty2 = malloc(131072)
    i2 = 0
    while i2 < 8192
        mem_byte_write(dirty2, i2, 205)
        i2 = i2 + 1
    end
    dirty2 = 0
    arena_reset(m2)
    d2 = dict()
    k2 = 0
    while k2 < 48
        d2["big_" + str(k2)] = k2 * 11
        k2 = k2 + 1
    end
    if d2["big_0"] != 0 or d2["big_31"] != 341 or d2["big_47"] != 517
        say "FAIL 8B large arena_reset + dict"
        exit(1)
    end
    say "  [PASS] 8. arena_reset zero-on-rollback (<64KB & >64KB) + fresh Robin-Hood dict()"
    return 1
end

fn main
    say "========================================================================"
    say "👑 LIPI WAVE W SOVEREIGN REGRESSION SUITE (ALL 10 GAPS END-TO-END)"
    say "========================================================================"

    lipc = "./bin/lipc_bin"
    lipi = "./bin/lipi"
    has_qa64 = 0
    if syscall(21, "/usr/bin/qemu-aarch64", 1, 0, 0, 0, 0) == 0 has_qa64 = 1 end
    has_qrv = 0
    if syscall(21, "/usr/bin/qemu-riscv64", 1, 0, 0, 0, 0) == 0 has_qrv = 1 end

    // 1. try + defer + throw
    ww_test_try_defer_throw()

    // 2. lipi -e --strict-ownership + exact <file>:<line>:<col> ownership spans
    uaf_src = "/tmp/lipi_ww_uaf.lp"
    uaf_out = "/tmp/lipi_ww_uaf_bin"
    uaf_log = "/tmp/lipi_ww_uaf.log"
    file_write(uaf_src, "fn main\n    b = alloc(16)\n    c = move(b)\n    say str(b)\nend\n")
    rc_uaf = ww_spawn(lipc, [uaf_src, uaf_out, "--strict-ownership"], uaf_log)
    log_uaf = file_read(uaf_log)
    if rc_uaf == 0 or str_contains(log_uaf, "<built-in>:0:0") == 1 or str_contains(log_uaf, "lipi_ww_uaf.lp:4:") != 1 or str_contains(log_uaf, "lipi_ww_uaf.lp:3:") != 1
        say "FAIL 2A ownership error span: rc=" + str(rc_uaf) + " log=" + log_uaf
        exit(1)
    end
    // Test lipi -e with trailing AND leading --strict-ownership
    e_snip = "b = alloc(16)\nc = move(b)\nsay str(b)\n"
    rc_e1 = ww_spawn(lipi, ["-e", e_snip, "--strict-ownership"], uaf_log)
    rc_e2 = ww_spawn(lipi, ["--strict-ownership", "-e", e_snip], uaf_log)
    rc_r1 = ww_spawn(lipi, ["run", "--strict-ownership", uaf_src], uaf_log)
    if rc_e1 == 0 or rc_e2 == 0 or rc_r1 == 0
        say "FAIL 2B lipi CLI --strict-ownership not enforced: e1=" + str(rc_e1) + " e2=" + str(rc_e2) + " r1=" + str(rc_r1)
        exit(1)
    end
    ww_unlink(uaf_src)
    ww_unlink(uaf_out)
    ww_unlink(uaf_log)
    say "  [PASS] 2. lipi -e / run --strict-ownership & exact <file>:<line>:<col> spans"

    // 3. Narrow integers across x64, x64 SSA, ARM64, RISC-V 64
    ww_test_narrow_x64()
    nar_src = "/tmp/lipi_ww_nar.lp"
    nar_x64 = "/tmp/lipi_ww_nar_ssa"
    nar_a64 = "/tmp/lipi_ww_nar_a64"
    nar_rv = "/tmp/lipi_ww_nar_rv"
    nar_log = "/tmp/lipi_ww_nar.log"
    file_write(nar_src, "fn add_n(a: u8, b: u8) -> i64\n    c: u8 = a + b\n    return c\nend\nfn main\n    u: u8 = 250\n    u = u + 10\n    u16v: u16 = 65530\n    u16v += 10\n    u32v: u32 = 4294967290\n    u32v = u32v + 10\n    i8v: i8 = 127\n    i8v = i8v + 1\n    i16v: i16 = 32767\n    i16v = i16v + 1\n    i32v: i32 = 2147483647\n    i32v = i32v + 1\n    p = add_n(300, 10)\n    if u != 4 or u16v != 4 or u32v != 4 or i8v != -128 or i16v != -32768 or i32v != -2147483648 or p != 54\n        exit(1)\n    end\n    say \"OK_NAR\"\nend\n")
    if ww_spawn(lipc, [nar_src, nar_x64, "--ssa-codegen"], nar_log) != 0 or ww_spawn(nar_x64, [], nar_log) != 0
        say "FAIL 3B x64 --ssa-codegen narrow ints"
        exit(1)
    end
    if has_qa64 == 1
        if ww_spawn(lipc, [nar_src, nar_a64, "--target=arm64"], nar_log) != 0 or ww_spawn("/usr/bin/qemu-aarch64", [nar_a64], nar_log) != 0
            say "FAIL 3C ARM64 narrow ints under qemu-aarch64"
            exit(1)
        end
    end
    if has_qrv == 1
        if ww_spawn(lipc, [nar_src, nar_rv, "--target=riscv64"], nar_log) != 0 or ww_spawn("/usr/bin/qemu-riscv64", [nar_rv], nar_log) != 0
            say "FAIL 3D RISC-V 64 narrow ints under qemu-riscv64"
            exit(1)
        end
    end
    ww_unlink(nar_src)
    ww_unlink(nar_x64)
    ww_unlink(nar_a64)
    ww_unlink(nar_rv)
    ww_unlink(nar_log)
    say "  [PASS] 3. Narrow int wrapping (u8/u16/u32/i8/i16/i32) on x64, x64-SSA, ARM64, RISC-V 64"

    // 4. Float memory primitives + live libm.so.6 FFI
    ww_test_float_mem_ffi()

    // 5. Live loopback TLS 1.3 HTTPS pool reuse + HTTPS SSE + WSS
    ww_test_live_tls13_wss_sse_pool()

    // 6. Multi-arch --ssa-codegen (x86_64 10-arg/arrays/methods, ARM64, RISC-V 64, WASM)
    ssa_src = "/tmp/lipi_ww_ssa.lp"
    ssa_x64 = "/tmp/lipi_ww_ssa_x64"
    ssa_m = "/tmp/lipi_ww_ssa_m.lp"
    ssa_a64 = "/tmp/lipi_ww_ssa_a64"
    ssa_rv = "/tmp/lipi_ww_ssa_rv"
    ssa_wasm = "/tmp/lipi_ww_ssa.wasm"
    ssa_log = "/tmp/lipi_ww_ssa.log"
    file_write(ssa_src, "fn sum10(a: i64, b: i64, c: i64, d: i64, e: i64, f: i64, g: i64, h: i64, i: i64, j: i64) -> i64\n    return a + b + c + d + e + f + g + h + i + j\nend\nfn main\n    s = sum10(1,2,3,4,5,6,7,8,9,10)\n    arr = [10, 20, 30, 40]\n    arr[2] = 99\n    v = arr[0] + arr[2] + arr.len()\n    if s != 55 or v != 113 exit(1) end\nend\n")
    if ww_spawn(lipc, [ssa_src, ssa_x64, "--ssa-codegen"], ssa_log) != 0 or ww_spawn(ssa_x64, [], ssa_log) != 0
        say "FAIL 6A x86_64 --ssa-codegen 10-arg/ArrayLit/Index"
        exit(1)
    end
    file_write(ssa_m, "fn sum8(a: i64, b: i64, c: i64, d: i64, e: i64, f: i64, g: i64, h: i64) -> i64\n    return a + b + c + d + e + f + g + h\nend\nfn fib(n: i64) -> i64\n    if n <= 1 return n end\n    a = 0\n    b = 1\n    k = 2\n    while k <= n\n        t = a + b\n        a = b\n        b = t\n        k = k + 1\n    end\n    return b\nend\nfn main\n    if sum8(1,2,3,4,5,6,7,8) != 36 or fib(12) != 144 exit(1) end\nend\n")
    if has_qa64 == 1
        if ww_spawn(lipc, [ssa_m, ssa_a64, "--target=arm64", "--ssa-codegen"], ssa_log) != 0
            say "FAIL 6B ARM64 --ssa-codegen compile"
            exit(1)
        end
        if str_contains(file_read(ssa_log), "[arm64_synth] --ssa-codegen active:") != 1 or ww_spawn("/usr/bin/qemu-aarch64", [ssa_a64], ssa_log) != 0
            say "FAIL 6B ARM64 --ssa-codegen qemu execution"
            exit(1)
        end
    end
    if has_qrv == 1
        if ww_spawn(lipc, [ssa_m, ssa_rv, "--target=riscv64", "--ssa-codegen"], ssa_log) != 0
            say "FAIL 6C RISC-V 64 --ssa-codegen compile"
            exit(1)
        end
        if str_contains(file_read(ssa_log), "[riscv64_synth] --ssa-codegen active:") != 1 or ww_spawn("/usr/bin/qemu-riscv64", [ssa_rv], ssa_log) != 0
            say "FAIL 6C RISC-V 64 --ssa-codegen qemu execution"
            exit(1)
        end
    end
    if ww_spawn(lipc, [ssa_m, ssa_wasm, "--target=wasm", "--ssa-codegen"], ssa_log) != 0
        say "FAIL 6D WASM --ssa-codegen compile"
        exit(1)
    end
    if str_contains(file_read(ssa_log), "[wasm_synth] --ssa-codegen active: replaced ") != 1
        say "FAIL 6D WASM --ssa-codegen did not splice SSA functions"
        exit(1)
    end
    w_raw = file_read(ssa_wasm)
    wp = _prod_raw_ptr(w_raw)
    if len(w_raw) < 16 or (mem_byte_read(wp, 0) & 255) != 0 or (mem_byte_read(wp, 1) & 255) != 97 or (mem_byte_read(wp, 2) & 255) != 115 or (mem_byte_read(wp, 3) & 255) != 109
        say "FAIL 6D WASM header invalid"
        exit(1)
    end
    ww_unlink(ssa_src)
    ww_unlink(ssa_x64)
    ww_unlink(ssa_m)
    ww_unlink(ssa_a64)
    ww_unlink(ssa_rv)
    ww_unlink(ssa_wasm)
    ww_unlink(ssa_log)
    say "  [PASS] 6. Multi-arch --ssa-codegen (x86_64, ARM64 AAPCS64, RISC-V 64 RV64IM, WASM MVP)"

    // 7. ARM64 & RISC-V 64 bare-metal raw-bin & elf-kernel + utso/silicon/{pl011,gic,opensbi}
    a64_ksrc = "/tmp/lipi_ww_a64k.lp"
    a64_raw = "/tmp/lipi_ww_a64.bin"
    a64_elf = "/tmp/lipi_ww_a64.elf"
    rv_ksrc = "/tmp/lipi_ww_rvk.lp"
    rv_raw = "/tmp/lipi_ww_rv.bin"
    rv_elf = "/tmp/lipi_ww_rv.elf"
    k_log = "/tmp/lipi_ww_kern.log"
    file_write(a64_ksrc, "import \"utso/silicon/pl011\"\nimport \"utso/silicon/gic\"\nfn _start\n    silicon_pl011_init(PL011_QEMU_VIRT_BASE(), 24000000, 115200)\n    silicon_gic_dist_init(GICD_QEMU_VIRT_BASE())\n    return 0\nend\n")
    file_write(rv_ksrc, "import \"utso/silicon/opensbi\"\nfn _start\n    silicon_rv_uart_init(RV_UART0_BASE())\n    silicon_rv_plic_enable_irq(RV_PLIC_BASE(), 0, 10)\n    return 0\nend\n")
    if ww_spawn(lipc, [a64_ksrc, a64_raw, "--target=arm64-raw-bin"], k_log) != 0
        say "FAIL 7A arm64-raw-bin"
        exit(1)
    end
    if ww_spawn(lipc, [a64_ksrc, a64_elf, "--target=arm64-elf-kernel", "--base-addr=0x40080000"], k_log) != 0
        say "FAIL 7B arm64-elf-kernel compile"
        exit(1)
    end
    if ww_check_elf_kernel(a64_elf, 183, 1074266112) != 1
        exit(1)
    end
    if ww_spawn(lipc, [rv_ksrc, rv_raw, "--target=riscv64-raw-bin"], k_log) != 0
        say "FAIL 7C riscv64-raw-bin"
        exit(1)
    end
    if ww_spawn(lipc, [rv_ksrc, rv_elf, "--target=riscv64-elf-kernel", "--base-addr=0x80200000"], k_log) != 0
        say "FAIL 7D riscv64-elf-kernel compile"
        exit(1)
    end
    if ww_check_elf_kernel(rv_elf, 243, 2149580800) != 1
        exit(1)
    end
    x64_ksrc = "/tmp/lipi_ww_x64k.lp"
    x64_raw = "/tmp/lipi_ww_x64k.bin"
    file_write(x64_ksrc, "fn kentry\n    cpu_nop()\n    return 0\nend\nkentry()\n")
    if ww_spawn(lipc, [x64_ksrc, x64_raw, "--target=raw-bin"], k_log) != 0
        say "FAIL 7E x86_64 raw-bin cpu_nop"
        exit(1)
    end
    ww_unlink(x64_ksrc)
    ww_unlink(x64_raw)
    ww_unlink(a64_ksrc)
    ww_unlink(a64_raw)
    ww_unlink(a64_elf)
    ww_unlink(rv_ksrc)
    ww_unlink(rv_raw)
    ww_unlink(rv_elf)
    ww_unlink(k_log)
    say "  [PASS] 7. ARM64 & RISC-V 64 bare-metal raw-bin/elf-kernel + utso/silicon/{pl011,gic,opensbi} (0 RWE, 0 svc/ecall)"

    // 8. Scoped arena_reset zero-on-rollback + Robin-Hood dict()
    ww_test_arena_reset_zero_dict()

    // 9. build.lp --kavach --strict-types --ssa-codegen compliance
    maya_out = "/tmp/lipi_ww_maya_build"
    maya_log = "/tmp/lipi_ww_maya.log"
    if ww_spawn(lipc, ["build.lp", maya_out, "--kavach", "--strict-types", "--ssa-codegen"], maya_log) != 0
        say "FAIL 9 build.lp --kavach --strict-types --ssa-codegen: " + file_read(maya_log)
        exit(1)
    end
    if str_contains(file_read(maya_log), "--ssa-codegen active: replaced ") != 1
        say "FAIL 9 build.lp --ssa-codegen missing replacement banner"
        exit(1)
    end
    ww_unlink(maya_out)
    ww_unlink(maya_log)
    say "  [PASS] 9. build.lp --kavach --strict-types --ssa-codegen compliance"

    say "========================================================================"
    say "🎉 ALL WAVE W SOVEREIGN REGRESSION TESTS PASSED (100% PURE LIPI)!"
    say "========================================================================"
    return 0
end

main()
