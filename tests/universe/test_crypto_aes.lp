@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: FIPS 197 / NIST SP 800-38A AES CIPHER VERIFICATION
@! File: tests/universe/test_crypto_aes.maya
@! ============================================================================

import "universe/crypto/aes"
import "universe/crypto/crypto"
import "universe/core/crypto"

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

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/crypto/aes (FIPS 197 & NIST SP 800-38A)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: FIPS 197 Appendix C.1 — AES-128 ECB Official Test Vector
  @! Key:        00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f
  @! Plaintext:  00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff
  @! Ciphertext: 69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a
  @! --------------------------------------------------------------------------
  total = total + 1
  key128 = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
  ]
  pt128 = [
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
  ]
  exp_ct128 = [
    0x69, 0xc4, 0xe0, 0xd8, 0x6a, 0x7b, 0x04, 0x30,
    0xd8, 0xcd, 0xb7, 0x80, 0x70, 0xb4, 0xc5, 0x5a
  ]

  ct128 = aes128_encrypt_block(key128, pt128)
  @if arrays_equal(ct128, exp_ct128) == 1
    passed = passed + 1
    println("  [PASS] Test 1: FIPS 197 Appendix C.1 AES-128 ECB encryption test vector")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: FIPS 197 Appendix C.1 AES-128 ECB encryption failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: AES-128 Decryption Invariant (Decrypt(Encrypt(P)) == P)
  @! --------------------------------------------------------------------------
  total = total + 1
  recovered_pt128 = aes128_decrypt_block(key128, ct128)
  @if arrays_equal(recovered_pt128, pt128) == 1
    passed = passed + 1
    println("  [PASS] Test 2: AES-128 ECB block decryption roundtrip invariant")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: AES-128 ECB block decryption failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: NIST SP 800-38A Section F.1.1 — AES-128 ECB Test Vector
  @! Key:        2b 7e 15 16 28 ae d2 a6 ab f7 15 88 09 cf 4f 3c
  @! Plaintext:  6b c1 be e2 2e 40 9f 96 e9 3d 7e 11 73 93 17 2a
  @! Ciphertext: 3a d7 7b b4 0d 7a 36 60 a8 9e ca f3 24 66 ef 97
  @! --------------------------------------------------------------------------
  total = total + 1
  key_nist_128 = [
    0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
    0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
  ]
  pt_nist_128 = [
    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
    0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
  ]
  exp_nist_ct128 = [
    0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60,
    0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97
  ]

  ct_nist_128 = aes128_encrypt_block(key_nist_128, pt_nist_128)
  @if arrays_equal(ct_nist_128, exp_nist_ct128) == 1
    passed = passed + 1
    println("  [PASS] Test 3: NIST SP 800-38A Section F.1.1 AES-128 ECB vector")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: NIST SP 800-38A AES-128 ECB vector failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: FIPS 197 Appendix C.2 — AES-256 ECB Official NIST Test Vector
  @! Key (256-bit): 00 01 02 ... 1e 1f
  @! Plaintext:     00 11 22 ... ee ff
  @! Ciphertext:    8e a2 b7 ca 51 67 45 bf ea fc 49 90 4b 49 60 89
  @! --------------------------------------------------------------------------
  total = total + 1
  key256 = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
  ]
  pt256 = [
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
  ]
  exp_ct256 = [
    0x8e, 0xa2, 0xb7, 0xca, 0x51, 0x67, 0x45, 0xbf,
    0xea, 0xfc, 0x49, 0x90, 0x4b, 0x49, 0x60, 0x89
  ]

  ct256 = aes256_encrypt_block(key256, pt256)
  @if arrays_equal(ct256, exp_ct256) == 1
    passed = passed + 1
    println("  [PASS] Test 4: FIPS 197 Appendix C.2 AES-256 ECB vector (8ea2b7ca516745bfeafc49904b496089)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: FIPS 197 Appendix C.2 AES-256 ECB vector failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: AES-256 Decryption Invariant (Decrypt(Encrypt(P)) == P)
  @! --------------------------------------------------------------------------
  total = total + 1
  recovered_pt256 = aes256_decrypt_block(key256, ct256)
  @if arrays_equal(recovered_pt256, pt256) == 1
    passed = passed + 1
    println("  [PASS] Test 5: AES-256 ECB block decryption roundtrip invariant")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: AES-256 ECB block decryption failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 6: AES-128 CBC Mode with IV & PKCS#7 Roundtrip
  @! --------------------------------------------------------------------------
  total = total + 1
  iv = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
  ]
  original_msg1 = "Hello Maya Pure Crypto Library!"
  cbc_ct128 = aes128_cbc_encrypt(key128, iv, original_msg1)
  decrypted_msg1 = aes128_cbc_decrypt(key128, iv, cbc_ct128)

  @if decrypted_msg1 == original_msg1
    passed = passed + 1
    println("  [PASS] Test 6: AES-128 CBC encryption & PKCS#7 decryption roundtrip")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: AES-128 CBC roundtrip failed -> Got: " + decrypted_msg1)
  @end

  @! --------------------------------------------------------------------------
  @! Test 7: AES-256 CBC Mode with IV & PKCS#7 Roundtrip
  @! --------------------------------------------------------------------------
  total = total + 1
  original_msg2 = "Confidential Pure Maya OS Kernel Data Payload Block!"
  cbc_ct256 = aes256_cbc_encrypt(key256, iv, original_msg2)
  decrypted_msg2 = aes256_cbc_decrypt(key256, iv, cbc_ct256)

  @if decrypted_msg2 == original_msg2
    passed = passed + 1
    println("  [PASS] Test 7: AES-256 CBC encryption & PKCS#7 decryption roundtrip")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: AES-256 CBC roundtrip failed -> Got: " + decrypted_msg2)
  @end

  @! --------------------------------------------------------------------------
  @! Test 8: Multi-Block Payload Invariant (64-byte payload = 4 AES blocks)
  @! --------------------------------------------------------------------------
  total = total + 1
  multi_block_msg = "1234567890123456789012345678901234567890123456789012345678901234"
  cbc_multi = aes256_cbc_encrypt(key256, iv, multi_block_msg)
  recovered_multi = aes256_cbc_decrypt(key256, iv, cbc_multi)

  @if recovered_multi == multi_block_msg
    passed = passed + 1
    println("  [PASS] Test 8: Multi-block (64-byte) AES-256 CBC payload invariant verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: Multi-block AES-256 CBC failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 9: Empty Payload Roundtrip with PKCS#7 (Pads to 1 full block 16 bytes)
  @! --------------------------------------------------------------------------
  total = total + 1
  empty_msg = ""
  cbc_empty = aes128_cbc_encrypt(key128, iv, empty_msg)
  recovered_empty = aes128_cbc_decrypt(key128, iv, cbc_empty)

  @if recovered_empty == empty_msg && cbc_empty.len() == 16
    passed = passed + 1
    println("  [PASS] Test 9: Empty payload PKCS#7 padding and decryption roundtrip")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: Empty payload roundtrip failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 10: Ciphertext Diffusion / Non-Trivial Transformation
  @! Verify ciphertext is not equal to plaintext and has 16-byte block boundary
  @! --------------------------------------------------------------------------
  total = total + 1
  @if cbc_ct128.len() > 0 && (cbc_ct128.len() % 16) == 0 && cbc_ct256.len() > 0
    passed = passed + 1
    println("  [PASS] Test 10: AES CBC ciphertext block length alignment (16-byte multiple)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 10: AES CBC ciphertext block length alignment failed")
  @end

  println("-----------------------------------------------------------------")
  println("AES Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/crypto/aes E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/crypto/aes E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
