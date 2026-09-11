@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ZERO-KNOWLEDGE PROOFS (ZK-SNARKS) TEST SUITE
@! File: tests/crypto/test_zkp_snark.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/zkp"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔐 MAYA ZERO-KNOWLEDGE PROOFS (ZK-SNARKS / R1CS) TEST SUITE 🔐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  p = 2147483647 @! 2^31 - 1 Mersenne Prime Modulus

  @! SECTION 1: R1CS System Setup & Constraint Assembly
  @! Equation to prove in zero-knowledge: x^3 + x + 5 = 35 (Solution: x = 3)
  @! Variables: [1, x, sym1=x*x, y=sym1*x, sym2=y+x, out=sym2+5]
  @! Witness:   [1, 3, 9,        27,       30,         35]
  println("▶ Section 1: R1CS Constraint Matrices Construction (x^3 + x + 5 = 35)...")
  total_tests = total_tests + 1
  sys = r1cs_system_new(6, p)

  @! Constraint 1: x * x = sym1 -> [0, 1, 0, 0, 0, 0] . [0, 1, 0, 0, 0, 0] = [0, 0, 1, 0, 0, 0]
  sys = r1cs_add_constraint(sys, [0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0], [0, 0, 1, 0, 0, 0])

  @! Constraint 2: sym1 * x = y -> [0, 0, 1, 0, 0, 0] . [0, 1, 0, 0, 0, 0] = [0, 0, 0, 1, 0, 0]
  sys = r1cs_add_constraint(sys, [0, 0, 1, 0, 0, 0], [0, 1, 0, 0, 0, 0], [0, 0, 0, 1, 0, 0])

  @! Constraint 3: (y + x) * 1 = sym2 -> [0, 1, 0, 1, 0, 0] . [1, 0, 0, 0, 0, 0] = [0, 0, 0, 0, 1, 0]
  sys = r1cs_add_constraint(sys, [0, 1, 0, 1, 0, 0], [1, 0, 0, 0, 0, 0], [0, 0, 0, 0, 1, 0])

  @! Constraint 4: (sym2 + 5) * 1 = out -> [5, 0, 0, 0, 1, 0] . [1, 0, 0, 0, 0, 0] = [0, 0, 0, 0, 0, 1]
  sys = r1cs_add_constraint(sys, [5, 0, 0, 0, 1, 0], [1, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 1])

  ok1 = assert_eq_int(sys.constraints.len(), 4, "R1CS assembled 4 arithmetic constraints")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] R1CS constraint matrix compilation verified")
  @end

  @! SECTION 2: Valid & Invalid Witness Verification
  println("▶ Section 2: Witness Verification over Finite Field F_p...")
  total_tests = total_tests + 1
  valid_witness = [1, 3, 9, 27, 30, 35]
  valid_res = r1cs_verify_witness_direct(sys, valid_witness)
  ok1 = assert_eq_int(valid_res, 1, "Valid witness (x=3 -> 35) satisfies all R1CS constraints")

  invalid_witness = [1, 4, 16, 64, 68, 35] @! Fake witness
  invalid_res = r1cs_verify_witness_direct(sys, invalid_witness)
  ok2 = assert_eq_int(invalid_res, 0, "Invalid witness correctly rejected by constraint verifier")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Valid & invalid witness evaluations verified")
  @end

  @! SECTION 3: Non-Interactive Zero-Knowledge Proof Generation & Verification
  println("▶ Section 3: Non-Interactive ZK Proof Generation & Verification...")
  total_tests = total_tests + 1
  proof = zkp_generate_proof(sys, valid_witness, 12345)
  ok1 = assert_true(str_len(proof.public_commitment) == 64, "Generated 64-char SHA-256 cryptographic commitment")
  
  verified = zkp_verify_proof(proof, p)
  ok2 = assert_eq_int(verified, 1, "Zero-Knowledge proof verified without revealing witness x=3")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Non-interactive zk-SNARK proof generation & verification verified")
  @end

  println("=================================================================")
  println("📊 ZK-SNARKS TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 ZERO-KNOWLEDGE PROOF TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ZK-SNARKS TESTS FAILED")
    return 1
  @end
@end
