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

@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: FIPS 180-4 SHA-256
@! Module: universe/crypto/sha256
@! 100% Pure Lipi Implementation - Zero External / C Dependencies
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. SHA-256 Round Constants K[0..63] (Cube roots of first 64 primes mod 2^32)
@! ----------------------------------------------------------------------------
@fn sha256_k()
  return [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]
@end

@! ----------------------------------------------------------------------------
@! 2. 32-Bit Bitwise Logical Operations (FIPS 180-4 Section 4.1.2)
@! ----------------------------------------------------------------------------
@fn sha256_rotr(x, n)
  v = x % 4294967296
  p1 = maya_pow2(n)
  p2 = maya_pow2(32 - n)
  t1 = (v / p1) % 4294967296
  t2 = (v * p2) % 4294967296
  res = t1 | t2
  return res % 4294967296
@end

@fn right_rotate(x, n)
  return sha256_rotr(x, n)
@end

@fn sha256_ch(x, y, z)
  not_x = ~x
  t1 = x & y
  t2 = not_x & z
  t3 = t1 ^ t2
  return t3 % 4294967296
@end

@fn sha256_maj(x, y, z)
  t1 = x & y
  t2 = x & z
  t3 = y & z
  res = t1 ^ t2 ^ t3
  return res % 4294967296
@end

@fn sha256_sigma0(x)
  t1 = sha256_rotr(x, 2)
  t2 = sha256_rotr(x, 13)
  t3 = sha256_rotr(x, 22)
  res = t1 ^ t2 ^ t3
  return res % 4294967296
@end

@fn sha256_sigma1(x)
  t1 = sha256_rotr(x, 6)
  t2 = sha256_rotr(x, 11)
  t3 = sha256_rotr(x, 25)
  res = t1 ^ t2 ^ t3
  return res % 4294967296
@end

@fn sha256_gamma0(x)
  t1 = sha256_rotr(x, 7)
  t2 = sha256_rotr(x, 18)
  t3 = (x / 8) % 4294967296
  res = t1 ^ t2 ^ t3
  return res % 4294967296
@end

@fn sha256_gamma1(x)
  t1 = sha256_rotr(x, 17)
  t2 = sha256_rotr(x, 19)
  t3 = (x / 1024) % 4294967296
  res = t1 ^ t2 ^ t3
  return res % 4294967296
@end

@fn sha256_s0(x)
  return sha256_gamma0(x)
@end

@fn sha256_s1(x)
  return sha256_gamma1(x)
@end

@fn sha256_big_s0(x)
  return sha256_sigma0(x)
@end

@fn sha256_big_s1(x)
  return sha256_sigma1(x)
@end

@! ----------------------------------------------------------------------------
@! 3. 64-Byte Block Compression Transform (FIPS 180-4 Section 6.2.2)
@! ----------------------------------------------------------------------------
@fn sha256_transform(state, block)
  w = []
  i = 0
  @while i < 16
    idx = i * 4
    @if idx + 3 >= block.len()
      @end
    b0 = block[idx] & 255
    b1 = block[idx + 1] & 255
    b2 = block[idx + 2] & 255
    b3 = block[idx + 3] & 255
    w0 = b0 * 16777216
    w1 = b1 * 65536
    w2 = b2 * 256
    w01 = w0 | w1
    w23 = w2 | b3
    w_val = w01 | w23
    w = w.push(w_val % 4294967296)
    i = i + 1
  @end

  @while i < 64
    s0 = sha256_gamma0(w[i - 15])
    s1 = sha256_gamma1(w[i - 2])
    w_val = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
    w = w.push(w_val)
    i = i + 1
  @end
  a = state[0] % 4294967296
  b = state[1] % 4294967296
  c = state[2] % 4294967296
  d = state[3] % 4294967296
  e = state[4] % 4294967296
  f = state[5] % 4294967296
  g = state[6] % 4294967296
  h = state[7] % 4294967296

  k = sha256_k()

  i = 0
  @while i < 64
    t1 = (h + sha256_sigma1(e) + sha256_ch(e, f, g) + k[i] + w[i]) % 4294967296
    t2 = (sha256_sigma0(a) + sha256_maj(a, b, c)) % 4294967296

    h = g
    g = f
    f = e
    e = (d + t1) % 4294967296
    d = c
    c = b
    b = a
    a = (t1 + t2) % 4294967296

    i = i + 1
  @end

  state = list_set(state, 0, (state[0] + a) % 4294967296)
  state = list_set(state, 1, (state[1] + b) % 4294967296)
  state = list_set(state, 2, (state[2] + c) % 4294967296)
  state = list_set(state, 3, (state[3] + d) % 4294967296)
  state = list_set(state, 4, (state[4] + e) % 4294967296)
  state = list_set(state, 5, (state[5] + f) % 4294967296)
  state = list_set(state, 6, (state[6] + g) % 4294967296)
  state = list_set(state, 7, (state[7] + h) % 4294967296)
  return state
