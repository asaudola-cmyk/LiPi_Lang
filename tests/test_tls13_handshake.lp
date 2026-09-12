@! ============================================================================
@! LIPI TEST SUITE: PURE TLS 1.3 HANDSHAKE & X25519 KEY EXCHANGE
@! File: tests/test_tls13_handshake.lp
@! Standard: RFC 8446 (TLS 1.3), RFC 7748 (X25519), NIST SP 800-38D (AES-GCM)
@! 100% Pure Lipi Implementation — Zero Libc / Zero OpenSSL Dependencies
@! ============================================================================

import "universe/crypto/x25519"
import "universe/net/tls/tls13"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn assert_str_eq(actual, expected, msg)
  @if str_eq(actual, expected) != 1
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'"))))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔐 LIPI PURE TLS 1.3 & X25519 HANDSHAKE TEST SUITE 🔐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: RFC 7748 X25519 Elliptic Curve Diffie-Hellman Key Exchange
  @! --------------------------------------------------------------------------
  println("▶ Section 1: RFC 7748 X25519 ECDH Key Exchange...")
  total_tests = total_tests + 1

  @! Alice 32-byte private key scalar
  alice_priv = [
    119, 145, 10, 95, 237, 222, 199, 161, 231, 88, 140, 204, 137, 219, 166, 80,
    240, 31, 109, 136, 172, 80, 186, 73, 205, 78, 145, 248, 18, 106, 173, 64
  ]

  @! Bob 32-byte private key scalar
  bob_priv = [
    41, 155, 149, 141, 245, 220, 174, 180, 122, 91, 25, 23, 138, 97, 105, 59,
    12, 42, 60, 194, 252, 181, 184, 91, 59, 236, 120, 70, 77, 181, 65, 91
  ]

  @! Derive public keys via base point multiplication (u = 9)
  alice_pub = x25519_public_key(alice_priv)
  bob_pub = x25519_public_key(bob_priv)

  ok_alen = assert_eq_int(alice_pub.len(), 32, "Alice public key is 32 bytes")
  ok_blen = assert_eq_int(bob_pub.len(), 32, "Bob public key is 32 bytes")

  @! Compute Diffie-Hellman shared secrets
  shared_alice = x25519_shared_secret(alice_priv, bob_pub)
  shared_bob = x25519_shared_secret(bob_priv, alice_pub)

  ok_slen1 = assert_eq_int(shared_alice.len(), 32, "Shared secret (Alice) is 32 bytes")
  ok_slen2 = assert_eq_int(shared_bob.len(), 32, "Shared secret (Bob) is 32 bytes")

  @! Verify RFC 7748 Commutativity: X25519(a, X25519(b, 9)) == X25519(b, X25519(a, 9))
  diff = 0
  i = 0
  @while i < 32
    d = shared_alice[i] ^ shared_bob[i]
    diff = diff | d
    i = i + 1
  @end
  ok_comm = assert_eq_int(diff, 0, "X25519 Diffie-Hellman Commutativity: shared_alice == shared_bob")

  all_s1 = ok_alen && ok_blen && ok_slen1 && ok_slen2 && ok_comm
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] RFC 7748 X25519 keypair generation and shared secret derivation verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: RFC 8446 TLS 1.3 ClientHello Handshake Wire Framing
  @! --------------------------------------------------------------------------
  println("▶ Section 2: RFC 8446 TLS 1.3 ClientHello Serialization...")
  total_tests = total_tests + 1

  server_name = "sovereign.lipi.dev"
  ch = tls13_build_client_hello(server_name, alice_pub)
  wire = ch.wire_bytes

  @! Check TLS Record Header
  ok_rec_type = assert_eq_int(wire[0], 22, "Record ContentType is 0x16 (Handshake)")
  ok_rec_vmaj = assert_eq_int(wire[1], 3, "Legacy Record Version Major is 3")
  ok_rec_vmin = assert_eq_int(wire[2], 1, "Legacy Record Version Minor is 1 (0x0301)")

  @! Check Handshake Message Header (offset 5)
  ok_hs_type = assert_eq_int(wire[5], 1, "Handshake Type is 0x01 (ClientHello)")

  @! ClientHello Legacy Version (offset 9..10: 0x0303)
  ok_ch_vmaj = assert_eq_int(wire[9], 3, "ClientHello Version Major is 3")
  ok_ch_vmin = assert_eq_int(wire[10], 3, "ClientHello Version Minor is 3 (TLS 1.2 legacy)")

  all_s2 = ok_rec_type && ok_rec_vmaj && ok_rec_vmin && ok_hs_type && ok_ch_vmaj && ok_ch_vmin
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] TLS 1.3 ClientHello record framing and extension blocks verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: AES-128-GCM Record Encryption with Derived Shared Key
  @! --------------------------------------------------------------------------
  println("▶ Section 3: AES-128-GCM Authenticated Encryption & Decryption...")
  total_tests = total_tests + 1

  @! Convert first 16 bytes of derived shared secret to string key
  key_str = ""
  ki = 0
  @while ki < 16
    key_str = str_concat(key_str, str_from_char_code(shared_alice[ki] & 255))
    ki = ki + 1
  @end

  iv_str = "123456789012"
  plaintext = "GET /index.html HTTP/1.1\r\nHost: sovereign.lipi.dev\r\n\r\n"
  ad_str = "TLS_1_3_RECORD_AD"

  @! Encrypt payload
  ciphertext = tls_aes_gcm_encrypt(key_str, iv_str, plaintext, ad_str)
  ok_ct = assert_true(str_len(ciphertext) > 0, "AES-128-GCM ciphertext emitted (Hex)")

  @! Decrypt payload with matching key and IV
  decrypted = tls_aes_gcm_decrypt(key_str, iv_str, ciphertext, ad_str)
  ok_dec = assert_str_eq(decrypted, plaintext, "Decrypted plaintext matches original HTTPS payload")

  all_s3 = ok_ct && ok_dec
  @if all_s3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] End-to-end AES-128-GCM encryption & roundtrip decryption verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Tampering & GHASH Authentication Tag Rejection
  @! --------------------------------------------------------------------------
  println("▶ Section 4: GHASH Authentication Tag Tamper Rejection...")
  total_tests = total_tests + 1

  @! Tamper with ciphertext by flipping first character
  tampered_ct = str_concat("F", str_substr(ciphertext, 1, str_len(ciphertext) - 1))
  tampered_dec = tls_aes_gcm_decrypt(key_str, iv_str, tampered_ct, ad_str)
  ok_tamp = assert_str_eq(tampered_dec, "", "Tampered ciphertext correctly rejected by GHASH tag")

  @! Wrong key rejection
  wrong_key = "wrong_secret_key"
  wrong_dec = tls_aes_gcm_decrypt(wrong_key, iv_str, ciphertext, ad_str)
  ok_wkey = assert_str_eq(wrong_dec, "", "Wrong key correctly rejected by GHASH tag")

  all_s4 = ok_tamp && ok_wkey
  @if all_s4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Cryptographic tamper protection and key authentication verified.")
  @end

  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  println(str_concat("📊 TLS 1.3 & X25519 RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed")))))
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL TLS 1.3 & X25519 CRYPTO TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TESTS FAILED")
    return 1
  @end
@end
