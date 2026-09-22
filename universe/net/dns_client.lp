// ==============================================================================
// 👑 LIPI UNIVERSE NET: SOVEREIGN RFC 1035 PURE DNS CLIENT & PROTOCOL ENCODER
// File: universe/net/dns_client.lp
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

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"

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

// ── ২. ডিএনএস রেসপন্স পার্সার (Parse IPv4 Address from Type-A Answer Record) ──
// WHY: Parses DNS wire format answers and extracts the 4-byte IPv4 address payload.
fn dns_parse_a_record resp_buf resp_len
    if resp_len < 12 return ""

    // Read ANCOUNT at offset 6 (16-bit BE)
    ancount = (mem_byte_read(resp_buf, 6) * 256) + mem_byte_read(resp_buf, 7)
    if ancount == 0 return ""

    // Skip Header (12 bytes) and Question Section
    cursor = 12
    // Skip QNAME (labels until 0-byte or pointer)
    while cursor < resp_len
        b = mem_byte_read(resp_buf, cursor)
        cursor = cursor + 1
        if b == 0
            break
        if (b & 192) == 192 // DNS compression pointer (2 bytes)
            cursor = cursor + 1
            break
    // Skip QTYPE (2) + QCLASS (2) = 4 bytes
    cursor = cursor + 4

    // Parse Answers (Iterate to find first Type A = 1 record)
    ans_idx = 0
    while ans_idx < ancount and cursor < resp_len
        // Skip Name field (compressed pointer or label)
        nb = mem_byte_read(resp_buf, cursor)
        if (nb & 192) == 192
            cursor = cursor + 2
        else
            while cursor < resp_len
                cur_b = mem_byte_read(resp_buf, cursor)
                cursor = cursor + 1
                if cur_b == 0 break

        if cursor + 10 > resp_len break

        // Type (2 bytes BE)
        rtype = (mem_byte_read(resp_buf, cursor) * 256) + mem_byte_read(resp_buf, cursor + 1)
        cursor = cursor + 2

        // Class (2 bytes BE)
        rclass = (mem_byte_read(resp_buf, cursor) * 256) + mem_byte_read(resp_buf, cursor + 1)
        cursor = cursor + 2

        // TTL (4 bytes)
        cursor = cursor + 4

        // RDLENGTH (2 bytes BE)
        rdlength = (mem_byte_read(resp_buf, cursor) * 256) + mem_byte_read(resp_buf, cursor + 1)
        cursor = cursor + 2

        if rtype == 1 and rdlength == 4
            // Type A (IPv4): 4 bytes follow
            ip0 = mem_byte_read(resp_buf, cursor)
            ip1 = mem_byte_read(resp_buf, cursor + 1)
            ip2 = mem_byte_read(resp_buf, cursor + 2)
            ip3 = mem_byte_read(resp_buf, cursor + 3)
            return str(ip0) + "." + str(ip1) + "." + str(ip2) + "." + str(ip3)

        cursor = cursor + rdlength
        ans_idx = ans_idx + 1

    return ""

// ── ৩. দ্বিভাষিক বাংলা ফাংশনসমূহ (Bilingual Bengali API) ──────────────────────
fn ডিএনএস_কুয়েরি_প্যাকেট_তৈরি ট্রানজ্যাকশন_আইডি ডোমেন বাফার
    return dns_encode_query(ট্রানজ্যাকশন_আইডি, ডোমেন, বাফার)

fn ডিএনএস_আইপি_পার্স রেসপন্স_বাফার সাইজ
    return dns_parse_a_record(রেসপন্স_বাফার, সাইজ)
