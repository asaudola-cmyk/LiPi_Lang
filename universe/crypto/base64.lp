@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: RFC 4648 BASE64 CODEC
@! Module: universe/crypto/base64
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Base64 Alphabet Table
@! ----------------------------------------------------------------------------
@fn base64_table()
  return [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
  ]
@end

@! ----------------------------------------------------------------------------
@! 2. Character Code to 6-Bit Value Decoder
@! ----------------------------------------------------------------------------
@fn base64_char_to_val(code)
  @if code >= 65 && code <= 90
    return code - 65
  @elif code >= 97 && code <= 122
    return code - 97 + 26
  @elif code >= 48 && code <= 57
    return code - 48 + 52
  @elif code == 43
    return 62
  @elif code == 47
    return 63
  @elif code == 61
    return -2 @! Padding '='
  @end
  return -1 @! Invalid / whitespace
@end

@! ----------------------------------------------------------------------------
@! 3. Base64 Encoding API (RFC 4648 Section 4)
@! ----------------------------------------------------------------------------
@fn base64_encode(data)
  tbl = base64_table()
  num_items = data.len()
  res = ""
  i = 0

  @while i + 2 < num_items
    b0 = data[i] & 255
    b1 = data[i + 1] & 255
    b2 = data[i + 2] & 255

    d0 = b0 / 4
    i0 = d0 & 63
    m0 = b0 & 3
    t0 = m0 * 16
    d1 = b1 / 16
    t1 = d1 & 15
    i1 = t0 | t1
    m1 = b1 & 15
    t2 = m1 * 4
    d2 = b2 / 64
    t3 = d2 & 3
    i2 = t2 | t3
    i3 = b2 & 63

    res = string_concat(res, string_concat(tbl[i0], string_concat(tbl[i1], string_concat(tbl[i2], tbl[i3]))))
    i = i + 3
  @end

  rem = num_items - i
  @if rem == 1
    b0 = data[i] & 255
    d0 = b0 / 4
    i0 = d0 & 63
    m0 = b0 & 3
    i1 = m0 * 16
    res = string_concat(res, string_concat(tbl[i0], string_concat(tbl[i1], "==")))
  @elif rem == 2
    b0 = data[i] & 255
    b1 = data[i + 1] & 255
    d0 = b0 / 4
    i0 = d0 & 63
    m0 = b0 & 3
    t0 = m0 * 16
    d1 = b1 / 16
    t1 = d1 & 15
    i1 = t0 | t1
    m1 = b1 & 15
    i2 = m1 * 4
    res = string_concat(res, string_concat(tbl[i0], string_concat(tbl[i1], string_concat(tbl[i2], "="))))
  @end

  return res
@end

@fn base64_encode_string(str)
  bytes = []
  num_items = str_len(str)
  i = 0
  @while i < num_items
    c = str_char_at(str, i)
    bytes = bytes.push(c & 255)
    i = i + 1
  @end
  return base64_encode(bytes)
@end

@fn base64_decode(encoded_str)
  num_items = str_len(encoded_str)
  vals = []
  i = 0
  @while i < num_items
    code = str_char_at(encoded_str, i)
    v = base64_char_to_val(code)
    @if v != -1
      vals = vals.push(v)
    @end
    i = i + 1
  @end

  out = []
  val_len = vals.len()
  j = 0
  @while j + 3 < val_len
    v0 = vals[j]
    v1 = vals[j + 1]
    v2 = vals[j + 2]
    v3 = vals[j + 3]

    @if v0 >= 0 && v1 >= 0
      t0 = v0 * 4
      d1 = v1 / 16
      t1 = d1 & 3
      val0 = t0 | t1
      b0 = val0 & 255
      out = out.push(b0)

      @if v2 >= 0
        m1 = v1 & 15
        t2 = m1 * 16
        d2 = v2 / 4
        t3 = d2 & 15
        val1 = t2 | t3
        b1 = val1 & 255
        out = out.push(b1)

        @if v3 >= 0
          m2 = v2 & 3
          t4 = m2 * 64
          t5 = v3 & 63
          val2 = t4 | t5
          b2 = val2 & 255
          out = out.push(b2)
        @end
      @end
    @end
    j = j + 4
  @end

  return out
@end

@fn base64_decode_string(encoded_str)
  bytes = base64_decode(encoded_str)
  res = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    b = bytes[i] & 255
    res = string_concat(res, str_from_char_code(b))
    i = i + 1
  @end
  return res
@end
