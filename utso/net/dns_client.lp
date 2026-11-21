// ==============================================================================
// 👑 LIPI UNIVERSE NET: SOVEREIGN RFC 1035 PURE DNS CLIENT & PROTOCOL ENCODER
// File: utso/net/dns_client.lp
// ⚡ 100% Pure Lipi First 1.0.0 | 0% Libc | 0% getaddrinfo | 0% Foreign Resolvers
// ==============================================================================
//
// WHY THIS EXISTS:
// Mainstream programming languages rely on glibc's getaddrinfo() or systemd-resolved
// to translate hostnames to IP addresses, binding the executable to libc ABI.
//
// LIPI'S SOVEREIGN ANSWER:
// Implements direct RFC 1035 DNS wire packet serialization and response parsing.
// Connects directly to DNS nameservers (e.g. 1.1.1.1 or 8.8.8.8) over UDP port 53
// using direct Linux kernel socket syscalls (SYS_socket, SYS_sendto, SYS_recvfrom).
// ==============================================================================

include "utso/core/io.lp"
include "utso/core/memory.lp"
include "utso/core/string.lp"

// ── ১. আরএফসি ১০৩৫ ডিএনএস কুয়েরি প্যাকেট বিল্ডার (RFC 1035 Wire Format Encoder) ──
// WHY: Converts hostname like "example.com" to DNS wire labels "\x07example\x03com\x00"
// with 12-byte standard recursive header (ID, Flags: 0x0100, QDCOUNT: 1, Type: A, Class: IN).
fn dns_encode_query tx_id domain_name out_buf
    // 12-byte standard DNS header
    // ID (16-bit)
    mem_byte_write(out_buf, 0, (tx_id >> 8) & 255)
    mem_byte_write(out_buf, 1, tx_id & 255)
    // Flags = 0x0100 (Standard query, Recursion Desired = 1)
    mem_byte_write(out_buf, 2, 1)
    mem_byte_write(out_buf, 3, 0)
    // QDCOUNT = 1
    mem_byte_write(out_buf, 4, 0)
    mem_byte_write(out_buf, 5, 1)
    // ANCOUNT = 0
    mem_byte_write(out_buf, 6, 0)
    mem_byte_write(out_buf, 7, 0)
    // NSCOUNT = 0
    mem_byte_write(out_buf, 8, 0)
    mem_byte_write(out_buf, 9, 0)
    // ARCOUNT = 0
    mem_byte_write(out_buf, 10, 0)
    mem_byte_write(out_buf, 11, 0)

    // Encode Question Name (QNAME): labels separated by dots
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
            is_sep = 1 // End of domain string acts as label boundary

        if is_sep == 1
            label_len = i - label_start
            if label_len > 0
                // Write label length byte
                mem_byte_write(out_buf, cursor, label_len & 255)
                cursor = cursor + 1

                // Copy label characters (get returns ASCII integer directly)
                p = label_start
                while p < i
                    c_byte = get(domain_name, p)
                    mem_byte_write(out_buf, cursor, c_byte & 255)
                    cursor = cursor + 1
                    p = p + 1
            label_start = i + 1
        i = i + 1

    // Zero-byte terminator for QNAME
    mem_byte_write(out_buf, cursor, 0)
    cursor = cursor + 1

    // QTYPE = 1 (Type A - Host Address IPv4)
    mem_byte_write(out_buf, cursor, 0)
    mem_byte_write(out_buf, cursor + 1, 1)
    cursor = cursor + 2

    // QCLASS = 1 (Class IN - Internet)
    mem_byte_write(out_buf, cursor, 0)
    mem_byte_write(out_buf, cursor + 1, 1)
    cursor = cursor + 2

    return cursor

// Read Question & Answers safely with QR/RCODE/tx_id/pointer checks
fn _dnsc_skip_name buf b_len start_pos
    cursor = start_pos
    while cursor < b_len
        b = mem_byte_read(buf, cursor)
        if (b & 192) == 192
            return cursor + 2
        if b == 0
            return cursor + 1
        cursor = cursor + 1 + b
    return b_len

fn dns_parse_a_record_checked resp_buf resp_len expected_tx_id
    if resp_len < 12 return ""

    if expected_tx_id >= 0
        rx_id = (mem_byte_read(resp_buf, 0) * 256) + mem_byte_read(resp_buf, 1)
        if rx_id != (expected_tx_id & 65535) return ""

    f_hi = mem_byte_read(resp_buf, 2)
    f_lo = mem_byte_read(resp_buf, 3)
    qr = (f_hi >> 7) & 1
    rcode = f_lo & 15
    if qr != 1 or rcode != 0 return ""

    qdcount = (mem_byte_read(resp_buf, 4) * 256) + mem_byte_read(resp_buf, 5)
    ancount = (mem_byte_read(resp_buf, 6) * 256) + mem_byte_read(resp_buf, 7)
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

        rtype = (mem_byte_read(resp_buf, cursor) * 256) + mem_byte_read(resp_buf, cursor + 1)
        cursor = cursor + 4 // skip TYPE + CLASS
        cursor = cursor + 4 // skip TTL
        rdlength = (mem_byte_read(resp_buf, cursor) * 256) + mem_byte_read(resp_buf, cursor + 1)
        cursor = cursor + 2

        if rtype == 1 and rdlength == 4 and cursor + 4 <= resp_len
            ip0 = mem_byte_read(resp_buf, cursor)
            ip1 = mem_byte_read(resp_buf, cursor + 1)
            ip2 = mem_byte_read(resp_buf, cursor + 2)
            ip3 = mem_byte_read(resp_buf, cursor + 3)
            return str(ip0) + "." + str(ip1) + "." + str(ip2) + "." + str(ip3)

        cursor = cursor + rdlength
        ans_idx = ans_idx + 1

    return ""

