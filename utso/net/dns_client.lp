// ==============================================================================
// 👑 LIPI UNIVERSE NET: SOVEREIGN RFC 1035 PURE DNS CLIENT & PROTOCOL ENCODER
// File: utso/net/dns_client.lp
// ⚡ 100% Pure Lipi | 0% Libc | 0% getaddrinfo | 0% Foreign Resolvers
// Features:
//   - RFC 1035 Wire Encoder & Parser (A=1, CNAME=5, AAAA=28) with Pointer Compression
//   - Tab + Space + Comment-Aware /etc/hosts Resolver (IPv4 & IPv6)
//   - Automatic UDP TC=1 Truncation -> TCP (2-byte Length-Prefixed) Fallback
//   - Recursive CNAME Following (up to 8 hops with loop protection)
// ==============================================================================

include "utso/core/io.lp"
include "utso/core/memory.lp"
include "utso/core/string.lp"

// ── 1. RFC 1035 Wire Format Query Encoder (Configurable QTYPE: A=1, AAAA=28) ──
fn dns_encode_query_type tx_id domain_name qtype out_buf
    mem_byte_write(out_buf, 0, (tx_id >> 8) & 255)
    mem_byte_write(out_buf, 1, tx_id & 255)
    // Flags = 0x0100 (Standard query, Recursion Desired = 1)
    mem_byte_write(out_buf, 2, 1)
    mem_byte_write(out_buf, 3, 0)
    // QDCOUNT = 1, ANCOUNT = 0, NSCOUNT = 0, ARCOUNT = 0
    mem_byte_write(out_buf, 4, 0)
    mem_byte_write(out_buf, 5, 1)
    mem_byte_write(out_buf, 6, 0)
    mem_byte_write(out_buf, 7, 0)
    mem_byte_write(out_buf, 8, 0)
    mem_byte_write(out_buf, 9, 0)
    mem_byte_write(out_buf, 10, 0)
    mem_byte_write(out_buf, 11, 0)

    cursor = 12
    domain_len = len(domain_name)
    label_start = 0
    i = 0

    while i <= domain_len
        is_sep = 0
        if i < domain_len
            ch = get(domain_name, i)
            if ch == 46
                is_sep = 1
        else
            is_sep = 1

        if is_sep == 1
            label_len = i - label_start
            if label_len > 0
                mem_byte_write(out_buf, cursor, label_len & 255)
                cursor = cursor + 1
                p = label_start
                while p < i
                    c_byte = get(domain_name, p)
                    mem_byte_write(out_buf, cursor, c_byte & 255)
                    cursor = cursor + 1
                    p = p + 1
            label_start = i + 1
        i = i + 1

    mem_byte_write(out_buf, cursor, 0)
    cursor = cursor + 1

    // QTYPE (2B BE)
    mem_byte_write(out_buf, cursor, (qtype >> 8) & 255)
    mem_byte_write(out_buf, cursor + 1, qtype & 255)
    cursor = cursor + 2

    // QCLASS = 1 (IN)
    mem_byte_write(out_buf, cursor, 0)
    mem_byte_write(out_buf, cursor + 1, 1)
    cursor = cursor + 2

    return cursor

fn dns_encode_query tx_id domain_name out_buf
    return dns_encode_query_type(tx_id, domain_name, 1, out_buf)

// ── 2. RFC 1035 Name Skipper & Decompressor (Compression-Pointer & Cycle-Safe) ─
fn _dnsc_skip_name buf b_len start_pos
    cursor = start_pos
    while cursor < b_len
        b = mem_byte_read(buf, cursor) & 255
        if (b & 192) == 192
            return cursor + 2
        if b == 0
            return cursor + 1
        cursor = cursor + 1 + b
    return b_len

