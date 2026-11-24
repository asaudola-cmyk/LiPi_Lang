// ==============================================================================
// Lipi Pure HTTP/2 Wire Protocol Engine (utso/net/http2/server.lp)
// RFC 7540 (HTTP/2 Framing & Connection Preface) + RFC 7541 (HPACK + Huffman)
// Supports live h2c (TCP prior knowledge) and h2 over Pure-Lipi TLS 1.3 (ALPN "h2")
// ==============================================================================

import "utso/net/tls13_server"

H2_FRAME_DATA          = 0
H2_FRAME_HEADERS       = 1
H2_FRAME_PRIORITY      = 2
H2_FRAME_RST_STREAM    = 3
H2_FRAME_SETTINGS      = 4
H2_FRAME_PUSH_PROMISE  = 5
H2_FRAME_PING          = 6
H2_FRAME_GOAWAY        = 7
H2_FRAME_WINDOW_UPDATE = 8
H2_FRAME_CONTINUATION  = 9

H2_FLAG_ACK            = 1
H2_FLAG_END_STREAM     = 1
H2_FLAG_END_HEADERS    = 4
H2_FLAG_PADDED         = 8
H2_FLAG_PRIORITY       = 32

// ── 1. Internal Byte Helpers ──────────────────────────────────────────────────

fn _h2_append dst src
    i = 0
    while i < len(src)
        push(dst, get(src, i) & 255)
        i = i + 1
    end
    return dst

fn _h2_slice src s e
    out = list()
    i = s
    while i < e and i < len(src)
        push(out, get(src, i) & 255)
        i = i + 1
    end
    return out

fn _h2_str_to_bytes s
    out = list()
    i = 0
    n = str_len(s)
    while i < n
        push(out, str_char_at(s, i) & 255)
        i = i + 1
    end
    return out

fn _h2_bytes_to_str b
    out = ""
    i = 0
    n = len(b)
    while i < n
        out = out + chr(get(b, i) & 255)
        i = i + 1
    end
    return out

fn http2_preface_bytes
    // RFC 7540 §3.5: "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n" (24 bytes)
    return [80, 82, 73, 32, 42, 32, 72, 84, 84, 80, 47, 50, 46, 48, 13, 10, 13, 10, 83, 77, 13, 10, 13, 10]

fn http2_check_preface data
    if len(data) < 24
        return 0
    end
    pref = http2_preface_bytes()
    i = 0
    while i < 24
        if (get(data, i) & 255) != get(pref, i)
            return 0
        end
        i = i + 1
    end
    return 1

// ── 2. RFC 7541 Appendix B Canonical Huffman Decoder ──────────────────────────

fn http2_huffman_decode data
    // WHY: Real HTTP/2 clients (curl/nghttp2, browsers) Huffman-encode header strings by default.
    // O(1) canonical range dispatch per bit-length covering all RFC 7541 printable ASCII (32..126).
    t5  = [48, 49, 50, 97, 99, 101, 105, 111, 115, 116]
    t6  = [32, 37, 45, 46, 47, 51, 52, 53, 54, 55, 56, 57, 61, 65, 95, 98, 100, 102, 103, 104, 108, 109, 110, 112, 114, 117]
    t7  = [58, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 89, 106, 107, 113, 118, 119, 120, 121, 122]
    t8  = [38, 42, 44, 59, 88, 90]
    t10 = [33, 34, 40, 41, 63]
    t11 = [39, 43, 124]
    t12 = [35, 62]
    t13 = [0, 36, 64, 91, 93, 126]
    t14 = [94, 125]
    t15 = [60, 96, 123]

    out = ""
    acc = 0
    nbits = 0
    i = 0
    n = len(data)
    while i < n
        b = get(data, i) & 255
        bit_pos = 7
        while bit_pos >= 0
            acc = (acc * 2) | ((b >> bit_pos) & 1)
            nbits = nbits + 1
            sym = 0 - 1

            if nbits == 5
                if acc >= 0 and acc <= 9
                    sym = get(t5, acc)
                end
            elif nbits == 6
                if acc >= 20 and acc <= 45
                    sym = get(t6, acc - 20)
                end
            elif nbits == 7
                if acc >= 92 and acc <= 123
                    sym = get(t7, acc - 92)
                end
            elif nbits == 8
                if acc >= 248 and acc <= 253
                    sym = get(t8, acc - 248)
                end
            elif nbits == 10
                if acc >= 1016 and acc <= 1020
                    sym = get(t10, acc - 1016)
                end
            elif nbits == 11
                if acc >= 2042 and acc <= 2044
                    sym = get(t11, acc - 2042)
                end
            elif nbits == 12
                if acc >= 4090 and acc <= 4091
                    sym = get(t12, acc - 4090)
                end
            elif nbits == 13
                if acc >= 8184 and acc <= 8189
                    sym = get(t13, acc - 8184)
                end
            elif nbits == 14
                if acc >= 16380 and acc <= 16381
                    sym = get(t14, acc - 16380)
                end
            elif nbits == 15
                if acc >= 32764 and acc <= 32766
                    sym = get(t15, acc - 32764)
                end
            elif nbits == 19
                if acc == 524272
                    sym = 92
                end
            elif nbits > 30
                return out
            end

            if sym >= 0
                out = out + chr(sym)
                acc = 0
                nbits = 0
            end
            bit_pos = bit_pos - 1
        end
        i = i + 1
    end
    return out

