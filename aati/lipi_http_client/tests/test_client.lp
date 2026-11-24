// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Sovereign HTTP/1.1 Client Unit Test
// ==============================================================================

include "aati/lipi_http_client/src/http_client.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI HTTP CLIENT: PROTOCOL ENGINE TEST 👑"
say "================================================================="

// ── ১. স্ট্যাটাস কোড পার্সিং পরীক্ষা ──
// "HTTP/1.1 200 OK\r\n"
buf_200 = sys_alloc(32)
mem_write_byte(buf_200, 0, 72)  // 'H'
mem_write_byte(buf_200, 1, 84)  // 'T'
mem_write_byte(buf_200, 2, 84)  // 'T'
mem_write_byte(buf_200, 3, 80)  // 'P'
mem_write_byte(buf_200, 4, 47)  // '/'
mem_write_byte(buf_200, 5, 49)  // '1'
mem_write_byte(buf_200, 6, 46)  // '.'
mem_write_byte(buf_200, 7, 49)  // '1'
mem_write_byte(buf_200, 8, 32)  // ' '
mem_write_byte(buf_200, 9, 50)  // '2'
mem_write_byte(buf_200, 10, 48) // '0'
mem_write_byte(buf_200, 11, 48) // '0'
mem_write_byte(buf_200, 12, 32) // ' '

s200 = http_parse_status_code(buf_200, 13)
assert_eq(s200, 200, "HTTP 200 OK parsed")

// 404
mem_write_byte(buf_200, 9, 52)  // '4'
mem_write_byte(buf_200, 10, 48) // '0'
mem_write_byte(buf_200, 11, 52) // '4'
s404 = http_parse_status_code(buf_200, 13)
assert_eq(s404, 404, "HTTP 404 Not Found parsed")

// 503
mem_write_byte(buf_200, 9, 53)  // '5'
mem_write_byte(buf_200, 10, 48) // '0'
mem_write_byte(buf_200, 11, 51) // '3'
s503 = http_parse_status_code(buf_200, 13)
assert_eq(s503, 503, "HTTP 503 Service Unavailable parsed")

sys_free(buf_200)

// ── ২. সম্পূর্ণ HTTP রেসপন্স এবং বডি ডিলিমিটার পরীক্ষা ──
// Raw response:
// HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELLO
raw = sys_alloc(64)
mem_zero(raw, 64)

// "HTTP/1.1 200 OK\r\n\r\nHELLO"
// indices:
// 0..14: "HTTP/1.1 200 OK"
mem_write_byte(raw, 0, 72)
mem_write_byte(raw, 1, 84)
mem_write_byte(raw, 2, 84)
mem_write_byte(raw, 3, 80)
mem_write_byte(raw, 4, 47)
mem_write_byte(raw, 5, 49)
mem_write_byte(raw, 6, 46)
mem_write_byte(raw, 7, 49)
mem_write_byte(raw, 8, 32)
mem_write_byte(raw, 9, 50)
mem_write_byte(raw, 10, 48)
mem_write_byte(raw, 11, 48)
mem_write_byte(raw, 12, 32)
mem_write_byte(raw, 13, 79) // 'O'
mem_write_byte(raw, 14, 75) // 'K'
mem_write_byte(raw, 15, 13) // \r
mem_write_byte(raw, 16, 10) // \n
mem_write_byte(raw, 17, 13) // \r
mem_write_byte(raw, 18, 10) // \n
// Body at index 19: "HELLO" (72, 69, 76, 76, 79)
mem_write_byte(raw, 19, 72)
mem_write_byte(raw, 20, 69)
mem_write_byte(raw, 21, 76)
mem_write_byte(raw, 22, 76)
mem_write_byte(raw, 23, 79)

total_len = 24

body_offset = http_find_body_offset(raw, total_len)
assert_eq(body_offset, 19, "Body offset correctly identified at index 19")

resp = http_parse_response(raw, total_len)
assert_true(resp > 0, "Response object allocated")
assert_eq(http_response_status(resp), 200, "Response status code is 200")
assert_eq(http_response_body_len(resp), 5, "Response body length is 5")

