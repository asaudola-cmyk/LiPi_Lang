@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — CRYPTOGRAPHY & SECURITY VERIFICATION
@! File: tests/universe/test_crypto.maya
@! ============================================================================

import "universe/core/crypto"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn run_crypto_tests()
  println("==================================================")
  println("▶ [TEST] Running Universe Cryptography Tests...")
  println("==================================================")

  passed = 0
  total = 0

  @! 1. SHA-256 State
  total = total + 1
  ctx = sha256_init()
  ctx = sha256_update(ctx, [0x4d, 0x61, 0x79, 0x61]) @! "Maya"
  h256 = sha256_final(ctx)
  passed = passed + assert_eq(h256.len(), 32, "FIPS SHA-256 State Digest 32 bytes")

  @! 2. SHA-512 Wrapper
  total = total + 1
  h512 = sha512([0x4d, 0x61, 0x79, 0x61])
  passed = passed + assert_eq(h512.len(), 64, "FIPS SHA-512 Digest 64 bytes")

  @! 3. Authentic Ed25519 Sign & Verify
  total = total + 1
  seed32 = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
  ]
  kp = ed25519_keypair_from_seed(seed32)
  msg = [65, 66, 67]
  sig = ed25519_sign(kp.secret_key, msg)
  v = ed25519_verify(kp.public_key, msg, sig)
  passed = passed + assert_eq(v, 1, "Ed25519 authentic signature verified successfully")

  @! 4. Authentic Ed25519 Rejection of Forged Signature
  total = total + 1
  forged_sig = []
  i = 0
  @while i < sig.len()
    b = sig[i]
    @if i == 0 b = b ^ 0xFF @end
    forged_sig = forged_sig.push(b)
    i = i + 1
  @end
  v_bad = ed25519_verify(kp.public_key, msg, forged_sig)
  passed = passed + assert_eq(v_bad, 0, "Ed25519 forged signature rejected")

  println("==================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("✅ All Universe Crypto Tests Passed!")
    return 0
  @else
    return 1
  @end
@end

@fn main()
  return run_crypto_tests()
@end
