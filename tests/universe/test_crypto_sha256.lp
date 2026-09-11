@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: FIPS 180-4 SHA-256 HASH VERIFICATION
@! File: tests/universe/test_crypto_sha256.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/crypto/crypto"
import "universe/core/crypto"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/crypto/sha256 (FIPS 180-4)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: NIST Official Vector 1 — Empty String ""
  @! Expected: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  @! --------------------------------------------------------------------------
  total = total + 1
  h1 = sha256_hex("")
  @if str_eq(h1, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == 1
    passed = passed + 1
    println("  [PASS] Test 1: NIST Vector 1 (Empty String \"\")")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 1: NIST Vector 1 (Empty String) -> Got: ", h1))
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: NIST Official Vector 2 — String "abc"
  @! Expected: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  @! --------------------------------------------------------------------------
  total = total + 1
  h2 = sha256_hex("abc")
  @if str_eq(h2, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") == 1
    passed = passed + 1
    println("  [PASS] Test 2: NIST Vector 2 (\"abc\")")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 2: NIST Vector 2 (\"abc\") -> Got: ", h2))
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: NIST Official Vector 3 — 56-Byte String
  @! "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
  @! Expected: 248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1
  @! --------------------------------------------------------------------------
  total = total + 1
  msg56 = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
  h3 = sha256_hex(msg56)
  @if str_eq(h3, "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1") == 1
    passed = passed + 1
    println("  [PASS] Test 3: NIST Vector 3 (56-byte message)")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 3: NIST Vector 3 (56-byte message) -> Got: ", h3))
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: NIST Vector 4 — 112-Byte Multi-Block String
  @! "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  @! Expected: cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1
  @! --------------------------------------------------------------------------
  total = total + 1
  msg112 = "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  h4 = sha256_hex(msg112)
  @if str_eq(h4, "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1") == 1
    passed = passed + 1
    println("  [PASS] Test 4: NIST Vector 4 (112-byte multi-block message)")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 4: NIST Vector 4 (112-byte message) -> Got: ", h4))
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: One-Shot String Hashing — sha256_hash_string("abc")
  @! Returns 32-byte array: first byte 0xba (186), last byte 0xad (173)
  @! --------------------------------------------------------------------------
  total = total + 1
  bytes_digest = sha256_hash_string("abc")
  @if bytes_digest.len() == 32 && bytes_digest[0] == 186 && bytes_digest[31] == 173
    passed = passed + 1
    println("  [PASS] Test 5: One-shot string hash returns valid 32-byte digest")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: One-shot string hash returned invalid byte array")
  @end

  @! --------------------------------------------------------------------------
  @! Test 6: One-Shot Byte Array Hashing — sha256_hash_bytes([97, 98, 99])
  @! --------------------------------------------------------------------------
  total = total + 1
  bytes_input = [97, 98, 99]
  h_from_bytes = sha256_hash_bytes(bytes_input)
  @if h_from_bytes.len() == 32 && h_from_bytes[0] == 186 && h_from_bytes[1] == 120 && h_from_bytes[31] == 173
    passed = passed + 1
    println("  [PASS] Test 6: One-shot byte array hash sha256_hash_bytes([97, 98, 99])")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: One-shot byte array hash failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 7: Streaming API (Full Message Update)
  @! sha256_init() -> sha256_update(ctx, "abc") -> sha256_final(ctx)
  @! --------------------------------------------------------------------------
  total = total + 1
  ctx1 = sha256_init()
  ctx1 = sha256_update(ctx1, "abc")
  stream_digest1 = sha256_final(ctx1)
  @if stream_digest1.len() == 32 && stream_digest1[0] == 186 && stream_digest1[31] == 173
    passed = passed + 1
    println("  [PASS] Test 7: Streaming API sha256_init/update/final with string")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: Streaming API with string failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 8: Streaming API with Incremental Chunks
  @! sha256_init() -> update("a") -> update("b") -> update("c") -> sha256_final()
  @! --------------------------------------------------------------------------
  total = total + 1
  ctx2 = sha256_init()
  ctx2 = sha256_update(ctx2, "a")
  ctx2 = sha256_update(ctx2, "b")
  ctx2 = sha256_update(ctx2, "c")
  stream_digest2 = sha256_final(ctx2)
  @if stream_digest2.len() == 32 && stream_digest2[0] == 186 && stream_digest2[31] == 173
    passed = passed + 1
    println("  [PASS] Test 8: Incremental streaming update(\"a\"), update(\"b\"), update(\"c\")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: Incremental streaming failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 9: Streaming API with Byte Array Chunks
  @! sha256_init() -> update([97]) -> update([98, 99]) -> sha256_final()
  @! --------------------------------------------------------------------------
  total = total + 1
  ctx3 = sha256_init()
  ctx3 = sha256_update(ctx3, [97])
  ctx3 = sha256_update(ctx3, [98, 99])
  stream_digest3 = sha256_final(ctx3)
  @if stream_digest3.len() == 32 && stream_digest3[0] == 186 && stream_digest3[31] == 173
    passed = passed + 1
    println("  [PASS] Test 9: Streaming byte array chunk updates")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: Streaming byte array chunk updates failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 10: Padding Boundary — 55-Byte Message (Single block boundary)
  @! "0123456789012345678901234567890123456789012345678901234"
  @! Expected: f34d5a0f80c0cbf84c8c0b90218c22637abd199965249da736a20143c8c9c9d9
  @! --------------------------------------------------------------------------
  total = total + 1
  msg55 = "0123456789012345678901234567890123456789012345678901234"
  h55 = sha256_hex(msg55)
  @if str_eq(h55, "f34d5a0f80c0cbf84c8c0b90218c22637abd199965249da736a20143c8c9c9d9") == 1
    passed = passed + 1
    println("  [PASS] Test 10: 55-byte single-block padding boundary")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 10: 55-byte boundary failed -> Got: ", h55))
  @end

  @! --------------------------------------------------------------------------
  @! Test 11: Exact Block Size Boundary — 64-Byte Message
  @! "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  @! Expected: a8ae6e6ee929abea3afcfc5258c8ccd6f85273e0d4626d26c7279f3250f77c8e
  @! --------------------------------------------------------------------------
  total = total + 1
  msg64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  h64 = sha256_hex(msg64)
  @if str_eq(h64, "a8ae6e6ee929abea3afcfc5258c8ccd6f85273e0d4626d26c7279f3250f77c8e") == 1
    passed = passed + 1
    println("  [PASS] Test 11: 64-byte block size boundary (forces 2nd block)")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 11: 64-byte boundary failed -> Got: ", h64))
  @end

  @! --------------------------------------------------------------------------
  @! Test 12: Avalanche Effect Verification (1-bit input change -> large hash diff)
  @! "abc" vs "abd"
  @! "abd" hash: a52d159f262b2c6ddb724a61840befc36eb30c88877a4030b65cbe86298449c9
  @! --------------------------------------------------------------------------
  total = total + 1
  h_abd = sha256_hex("abd")
  @if str_eq(h_abd, "a52d159f262b2c6ddb724a61840befc36eb30c88877a4030b65cbe86298449c9") == 1 && str_eq(h_abd, h2) == 0
    passed = passed + 1
    println("  [PASS] Test 12: Avalanche effect / 1-bit input flip sensitivity verified")
  @else
    failed = failed + 1
    println(str_concat("  [FAIL] Test 12: Avalanche effect check failed -> Got: ", h_abd))
  @end

  println("-----------------------------------------------------------------")
  println(str_concat("SHA-256 Test Summary: ", str_concat(to_str(passed), str_concat("/", str_concat(to_str(total), " passed")))))
  @if failed == 0
    println("✓ universe/crypto/sha256 E2E Test Suite PASSED")
    return 0
  @else
    println(str_concat("✗ universe/crypto/sha256 E2E Test Suite FAILED (", str_concat(to_str(failed), " errors)")))
    return 1
  @end
@end
