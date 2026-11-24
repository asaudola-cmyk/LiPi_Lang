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
@! LIPI UNIVERSE NET - PURE TLS 1.3 (utso/net/tls/tls13.lp)
@! Standard: Sovereign NIST SP 800-38D AES-GCM Implementation (128/256-Bit)
@! ============================================================================

import "utso/core/collections"
import "utso/core/string"
import "utso/crypto/sha256"
import "utso/crypto/sha512"
import "utso/crypto/aes"
import "utso/crypto/x25519"
import "utso/crypto/ed25519"
import "utso/crypto/p256_ecdsa"
import "utso/crypto/rsa"
import "utso/crypto/x509"

g_tls13_custom_init = 0
g_tls13_custom_roots = 0
g_tls13_sys_store = 0
g_tls13_sys_loaded = 0
g_tls13_disable_sys = 0

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
  num_items = bytes.len()
  @if num_items <= 0 return "" @end
  b = buf_new(num_items)
  i = 0
  @while i < num_items
    buf_write_byte(b, bytes[i] & 255)
    i = i + 1
  @end
  res = buf_to_str(b)
  buf_free(b)
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
    p = lipi_pow2(bit_idx)
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

@fn tls_append_bytes(dest, src)
  @! WHY: Appends bytes from src array to dest array without modifying original
  i = 0
  n = src.len()
  @while i < n
    dest = dest.push(src[i] & 255)
    i = i + 1
  @end
  return dest
@end

@struct TlsClientHello
  wire_bytes: array
  client_random: array
  client_pub_key: array
  server_name: string
@end

@fn tls13_build_client_hello(server_name, client_pub_key)
  @! WHY: Serializes standard RFC 8446 TLS 1.3 ClientHello handshake message with
  @! Supported Versions (0x002B), Supported Groups (X25519 0x001D), Key Share (0x0033),
  @! and SNI (0x0000) extensions for sovereign HTTPS connections.

  // 1. Client Random (32 bytes strictly from kernel CSPRNG SYS_getrandom 318 — fail closed on error)
  c_rand = []
  rng_buf = alloc(32)
  rng_ok = syscall(318, rng_buf, 32, 0, 0, 0, 0)
  @if rng_ok != 32
    free(rng_buf)
    return {
      wire_bytes: [],
      client_random: [],
      client_pub_key: client_pub_key,
      server_name: server_name
    }
  @end
  r_i = 0
  @while r_i < 32
    c_rand = c_rand.push(mem_byte_read(rng_buf, r_i) & 255)
    r_i = r_i + 1
  @end
  free(rng_buf)

  // 2. ClientHello Body
  ch_body = []
  // Legacy version: 0x0303 (TLS 1.2 compatibility)
  ch_body = ch_body.push(3)
  ch_body = ch_body.push(3)

  // 32-byte Client Random
  ch_body = tls_append_bytes(ch_body, c_rand)

  // Legacy Session ID (32 bytes)
  ch_body = ch_body.push(32)
  s_i = 0
  @while s_i < 32
    ch_body = ch_body.push(s_i & 255)
    s_i = s_i + 1
  @end

  // Cipher Suites (Length: 6 bytes = 3 suites: 0x1301 AES-128-GCM-SHA256, 0x1302 AES-256-GCM-SHA384, 0x1303 ChaCha20-Poly1305-SHA256)
  ch_body = ch_body.push(0)
  ch_body = ch_body.push(6)
  ch_body = ch_body.push(19) // 0x1301
  ch_body = ch_body.push(1)
  ch_body = ch_body.push(19) // 0x1302
  ch_body = ch_body.push(2)
  ch_body = ch_body.push(19) // 0x1303
  ch_body = ch_body.push(3)

  // Legacy Compression Methods (Length: 1 byte = 0x00 null compression)
  ch_body = ch_body.push(1)
  ch_body = ch_body.push(0)

  // Extensions Block
  ext_bytes = []

  // Ext 1: Server Name Indication (SNI) - Type 0x0000
  sn_len = str_len(server_name)
  @if sn_len > 0
    ext_bytes = ext_bytes.push(0)
    ext_bytes = ext_bytes.push(0)
    sni_data_len = 5 + sn_len
    ext_bytes = ext_bytes.push((sni_data_len / 256) & 255)
    ext_bytes = ext_bytes.push(sni_data_len & 255)
    list_len = 3 + sn_len
    ext_bytes = ext_bytes.push((list_len / 256) & 255)
    ext_bytes = ext_bytes.push(list_len & 255)
    ext_bytes = ext_bytes.push(0)
    ext_bytes = ext_bytes.push((sn_len / 256) & 255)
    ext_bytes = ext_bytes.push(sn_len & 255)
    si = 0
    @while si < sn_len
      ext_bytes = ext_bytes.push(str_char_at(server_name, si) & 255)
      si = si + 1
    @end
  @end

  // Ext 2: Supported Versions - Type 0x002B (43)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(43)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(3)
  ext_bytes = ext_bytes.push(2)
  ext_bytes = ext_bytes.push(3)
  ext_bytes = ext_bytes.push(4) // TLS 1.3

  // Ext 3: Supported Groups - Type 0x000A (10)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(10)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(4)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(2)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(29) // X25519

  // Ext 4: Key Share - Type 0x0033 (51)
  klen = client_pub_key.len()
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(51)
  ks_ext_len = 6 + klen
  ext_bytes = ext_bytes.push((ks_ext_len / 256) & 255)
  ext_bytes = ext_bytes.push(ks_ext_len & 255)
  cs_list_len = 4 + klen
  ext_bytes = ext_bytes.push((cs_list_len / 256) & 255)
  ext_bytes = ext_bytes.push(cs_list_len & 255)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(29) // X25519
  ext_bytes = ext_bytes.push((klen / 256) & 255)
  ext_bytes = ext_bytes.push(klen & 255)
  ext_bytes = tls_append_bytes(ext_bytes, client_pub_key)

  // Ext 5: Signature Algorithms - Type 0x000D (13): P-256/P-384 ECDSA, RSA-PSS-SHA256/384, Ed25519
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(13)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(12)
  ext_bytes = ext_bytes.push(0)
  ext_bytes = ext_bytes.push(10)
  ext_bytes = ext_bytes.push(4)
  ext_bytes = ext_bytes.push(3)
  ext_bytes = ext_bytes.push(5)
  ext_bytes = ext_bytes.push(3)
  ext_bytes = ext_bytes.push(8)
  ext_bytes = ext_bytes.push(4)
  ext_bytes = ext_bytes.push(8)
  ext_bytes = ext_bytes.push(5)
  ext_bytes = ext_bytes.push(8)
  ext_bytes = ext_bytes.push(7)

  // Append extensions length and extensions body
  ext_tot_len = ext_bytes.len()
  ch_body = ch_body.push((ext_tot_len / 256) & 255)
  ch_body = ch_body.push(ext_tot_len & 255)
  ch_body = tls_append_bytes(ch_body, ext_bytes)

  // 3. Handshake Header (4 bytes): Type 0x01 (ClientHello), 3-byte length
  hs_msg = []
  hs_msg = hs_msg.push(1) // ClientHello
  ch_body_len = ch_body.len()
  hs_msg = hs_msg.push((ch_body_len / 65536) & 255)
  hs_msg = hs_msg.push((ch_body_len / 256) & 255)
  hs_msg = hs_msg.push(ch_body_len & 255)
  hs_msg = tls_append_bytes(hs_msg, ch_body)

  // 4. TLS Record Layer Framing (5 bytes): ContentType 0x16 (Handshake), Version 0x0301 (TLS 1.0 legacy)
  wire = []
  wire = wire.push(22) // 0x16 Handshake
  wire = wire.push(3)  // Legacy Record Version TLS 1.0 (0x0301)
  wire = wire.push(1)
  hs_len = hs_msg.len()
  wire = wire.push((hs_len / 256) & 255)
  wire = wire.push(hs_len & 255)
  wire = tls_append_bytes(wire, hs_msg)

  return {
    wire_bytes: wire,
    client_random: c_rand,
    client_pub_key: client_pub_key,
    server_name: server_name
  }
