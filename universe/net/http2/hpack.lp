@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@fn pow2(n)
  return maya_pow2(n)
@end

@! ============================================================================
@! LIPI UNIVERSE NETWORKING: HPACK HEADER COMPRESSION (RFC 7541)
@! Module: universe/net/http2/hpack
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: Integer Encoding/Decoding with Prefix Bits, Static Header Table, Zero Synthetic Comments
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct HpackHeaderField
  name: string
  val: string
@end

@! ----------------------------------------------------------------------------
@! 1. HPACK Static Table (RFC 7541 Appendix A) - 61 entries
@! ----------------------------------------------------------------------------

@fn hpack_static_table() -> array
  return [
    { name: ":authority", val: "" },
    { name: ":method", val: "GET" },
    { name: ":method", val: "POST" },
    { name: ":path", val: "/" },
    { name: ":path", val: "/index.html" },
    { name: ":scheme", val: "http" },
    { name: ":scheme", val: "https" },
    { name: ":status", val: "200" },
    { name: ":status", val: "204" },
    { name: ":status", val: "206" },
    { name: ":status", val: "304" },
    { name: ":status", val: "400" },
    { name: ":status", val: "404" },
    { name: ":status", val: "500" },
    { name: "accept-charset", val: "" },
    { name: "accept-encoding", val: "gzip, deflate" },
    { name: "accept-language", val: "" },
    { name: "accept-ranges", val: "" },
    { name: "accept", val: "" },
    { name: "access-control-allow-origin", val: "" },
    { name: "age", val: "" },
    { name: "allow", val: "" },
    { name: "authorization", val: "" },
    { name: "cache-control", val: "" },
    { name: "content-disposition", val: "" },
    { name: "content-encoding", val: "" },
    { name: "content-language", val: "" },
    { name: "content-length", val: "" },
    { name: "content-location", val: "" },
    { name: "content-range", val: "" },
    { name: "content-type", val: "" },
    { name: "cookie", val: "" },
    { name: "date", val: "" },
    { name: "etag", val: "" },
    { name: "expect", val: "" },
    { name: "expires", val: "" },
    { name: "from", val: "" },
    { name: "host", val: "" },
    { name: "if-match", val: "" },
    { name: "if-modified-since", val: "" },
    { name: "if-none-match", val: "" },
    { name: "if-range", val: "" },
    { name: "if-unmodified-since", val: "" },
    { name: "last-modified", val: "" },
    { name: "link", val: "" },
    { name: "location", val: "" },
    { name: "max-forwards", val: "" },
    { name: "proxy-authenticate", val: "" },
    { name: "proxy-authorization", val: "" },
    { name: "range", val: "" },
    { name: "referer", val: "" },
    { name: "refresh", val: "" },
    { name: "retry-after", val: "" },
    { name: "server", val: "" },
    { name: "set-cookie", val: "" },
    { name: "strict-transport-security", val: "" },
    { name: "transfer-encoding", val: "" },
    { name: "user-agent", val: "" },
    { name: "vary", val: "" },
    { name: "via", val: "" },
    { name: "www-authenticate", val: "" }
  ]
@end

@! ----------------------------------------------------------------------------
@! 2. HPACK Integer Representation (RFC 7541 Section 5.1)
@! ----------------------------------------------------------------------------

@fn hpack_encode_integer(val: i64, prefix_bits: i64) -> array
  max_prefix = (pow2(prefix_bits)) - 1
  bytes = []
  @if val < max_prefix
    bytes = bytes.push(val)
    return bytes
  @end

  bytes = bytes.push(max_prefix)
  rem = val - max_prefix
  @while rem >= 128
    b = rem & 127 | 128
    bytes = bytes.push(b)
    rem = (rem / 128)
  @end
  bytes = bytes.push(rem & 127)
  return bytes
@end

@fn hpack_decode_integer(data: array, offset: i64, prefix_bits: i64) -> array
  max_prefix = (pow2(prefix_bits)) - 1
  @if offset >= data.len()
    return [0, 0]
  @end

  first_byte = data[offset] & max_prefix
  @if first_byte < max_prefix
    return [first_byte, 1]
  @end

  val = max_prefix
  shift = 0
  curr = offset + 1
  consumed = 1
  num_items = data.len()

  has_more = 1
  @while curr < num_items && has_more == 1
    b = data[curr] & 255
    consumed = consumed + 1
    p = maya_pow2(shift)
    m = b & 127
    term = m * p
    val = val + term
    shift = shift + 7
    curr = curr + 1
    @if b & 128 == 0
      has_more = 0
    @end
  @end

  return [val, consumed]
@end

@fn main()
  return 0
@end
