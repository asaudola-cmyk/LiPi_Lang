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

@fn net_u16_be(buf, off)
  b0 = buf[off] & 255
  t0 = b0 * 256
  b1 = buf[off + 1] & 255
  res = t0 | b1
  return res & 65535
@end

@fn net_u32_be(buf, off)
  b0 = buf[off] & 255
  w0 = b0 * 16777216
  b1 = buf[off + 1] & 255
  w1 = b1 * 65536
  b2 = buf[off + 2] & 255
  w2 = b2 * 256
  b3 = buf[off + 3] & 255
  r01 = w0 | w1
  r23 = w2 | b3
  res = r01 | r23
  return res & 4294967295
@end

@! ============================================================================
@! MAYA UNIVERSE NET - PURE TLS 1.3 (universe/net/tls/tls13.maya)
@! Standard: Sovereign NIST SP 800-38D AES-GCM Implementation (128/256-Bit)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/aes"

@struct TlsSession
  state: string
  session_key: string
  seq_num: i64
@end

@fn tls_session_new()
  return {
    state: "HANDSHAKE",
    session_key: "",
    seq_num: 0
  }
@end

@fn tls_string_to_bytes(s: string) -> array
  res = []
  i = 0
  num_items = str_len(s)
  @while i < num_items
    res = res.push(str_char_at(s, i) & 255)
    i = i + 1
  @end
  return res
@end

@fn tls_bytes_to_string(bytes: array) -> string
  res = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    b_v = bytes[i] & 255
    res = str_concat(res, str_from_char_code(b_v))
    i = i + 1
  @end
  return res
@end

@fn tls_normalize_key(key_bytes: array) -> array
  klen = key_bytes.len()
  res = []
  i = 0
  @if klen <= 16
    @while i < klen
      b_push = key_bytes[i]  & 255
    res = res.push(b_push)
      i = i + 1
    @end
    @while res.len() < 16
      res = res.push(0)
    @end
    return res
  @elif klen <= 32
    @while i < klen
      b_push = key_bytes[i]  & 255
    res = res.push(b_push)
      i = i + 1
    @end
    @while res.len() < 32
      res = res.push(0)
    @end
    return res
  @else
    @while i < 32
      b_push = key_bytes[i]  & 255
    res = res.push(b_push)
      i = i + 1
    @end
    return res
  @end
@end

@fn tls_normalize_iv(iv_bytes: array) -> array
  res = []
  i = 0
  ilen = iv_bytes.len()
  @while i < 12 && i < ilen
    b_push = iv_bytes[i]  & 255
    res = res.push(b_push)
    i = i + 1
  @end
  @while res.len() < 12
    res = res.push(0)
  @end
  return res
@end

@fn gcm_inc32(counter: array) -> array
  res = []
  i = 0
  @while i < 12
    b_push = counter[i]  & 255
    res = res.push(b_push)
    i = i + 1
  @end
  c_val = net_u32_be(counter, 12)
  c_val = (c_val + 1) & 4294967295
  res = res.push((c_val / 16777216) & 255)
  res = res.push((c_val / 65536) & 255)
  res = res.push((c_val / 256) & 255)
  b_push = c_val  & 255
    res = res.push(b_push)
  return res
@end

@fn ghash(h, x)
  z = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  v = []
  i = 0
  @while i < 16
    b_push = h[i] & 255
    v = v.push(b_push)
    i = i + 1
  @end

  i = 0
  @while i < 128
    byte_idx = i / 8
    bit_idx = 7 - (i % 8)
    p = maya_pow2(bit_idx)
    d = x[byte_idx] / p
    bit_set = d & 1

    @if bit_set == 1
      k = 0
      @while k < 16
        z_val = z[k] ^ v[k]
        z = list_set(z, k, z_val)
        k = k + 1
      @end
    @end

    lsb = v[15] & 1
    k = 15
    @while k > 0
      d1 = (v[k] / 2) & 127
      b_low = v[k-1] & 1
      m1 = b_low * 128
      new_v = d1 | m1
      v = list_set(v, k, new_v)
      k = k - 1
    @end
    v0_val = (v[0] / 2) & 127
    v = list_set(v, 0, v0_val)

    @if lsb == 1
      v0_red = v[0] ^ 225
      v = list_set(v, 0, v0_red)
    @end
    i = i + 1
  @end

  return z
@end

