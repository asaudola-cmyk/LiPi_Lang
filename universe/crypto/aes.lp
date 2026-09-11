@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: FIPS 197 & NIST SP 800-38A AES
@! Module: universe/crypto/aes
@! 100% Pure Lipi Implementation of AES-128 & AES-256 (ECB / CBC / CTR / PKCS#7)
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Genuine 256-Byte Rijndael S-Box and Inverse S-Box Tables (FIPS 197 §5.1.1)
@! ----------------------------------------------------------------------------
@fn aes_sbox()
  return [
    99, 124, 119, 123, 242, 107, 111, 197, 48, 1, 103, 43, 254, 215, 171, 118,
    202, 130, 201, 125, 250, 89, 71, 240, 173, 212, 162, 175, 156, 164, 114, 192,
    183, 253, 147, 38, 54, 63, 247, 204, 52, 165, 229, 241, 113, 216, 49, 21,
    4, 199, 35, 195, 24, 150, 5, 154, 7, 18, 128, 226, 235, 39, 178, 117,
    9, 131, 44, 26, 27, 110, 90, 160, 82, 59, 214, 179, 41, 227, 47, 132,
    83, 209, 0, 237, 32, 252, 177, 91, 106, 203, 190, 57, 74, 76, 88, 207,
    208, 239, 170, 251, 67, 77, 51, 133, 69, 249, 2, 127, 80, 60, 159, 168,
    81, 163, 64, 143, 146, 157, 56, 245, 188, 182, 218, 33, 16, 255, 243, 210,
    205, 12, 19, 236, 95, 151, 68, 23, 196, 167, 126, 61, 100, 93, 25, 115,
    96, 129, 79, 220, 34, 42, 144, 136, 70, 238, 184, 20, 222, 94, 11, 219,
    224, 50, 58, 10, 73, 6, 36, 92, 194, 211, 172, 98, 145, 149, 228, 121,
    231, 200, 55, 109, 141, 213, 78, 169, 108, 86, 244, 234, 101, 122, 174, 8,
    186, 120, 37, 46, 28, 166, 180, 198, 232, 221, 116, 31, 75, 189, 139, 138,
    112, 62, 181, 102, 72, 3, 246, 14, 97, 53, 87, 185, 134, 193, 29, 158,
    225, 248, 152, 17, 105, 217, 142, 148, 155, 30, 135, 233, 206, 85, 40, 223,
    140, 161, 137, 13, 191, 230, 66, 104, 65, 153, 45, 15, 176, 84, 187, 22
  ]
@end

@fn aes_inv_sbox()
  return [
    82, 9, 106, 213, 48, 54, 165, 56, 191, 64, 163, 158, 129, 243, 215, 251,
    124, 227, 57, 130, 155, 47, 255, 135, 52, 142, 67, 68, 196, 222, 233, 203,
    84, 123, 148, 50, 166, 194, 35, 61, 238, 76, 149, 11, 66, 250, 195, 78,
    8, 46, 161, 102, 40, 217, 36, 178, 118, 91, 162, 73, 109, 139, 209, 37,
    114, 248, 246, 100, 134, 104, 152, 22, 212, 164, 92, 204, 93, 101, 182, 146,
    108, 112, 72, 80, 253, 237, 185, 218, 94, 21, 70, 87, 167, 141, 157, 132,
    144, 216, 171, 0, 140, 188, 211, 10, 247, 228, 88, 5, 184, 179, 69, 6,
    208, 44, 30, 143, 202, 63, 15, 2, 193, 175, 189, 3, 1, 19, 138, 107,
    58, 145, 17, 65, 79, 103, 220, 234, 151, 242, 207, 206, 240, 180, 230, 115,
    150, 172, 116, 34, 231, 173, 53, 133, 226, 249, 55, 232, 28, 117, 223, 110,
    71, 241, 26, 113, 29, 41, 197, 137, 111, 183, 98, 14, 170, 24, 190, 27,
    252, 86, 62, 75, 198, 210, 121, 32, 154, 219, 192, 254, 120, 205, 90, 244,
    31, 221, 168, 51, 136, 7, 199, 49, 177, 18, 16, 89, 39, 128, 236, 95,
    96, 81, 127, 169, 25, 181, 74, 13, 45, 229, 122, 159, 147, 201, 156, 239,
    160, 224, 59, 77, 174, 42, 245, 176, 200, 235, 187, 60, 131, 83, 153, 97,
    23, 43, 4, 126, 186, 119, 214, 38, 225, 105, 20, 99, 85, 33, 12, 125
  ]
@end

@! ----------------------------------------------------------------------------
@! 2. Rcon Constant Table & Galois Field GF(2^8) Arithmetic (FIPS 197 §4.2)
@! ----------------------------------------------------------------------------
@fn aes_rcon()
  return [
    0, 1, 2, 4, 8, 16, 32, 64, 128, 27, 54
  ]
@end

@fn aes_xtime(a)
  val_and = a & 128
  @if val_and != 0
    t1 = a * 2
    t2 = t1 ^ 27
    return t2 & 255
  @end
  t1 = a * 2
  return t1 & 255
@end

@fn aes_gmul(a, b)
  p = 0
  aa = a & 255
  bb = b & 255
  i = 0
  @while i < 8
    bit_low = bb & 1
    @if bit_low != 0
      p = p ^ aa
    @end
    hi = aa & 128
    aa = ((aa * 2)) & 255
    @if hi != 0
      aa = aa ^ 27
    @end
    bb = (bb / 2)
    i = i + 1
  @end
  return p & 255
@end

@! ----------------------------------------------------------------------------
@! 3. Rijndael Key Schedule Expansion (FIPS 197 §5.2)
@! ----------------------------------------------------------------------------
@fn aes_key_expansion(key, nk, nr)
  sbox = aes_sbox()
  rcon = aes_rcon()
  w = []
  i = 0
  @while i < nk * 4
    w = w.push(key[i] & 255)
    i = i + 1
  @end

  total_words = 4 * (nr + 1)
  word_idx = nk
  @while word_idx < total_words
    prev_base = (word_idx - 1) * 4
    t0 = w[prev_base]
    t1 = w[prev_base + 1]
    t2 = w[prev_base + 2]
    t3 = w[prev_base + 3]

    mod_nk = word_idx % nk
    @if mod_nk == 0
      tmp = t0
      t0 = t1
      t1 = t2
      t2 = t3
      t3 = tmp

      t0 = sbox[t0]
      t1 = sbox[t1]
      t2 = sbox[t2]
      t3 = sbox[t3]

      idx_r = word_idx / nk
      r_val = rcon[idx_r]
      t0 = t0 ^ r_val
    @elif nk > 6 && mod_nk == 4
      t0 = sbox[t0]
      t1 = sbox[t1]
      t2 = sbox[t2]
      t3 = sbox[t3]
    @end

    p_base = (word_idx - nk) * 4
    p0 = w[p_base]
    p1 = w[p_base + 1]
    p2 = w[p_base + 2]
    p3 = w[p_base + 3]

    v0 = p0 ^ t0
    v1 = p1 ^ t1
    v2 = p2 ^ t2
    v3 = p3 ^ t3
    w = w.push(v0)
    w = w.push(v1)
    w = w.push(v2)
    w = w.push(v3)

    word_idx = word_idx + 1
  @end

  return w
@end

@! ----------------------------------------------------------------------------
@! 4. Core AES Round Transformations (FIPS 197 §5.1 & §5.3)
@! ----------------------------------------------------------------------------
@fn aes_add_round_key(state, round_key, round)
  res = []
  i = 0
  offset = round * 16
  @while i < 16
    res = res.push((state[i]) ^ (round_key[offset + i]))
    i = i + 1
  @end
  return res
@end

@fn aes_sub_bytes(state, sbox)
  res = []
  i = 0
  @while i < 16
    val_s = sbox[state[i]] & 255
    res = res.push(val_s)
    i = i + 1
  @end
  return res
@end

@fn aes_inv_sub_bytes(state, inv_sbox)
  res = []
  i = 0
  @while i < 16
    val_s = inv_sbox[state[i]] & 255
    res = res.push(val_s)
    i = i + 1
  @end
  return res
@end

@fn aes_shift_rows(s)
  res = [
    s[0],  s[5],  s[10], s[15],
    s[4],  s[9],  s[14], s[3],
    s[8],  s[13], s[2],  s[7],
    s[12], s[1],  s[6],  s[11]
  ]
  return res
@end

@fn aes_inv_shift_rows(s)
  res = [
    s[0],  s[13], s[10], s[7],
    s[4],  s[1],  s[14], s[11],
    s[8],  s[5],  s[2],  s[15],
    s[12], s[9],  s[6],  s[3]
  ]
  return res
@end

@fn aes_mix_columns(s)
  res = [
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0
  ]
  c = 0
  @while c < 4
    idx = c * 4
    s0 = s[idx]
    s1 = s[idx + 1]
    s2 = s[idx + 2]
    s3 = s[idx + 3]

    res[idx]     = aes_xtime(s0) ^ (aes_xtime(s1) ^ s1) ^ s2 ^ s3
    res[idx + 1] = s0 ^ aes_xtime(s1) ^ (aes_xtime(s2) ^ s2) ^ s3
    res[idx + 2] = s0 ^ s1 ^ aes_xtime(s2) ^ (aes_xtime(s3) ^ s3)
    res[idx + 3] = (aes_xtime(s0) ^ s0) ^ s1 ^ s2 ^ aes_xtime(s3)

    c = c + 1
  @end
  return res
@end

@fn aes_inv_mix_columns(s)
  res = [
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0
  ]
  c = 0
  @while c < 4
    idx = c * 4
    s0 = s[idx]
    s1 = s[idx + 1]
    s2 = s[idx + 2]
    s3 = s[idx + 3]

    res[idx]     = aes_gmul(s0, 14) ^ aes_gmul(s1, 11) ^ aes_gmul(s2, 13) ^ aes_gmul(s3, 9)
    res[idx + 1] = aes_gmul(s0, 9) ^ aes_gmul(s1, 14) ^ aes_gmul(s2, 11) ^ aes_gmul(s3, 13)
    res[idx + 2] = aes_gmul(s0, 13) ^ aes_gmul(s1, 9) ^ aes_gmul(s2, 14) ^ aes_gmul(s3, 11)
    res[idx + 3] = aes_gmul(s0, 11) ^ aes_gmul(s1, 13) ^ aes_gmul(s2, 9) ^ aes_gmul(s3, 14)

    c = c + 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 5. Single-Block Encryption & Decryption (16-Byte Blocks)
@! ----------------------------------------------------------------------------
@fn aes_encrypt_block(state, round_keys, nr)
  sbox = aes_sbox()
  state = aes_add_round_key(state, round_keys, 0)

  round = 1
  @while round < nr
    state = aes_sub_bytes(state, sbox)
    state = aes_shift_rows(state)
    state = aes_mix_columns(state)
    state = aes_add_round_key(state, round_keys, round)
    round = round + 1
  @end

  state = aes_sub_bytes(state, sbox)
  state = aes_shift_rows(state)
  state = aes_add_round_key(state, round_keys, nr)
  return state
@end

@fn aes_decrypt_block(state, round_keys, nr)
  inv_sbox = aes_inv_sbox()
  state = aes_add_round_key(state, round_keys, nr)

  round = nr - 1
  @while round > 0
    state = aes_inv_shift_rows(state)
    state = aes_inv_sub_bytes(state, inv_sbox)
    state = aes_add_round_key(state, round_keys, round)
    state = aes_inv_mix_columns(state)
    round = round - 1
  @end

  state = aes_inv_shift_rows(state)
  state = aes_inv_sub_bytes(state, inv_sbox)
  state = aes_add_round_key(state, round_keys, 0)
  return state
@end

@fn aes128_encrypt_block(key, block)
  round_keys = aes_key_expansion(key, 4, 10)
  return aes_encrypt_block(block, round_keys, 10)
@end

@fn aes128_decrypt_block(key, block)
  round_keys = aes_key_expansion(key, 4, 10)
  return aes_decrypt_block(block, round_keys, 10)
@end

@fn aes256_encrypt_block(key, block)
  round_keys = aes_key_expansion(key, 8, 14)
  return aes_encrypt_block(block, round_keys, 14)
@end

@fn aes256_decrypt_block(key, block)
  round_keys = aes_key_expansion(key, 8, 14)
  return aes_decrypt_block(block, round_keys, 14)
@end

@! ----------------------------------------------------------------------------
@! 6. PKCS#7 Padding & Unpadding (RFC 5652)
@! ----------------------------------------------------------------------------
@fn pkcs7_pad(data, block_size)
  res = []
  num_items = data.len()
  i = 0
  @while i < num_items
    res = res.push(data[i] & 255)
    i = i + 1
  @end

  pad_len = block_size - (num_items % block_size)
  @if pad_len == 0
    pad_len = block_size
  @end

  i = 0
  @while i < pad_len
    res = res.push(pad_len)
    i = i + 1
  @end
  return res
@end

@fn pkcs7_unpad(data)
  num_items = data.len()
  @if num_items == 0
    return []
  @end
  pad_len = data[num_items - 1] & 255
  @if pad_len <= 0 || pad_len > 16 || pad_len > num_items
    return data
  @end

  unpadded_len = num_items - pad_len
  res = []
  i = 0
  @while i < unpadded_len
    res = res.push(data[i] & 255)
    i = i + 1
  @end
  return res
@end

@fn aes_bytes_to_string(bytes)
  res = ""
  i = 0
  num_items = bytes.len()
  @while i < num_items
    res = res + str_from_char_code(bytes[i] & 255)
    i = i + 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 7. CBC Mode (Cipher Block Chaining - NIST SP 800-38A Section 6.2)
@! ----------------------------------------------------------------------------
@fn aes128_cbc_encrypt(key, iv, plaintext)
  padded = pkcs7_pad(plaintext, 16)
  round_keys = aes_key_expansion(key, 4, 10)
  ciphertext = []
  prev = []
  i = 0
  @while i < 16
    prev = prev.push(iv[i] & 255)
    i = i + 1
  @end

  num_blocks = padded.len() / 16
  blk = 0
  @while blk < num_blocks
    block = []
    i = 0
    @while i < 16
      block = block.push((padded[blk * 16 + i]) ^ (prev[i]))
      i = i + 1
    @end

    enc = aes_encrypt_block(block, round_keys, 10)
    i = 0
    @while i < 16
      ciphertext = ciphertext.push(enc[i])
      prev[i] = enc[i]
      i = i + 1
    @end

    blk = blk + 1
  @end

  return ciphertext
@end

@fn aes128_cbc_decrypt(key, iv, ciphertext)
  round_keys = aes_key_expansion(key, 4, 10)
  plaintext_padded = []
  prev = []
  i = 0
  @while i < 16
    prev = prev.push(iv[i] & 255)
    i = i + 1
  @end

  num_blocks = ciphertext.len() / 16
  blk = 0
  @while blk < num_blocks
    curr_ct = []
    i = 0
    @while i < 16
      curr_ct = curr_ct.push((ciphertext[blk * 16 + i]) & (255))
      i = i + 1
    @end

    dec = aes_decrypt_block(curr_ct, round_keys, 10)
    i = 0
    @while i < 16
      plaintext_padded = plaintext_padded.push((dec[i]) ^ (prev[i]))
      prev[i] = curr_ct[i]
      i = i + 1
    @end

    blk = blk + 1
  @end

  unpadded = pkcs7_unpad(plaintext_padded)
  return aes_bytes_to_string(unpadded)
@end

@fn aes256_cbc_encrypt(key, iv, plaintext)
  padded = pkcs7_pad(plaintext, 16)
  round_keys = aes_key_expansion(key, 8, 14)
  ciphertext = []
  prev = []
  i = 0
  @while i < 16
    prev = prev.push(iv[i] & 255)
    i = i + 1
  @end

  num_blocks = padded.len() / 16
  blk = 0
  @while blk < num_blocks
    block = []
    i = 0
    @while i < 16
      block = block.push((padded[blk * 16 + i]) ^ (prev[i]))
      i = i + 1
    @end

    enc = aes_encrypt_block(block, round_keys, 14)
    i = 0
    @while i < 16
      ciphertext = ciphertext.push(enc[i])
      prev[i] = enc[i]
      i = i + 1
    @end

    blk = blk + 1
  @end

  return ciphertext
@end

@fn aes256_cbc_decrypt(key, iv, ciphertext)
  round_keys = aes_key_expansion(key, 8, 14)
  plaintext_padded = []
  prev = []
  i = 0
  @while i < 16
    prev = prev.push(iv[i] & 255)
    i = i + 1
  @end

  num_blocks = ciphertext.len() / 16
  blk = 0
  @while blk < num_blocks
    curr_ct = []
    i = 0
    @while i < 16
      curr_ct = curr_ct.push((ciphertext[blk * 16 + i]) & (255))
      i = i + 1
    @end

    dec = aes_decrypt_block(curr_ct, round_keys, 14)
    i = 0
    @while i < 16
      plaintext_padded = plaintext_padded.push((dec[i]) ^ (prev[i]))
      prev[i] = curr_ct[i]
      i = i + 1
    @end

    blk = blk + 1
  @end

  unpadded = pkcs7_unpad(plaintext_padded)
  return aes_bytes_to_string(unpadded)
@end

@! ----------------------------------------------------------------------------
@! 8. ECB Mode (Electronic Codebook - NIST SP 800-38A Section 6.1)
@! ----------------------------------------------------------------------------
@fn aes128_ecb_encrypt(key, plaintext)
  padded = pkcs7_pad(plaintext, 16)
  round_keys = aes_key_expansion(key, 4, 10)
  ciphertext = []
  num_blocks = padded.len() / 16
  blk = 0
  @while blk < num_blocks
    block = []
    i = 0
    @while i < 16
      block = block.push((padded[blk * 16 + i]) & (255))
      i = i + 1
    @end
    enc = aes_encrypt_block(block, round_keys, 10)
    i = 0
    @while i < 16
      ciphertext = ciphertext.push(enc[i])
      i = i + 1
    @end
    blk = blk + 1
  @end
  return ciphertext
@end

@fn aes128_ecb_decrypt(key, ciphertext)
  round_keys = aes_key_expansion(key, 4, 10)
  plaintext_padded = []
  num_blocks = ciphertext.len() / 16
  blk = 0
  @while blk < num_blocks
    curr_ct = []
    i = 0
    @while i < 16
      curr_ct = curr_ct.push((ciphertext[blk * 16 + i]) & (255))
      i = i + 1
    @end
    dec = aes_decrypt_block(curr_ct, round_keys, 10)
    i = 0
    @while i < 16
      plaintext_padded = plaintext_padded.push(dec[i])
      i = i + 1
    @end
    blk = blk + 1
  @end
  unpadded = pkcs7_unpad(plaintext_padded)
  return aes_bytes_to_string(unpadded)
@end

@fn aes256_ecb_encrypt(key, plaintext)
  padded = pkcs7_pad(plaintext, 16)
  round_keys = aes_key_expansion(key, 8, 14)
  ciphertext = []
  num_blocks = padded.len() / 16
  blk = 0
  @while blk < num_blocks
    block = []
    i = 0
    @while i < 16
      block = block.push((padded[blk * 16 + i]) & (255))
      i = i + 1
    @end
    enc = aes_encrypt_block(block, round_keys, 14)
    i = 0
    @while i < 16
      ciphertext = ciphertext.push(enc[i])
      i = i + 1
    @end
    blk = blk + 1
  @end
  return ciphertext
@end

@fn aes256_ecb_decrypt(key, ciphertext)
  round_keys = aes_key_expansion(key, 8, 14)
  plaintext_padded = []
  num_blocks = ciphertext.len() / 16
  blk = 0
  @while blk < num_blocks
    curr_ct = []
    i = 0
    @while i < 16
      curr_ct = curr_ct.push((ciphertext[blk * 16 + i]) & (255))
      i = i + 1
    @end
    dec = aes_decrypt_block(curr_ct, round_keys, 14)
    i = 0
    @while i < 16
      plaintext_padded = plaintext_padded.push(dec[i])
      i = i + 1
    @end
    blk = blk + 1
  @end
  unpadded = pkcs7_unpad(plaintext_padded)
  return aes_bytes_to_string(unpadded)
@end

@! ----------------------------------------------------------------------------
@! 9. CTR Mode (Counter Mode - NIST SP 800-38A Section 6.5)
@! ----------------------------------------------------------------------------
@fn aes128_ctr_encrypt(key, nonce, plaintext)
  round_keys = aes_key_expansion(key, 4, 10)
  ciphertext = []
  counter = []
  i = 0
  @while i < 16
    counter = counter.push(nonce[i] & 255)
    i = i + 1
  @end

  data_len = plaintext.len()
  i = 0
  @while i < data_len
    keystream = aes_encrypt_block(counter, round_keys, 10)
    j = 0
    @while j < 16 && i < data_len
      b = plaintext[i] & 255
      ciphertext = ciphertext.push((b) ^ (keystream[j]))
      i = i + 1
      j = j + 1
    @end

    @! Increment 128-bit big-endian counter
    k = 15
    carry = 1
    @while k >= 0 && carry > 0
      val = counter[k] + 1
      @if val >= 256
        counter[k] = 0
        carry = 1
      @else
        counter[k] = val
        carry = 0
      @end
      k = k - 1
    @end
  @end

  return ciphertext
@end

@fn aes128_ctr_decrypt(key, nonce, ciphertext)
  return aes128_ctr_encrypt(key, nonce, ciphertext)
@end

@fn aes256_ctr_encrypt(key, nonce, plaintext)
  round_keys = aes_key_expansion(key, 8, 14)
  ciphertext = []
  counter = []
  i = 0
  @while i < 16
    counter = counter.push(nonce[i] & 255)
    i = i + 1
  @end

  data_len = plaintext.len()
  i = 0
  @while i < data_len
    keystream = aes_encrypt_block(counter, round_keys, 14)
    j = 0
    @while j < 16 && i < data_len
      b = plaintext[i] & 255
      ciphertext = ciphertext.push((b) ^ (keystream[j]))
      i = i + 1
      j = j + 1
    @end

    @! Increment 128-bit big-endian counter
    k = 15
    carry = 1
    @while k >= 0 && carry > 0
      val = counter[k] + 1
      @if val >= 256
        counter[k] = 0
        carry = 1
      @else
        counter[k] = val
        carry = 0
      @end
      k = k - 1
    @end
  @end

  return ciphertext
@end

@fn aes256_ctr_decrypt(key, nonce, ciphertext)
  return aes256_ctr_encrypt(key, nonce, ciphertext)
@end