fn dns_decode_name buf b_len start_pos
    // WHY: Follows RFC 1035 0xC0 compression pointers safely with a strict 16-jump cycle guard.
    out = buf_new(128)
    pos = start_pos
    jumps = 0
    first_label = 1
    while pos < b_len and jumps < 16
        b = mem_byte_read(buf, pos) & 255
        if b == 0
            break
        if (b & 192) == 192
            if pos + 1 >= b_len break
            b2 = mem_byte_read(buf, pos + 1) & 255
            ptr = ((b & 63) * 256) + b2
            if ptr >= b_len break
            pos = ptr
            jumps = jumps + 1
        else
            pos = pos + 1
            if pos + b > b_len break
            if first_label == 0
                buf_write_byte(out, 46) // '.'
            first_label = 0
            buf_write_mem(out, buf + pos, b)
            pos = pos + b
    res = buf_to_str(out)
    buf_free(out)
    return res

fn _dnsc_hex_nibble v
    n = v & 15
    if n < 10 return 48 + n
    return 97 + (n - 10)

fn _dnsc_format_ipv6 ptr
    // WHY: Formats 16 raw IPv6 bytes into canonical 8-group colon-hex notation (RFC 4291).
    out = buf_new(40)
    g = 0
    while g < 8
        if g > 0
            buf_write_byte(out, 58) // ':'
        hi = mem_byte_read(ptr, g * 2) & 255
        lo = mem_byte_read(ptr, g * 2 + 1) & 255
        val = (hi * 256) + lo
        if val == 0
            buf_write_byte(out, 48)
        else
            started = 0
            n3 = (val >> 12) & 15
            n2 = (val >> 8) & 15
            n1 = (val >> 4) & 15
            n0 = val & 15
            if n3 > 0
                buf_write_byte(out, _dnsc_hex_nibble(n3))
                started = 1
            if started == 1 or n2 > 0
                buf_write_byte(out, _dnsc_hex_nibble(n2))
                started = 1
            if started == 1 or n1 > 0
                buf_write_byte(out, _dnsc_hex_nibble(n1))
                started = 1
            buf_write_byte(out, _dnsc_hex_nibble(n0))
        g = g + 1
    res = buf_to_str(out)
    buf_free(out)
    return res

// ── 3. Answer Section Parsers (A=1, AAAA=28, CNAME=5) ─────────────────────────
fn dns_is_truncated resp_buf resp_len
    if resp_len < 12 return 0
    f_hi = mem_byte_read(resp_buf, 2) & 255
    if (f_hi & 2) != 0 return 1
    return 0

fn dns_parse_a_record_checked resp_buf resp_len expected_tx_id
    if resp_len < 12 return ""

    if expected_tx_id >= 0
        rx_id = ((mem_byte_read(resp_buf, 0) & 255) * 256) + (mem_byte_read(resp_buf, 1) & 255)
        if rx_id != (expected_tx_id & 65535) return ""

    f_hi = mem_byte_read(resp_buf, 2) & 255
    f_lo = mem_byte_read(resp_buf, 3) & 255
    qr = (f_hi >> 7) & 1
    rcode = f_lo & 15
    if qr != 1 or rcode != 0 return ""

    qdcount = ((mem_byte_read(resp_buf, 4) & 255) * 256) + (mem_byte_read(resp_buf, 5) & 255)
    ancount = ((mem_byte_read(resp_buf, 6) & 255) * 256) + (mem_byte_read(resp_buf, 7) & 255)
    if ancount == 0 return ""

    cursor = 12
    qi = 0
    while qi < qdcount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor) + 4
        qi = qi + 1

    ans_idx = 0
    while ans_idx < ancount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor)
        if cursor + 10 > resp_len break

        rtype = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 8 // skip TYPE(2) + CLASS(2) + TTL(4)
        rdlength = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 2

        if rtype == 1 and rdlength == 4 and cursor + 4 <= resp_len
            ip0 = mem_byte_read(resp_buf, cursor) & 255
            ip1 = mem_byte_read(resp_buf, cursor + 1) & 255
            ip2 = mem_byte_read(resp_buf, cursor + 2) & 255
            ip3 = mem_byte_read(resp_buf, cursor + 3) & 255
            return str(ip0) + "." + str(ip1) + "." + str(ip2) + "." + str(ip3)

        cursor = cursor + rdlength
        ans_idx = ans_idx + 1

    return ""

