// ==============================================================================
// LIPI PERMANENT REGRESSION TEST: WAVE 4 NET + TLS CA + SSE + DNS + EPOLL + WS
// Verifies:
//   1. DNS Tab/Space /etc/hosts (IPv4 & IPv6), TC=1 Detection, AAAA & CNAME Pointer Decoding
//   2. Portable Multi-Distro / SSL_CERT_FILE TLS 1.3 System Trust Store
//   3. Concurrent Multi-Connection Epoll Server (Exact 12B EPOLL_PACKED ABI):
//      - Dynamic Routing (POST /echo, PUT /item, DELETE /item, default /health)
//      - Chunked HTTP Request Body Decoding (Transfer-Encoding: chunked)
//      - Real-Time Incremental SSE Streaming (http_post_stream + mutable closure)
//      - Full-Duplex RFC 6455 WebSocket (Handshake, Ping->Pong, Fragmented Text,
//        Binary NUL-Safe Roundtrip, Close Handshake)
// ==============================================================================

include "utso/os/thread.lp"
include "utso/net/http.lp"
include "utso/net/server_production.lp"

fn w4_assert cond msg
    if cond == 0
        say "FAIL W4: " + msg
        syscall(231, 1, 0, 0, 0, 0, 0)
    end
    return 0

fn w4_handle_echo req: ProdReq
    prod_send_response(req.preq_fd, 200, "text/plain", "ECHO:" + req.preq_body)
    return 0

fn w4_handle_put req: ProdReq
    prod_send_response(req.preq_fd, 200, "text/plain", "PUT:" + req.preq_body)
    return 0

fn w4_handle_del req: ProdReq
    prod_send_response(req.preq_fd, 200, "text/plain", "DEL_OK")
    return 0

fn w4_handle_sse req: ProdReq
    prod_sse_start(req.preq_fd)
    prod_sse_send_chunk(req.preq_fd, "data: tok1\n\n")
    prod_sse_send_chunk(req.preq_fd, "data: tok2\n\n")
    prod_sse_send_chunk(req.preq_fd, "data: [DONE]\n\n")
    prod_sse_end(req.preq_fd)
    return 0

fn w4_handle_ws fd opcode payload plen
    if opcode == 1
        ws_send_text_frame(fd, "WS_ECHO:" + payload)
    elif opcode == 2
        ws_send_binary_frame(fd, payload, plen)
    end
    return 0

fn w4_server_loop ctrl
    srv = mem_word_read(ctrl, 0)
    while mem_word_read(ctrl, 8) == 0
        prod_server_tick(srv, 20)
    end
    return 0

fn w4_test_sse port
    sse_chunks = 0
    sse_acc = buf_new(256)
    r_sse = http_post_stream("http://127.0.0.1:" + str(port) + "/sse", [], "prompt=hi", |chunk| => {
        sse_chunks = sse_chunks + 1
        buf_write_str(sse_acc, chunk)
        0
    })
    sse_full = buf_to_str(sse_acc)
    buf_free(sse_acc)
    w4_assert(r_sse.status_code == 200 && sse_chunks >= 3, "SSE incremental chunks >= 3")
    w4_assert(str_eq(sse_full, "data: tok1\n\ndata: tok2\n\ndata: [DONE]\n\n") == 1, "SSE full payload")
    return sse_chunks