@end

@fn tls13_hmac_sha256(key_bytes, msg_bytes)
  @! WHY: Genuine RFC 2104 HMAC-SHA-256 keyed hash construction over FIPS 180-4 SHA-256.
  k_len = key_bytes.len()
  k0 = []
  @if k_len > 64
    k0 = sha256_hash_bytes(key_bytes)
  @else
    ki = 0
    @while ki < k_len
      k0 = k0.push(key_bytes[ki] & 255)
      ki = ki + 1
    @end
  @end
  @while k0.len() < 64
    k0 = k0.push(0)
  @end

  inner = []
  outer = []
  bi = 0
  @while bi < 64
    kb = k0[bi] & 255
    inner = inner.push(kb ^ 54)
    outer = outer.push(kb ^ 92)
    bi = bi + 1
  @end

  mi = 0
  m_len = msg_bytes.len()
  @while mi < m_len
    inner = inner.push(msg_bytes[mi] & 255)
    mi = mi + 1
  @end
  inner_digest = sha256_hash_bytes(inner)

  di = 0
  @while di < inner_digest.len()
    outer = outer.push(inner_digest[di] & 255)
    di = di + 1
  @end
  return sha256_hash_bytes(outer)
@end

@fn tls13_hkdf_extract(salt_bytes, ikm_bytes)
  @! WHY: Authentic RFC 5869 / RFC 8446 Section 7.1 HKDF-Extract(salt, IKM) -> HMAC-SHA256(salt, IKM)
  salt = salt_bytes
  @if salt.len() == 0
    salt = []
    zi = 0
    @while zi < 32
      salt = salt.push(0)
      zi = zi + 1
    @end
  @end
  return tls13_hmac_sha256(salt, ikm_bytes)
@end

