// ==============================================================================
// 💾 LIPI SOVEREIGN REDIS PROTOCOL ENGINE (RESP 2 / RESP 3)
// Module: universe/db/redis_protocol.lp
// Standard: Redis Serialization Protocol Specification (RFC compliant)
// 100% Pure Lipi Implementation — Zero Libc | Zero External Dependencies
// ==============================================================================
//
// WHY: Redis is the de facto universal in-memory data store protocol. By implementing
// standard RESP directly in pure Lipi machine code, Lipi applications can act as
// drop-in sovereign database servers reachable by redis-cli, Jedis, go-redis,
// redis-py, and any standard ecosystem client over pure TCP sockets.
//
// RESP Data Types:
//   '+' -> Simple String: "+OK\r\n"
//   '-' -> Error: "-ERR message\r\n"
//   ':' -> Integer: ":1000\r\n"
//   '$' -> Bulk String: "$6\r\nfoobar\r\n" or "$-1\r\n" (Null Bulk String)
//   '*' -> Array: "*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n"

import "universe/core/string"
import "universe/core/collections"

// ── 1. RESP Serializers ───────────────────────────────────────────────────────

@fn resp_crlf()
  // WHY: Standard RESP protocol delimiter carriage return linefeed (\r\n)
  return "\r\n"
@end

@fn resp_simple_string(str_val: string)
  // WHY: Emits lightweight status replies (+OK, +PONG) with minimal wire overhead
  return str_concat("+", str_concat(str_val, resp_crlf()))
@end

@fn resp_error(err_msg: string)
  // WHY: Standard error response prefix ensures client-side exception bubbling
  return str_concat("-ERR ", str_concat(err_msg, resp_crlf()))
@end

@fn resp_integer(val: i64)
  // WHY: Emits 64-bit integer values (:0, :1, :42) for counters and status codes
  return str_concat(":", str_concat(to_str(val), resp_crlf()))
@end

@fn resp_bulk_string(str_val: string)
  // WHY: Emits length-prefixed binary safe bulk strings ($<len>\r\n<data>\r\n)
  len_str = to_str(str_len(str_val))
  hdr = str_concat("$", str_concat(len_str, resp_crlf()))
  return str_concat(hdr, str_concat(str_val, resp_crlf()))
@end

@fn resp_null_bulk()
  // WHY: Signifies non-existent key lookup in GET/HGET commands (nil in redis-cli)
  return "$-1\r\n"
@end

@fn resp_array_header(count: i64)
  // WHY: Prefixes multi-element RESP responses (*<count>\r\n)
  return str_concat("*", str_concat(to_str(count), resp_crlf()))
@end

@fn resp_empty_array()
  return "*0\r\n"
@end

// ── 2. RESP Deserializer & Command Tokenizer ──────────────────────────────────
// WHY: Robustly decodes incoming wire buffers into an array of string tokens.
// Handles both RESP Multi-Bulk (*N\r\n$len\r\n...) and raw telnet inline commands.

@fn resp_parse_tokens(raw_req: string)
  tokens = []
  raw_len = str_len(raw_req)
  @if raw_len == 0
    return tokens
  @end

  // Check if request is RESP Array (*N\r\n...)
  first_char = str_char_at(raw_req, 0)
  @if first_char == 42 // ASCII '*'
    // RESP Array Format
    lines = str_split(raw_req, "\r\n")
    idx = 1
    total_lines = lines.len()
    @while idx < total_lines
      line = lines[idx]
      l_len = str_len(line)
      @if l_len > 0
        ch = str_char_at(line, 0)
        @if ch == 36 // ASCII '$' (Bulk string header)
          // Next line contains the actual argument string
          idx = idx + 1
          @if idx < total_lines
            arg_val = lines[idx]
            tokens = tokens.push(arg_val)
          @end
        @end
      @end
      idx = idx + 1
    @end
    return tokens
  @end

  // Fallback: Inline command format (e.g. "SET user:1 John\r\n")
  clean_req = str_trim(raw_req)
  // Replace carriage return if any
  clean_req = str_replace(clean_req, "\r", "")
  clean_req = str_replace(clean_req, "\n", "")

  // Split by whitespace
  parts = str_split(clean_req, " ")
  i = 0
  n_parts = parts.len()
  @while i < n_parts
    p = str_trim(parts[i])
    @if str_len(p) > 0
      tokens = tokens.push(p)
    @end
    i = i + 1
  @end

  return tokens
@end
