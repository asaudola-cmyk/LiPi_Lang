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
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: FIPS 180-1 SHA-1
@! Module: universe/crypto/sha1
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. 32-Bit Bitwise Left Rotation (FIPS 180-1 Section 3)
@! ----------------------------------------------------------------------------
@fn sha1_rotl(x, n)
  v = x % 4294967296
  p1 = maya_pow2(n)
  p2 = maya_pow2(32 - n)
  t1 = (v * p1) % 4294967296
  t2 = (v / p2) % 4294967296
  res = t1 | t2
  return res % 4294967296
@end

@! ----------------------------------------------------------------------------
@! 2. 64-Byte Block Compression Transform (FIPS 180-1 Section 5)
@! ----------------------------------------------------------------------------
@fn sha1_transform(state, block)
  w = []
  i = 0
  @while i < 16
    idx = i * 4
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
    w_item = w_val % 4294967296
    w = w.push(w_item)
    i = i + 1
  @end

  @while i < 80
    temp_w = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
    w_val = sha1_rotl(temp_w, 1)
    w = w.push(w_val)
    i = i + 1
  @end

  a = state[0] % 4294967296
  b = state[1] % 4294967296
  c = state[2] % 4294967296
  d = state[3] % 4294967296
  e = state[4] % 4294967296

  i = 0
  @while i < 80
    f = 0
    k = 0
    @if i < 20
      not_b = ~b
      t1 = b & c
      t2 = not_b & d
      f = t1 | t2
      k = 1518500249 @! 0x5A827999
    @elif i < 40
      f = b ^ c ^ d
      k = 1859775393 @! 0x6ED9EBA1
    @elif i < 60
      t1 = b & c
      t2 = b & d
      t3 = c & d
      f = t1 | t2 | t3
      k = 2400959708 @! 0x8F1BBCDC
    @else
      f = b ^ c ^ d
      k = 3395469782 @! 0xCA62C1D6
    @end
    f = f % 4294967296
    temp = (sha1_rotl(a, 5) + f + e + k + w[i]) % 4294967296
    e = d
    d = c
    c = sha1_rotl(b, 30)
    b = a
    a = temp
    i = i + 1
  @end

  state = list_set(state, 0, (state[0] + a) % 4294967296)
  state = list_set(state, 1, (state[1] + b) % 4294967296)
  state = list_set(state, 2, (state[2] + c) % 4294967296)
  state = list_set(state, 3, (state[3] + d) % 4294967296)
  state = list_set(state, 4, (state[4] + e) % 4294967296)
  return state
@end

@! ----------------------------------------------------------------------------
@! 3. Streaming Incremental Hash API
@! ----------------------------------------------------------------------------
@struct Sha1Context
  state: array
  count: i64
  buffer: array
@end

@fn sha1_init()
  return {
    state: [
      1732584193, @! 0x67452301
      4023233417, @! 0xEFCDAB89
      2562383102, @! 0x98BADCFE
      271733878,  @! 0x10325476
      3285377520  @! 0xC3D2E1F0
    ],
    count: 0,
    buffer: []
  }
@end

@fn sha1_update(ctx, data)
  num_items = data.len()
  i = 0
  @while i < num_items
    b = data[i] & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 64
      ctx.state = sha1_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha1_update_string(ctx, str)
  num_items = str_len(str)
  i = 0
  @while i < num_items
    b = str_char_at(str, i) & 255
    ctx.buffer = ctx.buffer.push(b)
    ctx.count = ctx.count + 1
    @if ctx.buffer.len() == 64
      ctx.state = sha1_transform(ctx.state, ctx.buffer)
      ctx.buffer = []
    @end
    i = i + 1
  @end
  return ctx
@end

@fn sha1_final(ctx)
  total_bytes = ctx.count
  total_bits = total_bytes * 8

  @! 1. Append bit '1' (0x80 = 128)
  ctx.buffer = ctx.buffer.push(128)

  @! 2. If buffer exceeds 56 bytes, pad to 64, transform, and start new block
  @if ctx.buffer.len() > 56
    @while ctx.buffer.len() < 64
      ctx.buffer = ctx.buffer.push(0)
    @end
    ctx.state = sha1_transform(ctx.state, ctx.buffer)
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
  ctx.state = sha1_transform(ctx.state, ctx.buffer)
  ctx.buffer = []

  @! 6. Emit 20-byte digest array
  digest = []
  i = 0
  @while i < 5
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
@! 4. One-Shot Hashing and Hexadecimal Formatting API
@! ----------------------------------------------------------------------------
@fn sha1_hash_bytes(data)
  ctx = sha1_init()
  ctx = sha1_update(ctx, data)
  return sha1_final(ctx)
@end

@fn sha1_hash_string(str)
  ctx = sha1_init()
  ctx = sha1_update_string(ctx, str)
  return sha1_final(ctx)
@end

@fn sha1_byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = ((b / 16)) % 16
  lo = b % 16
  return str_concat(hex_chars[hi], hex_chars[lo])
@end

@fn sha1_hex(data)
  digest = sha1_hash_bytes(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    byte_val = digest[i] & 255
    h_str = sha1_byte_to_hex(byte_val)
    res = str_concat(res, h_str)
    i = i + 1
  @end
  return res
@end

@fn sha1_hex_string(data)
  digest = sha1_hash_string(data)
  res = ""
  i = 0
  num_items = digest.len()
  @while i < num_items
    byte_val = digest[i] & 255
    h_str = sha1_byte_to_hex(byte_val)
    res = str_concat(res, h_str)
    i = i + 1
  @end
  return res
@end