@fn tls13_hkdf_expand_label(secret_bytes, label_str, context_bytes, out_len)
  @! WHY: Authentic RFC 8446 Section 7.1 HKDF-Expand-Label using RFC 5869 HMAC-SHA256 expansion.
  info = []
  info = info.push((out_len / 256) & 255)
  info = info.push(out_len & 255)
  full_label = "tls13 " + label_str
  fl_len = str_len(full_label)
  info = info.push(fl_len & 255)
  li = 0
  @while li < fl_len
    info = info.push(str_char_at(full_label, li) & 255)
    li = li + 1
  @end
  c_len = context_bytes.len()
  info = info.push(c_len & 255)
  ci = 0
  @while ci < c_len
    info = info.push(context_bytes[ci] & 255)
    ci = ci + 1
  @end

  okm = []
  t_prev = []
  counter = 1
  @while okm.len() < out_len
    inp = []
    ti = 0
    @while ti < t_prev.len()
      inp = inp.push(t_prev[ti] & 255)
      ti = ti + 1
    @end
    ii = 0
    @while ii < info.len()
      inp = inp.push(info[ii] & 255)
      ii = ii + 1
    @end
    inp = inp.push(counter & 255)
    t_prev = tls13_hmac_sha256(secret_bytes, inp)
    oi = 0
    @while oi < t_prev.len() && okm.len() < out_len
      okm = okm.push(t_prev[oi] & 255)
      oi = oi + 1
    @end
    counter = counter + 1
  @end
  return okm
@end

@fn tls13_derive_handshake_keys(shared_secret_bytes, transcript_hash_bytes)
  @! WHY: Derives TLS 1.3 Early Secret, Handshake Secret, Client/Server Handshake Traffic Secrets,
  @! and AEAD key (16 bytes) + IV (12 bytes) per RFC 8446 Section 7.1.
  zero_salt = []
  zi = 0
  @while zi < 32
    zero_salt = zero_salt.push(0)
    zi = zi + 1
  @end
  early_secret = tls13_hkdf_extract(zero_salt, zero_salt)
  empty_hash = sha256_hash_bytes([])
  derived_secret = tls13_hkdf_expand_label(early_secret, "derived", empty_hash, 32)
  hs_secret = tls13_hkdf_extract(derived_secret, shared_secret_bytes)
  c_hs_traffic = tls13_hkdf_expand_label(hs_secret, "c hs traffic", transcript_hash_bytes, 32)
  s_hs_traffic = tls13_hkdf_expand_label(hs_secret, "s hs traffic", transcript_hash_bytes, 32)
  c_key = tls13_hkdf_expand_label(c_hs_traffic, "key", [], 16)
  c_iv  = tls13_hkdf_expand_label(c_hs_traffic, "iv", [], 12)
  s_key = tls13_hkdf_expand_label(s_hs_traffic, "key", [], 16)
  s_iv  = tls13_hkdf_expand_label(s_hs_traffic, "iv", [], 12)
  return {
    handshake_secret: hs_secret,
    client_handshake_traffic_secret: c_hs_traffic,
    server_handshake_traffic_secret: s_hs_traffic,
    client_write_key: c_key,
    client_write_iv: c_iv,
    server_write_key: s_key,
    server_write_iv: s_iv
  }
@end

@fn tls13_hmac_sha384(key_bytes, msg_bytes)
  @! WHY: RFC 2104 HMAC-SHA-384 (block_size = 128 bytes) for TLS_AES_256_GCM_SHA384 (0x1302).
  k_len = key_bytes.len()
  k0 = []
  @if k_len > 128
    k0 = sha384_hash_bytes(key_bytes)
  @else
    ki = 0
    @while ki < k_len
      k0 = k0.push(key_bytes[ki] & 255)
      ki = ki + 1
    @end
  @end
  @while k0.len() < 128
    k0 = k0.push(0)
  @end

  inner = []
  outer = []
  bi = 0
  @while bi < 128
    kb = k0[bi] & 255
    inner = inner.push(kb ^ 54)
    outer = outer.push(kb ^ 92)
    bi = bi + 1
  @end
  inner = tls_append_bytes(inner, msg_bytes)
  inner_hash = sha384_hash_bytes(inner)
  outer = tls_append_bytes(outer, inner_hash)
  return sha384_hash_bytes(outer)
@end

@fn tls13_hkdf_extract_384(salt_bytes, ikm_bytes)
  salt = salt_bytes
  @if salt.len() == 0
    salt = []
    zi = 0
    @while zi < 48
      salt = salt.push(0)
      zi = zi + 1
    @end
  @end
  return tls13_hmac_sha384(salt, ikm_bytes)
@end

