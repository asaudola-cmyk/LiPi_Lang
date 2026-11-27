// ==============================================================================
// Wave Z Sovereign Standard Library & Networking Regression Suite:
//   Z1: `utso/core/time.lp` — Gregorian Civil DateTime, Pre-1970/Leap/Y2038+,
//       Timezone Offset Conversion, ISO-8601/RFC-3339, RFC-7231 HTTP-Date,
//       and `CLOCK_MONOTONIC` Timer
//   Z2: `utso/core/deflate.lp` — RFC 1951 DEFLATE, RFC 1950 ZLIB, RFC 1952 GZIP
//       (CRC-32, Adler-32, Multi-Member, FEXTRA/FNAME/FCOMMENT, Tamper Rejection,
//       HTTP/1.1 Auto-Decompression & Default `Accept-Encoding: gzip, deflate`)
//   Z3: Live Loopback HTTPS (HTTP/1.1 over TLS 1.3):
//       Conn 1 Full Handshake + `NewSessionTicket` Capture + GZIP Decompression
//       Conn 2 Automatic 1-RTT PSK Resumption (`psk_dhe_ke` + HMAC Binder) + DEFLATE
//   Z4: Live Loopback HTTP/2 over TLS 1.3 ALPN `"h2"`:
//       Conn 1 Full Handshake + `NewSessionTicket` Capture + GZIP Decompression
//       Conn 2 Automatic 1-RTT PSK Resumption + DEFLATE Decompression
// ==============================================================================

import "utso/core/time"
import "utso/core/deflate"
import "utso/net/http"
import "utso/net/http2/server"
import "utso/net/http2/client"

g_wz_stream_acc = ""
g_wz_mt_done = 0
g_wz_mt_err = 0

fn _wz_on_stream_chunk(chunk)
    g_wz_stream_acc = g_wz_stream_acc + chunk
    return 0
end

fn _wz_to_hex(v)
    if v == 0 return "0" end
    hx = "0123456789abcdef"
    out = ""
    n = v
    while n > 0
        out = str_sub(hx, n & 15, (n & 15) + 1) + out
        n = n >> 4
    end
    return out
end

fn _wz_mt_psk_worker(tid)
    i = 0
    while i < 1500
        kh = "wz-mt-host-" + str((tid + i) % 12)
        psk_b = [tid & 255, i & 255, 42, 99, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127]
        tkt_b = [1, 2, 3, 4, tid & 255, (i >> 8) & 255, i & 255, 8]
        tls13_cache_store_ticket(kh, "http/1.1", 4865, tkt_b, psk_b, 12345, 3600)
        got = tls13_cache_lookup_ticket(kh, "http/1.1")
        if got == 0
            atomic_add(g_wz_mt_err, 1)
        end
        i = i + 1
    end
    atomic_add(g_wz_mt_done, 1)
    return 0
end

fn _wz_listen_loopback()
    fd = syscall(41, 2, 1, 0, 0, 0, 0)
    if fd < 0 return [0 - 1, 0] end
    one = malloc(4)
    mem_write_u32(one, 0, 1)
    syscall(54, fd, 1, 2, one, 4, 0)
    free(one, 4)
    sa = malloc(16)
    i = 0
    while i < 16
        mem_write_byte(sa, i, 0)
        i = i + 1
    end
    mem_write_byte(sa, 0, 2)
    mem_write_byte(sa, 4, 127)
    mem_write_byte(sa, 7, 1)
    if syscall(49, fd, sa, 16, 0, 0, 0) < 0
        free(sa, 16)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return [0 - 1, 0]
    end
    if syscall(50, fd, 8, 0, 0, 0, 0) < 0
        free(sa, 16)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return [0 - 1, 0]
    end
    slen = malloc(4)
    mem_write_u32(slen, 0, 16)
    syscall(51, fd, sa, slen, 0, 0, 0)
    port = ((mem_read_byte(sa, 2) & 255) << 8) | (mem_read_byte(sa, 3) & 255)
    free(sa, 16)
    free(slen, 4)
    return [fd, port]
end

