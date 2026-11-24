// ==============================================================================
// 👑 LIPI SOVEREIGN HTTP/1.1 & HTTPS TLS 1.3 CLIENT (aati/lipi_http_client/src/http_client.lp)
// ⚡ Zero Libc | Zero cURL | Zero OpenSSL | Dynamic Multi-MB Buffering + DNS + TLS 1.3
// ==============================================================================
//
// WHY: Enterprise microservices, webhook dispatchers, and sovereign clients require
// real HTTP/1.1 & HTTPS TLS 1.3 over raw kernel syscalls with zero arbitrary buffer
// caps, chunked decoding, pure-Lipi DNS resolution, and full PKI verification.

include "utso/memory.lp"
import "utso/net/tls/tls13"

// Syscall constants
HTTP_SYS_READ     = 0
HTTP_SYS_WRITE    = 1
HTTP_SYS_CLOSE    = 3
HTTP_SYS_OPEN     = 2
HTTP_SYS_LSEEK    = 8
HTTP_SYS_SOCKET   = 41
HTTP_SYS_CONNECT  = 42
HTTP_SYS_SENDTO   = 44
HTTP_SYS_RECVFROM = 45
HTTP_SYS_SETSOCKOPT = 54

HTTP_MAX_RESP_BYTES = 16777216

// Response Descriptor (48 bytes)
// Offset 0:  status_code (i64, e.g. 200, 404)
// Offset 8:  body_offset (i64)
// Offset 16: body_len (i64)
// Offset 24: raw_buf (i64 pointer)
// Offset 32: raw_len (i64 total response bytes read)
// Offset 40: capacity (i64 buffer capacity)

fn http_parse_status_code buf buf_len
    if buf == 0
        return 0
    if buf_len < 12
        return 0

    idx = 0
    while idx + 3 < buf_len
        if mem_byte_read(buf, idx) == 32
            d0 = mem_byte_read(buf, idx + 1) - 48
            d1 = mem_byte_read(buf, idx + 2) - 48
            d2 = mem_byte_read(buf, idx + 3) - 48
            if d0 >= 0 and d0 <= 9 and d1 >= 0 and d1 <= 9 and d2 >= 0 and d2 <= 9
                return (d0 * 100) + (d1 * 10) + d2
        idx = idx + 1
    return 0

fn http_find_body_offset buf buf_len
    if buf == 0
        return 0
    if buf_len < 4
        return 0

    limit = buf_len - 3
    i = 0
    while i < limit
        if mem_byte_read(buf, i) == 13 and mem_byte_read(buf, i + 1) == 10 and mem_byte_read(buf, i + 2) == 13 and mem_byte_read(buf, i + 3) == 10
            return i + 4
        i = i + 1
    return 0

fn _hc_lower_ascii c
    if c >= 65 and c <= 90
        return c + 32
    return c

fn _hc_hdr_line_eq buf pos limit pat
    plen = str_len(pat)
    if pos + plen > limit
        return 0
    k = 0
    while k < plen
        if _hc_lower_ascii(mem_byte_read(buf, pos + k) & 255) != _hc_lower_ascii(str_char_at(pat, k) & 255)
            return 0
        k = k + 1
    return 1

fn _hc_parse_headers_framing buf body_off
    // Returns [content_length (-1 if none), is_chunked (0/1)]
    clen = -1
    chunked = 0
    hdr_end = body_off - 2
    if hdr_end < 0
        return [clen, chunked]
    pos = 0
    while pos < hdr_end
        eol = pos
        while eol < hdr_end
            if mem_byte_read(buf, eol) == 13 and eol + 1 < hdr_end and mem_byte_read(buf, eol + 1) == 10
                break
            eol = eol + 1
        if _hc_hdr_line_eq(buf, pos, eol, "content-length:") == 1
            vp = pos + 15
            while vp < eol and (mem_byte_read(buf, vp) == 32 or mem_byte_read(buf, vp) == 9)
                vp = vp + 1
            v = 0
            has_d = 0
            while vp < eol
                ch = mem_byte_read(buf, vp) & 255
                if ch >= 48 and ch <= 57
                    v = (v * 10) + (ch - 48)
                    has_d = 1
                else
                    break
                vp = vp + 1
            if has_d == 1
                clen = v
        elif _hc_hdr_line_eq(buf, pos, eol, "transfer-encoding:") == 1
            sp = pos + 18
            while sp + 7 <= eol
                if _hc_hdr_line_eq(buf, sp, eol, "chunked") == 1
                    chunked = 1
                    break
                sp = sp + 1
        pos = eol + 2
    return [clen, chunked]

fn _hc_hex_val c
    if c >= 48 and c <= 57 return c - 48
    if c >= 97 and c <= 102 return c - 87
    if c >= 65 and c <= 70 return c - 55
    return -1