@fn tls13_hkdf_expand_label_384(secret_bytes, label_str, context_bytes, out_len)
  info = []
  info = info.push((out_len / 256) & 255)
  info = info.push(out_len & 255)
  full_label = "tls13 " + label_str
  fl_len = str_len(full_label)
  info = info.push(fl_len & 255)
  li = 0
  @while li < fl_len
    info = info.push(str_char_at(full_label, li) & 255)
    li = li + 1
  @end
  c_len = context_bytes.len()
  info = info.push(c_len & 255)
  ci = 0
  @while ci < c_len
    info = info.push(context_bytes[ci] & 255)
    ci = ci + 1
  @end

  okm = []
  t_prev = []
  counter = 1
  @while okm.len() < out_len
    inp = []
    ti = 0
    @while ti < t_prev.len()
      inp = inp.push(t_prev[ti] & 255)
      ti = ti + 1
    @end
    ii = 0
    @while ii < info.len()
      inp = inp.push(info[ii] & 255)
      ii = ii + 1
    @end
    inp = inp.push(counter & 255)
    t_prev = tls13_hmac_sha384(secret_bytes, inp)
    oi = 0
    @while oi < t_prev.len() && okm.len() < out_len
      okm = okm.push(t_prev[oi] & 255)
      oi = oi + 1
    @end
    counter = counter + 1
  @end
  return okm
@end

@fn tls13_derive_handshake_keys_384(shared_secret_bytes, transcript_hash_bytes)
  zero48 = []
  zi = 0
  @while zi < 48
    zero48 = zero48.push(0)
    zi = zi + 1
  @end
  early_secret = tls13_hkdf_extract_384(zero48, zero48)
  empty_hash = sha384_hash_bytes([])
  derived_secret = tls13_hkdf_expand_label_384(early_secret, "derived", empty_hash, 48)
  hs_secret = tls13_hkdf_extract_384(derived_secret, shared_secret_bytes)
  c_hs_traffic = tls13_hkdf_expand_label_384(hs_secret, "c hs traffic", transcript_hash_bytes, 48)
  s_hs_traffic = tls13_hkdf_expand_label_384(hs_secret, "s hs traffic", transcript_hash_bytes, 48)
  c_key = tls13_hkdf_expand_label_384(c_hs_traffic, "key", [], 32)
  c_iv  = tls13_hkdf_expand_label_384(c_hs_traffic, "iv", [], 12)
  s_key = tls13_hkdf_expand_label_384(s_hs_traffic, "key", [], 32)
  s_iv  = tls13_hkdf_expand_label_384(s_hs_traffic, "iv", [], 12)
  return {
    handshake_secret: hs_secret,
    client_handshake_traffic_secret: c_hs_traffic,
    server_handshake_traffic_secret: s_hs_traffic,
    client_write_key: c_key,
    client_write_iv: c_iv,
    server_write_key: s_key,
    server_write_iv: s_iv
  }
@end

@fn _tls_rotl32(v, n)
  uv = v & 4294967295
  return ((uv << n) | (uv >> (32 - n))) & 4294967295
@end

@fn _tls_u32_le(arr, off)
  b0 = arr[off] & 255
  b1 = arr[off + 1] & 255
  b2 = arr[off + 2] & 255
  b3 = arr[off + 3] & 255
  return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
@end

@fn _tls_chacha_qr(s, a, b, c, d)
  s[a] = (s[a] + s[b]) & 4294967295
  s[d] = _tls_rotl32(s[d] ^ s[a], 16)
  s[c] = (s[c] + s[d]) & 4294967295
  s[b] = _tls_rotl32(s[b] ^ s[c], 12)
  s[a] = (s[a] + s[b]) & 4294967295
  s[d] = _tls_rotl32(s[d] ^ s[a], 8)
  s[c] = (s[c] + s[d]) & 4294967295
  s[b] = _tls_rotl32(s[b] ^ s[c], 7)
  return 0
@end

@fn _tls_chacha_block(key32, nonce12, counter)
  st = [
    1634760805, 857760878, 2036477234, 1797285236,
    _tls_u32_le(key32, 0), _tls_u32_le(key32, 4), _tls_u32_le(key32, 8), _tls_u32_le(key32, 12),
    _tls_u32_le(key32, 16), _tls_u32_le(key32, 20), _tls_u32_le(key32, 24), _tls_u32_le(key32, 28),
    counter & 4294967295, _tls_u32_le(nonce12, 0), _tls_u32_le(nonce12, 4), _tls_u32_le(nonce12, 8)
  ]
  w = []
  i = 0
  @while i < 16
    w = w.push(st[i])
    i = i + 1
  @end
  r = 0
  @while r < 10
    _tls_chacha_qr(w, 0, 4, 8, 12)
    _tls_chacha_qr(w, 1, 5, 9, 13)
    _tls_chacha_qr(w, 2, 6, 10, 14)
    _tls_chacha_qr(w, 3, 7, 11, 15)
    _tls_chacha_qr(w, 0, 5, 10, 15)
    _tls_chacha_qr(w, 1, 6, 11, 12)
    _tls_chacha_qr(w, 2, 7, 8, 13)
    _tls_chacha_qr(w, 3, 4, 9, 14)
    r = r + 1
  @end
  out = []
  i = 0
  @while i < 16
    word = (w[i] + st[i]) & 4294967295
    out = out.push(word & 255)
    out = out.push((word >> 8) & 255)
    out = out.push((word >> 16) & 255)
    out = out.push((word >> 24) & 255)
    i = i + 1
  @end
  return out
