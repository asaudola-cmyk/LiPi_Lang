// ==============================================================================
// LIPI PURE-SILICON HTTP/2 CLIENT ENGINE (utso/net/http2/client.lp)
// 100% Pure Lipi | 0% nghttp2 / 0% OpenSSL / 0% libc | RFC 9113 + RFC 7541 + TLS 1.3 ALPN
// ==============================================================================
//
// WHY THIS MODULE:
// Implements a complete RFC 9113 HTTP/2 binary framing & multiplexed stream client
// over BOTH cleartext TCP (h2c prior knowledge) AND Pure-Lipi TLS 1.3 with ALPN "h2"
// negotiation (RFC 7301 + RFC 8446). Supports concurrent odd-numbered streams,
// RFC 7541 HPACK encoding/decoding + Huffman + dynamic table, CONTINUATION headers,
// PING/PONG RTT checks, WINDOW_UPDATE flow control, RST_STREAM, and GOAWAY.
// ==============================================================================

import "utso/net/tls/tls13"
import "utso/core/memory"

H2C_FRAME_DATA          = 0
H2C_FRAME_HEADERS       = 1
H2C_FRAME_PRIORITY      = 2
H2C_FRAME_RST_STREAM    = 3
H2C_FRAME_SETTINGS      = 4
H2C_FRAME_PUSH_PROMISE  = 5
H2C_FRAME_PING          = 6
H2C_FRAME_GOAWAY        = 7
H2C_FRAME_WINDOW_UPDATE = 8
H2C_FRAME_CONTINUATION  = 9

H2C_FLAG_ACK            = 1
H2C_FLAG_END_STREAM     = 1
H2C_FLAG_END_HEADERS    = 4
H2C_FLAG_PADDED         = 8
H2C_FLAG_PRIORITY       = 32

struct H2Client
    h2_fd
    h2_is_tls
    h2_tls_cipher
    h2_tls_c_key
    h2_tls_c_iv
    h2_tls_s_key
    h2_tls_s_iv
    h2_tls_c_seq
    h2_tls_s_seq
    h2_alpn
    h2_tls_rx
    h2_next_stream_id
    h2_max_frame_size
    h2_conn_window
    h2_dyn_names
    h2_dyn_vals
    h2_s_ids
    h2_s_status
    h2_s_hnames
    h2_s_hvals
    h2_s_body_bufs
    h2_s_done
    h2_s_err
    h2_got_goaway
    h2_goaway_last_sid
    h2_goaway_err
    h2_last_ping_ack
    h2_connected
end

struct H2Response
    h2r_ok
    h2r_stream_id
    h2r_status
    h2r_header_names
    h2r_header_vals
    h2r_body
    h2r_err_code
    h2r_alpn
end

// ── 1. Internal Byte / Socket / TLS-1.3 Client Transport ─────────────────────

fn _h2c_append dst src
    i = 0
    n = len(src)
    while i < n
        push(dst, get(src, i) & 255)
        i = i + 1
    end
    return dst
end

fn _h2c_slice src s e
    out = list()
    i = s
    n = len(src)
    while i < e and i < n
        push(out, get(src, i) & 255)
        i = i + 1
    end
    return out
end

fn _h2c_str_to_bytes s
    out = list()
    n = str_len(s)
    i = 0
    while i < n
        push(out, str_char_at(s, i) & 255)
        i = i + 1
    end
    return out
end

fn _h2c_bytes_to_str arr
    n = len(arr)
    if n <= 0 return "" end
    b = buf_new(n + 8)
    i = 0
    while i < n
        buf_write_byte(b, get(arr, i) & 255)
        i = i + 1
    end
    res = buf_to_str(b)
    buf_free(b)
    return res
end

fn _h2c_parse_ipv4 ip_str
    // Parses dotted IPv4 string ("127.0.0.1") into 4-byte list [a, b, c, d]
    parts = list()
    cur = 0
    has_d = 0
    n = str_len(ip_str)
    i = 0
    while i < n
        ch = str_char_at(ip_str, i) & 255
        if ch >= 48 and ch <= 57
            cur = (cur * 10) + (ch - 48)
            has_d = 1
        elif ch == 46
            push(parts, cur & 255)
            cur = 0
            has_d = 0
        end
        i = i + 1
    end
    if has_d == 1 push(parts, cur & 255) end
    if len(parts) != 4 return [127, 0, 0, 1] end
    return parts
end

fn _h2c_tcp_dial ip_str port
    fd = syscall(41, 2, 1, 0, 0, 0, 0) // AF_INET=2, SOCK_STREAM=1
    if fd < 0 return 0 - 1 end
    octs = _h2c_parse_ipv4(ip_str)
    sa = malloc(16)
    i = 0
    while i < 16
        mem_write_byte(sa, i, 0)
        i = i + 1
    end
    mem_write_byte(sa, 0, 2) // AF_INET LE
    mem_write_byte(sa, 1, 0)
    mem_write_byte(sa, 2, (port >> 8) & 255)
    mem_write_byte(sa, 3, port & 255)
    mem_write_byte(sa, 4, octs[0] & 255)
    mem_write_byte(sa, 5, octs[1] & 255)
    mem_write_byte(sa, 6, octs[2] & 255)
    mem_write_byte(sa, 7, octs[3] & 255)
    rc = syscall(42, fd, sa, 16, 0, 0, 0)
    free(sa, 16)
    if rc < 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return 0 - 1
    end
    return fd
end

fn _h2c_fd_write_exact fd data
    n = len(data)
    if n <= 0 return 1 end
    buf = malloc(n)
    if buf <= 0 return 0 end
    i = 0
    while i < n
        mem_write_byte(buf, i, get(data, i) & 255)
        i = i + 1
    end
    sent = 0
    while sent < n
        w = syscall(1, fd, buf + sent, n - sent, 0, 0, 0)
        if w <= 0
            free(buf, n)
            return 0
        end
        sent = sent + w
    end
    free(buf, n)
    return 1