fn _hc_is_chunked_complete buf body_off total_len
    src = body_off
    while src < total_len
        line_end = -1
        p = src
        while p + 1 < total_len
            if mem_byte_read(buf, p) == 13 and mem_byte_read(buf, p + 1) == 10
                line_end = p
                break
            p = p + 1
        if line_end < 0 return 0
        csz = 0
        got_hex = 0
        hi = src
        while hi < line_end
            ch = mem_byte_read(buf, hi) & 255
            if ch == 59 break
            hv = _hc_hex_val(ch)
            if hv >= 0
                csz = (csz * 16) + hv
                got_hex = 1
            elif ch != 32 and ch != 9
                return 0
            hi = hi + 1
        if got_hex == 0 return 0
        src = line_end + 2
        if csz == 0
            if src + 2 <= total_len return 1
            return 0
        if src + csz + 2 > total_len return 0
        src = src + csz + 2
    return 0

fn http_client_decode_chunked_raw buf body_off total_len
    // Decodes HTTP/1.1 Transfer-Encoding: chunked body in-place starting at body_off.
    // Returns decoded body_len (>= 0), or -1 if incomplete chunk stream.
    src = body_off
    dst = body_off
    while src < total_len
        // Read chunk size hex line ending in \r\n
        line_end = -1
        p = src
        while p + 1 < total_len
            if mem_byte_read(buf, p) == 13 and mem_byte_read(buf, p + 1) == 10
                line_end = p
                break
            p = p + 1
        if line_end < 0
            return -1
        csz = 0
        got_hex = 0
        hi = src
        while hi < line_end
            ch = mem_byte_read(buf, hi) & 255
            if ch == 59 // ';' chunk extension
                break
            hv = _hc_hex_val(ch)
            if hv >= 0
                csz = (csz * 16) + hv
                got_hex = 1
            elif ch != 32 and ch != 9
                return -1
            hi = hi + 1
        if got_hex == 0
            return -1
        src = line_end + 2
        if csz == 0
            // Expect trailing \r\n (or trailers + \r\n)
            if src + 2 <= total_len
                return dst - body_off
            return -1
        if src + csz + 2 > total_len
            return -1
        k = 0
        while k < csz
            mem_byte_write(buf, dst + k, mem_byte_read(buf, src + k) & 255)
            k = k + 1
        dst = dst + csz
        src = src + csz + 2
    return -1

fn http_parse_response raw_buf raw_len
    if raw_buf == 0
        return 0
    if raw_len <= 0
        return 0

    status = http_parse_status_code(raw_buf, raw_len)
    body_off = http_find_body_offset(raw_buf, raw_len)

    body_len = 0
    if body_off > 0 and raw_len >= body_off
        framing = _hc_parse_headers_framing(raw_buf, body_off)
        clen = framing[0]
        is_chunked = framing[1]
        if is_chunked == 1
            dlen = http_client_decode_chunked_raw(raw_buf, body_off, raw_len)
            if dlen >= 0
                body_len = dlen
            else
                body_len = raw_len - body_off
        elif clen >= 0 and (body_off + clen) <= raw_len
            body_len = clen
        else
            body_len = raw_len - body_off

    res = sys_alloc(48)
    mem_write(res, 0, status)
    mem_write(res, 8, body_off)
    mem_write(res, 16, body_len)
    mem_write(res, 24, raw_buf)
    mem_write(res, 32, raw_len)
    mem_write(res, 40, raw_len)
    return res

fn http_response_status res
    if res == 0
        return 0
    return mem_read(res, 0)

fn http_response_body_len res
    if res == 0
        return 0
    return mem_read(res, 16)

fn http_response_body_ptr res
    if res == 0
        return 0
    raw_buf = mem_read(res, 24)
    body_off = mem_read(res, 8)
    return raw_buf + body_off

fn http_response_free res
    if res == 0
        return 0
    raw_buf = mem_read(res, 24)
    cap = mem_read(res, 40)
    if raw_buf > 0 and cap > 0
        sys_free(raw_buf)
    sys_free(res)
    return 0

fn _hc_write_all fd buf total_len
    sent = 0
    while sent < total_len
        n = syscall(HTTP_SYS_WRITE, fd, buf + sent, total_len - sent, 0, 0, 0)
        if n <= 0
            return -1
        sent = sent + n
    return sent

fn _hc_set_socket_timeout fd secs
    tv = sys_alloc(16)
    mem_write(tv, 0, secs)
    mem_write(tv, 8, 0)
    syscall(HTTP_SYS_SETSOCKOPT, fd, 1, 20, tv, 16, 0)
    syscall(HTTP_SYS_SETSOCKOPT, fd, 1, 21, tv, 16, 0)
    sys_free(tv)
    return 0