@end

@fn _tls_poly1305_tag(msg, key64)
  t0 = _tls_u32_le(key64, 0) & 268435455
  t1 = _tls_u32_le(key64, 4) & 268435452
  t2 = _tls_u32_le(key64, 8) & 268435452
  t3 = _tls_u32_le(key64, 12) & 268435452

  r0 = t0 & 67108863
  r1 = ((t0 >> 26) | ((t1 & 1048575) << 6)) & 67108863
  r2 = ((t1 >> 20) | ((t2 & 16383) << 12)) & 67108863
  r3 = ((t2 >> 14) | ((t3 & 255) << 18)) & 67108863
  r4 = (t3 >> 8) & 67108863

  s1 = r1 * 5
  s2 = r2 * 5
  s3 = r3 * 5
  s4 = r4 * 5

  h0 = 0
  h1 = 0
  h2 = 0
  h3 = 0
  h4 = 0

  mlen = msg.len()
  pos = 0
  @while pos < mlen
    blk = []
    k = 0
    @while k < 16
      @if pos + k < mlen
        blk = blk.push(msg[pos + k] & 255)
      @else
        blk = blk.push(0)
      @end
      k = k + 1
    @end
    rem = mlen - pos
    hib = 16777216
    @if rem < 16
      hib = 0
      blk = list_set(blk, rem, 1)
    @end

    m0 = _tls_u32_le(blk, 0)
    m1 = _tls_u32_le(blk, 4)
    m2 = _tls_u32_le(blk, 8)
    m3 = _tls_u32_le(blk, 12)

    h0 = h0 + (m0 & 67108863)
    h1 = h1 + (((m0 >> 26) | ((m1 & 1048575) << 6)) & 67108863)
    h2 = h2 + (((m1 >> 20) | ((m2 & 16383) << 12)) & 67108863)
    h3 = h3 + (((m2 >> 14) | ((m3 & 255) << 18)) & 67108863)
    h4 = h4 + ((m3 >> 8) | hib)

    d0 = (h0 * r0) + (h1 * s4) + (h2 * s3) + (h3 * s2) + (h4 * s1)
    d1 = (h0 * r1) + (h1 * r0) + (h2 * s4) + (h3 * s3) + (h4 * s2)
    d2 = (h0 * r2) + (h1 * r1) + (h2 * r0) + (h3 * s4) + (h4 * s3)
    d3 = (h0 * r3) + (h1 * r2) + (h2 * r1) + (h3 * r0) + (h4 * s4)
    d4 = (h0 * r4) + (h1 * r3) + (h2 * r2) + (h3 * r1) + (h4 * r0)

    c = d0 >> 26
    h0 = d0 & 67108863
    d1 = d1 + c
    c = d1 >> 26
    h1 = d1 & 67108863
    d2 = d2 + c
    c = d2 >> 26
    h2 = d2 & 67108863
    d3 = d3 + c
    c = d3 >> 26
    h3 = d3 & 67108863
    d4 = d4 + c
    c = d4 >> 26
    h4 = d4 & 67108863
    h0 = h0 + (c * 5)
    c = h0 >> 26
    h0 = h0 & 67108863
    h1 = h1 + c
    pos = pos + 16
  @end

  c = h1 >> 26
  h1 = h1 & 67108863
  h2 = h2 + c
  c = h2 >> 26
  h2 = h2 & 67108863
  h3 = h3 + c
  c = h3 >> 26
  h3 = h3 & 67108863
  h4 = h4 + c
  c = h4 >> 26
  h4 = h4 & 67108863
  h0 = h0 + (c * 5)
  c = h0 >> 26
  h0 = h0 & 67108863
  h1 = h1 + c

  g0 = h0 + 5
  c = g0 >> 26
  g0 = g0 & 67108863
  g1 = h1 + c
  c = g1 >> 26
  g1 = g1 & 67108863
  g2 = h2 + c
  c = g2 >> 26
  g2 = g2 & 67108863
  g3 = h3 + c
  c = g3 >> 26
  g3 = g3 & 67108863
  g4 = h4 + c - 67108864

  // Constant-time select: if g4 < 0 (borrow set), mask = 0 else 0x3ffffff
  neg = (g4 >> 63) & 1
  mask = 0 - (1 - neg)
  nmask = 0 - neg
  h0 = (g0 & mask) | (h0 & nmask)
  h1 = (g1 & mask) | (h1 & nmask)
  h2 = (g2 & mask) | (h2 & nmask)
  h3 = (g3 & mask) | (h3 & nmask)
  h4 = (g4 & mask) | (h4 & nmask)

  f0 = ((h0 | (h1 << 26)) & 4294967295) + _tls_u32_le(key64, 16)
  f1 = (((h1 >> 6) | (h2 << 20)) & 4294967295) + _tls_u32_le(key64, 20) + (f0 >> 32)
  f2 = (((h2 >> 12) | (h3 << 14)) & 4294967295) + _tls_u32_le(key64, 24) + (f1 >> 32)
  f3 = (((h3 >> 18) | (h4 << 8)) & 4294967295) + _tls_u32_le(key64, 28) + (f2 >> 32)

  fw = [f0 & 4294967295, f1 & 4294967295, f2 & 4294967295, f3 & 4294967295]
  tag = []
  wi = 0
  @while wi < 4
    wv = fw[wi]
    tag = tag.push(wv & 255)
    tag = tag.push((wv >> 8) & 255)
    tag = tag.push((wv >> 16) & 255)
    tag = tag.push((wv >> 24) & 255)
    wi = wi + 1
  @end
  return tag