// ── 3. RFC 7541 HPACK Static Table, Decoder & Encoder ─────────────────────────

fn _h2_static_entry idx
    // RFC 7541 Appendix A (1-indexed)
    if idx == 1  return [":authority", ""] end
    if idx == 2  return [":method", "GET"] end
    if idx == 3  return [":method", "POST"] end
    if idx == 4  return [":path", "/"] end
    if idx == 5  return [":path", "/index.html"] end
    if idx == 6  return [":scheme", "http"] end
    if idx == 7  return [":scheme", "https"] end
    if idx == 8  return [":status", "200"] end
    if idx == 9  return [":status", "204"] end
    if idx == 10 return [":status", "206"] end
    if idx == 11 return [":status", "304"] end
    if idx == 12 return [":status", "400"] end
    if idx == 13 return [":status", "404"] end
    if idx == 14 return [":status", "500"] end
    if idx == 15 return ["accept-charset", ""] end
    if idx == 16 return ["accept-encoding", "gzip, deflate"] end
    if idx == 17 return ["accept-language", ""] end
    if idx == 18 return ["accept-ranges", ""] end
    if idx == 19 return ["accept", ""] end
    if idx == 20 return ["access-control-allow-origin", ""] end
    if idx == 21 return ["age", ""] end
    if idx == 22 return ["allow", ""] end
    if idx == 23 return ["authorization", ""] end
    if idx == 24 return ["cache-control", ""] end
    if idx == 25 return ["content-disposition", ""] end
    if idx == 26 return ["content-encoding", ""] end
    if idx == 27 return ["content-language", ""] end
    if idx == 28 return ["content-length", ""] end
    if idx == 29 return ["content-location", ""] end
    if idx == 30 return ["content-range", ""] end
    if idx == 31 return ["content-type", ""] end
    if idx == 32 return ["cookie", ""] end
    if idx == 33 return ["date", ""] end
    if idx == 34 return ["etag", ""] end
    if idx == 35 return ["expect", ""] end
    if idx == 36 return ["expires", ""] end
    if idx == 37 return ["from", ""] end
    if idx == 38 return ["host", ""] end
    if idx == 44 return ["last-modified", ""] end
    if idx == 46 return ["location", ""] end
    if idx == 50 return ["range", ""] end
    if idx == 51 return ["referer", ""] end
    if idx == 54 return ["server", ""] end
    if idx == 55 return ["set-cookie", ""] end
    if idx == 58 return ["user-agent", ""] end
    if idx == 59 return ["vary", ""] end
    return ["", ""]

fn _h2_hpack_read_int data pos prefix_bits
    if pos >= len(data)
        return [0, pos]
    end
    mask = (1 << prefix_bits) - 1
    val = get(data, pos) & mask
    pos = pos + 1
    if val < mask
        return [val, pos]
    end
    shift = 0
    while pos < len(data)
        b = get(data, pos) & 255
        pos = pos + 1
        val = val + ((b & 127) << shift)
        if (b & 128) == 0
            break
        end
        shift = shift + 7
    end
    return [val, pos]

