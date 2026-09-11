@! ============================================================================
@! MAYA ADVERSARIAL CRYPTOGRAPHIC INTEGRITY & STRESS TEST SUITE
@! Module: tests/adversarial/test_crypto_adversarial_phase1_kzg_rsa.maya
@! Focus: Phase 1 Challenger 1 — KZG Polynomial Commitments, BN254 Pairings,
@!        RSA Extended GCD, BigInt & Plonk Custom Gates
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/plonk"
import "universe/crypto/rsa"
import "universe/security/rsa"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  ❌ [FAIL] " + msg)
    return 0
  @end
  println("  ✅ [PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " (Actual: " + actual.to_str() + ", Expected: " + expected.to_str() + ")")
    return 0
  @end
  println("  ✅ [PASS] " + msg)
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔥 CHALLENGER 1: ADVERSARIAL STRESS & INTEGRITY MATRIX 🔥")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  p_field = 2147483647 @! 2^31 - 1 Prime Field for BN254 pairing engine

  @! ============================================================================
  @! SECTION 1: KZG POLYNOMIAL COMMITMENT ADVERSARIAL STRESS MATRIX
  @! ============================================================================
  println("\n▶▶ [SUITE 1] KZG Polynomial Commitment Soundness & Forgery Resistance...")
  
  srs = kzg_srs_new(5, p_field) @! Standard SRS with tau = 5
  
  @! Poly 1: Quadratic P(X) = 4X^2 + 7X + 11 at evaluation point z = 4 (tau - z = 1)
  poly1 = [11, 7, 4]
  z1 = 4
  v1 = poly_eval(poly1, z1, p_field) @! 4(16) + 7(4) + 11 = 64 + 28 + 11 = 103
  
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(v1, 103, "Poly 1: P(4) evaluates to 103")

  kzg1 = kzg_commit_polynomial(poly1, srs.g1_gen, p_field)
  cm_pt1 = ec_point_new(kzg1.cm_x, kzg1.cm_y)
  w_pt1 = kzg_create_opening_proof(poly1, z1, srs, p_field)

  @! 1.1 Authentic Verification
  valid_check1 = kzg_verify(cm_pt1, z1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_check1, 1, "Authentic KZG proof strictly accepts: e(W, [tau-z]_2) == e(C - v[1]_1, [1]_2)")

  @! 1.2 Adversarial Forged Evaluations (v' != P(z))
  @! Case A: Off-by-one positive (v' = v + 1)
  bad_v_1 = kzg_verify(cm_pt1, z1, v1 + 1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_1, 0, "Adversarial: Off-by-one evaluation (v' = v + 1) strictly REJECTED")

  @! Case B: Off-by-one negative (v' = v - 1)
  bad_v_2 = kzg_verify(cm_pt1, z1, v1 - 1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_2, 0, "Adversarial: Off-by-one evaluation (v' = v - 1) strictly REJECTED")

  @! Case C: Zero evaluation (v' = 0)
  bad_v_3 = kzg_verify(cm_pt1, z1, 0, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_3, 0, "Adversarial: Zero evaluation (v' = 0) strictly REJECTED")

  @! Case D: Field boundary evaluation (v' = p_field - 1)
  bad_v_4 = kzg_verify(cm_pt1, z1, p_field - 1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_4, 0, "Adversarial: Field boundary evaluation (v' = p-1) strictly REJECTED")

  @! Case E: Arbitrary large forged evaluation
  bad_v_5 = kzg_verify(cm_pt1, z1, 123456789, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_v_5, 0, "Adversarial: Large forged evaluation (123456789) strictly REJECTED")

  @! 1.3 Adversarial Invalid Evaluation Points (z' != z)
  @! Case A: z' = z + 1
  bad_z_1 = kzg_verify(cm_pt1, z1 + 1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_z_1, 0, "Adversarial: Evaluation point mismatch (z' = z + 1) strictly REJECTED")

  @! Case B: z' = 0
  bad_z_2 = kzg_verify(cm_pt1, 0, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_z_2, 0, "Adversarial: Evaluation point at origin (z' = 0) strictly REJECTED")

  @! Case C: Singularity evaluation point z' = tau (tau - z = 0)
  bad_z_3 = kzg_verify(cm_pt1, srs.tau, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_z_3, 0, "Adversarial: Singularity evaluation point (z' = tau) strictly REJECTED")

  @! 1.4 Adversarial Forged Commitments (C')
  @! Case A: Shifted commitment C' = C + G1
  bad_c_1 = ec_point_add(cm_pt1, srs.g1_gen, p_field)
  bad_c_res1 = kzg_verify(bad_c_1, z1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_c_res1, 0, "Adversarial: Shifted commitment (C + G1) strictly REJECTED")

  @! Case B: Scaled commitment C' = 2 * C
  bad_c_2 = ec_point_add(cm_pt1, cm_pt1, p_field)
  bad_c_res2 = kzg_verify(bad_c_2, z1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_c_res2, 0, "Adversarial: Scaled commitment (2 * C) strictly REJECTED")

  @! Case C: Negated commitment C' = -C
  bad_c_3 = ec_point_neg(cm_pt1, p_field)
  bad_c_res3 = kzg_verify(bad_c_3, z1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_c_res3, 0, "Adversarial: Negated commitment (-C) strictly REJECTED")

  @! Case D: Point at infinity commitment C' = Infinity
  bad_c_4 = ec_point_infinity()
  bad_c_res4 = kzg_verify(bad_c_4, z1, v1, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_c_res4, 0, "Adversarial: Point at infinity commitment strictly REJECTED")

  @! 1.5 Adversarial Corrupted Quotient Proofs (W')
  @! Case A: Tampered proof W' = W + G1
  bad_w_1 = ec_point_add(w_pt1, srs.g1_gen, p_field)
  bad_w_res1 = kzg_verify(cm_pt1, z1, v1, bad_w_1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_w_res1, 0, "Adversarial: Tampered proof (W + G1) strictly REJECTED")

  @! Case B: Negated proof W' = -W
  bad_w_2 = ec_point_neg(w_pt1, p_field)
  bad_w_res2 = kzg_verify(cm_pt1, z1, v1, bad_w_2, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_w_res2, 0, "Adversarial: Negated proof (-W) strictly REJECTED")

  @! Case C: Point at infinity proof W' = Infinity
  bad_w_3 = ec_point_infinity()
  bad_w_res3 = kzg_verify(cm_pt1, z1, v1, bad_w_3, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_w_res3, 0, "Adversarial: Point at infinity proof strictly REJECTED")

  @! 1.6 High Degree Polynomials & Cross-Poly Rejection
  @! Poly 2: Degree 4: P(X) = 2X^4 + 5X^3 + 3X^2 + X + 9 at z = 4
  poly2 = [9, 1, 3, 5, 2]
  z2 = 4
  v2 = poly_eval(poly2, z2, p_field) @! 2(256) + 5(64) + 3(16) + 4 + 9 = 512 + 320 + 48 + 4 + 9 = 893
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(v2, 893, "Poly 2 (Degree 4): P(4) == 893")

  kzg2 = kzg_commit_polynomial(poly2, srs.g1_gen, p_field)
  cm_pt2 = ec_point_new(kzg2.cm_x, kzg2.cm_y)
  w_pt2 = kzg_create_opening_proof(poly2, z2, srs, p_field)

  valid_check2 = kzg_verify(cm_pt2, z2, v2, w_pt2, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_check2, 1, "High degree polynomial KZG opening strictly verified at z = 4")

  @! Cross-polynomial mismatch: proof from poly1 used for poly2
  bad_cross = kzg_verify(cm_pt2, z2, v2, w_pt1, srs, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_cross, 0, "Cross-polynomial proof substitution strictly REJECTED")

  @! ============================================================================
  @! SECTION 2: RSA EXT_GCD, MOD_INVERSE & EXTREME COPRIME STRESS MATRIX
  @! ============================================================================
  println("\n▶▶ [SUITE 2] RSA Extended GCD & Modular Inverse Stress Matrix...")

  @! 2.1 Bézout Identity Invariant Verification: a*x + b*y == gcd(a,b)
  test_pairs = [
    [17, 3120],
    [65537, 1000000007],
    [1, 1],
    [1, 999999],
    [999999, 1],
    [13, 233],          @! Consecutive Fibonacci numbers
    [144, 233],         @! Fibonacci numbers (worst case Euclidean iterations)
    [2584, 4181],       @! Fibonacci F_18, F_19
    [1000003, 1000033], @! 6-digit primes
    [104729, 1299709]   @! 10,000th and 100,000th primes
  ]

  i = 0
  num_pairs = test_pairs.len()
  @while i < num_pairs
    pair = test_pairs[i]
    a = pair[0]
    b = pair[1]
    res = ext_gcd(a, b)
    g = res[0]
    x = res[1]
    y = res[2]
    
    @! Verify Bézout Identity: a*x + b*y == g
    bezout = (a * x) + (b * y)
    total_tests = total_tests + 1
    passed_tests = passed_tests + assert_eq_int(bezout, g, "Bézout identity verified: " + a.to_str() + "*(" + x.to_str() + ") + " + b.to_str() + "*(" + y.to_str() + ") == " + g.to_str())
    
    @! If g == 1 and b > 1, verify modular inverse
    @if g == 1 && b > 1
      inv_a = rsa_mod_inverse(a, b)
      check_inv = (a * inv_a) % b
      total_tests = total_tests + 1
      passed_tests = passed_tests + assert_eq_int(check_inv, 1, "Modular inverse verified: (" + a.to_str() + " * " + inv_a.to_str() + ") mod " + b.to_str() + " == 1")
    @end
    i = i + 1
  @end

  @! 2.2 Non-coprime Failure Cases (Should return 0)
  non_coprime_pairs = [
    [6, 9],
    [14, 28],
    [100, 250],
    [1024, 2048],
    [1000000, 5000000],
    [35, 49]
  ]

  j = 0
  num_nc = non_coprime_pairs.len()
  @while j < num_nc
    pair_nc = non_coprime_pairs[j]
    a_nc = pair_nc[0]
    b_nc = pair_nc[1]
    inv_nc = rsa_mod_inverse(a_nc, b_nc)
    total_tests = total_tests + 1
    passed_tests = passed_tests + assert_eq_int(inv_nc, 0, "Non-coprime pair (" + a_nc.to_str() + ", " + b_nc.to_str() + ") modular inverse returns 0")
    j = j + 1
  @end

  @! 2.3 Boundary & Edge Case ext_gcd
  @! Case: b = 0
  res_zero = ext_gcd(42, 0)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(res_zero[0], 42, "ext_gcd(42, 0) gcd is 42")
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(res_zero[1], 1, "ext_gcd(42, 0) x is 1")

  @! ============================================================================
  @! SECTION 3: RSA ENCRYPTION / DECRYPTION & LARGE MODULUS SECURITY
  @! ============================================================================
  println("\n▶▶ [SUITE 3] RSA Keygen, Boundary Messages & Large Modulus Security...")

  @! 3.1 Keygen on large primes (Modulus > 10^12)
  large_p = 1000003
  large_q = 1000033
  large_key = rsa_key_from_primes(large_p, large_q)
  
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(large_key.n > 1000000000000, "Modulus is > 10^12 (" + large_key.n.to_str() + ")")
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(large_key.e, 65537, "Public exponent is standard 65537")

  @! Verify that (e * d) mod phi == 1 for large_key
  phi_val = (large_p - 1) * (large_q - 1)
  ed_mod = (large_key.e * large_key.d) % phi_val
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(ed_mod, 1, "(e * d) mod phi == 1 strictly holds for 10^12 modulus")

  @! 3.2 Moderate-size RSA prime key for full roundtrip encryption/decryption without i64 overflow (p=50021, q=50023, n=2.5*10^9)
  p_med = 50021
  q_med = 50023
  key_med = rsa_key_from_primes(p_med, q_med)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(key_med.e, 65537, "Medium RSA key selects e = 65537")
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_true(key_med.n > 2500000000, "Medium RSA modulus is > 2.5 billion")

  boundary_msgs = [0, 1, 2, 65535, 999999, 2500000000]
  k = 0
  b_len = boundary_msgs.len()
  @while k < b_len
    m = boundary_msgs[k]
    ct = rsa_encrypt(key_med, m)
    pt = rsa_decrypt(key_med, ct)
    total_tests = total_tests + 1
    passed_tests = passed_tests + assert_eq_int(pt, m, "RSA roundtrip decrypt(encrypt(" + m.to_str() + ")) == " + m.to_str())
    k = k + 1
  @end

  @! ============================================================================
  @! SECTION 4: PLONK CUSTOM GATE ARITHMETIZATION ADVERSARIAL STRESS
  @! ============================================================================
  println("\n▶▶ [SUITE 4] PLONK Custom Gate Arithmetization Adversarial Suite...")

  @! Gate 1: Pure multiplication gate: 0*a + 0*b - 1*c + 1*(a*b) + 0 = 0 -> a*b = c
  mul_gate = { ql: 0, qr: 0, qo: -1, qm: 1, qc: 0 }
  valid_mul = plonk_verify_gate(mul_gate, 7, 8, 56, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_mul, 1, "Plonk multiplication gate satisfied (7 * 8 = 56)")

  bad_mul = plonk_verify_gate(mul_gate, 7, 8, 57, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_mul, 0, "Plonk multiplication gate rejected invalid witness (7 * 8 != 57)")

  @! Gate 2: Pure addition gate: 1*a + 1*b - 1*c + 0*(a*b) + 0 = 0 -> a + b = c
  add_gate = { ql: 1, qr: 1, qo: -1, qm: 0, qc: 0 }
  valid_add = plonk_verify_gate(add_gate, 1234, 5678, 6912, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_add, 1, "Plonk addition gate satisfied (1234 + 5678 = 6912)")

  bad_add = plonk_verify_gate(add_gate, 1234, 5678, 6913, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_add, 0, "Plonk addition gate rejected invalid witness (1234 + 5678 != 6913)")

  @! Gate 3: Constant check gate: 1*a + 0*b + 0*c + 0*(a*b) - 42 = 0 -> a = 42
  const_gate = { ql: 1, qr: 0, qo: 0, qm: 0, qc: -42 }
  valid_const = plonk_verify_gate(const_gate, 42, 0, 0, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(valid_const, 1, "Plonk constant gate satisfied (a = 42)")

  bad_const = plonk_verify_gate(const_gate, 43, 0, 0, p_field)
  total_tests = total_tests + 1
  passed_tests = passed_tests + assert_eq_int(bad_const, 0, "Plonk constant gate rejected invalid witness (a = 43)")

  println("\n=================================================================")
  println("📊 ADVERSARIAL STRESS TEST SUMMARY: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🏆 ALL ADVERSARIAL CRYPTOGRAPHIC CHALLENGES PASSED! 🏆")
    return 0
  @else
    println("💥 SOME ADVERSARIAL CHALLENGES FAILED!")
    return 1
  @end
@end