@end

@fn _tls_build_poly1305_aead_input(ad_bytes, ct_bytes)
  inp = tls_append_bytes([], ad_bytes)
  @while (inp.len() % 16) != 0
    inp = inp.push(0)
  @end
  inp = tls_append_bytes(inp, ct_bytes)
  @while (inp.len() % 16) != 0
    inp = inp.push(0)
  @end
  al = ad_bytes.len()
  cl = ct_bytes.len()
  k = 0
  @while k < 8
    inp = inp.push((al >> (k * 8)) & 255)
    k = k + 1
  @end
  k = 0
  @while k < 8
    inp = inp.push((cl >> (k * 8)) & 255)
    k = k + 1
  @end
  return inp
@end

@fn tls_chacha20_poly1305_encrypt_raw(key32, iv12, pt_bytes, ad_bytes)
  poly_key = _tls_chacha_block(key32, iv12, 0)
  ct = []
  n = pt_bytes.len()
  ctr = 1
  pos = 0
  @while pos < n
    ks = _tls_chacha_block(key32, iv12, ctr)
    j = 0
    @while j < 64 && (pos + j) < n
      ct = ct.push((pt_bytes[pos + j] & 255) ^ ks[j])
      j = j + 1
    @end
    pos = pos + 64
    ctr = ctr + 1
  @end
  mac_in = _tls_build_poly1305_aead_input(ad_bytes, ct)
  tag = _tls_poly1305_tag(mac_in, poly_key)
  return tls_append_bytes(ct, tag)
@end

@fn tls_chacha20_poly1305_decrypt_raw(key32, iv12, ct_with_tag, ad_bytes)
  tot = ct_with_tag.len()
  @if tot < 16 return [] @end
  ct_len = tot - 16
  ct = []
  i = 0
  @while i < ct_len
    ct = ct.push(ct_with_tag[i] & 255)
    i = i + 1
  @end
  poly_key = _tls_chacha_block(key32, iv12, 0)
  mac_in = _tls_build_poly1305_aead_input(ad_bytes, ct)
  expected_tag = _tls_poly1305_tag(mac_in, poly_key)

  diff = 0
  k = 0
  @while k < 16
    diff = diff | ((ct_with_tag[ct_len + k] & 255) ^ expected_tag[k])
    k = k + 1
  @end
  @if diff != 0 return [] @end

  pt = []
  ctr = 1
  pos = 0
  @while pos < ct_len
    ks = _tls_chacha_block(key32, iv12, ctr)
    j = 0
    @while j < 64 && (pos + j) < ct_len
      pt = pt.push(ct[pos + j] ^ ks[j])
      j = j + 1
    @end
    pos = pos + 64
    ctr = ctr + 1
  @end
  return pt
@end

@fn _tls_ascii_lower(ch)
  @if ch >= 65 && ch <= 90 return ch + 32 @end
  return ch
@end

@fn _tls_is_hostname_byte(b)
  @if b >= 97 && b <= 122 return 1 @end
  @if b >= 65 && b <= 90 return 1 @end
  @if b >= 48 && b <= 57 return 1 @end
  @if b == 45 || b == 46 || b == 95 return 1 @end
  return 0
@end

@fn _tls_match_dns_name(cert_name, expected_sni)
  cl = cert_name.len()
  sl = str_len(expected_sni)
  @if cl == 0 || sl == 0 return 0 @end
  // Exact case-insensitive match
  @if cl == sl
    ok = 1
    i = 0
    @while i < cl
      @if _tls_ascii_lower(cert_name[i] & 255) != _tls_ascii_lower(str_char_at(expected_sni, i) & 255)
        ok = 0
        break
      @end
      i = i + 1
    @end
    @if ok == 1 return 1 @end
  @end
  // RFC 6125 single-label wildcard "*."
  @if cl >= 3 && cert_name[0] == 42 && cert_name[1] == 46
    suffix_len = cl - 2
    @if sl > suffix_len
      dot_pos = str_index_of(expected_sni, ".")
      @if dot_pos > 0 && (sl - dot_pos - 1) == suffix_len
        ok = 1
        i = 0
        @while i < suffix_len
          @if _tls_ascii_lower(cert_name[2 + i] & 255) != _tls_ascii_lower(str_char_at(expected_sni, dot_pos + 1 + i) & 255)
            ok = 0
            break
          @end
          i = i + 1
        @end
        @if ok == 1 return 1 @end
      @end
    @end
  @end
  return 0