fn _wz_h2_build_enc_response(sid, enc_name, raw_body)
    hblk = [136]
    push(hblk, 15)
    push(hblk, 11)
    eb = tls_string_to_bytes(enc_name)
    push(hblk, len(eb) & 255)
    _h2_append(hblk, eb)
    f_hdr = http2_build_frame(H2_FRAME_HEADERS, H2_FLAG_END_HEADERS, sid, hblk)
    body_b = tls_string_to_bytes(raw_body)
    f_data = http2_build_frame(H2_FRAME_DATA, H2_FLAG_END_STREAM, sid, body_b)
    _h2_append(f_hdr, f_data)
    return f_hdr
end

fn _wz_serve_h2_conn(lfd, engine, expect_resumed, send_ticket, enc_name, comp_body)
    cfd = syscall(43, lfd, 0, 0, 0, 0, 0)
    if cfd < 0 return 1 end
    sess = tls13_server_handshake_fd(cfd, engine)
    if sess == 0
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return 2
    end
    if sess.ts_is_resumed != expect_resumed
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return 3
    end
    if send_ticket == 1
        nst = tls13_server_issue_session_ticket(engine, sess)
        if len(nst[2]) == 0
            syscall(3, cfd, 0, 0, 0, 0, 0)
            return 4
        end
        _tls13s_write_list_fd(cfd, nst[2])
    end

    rx_buf = list()
    pr = _h2_tls_pull_bytes(cfd, sess, rx_buf, 24)
    rx_buf = pr[2]
    if pr[0] != 1 or http2_check_preface(pr[1]) != 1
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return 5
    end
    _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(sess, http2_build_server_settings()))

    req_stream = 0
    saw_ae = 0
    done = 0
    frames = 0
    while done == 0 and frames < 32
        hr = _h2_tls_pull_bytes(cfd, sess, rx_buf, 9)
        rx_buf = hr[2]
        if hr[0] != 1 break end
        hdr = hr[1]
        flen = ((get(hdr, 0) & 255) << 16) | ((get(hdr, 1) & 255) << 8) | (get(hdr, 2) & 255)
        ftype = get(hdr, 3) & 255
        flags = get(hdr, 4) & 255
        sid = ((get(hdr, 5) & 127) << 24) | ((get(hdr, 6) & 255) << 16) | ((get(hdr, 7) & 255) << 8) | (get(hdr, 8) & 255)
        payload = list()
        if flen > 0
            plr = _h2_tls_pull_bytes(cfd, sess, rx_buf, flen)
            rx_buf = plr[2]
            if plr[0] != 1 break end
            payload = plr[1]
        end
        frames = frames + 1
        if ftype == H2_FRAME_SETTINGS
            if (flags & H2_FLAG_ACK) == 0
                _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(sess, http2_build_settings_ack()))
            end
        elif ftype == H2_FRAME_HEADERS
            hblk = _h2_extract_headers_payload(flags, payload)
            kv = http2_hpack_decode_headers(hblk)
            ae_v = _h2_find_header(kv[0], kv[1], "accept-encoding")
            if str_contains(ae_v, "gzip") == 1
                saw_ae = 1
            end
            req_stream = sid
            if (flags & H2_FLAG_END_STREAM) != 0
                done = 1
            end
        end
    end

    if req_stream <= 0 or saw_ae != 1
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return 6
    end
    resp = _wz_h2_build_enc_response(req_stream, enc_name, comp_body)
    _h2_append(resp, http2_build_goaway(req_stream, 0))
    _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(sess, resp))
    close_alert = _tls13s_aead_wrap(sess.ts_cipher_suite, sess.ts_app_server_key, sess.ts_app_server_iv, sess.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
    sess.ts_server_seq = sess.ts_server_seq + 1
    _tls13s_write_list_fd(cfd, close_alert)
    _h2_graceful_close(cfd)
    return 0
end

fn test_z1_calendar_and_monotonic_time()
    // Epoch 0
    dt0 = time_from_unix_utc(0)
    if dt0.dt_valid != 1 or time_format_iso8601(dt0) != "1970-01-01T00:00:00Z" or dt0.dt_weekday != 4
        say "FAIL Z1a: epoch 0 mismatch"
        return 1
    end
    // Pre-1970 (-1 -> 1969-12-31T23:59:59Z)
    dtm = time_from_unix_utc(0 - 1)
    if dtm.dt_valid != 1 or time_format_iso8601(dtm) != "1969-12-31T23:59:59Z" or time_to_unix(dtm) != (0 - 1)
        say "FAIL Z1b: pre-1970 mismatch"
        return 1
    end
    // Leap day + timezone conversion (+06:00 <-> UTC <-> -05:00) + fractional ns
    dt_iso = time_parse_iso8601("2024-02-29T18:30:45.123456789+06:00")
    if dt_iso.dt_valid != 1 or dt_iso.dt_year != 2024 or dt_iso.dt_month != 2 or dt_iso.dt_day != 29 or dt_iso.dt_nanosecond != 123456789 or dt_iso.dt_tz_offset_min != 360
        say "FAIL Z1c: ISO-8601 parse mismatch"
        return 1
    end
    dt_utc = time_convert_offset(dt_iso, 0)
    if time_format_civil(dt_utc) != "2024-02-29 12:30:45" or time_to_unix(dt_utc) != time_to_unix(dt_iso)
        say "FAIL Z1d: UTC conversion mismatch"
        return 1
    end
    dt_est = time_convert_offset(dt_iso, 0 - 300)
    if time_format_iso8601(dt_est) != "2024-02-29T07:30:45-05:00"
        say "FAIL Z1e: -05:00 conversion mismatch"
        return 1
    end
    // Invalid leap dates rejected
    if time_parse_iso8601("1900-02-29T00:00:00Z").dt_valid != 0 or time_parse_iso8601("2026-02-29T00:00:00Z").dt_valid != 0
        say "FAIL Z1f: invalid leap year date accepted"
        return 1
    end
    // RFC-7231 HTTP-Date (valid + invalid weekday name + wrong Gregorian weekday + bounds)
    dt_http = time_parse_http_date("Sun, 06 Nov 1994 08:49:37 GMT")
    if dt_http.dt_valid != 1 or time_to_unix(dt_http) != 784111777 or time_format_http_date(dt_http) != "Sun, 06 Nov 1994 08:49:37 GMT"
        say "FAIL Z1g: HTTP-date roundtrip mismatch"
        return 1
    end
    if time_parse_http_date("ZZZ, 06 Nov 1994 08:49:37 GMT").dt_valid != 0 or time_parse_http_date("Mon, 06 Nov 1994 08:49:37 GMT").dt_valid != 0
        say "FAIL Z1g2: invalid/mismatched HTTP-date weekday accepted"
        return 1
    end
    if time_datetime_new(2026, 1, 1, 0, 0, 0, 1000000000, 0).dt_valid != 0 or time_datetime_new(2026, 1, 1, 0, 0, 0, 0, 90000).dt_valid != 0
        say "FAIL Z1g3: out-of-range nanosecond/tz_offset accepted"
        return 1
    end
    // Y2038+ check (2050-06-15T12:00:00Z)
    dt_fut = time_parse_iso8601("2050-06-15T12:00:00Z")
    dt_fut2 = time_from_unix_utc(time_to_unix(dt_fut))
    if dt_fut.dt_valid != 1 or time_format_iso8601(dt_fut2) != "2050-06-15T12:00:00Z"
        say "FAIL Z1h: Y2038+ date roundtrip mismatch"
        return 1
    end
    // CLOCK_MONOTONIC timer
    t0 = monotonic_timer_start()
    sleep_ms(12)
    el_ms = monotonic_timer_elapsed_ms(t0)
    el_ns = monotonic_timer_elapsed_ns(t0)
    if el_ms < 8 or el_ns < 8000000
        say "FAIL Z1i: CLOCK_MONOTONIC elapsed too small: " + str(el_ms)
        return 1
    end
    say "  [PASS] Z1. utso/core/time.lp (Civil DateTime, TZ offsets, ISO-8601, HTTP-Date, CLOCK_MONOTONIC)"
    return 0
end

fn test_z2_deflate_zlib_gzip_and_http_parse()
    // CRC-32 & Adler-32 canonical KATs
    if deflate_crc32_str("123456789") != 3421780262
        say "FAIL Z2a: CRC-32 KAT mismatch"
        return 1
    end
    if deflate_adler32_str("Wikipedia") != 300286872
        say "FAIL Z2b: Adler-32 KAT mismatch"
        return 1
    end

    // Raw DEFLATE, ZLIB, GZIP roundtrips (empty + repetitive LZ77)
    s_rep = "Sovereign LiPi Pure Compression Engine! " + "REPEAT_BLOCK_1234567890_" + "REPEAT_BLOCK_1234567890_" + "REPEAT_BLOCK_1234567890_"
    if deflate_raw_decompress(deflate_raw_compress("")).dr_data != ""
        say "FAIL Z2c: empty raw deflate mismatch"
        return 1
    end
    if deflate_raw_decompress(deflate_raw_compress(s_rep)).dr_data != s_rep
        say "FAIL Z2d: raw deflate roundtrip mismatch"
        return 1
    end
    zl = zlib_compress(s_rep)
    if zlib_decompress(zl).dr_data != s_rep
        say "FAIL Z2e: zlib roundtrip mismatch"
        return 1
    end
    gz = gzip_compress(s_rep)
    if len(gz) >= len(s_rep)
        say "FAIL Z2f: gzip failed to compress repetitive payload"
        return 1
    end
    if gzip_decompress(gz).dr_data != s_rep
        say "FAIL Z2g: gzip roundtrip mismatch"
        return 1
    end
    // Multi-member GZIP concatenation
    gz_multi = gzip_compress("part1_") + gzip_compress("part2_sovereign")
    if gzip_decompress(gz_multi).dr_data != "part1_part2_sovereign"
        say "FAIL Z2h: multi-member gzip failed"
        return 1
    end
    // Tamper check (corrupt last byte of CRC/ISIZE)
    gz_bad = str_sub(gz, 0, len(gz) - 1) + "X"
    if gzip_decompress(gz_bad).dr_ok != 0
        say "FAIL Z2i: tampered gzip not rejected"
        return 1
    end

    // HTTP/1.1 auto-decompression (gzip, x-gzip, deflate zlib, deflate raw) & default Accept-Encoding
    raw_gz = "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: " + str(len(gz)) + "\r\n\r\n" + gz
    if http_parse_response(raw_gz).body != s_rep
        say "FAIL Z2j: http_parse_response gzip failed"
        return 1
    end
    raw_zl = "HTTP/1.1 200 OK\r\nContent-Encoding: deflate\r\nContent-Length: " + str(len(zl)) + "\r\n\r\n" + zl
    if http_parse_response(raw_zl).body != s_rep
        say "FAIL Z2k: http_parse_response zlib deflate failed"
        return 1
    end
    rw = deflate_raw_compress(s_rep)
    raw_rw = "HTTP/1.1 200 OK\r\nContent-Encoding: deflate\r\nContent-Length: " + str(len(rw)) + "\r\n\r\n" + rw
    if http_parse_response(raw_rw).body != s_rep
        say "FAIL Z2l: http_parse_response raw deflate failed"
        return 1
    end
    u = http_parse_url("https://localhost:8443/api")
    if _http_find_header_value(_http_build_client_headers(u, []), "accept-encoding") != "gzip, deflate"
        say "FAIL Z2m: missing default Accept-Encoding"
        return 1
    end
    if _http_find_header_value(_http_build_client_headers(u, [HttpHeader("Accept-Encoding", "identity")]), "accept-encoding") != "identity"
        say "FAIL Z2n: Accept-Encoding override ignored"
        return 1
    end

    // Binary payload with embedded 0x00 bytes + chained "gzip, deflate" + multi-header Content-Encoding
    bb = buf_new(16)
    buf_write_byte(bb, 65)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 66)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 67)
    buf_write_byte(bb, 255)
    bin_s = buf_to_str(bb)
    buf_free(bb)
    gz_bin = gzip_compress(bin_s)
    dec_bin = gzip_decompress(gz_bin)
    if dec_bin.dr_ok != 1 or len(dec_bin.dr_data) != 6 or (mem_byte_read(dec_bin.dr_data, 1) & 255) != 0 or (mem_byte_read(dec_bin.dr_data, 5) & 255) != 255
        say "FAIL Z2o: binary 0x00 gzip roundtrip failed"
        return 1
    end
    ch_body = zlib_compress(gzip_compress(s_rep))
    if deflate_decompress_http("gzip, deflate", ch_body).dr_data != s_rep
        say "FAIL Z2p: chained gzip, deflate failed"
        return 1
    end
    raw_multi = "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Encoding: deflate\r\nContent-Length: " + str(len(ch_body)) + "\r\n\r\n" + ch_body
    if http_parse_response(raw_multi).body != s_rep
        say "FAIL Z2q: multi-header Content-Encoding failed"
        return 1
    end
    // GZIP FHCRC verification (valid passes, tampered rejected)
    fhb = buf_new(len(gz) + 2)
    fi = 0
    while fi < 10
        bv = mem_byte_read(gz, fi) & 255
        if fi == 3 bv = bv | 2 end
        buf_write_byte(fhb, bv)
        fi = fi + 1
    end
    hcrc = deflate_crc32_bytes(buf_ptr(fhb), 0, 10) & 65535
    buf_write_byte(fhb, hcrc & 255)
    buf_write_byte(fhb, (hcrc >> 8) & 255)
    fi = 10
    while fi < len(gz)
        buf_write_byte(fhb, mem_byte_read(gz, fi) & 255)
        fi = fi + 1
    end
    gz_fhcrc_ok = buf_to_str(fhb)
    mem_byte_write(buf_ptr(fhb), 10, (hcrc & 255) ^ 1)
    gz_fhcrc_bad = buf_to_str(fhb)
    buf_free(fhb)
    if gzip_decompress(gz_fhcrc_ok).dr_ok != 1 or gzip_decompress(gz_fhcrc_ok).dr_data != s_rep or gzip_decompress(gz_fhcrc_bad).dr_ok != 0
        say "FAIL Z2r: GZIP FHCRC check failed"
        return 1
    end
    // ZLIB FDICT rejection
    zb = buf_new(len(zl))
    zi = 0
    while zi < len(zl)
        buf_write_byte(zb, mem_byte_read(zl, zi) & 255)
        zi = zi + 1
    end
    cmf = mem_byte_read(buf_ptr(zb), 0) & 255
    flg = ((mem_byte_read(buf_ptr(zb), 1) & 255) | 32) & 224
    rem31 = ((cmf << 8) | flg) % 31
    if rem31 != 0 flg = flg + (31 - rem31) end
    mem_byte_write(buf_ptr(zb), 1, flg)
    zl_fdict = buf_to_str(zb)
    buf_free(zb)
    if zlib_decompress(zl_fdict).dr_ok != 0
        say "FAIL Z2s: ZLIB FDICT was not rejected"
        return 1
    end
    // Binary-safe chunked framing check (with 0x00 bytes, chunk extension, and trailer)
    chk_b = buf_new(128)
    chk_s = _wz_to_hex(len(gz_bin)) + ";ext=1\r\n" + gz_bin + "\r\n0;last=yes\r\nX-Trailer: ok\r\n\r\n"
    buf_write_mem(chk_b, chk_s, len(chk_s))
    if _http_is_chunked_complete_bytes(buf_ptr(chk_b), 0, buf_len(chk_b)) != 1 or _http_is_chunked_complete_bytes(buf_ptr(chk_b), 0, buf_len(chk_b) - 2) != 0
        buf_free(chk_b)
        say "FAIL Z2t: binary-safe chunked framing check failed"
        return 1
    end
    buf_free(chk_b)
    say "  [PASS] Z2. utso/core/deflate.lp (FHCRC, FDICT, chained, binary 0x00, chunked) + HTTP/1.1 auto-decompression"
    return 0