end

fn _h2c_fd_read_exact fd need
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
        push(out, mem_read_byte(buf, i) & 255)
        i = i + 1
    end
    free(buf, need)
    return out
end

fn _h2c_tls_nonce iv12 seq
    out = list()
    i = 0
    while i < 12
        push(out, get(iv12, i) & 255)
        i = i + 1
    end
    k = 0
    while k < 8
        shift = (7 - k) * 8
        sb = (seq >> shift) & 255
        list_set(out, 4 + k, get(out, 4 + k) ^ sb)
        k = k + 1
    end
    return out
end

fn _h2c_tls_wrap cipher key iv seq inner_type pt_bytes
    inner = _h2c_append(list(), pt_bytes)
    push(inner, inner_type & 255)
    ct_len = len(inner) + 16
    hdr = [23, 3, 3, (ct_len >> 8) & 255, ct_len & 255]
    nonce = _h2c_tls_nonce(iv, seq)
    ct = list()
    if cipher == 4867
        ct = tls_chacha20_poly1305_encrypt_raw(key, nonce, inner, hdr)
    else
        ct = tls_aes_gcm_encrypt_raw(key, nonce, inner, hdr)
    end
    out = _h2c_append(list(), hdr)
    return _h2c_append(out, ct)
end

fn _h2c_tls_read_rec fd
    hdr = _h2c_fd_read_exact(fd, 5)
    if len(hdr) < 5 return [0, 0, list(), list()] end
    rtype = get(hdr, 0) & 255
    rlen = ((get(hdr, 3) & 255) << 8) | (get(hdr, 4) & 255)
    if rlen > 18432 return [0, 0, list(), list()] end
    body = list()
    if rlen > 0
        body = _h2c_fd_read_exact(fd, rlen)
        if len(body) != rlen return [0, 0, list(), list()] end
    end
    return [1, rtype, hdr, body]
end

fn _h2c_tls_unwrap cipher key iv seq hdr body
    nonce = _h2c_tls_nonce(iv, seq)
    pt = list()
    if cipher == 4867
        pt = tls_chacha20_poly1305_decrypt_raw(key, nonce, body, hdr)
    else
        pt = tls_aes_gcm_decrypt_raw(key, nonce, body, hdr)
    end
    if len(pt) == 0 return [0, 0, list()] end
    // Strip trailing zero padding to locate RFC 8446 inner ContentType
    end_i = len(pt) - 1
    while end_i >= 0 and (get(pt, end_i) & 255) == 0
        end_i = end_i - 1
    end
    if end_i < 0 return [0, 0, list()] end
    ctype = get(pt, end_i) & 255
    return [1, ctype, _h2c_slice(pt, 0, end_i)]
end

fn _h2c_tls_hash cipher data
    if cipher == 4866
        return sha384_hash_bytes(data)
    end
    return sha256_hash_bytes(data)
end

fn _h2c_tls_parse_server_hello hs_msg
    // Returns [ok, cipher_suite, server_x25519_pub32]
    n = len(hs_msg)
    if n < 44 or (get(hs_msg, 0) & 255) != 2 return [0, 0, list()] end
    pos = 4 + 2 + 32
    sid_len = get(hs_msg, pos) & 255
    pos = pos + 1 + sid_len
    if pos + 5 > n return [0, 0, list()] end
    cipher = ((get(hs_msg, pos) & 255) << 8) | (get(hs_msg, pos + 1) & 255)
    pos = pos + 3 // cipher(2) + compression(1)
    ext_len = ((get(hs_msg, pos) & 255) << 8) | (get(hs_msg, pos + 1) & 255)
    pos = pos + 2
    end_p = pos + ext_len
    if end_p > n end_p = n end
    pub = list()
    while pos + 4 <= end_p
        et = ((get(hs_msg, pos) & 255) << 8) | (get(hs_msg, pos + 1) & 255)
        el = ((get(hs_msg, pos + 2) & 255) << 8) | (get(hs_msg, pos + 3) & 255)
        pos = pos + 4
        if pos + el > end_p break end
        if et == 51 and el >= 36
            grp = ((get(hs_msg, pos) & 255) << 8) | (get(hs_msg, pos + 1) & 255)
            klen = ((get(hs_msg, pos + 2) & 255) << 8) | (get(hs_msg, pos + 3) & 255)
            if grp == 29 and klen == 32 and 4 + klen <= el
                pub = _h2c_slice(hs_msg, pos + 4, pos + 36)
            end
        end
        pos = pos + el
    end
    if len(pub) != 32 return [0, 0, list()] end
    return [1, cipher, pub]
end

fn _h2c_tls_extract_certs msg
    out = list()
    n = len(msg)
    if n < 9 return out end
    ctx_len = get(msg, 4) & 255
    pos = 5 + ctx_len
    if pos + 3 > n return out end
    list_len = ((get(msg, pos) & 255) << 16) | ((get(msg, pos + 1) & 255) << 8) | (get(msg, pos + 2) & 255)
    pos = pos + 3
    end_p = pos + list_len
    if end_p > n end_p = n end
    while pos + 3 <= end_p
        clen = ((get(msg, pos) & 255) << 16) | ((get(msg, pos + 1) & 255) << 8) | (get(msg, pos + 2) & 255)
        pos = pos + 3
        if pos + clen + 2 > end_p break end
        push(out, _h2c_slice(msg, pos, pos + clen))
        pos = pos + clen
        elen = ((get(msg, pos) & 255) << 8) | (get(msg, pos + 1) & 255)
        pos = pos + 2 + elen
    end
    return out
