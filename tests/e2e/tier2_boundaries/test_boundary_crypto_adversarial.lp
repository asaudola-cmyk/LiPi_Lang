// @! RUN: %maya %file
// @! EXPECT: ✓ Tier 2: Boundary & Adversarial Cryptography PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: crypto, boundary, adversarial, ed25519, forgery, rsa, plonk

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & ADVERSARIAL CRYPTOGRAPHIC INTEGRITY
@! File: tests/e2e/tier2_boundaries/test_boundary_crypto_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/ed25519"
import "universe/crypto/rsa"
import "universe/crypto/plonk"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary & Adversarial Cryptography Suite")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  p_mod = 2147483647 @! 2^31 - 1 Prime Field

  seed = [
    9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8, 7, 6, 5, 4,
    3, 2, 1, 0, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8
  ]
  kp = ed25519_keygen(seed)
  orig_msg = [83, 111, 118, 101, 114, 101, 105, 103, 110] @! "Sovereign"
  sig = ed25519_sign(seed, orig_msg)

  @! T2.1: Ed25519 Tampered Message Rejection (Single-byte modification)
  total = total + 1
  tampered_msg = [83, 111, 118, 101, 114, 101, 105, 103, 111] @! Modified last byte
  valid_tampered = ed25519_verify(kp.public_key, tampered_msg, sig)
  @if valid_tampered == 0
    passed = passed + 1
    println("  [PASS] T2.1: Adversarial message forgery rejection (tampered payload fails)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.1: Adversarial message forgery rejection")
  @end

  @! T2.2: Ed25519 Mutated Signature R-Component Rejection
  total = total + 1
  mutated_sig_r = []
  i = 0
  @while i < 64
    b = sig[i]
    @if i == 0
      b = b ^ 1 @! Bit flip in R component
    @end
    mutated_sig_r = mutated_sig_r.push(b)
    i = i + 1
  @end
  valid_mutated_r = ed25519_verify(kp.public_key, orig_msg, mutated_sig_r)
  @if valid_mutated_r == 0
    passed = passed + 1
    println("  [PASS] T2.2: Adversarial signature mutation rejection (1-bit flip in R component)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.2: Adversarial signature mutation rejection (R)")
  @end

  @! T2.3: Ed25519 Mutated Signature S-Component Rejection
  total = total + 1
  mutated_sig_s = []
  i = 0
  @while i < 64
    b = sig[i]
    @if i == 33
      b = b ^ 1 @! Bit flip in S component
    @end
    mutated_sig_s = mutated_sig_s.push(b)
    i = i + 1
  @end
  valid_mutated_s = ed25519_verify(kp.public_key, orig_msg, mutated_sig_s)
  @if valid_mutated_s == 0
    passed = passed + 1
    println("  [PASS] T2.3: Adversarial signature mutation rejection (1-bit flip in S component)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.3: Adversarial signature mutation rejection (S)")
  @end

  @! T2.4: Ed25519 Wrong Public Key Rejection
  total = total + 1
  diff_seed = [
    55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55,
    55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55, 55
  ]
  diff_kp = ed25519_keygen(diff_seed)
  valid_wrong_pk = ed25519_verify(diff_kp.public_key, orig_msg, sig)
  @if valid_wrong_pk == 0
    passed = passed + 1
    println("  [PASS] T2.4: Adversarial mismatched public key rejection")
  @else
    failed = failed + 1
    println("  [FAIL] T2.4: Adversarial mismatched public key rejection")
  @end

  @! T2.5: Ed25519 Non-Canonical S >= L Rejection
  total = total + 1
  s_ge_l_sig = []
  i = 0
  @while i < 32
    s_ge_l_sig = s_ge_l_sig.push(sig[i])
    i = i + 1
  @end
  @! Append non-canonical S = 2^256 - 1 (all 0xFF)
  i = 0
  @while i < 32
    s_ge_l_sig = s_ge_l_sig.push(255)
    i = i + 1
  @end
  valid_s_ge_l = ed25519_verify(kp.public_key, orig_msg, s_ge_l_sig)
  @if valid_s_ge_l == 0
    passed = passed + 1
    println("  [PASS] T2.5: Non-canonical scalar S >= L signature rejection")
  @else
    failed = failed + 1
    println("  [FAIL] T2.5: Non-canonical scalar S >= L rejection")
  @end

  @! T2.6: RSA Non-Coprime (gcd(e, phi) != 1) Inverse Failure
  total = total + 1
  @! e = 6, phi = 12 -> gcd(6, 12) = 6 != 1 => Inverse does not exist, must return 0
  non_coprime_inv = rsa_mod_inverse(6, 12)
  non_coprime_inv2 = rsa_mod_inverse(14, 21) @! gcd(14, 21) = 7 != 1 => 0
  @if non_coprime_inv == 0 && non_coprime_inv2 == 0
    passed = passed + 1
    println("  [PASS] T2.6: RSA non-coprime modulus boundary rejection (returns 0 when gcd(e, phi) != 1)")
  @else
    failed = failed + 1
    println("  [FAIL] T2.6: RSA non-coprime modular inverse failure")
  @end

  @! T2.7: PLONK Custom Gate Constraint Violation & Invalid Witness Rejection
  total = total + 1
  bad_gate = { ql: 2, qr: 3, qo: -1, qm: 1, qc: -17 }
  gate_rej1 = plonk_verify_gate(bad_gate, 2, 3, 999, p_mod) @! Invalid witness c=999
  gate_rej2 = plonk_verify_gate(bad_gate, 5, 5, 24, p_mod)  @! Invalid witness 2(5)+3(5)+25-17 = 33 != 24
  @if gate_rej1 == 0 && gate_rej2 == 0
    passed = passed + 1
    println("  [PASS] T2.7: PLONK custom gate invalid witness rejection")
  @else
    failed = failed + 1
    println("  [FAIL] T2.7: PLONK invalid witness rejection")
  @end

  println("-----------------------------------------------------------------")
  println("Tier 2 Crypto Boundary Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Tier 2: Boundary & Adversarial Cryptography PASSED")
    return 0
  @else
    println("✗ Tier 2: Boundary & Adversarial Cryptography FAILED")
    return 1
  @end
@end
