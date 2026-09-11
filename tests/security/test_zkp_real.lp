@! ============================================================================
@! TEST: tests/security/test_zkp_real.maya
@! Phase 6 — Real ZKP Schnorr verification tests
@! Proves that zkp_verify is NOT "return 1" by testing BOTH valid and invalid
@! proofs and asserting they return different results.
@! ============================================================================

import "universe/security/zkp"

g_passed = 0
g_failed = 0

@fn check(label, got, expected)
  @if got == expected
    g_passed = g_passed + 1
    println("  PASS: " + label + " (got=" + got.to_str() + ")")
  @else
    g_failed = g_failed + 1
    println("  FAIL: " + label + " got=" + got.to_str() + " expected=" + expected.to_str())
  @end
@end

@fn main()
  println("=== ZKP Schnorr Real Verification Tests ===")

  @! ---- Test 1: Valid proof must pass ----
  @! Private key x=42, nonce k=1337, challenge c=7
  @! Verifier uses public key y = g^x mod p
  x = 42
  k = 1337
  c = 7
  keypair = zkp_keygen(x)
  proof = zkp_prove(x, k, c)
  result_valid = zkp_verify(proof, keypair.y, c)
  check("valid Schnorr proof accepted (result==1)", result_valid, 1)

  @! ---- Test 2: Different valid parameters still verify ----
  x2 = 101
  k2 = 999
  c2 = 13
  keypair2 = zkp_keygen(x2)
  proof2 = zkp_prove(x2, k2, c2)
  result_valid2 = zkp_verify(proof2, keypair2.y, c2)
  check("second valid Schnorr proof accepted (result==1)", result_valid2, 1)

  @! ---- Test 3: INVALID proof — tampered commitment must FAIL ----
  @! Same challenge, same public key, but commitment is wrong (set to 999999)
  bad_proof_commitment = { commitment: 999999, response: proof.response, challenge: c }
  result_bad_commit = zkp_verify(bad_proof_commitment, keypair.y, c)
  check("tampered commitment rejected (result==0)", result_bad_commit, 0)

  @! ---- Test 4: INVALID proof — wrong response must FAIL ----
  bad_proof_response = { commitment: proof.commitment, response: 1, challenge: c }
  result_bad_resp = zkp_verify(bad_proof_response, keypair.y, c)
  check("wrong response rejected (result==0)", result_bad_resp, 0)

  @! ---- Test 5: INVALID proof — wrong public key must FAIL ----
  @! Use a public key from a different private key
  wrong_keypair = zkp_keygen(7)   @! x=7, not x=42
  result_wrong_pk = zkp_verify(proof, wrong_keypair.y, c)
  check("wrong public key rejected (result==0)", result_wrong_pk, 0)

  @! ---- Test 6: Intentional-break guard ----
  @! If zkp_verify were "return 1", the bad-proof tests above would return 1,
  @! making check() fail.  If they all returned 1, total_valid would be wrong.
  @! We explicitly assert valid != invalid
  @if result_valid == 1 && result_bad_commit == 0 && result_bad_resp == 0
    g_passed = g_passed + 1
    println("  PASS: zkp_verify distinguishes valid from invalid proofs")
  @else
    g_failed = g_failed + 1
    println("  FAIL: zkp_verify does NOT distinguish valid from invalid proofs!")
  @end

  println("=== RESULTS: " + g_passed.to_str() + " passed, " + g_failed.to_str() + " failed ===")
  @if g_failed == 0
    println("ALL ZKP REAL TESTS PASSED")
  @else
    println("SOME ZKP REAL TESTS FAILED")
  @end
@end
