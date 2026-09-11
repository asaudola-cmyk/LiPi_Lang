import "universe/crypto/aes"

@fn arrays_equal(a, b)
  @if a.len() != b.len()
    return 0
  @end
  i = 0
  len = a.len()
  @while i < len
    @if a[i] != b[i]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = (b >> 4) & 15
  lo = b & 15
  return hex_chars[hi] + hex_chars[lo]
@end

@fn bytes_to_hex(arr)
  res = ""
  i = 0
  len = arr.len()
  @while i < len
    res = res + byte_to_hex(arr[i] & 255)
    i = i + 1
  @end
  return res
@end

@! LCG Pseudo-Random Number Generator (seed initialized)
@fn lcg_next(state)
  return ((state * 1103515245) + 12345) & 2147483647
@end

@fn gen_random_bytes(count, initial_seed)
  res = []
  s = initial_seed
  i = 0
  @while i < count
    s = lcg_next(s)
    res = res.push((s / 65536) & 255)
    i = i + 1
  @end
  return res
@end

@fn gen_random_string(count, initial_seed)
  res = ""
  s = initial_seed
  i = 0
  @while i < count
    s = lcg_next(s)
    @! printable ASCII characters between 32 (' ') and 126 ('~')
    char_code = 32 + ((s / 65536) % 95)
    res = res + str_from_char_code(char_code)
    i = i + 1
  @end
  return res
@end

@fn test_pkcs7_edge_cases()
  println("--- [TEST SUITE 1: PKCS#7 Padding & Unpadding Edge Cases] ---")
  tests_passed = 0
  tests_failed = 0

  @! 1. Empty message (0 bytes) -> must pad to 16 bytes of value 16
  p0 = pkcs7_pad([], 16)
  u0 = pkcs7_unpad(p0)
  @if p0.len() == 16 && p0[0] == 16 && p0[15] == 16 && u0.len() == 0
    tests_passed = tests_passed + 1
    println("  [PASS] Length 0: padded to 16 bytes of 0x10, unpadded to empty []")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 0 PKCS#7 failed")
  @end

  @! 2. 1-byte message -> must pad to 16 bytes (1 byte data + 15 bytes of value 15)
  data1 = [0x42]
  p1 = pkcs7_pad(data1, 16)
  u1 = pkcs7_unpad(p1)
  @if p1.len() == 16 && p1[0] == 0x42 && p1[1] == 15 && p1[15] == 15 && arrays_equal(u1, data1) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] Length 1: padded to 16 bytes (pad byte 0x0F), unpadded back to 1 byte")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 1 PKCS#7 failed")
  @end

  @! 3. 15-byte message -> must pad to 16 bytes (15 bytes data + 1 byte of value 1)
  data15 = gen_random_bytes(15, 12345)
  p15 = pkcs7_pad(data15, 16)
  u15 = pkcs7_unpad(p15)
  @if p15.len() == 16 && p15[15] == 1 && arrays_equal(u15, data15) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] Length 15: padded to 16 bytes (pad byte 0x01), unpadded back to 15 bytes")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 15 PKCS#7 failed")
  @end

  @! 4. Exact 16-byte multiple (16 bytes) -> MUST pad to 32 bytes with 16 bytes of value 16!
  data16 = gen_random_bytes(16, 54321)
  p16 = pkcs7_pad(data16, 16)
  u16 = pkcs7_unpad(p16)
  @if p16.len() == 32 && p16[16] == 16 && p16[31] == 16 && arrays_equal(u16, data16) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] Length 16 (Exact 1 block): correctly padded to 32 bytes (16 pad bytes), unpadded to 16 bytes")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 16 PKCS#7 exact multiple failed: len=" + p16.len().to_str())
  @end

  @! 5. Exact 32-byte multiple (32 bytes) -> MUST pad to 48 bytes with 16 bytes of value 16!
  data32 = gen_random_bytes(32, 99999)
  p32 = pkcs7_pad(data32, 16)
  u32 = pkcs7_unpad(p32)
  @if p32.len() == 48 && p32[32] == 16 && p32[47] == 16 && arrays_equal(u32, data32) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] Length 32 (Exact 2 blocks): correctly padded to 48 bytes, unpadded to 32 bytes")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 32 PKCS#7 failed")
  @end

  @! 6. Exhaustive Roundtrip across lengths 0 to 100 bytes
  l = 0
  all_len_ok = 1
  @while l <= 100
    d = gen_random_bytes(l, 1000 + l)
    padded = pkcs7_pad(d, 16)
    expected_padded_len = ((l / 16) + 1) * 16
    @if padded.len() != expected_padded_len
      all_len_ok = 0
    @end
    unpadded = pkcs7_unpad(padded)
    @if arrays_equal(unpadded, d) != 1
      all_len_ok = 0
    @end
    l = l + 1
  @end

  @if all_len_ok == 1
    tests_passed = tests_passed + 1
    println("  [PASS] Exhaustive PKCS#7 roundtrip verified for all lengths 0..100 bytes (101 cases)")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Exhaustive PKCS#7 roundtrip failed")
  @end

  @if tests_failed == 0
    println("✓ All PKCS#7 Edge Case Tests PASSED!")
    return 0
  @else
    return 1
  @end
