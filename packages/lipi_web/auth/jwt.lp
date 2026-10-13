@! ============================================================================
@! LIPI UNIVERSE WEB — RFC 7519 JSON WEB TOKEN (JWT) AUTHENTICATION (universe/web/auth/jwt.lp)
@! 100% Written in Pure Sovereign Lipi — Zero C / Libc / External Dependencies
@!
@! Standards Implemented:
@!   • RFC 7519: JSON Web Token (JWT)
@!   • RFC 2104: Keyed-Hashing for Message Authentication (HMAC-SHA256)
@!   • RFC 4648 Section 5: Base64URL with URL and Filename Safe Alphabet
@!   • RFC 6750: The OAuth 2.0 Bearer Token Usage Pattern
@! ============================================================================

import "universe/core/string"
import "universe/core/json"
import "universe/crypto/sha256"
import "universe/crypto/base64"
import "universe/web/context"

@! ----------------------------------------------------------------------------
@! 1. Base64URL Encoding & Decoding (RFC 4648 Section 5)
@! WHY: Web URLs and HTTP Authorization headers cannot safely transmit standard
@! base64 characters '+' and '/' or trailing '=' padding without URL escaping.
@! Base64URL substitutes '-' and '_' and omits trailing '=' padding.
@! ----------------------------------------------------------------------------

@fn web_jwt_str_to_bytes(s)
  bytes = []
  i = 0
  slen = str_len(s)
  @while i < slen
    ch = str_char_at(s, i)
    bytes = bytes.push(ch & 255)
    i = i + 1
  @end
  return bytes
@end

@fn web_jwt_bytes_to_str(bytes)
  res = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    b = bytes[i] & 255
    res = res + str_from_char_code(b)
    i = i + 1
  @end
  return res
@end

@! Encodes raw byte array into Base64URL unpadded string
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

@! Decodes a Base64URL string into raw bytes
@fn base64url_decode(str)
  normalized = ""
  i = 0
  slen = str_len(str)
  @while i < slen
    ch = str_char_at(str, i)
    @if ch == 45 @! '-'
      normalized = normalized + "+"
    @elif ch == 95 @! '_'
      normalized = normalized + "/"
    @else
      normalized = normalized + str_from_char_code(ch)
    @end
    i = i + 1
  @end

  rem = normalized.len() % 4
  @if rem == 2
    normalized = normalized + "=="
  @elif rem == 3
    normalized = normalized + "="
  @end

  return base64_decode(normalized)
@end

@! Decodes a Base64URL string directly into an ASCII/UTF-8 string
@fn base64url_decode_str(str)
  bytes = base64url_decode(str)
  return web_jwt_bytes_to_str(bytes)
@end

@! ----------------------------------------------------------------------------
@! 2. Pure Sovereign HMAC-SHA256 (RFC 2104 / FIPS 198-1)
@! WHY: HMAC provides cryptographic integrity and authenticity using a shared
@! secret key and two passes of SHA-256 with inner (0x36) and outer (0x5c) padding.
@! ----------------------------------------------------------------------------

@fn jwt_hmac_sha256(key_str, data_str)
  key_bytes = web_jwt_str_to_bytes(key_str)
  data_bytes = web_jwt_str_to_bytes(data_str)

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
    k_ipad = k_ipad.push(kb ^ 54)  @! 0x36
    k_opad = k_opad.push(kb ^ 92)  @! 0x5c
    i = i + 1
  @end

  inner_buf = []
  i = 0
  @while i < 64
    inner_buf = inner_buf.push(k_ipad[i])
    i = i + 1
  @end
  i = 0
  dlen = data_bytes.len()
  @while i < dlen
    inner_buf = inner_buf.push(data_bytes[i] & 255)
    i = i + 1
  @end
  inner_hash = sha256_hash_bytes(inner_buf)

  outer_buf = []
  i = 0
  @while i < 64
    outer_buf = outer_buf.push(k_opad[i])
    i = i + 1
  @end
  i = 0
  @while i < 32
    outer_buf = outer_buf.push(inner_hash[i] & 255)
    i = i + 1
  @end

  return sha256_hash_bytes(outer_buf)
@end

@! Constant-time string equality check to mitigate timing side-channel attacks
@fn jwt_constant_time_equals(a, b)
  alen = str_len(a)
  blen = str_len(b)
  @if alen != blen
    return 0
  @end

  diff = 0
  i = 0
  @while i < alen
    c1 = str_char_at(a, i)
    c2 = str_char_at(b, i)
    diff = diff | (c1 ^ c2)
    i = i + 1
  @end

  @if diff == 0
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. JWT Token Construction & Signing (RFC 7519)
@! ----------------------------------------------------------------------------

@! Creates a signed HS256 JWT from raw header and payload JSON strings
@fn jwt_sign_payload(header_json, payload_json, secret)
  hdr_bytes = web_jwt_str_to_bytes(header_json)
  pay_bytes = web_jwt_str_to_bytes(payload_json)

  enc_hdr = base64url_encode(hdr_bytes)
  enc_pay = base64url_encode(pay_bytes)

  signing_input = enc_hdr + "." + enc_pay
  sig_bytes = jwt_hmac_sha256(secret, signing_input)
  enc_sig = base64url_encode(sig_bytes)

  return signing_input + "." + enc_sig
