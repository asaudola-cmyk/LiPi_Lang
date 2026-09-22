// ==============================================================================
// 🧪 LIPI REGRESSION TEST: LIPIDB SOVEREIGN REDIS PROTOCOL ENGINE
// File: tests/test_lipidb_redis.lp
// Standard: Redis Serialization Protocol (RESP 2 / RESP 3)
// 100% Pure Lipi Implementation — Zero External Libs | Zero Libc
// ==============================================================================

import "universe/db/redis_protocol"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn assert_str_eq(actual, expected, msg)
  @if str_eq(actual, expected) != 1
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'"))))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI LIPIDB REDIS PROTOCOL & ENGINE REGRESSION TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── SECTION 1: RESP Serializer Frame Invariants ───────────────────────────
  println("▶ Section 1: RESP Serializer Frame Invariants...")
  total_tests = total_tests + 1

  s_ok = resp_simple_string("OK")
  ok_s1 = assert_str_eq(s_ok, "+OK\r\n", "Simple string frame (+OK\\r\\n)")

  s_err = resp_error("ERR unknown command")
  ok_s2 = assert_str_eq(s_err, "-ERR ERR unknown command\r\n", "Error frame (-ERR ...\\r\\n)")

  s_int = resp_integer(100)
  ok_s3 = assert_str_eq(s_int, ":100\r\n", "Integer frame (:100\\r\\n)")

  s_bulk = resp_bulk_string("sovereignty")
  ok_s4 = assert_str_eq(s_bulk, "$11\r\nsovereignty\r\n", "Bulk string frame ($11\\r\\nsovereignty\\r\\n)")

  s_null = resp_null_bulk()
  ok_s5 = assert_str_eq(s_null, "$-1\r\n", "Null bulk string frame ($-1\\r\\n)")

  s_arr = resp_array_header(3)
  ok_s6 = assert_str_eq(s_arr, "*3\r\n", "Array header frame (*3\\r\\n)")

  all_s1 = ok_s1 && ok_s2 && ok_s3 && ok_s4 && ok_s5 && ok_s6
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] All 6 RESP primitive wire formats verified.")
  @end

  // ── SECTION 2: Multi-Bulk Command Tokenizer ───────────────────────────────
  println("▶ Section 2: RESP Multi-Bulk Array Parser...")
  total_tests = total_tests + 1

  wire_req = "*3\r\n$3\r\nSET\r\n$11\r\nuser:1:name\r\n$6\r\nShafiu\r\n"
  tokens = resp_parse_tokens(wire_req)

  ok_t1 = assert_eq_int(tokens.len(), 3, "Parsed 3 tokens from Multi-Bulk wire")
  ok_t2 = assert_str_eq(tokens[0], "SET", "Token 0 is SET")
  ok_t3 = assert_str_eq(tokens[1], "user:1:name", "Token 1 is user:1:name")
  ok_t4 = assert_str_eq(tokens[2], "Shafiu", "Token 2 is Shafiu")

  all_s2 = ok_t1 && ok_t2 && ok_t3 && ok_t4
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Multi-Bulk RESP array tokenized accurately.")
  @end

  // ── SECTION 3: Inline Command Tokenizer (Telnet Compatibility) ───────────
  println("▶ Section 3: Inline Command Tokenizer...")
  total_tests = total_tests + 1

  inline_req = "GET user:1:name\r\n"
  tokens_in = resp_parse_tokens(inline_req)

  ok_in1 = assert_eq_int(tokens_in.len(), 2, "Parsed 2 tokens from inline wire")
  ok_in2 = assert_str_eq(tokens_in[0], "GET", "Token 0 is GET")
  ok_in3 = assert_str_eq(tokens_in[1], "user:1:name", "Token 1 is user:1:name")

  all_s3 = ok_in1 && ok_in2 && ok_in3
  @if all_s3 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Inline telnet commands parsed accurately.")
  @end

  println("")
  println("=================================================================")
  println(str_concat("🎉 TOTAL SECTIONS PASSED: ", str_concat(to_str(passed_tests), str_concat(" / ", to_str(total_tests)))))
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end

main()