fn _hc_connect_ipv4 ip0 ip1 ip2 ip3 port sock_type proto
    fd = syscall(HTTP_SYS_SOCKET, 2, sock_type, proto, 0, 0, 0)
    if fd < 0
        return -1
    _hc_set_socket_timeout(fd, 5)
    addr = sys_alloc(16)
    mem_zero(addr, 16)
    mem_byte_write(addr, 0, 2)
    mem_byte_write(addr, 2, (port / 256) & 255)
    mem_byte_write(addr, 3, port & 255)
    mem_byte_write(addr, 4, ip0 & 255)
    mem_byte_write(addr, 5, ip1 & 255)
    mem_byte_write(addr, 6, ip2 & 255)
    mem_byte_write(addr, 7, ip3 & 255)
    c_res = syscall(HTTP_SYS_CONNECT, fd, addr, 16, 0, 0, 0)
    sys_free(addr)
    if c_res < 0
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return -1
    return fd

// Client Networking: connect to IP, stream full response in dynamically growing buffer (>8KB safe)
fn http_client_execute ip0 ip1 ip2 ip3 port req_buf req_len
    fd = _hc_connect_ipv4(ip0, ip1, ip2, ip3, port, 1, 0)
    if fd < 0
        return 0

    if _hc_write_all(fd, req_buf, req_len) < 0
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    cap = 16384
    resp_buf = sys_alloc(cap)
    mem_zero(resp_buf, cap)
    total = 0

    while total < HTTP_MAX_RESP_BYTES
        if (cap - total) < 4096
            new_cap = cap * 2
            if new_cap > HTTP_MAX_RESP_BYTES
                new_cap = HTTP_MAX_RESP_BYTES
            if new_cap <= cap
                break
            nbuf = sys_alloc(new_cap)
            if nbuf <= 0
                break
            mem_zero(nbuf, new_cap)
            mem_copy(nbuf, resp_buf, total)
            sys_free(resp_buf)
            resp_buf = nbuf
            cap = new_cap

        n = syscall(HTTP_SYS_READ, fd, resp_buf + total, cap - total, 0, 0, 0)
        if n <= 0
            break
        total = total + n

        boff = http_find_body_offset(resp_buf, total)
        if boff > 0
            fr = _hc_parse_headers_framing(resp_buf, boff)
            cl = fr[0]
            chk = fr[1]
            if chk == 1
                if _hc_is_chunked_complete(resp_buf, boff, total) == 1
                    break
            elif cl >= 0 and total >= (boff + cl)
                break

    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    if total <= 0
        sys_free(resp_buf)
        return 0

    // Note: chunked decoding inside http_parse_response handles final buffer layout; re-wrap cleanly
    status = http_parse_status_code(resp_buf, total)
    body_off = http_find_body_offset(resp_buf, total)
    body_len = 0
    if body_off > 0 and total >= body_off
        fr2 = _hc_parse_headers_framing(resp_buf, body_off)
        if fr2[1] == 1
            dlen = http_client_decode_chunked_raw(resp_buf, body_off, total)
            if dlen >= 0
                body_len = dlen
            else
                body_len = total - body_off
        elif fr2[0] >= 0 and (body_off + fr2[0]) <= total
            body_len = fr2[0]
        else
            body_len = total - body_off

    res = sys_alloc(48)
    mem_write(res, 0, status)
    mem_write(res, 8, body_off)
    mem_write(res, 16, body_len)
    mem_write(res, 24, resp_buf)
    mem_write(res, 32, total)
    mem_write(res, 40, cap)
    return res

// ── Sovereign Pure-Lipi IPv4 / /etc/hosts / RFC 1035 UDP DNS & HTTPS Client ───

fn http_client_parse_ipv4 host_str
    hlen = str_len(host_str)
    if hlen == 0
        return []
    parts = [0, 0, 0, 0]
    pidx = 0
    cur = 0
    has_d = 0
    i = 0
    while i < hlen
        c = str_char_at(host_str, i) & 255
        if c >= 48 and c <= 57
            cur = (cur * 10) + (c - 48)
            has_d = 1
            if cur > 255 return []
        elif c == 46
            if has_d == 0 or pidx >= 3 return []
            parts[pidx] = cur
            pidx = pidx + 1
            cur = 0
            has_d = 0
        else
            return []
        i = i + 1
    if has_d == 0 or pidx != 3
        return []
    parts[3] = cur
    return parts

fn _hc_read_file_text path max_sz
    fd = syscall(HTTP_SYS_OPEN, path, 0, 0, 0, 0, 0)
    if fd < 0 return ""
    buf = sys_alloc(max_sz)
    n = syscall(HTTP_SYS_READ, fd, buf, max_sz, 0, 0, 0)
    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    out = ""
    i = 0
    while i < n
        out = out + chr(mem_byte_read(buf, i) & 255)
        i = i + 1
    sys_free(buf)
    return out

