import "universe/crypto/sha256"
import "universe/crypto/aes"
import "universe/crypto/crypto"

@fn arrays_equal(a, b)
  @if a.len() != b.len()
    return 0
  @end
  i = 0
  len = a.len()
  @while i < len
    @if a[i] != b[i]
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn lcg_next(state)
  return ((state * 1103515245) + 12345) & 2147483647
@end

@fn gen_random_bytes(count, initial_seed)
  res = []
  s = initial_seed
  i = 0
  @while i < count
    s = lcg_next(s)
    res = res.push((s / 65536) & 255)
    i = i + 1
  @end
  return res
@end

@fn gen_random_string(count, initial_seed)
  res = ""
  s = initial_seed
  i = 0
  @while i < count
    s = lcg_next(s)
    char_code = 32 + ((s / 65536) % 95)
    res = res + str_from_char_code(char_code)
    i = i + 1
  @end
  return res
@end

@fn test_randomized_fuzzing_suite()
  println("--- [TEST 1: 50-Iteration Randomized Key/IV/Payload Fuzzing Matrix] ---")
  tests_passed = 0
  tests_failed = 0

  test_lengths = [0, 1, 7, 15, 16, 17, 31, 32, 33, 47, 48, 49, 63, 64, 65, 127, 128, 129, 255, 256, 500]
  
  idx = 0
  @while idx < test_lengths.len()
    cur_len = test_lengths[idx]
    seed_base = 50000 + (idx * 137)

    k128 = gen_random_bytes(16, seed_base + 1)
    k256 = gen_random_bytes(32, seed_base + 2)
    iv = gen_random_bytes(16, seed_base + 3)
    nonce = gen_random_bytes(16, seed_base + 4)

    @! 1. Binary payload for CTR
    raw_payload = gen_random_bytes(cur_len, seed_base + 5)
    
    @! CTR-128
    c_ctr128 = aes128_ctr_encrypt(k128, nonce, raw_payload)
    d_ctr128 = aes128_ctr_decrypt(k128, nonce, c_ctr128)
    @if arrays_equal(d_ctr128, raw_payload) == 1
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] CTR-128 failed on length " + cur_len.to_str())
    @end

    @! CTR-256
    c_ctr256 = aes256_ctr_encrypt(k256, nonce, raw_payload)
    d_ctr256 = aes256_ctr_decrypt(k256, nonce, c_ctr256)
    @if arrays_equal(d_ctr256, raw_payload) == 1
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] CTR-256 failed on length " + cur_len.to_str())
    @end

    @! 2. String payload for CBC / ECB
    str_payload = gen_random_string(cur_len, seed_base + 6)

    @! CBC-128
    c_cbc128 = aes128_cbc_encrypt(k128, iv, str_payload)
    d_cbc128 = aes128_cbc_decrypt(k128, iv, c_cbc128)
    @if d_cbc128 == str_payload
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] CBC-128 failed on length " + cur_len.to_str())
    @end

    @! CBC-256
    c_cbc256 = aes256_cbc_encrypt(k256, iv, str_payload)
    d_cbc256 = aes256_cbc_decrypt(k256, iv, c_cbc256)
    @if d_cbc256 == str_payload
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] CBC-256 failed on length " + cur_len.to_str())
    @end

    @! ECB-128
    c_ecb128 = aes128_ecb_encrypt(k128, str_payload)
    d_ecb128 = aes128_ecb_decrypt(k128, c_ecb128)
    @if d_ecb128 == str_payload
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] ECB-128 failed on length " + cur_len.to_str())
    @end

    @! ECB-256
    c_ecb256 = aes256_ecb_encrypt(k256, str_payload)
    d_ecb256 = aes256_ecb_decrypt(k256, c_ecb256)
    @if d_ecb256 == str_payload
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] ECB-256 failed on length " + cur_len.to_str())
    @end

    idx = idx + 1
  @end

  println("  - Executed " + (test_lengths.len() * 6).to_str() + " randomized roundtrip cipher tests across 21 distinct payload lengths")
  @if tests_failed == 0
    println("  [PASS] 100% roundtrip accuracy verified across all modes & lengths!")
    return 0
  @else
    println("  [FAIL] Randomized fuzzing encountered " + tests_failed.to_str() + " failures")
    return 1
  @end
