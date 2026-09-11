@! ============================================================================
@! MAYA RSA SECURITY & EXT_GCD UNIT TEST SUITE
@! ============================================================================

import "universe/security/rsa"
import "universe/crypto/rsa"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (actual=" + actual.to_str() + ", expected=" + expected.to_str() + ")")
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA RSA SECURITY & EXT_GCD UNIT TEST SUITE    ")
  println("==================================================")
  
  passed = 0
  total = 0

  @! Test 1: Standard small prime key
  total = total + 1
  key = rsa_key_new()
  msg = 65
  c = rsa_encrypt(key, msg)
  passed = passed + assert_eq(c, 2790, "RSA Encrypts 65 to 2790 with p=61, q=53")

  total = total + 1
  m2 = rsa_decrypt(key, c)
  passed = passed + assert_eq(m2, 65, "RSA Decrypts 2790 back to 65")

  @! Test 2: Extended Euclidean Algorithm
  total = total + 1
  gcd_res = ext_gcd(17, 3120)
  passed = passed + assert_eq(gcd_res[0], 1, "ext_gcd(17, 3120) gcd == 1")

  total = total + 1
  inv = rsa_mod_inverse(17, 3120)
  passed = passed + assert_eq(inv, 2753, "rsa_mod_inverse(17, 3120) == 2753")

  @! Test 3: Standard e = 65537 with larger primes
  total = total + 1
  key2 = rsa_key_from_primes(2753, 3203)
  passed = passed + assert_eq(key2.e, 65537, "RSA Keygen selects e = 65537")

  total = total + 1
  c2 = rsa_encrypt(key2, 123456)
  m2_dec = rsa_decrypt(key2, c2)
  passed = passed + assert_eq(m2_dec, 123456, "RSA encrypt/decrypt roundtrip with e=65537")

  @! Test 4: Fast keygen on large primes (no hang, O(log phi))
  total = total + 1
  key3 = rsa_key_from_primes(1000003, 1000033)
  passed = passed + assert_eq(key3.e, 65537, "Fast RSA keygen on 10^12 modulus completes instantly")

  @! Test 5: Negative / Non-coprime inverse failure
  total = total + 1
  inv_fail = rsa_mod_inverse(6, 9)
  passed = passed + assert_eq(inv_fail, 0, "rsa_mod_inverse returns 0 for non-coprime inputs gcd(6,9)=3")

  println("==================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("🎉 ALL RSA CRYPTO & EXT_GCD TESTS PASSED!")
    return 0
  @else
    return 1
  @end
@end