fn _hc_lookup_etc_hosts host_str
    if host_str == "localhost" or host_str == "127.0.0.1"
        return [127, 0, 0, 1]
    txt = _hc_read_file_text("/etc/hosts", 16384)
    if str_len(txt) == 0 return []
    tlen = str_len(txt)
    pos = 0
    while pos < tlen
        eol = pos
        while eol < tlen and str_char_at(txt, eol) != 10
            eol = eol + 1
        line = str_sub(txt, pos, eol)
        pos = eol + 1
        // Strip comments & parse first IPv4 token + aliases
        toks = []
        cur = ""
        li = 0
        llen = str_len(line)
        while li < llen
            ch = str_char_at(line, li) & 255
            if ch == 35
                break
            if ch == 32 or ch == 9 or ch == 13
                if str_len(cur) > 0
                    toks = toks.push(cur)
                    cur = ""
            else
                cur = cur + chr(ch)
            li = li + 1
        if str_len(cur) > 0
            toks = toks.push(cur)
        if toks.len() >= 2
            ip4 = http_client_parse_ipv4(toks[0])
            if ip4.len() == 4
                ti = 1
                while ti < toks.len()
                    if toks[ti] == host_str
                        return ip4
                    ti = ti + 1
    return []

fn _hc_first_nameserver()
    txt = _hc_read_file_text("/etc/resolv.conf", 4096)
    tlen = str_len(txt)
    pos = 0
    while pos < tlen
        eol = pos
        while eol < tlen and str_char_at(txt, eol) != 10
            eol = eol + 1
        line = str_sub(txt, pos, eol)
        pos = eol + 1
        if str_starts_with(line, "nameserver ") == 1
            cand = str_trim(str_sub(line, 11, str_len(line)))
            ip4 = http_client_parse_ipv4(cand)
            if ip4.len() == 4 and ip4[0] != 127
                return ip4
    return [1, 1, 1, 1]

fn _hc_dns_skip_name buf n off
    p = off
    while p < n
        l = mem_byte_read(buf, p) & 255
        if l == 0
            return p + 1
        if (l & 192) == 192
            return p + 2
        p = p + 1 + l
    return n

fn http_client_resolve_host_ipv4 host_str
    ip4 = http_client_parse_ipv4(host_str)
    if ip4.len() == 4 return ip4
    hosts_ip = _hc_lookup_etc_hosts(host_str)
    if hosts_ip.len() == 4 return hosts_ip

    // RFC 1035 UDP DNS A-record query directly via SYS_sendto / SYS_recvfrom
    ns = _hc_first_nameserver()
    fd = syscall(HTTP_SYS_SOCKET, 2, 2, 17, 0, 0, 0)
    if fd < 0 return []
    _hc_set_socket_timeout(fd, 3)

    pkt = sys_alloc(512)
    mem_zero(pkt, 512)
    mem_byte_write(pkt, 0, 76)  // ID hi
    mem_byte_write(pkt, 1, 80)  // ID lo ("LP")
    mem_byte_write(pkt, 2, 1)   // RD = 1
    mem_byte_write(pkt, 5, 1)   // QDCOUNT = 1

    w = 12
    lbl_start = 0
    hlen = str_len(host_str)
    i = 0
    while i <= hlen
        ch = 46
        if i < hlen ch = str_char_at(host_str, i) & 255
        if ch == 46
            lbl_len = i - lbl_start
            if lbl_len > 0 and w + 1 + lbl_len < 480
                mem_byte_write(pkt, w, lbl_len & 63)
                w = w + 1
                j = 0
                while j < lbl_len
                    mem_byte_write(pkt, w, str_char_at(host_str, lbl_start + j) & 255)
                    w = w + 1
                    j = j + 1
            lbl_start = i + 1
        i = i + 1
    mem_byte_write(pkt, w, 0)
    w = w + 1
    mem_byte_write(pkt, w, 0)
    mem_byte_write(pkt, w + 1, 1) // QTYPE = A
    mem_byte_write(pkt, w + 2, 0)
    mem_byte_write(pkt, w + 3, 1) // QCLASS = IN
    w = w + 4

    addr = sys_alloc(16)
    mem_zero(addr, 16)
    mem_byte_write(addr, 0, 2)
    mem_byte_write(addr, 2, 0)
    mem_byte_write(addr, 3, 53)
    mem_byte_write(addr, 4, ns[0])
    mem_byte_write(addr, 5, ns[1])
    mem_byte_write(addr, 6, ns[2])
    mem_byte_write(addr, 7, ns[3])

    syscall(HTTP_SYS_SENDTO, fd, pkt, w, 0, addr, 16)
    resp = sys_alloc(1024)
    n = syscall(HTTP_SYS_RECVFROM, fd, resp, 1024, 0, 0, 0)
    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    sys_free(addr)
    sys_free(pkt)

    if n < 12
        sys_free(resp)
        return []
    qd = ((mem_byte_read(resp, 4) & 255) * 256) | (mem_byte_read(resp, 5) & 255)
    an = ((mem_byte_read(resp, 6) & 255) * 256) | (mem_byte_read(resp, 7) & 255)
    pos = 12
    qi = 0
    while qi < qd and pos < n
        pos = _hc_dns_skip_name(resp, n, pos) + 4
        qi = qi + 1
    ai = 0
    out_ip = []
    while ai < an and pos + 10 < n
        pos = _hc_dns_skip_name(resp, n, pos)
        if pos + 10 > n break
        rtype = ((mem_byte_read(resp, pos) & 255) * 256) | (mem_byte_read(resp, pos + 1) & 255)
        rdlen = ((mem_byte_read(resp, pos + 8) & 255) * 256) | (mem_byte_read(resp, pos + 9) & 255)
        pos = pos + 10
        if pos + rdlen > n break
        if rtype == 1 and rdlen == 4
            out_ip = [
                mem_byte_read(resp, pos) & 255,
                mem_byte_read(resp, pos + 1) & 255,
                mem_byte_read(resp, pos + 2) & 255,
                mem_byte_read(resp, pos + 3) & 255
            ]
            break
        pos = pos + rdlen
        ai = ai + 1
    sys_free(resp)
    return out_ip

