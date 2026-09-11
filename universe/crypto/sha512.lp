import "universe/core/collections"
@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: FIPS 180-4 / RFC 6234 SHA-512
@! Module: universe/crypto/sha512
@! 100% Pure Lipi Implementation - Portable 64-Bit Word Pair [hi, lo] Arithmetic
@! Zero External / C Dependencies
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. 64-Bit Word Representation & Arithmetic (Pair of 32-bit unsigned halves)
@! Word = [hi, lo] where 0 <= hi, lo <= 4294967295 (0xFFFFFFFF)
@! ----------------------------------------------------------------------------

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

@fn w64_new(hi, lo)
  return [hi % 4294967296, lo % 4294967296]
@end

@fn w64_add(a, b)
  a1 = a[1] % 4294967296
  b1 = b[1] % 4294967296
  lo_sum = a1 + b1
  carry = lo_sum / 4294967296
  a0 = a[0] % 4294967296
  b0 = b[0] % 4294967296
  hi_sum = (a0 + b0 + carry) % 4294967296
  return [hi_sum, lo_sum % 4294967296]
@end

@fn w64_add4(a, b, c, d)
  return w64_add(w64_add(a, b), w64_add(c, d))
@end

@fn w64_add5(a, b, c, d, e)
  return w64_add(w64_add4(a, b, c, d), e)
@end

@fn w64_xor(a, b)
  t0 = a[0] ^ b[0]
  x0 = t0 % 4294967296
  t1 = a[1] ^ b[1]
  x1 = t1 % 4294967296
  return [x0, x1]
@end

@fn w64_xor3(a, b, c)
  return w64_xor(w64_xor(a, b), c)
@end

@fn w64_and(a, b)
  a0 = a[0] & b[0]
  a1 = a[1] & b[1]
  return [a0 % 4294967296, a1 % 4294967296]
@end

@fn w64_or(a, b)
  o0 = a[0] | b[0]
  o1 = a[1] | b[1]
  return [o0 % 4294967296, o1 % 4294967296]
@end

@fn w64_not(a)
  n0 = ~a[0]
  n1 = ~a[1]
  return [n0 % 4294967296, n1 % 4294967296]
@end

@fn w64_rotr(x, n)
  @if n == 0 return [x[0] % 4294967296, x[1] % 4294967296] @end
  @if n == 32 return [x[1] % 4294967296, x[0] % 4294967296] @end
  @if n < 32
    p1 = maya_pow2(n)
    p2 = maya_pow2(32 - n)
    t1 = (x[0] / p1) % 4294967296
    t2 = (x[1] * p2) % 4294967296
    t_hi = t1 | t2
    hi = t_hi % 4294967296
    t3 = (x[1] / p1) % 4294967296
    t4 = (x[0] * p2) % 4294967296
    t_lo = t3 | t4
    lo = t_lo % 4294967296
    return [hi, lo]
  @end
  m = n - 32
  p1 = maya_pow2(m)
  p2 = maya_pow2(32 - m)
  t1 = (x[1] / p1) % 4294967296
  t2 = (x[0] * p2) % 4294967296
  t_hi = t1 | t2
    hi = t_hi % 4294967296
  t3 = (x[0] / p1) % 4294967296
  t4 = (x[1] * p2) % 4294967296
  t_lo = t3 | t4
    lo = t_lo % 4294967296
  return [hi, lo]
@end

@fn w64_shr(x, n)
  @if n == 0 return [x[0] % 4294967296, x[1] % 4294967296] @end
  @if n == 32 return [0, x[0] % 4294967296] @end
  @if n < 32
    p1 = maya_pow2(n)
    p2 = maya_pow2(32 - n)
    hi = (x[0] / p1) % 4294967296
    t1 = (x[1] / p1) % 4294967296
    t2 = (x[0] * p2) % 4294967296
    t_lo = t1 | t2
    lo = t_lo % 4294967296
    return [hi, lo]
  @end
  m = n - 32
  p1 = maya_pow2(m)
  hi = 0
  lo = (x[0] / p1) % 4294967296
  return [hi, lo]
@end

@fn sha512_ch(x, y, z)
  @! Ch(x, y, z) = (x AND y) XOR (NOT x AND z)
  return w64_xor(w64_and(x, y), w64_and(w64_not(x), z))
@end

