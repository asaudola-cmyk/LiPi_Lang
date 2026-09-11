@! Maya TLS Crypto Unit Tests

import "universe/core/string"
import "universe/core/collections"
import "universe/net/tls/tls13"
import "universe/net/tls/record"

@fn assert_eq(actual, expected, msg)
  @! Dual-mode equality assertion for integer values and string pointers without pointer +
  @! WHY: Compares primitive ints via == and dynamic string pointers via str_eq, preventing memory corruption
  is_match = 0
  @if actual == expected
    is_match = 1
  @elif actual > 65536 && expected > 65536
    @if str_eq(actual, expected) == 1
      is_match = 1
    @end
  @end

  @if is_match == 1
    println(str_concat("  [PASS] ", msg))
    return 1
  @else
    println(str_concat("  [FAIL] ", msg))
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA TLS CRYPTO UNIT TEST SUITE                ")
  println("==================================================")
  
  passed = 0
  total = 0

  @! 1. Session State
  total = total + 1
  session = tls_session_new()
  passed = passed + assert_eq(session.state, "HANDSHAKE", "TLS Session state is HANDSHAKE")
  
  @! 2. AES-GCM Roundtrip Encryption & Decryption
  pt = "HelloMaya"
  key = "secret_session_key_1234567890abc"
  iv = "unique_iv_12"
  ad = "tls13_additional_authenticated_data"
  
  ct = tls_aes_gcm_encrypt(key, iv, pt, ad)
  
  total = total + 1
  is_diff = 0
  @if str_eq(ct, pt) == 0
    is_diff = 1
  @end
  passed = passed + assert_eq(is_diff, 1, "AES-GCM encrypted text differs from plaintext")
  
  total = total + 1
  dec = tls_aes_gcm_decrypt(key, iv, ct, ad)
  passed = passed + assert_eq(dec, pt, "AES-GCM decryption recovers plaintext")
  
  @! 3. Dynamic Key Differentiation
  total = total + 1
  key2 = "different_secret_key_9876543210x"
  ct2 = tls_aes_gcm_encrypt(key2, iv, pt, ad)
  is_diff_key = 0
  @if str_eq(ct, ct2) == 0
    is_diff_key = 1
  @end
  passed = passed + assert_eq(is_diff_key, 1, "Different secret keys produce different ciphertexts")

  @! 4. Tampering & Authentication Tag Verification
  total = total + 1
  @! Decrypting with wrong key must fail (rejecting authentication tag)
  bad_dec_key = tls_aes_gcm_decrypt(key2, iv, ct, ad)
  passed = passed + assert_eq(bad_dec_key, "", "Decryption with incorrect key rejected by GHASH tag")

  total = total + 1
  @! Decrypting with tampered AAD must fail
  bad_dec_ad = tls_aes_gcm_decrypt(key, iv, ct, "tampered_ad")
  passed = passed + assert_eq(bad_dec_ad, "", "Decryption with tampered AAD rejected by GHASH tag")

  total = total + 1
  @! Decrypting tampered ciphertext must fail
  tampered_ct = str_concat(ct, "x")
  bad_dec_ct = tls_aes_gcm_decrypt(key, iv, tampered_ct, ad)
  passed = passed + assert_eq(bad_dec_ct, "", "Decryption with corrupted ciphertext rejected")

  @! 5. NIST SP 800-38D Standard Test Vector (AES-128-GCM Case 2)
  total = total + 1
  zero_key_bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  zero_iv_bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  zero_pt_bytes = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  nist_raw_out = tls_aes_gcm_encrypt_raw(zero_key_bytes, zero_iv_bytes, zero_pt_bytes, [])
  nist_ct = tls_bytes_to_hex(nist_raw_out)
  expected_nist_ct = "0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf"
  passed = passed + assert_eq(nist_ct, expected_nist_ct, "NIST SP 800-38D AES-128-GCM standard test vector matched")

  @! 6. TLS 1.3 Record Layer Framing & Roundtrip
  total = total + 1
  rec_layer = record_layer_with_keys(key, iv)
  framed = record_layer_encrypt(rec_layer, "ApplicationPayloadData", 23)
  is_framed_diff = 0
  @if str_eq(framed, "ApplicationPayloadData") == 0
    is_framed_diff = 1
  @end
  passed = passed + assert_eq(is_framed_diff, 1, "TLS 1.3 record layer framing produces encrypted envelope")

  total = total + 1
  dec_layer = record_layer_with_keys(key, iv)
  unframed = record_layer_decrypt(dec_layer, framed)
  passed = passed + assert_eq(unframed, "ApplicationPayloadData", "TLS 1.3 record layer decryption recovers payload")

  println("--------------------------------------------------")
  summary_msg = str_concat("TLS Crypto Test Summary: ", str_concat(to_str(passed), str_concat(" / ", str_concat(to_str(total), " passed"))))
  println(summary_msg)
  @if passed == total
    println("🎉 ALL TLS CRYPTO TESTS PASSED!")
    return 0
  @else
    println("❌ SOME TLS CRYPTO TESTS FAILED")
    return 1
  @end
@end