fn main
    // 1. DNS Client: tab/space /etc/hosts + AAAA + CNAME pointer compression + TC=1
    hosts_sample = "# comment\n127.0.0.1\tlocalhost\tmybox # inline\n::1\t\tip6host\n10.0.0.9   api.internal\n"
    w4_assert(str_eq(dns_lookup_hosts_text(hosts_sample, "mybox", 0), "127.0.0.1") == 1, "dns tab /etc/hosts v4")
    w4_assert(str_eq(dns_lookup_hosts_text(hosts_sample, "api.internal", 0), "10.0.0.9") == 1, "dns space /etc/hosts v4")
    w4_assert(str_eq(dns_lookup_hosts_text(hosts_sample, "ip6host", 1), "::1") == 1, "dns tab /etc/hosts v6")

    pkt_aaaa = alloc(128)
    mem_byte_write(pkt_aaaa, 0, 18)
    mem_byte_write(pkt_aaaa, 1, 52)
    mem_byte_write(pkt_aaaa, 2, 131) // QR=1 | TC=1 | RD=1
    mem_byte_write(pkt_aaaa, 3, 128)
    mem_byte_write(pkt_aaaa, 4, 0)
    mem_byte_write(pkt_aaaa, 5, 1)
    mem_byte_write(pkt_aaaa, 6, 0)
    mem_byte_write(pkt_aaaa, 7, 1)
    mem_byte_write(pkt_aaaa, 8, 0)
    mem_byte_write(pkt_aaaa, 9, 0)
    mem_byte_write(pkt_aaaa, 10, 0)
    mem_byte_write(pkt_aaaa, 11, 0)
    mem_byte_write(pkt_aaaa, 12, 1)
    mem_byte_write(pkt_aaaa, 13, 97)
    mem_byte_write(pkt_aaaa, 14, 3)
    mem_byte_write(pkt_aaaa, 15, 99)
    mem_byte_write(pkt_aaaa, 16, 111)
    mem_byte_write(pkt_aaaa, 17, 109)
    mem_byte_write(pkt_aaaa, 18, 0)
    mem_byte_write(pkt_aaaa, 19, 0)
    mem_byte_write(pkt_aaaa, 20, 28)
    mem_byte_write(pkt_aaaa, 21, 0)
    mem_byte_write(pkt_aaaa, 22, 1)
    mem_byte_write(pkt_aaaa, 23, 192)
    mem_byte_write(pkt_aaaa, 24, 12)
    mem_byte_write(pkt_aaaa, 25, 0)
    mem_byte_write(pkt_aaaa, 26, 28)
    mem_byte_write(pkt_aaaa, 27, 0)
    mem_byte_write(pkt_aaaa, 28, 1)
    mem_byte_write(pkt_aaaa, 29, 0)
    mem_byte_write(pkt_aaaa, 30, 0)
    mem_byte_write(pkt_aaaa, 31, 0)
    mem_byte_write(pkt_aaaa, 32, 60)
    mem_byte_write(pkt_aaaa, 33, 0)
    mem_byte_write(pkt_aaaa, 34, 16)
    mem_byte_write(pkt_aaaa, 35, 32)
    mem_byte_write(pkt_aaaa, 36, 1)
    mem_byte_write(pkt_aaaa, 37, 13)
    mem_byte_write(pkt_aaaa, 38, 184)
    zi = 39
    while zi < 50
        mem_byte_write(pkt_aaaa, zi, 0)
        zi = zi + 1
    end
    mem_byte_write(pkt_aaaa, 50, 1)
    w4_assert(dns_is_truncated(pkt_aaaa, 51) == 1, "dns TC=1")
    w4_assert(str_eq(dns_parse_aaaa_record_checked(pkt_aaaa, 51, 4660), "2001:db8:0:0:0:0:0:1") == 1, "dns AAAA")
    free(pkt_aaaa)

    pkt_cn = alloc(64)
    mem_byte_write(pkt_cn, 0, 0)
    mem_byte_write(pkt_cn, 1, 7)
    mem_byte_write(pkt_cn, 2, 129)
    mem_byte_write(pkt_cn, 3, 128)
    mem_byte_write(pkt_cn, 4, 0)
    mem_byte_write(pkt_cn, 5, 1)
    mem_byte_write(pkt_cn, 6, 0)
    mem_byte_write(pkt_cn, 7, 1)
    mem_byte_write(pkt_cn, 8, 0)
    mem_byte_write(pkt_cn, 9, 0)
    mem_byte_write(pkt_cn, 10, 0)
    mem_byte_write(pkt_cn, 11, 0)
    mem_byte_write(pkt_cn, 12, 1)
    mem_byte_write(pkt_cn, 13, 97)
    mem_byte_write(pkt_cn, 14, 3)
    mem_byte_write(pkt_cn, 15, 99)
    mem_byte_write(pkt_cn, 16, 111)
    mem_byte_write(pkt_cn, 17, 109)
    mem_byte_write(pkt_cn, 18, 0)
    mem_byte_write(pkt_cn, 19, 0)
    mem_byte_write(pkt_cn, 20, 1)
    mem_byte_write(pkt_cn, 21, 0)
    mem_byte_write(pkt_cn, 22, 1)
    mem_byte_write(pkt_cn, 23, 192)
    mem_byte_write(pkt_cn, 24, 12)
    mem_byte_write(pkt_cn, 25, 0)
    mem_byte_write(pkt_cn, 26, 5)
    mem_byte_write(pkt_cn, 27, 0)
    mem_byte_write(pkt_cn, 28, 1)
    mem_byte_write(pkt_cn, 29, 0)
    mem_byte_write(pkt_cn, 30, 0)
    mem_byte_write(pkt_cn, 31, 0)
    mem_byte_write(pkt_cn, 32, 60)
    mem_byte_write(pkt_cn, 33, 0)
    mem_byte_write(pkt_cn, 34, 4)
    mem_byte_write(pkt_cn, 35, 1)
    mem_byte_write(pkt_cn, 36, 98)
    mem_byte_write(pkt_cn, 37, 192)
    mem_byte_write(pkt_cn, 38, 14)
    w4_assert(str_eq(dns_parse_cname_target(pkt_cn, 39, 7), "b.com") == 1, "dns CNAME pointer")
    free(pkt_cn)

    // 2. Portable TLS CA store
    ca_store = _tls13_get_active_trust_store()
    w4_assert(ca_store.len() > 0, "portable TLS trust store")

    // 3. Live Concurrent Epoll Server
    port = 18943
    srv = prod_server_create(port, 64)
    prod_route_add(srv, "POST", "/echo", fn_ptr(w4_handle_echo))
    prod_route_add(srv, "PUT", "/item", fn_ptr(w4_handle_put))
    prod_route_add(srv, "DELETE", "/item", fn_ptr(w4_handle_del))
    prod_route_add(srv, "POST", "/sse", fn_ptr(w4_handle_sse))
    prod_ws_route_add(srv, "/ws", fn_ptr(w4_handle_ws))
    w4_assert(prod_server_listen(srv) == 0, "prod_server_listen")

    ctrl = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    mem_word_write(ctrl, 0, srv)
    mem_word_write(ctrl, 8, 0)
    srv_th = thread_spawn_joinable(fn_ptr(w4_server_loop), ctrl, 131072)
    w4_assert(srv_th != 0, "server thread spawned")

    r_h = http_get("http://127.0.0.1:" + str(port) + "/health")
    w4_assert(r_h.status_code == 200 && str_contains(r_h.body, "UP") == 1, "default /health")

    r_p = http_post("http://127.0.0.1:" + str(port) + "/echo", [], "PAYLOAD_42")
    w4_assert(r_p.status_code == 200 && str_eq(r_p.body, "ECHO:PAYLOAD_42") == 1, "POST /echo")

    r_put = http_put("http://127.0.0.1:" + str(port) + "/item", [], "UPDATED_V2")
    w4_assert(r_put.status_code == 200 && str_eq(r_put.body, "PUT:UPDATED_V2") == 1, "PUT /item")

    r_del = http_delete("http://127.0.0.1:" + str(port) + "/item", [])
    w4_assert(r_del.status_code == 200 && str_eq(r_del.body, "DEL_OK") == 1, "DELETE /item")

    // Chunked POST request
    chk_st = tcp_stream_connect("127.0.0.1", port)
    chk_req = "POST /echo HTTP/1.1\r\nHost: 127.0.0.1\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n8\r\nCHUNK_A+\r\n7\r\nCHUNK_B\r\n0\r\n\r\n"
    tcp_stream_write(chk_st, chk_req)
    chk_raw = tcp_stream_read(chk_st, 4096)
    tcp_stream_close(chk_st)
    chk_resp = http_parse_response(chk_raw)
    w4_assert(chk_resp.status_code == 200 && str_eq(chk_resp.body, "ECHO:CHUNK_A+CHUNK_B") == 1, "chunked POST")

    // Real-time SSE streaming
    sse_n = w4_test_sse(port)
    w4_assert(sse_n >= 3, "SSE chunk count")

    // Full-duplex RFC 6455 WebSocket
    ws_st = tcp_stream_connect("127.0.0.1", port)
    ws_up = "GET /ws HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
    tcp_stream_write(ws_st, ws_up)
    hs_resp = tcp_stream_read(ws_st, 1024)
    w4_assert(str_contains(hs_resp, "101 Switching Protocols") == 1 && str_contains(hs_resp, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == 1, "WS 101 handshake")

    ping_msg = "ping42"
    ping_fr = ws_encode_client_frame(9, ping_msg, 6, 1, 305419896)
    ws_write_all(ws_st.tcp_fd, buf_ptr(ping_fr), buf_len(ping_fr))
    buf_free(ping_fr)
    pong_raw = alloc(128)
    pn = syscall(0, ws_st.tcp_fd, pong_raw, 128, 0, 0, 0)
    pong_f = ws_parse_frame(pong_raw, pn, 0)
    w4_assert(pong_f.ws_ok == 1 && pong_f.ws_opcode == 10 && str_eq(pong_f.ws_payload, "ping42") == 1, "WS Ping->Pong")
    free(pong_raw)

    f1_s = "FRAG_"
    f2_s = "JOINED"
    fr1 = ws_encode_client_frame(1, f1_s, 5, 0, 111111)
    fr2 = ws_encode_client_frame(0, f2_s, 6, 1, 222222)
    ws_write_all(ws_st.tcp_fd, buf_ptr(fr1), buf_len(fr1))
    ws_write_all(ws_st.tcp_fd, buf_ptr(fr2), buf_len(fr2))
    buf_free(fr1)
    buf_free(fr2)
    txt_raw = alloc(128)
    tn = syscall(0, ws_st.tcp_fd, txt_raw, 128, 0, 0, 0)
    txt_f = ws_parse_frame(txt_raw, tn, 0)
    w4_assert(txt_f.ws_ok == 1 && txt_f.ws_opcode == 1 && str_eq(txt_f.ws_payload, "WS_ECHO:FRAG_JOINED") == 1, "WS fragmented text")
    free(txt_raw)

    bin_in = alloc(8)
    mem_byte_write(bin_in, 0, 65)
    mem_byte_write(bin_in, 1, 0)
    mem_byte_write(bin_in, 2, 66)
    mem_byte_write(bin_in, 3, 0)
    mem_byte_write(bin_in, 4, 67)
    bfr = ws_encode_client_frame(2, bin_in, 5, 1, 333333)
    ws_write_all(ws_st.tcp_fd, buf_ptr(bfr), buf_len(bfr))
    buf_free(bfr)
    free(bin_in)
    bin_raw = alloc(128)
    bn = syscall(0, ws_st.tcp_fd, bin_raw, 128, 0, 0, 0)
    bin_f = ws_parse_frame(bin_raw, bn, 0)
    bp = bin_f.ws_payload
    w4_assert(bin_f.ws_ok == 1 && bin_f.ws_opcode == 2 && bin_f.ws_payload_len == 5 && (mem_byte_read(bp, 1) & 255) == 0 && (mem_byte_read(bp, 4) & 255) == 67, "WS binary NUL-safe")
    free(bin_raw)

    cls_in = alloc(4)
    mem_byte_write(cls_in, 0, 3)
    mem_byte_write(cls_in, 1, 232)
    cfr = ws_encode_client_frame(8, cls_in, 2, 1, 444444)
    ws_write_all(ws_st.tcp_fd, buf_ptr(cfr), buf_len(cfr))
    buf_free(cfr)
    free(cls_in)
    cls_raw = alloc(64)
    cn = syscall(0, ws_st.tcp_fd, cls_raw, 64, 0, 0, 0)
    cls_f = ws_parse_frame(cls_raw, cn, 0)
    w4_assert(cls_f.ws_ok == 1 && cls_f.ws_opcode == 8, "WS close handshake")
    free(cls_raw)
    tcp_stream_close(ws_st)

    mem_word_write(ctrl, 8, 1)
    thread_join(srv_th)
    prod_server_close(srv)
    syscall(11, ctrl, 4096, 0, 0, 0, 0)

    say "PASS: test_wave4_net_sse_dns_epoll_ws (DNS+TLSCA+Epoll+Chunked+SSE+WS)"
    return 0
