// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Sovereign RFC 1035 DNS Wire Encoder & Response Parser
// File: tests/test_dns_resolver.lp
// Milestone: First 1.0.0 (প্রথম ১.০.০) | Zero Libc | Zero getaddrinfo
// ==============================================================================

include "universe/net/dns_client.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ FAILED: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🌐 LIPI SOVEREIGN RFC 1035 DNS PROTOCOL ENCODER & PARSER TEST"
    say "════════════════════════════════════════════════════════════════════════"

    query_buf = malloc(512)

    say "\n[Phase 1]: Encoding Domain 'lipi.dev' into RFC 1035 Wire Format..."
    tx_id = 4660 // 0x1234
    packet_len = dns_encode_query(tx_id, "lipi.dev", query_buf)
    // 12 (hdr) + 1 (len 'lipi') + 4 ('lipi') + 1 (len 'dev') + 3 ('dev') + 1 (term 0) + 2 (type) + 2 (class) = 26 bytes
    assert_true(packet_len == 26, "Encoded DNS query packet length is 26 bytes")

    // Verify 16-bit Transaction ID (0x12, 0x34)
    assert_true(mem_byte_read(query_buf, 0) == 18, "Transaction ID high byte is 0x12")
    assert_true(mem_byte_read(query_buf, 1) == 52, "Transaction ID low byte is 0x34")

    // Verify Flags: 0x0100 (Recursion Desired = 1)
    assert_true(mem_byte_read(query_buf, 2) == 1, "Flags high byte has RD=1")
    assert_true(mem_byte_read(query_buf, 3) == 0, "Flags low byte is 0")

    // Verify QDCOUNT = 1
    assert_true(mem_byte_read(query_buf, 4) == 0, "QDCOUNT high byte is 0")
    assert_true(mem_byte_read(query_buf, 5) == 1, "QDCOUNT low byte is 1")

    // Verify QNAME labels: 4 'l' 'i' 'p' 'i' 3 'd' 'e' 'v' 0
    assert_true(mem_byte_read(query_buf, 12) == 4, "First label length is 4")
    assert_true(mem_byte_read(query_buf, 13) == 108, "Byte 'l'")
    assert_true(mem_byte_read(query_buf, 14) == 105, "Byte 'i'")
    assert_true(mem_byte_read(query_buf, 15) == 112, "Byte 'p'")
    assert_true(mem_byte_read(query_buf, 16) == 105, "Byte 'i'")
    assert_true(mem_byte_read(query_buf, 17) == 3, "Second label length is 3")
    assert_true(mem_byte_read(query_buf, 18) == 100, "Byte 'd'")
    assert_true(mem_byte_read(query_buf, 19) == 101, "Byte 'e'")
    assert_true(mem_byte_read(query_buf, 20) == 118, "Byte 'v'")
    assert_true(mem_byte_read(query_buf, 21) == 0, "QNAME zero terminator verified")

    // Verify QTYPE = 1 (A), QCLASS = 1 (IN)
    assert_true(mem_byte_read(query_buf, 23) == 1, "QTYPE is 1 (Type A)")
    assert_true(mem_byte_read(query_buf, 25) == 1, "QCLASS is 1 (Class IN)")

    say "\n[Phase 2]: Synthesizing & Parsing DNS Answer Response..."
    // Construct a synthetic 42-byte DNS response with 1 Answer pointing to 142.250.190.46
    resp_buf = malloc(128)
    mem_fill(resp_buf, 0, 128)

    // Header: ID=0x1234, Flags=0x8180 (Standard response, no error), QD=1, AN=1
    mem_byte_write(resp_buf, 0, 18)
    mem_byte_write(resp_buf, 1, 52)
    mem_byte_write(resp_buf, 2, 129) // 0x81
    mem_byte_write(resp_buf, 3, 128) // 0x80
    mem_byte_write(resp_buf, 5, 1)   // QDCOUNT = 1
    mem_byte_write(resp_buf, 7, 1)   // ANCOUNT = 1

    // Copy Question Section (14 bytes) from query_buf[12..26]
    qi = 0
    while qi < 14
        mem_byte_write(resp_buf, 12 + qi, mem_byte_read(query_buf, 12 + qi))
        qi = qi + 1

    // Answer Section starting at offset 26
    // Name pointer: 0xC00C (points to offset 12)
    mem_byte_write(resp_buf, 26, 192)
    mem_byte_write(resp_buf, 27, 12)
    // Type A: 0x0001
    mem_byte_write(resp_buf, 28, 0)
    mem_byte_write(resp_buf, 29, 1)
    // Class IN: 0x0001
    mem_byte_write(resp_buf, 30, 0)
    mem_byte_write(resp_buf, 31, 1)
    // TTL: 300 seconds
    mem_byte_write(resp_buf, 32, 0)
    mem_byte_write(resp_buf, 33, 0)
    mem_byte_write(resp_buf, 34, 1)
    mem_byte_write(resp_buf, 35, 44)
    // RDLENGTH: 4 bytes
    mem_byte_write(resp_buf, 36, 0)
    mem_byte_write(resp_buf, 37, 4)
    // IPv4 Address: 142.250.190.46
    mem_byte_write(resp_buf, 38, 142)
    mem_byte_write(resp_buf, 39, 250)
    mem_byte_write(resp_buf, 40, 190)
    mem_byte_write(resp_buf, 41, 46)

    resolved_ip = dns_parse_a_record(resp_buf, 42)
    assert_true(resolved_ip == "142.250.190.46", "Resolved IPv4 is exactly '142.250.190.46'")

    free(query_buf, 512)
    free(resp_buf, 128)

    say "\n════════════════════════════════════════════════════════════════════════"
    say "🎉 SOVEREIGN RFC 1035 DNS WIRE PROTOCOL TEST PASSED (100% PURE)"
    say "════════════════════════════════════════════════════════════════════════\n"
    return 0

main()
