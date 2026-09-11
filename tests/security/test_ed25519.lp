@! ============================================================================
@! MAYA SECURITY TEST SUITE — ED25519 CRYPTOGRAPHIC SIGNATURES
@! File: tests/security/test_ed25519.maya
@! ============================================================================

import "universe/security/ed25519"
import "universe/crypto/ed25519"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA ED25519 SECURITY & SIGNATURE TEST SUITE   ")
  println("==================================================")
  
  passed = 0
  total = 0

  @! Test 1: Keypair derivation from seed
  total = total + 1
  seed = [
    0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60,
    0xba, 0x84, 0x4a, 0xf4, 0x92, 0xec, 0x2c, 0xc4,
    0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19,
    0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60
  ]
  kp = ed25519_keygen_sec(seed)
  passed = passed + assert_eq(kp.public_key.len(), 32, "Public key is 32 bytes")

  @! Test 2: Authentic RFC 8032 signature generation & verification
  total = total + 1
  msg = [77, 97, 121, 97, 32, 83, 101, 99, 117, 114, 105, 116, 121] @! "Maya Security"
  sig = ed25519_sign_sec(kp.secret_key, msg)
  passed = passed + assert_eq(sig.len(), 64, "Signature is 64 bytes")

  total = total + 1
  v = ed25519_verify_sec(kp.public_key, msg, sig)
  passed = passed + assert_eq(v, 1, "Ed25519 authentic signature verifies successfully")

  @! Test 3: Rejection of forged signature
  total = total + 1
  forged_sig = []
  i = 0
  @while i < sig.len()
    b = sig[i]
    @if i == 0 b = b ^ 0xFF @end
    forged_sig = forged_sig.push(b)
    i = i + 1
  @end
  v_forged = ed25519_verify_sec(kp.public_key, msg, forged_sig)
  passed = passed + assert_eq(v_forged, 0, "Forged signature strictly rejected by verifier")

  @! Test 4: Rejection of tampered message
  total = total + 1
  tampered_msg = [77, 97, 121, 97, 32, 83, 101, 99, 117, 114, 105, 116, 122]
  v_tampered = ed25519_verify_sec(kp.public_key, tampered_msg, sig)
  passed = passed + assert_eq(v_tampered, 0, "Tampered message strictly rejected by verifier")

  println("==================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("🎉 ALL ED25519 SIGNATURE TESTS PASSED!")
    return 0
  @else
    return 1
  @end
@end