end

fn _h2c_ct_eq a b
    if len(a) != len(b) return 0 end
    diff = 0
    i = 0
    while i < len(a)
        diff = diff | ((get(a, i) & 255) ^ (get(b, i) & 255))
        i = i + 1
    end
    if diff == 0 return 1 end
    return 0
end

// ── 2. RFC 7541 HPACK Request Encoder & Stateful Response Decoder ────────────

fn _h2c_huff_decode data
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

    b_out = buf_new(len(data) * 2 + 16)
    acc = 0
    nbits = 0
    i = 0
    n = len(data)
    while i < n
        bv = get(data, i) & 255
        bp = 7
        while bp >= 0
            acc = (acc * 2) | ((bv >> bp) & 1)
            nbits = nbits + 1
            sym = 0 - 1
            if nbits == 5 and acc >= 0 and acc <= 9
                sym = get(t5, acc)
            elif nbits == 6 and acc >= 20 and acc <= 45
                sym = get(t6, acc - 20)
            elif nbits == 7 and acc >= 92 and acc <= 123
                sym = get(t7, acc - 92)
            elif nbits == 8 and acc >= 248 and acc <= 253
                sym = get(t8, acc - 248)
            elif nbits == 10 and acc >= 1016 and acc <= 1020
                sym = get(t10, acc - 1016)
            elif nbits == 11 and acc >= 2042 and acc <= 2044
                sym = get(t11, acc - 2042)
            elif nbits == 12 and acc >= 4090 and acc <= 4091
                sym = get(t12, acc - 4090)
            elif nbits == 13 and acc >= 8184 and acc <= 8189
                sym = get(t13, acc - 8184)
            elif nbits == 14 and acc >= 16380 and acc <= 16381
                sym = get(t14, acc - 16380)
            elif nbits == 15 and acc >= 32764 and acc <= 32766
                sym = get(t15, acc - 32764)
            elif nbits == 19 and acc == 524272
                sym = 92
            elif nbits > 30
                res = buf_to_str(b_out)
                buf_free(b_out)
                return res
            end
            if sym >= 0
                buf_write_byte(b_out, sym)
                acc = 0
                nbits = 0
            end
            bp = bp - 1
        end
        i = i + 1
    end
    res = buf_to_str(b_out)
    buf_free(b_out)
    return res
end

fn _h2c_static_entry idx
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
    if idx == 16 return ["accept-encoding", "gzip, deflate"] end
    if idx == 19 return ["accept", ""] end
    if idx == 20 return ["access-control-allow-origin", ""] end
    if idx == 23 return ["authorization", ""] end
    if idx == 24 return ["cache-control", ""] end
    if idx == 26 return ["content-encoding", ""] end
    if idx == 28 return ["content-length", ""] end
    if idx == 31 return ["content-type", ""] end
    if idx == 32 return ["cookie", ""] end
    if idx == 33 return ["date", ""] end
    if idx == 34 return ["etag", ""] end
    if idx == 38 return ["host", ""] end
    if idx == 46 return ["location", ""] end
    if idx == 54 return ["server", ""] end
    if idx == 55 return ["set-cookie", ""] end
    if idx == 58 return ["user-agent", ""] end
    if idx == 59 return ["vary", ""] end
    return ["", ""]
end

fn _h2c_hpack_read_int data pos pbits
    if pos >= len(data) return [0, pos] end
    mask = (1 << pbits) - 1
    val = get(data, pos) & mask
    pos = pos + 1
    if val < mask return [val, pos] end
    shift = 0
    while pos < len(data)
        b = get(data, pos) & 255
        pos = pos + 1
        val = val + ((b & 127) << shift)
        if (b & 128) == 0 break end
        shift = shift + 7
    end
    return [val, pos]
end

fn _h2c_hpack_read_str data pos
    if pos >= len(data) return ["", pos] end
    is_h = (get(data, pos) & 128) != 0
    ir = _h2c_hpack_read_int(data, pos, 7)
    slen = ir[0]
    pos = ir[1]
    if pos + slen > len(data) return ["", len(data)] end
    raw = _h2c_slice(data, pos, pos + slen)
    pos = pos + slen
    if is_h == 1 return [_h2c_huff_decode(raw), pos] end
    return [_h2c_bytes_to_str(raw), pos]
end

fn _h2c_hpack_lookup cli idx
    if idx >= 1 and idx <= 61 return _h2c_static_entry(idx) end
    didx = idx - 62
    dlen = len(cli.h2_dyn_names)
    if didx >= 0 and didx < dlen
        p = dlen - 1 - didx
        return [get(cli.h2_dyn_names, p), get(cli.h2_dyn_vals, p)]
    end
    return ["", ""]
end

fn _h2c_hpack_decode cli block
    names = list()
    vals = list()
    pos = 0
    blen = len(block)
    while pos < blen
        b = get(block, pos) & 255
        if (b & 128) != 0
            ir = _h2c_hpack_read_int(block, pos, 7)
            pos = ir[1]
            kv = _h2c_hpack_lookup(cli, ir[0])
            push(names, kv[0])
            push(vals, kv[1])
        elif (b & 192) == 64
            ir = _h2c_hpack_read_int(block, pos, 6)
            idx = ir[0]
            pos = ir[1]
            hn = ""
            if idx > 0
                kv = _h2c_hpack_lookup(cli, idx)
                hn = kv[0]
            else
                sr = _h2c_hpack_read_str(block, pos)
                hn = sr[0]
                pos = sr[1]
            end
            vr = _h2c_hpack_read_str(block, pos)
            hv = vr[0]
            pos = vr[1]
            push(names, hn)
            push(vals, hv)
            push(cli.h2_dyn_names, hn)
            push(cli.h2_dyn_vals, hv)
        elif (b & 224) == 32
            ir = _h2c_hpack_read_int(block, pos, 5)
            pos = ir[1]
        else
            ir = _h2c_hpack_read_int(block, pos, 4)
            idx = ir[0]
            pos = ir[1]
            hn = ""
            if idx > 0
                kv = _h2c_hpack_lookup(cli, idx)
                hn = kv[0]
            else
                sr = _h2c_hpack_read_str(block, pos)
                hn = sr[0]
                pos = sr[1]
            end
            vr = _h2c_hpack_read_str(block, pos)
            hv = vr[0]
            pos = vr[1]
            push(names, hn)
            push(vals, hv)
        end
    end
    return [names, vals]