fn dns_parse_a_record resp_buf resp_len
    return dns_parse_a_record_checked(resp_buf, resp_len, -1)

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
    mem_byte_write(buf, n, 0)
    txt = str_sub(buf, 0, n)
    free(buf, 4096)
    lines = string_split(txt, "\n")
    li = 0
    while li < len(lines)
        ln = str_trim(get(lines, li))
        if starts_with(ln, "nameserver ")
            cand = str_trim(str_sub(ln, 11, len(ln)))
            if len(_dnsc_parse_ipv4_octets(cand)) == 4
                return cand
        li = li + 1
    return "1.1.1.1"

fn _dnsc_lookup_etc_hosts domain
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
    mem_byte_write(buf, n, 0)
    txt = str_sub(buf, 0, n)
    free(buf, 16384)
    lines = string_split(txt, "\n")
    li = 0
    while li < len(lines)
        ln = str_trim(get(lines, li))
        if len(ln) > 0 and str_char_at(ln, 0) != 35
            parts = string_split(ln, " ")
            if len(parts) >= 2
                ip = str_trim(get(parts, 0))
                if len(_dnsc_parse_ipv4_octets(ip)) == 4
                    pi = 1
                    while pi < len(parts)
                        hn = str_trim(get(parts, pi))
                        if hn == domain return ip
                        pi = pi + 1
        li = li + 1
    return ""

fn dns_resolve_ipv4_with_server domain ns_ip port
    if domain == "" return ""
    if domain == "localhost" return "127.0.0.1"
    if len(_dnsc_parse_ipv4_octets(domain)) == 4 return domain
    h_ip = _dnsc_lookup_etc_hosts(domain)
    if h_ip != "" return h_ip

    octs = _dnsc_parse_ipv4_octets(ns_ip)
    if len(octs) != 4 return ""
    p_use = port
    if p_use <= 0 p_use = 53

    // CSPRNG 16-bit tx_id
    rng_buf = malloc(16)
    if rng_buf <= 0 return ""
    tx_id = 4242
    if syscall(318, rng_buf, 2, 0, 0, 0, 0) == 2
        tx_id = (mem_byte_read(rng_buf, 0) * 256) + mem_byte_read(rng_buf, 1)
    if tx_id == 0 tx_id = 13579
    free(rng_buf, 16)

    q_buf = malloc(512)
    r_buf = malloc(1536)
    addr_buf = malloc(16)
    tv_buf = malloc(16)
    if q_buf <= 0 or r_buf <= 0 or addr_buf <= 0 or tv_buf <= 0
        if q_buf > 0 free(q_buf, 512)
        if r_buf > 0 free(r_buf, 1536)
        if addr_buf > 0 free(addr_buf, 16)
        if tv_buf > 0 free(tv_buf, 16)
        return ""

    q_len = dns_encode_query(tx_id, domain, q_buf)
    mem_fill(addr_buf, 0, 16)
    mem_byte_write(addr_buf, 0, 2) // AF_INET
    mem_byte_write(addr_buf, 2, (p_use >> 8) & 255)
    mem_byte_write(addr_buf, 3, p_use & 255)
    mem_byte_write(addr_buf, 4, get(octs, 0))
    mem_byte_write(addr_buf, 5, get(octs, 1))
    mem_byte_write(addr_buf, 6, get(octs, 2))
    mem_byte_write(addr_buf, 7, get(octs, 3))

    fd = syscall(41, 2, 2, 0, 0, 0, 0) // SOCK_DGRAM
    res_ip = ""
    if fd >= 0
        mem_write(tv_buf, 0, 1)
        mem_write(tv_buf, 8, 0)
        syscall(54, fd, 1, 20, tv_buf, 16, 0) // SO_RCVTIMEO = 1s
        sent = syscall(44, fd, q_buf, q_len, 0, addr_buf, 16)
        if sent > 0
            rn = syscall(45, fd, r_buf, 1536, 0, 0, 0)
            if rn >= 12
                res_ip = dns_parse_a_record_checked(r_buf, rn, tx_id)
        syscall(3, fd, 0, 0, 0, 0, 0)

    free(q_buf, 512)
    free(r_buf, 1536)
    free(addr_buf, 16)
    free(tv_buf, 16)
    return res_ip

fn dns_resolve_ipv4 domain
    ns_ip = _dnsc_read_resolv_ns()
    ip = dns_resolve_ipv4_with_server(domain, ns_ip, 53)
    if ip == "" and ns_ip != "1.1.1.1"
        ip = dns_resolve_ipv4_with_server(domain, "1.1.1.1", 53)
    return ip

// ── ৩. দ্বিভাষিক বাংলা ফাংশনসমূহ (Bilingual Bengali API) ──────────────────────
fn ডিএনএস_কুয়েরি_প্যাকেট_তৈরি ট্রানজ্যাকশন_আইডি ডোমেন বাফার
    return dns_encode_query(ট্রানজ্যাকশন_আইডি, ডোমেন, বাফার)

fn ডিএনএস_আইপি_পার্স রেসপন্স_বাফার সাইজ
    return dns_parse_a_record(রেসপন্স_বাফার, সাইজ)