fn _h2_hpack_read_str data pos
    if pos >= len(data)
        return ["", pos]
    end
    is_huff = (get(data, pos) & 128) != 0
    ir = _h2_hpack_read_int(data, pos, 7)
    slen = ir[0]
    pos = ir[1]
    if pos + slen > len(data)
        return ["", len(data)]
    end
    raw = _h2_slice(data, pos, pos + slen)
    pos = pos + slen
    if is_huff == 1
        return [http2_huffman_decode(raw), pos]
    end
    return [_h2_bytes_to_str(raw), pos]

fn _h2_lookup_table dyn_names dyn_vals idx
    if idx >= 1 and idx <= 61
        return _h2_static_entry(idx)
    end
    didx = idx - 62
    dlen = len(dyn_names)
    if didx >= 0 and didx < dlen
        // Dynamic table is LIFO: newest entry is index 62 (last element pushed)
        pos = dlen - 1 - didx
        return [get(dyn_names, pos), get(dyn_vals, pos)]
    end
    return ["", ""]

fn http2_hpack_decode_headers block
    // Decodes an RFC 7541 header block into parallel lists [names, values]
    names = list()
    vals = list()
    dyn_names = list()
    dyn_vals = list()
    pos = 0
    blen = len(block)
    while pos < blen
        b = get(block, pos) & 255
        if (b & 128) != 0
            // Indexed Header Field (RFC 7541 §6.1)
            ir = _h2_hpack_read_int(block, pos, 7)
            idx = ir[0]
            pos = ir[1]
            kv = _h2_lookup_table(dyn_names, dyn_vals, idx)
            push(names, kv[0])
            push(vals, kv[1])
        elif (b & 192) == 64
            // Literal Header Field with Incremental Indexing (RFC 7541 §6.2.1)
            ir = _h2_hpack_read_int(block, pos, 6)
            idx = ir[0]
            pos = ir[1]
            hname = ""
            if idx > 0
                kv = _h2_lookup_table(dyn_names, dyn_vals, idx)
                hname = kv[0]
            else
                sr = _h2_hpack_read_str(block, pos)
                hname = sr[0]
                pos = sr[1]
            end
            vr = _h2_hpack_read_str(block, pos)
            hval = vr[0]
            pos = vr[1]
            push(names, hname)
            push(vals, hval)
            push(dyn_names, hname)
            push(dyn_vals, hval)
        elif (b & 224) == 32
            // Dynamic Table Size Update (RFC 7541 §6.3)
            ir = _h2_hpack_read_int(block, pos, 5)
            pos = ir[1]
        else
            // Literal without Indexing (0x00) or Never Indexed (0x10)
            ir = _h2_hpack_read_int(block, pos, 4)
            idx = ir[0]
            pos = ir[1]
            hname = ""
            if idx > 0
                kv = _h2_lookup_table(dyn_names, dyn_vals, idx)
                hname = kv[0]
            else
                sr = _h2_hpack_read_str(block, pos)
                hname = sr[0]
                pos = sr[1]
            end
            vr = _h2_hpack_read_str(block, pos)
            hval = vr[0]
            pos = vr[1]
            push(names, hname)
            push(vals, hval)
        end
    end
    return [names, vals]

fn _h2_hpack_write_int out first_mask prefix_bits val
    max_p = (1 << prefix_bits) - 1
    if val < max_p
        push(out, (first_mask | val) & 255)
        return out
    end
    push(out, (first_mask | max_p) & 255)
    rem = val - max_p
    while rem >= 128
        push(out, (rem & 127) | 128)
        rem = rem / 128
    end
    push(out, rem & 127)
    return out

fn _h2_hpack_write_str out s
    sb = _h2_str_to_bytes(s)
    _h2_hpack_write_int(out, 0, 7, len(sb))
    return _h2_append(out, sb)

fn http2_hpack_encode_response status_code content_type body_len
    blk = list()
    // :status pseudo-header
    if status_code == 200
        push(blk, 136) // 0x80 | 8
    elif status_code == 204
        push(blk, 137) // 0x80 | 9
    elif status_code == 400
        push(blk, 140) // 0x80 | 12
    elif status_code == 404
        push(blk, 141) // 0x80 | 13
    elif status_code == 500
        push(blk, 142) // 0x80 | 14
    else
        _h2_hpack_write_int(blk, 0, 4, 8)
        _h2_hpack_write_str(blk, str(status_code))
    end
    // content-type (static index 31)
    _h2_hpack_write_int(blk, 0, 4, 31)
    _h2_hpack_write_str(blk, content_type)
    // content-length (static index 28)
    _h2_hpack_write_int(blk, 0, 4, 28)
    _h2_hpack_write_str(blk, str(body_len))
    // server (static index 54)
    _h2_hpack_write_int(blk, 0, 4, 54)
    _h2_hpack_write_str(blk, "lipi/1.0.1")
    return blk

