@! ============================================================================
@! MAYA UNIVERSE SECURITY: JSON WEB TOKEN (JWT) RFC 7519 & RFC 2104 HMAC-SHA256
@! Module: universe/security/jwt
@! 100% Pure Maya Implementation — Zero External / C Dependencies
@! Standard: RFC 7519 (JWT), RFC 2104 (HMAC), FIPS 198-1
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/crypto/base64"

@enum JwtAlg
  HS256
  RS256
  ES256
@end

@enum JwtError
  InvalidFormat
  InvalidSignature
  TokenExpired
  TokenNotYetValid
  InvalidIssuer
@end

@struct JwtClaims
  sub: string
  iss: string
  exp: i64
  nbf: i64
  iat: i64
@end

@fn jwt_str_to_bytes(s)
  bytes = []
  i = 0
  l = str_len(s)
  @while i < l
    ch = str_char_at(s, i)
    code = char_to_code(ch)
    bytes = bytes.push(code & 255)
    i = i + 1
  @end
  return bytes
@end

@fn jwt_compare_sig(sig1, sig2)
  @if str_len(sig1) != str_len(sig2)
    return 0
  @end
  @if sig1 == sig2
    return 1
  @end
  return 0
@end

@fn hmac_sha256_bytes(key_bytes, msg_bytes)
  k = []
  @if key_bytes.len() > 64
    k = sha256_hash_bytes(key_bytes)
  @else
    k = key_bytes
  @end

  @while k.len() < 64
    k = k.push(0)
  @end

  k_ipad = []
  k_opad = []
  i = 0
  @while i < 64
    kb = k[i] & 255
    k_ipad = k_ipad.push(kb ^ 54)
    k_opad = k_opad.push(kb ^ 92)
    i = i + 1
  @end

  inner_input = []
  i = 0
  @while i < 64
    inner_input = inner_input.push(k_ipad[i])
    i = i + 1
  @end
  m_len = msg_bytes.len()
  i = 0
  @while i < m_len
    inner_input = inner_input.push(msg_bytes[i] & 255)
    i = i + 1
  @end
  inner_hash = sha256_hash_bytes(inner_input)

  outer_data = []
  i = 0
  @while i < 64
    outer_data = outer_data.push(k_opad[i])
    i = i + 1
  @end
  i = 0
  @while i < 32
    outer_data = outer_data.push(inner_hash[i] & 255)
    i = i + 1
  @end

  return sha256_hash_bytes(outer_data)
@end

@fn hmac_sha256(key_bytes, msg_bytes)
  return hmac_sha256_bytes(key_bytes, msg_bytes)
@end

@fn hmac_sha256_string(secret, message)
  k_bytes = jwt_str_to_bytes(secret)
  m_bytes = jwt_str_to_bytes(message)
  return hmac_sha256_bytes(k_bytes, m_bytes)
@end

@fn base64url_encode(data)
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
    c0 = tbl[i0]
    c1 = tbl[i1]
    c2 = tbl[i2]
    c3 = tbl[i3]
    @if c0 == "+" c0 = "-" @end
    @if c0 == "/" c0 = "_" @end
    @if c1 == "+" c1 = "-" @end
    @if c1 == "/" c1 = "_" @end
    @if c2 == "+" c2 = "-" @end
    @if c2 == "/" c2 = "_" @end
    @if c3 == "+" c3 = "-" @end
    @if c3 == "/" c3 = "_" @end
    res = res + c0 + c1 + c2 + c3
    i = i + 3
  @end

  rem = num_items - i
  @if rem == 1
    b0 = data[i] & 255
    d0 = b0 / 4
    i0 = d0 & 63
    m0 = b0 & 3
    i1 = m0 * 16
    c0 = tbl[i0]
    c1 = tbl[i1]
    @if c0 == "+" c0 = "-" @end
    @if c0 == "/" c0 = "_" @end
    @if c1 == "+" c1 = "-" @end
    @if c1 == "/" c1 = "_" @end
    res = res + c0 + c1
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
    c0 = tbl[i0]
    c1 = tbl[i1]
    c2 = tbl[i2]
    @if c0 == "+" c0 = "-" @end
    @if c0 == "/" c0 = "_" @end
    @if c1 == "+" c1 = "-" @end
    @if c1 == "/" c1 = "_" @end
    @if c2 == "+" c2 = "-" @end
    @if c2 == "/" c2 = "_" @end
    res = res + c0 + c1 + c2
  @end
  return res
@end

@fn create_jwt_hs256(header_str, payload_str, secret)

  hdr_bytes = jwt_str_to_bytes(header_str)
  pay_bytes = jwt_str_to_bytes(payload_str)

  enc_header = base64url_encode(hdr_bytes)
  enc_payload = base64url_encode(pay_bytes)
  signing_input = enc_header + "." + enc_payload

  key_bytes = jwt_str_to_bytes(secret)
  input_bytes = jwt_str_to_bytes(signing_input)
  sig_bytes = hmac_sha256_bytes(key_bytes, input_bytes)
  enc_sig = base64url_encode(sig_bytes)

  return signing_input + "." + enc_sig
@end

@fn verify_jwt_hs256(token, secret)
  parts = string_split(token, ".")
  @if parts.len() != 3
    return 0
  @end

  signing_input = parts[0] + "." + parts[1]
  key_bytes = jwt_str_to_bytes(secret)
  input_bytes = jwt_str_to_bytes(signing_input)
  expected_sig_bytes = hmac_sha256_bytes(key_bytes, input_bytes)
  expected_sig = base64url_encode(expected_sig_bytes)

  @if jwt_compare_sig(parts[2], expected_sig) == 1
    return 1
  @end
  return 0
@end

@fn jwt_sign(header_str, payload_str, secret)
  return create_jwt_hs256(header_str, payload_str, secret)
@end

@fn jwt_verify(token, secret)
  return verify_jwt_hs256(token, secret)
@end