fn _hc_tls_read_exact fd buf_ptr need
    got = 0
    while got < need
        n = syscall(HTTP_SYS_READ, fd, buf_ptr + got, need - got, 0, 0, 0)
        if n <= 0 return -1
        got = got + n
    return got

fn _hc_tls_write_arr fd arr
    n = arr.len()
    if n == 0 return 0
    buf = sys_alloc(n)
    i = 0
    while i < n
        mem_byte_write(buf, i, arr[i] & 255)
        i = i + 1
    r = _hc_write_all(fd, buf, n)
    sys_free(buf)
    return r

fn _hc_tls_read_rec fd
    hdr_buf = sys_alloc(8)
    if _hc_tls_read_exact(fd, hdr_buf, 5) != 5
        sys_free(hdr_buf)
        return [0, 0, [], []]
    rtype = mem_byte_read(hdr_buf, 0) & 255
    hdr = [
        rtype,
        mem_byte_read(hdr_buf, 1) & 255,
        mem_byte_read(hdr_buf, 2) & 255,
        mem_byte_read(hdr_buf, 3) & 255,
        mem_byte_read(hdr_buf, 4) & 255
    ]
    sys_free(hdr_buf)
    rlen = (hdr[3] * 256) | hdr[4]
    if rlen > 32768
        return [0, 0, [], []]
    body = []
    if rlen > 0
        rb = sys_alloc(rlen)
        if _hc_tls_read_exact(fd, rb, rlen) != rlen
            sys_free(rb)
            return [0, 0, [], []]
        i = 0
        while i < rlen
            body = body.push(mem_byte_read(rb, i) & 255)
            i = i + 1
        sys_free(rb)
    return [1, rtype, hdr, body]

fn _hc_tls_rand32()
    b = sys_alloc(32)
    r = syscall(318, b, 32, 0, 0, 0, 0)
    if r != 32
        sys_free(b)
        return []
    out = []
    i = 0
    while i < 32
        out = out.push(mem_byte_read(b, i) & 255)
        i = i + 1
    sys_free(b)
    return out

fn _hc_tls_nonce iv seq
    nonce = []
    i = 0
    while i < 12
        nonce = nonce.push(iv[i] & 255)
        i = i + 1
    i = 0
    while i < 8
        sb = (seq >> ((7 - i) * 8)) & 255
        nonce[4 + i] = (nonce[4 + i] ^ sb) & 255
        i = i + 1
    return nonce

fn _hc_tls_wrap cipher key iv seq inner_type pt_bytes
    inner = tls_append_bytes(pt_bytes, [inner_type & 255])
    enc_len = inner.len() + 16
    hdr = [23, 3, 3, (enc_len / 256) & 255, enc_len & 255]
    nonce = _hc_tls_nonce(iv, seq)
    ct = []
    if cipher == 4867
        ct = tls_chacha20_poly1305_encrypt_raw(key, nonce, inner, hdr)
    else
        ct = tls_aes_gcm_encrypt_raw(key, nonce, inner, hdr)
    return tls_append_bytes(hdr, ct)