// ── 4. RFC 7540 Frame Builders ────────────────────────────────────────────────

fn http2_build_frame ftype flags stream_id payload
    plen = len(payload)
    out = [
        (plen >> 16) & 255,
        (plen >> 8) & 255,
        plen & 255,
        ftype & 255,
        flags & 255,
        (stream_id >> 24) & 127,
        (stream_id >> 16) & 255,
        (stream_id >> 8) & 255,
        stream_id & 255
    ]
    return _h2_append(out, payload)

fn http2_build_server_settings
    // SETTINGS_MAX_CONCURRENT_STREAMS (3) = 128, SETTINGS_MAX_FRAME_SIZE (5) = 16384
    payload = [0, 3, 0, 0, 0, 128, 0, 5, 0, 0, 64, 0]
    return http2_build_frame(H2_FRAME_SETTINGS, 0, 0, payload)

fn http2_build_settings_ack
    return http2_build_frame(H2_FRAME_SETTINGS, H2_FLAG_ACK, 0, list())

fn http2_build_ping_ack opaque8
    return http2_build_frame(H2_FRAME_PING, H2_FLAG_ACK, 0, opaque8)

fn http2_build_goaway last_stream_id err_code
    payload = [
        (last_stream_id >> 24) & 127,
        (last_stream_id >> 16) & 255,
        (last_stream_id >> 8) & 255,
        last_stream_id & 255,
        (err_code >> 24) & 255,
        (err_code >> 16) & 255,
        (err_code >> 8) & 255,
        err_code & 255
    ]
    return http2_build_frame(H2_FRAME_GOAWAY, 0, 0, payload)

fn http2_build_response_frames stream_id status_code content_type body_str
    body_b = _h2_str_to_bytes(body_str)
    blen = len(body_b)
    hblk = http2_hpack_encode_response(status_code, content_type, blen)
    out = list()
    if blen == 0
        _h2_append(out, http2_build_frame(H2_FRAME_HEADERS, H2_FLAG_END_HEADERS | H2_FLAG_END_STREAM, stream_id, hblk))
        return out
    end
    _h2_append(out, http2_build_frame(H2_FRAME_HEADERS, H2_FLAG_END_HEADERS, stream_id, hblk))
    off = 0
    while off < blen
        stop = off + 16384
        if stop > blen
            stop = blen
        end
        dflags = 0
        if stop == blen
            dflags = H2_FLAG_END_STREAM
        end
        _h2_append(out, http2_build_frame(H2_FRAME_DATA, dflags, stream_id, _h2_slice(body_b, off, stop)))
        off = stop
    end
    return out

fn _h2_extract_headers_payload flags payload
    pos = 0
    end_pos = len(payload)
    if (flags & H2_FLAG_PADDED) != 0 and pos < end_pos
        pad_len = get(payload, pos) & 255
        pos = pos + 1
        end_pos = end_pos - pad_len
    end
    if (flags & H2_FLAG_PRIORITY) != 0 and pos + 5 <= end_pos
        pos = pos + 5
    end
    if pos > end_pos
        return list()
    end
    return _h2_slice(payload, pos, end_pos)

fn _h2_find_header names vals target
    i = 0
    n = len(names)
    while i < n
        if get(names, i) == target
            return get(vals, i)
        end
        i = i + 1
    end
    return ""

// ── 5. Transport-Agnostic Byte Stream Helpers (Plain TCP & TLS 1.3) ───────────

fn _h2_tcp_read_exact fd need
    if need <= 0 return list() end
    buf = malloc(need)
    if buf <= 0 return list() end
    got = 0
    while got < need
        n = syscall(0, fd, buf + got, need - got, 0, 0, 0)
        if n <= 0
            free(buf, need)
            return list()
        end
        got = got + n
    end
    out = list()
    i = 0
    while i < need
        push(out, mem_byte_read(buf, i) & 255)
        i = i + 1
    end
    free(buf, need)
    return out