fn dns_parse_a_record resp_buf resp_len
    return dns_parse_a_record_checked(resp_buf, resp_len, -1)

fn dns_parse_aaaa_record_checked resp_buf resp_len expected_tx_id
    if resp_len < 12 return ""
    if expected_tx_id >= 0
        rx_id = ((mem_byte_read(resp_buf, 0) & 255) * 256) + (mem_byte_read(resp_buf, 1) & 255)
        if rx_id != (expected_tx_id & 65535) return ""
    f_hi = mem_byte_read(resp_buf, 2) & 255
    f_lo = mem_byte_read(resp_buf, 3) & 255
    if ((f_hi >> 7) & 1) != 1 or (f_lo & 15) != 0 return ""

    qdcount = ((mem_byte_read(resp_buf, 4) & 255) * 256) + (mem_byte_read(resp_buf, 5) & 255)
    ancount = ((mem_byte_read(resp_buf, 6) & 255) * 256) + (mem_byte_read(resp_buf, 7) & 255)
    if ancount == 0 return ""

    cursor = 12
    qi = 0
    while qi < qdcount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor) + 4
        qi = qi + 1

    ans_idx = 0
    while ans_idx < ancount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor)
        if cursor + 10 > resp_len break
        rtype = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 8
        rdlength = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 2
        if rtype == 28 and rdlength == 16 and cursor + 16 <= resp_len
            return _dnsc_format_ipv6(resp_buf + cursor)
        cursor = cursor + rdlength
        ans_idx = ans_idx + 1
    return ""

fn dns_parse_aaaa_record resp_buf resp_len
    return dns_parse_aaaa_record_checked(resp_buf, resp_len, -1)

fn dns_parse_cname_target resp_buf resp_len expected_tx_id
    if resp_len < 12 return ""
    if expected_tx_id >= 0
        rx_id = ((mem_byte_read(resp_buf, 0) & 255) * 256) + (mem_byte_read(resp_buf, 1) & 255)
        if rx_id != (expected_tx_id & 65535) return ""
    f_hi = mem_byte_read(resp_buf, 2) & 255
    f_lo = mem_byte_read(resp_buf, 3) & 255
    if ((f_hi >> 7) & 1) != 1 or (f_lo & 15) != 0 return ""

    qdcount = ((mem_byte_read(resp_buf, 4) & 255) * 256) + (mem_byte_read(resp_buf, 5) & 255)
    ancount = ((mem_byte_read(resp_buf, 6) & 255) * 256) + (mem_byte_read(resp_buf, 7) & 255)
    if ancount == 0 return ""

    cursor = 12
    qi = 0
    while qi < qdcount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor) + 4
        qi = qi + 1

    last_cname = ""
    ans_idx = 0
    while ans_idx < ancount and cursor < resp_len
        cursor = _dnsc_skip_name(resp_buf, resp_len, cursor)
        if cursor + 10 > resp_len break
        rtype = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 8
        rdlength = ((mem_byte_read(resp_buf, cursor) & 255) * 256) + (mem_byte_read(resp_buf, cursor + 1) & 255)
        cursor = cursor + 2
        if rtype == 5 and cursor + rdlength <= resp_len
            last_cname = dns_decode_name(resp_buf, resp_len, cursor)
        cursor = cursor + rdlength
        ans_idx = ans_idx + 1
    return last_cname

