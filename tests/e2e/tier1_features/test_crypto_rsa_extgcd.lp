// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Fast RSA ext_gcd Modular Inverse PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: crypto, rsa, ext_gcd, modular_inverse, keygen

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: FAST RSA EXT_GCD MODULAR INVERSE
@! File: tests/e2e/tier1_features/test_crypto_rsa_extgcd.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/rsa"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 3: Fast RSA Modular Inverse (ext_gcd) & Keygen")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.1: Extended Euclidean Algorithm (ext_gcd)
  total = total + 1
  eg_res = ext_gcd(30, 20) @! gcd = 10, 30*(1) + 20*(-1) = 10
  g = eg_res[0]
  x = eg_res[1]
  y = eg_res[2]
  identity_check = (30 * x) + (20 * y)
  @if g == 10 && identity_check == 10
    passed = passed + 1
    println("  [PASS] T1.1: Extended Euclidean Algorithm (ext_gcd(30, 20) -> gcd=10, a*x + b*y = gcd)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.1: Extended Euclidean Algorithm")
  @end

  @! T1.2: Fast O(log phi) Modular Inverse
  total = total + 1
  d1 = rsa_mod_inverse(17, 3120) @! 17 * 2753 = 46801 = 15 * 3120 + 1 => d = 2753
  d2 = rsa_mod_inverse(65537, 1021180) @! Large modulus modular inverse
  check1 = (17 * d1) % 3120
  check2 = (65537 * d2) % 1021180
  @if d1 == 2753 && check1 == 1 && check2 == 1
    passed = passed + 1
    println("  [PASS] T1.2: Fast O(log phi) modular inverse (rsa_mod_inverse(17, 3120) = 2753)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.2: Fast modular inverse")
  @end

  @! T1.3: Modular Exponentiation (rsa_mod_pow)
  total = total + 1
  pow_res1 = rsa_mod_pow(7, 4, 100) @! 7^4 = 2401 % 100 = 1
  pow_res2 = rsa_mod_pow(65, 17, 3233) @! 65^17 mod 3233 = 2790
  pow_dec = rsa_mod_pow(pow_res2, 2753, 3233) @! 2790^2753 mod 3233 = 65
  @if pow_res1 == 1 && pow_res2 == 2790 && pow_dec == 65
    passed = passed + 1
    println("  [PASS] T1.3: Modular exponentiation (b^e mod n)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.3: Modular exponentiation")
  @end

  @! T1.4: Primality Testing
  total = total + 1
  p_prime1 = rsa_is_prime(61)
  p_prime2 = rsa_is_prime(53)
  p_prime3 = rsa_is_prime(1009)
  p_prime4 = rsa_is_prime(1013)
  p_comp1 = rsa_is_prime(100)
  p_comp2 = rsa_is_prime(3233) @! 61 * 53
  @if p_prime1 == 1 && p_prime2 == 1 && p_prime3 == 1 && p_prime4 == 1 && p_comp1 == 0 && p_comp2 == 0
    passed = passed + 1
    println("  [PASS] T1.4: Primality test (rsa_is_prime for primes and composites)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.4: Primality test")
  @end

  @! T1.5: Fast RSA Key Generation
  total = total + 1
  key1 = rsa_keygen(61, 53)
  e1 = key1[0]
  d_priv1 = key1[1]
  n_mod1 = key1[2]
  @if n_mod1 == 3233 && ((e1 * d_priv1) % 3120) == 1
    passed = passed + 1
    println("  [PASS] T1.5: Fast RSA keypair generation (p=61, q=53 -> n=3233, e=" + e1.to_str() + ", d=" + d_priv1.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.5: Fast RSA keypair generation")
  @end

  @! T1.6: RSA Encryption & Decryption Roundtrip
  total = total + 1
  msg = 1234
  cipher = rsa_raw_encrypt(msg, e1, n_mod1)
  decrypted = rsa_raw_decrypt(cipher, d_priv1, n_mod1)
  @if cipher != msg && decrypted == msg
    passed = passed + 1
    println("  [PASS] T1.6: RSA encryption and decryption roundtrip (msg=" + msg.to_str() + " -> cipher=" + cipher.to_str() + " -> dec=" + decrypted.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.6: RSA encryption and decryption roundtrip")
  @end

  @! T1.7: Larger Prime Keypair & Multi-Message Roundtrip
  total = total + 1
  key2 = rsa_keygen(1009, 1013)
  e2 = key2[0]
  d2_priv = key2[1]
  n2_mod = key2[2]
  c1 = rsa_raw_encrypt(42, e2, n2_mod)
  c2 = rsa_raw_encrypt(500, e2, n2_mod)
  c3 = rsa_raw_encrypt(9999, e2, n2_mod)
  d_m1 = rsa_raw_decrypt(c1, d2_priv, n2_mod)
  d_m2 = rsa_raw_decrypt(c2, d2_priv, n2_mod)
  d_m3 = rsa_raw_decrypt(c3, d2_priv, n2_mod)
  @if d_m1 == 42 && d_m2 == 500 && d_m3 == 9999
    passed = passed + 1
    println("  [PASS] T1.7: Large prime RSA keypair (p=1009, q=1013) multi-message encryption roundtrip")
  @else
    failed = failed + 1
    println("  [FAIL] T1.7: Large prime RSA keypair roundtrip")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Fast RSA ext_gcd Modular Inverse PASSED")
    return 0
  @else
    println("✗ Feature: Fast RSA ext_gcd Modular Inverse FAILED")
    return 1
  @end
@end