@end

@fn _tls_der_read_len(buf, off)
  n = buf.len()
  @if off >= n return [0, 0, n] @end
  b = buf[off] & 255
  @if b < 128
    return [off + 1, b, off + 1 + b]
  @end
  nbytes = b & 127
  @if nbytes == 0 || nbytes > 4 || off + 1 + nbytes > n
    return [0, 0, n]
  @end
  lval = 0
  k = 0
  @while k < nbytes
    lval = (lval * 256) + (buf[off + 1 + k] & 255)
    k = k + 1
  @end
  v_off = off + 1 + nbytes
  @if v_off + lval > n return [0, 0, n] @end
  return [v_off, lval, v_off + lval]
@end

@fn _tls_find_byte_seq(buf, seq, start_pos, end_pos)
  sl = seq.len()
  @if sl == 0 || start_pos < 0 return -1 @end
  i = start_pos
  @while i + sl <= end_pos
    ok = 1
    j = 0
    @while j < sl
      @if (buf[i + j] & 255) != (seq[j] & 255)
        ok = 0
        break
      @end
      j = j + 1
    @end
    @if ok == 1 return i @end
    i = i + 1
  @end
  return -1
@end

@fn tls13_add_trust_root(root_der_bytes)
  @if g_tls13_custom_init == 0
    g_tls13_custom_roots = []
    g_tls13_custom_init = 1
  @end
  parsed = x509_decode_full(root_der_bytes)
  @if parsed.x5f_valid != 1 return 0 @end
  g_tls13_custom_roots = g_tls13_custom_roots.push(parsed)
  return 1
@end

@fn tls13_clear_custom_trust_roots()
  g_tls13_custom_roots = []
  g_tls13_custom_init = 1
  return 1
@end

@fn tls13_set_system_roots_enabled(flag)
  @if flag == 0
    g_tls13_disable_sys = 1
  @else
    g_tls13_disable_sys = 0
  @end
  return 1
@end

@fn _tls13_read_env_var(target_name)
  // WHY: Reads an environment variable (e.g. SSL_CERT_FILE) directly from /proc/self/environ
  // with zero extra module imports so portable CA bundles work on any Linux distro/container.
  fd = syscall(2, "/proc/self/environ", 0, 0, 0, 0, 0)
  @if fd < 0 return "" @end
  raw = buf_new(4096)
  tmp = alloc(4096)
  @if tmp > 0
    @while 1 == 1
      nr = syscall(0, fd, tmp, 4096, 0, 0, 0)
      @if nr <= 0 break @end
      buf_write_mem(raw, tmp, nr)
    @end
    free(tmp)
  @end
  syscall(3, fd, 0, 0, 0, 0, 0)
  total = buf_len(raw)
  base = buf_ptr(raw)
  tlen = str_len(target_name)
  found_val = ""
  pos = 0
  @while pos < total
    start = pos
    eq_pos = 0 - 1
    @while pos < total
      b = mem_byte_read(base, pos) & 255
      @if b == 0 break @end
      @if b == 61 && eq_pos < 0
        eq_pos = pos
      @end
      pos = pos + 1
    @end
    @if eq_pos > start && (eq_pos - start) == tlen
      matched = 1
      k = 0
      @while k < tlen
        @if (mem_byte_read(base, start + k) & 255) != (mem_byte_read(target_name, k) & 255)
          matched = 0
          break
        @end
        k = k + 1
      @end
      @if matched == 1
        vlen = pos - (eq_pos + 1)
        @if vlen > 0
          found_val = bytes_to_str(base + eq_pos + 1, vlen)
        @end
        break
      @end
    @end
    pos = pos + 1
  @end
  buf_free(raw)
  return found_val
@end

@fn _tls13_load_portable_sys_ca_ders()
  // WHY: Honors SSL_CERT_FILE first, then searches standard multi-distro Linux/BSD/Nix CA paths.
  env_ca = _tls13_read_env_var("SSL_CERT_FILE")
  @if str_len(env_ca) > 0
    ders = x509_load_pem_bundle_file(env_ca)
    @if ders.len() > 0 return ders @end
  @end
  candidates = [
    "/etc/ssl/certs/ca-certificates.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/ca-bundle.pem",
    "/etc/ssl/cert.pem"
  ]
  ci = 0
  @while ci < candidates.len()
    ders = x509_load_pem_bundle_file(candidates[ci])
    @if ders.len() > 0 return ders @end
    ci = ci + 1
  @end
  return []
@end

@fn _tls13_get_active_trust_store()
  combined = []
  @if g_tls13_custom_init == 1
    i = 0
    @while i < g_tls13_custom_roots.len()
      combined = combined.push(g_tls13_custom_roots[i])
      i = i + 1
    @end
  @end
  @if g_tls13_disable_sys == 0
    @if g_tls13_sys_loaded == 0
      sys_ders = _tls13_load_portable_sys_ca_ders()
      g_tls13_sys_store = x509_trust_store_build(sys_ders)
      g_tls13_sys_loaded = 1
    @end
    i = 0
    @while i < g_tls13_sys_store.len()
      combined = combined.push(g_tls13_sys_store[i])
      i = i + 1
    @end
  @end
  return combined
