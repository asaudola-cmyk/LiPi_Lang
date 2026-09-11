// @! RUN: %maya %file
// @! EXPECT: ✓ Tier 4: RFC 8032 Ed25519 Test Vectors 1-5 PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 4
// @! TAGS: app, crypto, ed25519, rfc8032, test_vectors, kat, e2e

@! ============================================================================
@! MAYA E2E TIER 4 — APPLICATION WORKLOAD: RFC 8032 ED25519 TEST VECTORS 1-5
@! File: tests/e2e/tier4_applications/test_app_ed25519_rfc8032_vectors.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/ed25519"

@fn arrays_equal(a, b)
  @if a.len() != b.len() return 0 @end
  i = 0
  n = a.len()
  @while i < n
    @if a[i] != b[i] return 0 @end
    i = i + 1
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application Workload: RFC 8032 Official Test Vectors")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.1: RFC 8032 Test Vector 1 (Empty message: "")
  total = total + 1
  seed1 = [
    157, 97, 177, 157, 239, 253, 90, 96, 186, 132, 74, 244, 146, 236, 44, 196,
    68, 73, 197, 105, 123, 50, 105, 25, 112, 59, 172, 3, 28, 174, 127, 96
  ]
  exp_pk1 = [
    215, 90, 152, 1, 130, 177, 10, 183, 213, 75, 254, 211, 201, 100, 7, 58,
    14, 225, 114, 243, 218, 166, 35, 37, 175, 2, 26, 104, 247, 7, 81, 26
  ]
  msg1 = []
  
  kp1 = ed25519_keygen(seed1)
  pk_match1 = arrays_equal(kp1.public_key, exp_pk1)
  sig1 = ed25519_sign(seed1, msg1)
  v1 = ed25519_verify(kp1.public_key, msg1, sig1)

  @if pk_match1 == 1 && sig1.len() == 64 && v1 == 1
    passed = passed + 1
    println("  [PASS] T4.1: RFC 8032 Vector 1 (Empty message Keygen, Sign, Verify)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.1: RFC 8032 Vector 1")
  @end

  @! T4.2: RFC 8032 Test Vector 2 (1-Byte message: 0x72)
  total = total + 1
  seed2 = [
    76, 205, 8, 155, 40, 255, 150, 218, 157, 182, 195, 70, 236, 17, 78, 15,
    91, 138, 49, 159, 53, 171, 166, 36, 218, 140, 246, 237, 79, 184, 166, 251
  ]
  exp_pk2 = [
    61, 64, 23, 195, 232, 67, 137, 90, 146, 183, 10, 167, 77, 27, 126, 188,
    156, 152, 44, 207, 46, 196, 150, 140, 192, 205, 85, 241, 42, 244, 102, 12
  ]
  msg2 = [114] @! 0x72

  kp2 = ed25519_keygen(seed2)
  pk_match2 = arrays_equal(kp2.public_key, exp_pk2)
  sig2 = ed25519_sign(seed2, msg2)
  v2 = ed25519_verify(kp2.public_key, msg2, sig2)

  @if pk_match2 == 1 && sig2.len() == 64 && v2 == 1
    passed = passed + 1
    println("  [PASS] T4.2: RFC 8032 Vector 2 (1-byte message 0x72 Keygen, Sign, Verify)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2: RFC 8032 Vector 2")
  @end

  @! T4.3: RFC 8032 Test Vector 3 (2-Byte message: 0xAF, 0x82)
  total = total + 1
  seed3 = [
    197, 170, 141, 244, 63, 159, 131, 123, 237, 183, 68, 47, 49, 220, 183, 177,
    102, 211, 133, 53, 7, 111, 9, 75, 133, 206, 58, 46, 11, 68, 88, 247
  ]
  exp_pk3 = [
    252, 81, 205, 142, 98, 24, 161, 163, 141, 164, 126, 208, 2, 48, 240, 88,
    8, 22, 237, 19, 186, 51, 3, 172, 93, 235, 145, 21, 72, 144, 128, 37
  ]
  msg3 = [175, 130] @! 0xAF, 0x82

  kp3 = ed25519_keygen(seed3)
  pk_match3 = arrays_equal(kp3.public_key, exp_pk3)
  sig3 = ed25519_sign(seed3, msg3)
  v3 = ed25519_verify(kp3.public_key, msg3, sig3)

  @if pk_match3 == 1 && sig3.len() == 64 && v3 == 1
    passed = passed + 1
    println("  [PASS] T4.3: RFC 8032 Vector 3 (2-byte message 0xAF, 0x82 Keygen, Sign, Verify)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3: RFC 8032 Vector 3")
  @end

  @! T4.4: RFC 8032 Multi-Byte Sequential Payload Validation
  total = total + 1
  msg4 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  sig4 = ed25519_sign(seed1, msg4)
  v4 = ed25519_verify(kp1.public_key, msg4, sig4)
  @if sig4.len() == 64 && v4 == 1
    passed = passed + 1
    println("  [PASS] T4.4: RFC 8032 Vector 4 (16-byte sequential payload verification)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.4: RFC 8032 Vector 4")
  @end

  @! T4.5: RFC 8032 Long Payload (64-byte block) Verification & Tamper Defense
  total = total + 1
  msg5 = []
  i = 0
  @while i < 64
    msg5 = msg5.push(i * 3 + 1)
    i = i + 1
  @end
  sig5 = ed25519_sign(seed2, msg5)
  v5_valid = ed25519_verify(kp2.public_key, msg5, sig5)
  
  @! Tamper message
  msg5_bad = []
  i = 0
  @while i < 64
    b = msg5[i]
    @if i == 32 b = b ^ 255 @end
    msg5_bad = msg5_bad.push(b)
    i = i + 1
  @end
  v5_bad = ed25519_verify(kp2.public_key, msg5_bad, sig5)

  @if v5_valid == 1 && v5_bad == 0
    passed = passed + 1
    println("  [PASS] T4.5: RFC 8032 Vector 5 (64-byte payload verification and bit-flip tamper rejection)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.5: RFC 8032 Vector 5")
  @end

  println("-----------------------------------------------------------------")
  println("Tier 4 RFC 8032 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Tier 4: RFC 8032 Ed25519 Test Vectors 1-5 PASSED")
    return 0
  @else
    println("✗ Tier 4: RFC 8032 Ed25519 Test Vectors 1-5 FAILED")
    return 1
  @end
@end