@fn sha512_maj(x, y, z)
  @! Maj(x, y, z) = (x AND y) XOR (x AND z) XOR (y AND z)
  return w64_xor3(w64_and(x, y), w64_and(x, z), w64_and(y, z))
@end

@fn sha512_sigma0(x)
  @! Sigma0(x) = ROTR28(x) XOR ROTR34(x) XOR ROTR39(x)
  return w64_xor3(w64_rotr(x, 28), w64_rotr(x, 34), w64_rotr(x, 39))
@end

@fn sha512_sigma1(x)
  @! Sigma1(x) = ROTR14(x) XOR ROTR18(x) XOR ROTR41(x)
  return w64_xor3(w64_rotr(x, 14), w64_rotr(x, 18), w64_rotr(x, 41))
@end

@fn sha512_gamma0(x)
  @! gamma0(x) = ROTR1(x) XOR ROTR8(x) XOR SHR7(x)
  return w64_xor3(w64_rotr(x, 1), w64_rotr(x, 8), w64_shr(x, 7))
@end

@fn sha512_gamma1(x)
  @! gamma1(x) = ROTR19(x) XOR ROTR61(x) XOR SHR6(x)
  return w64_xor3(w64_rotr(x, 19), w64_rotr(x, 61), w64_shr(x, 6))
@end

@! ----------------------------------------------------------------------------
@! 3. SHA-512 Round Constants K[0..79]
@! ----------------------------------------------------------------------------
@fn sha512_k()
  return [
    [0x428a2f98, 0xd728ae22], [0x71374491, 0x23ef65cd], [0xb5c0fbcf, 0xec4d3b2f], [0xe9b5dba5, 0x8189dbbc],
    [0x3956c25b, 0xf348b538], [0x59f111f1, 0xb605d019], [0x923f82a4, 0xaf194f9b], [0xab1c5ed5, 0xda6d8118],
    [0xd807aa98, 0xa3030242], [0x12835b01, 0x45706fbe], [0x243185be, 0x4ee4b28c], [0x550c7dc3, 0xd5ffb4e2],
    [0x72be5d74, 0xf27b896f], [0x80deb1fe, 0x3b1696b1], [0x9bdc06a7, 0x25c71235], [0xc19bf174, 0xcf692694],
    [0xe49b69c1, 0x9ef14ad2], [0xefbe4786, 0x384f25e3], [0x0fc19dc6, 0x8b8cd5b5], [0x240ca1cc, 0x77ac9c65],
    [0x2de92c6f, 0x592b0275], [0x4a7484aa, 0x6ea6e483], [0x5cb0a9dc, 0xbd41fbd4], [0x76f988da, 0x831153b5],
    [0x983e5152, 0xee66dfab], [0xa831c66d, 0x2db43210], [0xb00327c8, 0x98fb213f], [0xbf597fc7, 0xbeef0ee4],
    [0xc6e00bf3, 0x3da88fc2], [0xd5a79147, 0x930aa725], [0x06ca6351, 0xe003826f], [0x14292967, 0x0a0e6e70],
    [0x27b70a85, 0x46d22ffc], [0x2e1b2138, 0x5c26c926], [0x4d2c6dfc, 0x5ac42aed], [0x53380d13, 0x9d95b3df],
    [0x650a7354, 0x8baf63de], [0x766a0abb, 0x3c77b2a8], [0x81c2c92e, 0x47edaee6], [0x92722c85, 0x1482353b],
    [0xa2bfe8a1, 0x4cf10364], [0xa81a664b, 0xbc423001], [0xc24b8b70, 0xd0f89791], [0xc76c51a3, 0x0654be30],
    [0xd192e819, 0xd6ef5218], [0xd6990624, 0x5565a910], [0xf40e3585, 0x5771202a], [0x106aa070, 0x32bbd1b8],
    [0x19a4c116, 0xb8d2d0c8], [0x1e376c08, 0x5141ab53], [0x2748774c, 0xdf8eeb99], [0x34b0bcb5, 0xe19b48a8],
    [0x391c0cb3, 0xc5c95a63], [0x4ed8aa4a, 0xe3418acb], [0x5b9cca4f, 0x7763e373], [0x682e6ff3, 0xd6b2b8a3],
    [0x748f82ee, 0x5defb2fc], [0x78a5636f, 0x43172f60], [0x84c87814, 0xa1f0ab72], [0x8cc70208, 0x1a6439ec],
    [0x90befffa, 0x23631e28], [0xa4506ceb, 0xde82bde9], [0xbef9a3f7, 0xb2c67915], [0xc67178f2, 0xe372532b],
    [0xca273ece, 0xea26619c], [0xd186b8c7, 0x21c0c207], [0xeada7dd6, 0xcde0eb1e], [0xf57d4f7f, 0xee6ed178],
    [0x06f067aa, 0x72176fba], [0x0a637dc5, 0xa2c898a6], [0x113f9804, 0xbef90dae], [0x1b710b35, 0x131c471b],
    [0x28db77f5, 0x23047d84], [0x32caab7b, 0x40c72493], [0x3c9ebe0a, 0x15c9bebc], [0x431d67c4, 0x9c100d4c],
    [0x4cc5d4be, 0xcb3e42b6], [0x597f299c, 0xfc657e2a], [0x5fcb6fab, 0x3ad6faec], [0x6c44198c, 0x4a475817]
  ]