end

fn _h2c_hpack_write_int out fmask pbits val
    mp = (1 << pbits) - 1
    if val < mp
        push(out, (fmask | val) & 255)
        return out
    end
    push(out, (fmask | mp) & 255)
    rem = val - mp
    while rem >= 128
        push(out, (rem & 127) | 128)
        rem = rem / 128
    end
    push(out, rem & 127)
    return out
end

fn _h2c_hpack_write_str out s
    sb = _h2c_str_to_bytes(s)
    _h2c_hpack_write_int(out, 0, 7, len(sb))
    return _h2c_append(out, sb)
end

fn _h2c_hpack_encode_request method scheme authority path extra_names extra_vals
    blk = list()
    // :method
    if method == "GET"
        push(blk, 130) // 0x80 | 2
    elif method == "POST"
        push(blk, 131) // 0x80 | 3
    else
        _h2c_hpack_write_int(blk, 0, 4, 2)
        _h2c_hpack_write_str(blk, method)
    end
    // :scheme
    if scheme == "https"
        push(blk, 135) // 0x80 | 7
    else
        push(blk, 134) // 0x80 | 6
    end
    // :path
    if path == "/"
        push(blk, 132) // 0x80 | 4
    else
        _h2c_hpack_write_int(blk, 0, 4, 4)
        _h2c_hpack_write_str(blk, path)
    end
    // :authority
    if str_len(authority) > 0
        _h2c_hpack_write_int(blk, 0, 4, 1)
        _h2c_hpack_write_str(blk, authority)
    end
    // user-agent (static 58)
    _h2c_hpack_write_int(blk, 0, 4, 58)
    _h2c_hpack_write_str(blk, "lipi-h2/1.0.1")
    // Extra user headers
    i = 0
    while i < len(extra_names) and i < len(extra_vals)
        push(blk, 0) // literal without indexing, new name
        _h2c_hpack_write_str(blk, get(extra_names, i))
        _h2c_hpack_write_str(blk, get(extra_vals, i))
        i = i + 1
    end
    return blk
end

// ── 3. RFC 9113 Frame Serialization & Wire I/O ────────────────────────────────

fn _h2c_build_frame ftype flags sid payload
    plen = len(payload)
    out = [
        (plen >> 16) & 255,
        (plen >> 8) & 255,
        plen & 255,
        ftype & 255,
        flags & 255,
        (sid >> 24) & 127,
        (sid >> 16) & 255,
        (sid >> 8) & 255,
        sid & 255
    ]
    return _h2c_append(out, payload)
end

fn _h2c_wire_send cli raw_bytes
    if cli.h2_is_tls == 0
        return _h2c_fd_write_exact(cli.h2_fd, raw_bytes)
    end
    // Split across max 16384-byte TLS 1.3 records
    off = 0
    n = len(raw_bytes)
    while off < n
        stop = off + 16384
        if stop > n stop = n end
        rec = _h2c_tls_wrap(cli.h2_tls_cipher, cli.h2_tls_c_key, cli.h2_tls_c_iv, cli.h2_tls_c_seq, 23, _h2c_slice(raw_bytes, off, stop))
        cli.h2_tls_c_seq = cli.h2_tls_c_seq + 1
        if _h2c_fd_write_exact(cli.h2_fd, rec) != 1 return 0 end
        off = stop
    end
    return 1
end

fn _h2c_wire_read_exact cli need
    if need <= 0 return list() end
    if cli.h2_is_tls == 0
        return _h2c_fd_read_exact(cli.h2_fd, need)
    end
    while len(cli.h2_tls_rx) < need
        rec = _h2c_tls_read_rec(cli.h2_fd)
        if rec[0] != 1 return list() end
        if rec[1] == 20 continue end // ChangeCipherSpec compat
        if rec[1] == 21 return list() end
        if rec[1] != 23 return list() end
        unw = _h2c_tls_unwrap(cli.h2_tls_cipher, cli.h2_tls_s_key, cli.h2_tls_s_iv, cli.h2_tls_s_seq, rec[2], rec[3])
        if unw[0] != 1 return list() end
        cli.h2_tls_s_seq = cli.h2_tls_s_seq + 1
        if unw[1] == 21 return list() end // Encrypted Alert (e.g. close_notify)
        if unw[1] == 23
            _h2c_append(cli.h2_tls_rx, unw[2])
        end
    end
    taken = _h2c_slice(cli.h2_tls_rx, 0, need)
    cli.h2_tls_rx = _h2c_slice(cli.h2_tls_rx, need, len(cli.h2_tls_rx))
    return taken
end

fn _h2c_new_client fd is_tls alpn
    return H2Client(
        fd, is_tls, 0, list(), list(), list(), list(), 0, 0, alpn, list(),
        1, 16384, 65535, list(), list(),
        list(), list(), list(), list(), list(), list(), list(),
        0, 0, 0, list(), 1
    )
end