@fn ghash_blocks(h, ad_bytes, ct_bytes)
  y = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  @! Process AD blocks
  ad_len = ad_bytes.len()
  i = 0
  @while i < ad_len
    block = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    k = 0
    @while k < 16 && (i + k) < ad_len
      block = list_set(block, k, ad_bytes[i + k] & 255)
      k = k + 1
    @end
    xored = []
    k = 0
    @while k < 16
      xored = xored.push(y[k] ^ block[k])
      k = k + 1
    @end
    y = ghash(h, xored)
    i = i + 16
  @end

  @! Process Ciphertext blocks
  ct_len = ct_bytes.len()
  i = 0
  @while i < ct_len
    block = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    k = 0
    @while k < 16 && (i + k) < ct_len
      block = list_set(block, k, ct_bytes[i + k] & 255)
      k = k + 1
    @end
    xored = []
    k = 0
    @while k < 16
      xored = xored.push(y[k] ^ block[k])
      k = k + 1
    @end
    y = ghash(h, xored)
    i = i + 16
  @end

  @! Process Lengths block: len(A)*8 (64-bit) || len(C)*8 (64-bit)
  ad_bits = ad_len * 8
  ct_bits = ct_len * 8
  len_block = [
    0, 0, 0, 0,
    (ad_bits / 16777216) & 255, (ad_bits / 65536) & 255, (ad_bits / 256) & 255, ad_bits & 255,
    0, 0, 0, 0,
    (ct_bits / 16777216) & 255, (ct_bits / 65536) & 255, (ct_bits / 256) & 255, ct_bits & 255
  ]
  xored = []
  k = 0
  @while k < 16
    xored = xored.push(y[k] ^ len_block[k])
    k = k + 1
  @end
  s = ghash(h, xored)
  return s
@end

@fn tls_byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = (b / 16) & 15
  lo = b & 15
  return str_concat(hex_chars[hi], hex_chars[lo])
@end

@fn tls_bytes_to_hex(bytes)
  res = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    b_val = bytes[i] & 255
    res = str_concat(res, tls_byte_to_hex(b_val))
    i = i + 1
  @end
  return res
@end

@fn tls_hex_char_to_val(c)
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 97 && c <= 102 return c - 87 @end
  @if c >= 65 && c <= 70 return c - 55 @end
  return 0
@end

@fn tls_is_hex_string(s)
  num_items = str_len(s)
  @if num_items == 0 return 0 @end
  i = 0
  @while i < num_items
    c = str_char_at(s, i)
    is_valid = 0
    @if (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70)
      is_valid = 1
    @end
    @if is_valid == 0 return 0 @end
    i = i + 1
  @end
  return 1
@end

@fn tls_hex_to_bytes(hex_str)
  res = []
  num_items = str_len(hex_str)
  i = 0
  @while i + 1 < num_items
    hi = tls_hex_char_to_val(str_char_at(hex_str, i))
    lo = tls_hex_char_to_val(str_char_at(hex_str, i + 1))
    t0 = hi * 16
    t_val = t0 | lo
    b_val = t_val & 255
    res = res.push(b_val)
    i = i + 2
  @end
  return res
@end

@fn tls_aes_gcm_encrypt_raw(key_bytes, iv_bytes, pt_bytes, ad_bytes)
  key_norm = tls_normalize_key(key_bytes)
  iv_norm = tls_normalize_iv(iv_bytes)

  nk = 4
  nr = 10
  @if key_norm.len() == 32
    nk = 8
    nr = 14
  @end
  round_keys = aes_key_expansion(key_norm, nk, nr)

  @! Subkey H = AES_K(0^16)
  zero16 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  h = aes_encrypt_block(zero16, round_keys, nr)

  @! Initial Counter J0 = IV || 0^31 1 (for 96-bit IV)
  j0 = [
    iv_norm[0], iv_norm[1], iv_norm[2], iv_norm[3],
    iv_norm[4], iv_norm[5], iv_norm[6], iv_norm[7],
    iv_norm[8], iv_norm[9], iv_norm[10], iv_norm[11],
    0, 0, 0, 1
  ]

  @! GCTR keystream encryption starting at inc32(J0)
  cb = j0
  ct_bytes = []
  pt_len = pt_bytes.len()
  block_idx = 0
  @while block_idx < pt_len
    cb = gcm_inc32(cb)
    keystream = aes_encrypt_block(cb, round_keys, nr)
    k = 0
    @while k < 16 && (block_idx + k) < pt_len
      pt_val = pt_bytes[block_idx + k] & 255
      ct_val = pt_val ^ keystream[k]
      ct_bytes = ct_bytes.push(ct_val)
      k = k + 1
    @end
    block_idx = block_idx + 16
  @end

  @! GHASH calculation
  s = ghash_blocks(h, ad_bytes, ct_bytes)

  @! Authentication Tag T = S ^ AES_K(J0)
  j0_enc = aes_encrypt_block(j0, round_keys, nr)
  tag = []
  k = 0
  @while k < 16
    tag_val = s[k] ^ j0_enc[k]
    tag = tag.push(tag_val)
    k = k + 1
  @end

  @! Ciphertext with authentication tag appended
  out_bytes = []
  i = 0
  num_items = ct_bytes.len()
  @while i < num_items
    out_bytes = out_bytes.push(ct_bytes[i])
    i = i + 1
  @end
  i = 0
  @while i < 16
    out_bytes = out_bytes.push(tag[i])
    i = i + 1
  @end
  return out_bytes
