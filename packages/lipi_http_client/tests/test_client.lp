// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Sovereign HTTP/1.1 Client Unit Test
// ==============================================================================

include "packages/lipi_http_client/src/http_client.lp"

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

mem_free(buf_200, 32)

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

say "🎉 ALL SOVEREIGN HTTP CLIENT TESTS PASSED!"