fn _h2_tls_pull_bytes fd session rx_buf need
    while len(rx_buf) < need
        rec = _tls13s_read_wire_record(fd)
        if len(rec) < 22
            return [0, list(), rx_buf]
        end
        unw = tls13_record_decrypt_raw(session, rec)
        if unw[0] != 1
            return [0, list(), rx_buf]
        end
        if unw[1] == TLS_CONTENT_ALERT
            return [0, list(), rx_buf]
        end
        if unw[1] == TLS_CONTENT_APPLICATION_DATA
            _h2_append(rx_buf, unw[2])
        end
    end
    taken = _h2_slice(rx_buf, 0, need)
    rem = _h2_slice(rx_buf, need, len(rx_buf))
    return [1, taken, rem]

fn _h2_graceful_close fd
    // WHY: Per Linux TCP/RFC 1122, close() while unread bytes (e.g. client SETTINGS ACK) sit
    // in the recv buffer sends TCP RST and discards unread server response bytes at the client.
    // Sending SHUT_WR first and draining until client FIN/timeout guarantees clean EOF delivery.
    syscall(48, fd, 1, 0, 0, 0, 0) // SYS_shutdown(fd, SHUT_WR)
    pfd = malloc(16)
    drain = malloc(1024)
    if pfd > 0 and drain > 0
        tries = 0
        while tries < 8
            mem_byte_write(pfd, 0, fd & 255)
            mem_byte_write(pfd, 1, (fd >> 8) & 255)
            mem_byte_write(pfd, 2, (fd >> 16) & 255)
            mem_byte_write(pfd, 3, (fd >> 24) & 255)
            mem_byte_write(pfd, 4, 1) // POLLIN
            mem_byte_write(pfd, 5, 0)
            mem_byte_write(pfd, 6, 0)
            mem_byte_write(pfd, 7, 0)
            pr = syscall(7, pfd, 1, 50, 0, 0, 0) // SYS_poll(pfd, 1, 50ms)
            if pr <= 0
                break
            end
            n = syscall(0, fd, drain, 1024, 0, 0, 0)
            if n <= 0
                break
            end
            tries = tries + 1
        end
    end
    if pfd > 0 free(pfd, 16) end
    if drain > 0 free(drain, 1024) end
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

// ── 6. Live h2c (TCP) and h2 (TLS 1.3 ALPN) Server Drivers ────────────────────

fn http2_serve_h2c_once listen_fd response_body
    // WHY: Accepts 1 cleartext HTTP/2 (h2c prior knowledge) connection, validates the 24-byte
    // preface, completes SETTINGS/PING/HEADERS exchange, sends HPACK HEADERS+DATA+GOAWAY.
    cfd = syscall(43, listen_fd, 0, 0, 0, 0, 0)
    if cfd < 0
        return [0, "", ""]
    end
    pref = _h2_tcp_read_exact(cfd, 24)
    if http2_check_preface(pref) != 1
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return [0, "", ""]
    end
    _tls13s_write_list_fd(cfd, http2_build_server_settings())

    req_method = ""
    req_path = ""
    req_stream = 0
    done = 0
    frames_seen = 0
    while done == 0 and frames_seen < 32
        hdr = _h2_tcp_read_exact(cfd, 9)
        if len(hdr) < 9
            break
        end
        flen = ((get(hdr, 0) & 255) << 16) | ((get(hdr, 1) & 255) << 8) | (get(hdr, 2) & 255)
        ftype = get(hdr, 3) & 255
        flags = get(hdr, 4) & 255
        sid = ((get(hdr, 5) & 127) << 24) | ((get(hdr, 6) & 255) << 16) | ((get(hdr, 7) & 255) << 8) | (get(hdr, 8) & 255)
        if flen > 65536
            break
        end
        payload = _h2_tcp_read_exact(cfd, flen)
        if len(payload) != flen
            break
        end
        frames_seen = frames_seen + 1

        if ftype == H2_FRAME_SETTINGS
            if (flags & H2_FLAG_ACK) == 0
                _tls13s_write_list_fd(cfd, http2_build_settings_ack())
            end
        elif ftype == H2_FRAME_PING
            if (flags & H2_FLAG_ACK) == 0 and flen == 8
                _tls13s_write_list_fd(cfd, http2_build_ping_ack(payload))
            end
        elif ftype == H2_FRAME_HEADERS
            hblk = _h2_extract_headers_payload(flags, payload)
            kv = http2_hpack_decode_headers(hblk)
            req_method = _h2_find_header(kv[0], kv[1], ":method")
            req_path = _h2_find_header(kv[0], kv[1], ":path")
            req_stream = sid
            if (flags & H2_FLAG_END_STREAM) != 0
                done = 1
            end
        elif ftype == H2_FRAME_DATA
            if sid == req_stream and (flags & H2_FLAG_END_STREAM) != 0
                done = 1
            end
        elif ftype == H2_FRAME_GOAWAY
            break
        end
    end

    if req_stream > 0
        resp = http2_build_response_frames(req_stream, 200, "application/json", response_body)
        _h2_append(resp, http2_build_goaway(req_stream, 0))
        _tls13s_write_list_fd(cfd, resp)
        _h2_graceful_close(cfd)
        return [1, req_method, req_path]
    end
    _h2_graceful_close(cfd)
    return [0, "", ""]