@end

@! High-level builder to create a standard JWT for a subject with expiration
@fn jwt_create_token(subject, issuer, expire_timestamp, secret)
  header_json = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
  payload_json = "{\"sub\":\"" + subject + "\",\"iss\":\"" + issuer + "\",\"exp\":" + expire_timestamp.to_str() + "}"
  return jwt_sign_payload(header_json, payload_json, secret)
@end

@! ----------------------------------------------------------------------------
@! 4. JWT Token Verification & Claim Extraction
@! ----------------------------------------------------------------------------

@! Verifies JWT signature and structure
@fn jwt_verify(token, secret)
  p1 = str_index_of(token, ".")
  @if p1 < 0
    return 0
  @end

  rest = str_substr(token, p1 + 1, str_len(token))
  p2 = str_index_of(rest, ".")
  @if p2 < 0
    return 0
  @end

  enc_hdr = str_substr(token, 0, p1)
  enc_pay = str_substr(rest, 0, p2)
  enc_sig = str_substr(rest, p2 + 1, str_len(rest))

  signing_input = enc_hdr + "." + enc_pay
  expected_sig_bytes = jwt_hmac_sha256(secret, signing_input)
  expected_sig = base64url_encode(expected_sig_bytes)

  return jwt_constant_time_equals(enc_sig, expected_sig)
@end

@! Extracts and decodes the payload JSON string from a JWT token
@fn jwt_get_payload(token)
  p1 = str_index_of(token, ".")
  @if p1 < 0
    return ""
  @end

  rest = str_substr(token, p1 + 1, str_len(token))
  p2 = str_index_of(rest, ".")
  @if p2 < 0
    return ""
  @end

  enc_pay = str_substr(rest, 0, p2)
  return base64url_decode_str(enc_pay)
@end

@! Extracts a specific string claim from a JWT token (e.g. "sub", "iss")
@fn jwt_get_claim(token, claim_key)
  payload = jwt_get_payload(token)
  @if payload == ""
    return ""
  @end

  needle = "\"" + claim_key + "\""
  idx = str_index_of(payload, needle)
  @if idx < 0
    return ""
  @end

  pos = idx + str_len(needle)
  plen = str_len(payload)
  @while pos < plen && (str_char_at(payload, pos) == 32 || str_char_at(payload, pos) == 58)
    pos = pos + 1
  @end

  @if pos >= plen
    return ""
  @end

  ch = str_char_at(payload, pos)
  @if ch == 34  @! String value enclosed in quotes
    v_start = pos + 1
    v_end = v_start
    @while v_end < plen && str_char_at(payload, v_end) != 34
      v_end = v_end + 1
    @end
    return str_substr(payload, v_start, v_end)
  @else         @! Number or boolean
    v_start = pos
    v_end = v_start
    @while v_end < plen && str_char_at(payload, v_end) != 44 && str_char_at(payload, v_end) != 125 && str_char_at(payload, v_end) != 32
      v_end = v_end + 1
    @end
    return str_substr(payload, v_start, v_end)
  @end
@end

@! ----------------------------------------------------------------------------
@! 5. Web Context Authentication Integration (RFC 6750 & RFC 6265)
@! ----------------------------------------------------------------------------

@! Extracts bearer token from Authorization header or 'jwt' / 'token' cookie
@fn ctx_get_token(ctx)
  auth_header = ctx_get_header(ctx, "Authorization", "")
  @if starts_with(auth_header, "Bearer ") == 1
    return str_trim(str_substr(auth_header, 7, str_len(auth_header)))
  @elif starts_with(auth_header, "bearer ") == 1
    return str_trim(str_substr(auth_header, 7, str_len(auth_header)))
  @end

  @! Fallback to Cookie
  cookie_token = ctx_cookie(ctx, "jwt", "")
  @if cookie_token == ""
    cookie_token = ctx_cookie(ctx, "token", "")
  @end
  return cookie_token
@end

@! Authenticates the request context with secret; returns subject if valid, "" if invalid
@fn ctx_authenticate(ctx, secret)
  token = ctx_get_token(ctx)
  @if token == ""
    return ""
  @end

  @if jwt_verify(token, secret) == 0
    return ""
  @end

  sub = jwt_get_claim(token, "sub")
  ctx_set(ctx, "auth_user", sub)
  ctx_set(ctx, "auth_token", token)
  return sub
@end

@! Authentication Guard Middleware
@! Halts request pipeline with HTTP 401 Unauthorized if token is missing or invalid
@fn ctx_require_auth(ctx, secret)
  user = ctx_authenticate(ctx, secret)
  @if user == ""
    ctx_abort_with_json(ctx, 401, "{\"error\":\"Unauthorized\",\"message\":\"Missing or invalid cryptographic JWT bearer token\"}")
    return 0
  @end
  return 1
@end
