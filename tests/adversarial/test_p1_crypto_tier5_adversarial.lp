@! ============================================================================
@! MAYA TIER 5 ADVERSARIAL STRESS HARNESS — PHASE 1 CRYPTOGRAPHY
@! Module: tests/adversarial/test_p1_crypto_tier5_adversarial.maya
@! Focus: BN254 KZG Pairing Non-Degeneracy, Forgery Rejection, RFC 8032 Ed25519
@!        Malleability / Non-Canonical Rejection, RSA ext_gcd Logarithmic Inverse
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/plonk"
import "universe/crypto/ed25519"
import "universe/crypto/rsa"

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
  println("🔱 TIER 5 ADVERSARIAL CHALLENGE: PHASE 1 CRYPTOGRAPHIC ENGINE 🔱")
  println("=================================================================")

  total = 0
  passed = 0

  p_field = 2147483647 @! 2^31 - 1 Prime Field

  @! ============================================================================
  @! 1. BN254 KZG PAIRINGS & MILLER LOOP NON-DEGENERACY
  @! ============================================================================
  println("\n--- [Suite 1.1] BN254 KZG Pairings, Non-Degeneracy & Forgery Defense ---")

  srs = kzg_srs_new(5, p_field)

  @! 1.1.1 Miller Loop Non-Degeneracy: e(G1, G2) != 1
  g1 = srs.g1_gen
  g2 = srs.g2_gen
  e_g1_g2 = ate_pairing(g1, g2, p_field)
  is_one = fp12_eq(e_g1_g2, fp12_one())
  total = total + 1
  passed = passed + assert_eq_int(is_one, 0, "Miller loop non-degeneracy: e(G1, G2) != 1 (identity)")

  @! 1.1.2 Pairing with Point at Infinity yields identity (1)
  inf_g1 = ec_point_infinity()
  e_inf_g2 = ate_pairing(inf_g1, g2, p_field)
  total = total + 1
  passed = passed + assert_eq_int(fp12_eq(e_inf_g2, fp12_one()), 1, "e(Inf, G2) == 1 (identity element in Fp12)")

  inf_g2 = g2_point_infinity()
  e_g1_inf = ate_pairing(g1, inf_g2, p_field)
  total = total + 1
  passed = passed + assert_eq_int(fp12_eq(e_g1_inf, fp12_one()), 1, "e(G1, Inf) == 1 (identity element in Fp12)")

  @! 1.1.3 KZG Opening & Verification: P(X) = 2X^3 + 5X^2 + 7X + 13 at z = 4 (tau - z = 1)
  poly_cubic = [13, 7, 5, 2]
  z_pt = 4
  v_val = poly_eval(poly_cubic, z_pt, p_field) @! 2(64) + 5(16) + 7(4) + 13 = 128 + 80 + 28 + 13 = 249
  total = total + 1
  passed = passed + assert_eq_int(v_val, 249, "Cubic polynomial P(4) == 249")

  kzg_cubic = kzg_commit_polynomial(poly_cubic, srs.g1_gen, p_field)
  cm_cubic = ec_point_new(kzg_cubic.cm_x, kzg_cubic.cm_y)
  w_cubic = kzg_create_opening_proof(poly_cubic, z_pt, srs, p_field)

  valid_kzg = kzg_verify(cm_cubic, z_pt, v_val, w_cubic, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(valid_kzg, 1, "Authentic KZG verification of cubic poly accepts")

  @! 1.1.4 Forgery Attack 1: Altered evaluation v' = v + 1
  bad_v = kzg_verify(cm_cubic, z_pt, v_val + 1, w_cubic, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(bad_v, 0, "KZG forgery v' = v + 1 strictly REJECTED")

  @! 1.1.5 Forgery Attack 2: Altered evaluation point z' = z + 1
  bad_z = kzg_verify(cm_cubic, z_pt + 1, v_val, w_cubic, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(bad_z, 0, "KZG forgery z' = z + 1 strictly REJECTED")

  @! 1.1.6 Forgery Attack 3: Altered quotient proof W' = 2*W
  bad_w = ec_point_add(w_cubic, w_cubic, p_field)
  bad_w_res = kzg_verify(cm_cubic, z_pt, v_val, bad_w, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(bad_w_res, 0, "KZG forgery W' = 2W strictly REJECTED")

  @! 1.1.7 Forgery Attack 4: Altered commitment C' = C + G1
  bad_cm = ec_point_add(cm_cubic, srs.g1_gen, p_field)
  bad_cm_res = kzg_verify(bad_cm, z_pt, v_val, w_cubic, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(bad_cm_res, 0, "KZG forgery C' = C + G1 strictly REJECTED")

  @! 1.1.8 PLONK Recursive Proof Verification
  proof = plonk_create_recursive_proof(101, 777, "0000000000000000000000000000000000000000000000000000000000000000", p_field)
  plonk_ok = plonk_verify_recursive_proof(proof, srs, p_field)
  total = total + 1
  passed = passed + assert_eq_int(plonk_ok, 1, "Plonk recursive proof authentic verification accepts")

  @! Plonk Forged Proof Size Limit
  forged_size_proof = proof
  forged_size_proof.proof_size_bytes = 25000 @! Exceeds 22528 limit
  total = total + 1
  passed = passed + assert_eq_int(plonk_verify_recursive_proof(forged_size_proof, srs, p_field), 0, "Plonk oversized proof (>22KB) strictly REJECTED")

  @! ============================================================================
  @! 2. RFC 8032 ED25519 SIGNATURE VERIFICATION & ADVERSARIAL FORGERY DEFENSE
  @! ============================================================================
  println("\n--- [Suite 1.2] RFC 8032 Ed25519 Malleability & Forgery Stress ---")

  seed = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
  keypair = ed25519_keygen(seed)

  msg = [77, 65, 89, 65, 95, 84, 69, 83, 84] @! "MAYA_TEST"
  sig = ed25519_sign(keypair.secret_key, msg)

  @! 2.1 Authentic Signature Verification
  v_auth = ed25519_verify(keypair.public_key, msg, sig)
  total = total + 1
  passed = passed + assert_eq_int(v_auth, 1, "Authentic RFC 8032 Ed25519 signature verified successfully")

  @! 2.2 Signature Malleability: S >= L rejection
  @! S component is in sig[32..63]. Set top bit or add L to trigger S >= L.
  malleable_sig = []
  i = 0
  @while i < 64
    malleable_sig = malleable_sig.push(sig[i])
    i = i + 1
  @end
  malleable_sig[63] = malleable_sig[63] | 128 @! Set MSB of S (forces S >= 2^255 > L)
  v_mal = ed25519_verify(keypair.public_key, msg, malleable_sig)
  total = total + 1
  passed = passed + assert_eq_int(v_mal, 0, "Ed25519 Malleability: S >= L strictly REJECTED")

  @! 2.3 Non-canonical Point Encoding: y >= p rejection in public key
  @! 2^255 - 19 in little-endian bytes: [237, 255, 255, ..., 127]
  non_canonical_pub = []
  i = 0
  @while i < 32
    non_canonical_pub = non_canonical_pub.push(255)
    i = i + 1
  @end
  non_canonical_pub[31] = 127 @! y = 2^255 - 1 > p = 2^255 - 19
  v_non_canon = ed25519_verify(non_canonical_pub, msg, sig)
  total = total + 1
  passed = passed + assert_eq_int(v_non_canon, 0, "Ed25519 Non-canonical public key (y >= p) strictly REJECTED")

  @! 2.4 Point Not On Curve Rejection
  @! Decompressing a point not satisfying -x^2 + y^2 = 1 + d x^2 y^2 must return zero point
  invalid_pt_bytes = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  dec_pt = ed25519_point_decompress(invalid_pt_bytes)
  total = total + 1
  passed = passed + assert_eq_int(fe_is_zero(dec_pt.z), 1, "Ed25519 decompress invalid curve point returns invalid (Z=0)")

  @! 2.5 Forgery Defense: Bit-flipped signature bytes
  forged_sig = []
  i = 0
  @while i < 64
    @if i == 5
      forged_sig = forged_sig.push(sig[i] ^ 1) @! Flip 1 bit in R
    @else
      forged_sig = forged_sig.push(sig[i])
    @end
    i = i + 1
  @end
  v_forged_sig = ed25519_verify(keypair.public_key, msg, forged_sig)
  total = total + 1
  passed = passed + assert_eq_int(v_forged_sig, 0, "Ed25519 bit-flipped signature strictly REJECTED")

  @! 2.6 Forgery Defense: Altered message payload
  tampered_msg = [77, 65, 89, 65, 95, 84, 69, 83, 85] @! "MAYA_TESU"
  v_tampered_msg = ed25519_verify(keypair.public_key, tampered_msg, sig)
  total = total + 1
  passed = passed + assert_eq_int(v_tampered_msg, 0, "Ed25519 tampered message payload strictly REJECTED")

  @! ============================================================================
  @! 3. RSA O(LOG PHI) EXT_GCD FAST MODULAR INVERSE
  @! ============================================================================
  println("\n--- [Suite 1.3] RSA O(log phi) ext_gcd Fast Modular Inverse ---")

  @! 3.1 Standard RSA Exponent: e = 65537, p = 61, q = 53 -> n = 3233, phi = 60 * 52 = 3120
  e1 = 17
  phi1 = 3120
  d1 = rsa_mod_inverse(e1, phi1)
  total = total + 1
  passed = passed + assert_true(d1 > 0, "ext_gcd computes positive modular inverse")
  total = total + 1
  passed = passed + assert_eq_int((d1 * e1) % phi1, 1, "Modular inverse identity: (d * e) % phi == 1")

  @! 3.2 Large Coprime Primes: p = 10007, q = 10009 -> phi = 10006 * 10008 = 100140048
  phi_large = 100140048
  e_std = 65537
  d_large = rsa_mod_inverse(e_std, phi_large)
  total = total + 1
  passed = passed + assert_eq_int((d_large * e_std) % phi_large, 1, "Large RSA 65537 inverse satisfies (d * 65537) % phi == 1")

  @! 3.3 Boundary: e = 1 -> d = 1
  d_one = rsa_mod_inverse(1, 999999)
  total = total + 1
  passed = passed + assert_eq_int(d_one, 1, "Boundary e = 1 yields d = 1")

  @! 3.4 Non-Coprime Inputs: gcd(e, phi) != 1 returns 0 (No inverse exists)
  d_non_coprime1 = rsa_mod_inverse(6, 9) @! gcd(6, 9) = 3 != 1
  total = total + 1
  passed = passed + assert_eq_int(d_non_coprime1, 0, "Non-coprime pair (6, 9) returns 0 (no inverse)")

  d_non_coprime2 = rsa_mod_inverse(100, 200) @! gcd(100, 200) = 100
  total = total + 1
  passed = passed + assert_eq_int(d_non_coprime2, 0, "Non-coprime pair (100, 200) returns 0 (no inverse)")

  @! 3.5 End-to-end RSA Encryption & Decryption Roundtrip
  key = rsa_keygen(61, 53)
  e_k = key[0]
  d_k = key[1]
  n_k = key[2]
  msg_val = 1234
  cipher = rsa_raw_encrypt(msg_val, e_k, n_k)
  plain = rsa_raw_decrypt(cipher, d_k, n_k)
  total = total + 1
  passed = passed + assert_eq_int(plain, msg_val, "RSA raw encrypt -> decrypt roundtrip recovers plaintext 1234")

  println("\n=================================================================")
  println("📊 PHASE 1 ADVERSARIAL SUITE SUMMARY: " + passed.to_str() + " / " + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL PHASE 1 ADVERSARIAL STRESS TESTS PASSED CLEANLY! 🎉")
    return 0
  @else
    println("❌ PHASE 1 ADVERSARIAL TESTS FAILED!")
    return 1
  @end
@end