@end

@! ----------------------------------------------------------------------------
@! 4. Streaming Incremental Hash API
@! ----------------------------------------------------------------------------
@struct Sha256Context
  state: array
  count: i64
  buffer: array
@end

@fn sha256_init()
  return {
    state: [
      1779033703, 3144134277, 1013904242, 2773480762,
      1359893119, 2600822924, 528734635, 1541459225
    ],
    count: 0,
    buffer: []
  }
@end

@fn sha256_update(ctx, data)
  @if data == 0 return ctx @end
  // WHY: Native is_str reliably identifies string literals and heap strings via STR0 tags
  @if is_str(data) == 1
    return sha256_update_string(ctx, data)
  @end
  num_items = data.len()
  i = 0
  @while i < num_items
    b = data[i] & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 64
      ctx.state = sha256_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha256_update_string(ctx, str)
  num_items = str_len(str)
  i = 0
  @while i < num_items
    // WHY: str[i] uses compiler indexer which extracts the exact byte at index i without string concatenation
    b = str[i] & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 64
      ctx.state = sha256_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha256_final(ctx)
  total_bytes = ctx.count
  total_bits = total_bytes * 8

  @! 1. Append bit '1' (0x80 = 128)
  ctx.buffer = ctx.buffer.push(128)

  @! 2. If buffer exceeds 56 bytes, pad to 64, transform, and start new block
  @if ctx.buffer.len() > 56
    @while ctx.buffer.len() < 64
      ctx.buffer = ctx.buffer.push(0)
    @end
    ctx.state = sha256_transform(ctx.state, ctx.buffer)
    ctx.buffer = []
  @end

  @! 3. Zero-pad up to 56 bytes
  @while ctx.buffer.len() < 56
    ctx.buffer = ctx.buffer.push(0)
  @end

  @! 4. Append 64-bit big-endian original bit length (8 bytes)
  ctx.buffer = ctx.buffer.push((total_bits / 72057594037927936) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 281474976710656) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 1099511627776) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 4294967296) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 16777216) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 65536) & 255)
  ctx.buffer = ctx.buffer.push((total_bits / 256) & 255)
  ctx.buffer = ctx.buffer.push(total_bits & 255)

  @! 5. Transform final 64-byte block
  ctx.state = sha256_transform(ctx.state, ctx.buffer)
  ctx.buffer = []

  @! 6. Emit 32-byte digest array
  digest = []
  i = 0
  @while i < 8
    word = ctx.state[i] % 4294967296
    digest = digest.push((word / 16777216) & 255)
    digest = digest.push((word / 65536) & 255)
    digest = digest.push((word / 256) & 255)
    digest = digest.push(word & 255)
    i = i + 1
  @end
  return digest
@end

@! ----------------------------------------------------------------------------
@! 5. One-Shot Hashing and Hexadecimal Formatting API
@! ----------------------------------------------------------------------------
@fn sha256_hash_bytes(data)
  ctx = sha256_init()
  ctx = sha256_update(ctx, data)
  return sha256_final(ctx)
@end

@fn sha256_hash_string(str)
  ctx = sha256_init()
  ctx = sha256_update_string(ctx, str)
  return sha256_final(ctx)
@end

@fn sha256_byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = ((b / 16)) % 16
  lo = b % 16
  return str_concat(hex_chars[hi], hex_chars[lo])
@end

@fn sha256_hex(data)
  digest = sha256_hash_bytes(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    byte_val = digest[i] & 255
    h_str = sha256_byte_to_hex(byte_val)
    res = str_concat(res, h_str)
    i = i + 1
  @end
  return res
@end

@fn sha256_hex_string(data)
  digest = sha256_hash_string(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    byte_val = digest[i] & 255
    h_str = sha256_byte_to_hex(byte_val)
    res = str_concat(res, h_str)
    i = i + 1
  @end
  return res
@end