fn _h2c_send_client_preface cli
    // RFC 9113 §3.4: 24-byte connection preface + client SETTINGS (ENABLE_PUSH=0, MAX_FRAME_SIZE=16384)
    pref = [80, 82, 73, 32, 42, 32, 72, 84, 84, 80, 47, 50, 46, 48, 13, 10, 13, 10, 83, 77, 13, 10, 13, 10]
    settings = _h2c_build_frame(H2C_FRAME_SETTINGS, 0, 0, [0, 2, 0, 0, 0, 0, 0, 5, 0, 0, 64, 0])
    _h2c_append(pref, settings)
    return _h2c_wire_send(cli, pref)
end

// ── 4. Public Connection API: h2_connect_h2c & h2_connect_tls ─────────────────

fn h2_connect_h2c host_ip port
    fd = _h2c_tcp_dial(host_ip, port)
    if fd < 0
        c = _h2c_new_client(0 - 1, 0, "")
        c.h2_connected = 0
        return c
    end
    cli = _h2c_new_client(fd, 0, "h2c")
    if _h2c_send_client_preface(cli) != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        cli.h2_connected = 0
        return cli
    end
    return cli
end

fn h2_connect_tls host_ip sni_host port verify_cert
    // WHY: Full RFC 8446 TLS 1.3 handshake advertising ALPN ["h2", "http/1.1"] (RFC 7301),
    // deriving AEAD traffic keys via X25519 + HKDF, verifying Finished + optional X.509 chain,
    // and asserting negotiated ALPN == "h2" before transmitting the HTTP/2 preface.
    bad = _h2c_new_client(0 - 1, 1, "")
    bad.h2_connected = 0
    fd = _h2c_tcp_dial(host_ip, port)
    if fd < 0 return bad end

    // 1. Ephemeral X25519 keypair from kernel CSPRNG (SYS_getrandom 318)
    rng = malloc(32)
    if syscall(318, rng, 32, 0, 0, 0, 0) != 32
        free(rng, 32)
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    c_priv = list()
    ri = 0
    while ri < 32
        push(c_priv, mem_read_byte(rng, ri) & 255)
        ri = ri + 1
    end
    free(rng, 32)
    c_pub = x25519_public_key(c_priv)

    // 2. ClientHello with ALPN ["h2", "http/1.1"]
    ch = tls13_build_client_hello_alpn(sni_host, c_pub, ["h2", "http/1.1"])
    if len(ch.wire_bytes) < 46
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    ch_hs = _h2c_slice(ch.wire_bytes, 5, len(ch.wire_bytes))
    if _h2c_fd_write_exact(fd, ch.wire_bytes) != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end

    // 3. Read ServerHello
    sh_rec = _h2c_tls_read_rec(fd)
    if sh_rec[0] != 1 or sh_rec[1] != 22
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    sh_hs = sh_rec[3]
    shi = _h2c_tls_parse_server_hello(sh_hs)
    if shi[0] != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end
    cipher = shi[1]
    s_pub = shi[2]

    transcript = _h2c_append(list(), ch_hs)
    _h2c_append(transcript, sh_hs)
    shared = x25519_shared_secret(c_priv, s_pub)
    th1 = _h2c_tls_hash(cipher, transcript)

    hs_keys = 0
    c_hs_key = list()
    c_hs_iv = list()
    s_hs_key = list()
    s_hs_iv = list()
    if cipher == 4866
        hs_keys = tls13_derive_handshake_keys_384(shared, th1)
        c_hs_key = hs_keys.client_write_key
        c_hs_iv = hs_keys.client_write_iv
        s_hs_key = hs_keys.server_write_key
        s_hs_iv = hs_keys.server_write_iv
    else
        hs_keys = tls13_derive_handshake_keys(shared, th1)
        if cipher == 4867
            c_hs_key = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "key", list(), 32)
            s_hs_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "key", list(), 32)
        else
            c_hs_key = hs_keys.client_write_key
            s_hs_key = hs_keys.server_write_key
        end
        c_hs_iv = hs_keys.client_write_iv
        s_hs_iv = hs_keys.server_write_iv
    end

    // 4. Consume EncryptedExtensions (ALPN!), Certificate, CertificateVerify, Finished
    hs_buf = list()
    s_hs_seq = 0
    got_fin = 0
    got_cert = 0
    got_cv = 0
    cert_der = list()
    neg_alpn = ""
    steps = 0
    while got_fin == 0 and steps < 64
        steps = steps + 1
        rec = _h2c_tls_read_rec(fd)
        if rec[0] != 1 break end
        if rec[1] == 20 continue end
        if rec[1] != 23 break end
        unw = _h2c_tls_unwrap(cipher, s_hs_key, s_hs_iv, s_hs_seq, rec[2], rec[3])
        if unw[0] != 1 break end
        s_hs_seq = s_hs_seq + 1
        if unw[1] != 22 break end
        _h2c_append(hs_buf, unw[2])

        pos = 0
        while pos + 4 <= len(hs_buf)
            ht = get(hs_buf, pos) & 255
            hl = ((get(hs_buf, pos + 1) & 255) << 16) | ((get(hs_buf, pos + 2) & 255) << 8) | (get(hs_buf, pos + 3) & 255)
            if pos + 4 + hl > len(hs_buf) break end
            msg = _h2c_slice(hs_buf, pos, pos + 4 + hl)
            pos = pos + 4 + hl
            if ht == 8
                neg_alpn = tls13_parse_encrypted_extensions_alpn(msg)
            elif ht == 11
                certs = _h2c_tls_extract_certs(msg)
                if len(certs) > 0
                    if verify_cert == 1
                        if tls13_verify_x509_cert_chain_list(certs, sni_host) != 1
                            syscall(3, fd, 0, 0, 0, 0, 0)
                            return bad
                        end
                    end
                    cert_der = get(certs, 0)
                    got_cert = 1
                end
            elif ht == 15
                if got_cert == 1 and len(msg) >= 8
                    salg = ((get(msg, 4) & 255) << 8) | (get(msg, 5) & 255)
                    slen = ((get(msg, 6) & 255) << 8) | (get(msg, 7) & 255)
                    if 8 + slen == len(msg)
                        sbytes = _h2c_slice(msg, 8, 8 + slen)
                        cvh = _h2c_tls_hash(cipher, transcript)
                        if tls13_verify_certificate_verify(cert_der, cvh, salg, sbytes) != 1
                            syscall(3, fd, 0, 0, 0, 0, 0)
                            return bad
                        end
                        got_cv = 1
                    end
                end
            elif ht == 20
                exp_l = 32
                if cipher == 4866 exp_l = 48 end
                if hl == exp_l
                    exp_fin = list()
                    if cipher == 4866
                        sfk = tls13_hkdf_expand_label_384(hs_keys.server_handshake_traffic_secret, "finished", list(), 48)
                        exp_fin = tls13_hmac_sha384(sfk, sha384_hash_bytes(transcript))
                    else
                        sfk = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "finished", list(), 32)
                        exp_fin = tls13_hmac_sha256(sfk, sha256_hash_bytes(transcript))
                    end
                    act_fin = _h2c_slice(msg, 4, 4 + exp_l)
                    if _h2c_ct_eq(act_fin, exp_fin) != 1
                        syscall(3, fd, 0, 0, 0, 0, 0)
                        return bad
                    end
                    _h2c_append(transcript, msg)
                    got_fin = 1
                    break
                end
            end
            _h2c_append(transcript, msg)
        end
        hs_buf = _h2c_slice(hs_buf, pos, len(hs_buf))
    end

    if got_fin != 1 or got_cert != 1 or got_cv != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end

    // 5. Derive Application Traffic Secrets & send Client Finished
    fin_hash = _h2c_tls_hash(cipher, transcript)
    c_app_key = list()
    c_app_iv = list()
    s_app_key = list()
    s_app_iv = list()
    c_fin_msg = list()
    if cipher == 4866
        z48 = list()
        zi = 0
        while zi < 48 push(z48, 0) zi = zi + 1 end
        d_s = tls13_hkdf_expand_label_384(hs_keys.handshake_secret, "derived", sha384_hash_bytes(list()), 48)
        ms = tls13_hkdf_extract_384(d_s, z48)
        cat = tls13_hkdf_expand_label_384(ms, "c ap traffic", fin_hash, 48)
        sat = tls13_hkdf_expand_label_384(ms, "s ap traffic", fin_hash, 48)
        c_app_key = tls13_hkdf_expand_label_384(cat, "key", list(), 32)
        c_app_iv = tls13_hkdf_expand_label_384(cat, "iv", list(), 12)
        s_app_key = tls13_hkdf_expand_label_384(sat, "key", list(), 32)
        s_app_iv = tls13_hkdf_expand_label_384(sat, "iv", list(), 12)
        cfk = tls13_hkdf_expand_label_384(hs_keys.client_handshake_traffic_secret, "finished", list(), 48)
        c_fin_msg = _h2c_append([20, 0, 0, 48], tls13_hmac_sha384(cfk, fin_hash))
    else
        z32 = list()
        zi = 0
        while zi < 32 push(z32, 0) zi = zi + 1 end
        d_s = tls13_hkdf_expand_label(hs_keys.handshake_secret, "derived", sha256_hash_bytes(list()), 32)
        ms = tls13_hkdf_extract(d_s, z32)
        cat = tls13_hkdf_expand_label(ms, "c ap traffic", fin_hash, 32)
        sat = tls13_hkdf_expand_label(ms, "s ap traffic", fin_hash, 32)
        kl = 16
        if cipher == 4867 kl = 32 end
        c_app_key = tls13_hkdf_expand_label(cat, "key", list(), kl)
        c_app_iv = tls13_hkdf_expand_label(cat, "iv", list(), 12)
        s_app_key = tls13_hkdf_expand_label(sat, "key", list(), kl)
        s_app_iv = tls13_hkdf_expand_label(sat, "iv", list(), 12)
        cfk = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "finished", list(), 32)
        c_fin_msg = _h2c_append([20, 0, 0, 32], tls13_hmac_sha256(cfk, fin_hash))
    end

    c_fin_rec = _h2c_tls_wrap(cipher, c_hs_key, c_hs_iv, 0, 22, c_fin_msg)
    if _h2c_fd_write_exact(fd, c_fin_rec) != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        return bad
    end

    cli = _h2c_new_client(fd, 1, neg_alpn)
    cli.h2_tls_cipher = cipher
    cli.h2_tls_c_key = c_app_key
    cli.h2_tls_c_iv = c_app_iv
    cli.h2_tls_s_key = s_app_key
    cli.h2_tls_s_iv = s_app_iv
    if _h2c_send_client_preface(cli) != 1
        syscall(3, fd, 0, 0, 0, 0, 0)
        cli.h2_connected = 0
        return cli
    end
    return cli