fn _hc_tls_unwrap cipher key iv seq hdr body
    nonce = _hc_tls_nonce(iv, seq)
    pt = []
    if cipher == 4867
        pt = tls_chacha20_poly1305_decrypt_raw(key, nonce, body, hdr)
    else
        pt = tls_aes_gcm_decrypt_raw(key, nonce, body, hdr)
    if pt.len() == 0 return [0, 0, []]
    end_idx = pt.len() - 1
    while end_idx >= 0 and pt[end_idx] == 0
        end_idx = end_idx - 1
    if end_idx < 0 return [0, 0, []]
    itype = pt[end_idx] & 255
    out = []
    i = 0
    while i < end_idx
        out = out.push(pt[i] & 255)
        i = i + 1
    return [1, itype, out]

fn _hc_tls_parse_sh sh_hs
    n = sh_hs.len()
    if n < 44 return [0, 0, []]
    sid_len = sh_hs[38] & 255
    pos = 39 + sid_len
    if pos + 5 > n return [0, 0, []]
    cipher = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
    pos = pos + 3
    ext_len = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
    pos = pos + 2
    ext_end = pos + ext_len
    if ext_end > n return [0, 0, []]
    pub = []
    is_tls13 = 0
    while pos + 4 <= ext_end
        et = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
        el = ((sh_hs[pos + 2] & 255) * 256) | (sh_hs[pos + 3] & 255)
        pos = pos + 4
        if pos + el > ext_end return [0, 0, []]
        if et == 43 and el == 2
            v = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
            if v == 772 is_tls13 = 1
        elif et == 51 and el >= 36
            grp = ((sh_hs[pos] & 255) * 256) | (sh_hs[pos + 1] & 255)
            klen = ((sh_hs[pos + 2] & 255) * 256) | (sh_hs[pos + 3] & 255)
            if grp == 29 and klen == 32 and pos + 4 + 32 <= ext_end
                i = 0
                while i < 32
                    pub = pub.push(sh_hs[pos + 4 + i] & 255)
                    i = i + 1
        pos = pos + el
    if is_tls13 == 0 or pub.len() != 32 return [0, 0, []]
    return [1, cipher, pub]

fn _hc_tls_extract_certs msg
    n = msg.len()
    if n < 12 return []
    ctx_len = msg[4] & 255
    pos = 5 + ctx_len
    if pos + 3 > n return []
    llen = ((msg[pos] & 255) * 65536) | ((msg[pos + 1] & 255) * 256) | (msg[pos + 2] & 255)
    pos = pos + 3
    lend = pos + llen
    if lend > n return []
    chain = []
    while pos + 5 <= lend
        clen = ((msg[pos] & 255) * 65536) | ((msg[pos + 1] & 255) * 256) | (msg[pos + 2] & 255)
        pos = pos + 3
        if clen <= 0 or pos + clen + 2 > lend return []
        der = []
        i = 0
        while i < clen
            der = der.push(msg[pos + i] & 255)
            i = i + 1
        chain = chain.push(der)
        pos = pos + clen
        ext_len = ((msg[pos] & 255) * 256) | (msg[pos + 1] & 255)
        pos = pos + 2 + ext_len
    return chain