@end

@! ----------------------------------------------------------------------------
@! 4. SHA-512 Block Compression Transform (128-byte block, 80 rounds)
@! ----------------------------------------------------------------------------
@fn sha512_transform(state, block)
  w = []
  i = 0
  @while i < 16
    idx = i * 8
    b0 = block[idx] & 255
    b1 = block[idx + 1] & 255
    b2 = block[idx + 2] & 255
    b3 = block[idx + 3] & 255
    b4 = block[idx + 4] & 255
    b5 = block[idx + 5] & 255
    b6 = block[idx + 6] & 255
    b7 = block[idx + 7] & 255

    w0 = b0 * 16777216
    w1 = b1 * 65536
    w2 = b2 * 256
    r01 = w0 | w1
    r23 = w2 | b3
    hi = r01 | r23

    w4 = b4 * 16777216
    w5 = b5 * 65536
    w6 = b6 * 256
    r45 = w4 | w5
    r67 = w6 | b7
    lo = r45 | r67
    w = w.push([hi, lo])
    i = i + 1
  @end

  @while i < 80
    s0 = sha512_gamma0(w[i - 15])
    s1 = sha512_gamma1(w[i - 2])
    w_val = w64_add4(w[i - 16], s0, w[i - 7], s1)
    w = w.push(w_val)
    i = i + 1
  @end

  a = [state[0][0], state[0][1]]
  b = [state[1][0], state[1][1]]
  c = [state[2][0], state[2][1]]
  d = [state[3][0], state[3][1]]
  e = [state[4][0], state[4][1]]
  f = [state[5][0], state[5][1]]
  g = [state[6][0], state[6][1]]
  h = [state[7][0], state[7][1]]

  k = sha512_k()

  i = 0
  @while i < 80
    t1 = w64_add5(h, sha512_sigma1(e), sha512_ch(e, f, g), k[i], w[i])
    t2 = w64_add(sha512_sigma0(a), sha512_maj(a, b, c))

    h = g
    g = f
    f = e
    e = w64_add(d, t1)
    d = c
    c = b
    b = a
    a = w64_add(t1, t2)

    i = i + 1
  @end

  state = list_set(state, 0, w64_add(state[0], a))
  state = list_set(state, 1, w64_add(state[1], b))
  state = list_set(state, 2, w64_add(state[2], c))
  state = list_set(state, 3, w64_add(state[3], d))
  state = list_set(state, 4, w64_add(state[4], e))
  state = list_set(state, 5, w64_add(state[5], f))
  state = list_set(state, 6, w64_add(state[6], g))
  state = list_set(state, 7, w64_add(state[7], h))

  return state
@end

@! ----------------------------------------------------------------------------
@! 5. Streaming Incremental Hash API
@! ----------------------------------------------------------------------------
@struct Sha512Context
  state: array
  count: i64
  buffer: array
@end

@fn sha512_init()
  return {
    state: [
      [0x6a09e667, 0xf3bcc908],
      [0xbb67ae85, 0x84caa73b],
      [0x3c6ef372, 0xfe94f82b],
      [0xa54ff53a, 0x5f1d36f1],
      [0x510e527f, 0xade682d1],
      [0x9b05688c, 0x2b3e6c1f],
      [0x1f83d9ab, 0xfb41bd6b],
      [0x5be0cd19, 0x137e2179]
    ],
    count: 0,
    buffer: []
  }