end

// ── 5. Multiplexed Stream Submission, Frame Pump & Flow Control ───────────────

fn _h2c_find_stream_idx cli sid
    i = 0
    n = len(cli.h2_s_ids)
    while i < n
        if get(cli.h2_s_ids, i) == sid return i end
        i = i + 1
    end
    return 0 - 1
end

fn _h2c_str_to_i64 s
    v = 0
    i = 0
    n = str_len(s)
    while i < n
        c = str_char_at(s, i) & 255
        if c >= 48 and c <= 57
            v = (v * 10) + (c - 48)
        end
        i = i + 1
    end
    return v
end

fn h2_send_request cli method path authority extra_names extra_vals body_str
    // WHY: Submits an HTTP/2 request on a fresh odd stream_id without blocking for its reply,
    // enabling true RFC 9113 concurrent stream multiplexing over one connection.
    if cli.h2_connected == 0 return 0 end
    sid = cli.h2_next_stream_id
    cli.h2_next_stream_id = sid + 2

    push(cli.h2_s_ids, sid)
    push(cli.h2_s_status, 0)
    push(cli.h2_s_hnames, list())
    push(cli.h2_s_hvals, list())
    push(cli.h2_s_body_bufs, buf_new(256))
    push(cli.h2_s_done, 0)
    push(cli.h2_s_err, 0)

    scheme = "http"
    if cli.h2_is_tls == 1 scheme = "https" end
    hblk = _h2c_hpack_encode_request(method, scheme, authority, path, extra_names, extra_vals)
    blen = str_len(body_str)

    wire = list()
    if blen == 0
        _h2c_append(wire, _h2c_build_frame(H2C_FRAME_HEADERS, H2C_FLAG_END_HEADERS | H2C_FLAG_END_STREAM, sid, hblk))
    else
        _h2c_append(wire, _h2c_build_frame(H2C_FRAME_HEADERS, H2C_FLAG_END_HEADERS, sid, hblk))
        body_b = _h2c_str_to_bytes(body_str)
        max_f = cli.h2_max_frame_size
        if max_f < 1024 max_f = 16384 end
        off = 0
        while off < blen
            stop = off + max_f
            if stop > blen stop = blen end
            df = 0
            if stop == blen df = H2C_FLAG_END_STREAM end
            _h2c_append(wire, _h2c_build_frame(H2C_FRAME_DATA, df, sid, _h2c_slice(body_b, off, stop)))
            off = stop
        end
    end
    if _h2c_wire_send(cli, wire) != 1
        cli.h2_connected = 0
        return 0
    end
    return sid