fn _hc_https_execute ip0 ip1 ip2 ip3 port host req_str
    fd = _hc_connect_ipv4(ip0, ip1, ip2, ip3, port, 1, 0)
    if fd < 0 return 0

    c_priv = _hc_tls_rand32()
    if c_priv.len() != 32
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0
    c_pub = x25519_public_key(c_priv)
    ch = tls13_build_client_hello(host, c_pub)
    ch_hs = []
    i = 5
    while i < ch.wire_bytes.len()
        ch_hs = ch_hs.push(ch.wire_bytes[i])
        i = i + 1
    if _hc_tls_write_arr(fd, ch.wire_bytes) <= 0
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    sh_rec = _hc_tls_read_rec(fd)
    while sh_rec[0] == 1 and sh_rec[1] == 20
        sh_rec = _hc_tls_read_rec(fd)
    if sh_rec[0] != 1 or sh_rec[1] != 22
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0
    sh_hs = sh_rec[3]
    sh_info = _hc_tls_parse_sh(sh_hs)
    if sh_info[0] != 1
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0
    cipher = sh_info[1]
    shared = x25519_shared_secret(c_priv, sh_info[2])
    if shared.len() != 32
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    transcript = tls_append_bytes(ch_hs, sh_hs)
    thash1 = sha256_hash_bytes(transcript)
    hs_keys = 0
    if cipher == 4866
        thash1 = sha384_hash_bytes(transcript)
        hs_keys = tls13_derive_handshake_keys_384(shared, thash1)
    else
        hs_keys = tls13_derive_handshake_keys(shared, thash1)
        if cipher == 4867
            hs_keys.client_write_key = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "key", [], 32)
            hs_keys.server_write_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "key", [], 32)

    hs_buf = []
    s_hs_seq = 0
    got_fin = 0
    got_cert = 0
    got_cv = 0
    leaf_der = []
    steps = 0
    while got_fin == 0 and steps < 64
        steps = steps + 1
        rec = _hc_tls_read_rec(fd)
        if rec[0] != 1 break
        if rec[1] == 20 continue
        if rec[1] != 23 break
        unw = _hc_tls_unwrap(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, rec[2], rec[3])
        if unw[0] != 1 or unw[1] != 22 break
        s_hs_seq = s_hs_seq + 1
        hs_buf = tls_append_bytes(hs_buf, unw[2])

        pos = 0
        while pos + 4 <= hs_buf.len()
            ht = hs_buf[pos] & 255
            hl = ((hs_buf[pos + 1] & 255) * 65536) | ((hs_buf[pos + 2] & 255) * 256) | (hs_buf[pos + 3] & 255)
            if pos + 4 + hl > hs_buf.len() break
            msg = []
            mi = 0
            while mi < 4 + hl
                msg = msg.push(hs_buf[pos + mi])
                mi = mi + 1
            pos = pos + 4 + hl
            if ht == 11
                chain = _hc_tls_extract_certs(msg)
                if chain.len() == 0 or tls13_verify_x509_cert_chain_list(chain, host) != 1
                    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
                    return 0
                leaf_der = chain[0]
                got_cert = 1
            elif ht == 15
                if got_cert != 1 or msg.len() < 8
                    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
                    return 0
                sa = ((msg[4] & 255) * 256) | (msg[5] & 255)
                sl = ((msg[6] & 255) * 256) | (msg[7] & 255)
                sb = []
                si = 0
                while si < sl and 8 + si < msg.len()
                    sb = sb.push(msg[8 + si])
                    si = si + 1
                cv_h = sha256_hash_bytes(transcript)
                if cipher == 4866 cv_h = sha384_hash_bytes(transcript)
                if tls13_verify_certificate_verify(leaf_der, cv_h, sa, sb) != 1
                    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
                    return 0
                got_cv = 1
            elif ht == 20
                if got_cert != 1 or got_cv != 1
                    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
                    return 0
                transcript = tls_append_bytes(transcript, msg)
                got_fin = 1
                break
            transcript = tls_append_bytes(transcript, msg)
        rest = []
        ri = pos
        while ri < hs_buf.len()
            rest = rest.push(hs_buf[ri])
            ri = ri + 1
        hs_buf = rest

    if got_fin != 1
        syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
        return 0

    fin_h = sha256_hash_bytes(transcript)
    zero32 = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    c_app_key = []
    c_app_iv = []
    s_app_key = []
    s_app_iv = []
    if cipher == 4866
        fin_h = sha384_hash_bytes(transcript)
        z48 = []
        zi = 0
        while zi < 48
            z48 = z48.push(0)
            zi = zi + 1
        dhs = tls13_hkdf_expand_label_384(hs_keys.handshake_secret, "derived", sha384_hash_bytes([]), 48)
        m = tls13_hkdf_extract_384(dhs, z48)
        ca = tls13_hkdf_expand_label_384(m, "c ap traffic", fin_h, 48)
        sa_t = tls13_hkdf_expand_label_384(m, "s ap traffic", fin_h, 48)
        c_app_key = tls13_hkdf_expand_label_384(ca, "key", [], 32)
        c_app_iv = tls13_hkdf_expand_label_384(ca, "iv", [], 12)
        s_app_key = tls13_hkdf_expand_label_384(sa_t, "key", [], 32)
        s_app_iv = tls13_hkdf_expand_label_384(sa_t, "iv", [], 12)
        cfk = tls13_hkdf_expand_label_384(hs_keys.client_handshake_traffic_secret, "finished", [], 48)
        cfv = tls13_hmac_sha384(cfk, fin_h)
        cf_rec = _hc_tls_wrap(cipher, hs_keys.client_write_key, hs_keys.client_write_iv, 0, 22, tls_append_bytes([20, 0, 0, 48], cfv))
        _hc_tls_write_arr(fd, cf_rec)
    else
        dhs = tls13_hkdf_expand_label(hs_keys.handshake_secret, "derived", sha256_hash_bytes([]), 32)
        m = tls13_hkdf_extract(dhs, zero32)
        ca = tls13_hkdf_expand_label(m, "c ap traffic", fin_h, 32)
        sa_t = tls13_hkdf_expand_label(m, "s ap traffic", fin_h, 32)
        kl = 16
        if cipher == 4867 kl = 32
        c_app_key = tls13_hkdf_expand_label(ca, "key", [], kl)
        c_app_iv = tls13_hkdf_expand_label(ca, "iv", [], 12)
        s_app_key = tls13_hkdf_expand_label(sa_t, "key", [], kl)
        s_app_iv = tls13_hkdf_expand_label(sa_t, "iv", [], 12)
        cfk = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "finished", [], 32)
        cfv = tls13_hmac_sha256(cfk, fin_h)
        cf_rec = _hc_tls_wrap(cipher, hs_keys.client_write_key, hs_keys.client_write_iv, 0, 22, tls_append_bytes([20, 0, 0, 32], cfv))
        _hc_tls_write_arr(fd, cf_rec)

    req_bytes = tls_string_to_bytes(req_str)
    rlen = req_bytes.len()
    c_seq = 0
    roff = 0
    while roff < rlen or (roff == 0 and rlen == 0)
        rstop = roff + 16384
        if rstop > rlen rstop = rlen
        rchunk = []
        rki = roff
        while rki < rstop
            rchunk = rchunk.push(req_bytes[rki])
            rki = rki + 1
        req_rec = _hc_tls_wrap(cipher, c_app_key, c_app_iv, c_seq, 23, rchunk)
        _hc_tls_write_arr(fd, req_rec)
        c_seq = c_seq + 1
        roff = rstop
        if rlen == 0 break

    cap = 16384
    raw_buf = sys_alloc(cap)
    total = 0
    s_app_seq = 0
    while total < HTTP_MAX_RESP_BYTES
        rec = _hc_tls_read_rec(fd)
        if rec[0] != 1 break
        if rec[1] == 20 continue
        if rec[1] != 23 break
        unw = _hc_tls_unwrap(cipher, s_app_key, s_app_iv, s_app_seq, rec[2], rec[3])
        if unw[0] != 1 break
        s_app_seq = s_app_seq + 1
        if unw[1] == 21 break
        if unw[1] == 23
            pt = unw[2]
            while (cap - total) < pt.len() + 16
                new_cap = cap * 2
                if new_cap > HTTP_MAX_RESP_BYTES break
                nbuf = sys_alloc(new_cap)
                mem_copy(nbuf, raw_buf, total)
                sys_free(raw_buf)
                raw_buf = nbuf
                cap = new_cap
            pi = 0
            while pi < pt.len() and total < cap
                mem_byte_write(raw_buf, total, pt[pi] & 255)
                total = total + 1
                pi = pi + 1
            boff = http_find_body_offset(raw_buf, total)
            if boff > 0
                fr = _hc_parse_headers_framing(raw_buf, boff)
                if fr[1] == 1 and _hc_is_chunked_complete(raw_buf, boff, total) == 1
                    break
                elif fr[0] >= 0 and total >= (boff + fr[0])
                    break
    syscall(HTTP_SYS_CLOSE, fd, 0, 0, 0, 0, 0)
    if total <= 0
        sys_free(raw_buf)
        return 0
    rdesc = http_parse_response(raw_buf, total)
    if rdesc > 0
        mem_write(rdesc, 40, cap)
    return rdesc

