@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — SHA-512 FIPS 180-4 / RFC 6234 CONFORMANCE
@! ============================================================================

import "universe/crypto/sha512"

@fn assert_eq_str(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    println("    Expected: " + expected)
    println("    Actual:   " + actual)
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA SHA-512 NIST CONFORMANCE TEST SUITE       ")
  println("==================================================")

  passed = 0
  total = 0

  @! Vector 1: Empty string ""
  total = total + 1
  h1 = sha512_hex_string("")
  exp1 = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  passed = passed + assert_eq_str(h1, exp1, "SHA-512 empty string digest")

  @! Vector 2: "abc"
  total = total + 1
  h2 = sha512_hex_string("abc")
  exp2 = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  passed = passed + assert_eq_str(h2, exp2, "SHA-512 'abc' digest")

  @! Vector 3: 112-byte NIST vector
  total = total + 1
  msg3 = "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  h3 = sha512_hex_string(msg3)
  exp3 = "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"
  passed = passed + assert_eq_str(h3, exp3, "SHA-512 112-byte multi-block digest")

  @! Vector 4: Byte array API
  total = total + 1
  bytes_h = sha512_hex([97, 98, 99])
  passed = passed + assert_eq_str(bytes_h, exp2, "SHA-512 sha512_hex([97, 98, 99]) == 'abc' digest")

  println("==================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("🎉 ALL SHA-512 CONFORMANCE TESTS PASSED!")
    return 0
  @else
    return 1
  @end
@end