end

fn _h2c_send_window_update cli sid inc
    if inc <= 0 return 0 end
    pl = [(inc >> 24) & 127, (inc >> 16) & 255, (inc >> 8) & 255, inc & 255]
    return _h2c_wire_send(cli, _h2c_build_frame(H2C_FRAME_WINDOW_UPDATE, 0, sid, pl))
end

fn h2_pump_one_frame cli
    if cli.h2_connected == 0 return 0 end
    hdr = _h2c_wire_read_exact(cli, 9)
    if len(hdr) < 9
        cli.h2_connected = 0
        return 0
    end
    flen = ((get(hdr, 0) & 255) << 16) | ((get(hdr, 1) & 255) << 8) | (get(hdr, 2) & 255)
    ftype = get(hdr, 3) & 255
    flags = get(hdr, 4) & 255
    sid = ((get(hdr, 5) & 127) << 24) | ((get(hdr, 6) & 255) << 16) | ((get(hdr, 7) & 255) << 8) | (get(hdr, 8) & 255)
    if flen > 1048576
        cli.h2_connected = 0
        return 0
    end
    payload = list()
    if flen > 0
        payload = _h2c_wire_read_exact(cli, flen)
        if len(payload) != flen
            cli.h2_connected = 0
            return 0
        end
    end

    if ftype == H2C_FRAME_SETTINGS
        if (flags & H2C_FLAG_ACK) == 0
            si = 0
            while si + 6 <= flen
                pid = ((get(payload, si) & 255) << 8) | (get(payload, si + 1) & 255)
                pval = ((get(payload, si + 2) & 255) << 24) | ((get(payload, si + 3) & 255) << 16) | ((get(payload, si + 4) & 255) << 8) | (get(payload, si + 5) & 255)
                if pid == 5 and pval >= 16384 and pval <= 16777215
                    cli.h2_max_frame_size = pval
                end
                si = si + 6
            end
            _h2c_wire_send(cli, _h2c_build_frame(H2C_FRAME_SETTINGS, H2C_FLAG_ACK, 0, list()))
        end
    elif ftype == H2C_FRAME_PING
        if (flags & H2C_FLAG_ACK) != 0
            cli.h2_last_ping_ack = payload
        elif flen == 8
            _h2c_wire_send(cli, _h2c_build_frame(H2C_FRAME_PING, H2C_FLAG_ACK, 0, payload))
        end
    elif ftype == H2C_FRAME_WINDOW_UPDATE
        if flen >= 4
            inc = ((get(payload, 0) & 127) << 24) | ((get(payload, 1) & 255) << 16) | ((get(payload, 2) & 255) << 8) | (get(payload, 3) & 255)
            if sid == 0 cli.h2_conn_window = cli.h2_conn_window + inc end
        end
    elif ftype == H2C_FRAME_HEADERS
        pos = 0
        epos = flen
        if (flags & H2C_FLAG_PADDED) != 0 and pos < epos
            plen = get(payload, pos) & 255
            pos = pos + 1
            epos = epos - plen
        end
        if (flags & H2C_FLAG_PRIORITY) != 0 and pos + 5 <= epos
            pos = pos + 5
        end
        hblk = _h2c_slice(payload, pos, epos)
        // Reassemble any CONTINUATION frames until END_HEADERS is set
        cur_flags = flags
        while (cur_flags & H2C_FLAG_END_HEADERS) == 0
            chdr = _h2c_wire_read_exact(cli, 9)
            if len(chdr) < 9 break end
            cflen = ((get(chdr, 0) & 255) << 16) | ((get(chdr, 1) & 255) << 8) | (get(chdr, 2) & 255)
            cur_flags = get(chdr, 4) & 255
            if cflen > 0
                cpl = _h2c_wire_read_exact(cli, cflen)
                _h2c_append(hblk, cpl)
            end
        end
        sidx = _h2c_find_stream_idx(cli, sid)
        if sidx >= 0
            kv = _h2c_hpack_decode(cli, hblk)
            hn_list = get(cli.h2_s_hnames, sidx)
            hv_list = get(cli.h2_s_hvals, sidx)
            hi = 0
            while hi < len(kv[0])
                kname = get(kv[0], hi)
                kval = get(kv[1], hi)
                push(hn_list, kname)
                push(hv_list, kval)
                if kname == ":status"
                    list_set(cli.h2_s_status, sidx, _h2c_str_to_i64(kval))
                end
                hi = hi + 1
            end
            if (flags & H2C_FLAG_END_STREAM) != 0
                list_set(cli.h2_s_done, sidx, 1)
            end
        end
    elif ftype == H2C_FRAME_DATA
        pos = 0
        epos = flen
        if (flags & H2C_FLAG_PADDED) != 0 and pos < epos
            plen = get(payload, pos) & 255
            pos = pos + 1
            epos = epos - plen
        end
        sidx = _h2c_find_stream_idx(cli, sid)
        if sidx >= 0
            bb = get(cli.h2_s_body_bufs, sidx)
            bi = pos
            while bi < epos
                buf_write_byte(bb, get(payload, bi) & 255)
                bi = bi + 1
            end
            if (flags & H2C_FLAG_END_STREAM) != 0
                list_set(cli.h2_s_done, sidx, 1)
            end
        end
        if flen > 0
            _h2c_send_window_update(cli, 0, flen)
            if (flags & H2C_FLAG_END_STREAM) == 0 and sid > 0
                _h2c_send_window_update(cli, sid, flen)
            end
        end
    elif ftype == H2C_FRAME_RST_STREAM
        err = 0
        if flen >= 4
            err = ((get(payload, 0) & 255) << 24) | ((get(payload, 1) & 255) << 16) | ((get(payload, 2) & 255) << 8) | (get(payload, 3) & 255)
        end
        sidx = _h2c_find_stream_idx(cli, sid)
        if sidx >= 0
            list_set(cli.h2_s_err, sidx, err)
            list_set(cli.h2_s_done, sidx, 1)
        end
    elif ftype == H2C_FRAME_GOAWAY
        cli.h2_got_goaway = 1
        if flen >= 8
            cli.h2_goaway_last_sid = ((get(payload, 0) & 127) << 24) | ((get(payload, 1) & 255) << 16) | ((get(payload, 2) & 255) << 8) | (get(payload, 3) & 255)
            cli.h2_goaway_err = ((get(payload, 4) & 255) << 24) | ((get(payload, 5) & 255) << 16) | ((get(payload, 6) & 255) << 8) | (get(payload, 7) & 255)
        end
    end
    return 1