fn http_client_get_url url_str
    // Sovereign URL client supporting both http:// and https:// with DNS resolution + full TLS 1.3 PKI
    is_tls = 0
    port = 80
    rest = url_str
    if str_starts_with(url_str, "https://") == 1
        is_tls = 1
        port = 443
        rest = str_sub(url_str, 8, str_len(url_str))
    elif str_starts_with(url_str, "http://") == 1
        rest = str_sub(url_str, 7, str_len(url_str))

    slash_pos = str_index_of(rest, "/")
    host_port = rest
    path = "/"
    if slash_pos >= 0
        host_port = str_sub(rest, 0, slash_pos)
        path = str_sub(rest, slash_pos, str_len(rest))

    host = host_port
    colon_pos = str_index_of(host_port, ":")
    if colon_pos >= 0
        host = str_sub(host_port, 0, colon_pos)
        pstr = str_sub(host_port, colon_pos + 1, str_len(host_port))
        pv = 0
        pi = 0
        while pi < str_len(pstr)
            ch = str_char_at(pstr, pi) & 255
            if ch >= 48 and ch <= 57
                pv = (pv * 10) + (ch - 48)
            pi = pi + 1
        if pv > 0
            port = pv

    ip4 = http_client_resolve_host_ipv4(host)
    if ip4.len() != 4
        return 0
    req_str = "GET " + path + " HTTP/1.1\r\nHost: " + host_port + "\r\nUser-Agent: LipiSovereign/1.0\r\nConnection: close\r\n\r\n"
    if is_tls == 1
        return _hc_https_execute(ip4[0], ip4[1], ip4[2], ip4[3], port, host, req_str)
    req_len = str_len(req_str)
    req_buf = sys_alloc(req_len)
    i = 0
    while i < req_len
        mem_byte_write(req_buf, i, str_char_at(req_str, i) & 255)
        i = i + 1
    res = http_client_execute(ip4[0], ip4[1], ip4[2], ip4[3], port, req_buf, req_len)
    sys_free(req_buf)
    return res