@end

@fn sha512_update(ctx, data)
  num_items = data.len()
  i = 0
  @while i < num_items
    b = data[i] & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 128
      ctx.state = sha512_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha512_update_string(ctx, str)
  num_items = str_len(str)
  i = 0
  @while i < num_items
    b = str_char_at(str, i) & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 128
      ctx.state = sha512_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha512_final(ctx)
  total_bytes = ctx.count
  
  @! total_bits represented across two 64-bit halves (hi_bits, lo_bits)
  @! lo_bits = (total_bytes * 8) mod 2^64
  lo_bits = total_bytes * 8
  hi_bits = 0
  @if total_bytes > 2305843009213693951
    hi_bits = total_bytes / 2305843009213693952
  @end

  @! 1. Append bit '1' (0x80 = 128)
  ctx.buffer = ctx.buffer.push(128)

  @! 2. If buffer exceeds 112 bytes, pad to 128, transform, and start new block
  @if ctx.buffer.len() > 112
    @while ctx.buffer.len() < 128
      ctx.buffer = ctx.buffer.push(0)
    @end
    ctx.state = sha512_transform(ctx.state, ctx.buffer)
    ctx.buffer = []
  @end

  @! 3. Zero-pad up to 112 bytes
  @while ctx.buffer.len() < 112
    ctx.buffer = ctx.buffer.push(0)
  @end

  @! 4. Append 128-bit big-endian original bit length (16 bytes)
  @! High 8 bytes (hi_bits)
  ctx.buffer = ctx.buffer.push((hi_bits / 72057594037927936) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 281474976710656) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 1099511627776) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 4294967296) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 16777216) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 65536) & 255)
  ctx.buffer = ctx.buffer.push((hi_bits / 256) & 255)
  ctx.buffer = ctx.buffer.push(hi_bits & 255)

  @! Low 8 bytes (lo_bits)
  ctx.buffer = ctx.buffer.push((lo_bits / 72057594037927936) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 281474976710656) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 1099511627776) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 4294967296) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 16777216) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 65536) & 255)
  ctx.buffer = ctx.buffer.push((lo_bits / 256) & 255)
  ctx.buffer = ctx.buffer.push(lo_bits & 255)

  @! 5. Transform final 128-byte block
  ctx.state = sha512_transform(ctx.state, ctx.buffer)
  ctx.buffer = []

  @! 6. Emit 64-byte digest array
  digest = []
  i = 0
  @while i < 8
    hi = ctx.state[i][0] % 4294967296
    lo = ctx.state[i][1] % 4294967296

    digest = digest.push((hi / 16777216) & 255)
    digest = digest.push((hi / 65536) & 255)
    digest = digest.push((hi / 256) & 255)
    digest = digest.push(hi & 255)

    digest = digest.push((lo / 16777216) & 255)
    digest = digest.push((lo / 65536) & 255)
    digest = digest.push((lo / 256) & 255)
    digest = digest.push(lo & 255)

    i = i + 1
  @end
  return digest
@end

@! ----------------------------------------------------------------------------
@! 6. One-Shot Hashing and Hexadecimal Formatting API
@! ----------------------------------------------------------------------------
@fn sha512_hash_bytes(data)
  ctx = sha512_init()
  ctx = sha512_update(ctx, data)
  return sha512_final(ctx)
@end

@fn sha512_hash_string(str)
  ctx = sha512_init()
  ctx = sha512_update_string(ctx, str)
  return sha512_final(ctx)
@end

@fn sha512_byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = ((b / 16)) % 16
  lo = b % 16
  return str_concat(hex_chars[hi], hex_chars[lo])
@end

@fn sha512_hex(data)
  digest = sha512_hash_bytes(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    bv = digest[i] & 255
    h_val = sha512_byte_to_hex(bv)
    res = str_concat(res, h_val)
    i = i + 1
  @end
  return res
@end

@fn sha512_hex_string(data)
  digest = sha512_hash_string(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    bv = digest[i] & 255
    h_val = sha512_byte_to_hex(bv)
    res = str_concat(res, h_val)
    i = i + 1
  @end
  return res
@end
