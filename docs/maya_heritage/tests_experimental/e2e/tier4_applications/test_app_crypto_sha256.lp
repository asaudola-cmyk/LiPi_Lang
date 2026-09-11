@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: CRYPTOGRAPHIC SHA-256 PIPELINE (NIST KAT)
@! File: tests/e2e/tier4_applications/test_app_crypto_sha256.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/crypto/sha256"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 10: Cryptographic SHA-256 Pipeline & NIST KAT")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.10.1: NIST KAT Test Vector 1 — Empty String ""
  total = total + 1
  h1 = sha256_hex("")
  expected_h1 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  @if h1 == expected_h1
    passed = passed + 1
    println("  [PASS] T4.10.1: NIST Empty String KAT verified: " + h1)
  @else
    failed = failed + 1
    println("  [FAIL] T4.10.1: Empty hash mismatch: " + h1)
  @end

  @! T4.10.2: NIST KAT Test Vector 2 — Standard 3-character string "abc"
  total = total + 1
  h2 = sha256_hex("abc")
  expected_h2 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

  @if h2 == expected_h2
    passed = passed + 1
    println("  [PASS] T4.10.2: NIST 'abc' KAT verified: " + h2)
  @else
    failed = failed + 1
    println("  [FAIL] T4.10.2: 'abc' hash mismatch: " + h2)
  @end

  @! T4.10.3: NIST KAT Test Vector 3 — Multi-word string "The quick brown fox jumps over the lazy dog"
  total = total + 1
  fox_str = "The quick brown fox jumps over the lazy dog"
  h3 = sha256_hex(fox_str)
  expected_h3 = "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"

  @if h3 == expected_h3
    passed = passed + 1
    println("  [PASS] T4.10.3: NIST Fox KAT verified: " + h3)
  @else
    failed = failed + 1
    println("  [FAIL] T4.10.3: Fox hash mismatch: " + h3)
  @end

  @! T4.10.4: Sovereign Verification — "Maya Sovereign Compiler"
  total = total + 1
  h4 = sha256_hex("Maya Sovereign Compiler")
  expected_h4 = "b00700d723ffdde3fefdaf89102b81d2b427e39339cb84ce5a8cd8d245c7fee7"

  @if h4 == expected_h4
    passed = passed + 1
    println("  [PASS] T4.10.4: 'Maya Sovereign Compiler' SHA-256 hash verified: " + h4)
  @else
    failed = failed + 1
    println("  [FAIL] T4.10.4: 'Maya Sovereign Compiler' hash mismatch: " + h4)
  @end

  @! T4.10.5: Streaming Context Incremental Digest Equivalence
  total = total + 1
  @! Compute hash incrementally in 3 chunks: "Maya ", "Sovereign ", "Compiler"
  ctx = sha256_init()
  ctx = sha256_update(ctx, "Maya ")
  ctx = sha256_update(ctx, "Sovereign ")
  ctx = sha256_update(ctx, "Compiler")
  digest_stream = sha256_final(ctx)

  stream_hex = ""
  i = 0
  while i < digest_stream.len()
    stream_hex = stream_hex + sha256_byte_to_hex(digest_stream[i] & 255)
    i = i + 1
  @end

  @if stream_hex == expected_h4
    passed = passed + 1
    println("  [PASS] T4.10.5: Streaming chunked SHA-256 digest identical to one-shot digest")
  @else
    failed = failed + 1
    println("  [FAIL] T4.10.5: Streaming chunked hash mismatch: " + stream_hex)
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 10 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 10 (Cryptographic SHA-256 Pipeline) PASSED")
    return 0
  @else
    println("✗ Scenario 10 (Cryptographic SHA-256 Pipeline) FAILED")
    return 1
  @end
@end