// ── 4. /etc/resolv.conf & Whitespace/Tab-Safe /etc/hosts Parser ───────────────
fn _dnsc_parse_ipv4_octets ip_str
    o0 = 0
    o1 = 0
    o2 = 0
    o3 = 0
    part = 0
    curr = 0
    has_d = 0
    valid = 1
    i = 0
    n = len(ip_str)
    while i < n
        ch = str_char_at(ip_str, i)
        if ch >= 48 and ch <= 57
            curr = (curr * 10) + (ch - 48)
            has_d = 1
            if curr > 255 valid = 0
        elif ch == 46
            if has_d == 0 or part >= 3 valid = 0
            if part == 0 o0 = curr
            if part == 1 o1 = curr
            if part == 2 o2 = curr
            part = part + 1
            curr = 0
            has_d = 0
        else
            valid = 0
        i = i + 1
    if has_d == 0 or part != 3 valid = 0
    if valid == 0 return []
    o3 = curr
    return [o0, o1, o2, o3]

fn _dnsc_raw_ptr x
    return x

fn _dnsc_split_ws_tokens line
    // WHY: Splits a line on spaces (32), tabs (9), CR (13), stopping at inline '#' (35) comments.
    toks = []
    n = len(line)
    lp = _dnsc_raw_ptr(line)
    i = 0
    while i < n
        ch = mem_byte_read(lp, i) & 255
        if ch == 35 break // '#' comment
        if ch == 32 or ch == 9 or ch == 13
            i = i + 1
            continue
        start = i
        while i < n
            c2 = mem_byte_read(lp, i) & 255
            if c2 == 32 or c2 == 9 or c2 == 13 or c2 == 35 break
            i = i + 1
        toks = push(toks, bytes_to_str(lp + start, i - start))
    return toks

fn dns_lookup_hosts_text hosts_txt domain want_ipv6
    // WHY: Pure parser supporting both spaces and tabs (e.g. "127.0.0.1\tlocalhost") and '#' comments.
    lines = string_split(hosts_txt, "\n")
    li = 0
    while li < len(lines)
        toks = _dnsc_split_ws_tokens(get(lines, li))
        if len(toks) >= 2
            ip = get(toks, 0)
            is_v4 = 0
            if len(_dnsc_parse_ipv4_octets(ip)) == 4
                is_v4 = 1
            is_v6 = str_contains(ip, ":")
            if (want_ipv6 == 0 and is_v4 == 1) or (want_ipv6 == 1 and is_v6 == 1)
                pi = 1
                while pi < len(toks)
                    if get(toks, pi) == domain return ip
                    pi = pi + 1
        li = li + 1
    return ""

