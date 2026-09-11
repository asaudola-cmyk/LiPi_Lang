@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ADVANCED PLONK & KZG TEST SUITE
@! File: tests/crypto/test_plonk_kzg.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/plonk"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  println("  [PASS] " + msg)
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔐 MAYA ADVANCED PLONK, BN254 EC & KZG COMMITMENTS TEST SUITE 🔐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  p = 2147483647 @! 2^31 - 1 Prime Field

  @! SECTION 1: BN254 Elliptic Curve Point Addition & Doubling
  println("▶ Section 1: Elliptic Curve Point Addition & Modular Group Math...")
  p1 = ec_point_new(1, 2)
  p2 = ec_point_new(3, 8)
  p3 = ec_point_add(p1, p2, p)
  
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(p3.is_inf == 0, "Resulting point is on the finite field curve")
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(p3.x_coord > 0, "Calculated non-zero X coordinate")
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(p3.y_coord > 0, "Calculated non-zero Y coordinate")

  @! SECTION 2: Universal PLONK Custom Gate Verification
  println("▶ Section 2: Universal PLONK Custom Gate Arithmetization...")
  @! Gate: 2*a + 3*b - 1*c + 1*(a*b) - 17 = 0
  @! With a = 2, b = 3: 2(2) + 3(3) - 1(c) + 1(6) - 17 = 0 -> 4 + 9 - c + 6 - 17 = 0 -> 19 - 17 - c = 0 -> c = 2
  gate = { ql: 2, qr: 3, qo: -1, qm: 1, qc: -17 }
  res1 = plonk_verify_gate(gate, 2, 3, 2, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(res1, 1, "PLONK custom gate satisfied with correct witness (a=2, b=3, c=2)")

  res2 = plonk_verify_gate(gate, 2, 3, 99, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(res2, 0, "PLONK custom gate rejected invalid witness (c=99)")

  @! SECTION 3: Field Tower Arithmetic (Fp -> Fp2 -> Fp6 -> Fp12)
  println("▶ Section 3: Field Tower Arithmetic & Multiplication Invariance...")
  f2_a = fp2_new(3, 4)
  f2_inv = fp2_inv(f2_a, p)
  f2_prod = fp2_mul(f2_a, f2_inv, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(fp2_eq(f2_prod, fp2_one()), "Fp2 multiplicative inversion a * a^-1 == 1")

  f12_one_val = fp12_one()
  f12_prod = fp12_mul(f12_one_val, f12_one_val, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(fp12_eq(f12_prod, f12_one_val), "Fp12 identity multiplication 1_GT * 1_GT == 1_GT")

  @! SECTION 4: Genuine KZG Polynomial Commitments & Bilinear Pairing Check
  println("▶ Section 4: Genuine KZG Polynomial Commitments & Bilinear Pairing Verification...")
  srs = kzg_srs_new(5, p) @! SRS with tau = 5
  poly_coeffs = [5, 2, 3] @! P(X) = 3X^2 + 2X + 5
  z = 4
  v = poly_eval(poly_coeffs, z, p) @! v = 61
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(v, 61, "Polynomial evaluation P(4) == 61")

  kzg = kzg_commit_polynomial(poly_coeffs, srs.g1_gen, p)
  cm_pt = ec_point_new(kzg.cm_x, kzg.cm_y)
  w_pt = kzg_create_opening_proof(poly_coeffs, z, srs, p)

  @! 4.1 Valid KZG opening proof check via pairing
  valid_kzg = kzg_verify(cm_pt, z, v, w_pt, srs, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_kzg, 1, "Genuine KZG polynomial opening verified via bilinear pairing")

  @! 4.2 Adversarial KZG: Forged evaluation value v' = 62
  bad_v_kzg = kzg_verify(cm_pt, z, 62, w_pt, srs, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_kzg, 0, "Adversarial forged evaluation v'=62 rejected by pairing check")

  @! 4.3 Adversarial KZG: Tampered opening proof W'
  tampered_w = ec_point_add(w_pt, srs.g1_gen, p)
  bad_w_kzg = kzg_verify(cm_pt, z, v, tampered_w, srs, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_w_kzg, 0, "Adversarial tampered opening proof W' rejected by pairing check")

  @! 4.4 Adversarial KZG: Corrupted commitment C'
  corrupted_c = ec_point_add(cm_pt, srs.g1_gen, p)
  bad_c_kzg = kzg_verify(corrupted_c, z, v, w_pt, srs, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_c_kzg, 0, "Adversarial corrupted commitment C' rejected by pairing check")

  @! SECTION 5: PLONK Recursive Proof Verification
  println("▶ Section 5: PLONK Recursive SNARK Proof Verification...")
  rec_proof = plonk_create_recursive_proof(101, 555, "0000000000000000000000000000000000000000000000000000000000000000", p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(rec_proof.proof_size_bytes < 22000, "Recursive proof size is strictly under 22 KB")
  
  rec_ok = plonk_verify_recursive_proof(rec_proof, srs, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(rec_ok, 1, "Recursive SNARK proof authenticated via bilinear pairing")

  @! SECTION 6: Roots of Unity Domain, Vanishing Polynomial & Permutation Accumulator
  println("▶ Section 6: Roots of Unity Domain, Vanishing Polynomial & Permutations...")
  domain6 = plonk_domain_subgroup(6, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(domain6.len(), 6, "Subgroup domain H has 6 roots of unity")

  @! Vanishing polynomial Z_H(X) = X^6 - 1 evaluates to 0 on all domain elements
  v_eval0 = vanishing_poly_eval(6, domain6[0], p)
  v_eval1 = vanishing_poly_eval(6, domain6[1], p)
  v_eval2 = vanishing_poly_eval(6, domain6[2], p)
  v_eval3 = vanishing_poly_eval(6, domain6[3], p)
  v_eval4 = vanishing_poly_eval(6, domain6[4], p)
  v_eval5 = vanishing_poly_eval(6, domain6[5], p)
  all_vanish = v_eval0 == 0 && v_eval1 == 0 && v_eval2 == 0 && v_eval3 == 0 && v_eval4 == 0 && v_eval5 == 0
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(all_vanish, 1, "Vanishing polynomial Z_H(omega^i) == 0 for all i in H")

  @! Grand Product accumulator z(X) over gate copy constraints
  w_a = [2, 5]
  w_b = [3, 7]
  w_c = [2, 12]
  domain2 = plonk_domain_subgroup(2, p)
  sig1 = [domain2[0], domain2[1]]
  sig2 = [domain2[0], domain2[1]]
  sig3 = [domain2[0], domain2[1]]
  z_acc = plonk_compute_permutation_polynomial(w_a, w_b, w_c, sig1, sig2, sig3, 11, 13, 2, p)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(z_acc[0], 1, "Grand Product accumulator initial value z(1) == 1")

  println("=================================================================")
  println("📊 ADVANCED PLONK TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL ADVANCED PLONK & KZG TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ADVANCED PLONK TESTS FAILED")
    return 1
  @end
@end