@end

@fn tls13_verify_x509_cert_chain_list(cert_der_list, expected_sni)
  @! WHY: Enforces full RFC 5280 chain validation (expiry, SAN/CN hostname, BasicConstraints cA,
  @! and cryptographic signature chain up to system or pinned Root CAs). Rejects self-signed MITM.
  @if cert_der_list.len() == 0 return 0 @end
  store = _tls13_get_active_trust_store()
  @if store.len() == 0 return 0 @end
  return x509_verify_chain_with_store(cert_der_list, expected_sni, store, 0)
@end

@fn tls13_verify_x509_cert_chain(cert_der_bytes, expected_sni)
  @! Single-cert convenience entry point routing into full Root-CA & expiry verification.
  @if cert_der_bytes.len() < 32 return 0 @end
  return tls13_verify_x509_cert_chain_list([cert_der_bytes], expected_sni)
@end

@fn tls13_verify_certificate_verify(cert_der_bytes, transcript_hash, sig_alg, sig_bytes)
  @! WHY: Validates RFC 8446 Section 4.4.3 server CertificateVerify signature cryptographically across
  @! Ed25519 (0x0807), ECDSA P-256 (0x0403), ECDSA P-384 (0x0503), and RSA-PSS (0x0804/0805/0806).
  @if cert_der_bytes.len() < 32 || sig_bytes.len() < 64 || transcript_hash.len() < 32
    return 0
  @end
  cert = x509_decode_full(cert_der_bytes)
  @if cert.x5f_valid != 1 return 0 @end

  // Reject all-zero forged signature
  nz = 0
  si = 0
  @while si < sig_bytes.len()
    nz = nz | (sig_bytes[si] & 255)
    si = si + 1
  @end
  @if nz == 0 return 0 @end

  // RFC 8446 Section 4.4.3 signed content: 64 * 0x20 || "TLS 1.3, server CertificateVerify\0" || hash
  cv_msg = []
  k = 0
  @while k < 64
    cv_msg = cv_msg.push(32)
    k = k + 1
  @end
  ctx_str = "TLS 1.3, server CertificateVerify"
  ci = 0
  @while ci < str_len(ctx_str)
    cv_msg = cv_msg.push(str_char_at(ctx_str, ci) & 255)
    ci = ci + 1
  @end
  cv_msg = cv_msg.push(0)
  cv_msg = tls_append_bytes(cv_msg, transcript_hash)

  spki_alg = cert.x5f_spki_alg_oid
  pub = cert.x5f_spki_pub_bytes

  // Ed25519 (sig_alg 0x0807 = 2055)
  @if sig_alg == 2055
    @if spki_alg != "1.3.101.112" return 0 @end
    return ed25519_verify(pub, cv_msg, sig_bytes)
  @end

  // ECDSA secp256r1 SHA-256 (0x0403 = 1027)
  @if sig_alg == 1027
    @if spki_alg != "1.2.840.10045.2.1" || cert.x5f_spki_curve_oid != "1.2.840.10045.3.1.7"
      return 0
    @end
    return ecdsa_p256_verify_der(pub, sha256_hash_bytes(cv_msg), sig_bytes)
  @end

  // ECDSA secp384r1 SHA-384 (0x0503 = 1283)
  @if sig_alg == 1283
    @if spki_alg != "1.2.840.10045.2.1" || cert.x5f_spki_curve_oid != "1.3.132.0.34"
      return 0
    @end
    return ecdsa_p384_verify_der(pub, sha384_hash_bytes(cv_msg), sig_bytes)
  @end

  // RSA-PSS SHA-256 (0x0804=2052 rsae, 0x0809=2057 pss)
  @if sig_alg == 2052 || sig_alg == 2057
    @if spki_alg != "1.2.840.113549.1.1.1" return 0 @end
    return rsa_pss_verify_spki(pub, sha256_hash_bytes(cv_msg), sig_bytes, 256, 32)
  @end

  // RSA-PSS SHA-384 (0x0805=2053 rsae, 0x080A=2058 pss)
  @if sig_alg == 2053 || sig_alg == 2058
    @if spki_alg != "1.2.840.113549.1.1.1" return 0 @end
    return rsa_pss_verify_spki(pub, sha384_hash_bytes(cv_msg), sig_bytes, 384, 48)
  @end

  // RSA-PSS SHA-512 (0x0806=2054 rsae, 0x080B=2059 pss)
  @if sig_alg == 2054 || sig_alg == 2059
    @if spki_alg != "1.2.840.113549.1.1.1" return 0 @end
    return rsa_pss_verify_spki(pub, sha512_hash_bytes(cv_msg), sig_bytes, 512, 64)
  @end

  return 0
@end