fn http2_serve_tls_h2_once listen_fd engine response_body
    // WHY: Accepts 1 TLS 1.3 connection negotiating ALPN "h2", decrypts binary HTTP/2 frames
    // over RFC 8446 AEAD records, and serves HPACK HEADERS + DATA + GOAWAY encrypted back to client.
    tls13_engine_enable_h2(engine, 1)
    cfd = syscall(43, listen_fd, 0, 0, 0, 0, 0)
    if cfd < 0
        return [0, "", "", ""]
    end
    session = tls13_server_handshake_fd(cfd, engine)
    if session == 0
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return [0, "", "", ""]
    end

    rx_buf = list()
    pr = _h2_tls_pull_bytes(cfd, session, rx_buf, 24)
    rx_buf = pr[2]
    if pr[0] != 1 or http2_check_preface(pr[1]) != 1
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return [0, "", "", session.ts_alpn]
    end
    _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(session, http2_build_server_settings()))

    req_method = ""
    req_path = ""
    req_stream = 0
    done = 0
    frames_seen = 0
    while done == 0 and frames_seen < 32
        hr = _h2_tls_pull_bytes(cfd, session, rx_buf, 9)
        rx_buf = hr[2]
        if hr[0] != 1
            break
        end
        hdr = hr[1]
        flen = ((get(hdr, 0) & 255) << 16) | ((get(hdr, 1) & 255) << 8) | (get(hdr, 2) & 255)
        ftype = get(hdr, 3) & 255
        flags = get(hdr, 4) & 255
        sid = ((get(hdr, 5) & 127) << 24) | ((get(hdr, 6) & 255) << 16) | ((get(hdr, 7) & 255) << 8) | (get(hdr, 8) & 255)
        if flen > 65536
            break
        end
        payload = list()
        if flen > 0
            plr = _h2_tls_pull_bytes(cfd, session, rx_buf, flen)
            rx_buf = plr[2]
            if plr[0] != 1
                break
            end
            payload = plr[1]
        end
        frames_seen = frames_seen + 1

        if ftype == H2_FRAME_SETTINGS
            if (flags & H2_FLAG_ACK) == 0
                _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(session, http2_build_settings_ack()))
            end
        elif ftype == H2_FRAME_PING
            if (flags & H2_FLAG_ACK) == 0 and flen == 8
                _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(session, http2_build_ping_ack(payload)))
            end
        elif ftype == H2_FRAME_HEADERS
            hblk = _h2_extract_headers_payload(flags, payload)
            kv = http2_hpack_decode_headers(hblk)
            req_method = _h2_find_header(kv[0], kv[1], ":method")
            req_path = _h2_find_header(kv[0], kv[1], ":path")
            req_stream = sid
            if (flags & H2_FLAG_END_STREAM) != 0
                done = 1
            end
        elif ftype == H2_FRAME_DATA
            if sid == req_stream and (flags & H2_FLAG_END_STREAM) != 0
                done = 1
            end
        elif ftype == H2_FRAME_GOAWAY
            break
        end
    end

    if req_stream > 0
        resp = http2_build_response_frames(req_stream, 200, "application/json", response_body)
        _h2_append(resp, http2_build_goaway(req_stream, 0))
        _tls13s_write_list_fd(cfd, tls13_record_encrypt_raw(session, resp))
        close_alert = _tls13s_aead_wrap(session.ts_cipher_suite, session.ts_app_server_key, session.ts_app_server_iv, session.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
        session.ts_server_seq = session.ts_server_seq + 1
        _tls13s_write_list_fd(cfd, close_alert)
        _h2_graceful_close(cfd)
        return [1, req_method, req_path, session.ts_alpn]
    end
    _h2_graceful_close(cfd)
    return [0, "", "", session.ts_alpn]

fn http2_serve_h2c_multi listen_fd expected_streams
    // WHY: Accepts 1 cleartext HTTP/2 (h2c) connection and serves `expected_streams` multiplexed
    // requests (including PING ACK, WINDOW_UPDATE, HEADERS+DATA body echo) on the same TCP stream.
    cfd = syscall(43, listen_fd, 0, 0, 0, 0, 0)
    if cfd < 0 return 0 end
    pref = _h2_tcp_read_exact(cfd, 24)
    if http2_check_preface(pref) != 1
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return 0
    end
    _tls13s_write_list_fd(cfd, http2_build_server_settings())

    s_ids = list()
    s_methods = list()
    s_paths = list()
    s_bodies = list()
    served = 0
    last_sid = 0
    frames_seen = 0
    while served < expected_streams and frames_seen < 128
        hdr = _h2_tcp_read_exact(cfd, 9)
        if len(hdr) < 9 break end
        flen = ((get(hdr, 0) & 255) << 16) | ((get(hdr, 1) & 255) << 8) | (get(hdr, 2) & 255)
        ftype = get(hdr, 3) & 255
        flags = get(hdr, 4) & 255
        sid = ((get(hdr, 5) & 127) << 24) | ((get(hdr, 6) & 255) << 16) | ((get(hdr, 7) & 255) << 8) | (get(hdr, 8) & 255)
        if flen > 65536 break end
        payload = list()
        if flen > 0
            payload = _h2_tcp_read_exact(cfd, flen)
            if len(payload) != flen break end
        end
        frames_seen = frames_seen + 1

        if ftype == H2_FRAME_SETTINGS
            if (flags & H2_FLAG_ACK) == 0
                _tls13s_write_list_fd(cfd, http2_build_settings_ack())
            end
        elif ftype == H2_FRAME_PING
            if (flags & H2_FLAG_ACK) == 0 and flen == 8
                _tls13s_write_list_fd(cfd, http2_build_ping_ack(payload))
            end
        elif ftype == H2_FRAME_HEADERS
            hblk = _h2_extract_headers_payload(flags, payload)
            kv = http2_hpack_decode_headers(hblk)
            rm = _h2_find_header(kv[0], kv[1], ":method")
            rp = _h2_find_header(kv[0], kv[1], ":path")
            push(s_ids, sid)
            push(s_methods, rm)
            push(s_paths, rp)
            push(s_bodies, "")
            if sid > last_sid last_sid = sid end
            if (flags & H2_FLAG_END_STREAM) != 0
                reply = "{\"stream\":" + str(sid) + ",\"method\":\"" + rm + "\",\"path\":\"" + rp + "\"}"
                _tls13s_write_list_fd(cfd, http2_build_response_frames(sid, 200, "application/json", reply))
                served = served + 1
            end
        elif ftype == H2_FRAME_DATA
            idx = 0
            found = 0 - 1
            while idx < len(s_ids)
                if get(s_ids, idx) == sid
                    found = idx
                    break
                end
                idx = idx + 1
            end
            if found >= 0
                cur_b = get(s_bodies, found) + _h2_bytes_to_str(payload)
                list_set(s_bodies, found, cur_b)
                if (flags & H2_FLAG_END_STREAM) != 0
                    rm2 = get(s_methods, found)
                    rp2 = get(s_paths, found)
                    reply2 = "{\"stream\":" + str(sid) + ",\"method\":\"" + rm2 + "\",\"path\":\"" + rp2 + "\",\"echo\":\"" + cur_b + "\"}"
                    _tls13s_write_list_fd(cfd, http2_build_response_frames(sid, 200, "application/json", reply2))
                    served = served + 1
                end
            end
        elif ftype == H2_FRAME_GOAWAY
            break
        end
    end
    _tls13s_write_list_fd(cfd, http2_build_goaway(last_sid, 0))
    _h2_graceful_close(cfd)
    return served