end

fn test_z3_live_https_psk_and_compression()
    eng1 = tls13_record_engine_new()
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    ca1 = get(eng1.re_cert_chain, 0)
    if len(eng1.re_cert_chain) >= 2 ca1 = get(eng1.re_cert_chain, 1) end
    if tls13_add_trust_root(ca1) != 1 return 1 end
    tls13_cache_clear()

    b1 = "{\"conn\":1,\"mode\":\"full\",\"enc\":\"gzip\",\"payload\":\"Sovereign HTTPS TLS 1.3 GZIP verified!\"}"
    b2 = "{\"conn\":2,\"mode\":\"psk_resumed\",\"enc\":\"deflate\",\"payload\":\"Sovereign HTTPS TLS 1.3 1-RTT PSK DEFLATE verified!\"}"
    gz1 = gzip_compress(b1)
    zl2 = zlib_compress(b2)

    lp1 = _wz_listen_loopback()
    lfd1 = lp1[0]
    port1 = lp1[1]
    pid1 = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid1 == 0
        cfd1 = syscall(43, lfd1, 0, 0, 0, 0, 0)
        s1 = tls13_server_handshake_fd(cfd1, eng1)
        if s1 == 0 or s1.ts_is_resumed != 0 syscall(231, 11, 0, 0, 0, 0, 0) end
        nst1 = tls13_server_issue_session_ticket(eng1, s1)
        _tls13s_write_list_fd(cfd1, nst1[2])
        req1_pt = tls13_record_decrypt(s1, _tls13s_read_wire_record(cfd1))
        if str_contains(req1_pt, "Accept-Encoding: gzip, deflate") != 1 syscall(231, 12, 0, 0, 0, 0, 0) end
        r1 = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\nContent-Length: " + str(len(gz1)) + "\r\nConnection: close\r\n\r\n" + gz1
        _tls13s_write_list_fd(cfd1, tls13_record_encrypt(s1, r1))
        a1 = _tls13s_aead_wrap(s1.ts_cipher_suite, s1.ts_app_server_key, s1.ts_app_server_iv, s1.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
        s1.ts_server_seq = s1.ts_server_seq + 1
        _tls13s_write_list_fd(cfd1, a1)
        syscall(3, cfd1, 0, 0, 0, 0, 0)

        cfd2 = syscall(43, lfd1, 0, 0, 0, 0, 0)
        s2 = tls13_server_handshake_fd(cfd2, eng1)
        if s2 == 0 or s2.ts_is_resumed != 1 syscall(231, 13, 0, 0, 0, 0, 0) end
        req2_pt = tls13_record_decrypt(s2, _tls13s_read_wire_record(cfd2))
        if str_len(req2_pt) == 0 syscall(231, 14, 0, 0, 0, 0, 0) end
        r2 = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Encoding: deflate\r\nContent-Length: " + str(len(zl2)) + "\r\nConnection: close\r\n\r\n" + zl2
        _tls13s_write_list_fd(cfd2, tls13_record_encrypt(s2, r2))
        a2 = _tls13s_aead_wrap(s2.ts_cipher_suite, s2.ts_app_server_key, s2.ts_app_server_iv, s2.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
        s2.ts_server_seq = s2.ts_server_seq + 1
        _tls13s_write_list_fd(cfd2, a2)
        syscall(3, cfd2, 0, 0, 0, 0, 0)
        syscall(3, lfd1, 0, 0, 0, 0, 0)
        syscall(231, 0, 0, 0, 0, 0, 0)
    end
    syscall(3, lfd1, 0, 0, 0, 0, 0)

    hr1 = http_get("https://localhost:" + str(port1) + "/h1-gzip")
    if hr1.status_code != 200 or http_last_tls_was_resumed() != 0 or hr1.body != b1 or tls13_cache_count() < 1
        say "FAIL Z3a: HTTPS conn1 failed"
        return 1
    end
    hr2 = http_get("https://localhost:" + str(port1) + "/h1-deflate")
    st1 = malloc(8)
    syscall(61, pid1, st1, 0, 0, 0, 0)
    src1 = (mem_word_read(st1, 0) / 256) % 256
    free(st1, 8)
    if src1 != 0 or hr2.status_code != 200 or http_last_tls_was_resumed() != 1 or hr2.body != b2
        say "FAIL Z3b: HTTPS conn2 PSK resumption failed srv_rc=" + str(src1)
        return 1
    end
    say "  [PASS] Z3. Live HTTPS TLS 1.3 NewSessionTicket + 1-RTT PSK resumption + gzip/deflate"
    return 0
end

fn test_z4_live_http2_psk_and_compression()
    eng2 = tls13_record_engine_new()
    tls13_engine_enable_h2(eng2, 1)
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    ca2 = get(eng2.re_cert_chain, 0)
    if len(eng2.re_cert_chain) >= 2 ca2 = get(eng2.re_cert_chain, 1) end
    if tls13_add_trust_root(ca2) != 1 return 1 end
    tls13_cache_clear()

    b1 = "{\"h2\":1,\"mode\":\"full\",\"enc\":\"gzip\",\"msg\":\"HTTP/2 TLS 1.3 GZIP verified!\"}"
    b2 = "{\"h2\":2,\"mode\":\"psk_resumed\",\"enc\":\"deflate\",\"msg\":\"HTTP/2 TLS 1.3 1-RTT PSK DEFLATE verified!\"}"
    gz1 = gzip_compress(b1)
    zl2 = zlib_compress(b2)

    lp2 = _wz_listen_loopback()
    lfd2 = lp2[0]
    port2 = lp2[1]
    pid2 = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid2 == 0
        rc_a = _wz_serve_h2_conn(lfd2, eng2, 0, 1, "gzip", gz1)
        if rc_a != 0 syscall(231, 20 + rc_a, 0, 0, 0, 0, 0) end
        rc_b = _wz_serve_h2_conn(lfd2, eng2, 1, 0, "deflate", zl2)
        if rc_b != 0 syscall(231, 30 + rc_b, 0, 0, 0, 0, 0) end
        syscall(3, lfd2, 0, 0, 0, 0, 0)
        syscall(231, 0, 0, 0, 0, 0, 0)
    end
    syscall(3, lfd2, 0, 0, 0, 0, 0)

    c1 = h2_connect_tls("127.0.0.1", "localhost", port2, 1)
    if c1.h2_connected != 1 or c1.h2_alpn != "h2" or c1.h2_tls_resumed != 0
        say "FAIL Z4a: HTTP/2 conn1 failed"
        return 1
    end
    r1 = h2_request(c1, "GET", "/h2-gzip", "localhost", list(), list(), "")
    h2_close(c1)
    if r1.h2r_ok != 1 or r1.h2r_status != 200 or r1.h2r_body != b1 or tls13_cache_count() < 1
        say "FAIL Z4b: HTTP/2 conn1 body/ticket failed"
        return 1
    end

    c2 = h2_connect_tls("127.0.0.1", "localhost", port2, 1)
    if c2.h2_connected != 1 or c2.h2_alpn != "h2" or c2.h2_tls_resumed != 1
        say "FAIL Z4c: HTTP/2 conn2 PSK resumption failed"
        return 1
    end
    r2 = h2_request(c2, "GET", "/h2-deflate", "localhost", list(), list(), "")
    h2_close(c2)
    st2 = malloc(8)
    syscall(61, pid2, st2, 0, 0, 0, 0)
    src2 = (mem_word_read(st2, 0) / 256) % 256
    free(st2, 8)
    if src2 != 0 or r2.h2r_ok != 1 or r2.h2r_status != 200 or r2.h2r_body != b2
        say "FAIL Z4d: HTTP/2 conn2 body failed srv_rc=" + str(src2)
        return 1
    end
    say "  [PASS] Z4. Live HTTP/2 ALPN h2 TLS 1.3 NewSessionTicket + 1-RTT PSK resumption + gzip/deflate"
    return 0
end

fn test_z5_live_https_stream_psk_and_compression()
    eng = tls13_record_engine_new()
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    ca = get(eng.re_cert_chain, 0)
    if len(eng.re_cert_chain) >= 2 ca = get(eng.re_cert_chain, 1) end
    if tls13_add_trust_root(ca) != 1 return 1 end
    tls13_cache_clear()

    bb = buf_new(8)
    buf_write_byte(bb, 65)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 66)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 67)
    buf_write_byte(bb, 255)
    bin_s = buf_to_str(bb)
    buf_free(bb)
    gz_bin = gzip_compress(bin_s)
    msg_ch = "Sovereign streaming HTTPS PSK + chained gzip,deflate verified!"
    ch_body = zlib_compress(gzip_compress(msg_ch))

    lp = _wz_listen_loopback()
    lfd = lp[0]
    port = lp[1]
    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd1 = syscall(43, lfd, 0, 0, 0, 0, 0)
        s1 = tls13_server_handshake_fd(cfd1, eng)
        if s1 == 0 or s1.ts_is_resumed != 0 syscall(231, 41, 0, 0, 0, 0, 0) end
        nst1 = tls13_server_issue_session_ticket(eng, s1)
        _tls13s_write_list_fd(cfd1, nst1[2])
        _tls13s_read_wire_record(cfd1)
        r1 = "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n" + _wz_to_hex(len(gz_bin)) + "\r\n" + gz_bin + "\r\n0\r\n\r\n"
        _tls13s_write_list_fd(cfd1, tls13_record_encrypt(s1, r1))
        a1 = _tls13s_aead_wrap(s1.ts_cipher_suite, s1.ts_app_server_key, s1.ts_app_server_iv, s1.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
        s1.ts_server_seq = s1.ts_server_seq + 1
        _tls13s_write_list_fd(cfd1, a1)
        syscall(3, cfd1, 0, 0, 0, 0, 0)

        cfd2 = syscall(43, lfd, 0, 0, 0, 0, 0)
        s2 = tls13_server_handshake_fd(cfd2, eng)
        if s2 == 0 or s2.ts_is_resumed != 1 syscall(231, 42, 0, 0, 0, 0, 0) end
        _tls13s_read_wire_record(cfd2)
        r2 = "HTTP/1.1 200 OK\r\nContent-Encoding: gzip, deflate\r\nContent-Length: " + str(len(ch_body)) + "\r\nConnection: close\r\n\r\n" + ch_body
        _tls13s_write_list_fd(cfd2, tls13_record_encrypt(s2, r2))
        a2 = _tls13s_aead_wrap(s2.ts_cipher_suite, s2.ts_app_server_key, s2.ts_app_server_iv, s2.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
        s2.ts_server_seq = s2.ts_server_seq + 1
        _tls13s_write_list_fd(cfd2, a2)
        syscall(3, cfd2, 0, 0, 0, 0, 0)
        syscall(3, lfd, 0, 0, 0, 0, 0)
        syscall(231, 0, 0, 0, 0, 0, 0)
    end
    syscall(3, lfd, 0, 0, 0, 0, 0)

    g_wz_stream_acc = ""
    sr1 = http_request_stream("GET", "https://localhost:" + str(port) + "/stream-gz", [], "", _wz_on_stream_chunk)
    if sr1.status_code != 200 or http_last_tls_was_resumed() != 0 or len(g_wz_stream_acc) != 6 or (mem_byte_read(g_wz_stream_acc, 1) & 255) != 0 or (mem_byte_read(g_wz_stream_acc, 5) & 255) != 255 or tls13_cache_count() < 1
        say "FAIL Z5a: http_request_stream conn1 failed"
        return 1
    end
    g_wz_stream_acc = ""
    sr2 = http_request_stream("GET", "https://localhost:" + str(port) + "/stream-psk", [], "", _wz_on_stream_chunk)
    st = malloc(8)
    syscall(61, pid, st, 0, 0, 0, 0)
    src = (mem_word_read(st, 0) / 256) % 256
    free(st, 8)
    if src != 0 or sr2.status_code != 200 or http_last_tls_was_resumed() != 1 or g_wz_stream_acc != msg_ch
        say "FAIL Z5b: http_request_stream conn2 PSK+chained failed srv_rc=" + str(src)
        return 1
    end
    say "  [PASS] Z5. Live http_request_stream HTTPS TLS 1.3 PSK + chunked binary gzip + chained gzip,deflate"
    return 0
end

fn test_z6_mt_psk_cache_stress()
    tls13_cache_clear()
    g_wz_mt_done = malloc(16)
    g_wz_mt_err = malloc(16)
    mem_word_write(g_wz_mt_done, 0, 0)
    mem_word_write(g_wz_mt_err, 0, 0)
    handles = []
    stacks = []
    ti = 0
    while ti < 8
        stk = malloc(131072)
        hdl = malloc(16)
        mem_word_write(hdl, 0, 1)
        mem_word_write(hdl, 8, 0)
        thread_spawn_vm_joinable(fn_ptr(_wz_mt_psk_worker), ti, stk + 131072, hdl)
        stacks = stacks.push(stk)
        handles = handles.push(hdl)
        ti = ti + 1
    end
    ti = 0
    while ti < 8
        h = handles[ti]
        while mem_word_read(h, 0) != 0
            cv = mem_word_read(h, 0)
            if cv != 0
                futex_wait(h, cv)
            end
        end
        ti = ti + 1
    end
    done_cnt = mem_word_read(g_wz_mt_done, 0)
    err_cnt = mem_word_read(g_wz_mt_err, 0)
    if done_cnt != 8 or err_cnt != 0 or tls13_cache_count() != 12
        say "FAIL Z6: MT PSK cache stress done=" + str(done_cnt) + " err=" + str(err_cnt) + " count=" + str(tls13_cache_count())
        return 1
    end
    say "  [PASS] Z6. 8-thread 12,000-op concurrent TLS 1.3 PSK ticket cache spinlock stress"
    return 0
end

fn main()
    if test_z1_calendar_and_monotonic_time() != 0 exit(1) end
    if test_z2_deflate_zlib_gzip_and_http_parse() != 0 exit(1) end
    if test_z3_live_https_psk_and_compression() != 0 exit(1) end
    if test_z4_live_http2_psk_and_compression() != 0 exit(1) end
    if test_z5_live_https_stream_psk_and_compression() != 0 exit(1) end
    if test_z6_mt_psk_cache_stress() != 0 exit(1) end
    say "PASS: test_wave_z_time_deflate_tls_psk"
    return 0
end
