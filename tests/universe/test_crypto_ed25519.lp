@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — RFC 8032 ED25519 CONFORMANCE & ADVERSARIAL
@! ============================================================================

import "universe/crypto/ed25519"

@fn assert_eq_int(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (expected=" + expected.to_str() + ", actual=" + actual.to_str() + ")")
    return 0
  @end
@end

@fn bytes_match(b1, b2)
  @if b1.len() != b2.len()
    return 0
  @end
  i = 0
  len = b1.len()
  @while i < len
    @if (b1[i] & 255) != (b2[i] & 255)
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn main()
  println("==================================================")
  println("   MAYA ED25519 RFC 8032 CONFORMANCE & SECURITY   ")
  println("==================================================")

  passed = 0
  total = 0

  @! Vector 1: Empty message
  @! Seed: 9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60
  sk1 = [
    0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60,
    0xba, 0x84, 0x4a, 0xf4, 0x92, 0xec, 0x2c, 0xc4,
    0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19,
    0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60
  ]
  exp_pk1 = [
    0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
    0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
    0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
    0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a
  ]
  exp_sig1 = [
    0xe5, 0x56, 0x43, 0x00, 0xc3, 0x60, 0xac, 0x72,
    0x90, 0x86, 0xe2, 0xcc, 0x80, 0x6e, 0x82, 0x8a,
    0x84, 0x87, 0x7f, 0x1e, 0xb8, 0xe5, 0xd9, 0x74,
    0xd8, 0x73, 0xe0, 0x65, 0x22, 0x49, 0x01, 0x55,
    0x5f, 0xb8, 0x82, 0x15, 0x90, 0xa3, 0x3b, 0xac,
    0xc6, 0x1e, 0x39, 0x70, 0x1c, 0xf9, 0xb4, 0x6b,
    0xd2, 0x5b, 0xf5, 0xf0, 0x59, 0x5b, 0xbe, 0x24,
    0x65, 0x51, 0x41, 0x43, 0x8e, 0x7a, 0x10, 0x0b
  ]

  total = total + 1
  kp1 = ed25519_keygen(sk1)
  pk_match1 = bytes_match(kp1.public_key, exp_pk1)
  passed = passed + assert_eq_int(pk_match1, 1, "RFC 8032 Vector 1 public key matches expected")

  total = total + 1
  sig1 = ed25519_sign(sk1, [])
  sig_match1 = bytes_match(sig1, exp_sig1)
  passed = passed + assert_eq_int(sig_match1, 1, "RFC 8032 Vector 1 signature matches expected")

  total = total + 1
  v1 = ed25519_verify(kp1.public_key, [], sig1)
  passed = passed + assert_eq_int(v1, 1, "RFC 8032 Vector 1 signature verified successfully")

  @! Vector 2: 1-byte message [0x72]
  sk2 = [
    0x4c, 0xcd, 0x08, 0x9b, 0x28, 0xff, 0x96, 0xda,
    0x9d, 0xb6, 0xc3, 0x46, 0xec, 0x11, 0x4e, 0x0f,
    0x5b, 0x8a, 0x31, 0x9f, 0x35, 0xab, 0xa6, 0x24,
    0xda, 0x8c, 0xf6, 0xed, 0x4f, 0xb8, 0xa6, 0xfb
  ]
  exp_pk2 = [
    0x3d, 0x40, 0x17, 0xc3, 0xe8, 0x43, 0x89, 0x5a,
    0x92, 0xb7, 0x0a, 0xa7, 0x4d, 0x1b, 0x7e, 0xbc,
    0x9c, 0x98, 0x2c, 0xcf, 0x2e, 0xc4, 0x96, 0x8c,
    0xc0, 0xcd, 0x55, 0xf1, 0x2a, 0xf4, 0x66, 0x0c
  ]
  exp_sig2 = [
    0x92, 0xa0, 0x09, 0xa9, 0xf0, 0xd4, 0xca, 0xb8,
    0x72, 0x0e, 0x82, 0x0b, 0x5f, 0x64, 0x25, 0x40,
    0xa2, 0xb2, 0x7b, 0x54, 0x16, 0x50, 0x3f, 0x8f,
    0xb3, 0x76, 0x22, 0x23, 0xeb, 0xdb, 0x69, 0xda,
    0x08, 0x5a, 0xc1, 0xe4, 0x3e, 0x15, 0x99, 0x6e,
    0x45, 0x8f, 0x36, 0x13, 0xd0, 0xf1, 0x1d, 0x8c,
    0x38, 0x7b, 0x2e, 0xae, 0xb4, 0x30, 0x2a, 0xee,
    0xb0, 0x0d, 0x29, 0x16, 0x12, 0xbb, 0x0c, 0x00
  ]

  total = total + 1
  kp2 = ed25519_keygen(sk2)
  pk_match2 = bytes_match(kp2.public_key, exp_pk2)
  passed = passed + assert_eq_int(pk_match2, 1, "RFC 8032 Vector 2 public key matches expected")

  total = total + 1
  sig2 = ed25519_sign(sk2, [0x72])
  sig_match2 = bytes_match(sig2, exp_sig2)
  passed = passed + assert_eq_int(sig_match2, 1, "RFC 8032 Vector 2 signature matches expected")

  total = total + 1
  v2 = ed25519_verify(kp2.public_key, [0x72], sig2)
  passed = passed + assert_eq_int(v2, 1, "RFC 8032 Vector 2 signature verified successfully")

  @! SECTION 3: ADVERSARIAL FORGERY & TAMPERING TESTS
  println("▶ Section 3: Adversarial Forgery & Malleability Rejection...")

  @! Adversarial 1: Message tampering
  total = total + 1
  tampered_msg = [0x73] @! Modified byte from 0x72 to 0x73
  v_bad_msg = ed25519_verify(kp2.public_key, tampered_msg, sig2)
  passed = passed + assert_eq_int(v_bad_msg, 0, "Tampered message rejected by Ed25519 verifier")

  @! Adversarial 2: Signature corruption (flip byte 0)
  total = total + 1
  corrupted_sig = []
  i = 0
  @while i < sig2.len()
    b = sig2[i]
    @if i == 0
      b = b ^ 0xFF
    @end
    corrupted_sig = corrupted_sig.push(b)
    i = i + 1
  @end
  v_bad_sig = ed25519_verify(kp2.public_key, [0x72], corrupted_sig)
  passed = passed + assert_eq_int(v_bad_sig, 0, "Corrupted signature byte rejected by Ed25519 verifier")

  @! Adversarial 3: Wrong public key
  total = total + 1
  v_wrong_pk = ed25519_verify(kp1.public_key, [0x72], sig2)
  passed = passed + assert_eq_int(v_wrong_pk, 0, "Signature rejected when verified with wrong public key")

  @! Adversarial 4: Non-canonical scalar S >= L
  total = total + 1
  bad_s_sig = []
  i = 0
  @while i < 32
    bad_s_sig = bad_s_sig.push(sig2[i])
    i = i + 1
  @end
  @while i < 64
    bad_s_sig = bad_s_sig.push(0xFF) @! S is maxed out, S > L
    i = i + 1
  @end
  v_bad_s = ed25519_verify(kp2.public_key, [0x72], bad_s_sig)
  passed = passed + assert_eq_int(v_bad_s, 0, "Non-canonical S >= L rejected by RFC 8032 verifier")

  println("==================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("🎉 ALL ED25519 CONFORMANCE & ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    return 1
  @end
@end