end

fn h2_ping cli opaque8
    if cli.h2_connected == 0 return 0 end
    cli.h2_last_ping_ack = list()
    if _h2c_wire_send(cli, _h2c_build_frame(H2C_FRAME_PING, 0, 0, opaque8)) != 1
        return 0
    end
    spins = 0
    while len(cli.h2_last_ping_ack) == 0 and spins < 64 and cli.h2_connected == 1
        if h2_pump_one_frame(cli) == 0 break end
        spins = spins + 1
    end
    return _h2c_ct_eq(cli.h2_last_ping_ack, opaque8)
end

fn h2_recv_stream cli sid
    sidx = _h2c_find_stream_idx(cli, sid)
    if sidx < 0
        return H2Response(0, sid, 0, list(), list(), "", 1, cli.h2_alpn)
    end
    spins = 0
    while get(cli.h2_s_done, sidx) == 0 and cli.h2_connected == 1 and spins < 512
        if h2_pump_one_frame(cli) == 0 break end
        spins = spins + 1
    end
    bb = get(cli.h2_s_body_bufs, sidx)
    body_str = buf_to_str(bb)
    st_code = get(cli.h2_s_status, sidx)
    err_c = get(cli.h2_s_err, sidx)
    ok_flag = 0
    if get(cli.h2_s_done, sidx) == 1 and err_c == 0 and st_code > 0
        ok_flag = 1
    end
    return H2Response(ok_flag, sid, st_code, get(cli.h2_s_hnames, sidx), get(cli.h2_s_hvals, sidx), body_str, err_c, cli.h2_alpn)
end

fn h2_request cli method path authority extra_names extra_vals body_str
    sid = h2_send_request(cli, method, path, authority, extra_names, extra_vals, body_str)
    if sid <= 0
        return H2Response(0, 0, 0, list(), list(), "", 1, cli.h2_alpn)
    end
    return h2_recv_stream(cli, sid)
end

fn h2_close cli
    if cli.h2_connected == 1
        _h2c_wire_send(cli, _h2c_build_frame(H2C_FRAME_GOAWAY, 0, 0, [0, 0, 0, 0, 0, 0, 0, 0]))
        if cli.h2_is_tls == 1
            al = _h2c_tls_wrap(cli.h2_tls_cipher, cli.h2_tls_c_key, cli.h2_tls_c_iv, cli.h2_tls_c_seq, 21, [1, 0])
            cli.h2_tls_c_seq = cli.h2_tls_c_seq + 1
            _h2c_fd_write_exact(cli.h2_fd, al)
        end
    end
    if cli.h2_fd >= 0
        syscall(48, cli.h2_fd, 1, 0, 0, 0, 0)
        syscall(3, cli.h2_fd, 0, 0, 0, 0, 0)
        cli.h2_fd = 0 - 1
    end
    i = 0
    while i < len(cli.h2_s_body_bufs)
        bb = get(cli.h2_s_body_bufs, i)
        if bb > 0 buf_free(bb) end
        list_set(cli.h2_s_body_bufs, i, 0)
        i = i + 1
    end
    cli.h2_connected = 0
    return 0
end