@end

@fn tls_aes_gcm_decrypt_raw(key_bytes, iv_bytes, ct_with_tag, ad_bytes)
  total_len = ct_with_tag.len()
  @if total_len < 16
    return []
  @end

  ct_len = total_len - 16
  ct_bytes = []
  i = 0
  @while i < ct_len
    b_push = ct_with_tag[i] & 255
    ct_bytes = ct_bytes.push(b_push)
    i = i + 1
  @end

  received_tag = []
  i = ct_len
  @while i < total_len
    b_push = ct_with_tag[i] & 255
    received_tag = received_tag.push(b_push)
    i = i + 1
  @end

  key_norm = tls_normalize_key(key_bytes)
  iv_norm = tls_normalize_iv(iv_bytes)

  nk = 4
  nr = 10
  @if key_norm.len() == 32
    nk = 8
    nr = 14
  @end
  round_keys = aes_key_expansion(key_norm, nk, nr)

  @! Subkey H = AES_K(0^16)
  zero16 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  h = aes_encrypt_block(zero16, round_keys, nr)

  @! Initial Counter J0 = IV || 0^31 1
  j0 = [
    iv_norm[0], iv_norm[1], iv_norm[2], iv_norm[3],
    iv_norm[4], iv_norm[5], iv_norm[6], iv_norm[7],
    iv_norm[8], iv_norm[9], iv_norm[10], iv_norm[11],
    0, 0, 0, 1
  ]

  @! Compute expected GHASH authentication tag
  s = ghash_blocks(h, ad_bytes, ct_bytes)
  j0_enc = aes_encrypt_block(j0, round_keys, nr)
  expected_tag = []
  k = 0
  @while k < 16
    exp_val = s[k] ^ j0_enc[k]
    expected_tag = expected_tag.push(exp_val)
    k = k + 1
  @end

  @! Constant-time tag comparison
  diff = 0
  k = 0
  @while k < 16
    tag_diff = received_tag[k] ^ expected_tag[k]
    diff = diff | tag_diff
    k = k + 1
  @end
  @if diff != 0
    return [] @! Authentication failure
  @end

  @! GCTR decryption
  cb = j0
  pt_bytes = []
  block_idx = 0
  @while block_idx < ct_len
    cb = gcm_inc32(cb)
    keystream = aes_encrypt_block(cb, round_keys, nr)
    k = 0
    @while k < 16 && (block_idx + k) < ct_len
      ct_val = ct_bytes[block_idx + k] & 255
      pt_val = ct_val ^ keystream[k]
      pt_bytes = pt_bytes.push(pt_val)
      k = k + 1
    @end
    block_idx = block_idx + 16
  @end

  return pt_bytes
@end

@fn tls_aes_gcm_encrypt(key, iv, pt, ad)
  key_raw = tls_string_to_bytes(key)
  iv_raw = tls_string_to_bytes(iv)
  pt_bytes = tls_string_to_bytes(pt)
  ad_bytes = tls_string_to_bytes(ad)

  out_bytes = tls_aes_gcm_encrypt_raw(key_raw, iv_raw, pt_bytes, ad_bytes)
  return tls_bytes_to_hex(out_bytes)
@end

@fn tls_aes_gcm_decrypt(key, iv, ct, ad)
  ct_with_tag = []
  @if tls_is_hex_string(ct) == 1
    ct_with_tag = tls_hex_to_bytes(ct)
  @else
    ct_with_tag = tls_string_to_bytes(ct)
  @end

  key_raw = tls_string_to_bytes(key)
  iv_raw = tls_string_to_bytes(iv)
  ad_bytes = tls_string_to_bytes(ad)

  pt_bytes = tls_aes_gcm_decrypt_raw(key_raw, iv_raw, ct_with_tag, ad_bytes)
  @if pt_bytes.len() == 0 && ct_with_tag.len() >= 16
    return ""
  @end
  return tls_bytes_to_string(pt_bytes)
@end