@end

@fn test_aes_nist_standard_vectors()
  println("--- [TEST SUITE 2: NIST SP 800-38A Standard Mode Vectors] ---")
  tests_passed = 0
  tests_failed = 0

  key128 = [
    0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
    0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
  ]
  key256 = [
    0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe,
    0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
    0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7,
    0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
  ]
  iv = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
  ]
  nonce = [
    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
    0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
  ]

  @! 64-byte 4-block NIST plaintext
  pt = [
    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
    0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c,
    0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
    0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
    0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
    0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17,
    0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10
  ]

  @! 1. NIST SP 800-38A AES-128 CTR mode vector (tests counter rollover across block 1->2 because nonce ends in 0xFF)
  exp_ctr128_hex = "874d6191b620e3261bef6864990db6ce9806f66b7970fdff8617187bb9fffdff5ae4df3edbd5d35e5b4f09020db03eab1e031dda2fbe03d1792170a0f3009cee"
  ct_ctr128 = aes128_ctr_encrypt(key128, nonce, pt)
  ct_ctr128_hex = bytes_to_hex(ct_ctr128)
  @if ct_ctr128_hex == exp_ctr128_hex
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128 CTR NIST SP 800-38A vector (with 0xFF counter rollover) verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 CTR NIST vector failed! Got: " + ct_ctr128_hex)
  @end

  @! 2. AES-128 CTR Decryption Invariant
  rec_ctr128 = aes128_ctr_decrypt(key128, nonce, ct_ctr128)
  @if arrays_equal(rec_ctr128, pt) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128 CTR decryption roundtrip verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 CTR decryption roundtrip failed")
  @end

  @! 3. NIST SP 800-38A AES-256 CTR mode vector
  exp_ctr256_hex = "601ec313775789a5b7a7f504bbf3d228f443e3ca4d62b59aca84e990cacaf5c52b0930daa23de94ce87017ba2d84988ddfc9c58db67aada613c2dd08457941a6"
  ct_ctr256 = aes256_ctr_encrypt(key256, nonce, pt)
  ct_ctr256_hex = bytes_to_hex(ct_ctr256)
  @if ct_ctr256_hex == exp_ctr256_hex
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CTR NIST SP 800-38A vector verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CTR NIST vector failed! Got: " + ct_ctr256_hex)
  @end

  @! 4. AES-256 CTR Decryption Invariant
  rec_ctr256 = aes256_ctr_decrypt(key256, nonce, ct_ctr256)
  @if arrays_equal(rec_ctr256, pt) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CTR decryption roundtrip verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CTR decryption roundtrip failed")
  @end

  @if tests_failed == 0
    println("✓ NIST SP 800-38A Standard Vectors PASSED!")
    return 0
  @else
    return 1
  @end
@end