@end

@fn test_massive_payload_suite()
  println("--- [TEST 2: 200-Block (3,200 Bytes) AES Multi-Block Stress] ---")
  tests_passed = 0
  tests_failed = 0

  k256 = gen_random_bytes(32, 98765)
  iv = gen_random_bytes(16, 54321)
  nonce = gen_random_bytes(16, 12345)

  @! 3,200 bytes string payload
  big_str = gen_random_string(3200, 112233)

  @! 1. 200-block AES-256 CBC
  ct_cbc = aes256_cbc_encrypt(k256, iv, big_str)
  dec_cbc = aes256_cbc_decrypt(k256, iv, ct_cbc)
  @if dec_cbc == big_str && ct_cbc.len() == 3216
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CBC 200-block (3,200 bytes) roundtrip verified (CT: 3216 bytes)")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CBC 200-block failed")
  @end

  @! 2. 200-block AES-256 CTR
  big_bin = gen_random_bytes(3200, 445566)
  ct_ctr = aes256_ctr_encrypt(k256, nonce, big_bin)
  dec_ctr = aes256_ctr_decrypt(k256, nonce, ct_ctr)
  @if arrays_equal(dec_ctr, big_bin) == 1 && ct_ctr.len() == 3200
    tests_passed = tests_passed + 1
    println("  [PASS] AES-256 CTR 200-block (3,200 bytes binary) roundtrip verified (CT: 3200 bytes)")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] AES-256 CTR 200-block failed")
  @end

  @if tests_failed == 0
    return 0
  @else
    return 1
  @end
@end

@fn test_crypto_facade()
  println("--- [TEST 3: universe/crypto/crypto Unified Facade Verification] ---")
  tests_passed = 0
  tests_failed = 0

  msg = "Maya Unified Cryptography Facade Verification String"
  h = crypto_sha256_hex(msg)
  b = crypto_sha256_bytes(msg)
  @if h.len() == 64 && b.len() == 32
    tests_passed = tests_passed + 1
    println("  [PASS] crypto_sha256_hex & crypto_sha256_bytes verified")
  @else
    tests_failed = tests_failed + 1
  @end

  k128 = gen_random_bytes(16, 1111)
  iv = gen_random_bytes(16, 2222)
  k256 = gen_random_bytes(32, 3333)

  c128 = crypto_aes128_encrypt(k128, iv, msg)
  d128 = crypto_aes128_decrypt(k128, iv, c128)
  @if d128 == msg
    tests_passed = tests_passed + 1
    println("  [PASS] crypto_aes128_encrypt / decrypt verified")
  @else
    tests_failed = tests_failed + 1
  @end

  c256 = crypto_aes256_encrypt(k256, iv, msg)
  d256 = crypto_aes256_decrypt(k256, iv, c256)
  @if d256 == msg
    tests_passed = tests_passed + 1
    println("  [PASS] crypto_aes256_encrypt / decrypt verified")
  @else
    tests_failed = tests_failed + 1
  @end

  @if tests_failed == 0
    println("✓ Unified crypto facade PASSED!")
    return 0
  @else
    return 1
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [CHALLENGER 1] Extreme Fuzzing & Stress Matrix")
  println("=================================================================")

  r1 = test_randomized_fuzzing_suite()
  r2 = test_massive_payload_suite()
  r3 = test_crypto_facade()

  total = r1 + r2 + r3
  println("=================================================================")
  @if total == 0
    println("🏆 ALL EXTREME ADVERSARIAL CRYPTO TESTS PASSED WITH 0 FAILURES!")
    return 0
  @else
    println("💥 EXTREME ADVERSARIAL CRYPTO TESTS FAILED: " + total.to_str())
    return 1
  @end
@end