fn _dnsc_read_resolv_ns
    fd = syscall(2, "/etc/resolv.conf", 0, 0, 0, 0, 0)
    if fd < 0 return "1.1.1.1"
    buf = malloc(4096)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return "1.1.1.1"
    n = syscall(0, fd, buf, 4095, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if n <= 0
        free(buf, 4096)
        return "1.1.1.1"
    txt = bytes_to_str(buf, n)
    free(buf, 4096)
    lines = string_split(txt, "\n")
    li = 0
    while li < len(lines)
        toks = _dnsc_split_ws_tokens(get(lines, li))
        if len(toks) >= 2 and get(toks, 0) == "nameserver"
            cand = get(toks, 1)
            if len(_dnsc_parse_ipv4_octets(cand)) == 4
                return cand
        li = li + 1
    return "1.1.1.1"

fn _dnsc_lookup_etc_hosts_kind domain want_ipv6
    fd = syscall(2, "/etc/hosts", 0, 0, 0, 0, 0)
    if fd < 0 return ""
    buf = malloc(16384)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return ""
    n = syscall(0, fd, buf, 16383, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    if n <= 0
        free(buf, 16384)
        return ""
    txt = bytes_to_str(buf, n)
    free(buf, 16384)
    return dns_lookup_hosts_text(txt, domain, want_ipv6)

fn _dnsc_lookup_etc_hosts domain
    return _dnsc_lookup_etc_hosts_kind(domain, 0)

// ── 5. RFC 1035 UDP + Automatic TCP Fallback (TC=1) Transport ─────────────────
fn _dnsc_query_tcp addr_buf q_buf q_len r_buf r_max
    // WHY: RFC 1035 Section 4.2.2 TCP DNS uses a 2-byte big-endian length prefix before message bytes.
    tfd = syscall(41, 2, 1, 6, 0, 0, 0) // AF_INET, SOCK_STREAM, IPPROTO_TCP
    if tfd < 0 return 0
    tv = malloc(16)
    if tv > 0
        mem_write(tv, 0, 2)
        mem_write(tv, 8, 0)
        syscall(54, tfd, 1, 20, tv, 16, 0)
        syscall(54, tfd, 1, 21, tv, 16, 0)
        free(tv, 16)
    if syscall(42, tfd, addr_buf, 16, 0, 0, 0) < 0
        syscall(3, tfd, 0, 0, 0, 0, 0)
        return 0
    pkt = malloc(q_len + 2)
    if pkt <= 0
        syscall(3, tfd, 0, 0, 0, 0, 0)
        return 0
    mem_byte_write(pkt, 0, (q_len >> 8) & 255)
    mem_byte_write(pkt, 1, q_len & 255)
    ci = 0
    while ci < q_len
        mem_byte_write(pkt, 2 + ci, mem_byte_read(q_buf, ci))
        ci = ci + 1
    sent = 0
    total_tx = q_len + 2
    while sent < total_tx
        nw = syscall(1, tfd, pkt + sent, total_tx - sent, 0, 0, 0)
        if nw <= 0 break
        sent = sent + nw
    free(pkt, q_len + 2)
    if sent < total_tx
        syscall(3, tfd, 0, 0, 0, 0, 0)
        return 0

    // Read 2-byte response length prefix
    len_hdr = malloc(4)
    got_h = 0
    while got_h < 2
        nr = syscall(0, tfd, len_hdr + got_h, 2 - got_h, 0, 0, 0)
        if nr <= 0 break
        got_h = got_h + nr
    resp_want = 0
    if got_h == 2
        resp_want = ((mem_byte_read(len_hdr, 0) & 255) * 256) + (mem_byte_read(len_hdr, 1) & 255)
    free(len_hdr, 4)
    if resp_want <= 0 or resp_want > r_max
        syscall(3, tfd, 0, 0, 0, 0, 0)
        return 0
    got_b = 0
    while got_b < resp_want
        nr = syscall(0, tfd, r_buf + got_b, resp_want - got_b, 0, 0, 0)
        if nr <= 0 break
        got_b = got_b + nr
    syscall(3, tfd, 0, 0, 0, 0, 0)
    return got_b

fn _dnsc_resolve_qtype_server domain qtype ns_ip port
    octs = _dnsc_parse_ipv4_octets(ns_ip)
    if len(octs) != 4 return ""
    p_use = port
    if p_use <= 0
        p_use = 53

    q_buf = malloc(512)
    r_buf = malloc(4096)
    addr_buf = malloc(16)
    tv_buf = malloc(16)
    if q_buf <= 0 or r_buf <= 0 or addr_buf <= 0 or tv_buf <= 0
        if q_buf > 0 free(q_buf, 512)
        if r_buf > 0 free(r_buf, 4096)
        if addr_buf > 0 free(addr_buf, 16)
        if tv_buf > 0 free(tv_buf, 16)
        return ""

    mem_fill(addr_buf, 0, 16)
    mem_byte_write(addr_buf, 0, 2)
    mem_byte_write(addr_buf, 2, (p_use >> 8) & 255)
    mem_byte_write(addr_buf, 3, p_use & 255)
    mem_byte_write(addr_buf, 4, get(octs, 0))
    mem_byte_write(addr_buf, 5, get(octs, 1))
    mem_byte_write(addr_buf, 6, get(octs, 2))
    mem_byte_write(addr_buf, 7, get(octs, 3))

    cur_domain = domain
    res_ip = ""
    hop = 0
    while hop < 8
        rng_buf = malloc(16)
        tx_id = 4242 + hop
        if rng_buf > 0
            if syscall(318, rng_buf, 2, 0, 0, 0, 0) == 2
                tx_id = ((mem_byte_read(rng_buf, 0) & 255) * 256) + (mem_byte_read(rng_buf, 1) & 255)
            free(rng_buf, 16)
        if tx_id == 0
            tx_id = 13579 + hop

        q_len = dns_encode_query_type(tx_id, cur_domain, qtype, q_buf)
        rn = 0
        fd = syscall(41, 2, 2, 0, 0, 0, 0) // SOCK_DGRAM
        if fd >= 0
            mem_write(tv_buf, 0, 1)
            mem_write(tv_buf, 8, 0)
            syscall(54, fd, 1, 20, tv_buf, 16, 0)
            sent = syscall(44, fd, q_buf, q_len, 0, addr_buf, 16)
            if sent > 0
                rn = syscall(45, fd, r_buf, 4096, 0, 0, 0)
            syscall(3, fd, 0, 0, 0, 0, 0)

        // Automatic RFC 1035 TCP fallback when UDP response has TC=1 (truncated)
        if rn >= 12 and dns_is_truncated(r_buf, rn) == 1
            tcp_rn = _dnsc_query_tcp(addr_buf, q_buf, q_len, r_buf, 4096)
            if tcp_rn >= 12
                rn = tcp_rn

        if rn < 12 break

        if qtype == 28
            res_ip = dns_parse_aaaa_record_checked(r_buf, rn, tx_id)
        else
            res_ip = dns_parse_a_record_checked(r_buf, rn, tx_id)
        if res_ip != "" break

        // Follow CNAME chain recursively up to 8 hops
        cname_next = dns_parse_cname_target(r_buf, rn, tx_id)
        if cname_next == "" or cname_next == cur_domain break
        cur_domain = cname_next
        hop = hop + 1

    free(q_buf, 512)
    free(r_buf, 4096)
    free(addr_buf, 16)
    free(tv_buf, 16)
    return res_ip

fn dns_resolve_ipv4_with_server domain ns_ip port
    if domain == "" return ""
    if domain == "localhost" return "127.0.0.1"
    if len(_dnsc_parse_ipv4_octets(domain)) == 4 return domain
    h_ip = _dnsc_lookup_etc_hosts(domain)
    if h_ip != "" return h_ip
    return _dnsc_resolve_qtype_server(domain, 1, ns_ip, port)

fn dns_resolve_ipv4 domain
    ns_ip = _dnsc_read_resolv_ns()
    ip = dns_resolve_ipv4_with_server(domain, ns_ip, 53)
    if ip == "" and ns_ip != "1.1.1.1"
        ip = dns_resolve_ipv4_with_server(domain, "1.1.1.1", 53)
    return ip

fn dns_resolve_ipv6_with_server domain ns_ip port
    if domain == "" return ""
    if domain == "localhost" return "::1"
    if str_contains(domain, ":") == 1 return domain
    h_ip = _dnsc_lookup_etc_hosts_kind(domain, 1)
    if h_ip != "" return h_ip
    return _dnsc_resolve_qtype_server(domain, 28, ns_ip, port)

fn dns_resolve_ipv6 domain
    ns_ip = _dnsc_read_resolv_ns()
    ip = dns_resolve_ipv6_with_server(domain, ns_ip, 53)
    if ip == "" and ns_ip != "1.1.1.1"
        ip = dns_resolve_ipv6_with_server(domain, "1.1.1.1", 53)
    return ip

// ── 6. Bilingual Bengali API ──────────────────────────────────────────────────
fn ডিএনএস_কুয়েরি_প্যাকেট_তৈরি ট্রানজ্যাকশন_আইডি ডোমেন বাফার
    return dns_encode_query(ট্রানজ্যাকশন_আইডি, ডোমেন, বাফার)

fn ডিএনএস_আইপি_পার্স রেসপন্স_বাফার সাইজ
    return dns_parse_a_record(রেসপন্স_বাফার, সাইজ)