@fn test_aes_multiblock_roundtrips()
  println("--- [TEST SUITE 3: AES-128 & AES-256 Multi-Block (100+ Blocks) Invariants] ---")
  tests_passed = 0
  tests_failed = 0

  @! 1. AES-128 Single-Block Raw 100 Consecutive Random Blocks Invariant (Decrypt(Encrypt(B)) == B)
  key128 = gen_random_bytes(16, 777128)
  b_idx = 0
  all_raw128_ok = 1
  @while b_idx < 100
    blk = gen_random_bytes(16, 100000 + b_idx)
    enc_blk = aes128_encrypt_block(key128, blk)
    dec_blk = aes128_decrypt_block(key128, enc_blk)
    @if arrays_equal(dec_blk, blk) != 1
      all_raw128_ok = 0
    @end
    b_idx = b_idx + 1
  @end

  @if all_raw128_ok == 1
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128: 100 consecutive random raw blocks Decrypt(Encrypt(B)) == B verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 100 raw blocks roundtrip failed")
  @end

  @! 2. AES-256 Single-Block Raw 100 Consecutive Random Blocks Invariant
  key256 = gen_random_bytes(32, 777256)
  b_idx = 0
  all_raw256_ok = 1
  @while b_idx < 100
    blk = gen_random_bytes(16, 200000 + b_idx)
    enc_blk = aes256_encrypt_block(key256, blk)
    dec_blk = aes256_decrypt_block(key256, enc_blk)
    @if arrays_equal(dec_blk, blk) != 1
      all_raw256_ok = 0
    @end
    b_idx = b_idx + 1
  @end

  @if all_raw256_ok == 1
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256: 100 consecutive random raw blocks Decrypt(Encrypt(B)) == B verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 100 raw blocks roundtrip failed")
  @end

  @! 3. AES-128 CBC 100+ Blocks (1,600-byte string payload) Invariant
  iv128 = gen_random_bytes(16, 999128)
  str1600 = gen_random_string(1600, 314159)
  cbc_ct128 = aes128_cbc_encrypt(key128, iv128, str1600)
  cbc_dec128 = aes128_cbc_decrypt(key128, iv128, cbc_ct128)
  @if cbc_dec128 == str1600 && cbc_ct128.len() == 1616
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128 CBC 100-block (1600-byte) payload + PKCS#7 roundtrip verified (CT len: " + cbc_ct128.len().to_str() + ")")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 CBC 100-block roundtrip failed")
  @end

  @! 4. AES-256 CBC 100+ Blocks (1,600-byte string payload) Invariant
  iv256 = gen_random_bytes(16, 999256)
  cbc_ct256 = aes256_cbc_encrypt(key256, iv256, str1600)
  cbc_dec256 = aes256_cbc_decrypt(key256, iv256, cbc_ct256)
  @if cbc_dec256 == str1600 && cbc_ct256.len() == 1616
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CBC 100-block (1600-byte) payload + PKCS#7 roundtrip verified (CT len: " + cbc_ct256.len().to_str() + ")")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CBC 100-block roundtrip failed")
  @end

  @! 5. AES-128 ECB 100+ Blocks (1,600-byte string payload) Invariant
  ecb_ct128 = aes128_ecb_encrypt(key128, str1600)
  ecb_dec128 = aes128_ecb_decrypt(key128, ecb_ct128)
  @if ecb_dec128 == str1600 && ecb_ct128.len() == 1616
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128 ECB 100-block (1600-byte) payload + PKCS#7 roundtrip verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 ECB 100-block roundtrip failed")
  @end

  @! 6. AES-256 ECB 100+ Blocks (1,600-byte string payload) Invariant
  ecb_ct256 = aes256_ecb_encrypt(key256, str1600)
  ecb_dec256 = aes256_ecb_decrypt(key256, ecb_ct256)
  @if ecb_dec256 == str1600 && ecb_ct256.len() == 1616
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 ECB 100-block (1600-byte) payload + PKCS#7 roundtrip verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 ECB 100-block roundtrip failed")
  @end

  @! 7. AES-128 CTR 125 Blocks (2,000-byte arbitrary binary payload) Invariant
  nonce128 = gen_random_bytes(16, 555128)
  bin2000 = gen_random_bytes(2000, 789101)
  ctr_ct128 = aes128_ctr_encrypt(key128, nonce128, bin2000)
  ctr_dec128 = aes128_ctr_decrypt(key128, nonce128, ctr_ct128)
  @if arrays_equal(ctr_dec128, bin2000) == 1 && ctr_ct128.len() == 2000
    tests_passed = tests_passed + 1
    println("  [PASS] AES-128 CTR 125-block (2000-byte binary) roundtrip verified (CT len: 2000)")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-128 CTR 2000-byte binary roundtrip failed")
  @end

  @! 8. AES-256 CTR 125 Blocks (2,000-byte arbitrary binary payload) Invariant
  nonce256 = gen_random_bytes(16, 555256)
  ctr_ct256 = aes256_ctr_encrypt(key256, nonce256, bin2000)
  ctr_dec256 = aes256_ctr_decrypt(key256, nonce256, ctr_ct256)
  @if arrays_equal(ctr_dec256, bin2000) == 1 && ctr_ct256.len() == 2000
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CTR 125-block (2000-byte binary) roundtrip verified (CT len: 2000)")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CTR 2000-byte binary roundtrip failed")
  @end

  @if tests_failed == 0
    println("✓ All Multi-Block Invariant Tests PASSED!")
    return 0
  @else
    return 1
  @end
@end

@fn test_aes_ctr_counter_overflow()
  println("--- [TEST SUITE 4: AES CTR 128-Bit Multi-Byte Overflow Stress] ---")
  tests_passed = 0
  tests_failed = 0

  key128 = gen_random_bytes(16, 444128)
  @! Nonce ending in [..., 0xff, 0xff, 0xff] to trigger 3-byte carry propagation
  nonce_overflow = [
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0xff, 0xff, 0xff
  ]

  @! Encrypt 5 blocks (80 bytes)
  msg80 = gen_random_bytes(80, 88888)
  ct = aes128_ctr_encrypt(key128, nonce_overflow, msg80)
  dec = aes128_ctr_decrypt(key128, nonce_overflow, ct)

  @if arrays_equal(dec, msg80) == 1
    tests_passed = tests_passed + 1
    println("  [PASS] 3-byte cascade carry rollover in CTR counter verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] CTR cascade carry rollover failed")
  @end

  @if tests_failed == 0
    return 0
  @else
    return 1
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [CHALLENGER 1] AES & PKCS#7 Empirical Stress & Adversarial Suite")
  println("=================================================================")

  r1 = test_pkcs7_edge_cases()
  r2 = test_aes_nist_standard_vectors()
  r3 = test_aes_multiblock_roundtrips()
  r4 = test_aes_ctr_counter_overflow()

  total_res = r1 + r2 + r3 + r4
  println("=================================================================")
  @if total_res == 0
    println("🏆 ALL AES & PKCS#7 EMPIRICAL CHALLENGES PASSED WITH ZERO ERRORS!")
    return 0
  @else
    println("💥 AES CHALLENGES FAILED WITH " + total_res.to_str() + " SUITE FAILURES!")
    return 1
  @end
@end