body_p = http_response_body_ptr(resp)
assert_eq(mem_byte_read(body_p, 0), 72, "First char of body is 'H'")
assert_eq(mem_byte_read(body_p, 4), 79, "Last char of body is 'O'")

http_response_free(resp)

// ── ৩. Chunked Transfer-Encoding Decoding ────────────────────────────────────
chk_str = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n6\r\n World\r\n0\r\n\r\n"
chk_len = str_len(chk_str)
chk_buf = sys_alloc(chk_len)
ci = 0
while ci < chk_len
    mem_write_byte(chk_buf, ci, str_char_at(chk_str, ci) & 255)
    ci = ci + 1
cresp = http_parse_response(chk_buf, chk_len)
assert_eq(http_response_status(cresp), 200, "Chunked response status 200")
assert_eq(http_response_body_len(cresp), 11, "Chunked body decoded length == 11")
assert_eq(mem_byte_read(http_response_body_ptr(cresp), 0), 72, "Chunked body starts with 'H'")
assert_eq(mem_byte_read(http_response_body_ptr(cresp), 10), 100, "Chunked body ends with 'd'")
http_response_free(cresp)

// ── ৪. Real Loopback >32KB Multi-Segment HTTP Server via SYS_fork + http_client_get_url ──
lfd = syscall(41, 2, 1, 6, 0, 0, 0)
assert_true(lfd >= 0, "Created loopback listener socket")
saddr = sys_alloc(16)
mem_zero(saddr, 16)
mem_byte_write(saddr, 0, 2)
mem_byte_write(saddr, 4, 127)
mem_byte_write(saddr, 7, 1)
assert_eq(syscall(49, lfd, saddr, 16, 0, 0, 0), 0, "Bound ephemeral loopback port")
alen_ptr = sys_alloc(8)
mem_write(alen_ptr, 0, 16)
assert_eq(syscall(51, lfd, saddr, alen_ptr, 0, 0, 0), 0, "Queried assigned ephemeral port via getsockname")
port = ((mem_byte_read(saddr, 2) & 255) * 256) | (mem_byte_read(saddr, 3) & 255)
sys_free(saddr)
sys_free(alen_ptr)
assert_eq(syscall(50, lfd, 4, 0, 0, 0, 0), 0, "Listening on loopback socket")

pid = syscall(57, 0, 0, 0, 0, 0, 0)
if pid == 0
    // Child server: accept 1 HTTP request & send 32,768-byte body in segments (> 8KB!)
    cfd = syscall(43, lfd, 0, 0, 0, 0, 0)
    syscall(3, lfd, 0, 0, 0, 0, 0)
    if cfd >= 0
        rb = sys_alloc(2048)
        syscall(0, cfd, rb, 2048, 0, 0, 0)
        sys_free(rb)
        hdr = "HTTP/1.1 200 OK\r\nContent-Length: 32768\r\n\r\n"
        syscall(1, cfd, hdr, str_len(hdr), 0, 0, 0)
        blk = sys_alloc(4096)
        bi = 0
        while bi < 8
            k = 0
            while k < 4096
                mem_write_byte(blk, k, 65 + ((bi + k) % 26))
                k = k + 1
            mem_write_byte(blk, 4095, 90)
            syscall(1, cfd, blk, 4096, 0, 0, 0)
            bi = bi + 1
        sys_free(blk)
        syscall(3, cfd, 0, 0, 0, 0, 0)
    syscall(60, 0, 0, 0, 0, 0, 0)

syscall(3, lfd, 0, 0, 0, 0, 0)
url = "http://localhost:" + to_str(port) + "/big32k"
r32k = http_client_get_url(url)
st_buf = sys_alloc(8)
syscall(61, pid, st_buf, 0, 0, 0, 0)
sys_free(st_buf)
assert_true(r32k > 0, "http_client_get_url fetched 32KB multi-segment response")
assert_eq(http_response_status(r32k), 200, "32KB response status is 200")
assert_eq(http_response_body_len(r32k), 32768, "32KB multi-segment body length == 32768 (> 8KB limit gone)")
assert_eq(mem_byte_read(http_response_body_ptr(r32k), 32767), 90, "Final byte of 32KB stream == 'Z'")
http_response_free(r32k)

say "🎉 ALL SOVEREIGN HTTP CLIENT TESTS PASSED!"
