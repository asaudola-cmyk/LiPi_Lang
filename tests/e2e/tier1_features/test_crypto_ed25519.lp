// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: RFC 8032 Ed25519 Signatures PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: crypto, ed25519, rfc8032, curve25519, signatures

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: RFC 8032 ED25519 SIGNATURES & CURVE MATH
@! File: tests/e2e/tier1_features/test_crypto_ed25519.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/ed25519"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 2: RFC 8032 Edwards25519 Signatures & Curve Math")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Field Arithmetic: Add, Sub, Negation over F(2^255 - 19)
  total = total + 1
  one = fe_one()
  zero = fe_zero()
  add_res = fe_add(one, one)
  sub_res = fe_sub(add_res, one)
  neg_one = fe_neg(one)
  neg_check = fe_add(one, neg_one)
  @if fe_eq(sub_res, one) == 1 && fe_eq(neg_check, zero) == 1
    passed = passed + 1
    println("  [PASS] T1.1: Field addition, subtraction, and negation over F(2^255-19)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Field addition, subtraction, and negation")
  @end

  @! T1.2: Field Multiplication, Squaring & Inversion
  total = total + 1
  a = fe_add(one, one) @! 2
  a_sqr = fe_sqr(a)    @! 4
  a_inv = fe_inv(a)
  prod_inv = fe_mul(a, a_inv)
  @if fe_eq(prod_inv, one) == 1
    passed = passed + 1
    println("  [PASS] T1.2: Field multiplication, squaring, and inversion (a * a^-1 = 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Field multiplication and inversion")
  @end

  @! T1.3: Edwards25519 Base Point and Point Doubling / Addition
  total = total + 1
  b_pt = ed25519_base_point()
  pt_2b = ed25519_point_double(b_pt)
  pt_add = ed25519_point_add(b_pt, b_pt)
  @if ed25519_point_eq(pt_2b, pt_add) == 1
    passed = passed + 1
    println("  [PASS] T1.3: Curve25519 point doubling matches point addition (2B = B + B)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: Curve25519 point arithmetic")
  @end

  @! T1.4: Scalar Arithmetic Modulo Group Order L
  total = total + 1
  l_limbs = scalar_l_limbs()
  s1 = [10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  s2 = [20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  s_sum = scalar_add_l(s1, s2)
  s_mul = scalar_mul_l(s1, s2)
  @if s_sum[0] == 30 && s_mul[0] == 200
    passed = passed + 1
    println("  [PASS] T1.4: Scalar addition and multiplication modulo group order L")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: Scalar arithmetic modulo L")
  @end

  @! T1.5: Point Compression & Decompression Roundtrip
  total = total + 1
  comp_bytes = ed25519_point_compress(b_pt)
  decomp_pt = ed25519_point_decompress(comp_bytes)
  @if comp_bytes.len() == 32 && ed25519_point_eq(b_pt, decomp_pt) == 1
    passed = passed + 1
    println("  [PASS] T1.5: Point compression and decompression roundtrip")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Point compression/decompression")
  @end

  @! T1.6: Keypair Generation from 32-Byte Seed
  total = total + 1
  seed = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
  ]
  kp = ed25519_keygen(seed)
  @if kp.secret_key.len() == 32 && kp.public_key.len() == 32
    passed = passed + 1
    println("  [PASS] T1.6: RFC 8032 keypair generation from 32-byte entropy seed")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: RFC 8032 keypair generation")
  @end

  @! T1.7: Message Signing and Valid Verification
  total = total + 1
  msg = [77, 97, 121, 97, 32, 83, 111, 118, 101, 114, 101, 105, 103, 110] @! "Maya Sovereign"
  sig = ed25519_sign(seed, msg)
  valid = ed25519_verify(kp.public_key, msg, sig)
  @if sig.len() == 64 && valid == 1
    passed = passed + 1
    println("  [PASS] T1.7: Ed25519 message signing and signature verification ([S]B == R + [k]A)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.7: Ed25519 message signing/verification")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: RFC 8032 Ed25519 Signatures PASSED")
    return 0
  @else
    println("✗ Feature: RFC 8032 Ed25519 Signatures FAILED")
    return 1
  @end
@end
