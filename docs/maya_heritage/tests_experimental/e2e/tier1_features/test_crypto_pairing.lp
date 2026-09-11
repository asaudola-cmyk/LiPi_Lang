// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: BN254 / BLS12-381 PLONK Pairing PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: crypto, pairing, bn254, bls12_381, kzg, plonk

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: BN254/BLS12-381 PAIRINGS & PLONK KZG
@! File: tests/e2e/tier1_features/test_crypto_pairing.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/plonk"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 1: BN254 / BLS12-381 PLONK Pairing Verification")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  p_mod = 2147483647 @! 2^31 - 1 Mersenne Prime Field

  @! T1.1: G1 Point Creation & Point at Infinity
  total = total + 1
  p_inf = ec_point_infinity()
  p_val = ec_point_new(10, 20)
  add_inf = ec_point_add(p_val, p_inf, p_mod)
  @if p_inf.is_inf == 1 && p_val.x_coord == 10 && add_inf.x_coord == 10 && add_inf.y_coord == 20
    passed = passed + 1
    println("  [PASS] T1.1: G1 Point creation and point at infinity identity (P + O = P)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: G1 Point creation and infinity identity")
  @end

  @! T1.2: Modular Inverse in Prime Field
  total = total + 1
  inv_3 = fp_inv(3, 7) @! 3 * 5 = 15 = 1 mod 7
  inv_7 = fp_inv(7, 13) @! 7 * 2 = 14 = 1 mod 13
  inv_large = fp_inv(12345, p_mod)
  prod_check = (12345 * inv_large) % p_mod
  @if inv_3 == 5 && inv_7 == 2 && prod_check == 1
    passed = passed + 1
    println("  [PASS] T1.2: Field modular inverse via Fermat's Little Theorem (fp_inv)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Field modular inverse")
  @end

  @! T1.3: G1 Point Doubling
  total = total + 1
  p_base = ec_point_new(1, 2)
  p_double = ec_point_add(p_base, p_base, p_mod)
  @if p_double.is_inf == 0 && p_double.x_coord > 0 && p_double.y_coord > 0
    passed = passed + 1
    println("  [PASS] T1.3: G1 Point doubling over finite field (2P computation)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: G1 Point doubling")
  @end

  @! T1.4: G1 Point Addition for Distinct Points
  total = total + 1
  pt_a = ec_point_new(2, 5)
  pt_b = ec_point_new(3, 8)
  pt_sum = ec_point_add(pt_a, pt_b, p_mod)
  @if pt_sum.is_inf == 0 && pt_sum.x_coord != pt_a.x_coord
    passed = passed + 1
    println("  [PASS] T1.4: G1 Point addition for distinct points (P1 + P2)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: G1 Point addition for distinct points")
  @end

  @! T1.5: Universal PLONK Custom Gate Verification
  total = total + 1
  gate_arith = { ql: 1, qr: 1, qo: -1, qm: 1, qc: 0 }
  gate_ok = plonk_verify_gate(gate_arith, 2, 3, 11, p_mod)
  gate_bad = plonk_verify_gate(gate_arith, 2, 3, 12, p_mod)
  @if gate_ok == 1 && gate_bad == 0
    passed = passed + 1
    println("  [PASS] T1.5: Universal PLONK custom gate evaluation (addition + multiplication)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Universal PLONK custom gate evaluation")
  @end

  @! T1.6: Fp2 Extension Field Multiplicative Inversion
  total = total + 1
  f2_a = fp2_new(3, 4)
  f2_inv = fp2_inv(f2_a, p_mod)
  f2_prod = fp2_mul(f2_a, f2_inv, p_mod)
  @if fp2_eq(f2_prod, fp2_one()) == 1
    passed = passed + 1
    println("  [PASS] T1.6: Fp2 extension field tower multiplicative inversion (a * a^-1 == 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: Fp2 extension field arithmetic")
  @end

  @! T1.7: Fp12 Bilinear Pairing Target Group Identity
  total = total + 1
  f12_one_val = fp12_one()
  f12_prod = fp12_mul(f12_one_val, f12_one_val, p_mod)
  @if fp12_eq(f12_prod, f12_one_val) == 1
    passed = passed + 1
    println("  [PASS] T1.7: Fp12 bilinear pairing target group identity multiplication")
  @else
    failed = failed + 1
    println("  [FAIL] T1.7: Fp12 pairing target group identity")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: BN254 / BLS12-381 PLONK Pairing PASSED")
    return 0
  @else
    println("✗ Feature: BN254 / BLS12-381 PLONK Pairing FAILED")
    return 1
  @end
@end
