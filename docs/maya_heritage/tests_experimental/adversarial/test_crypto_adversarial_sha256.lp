import "universe/crypto/sha256"

@fn byte_to_hex(b)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  hi = (b >> 4) & 15
  lo = b & 15
  return hex_chars[hi] + hex_chars[lo]
@end

@fn digest_to_hex(d)
  res = ""
  i = 0
  len = d.len()
  @while i < len
    res = res + byte_to_hex(d[i] & 255)
    i = i + 1
  @end
  return res
@end

@fn count_set_bits(n)
  count = 0
  v = n & 255
  @while v > 0
    @if v & 1 != 0
      count = count + 1
    @end
    v = v >> 1
  @end
  return count
@end

@fn hamming_distance(d1, d2)
  dist = 0
  i = 0
  @while i < 32
    diff = (d1[i] ^ d2[i]) & 255
    dist = dist + count_set_bits(diff)
    i = i + 1
  @end
  return dist
@end

@fn make_pattern(length)
  arr = []
  i = 0
  @while i < length
    arr = arr.push(i % 256)
    i = i + 1
  @end
  return arr
@end

@fn test_sha256_boundaries()
  println("--- [TEST SUITE 1: SHA-256 Strict Boundary Testing] ---")
  tests_passed = 0
  tests_failed = 0

  @! 1. Empty string & array
  h_empty_str = sha256_hex("")
  h_empty_arr = sha256_hex([])
  exp_empty = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  @if h_empty_str == exp_empty && h_empty_arr == exp_empty
    tests_passed = tests_passed + 1
    println("  [PASS] Length 0 (Empty message): exact FIPS hash verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 0 empty message failed: " + h_empty_str)
  @end

  @! 2. Single Byte tests: 'a', 0x00, 0xFF
  h_a = sha256_hex("a")
  exp_a = "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb"
  @if h_a == exp_a
    tests_passed = tests_passed + 1
    println("  [PASS] Length 1 ('a'): exact FIPS hash verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 1 ('a') failed: " + h_a)
  @end

  h_00 = sha256_hex([0])
  exp_00 = "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"
  @if h_00 == exp_00
    tests_passed = tests_passed + 1
    println("  [PASS] Length 1 (0x00): exact FIPS hash verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 1 (0x00) failed: " + h_00)
  @end

  h_ff = sha256_hex([255])
  exp_ff = "a8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89"
  @if h_ff == exp_ff
    tests_passed = tests_passed + 1
    println("  [PASS] Length 1 (0xFF): exact FIPS hash verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 1 (0xFF) failed: " + h_ff)
  @end

  @! 3. Boundary Length 55 (Single block max capacity before 2nd block)
  p55 = make_pattern(55)
  h55 = sha256_hex(p55)
  exp55 = "463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59"
  @if h55 == exp55
    tests_passed = tests_passed + 1
    println("  [PASS] Length 55 (1-block max threshold): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 55 failed: " + h55)
  @end

  @! 4. Boundary Length 56 (First length requiring 2 blocks)
  p56 = make_pattern(56)
  h56 = sha256_hex(p56)
  exp56 = "da2ae4d6b36748f2a318f23e7ab1dfdf45acdc9d049bd80e59de82a60895f562"
  @if h56 == exp56
    tests_passed = tests_passed + 1
    println("  [PASS] Length 56 (2-block boundary transition): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 56 failed: " + h56)
  @end

  @! 5. Boundary Length 57
  p57 = make_pattern(57)
  h57 = sha256_hex(p57)
  exp57 = "2fe741af801cc238602ac0ec6a7b0c3a8a87c7fc7d7f02a3fe03d1c12eac4d8f"
  @if h57 == exp57
    tests_passed = tests_passed + 1
    println("  [PASS] Length 57: verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 57 failed: " + h57)
  @end

  @! 6. Boundary Length 63
  p63 = make_pattern(63)
  h63 = sha256_hex(p63)
  exp63 = "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488"
  @if h63 == exp63
    tests_passed = tests_passed + 1
    println("  [PASS] Length 63: verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 63 failed: " + h63)
  @end

  @! 7. Boundary Length 64 (Exact 1 full block of raw payload)
  p64 = make_pattern(64)
  h64 = sha256_hex(p64)
  exp64 = "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108"
  @if h64 == exp64
    tests_passed = tests_passed + 1
    println("  [PASS] Length 64 (Exact 1-block raw message): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 64 failed: " + h64)
  @end

  @! 8. Boundary Length 65
  p65 = make_pattern(65)
  h65 = sha256_hex(p65)
  exp65 = "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781"
  @if h65 == exp65
    tests_passed = tests_passed + 1
    println("  [PASS] Length 65: verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 65 failed: " + h65)
  @end

  @! 9. Boundary Length 119 (2-block max threshold)
  p119 = make_pattern(119)
  h119 = sha256_hex(p119)
  exp119 = "da18797ed7c3a777f0847f429724a2d8cd5138e6ed2895c3fa1a6d39d18f7ec6"
  @if h119 == exp119
    tests_passed = tests_passed + 1
    println("  [PASS] Length 119 (2-block max threshold): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 119 failed: " + h119)
  @end

  @! 10. Boundary Length 120 (3-block transition threshold)
  p120 = make_pattern(120)
  h120 = sha256_hex(p120)
  exp120 = "f52b23db1fbb6ded89ef42a23ce0c8922c45f25c50b568a93bf1c075420bbb7c"
  @if h120 == exp120
    tests_passed = tests_passed + 1
    println("  [PASS] Length 120 (3-block transition threshold): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 120 failed: " + h120)
  @end

  @! 11. Boundary Length 128 (Exact 2 full blocks of data)
  p128 = make_pattern(128)
  h128 = sha256_hex(p128)
  exp128 = "471fb943aa23c511f6f72f8d1652d9c880cfa392ad80503120547703e56a2be5"
  @if h128 == exp128
    tests_passed = tests_passed + 1
    println("  [PASS] Length 128 (Exact 2 full blocks): verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 128 failed: " + h128)
  @end

  @! 12. Boundary Length 129
  p129 = make_pattern(129)
  h129 = sha256_hex(p129)
  exp129 = "5099c6a56203f9687f7d33f4bfdf576d31dc91f6b695ecea38b2770c87631135"
  @if h129 == exp129
    tests_passed = tests_passed + 1
    println("  [PASS] Length 129: verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] Length 129 failed: " + h129)
  @end

  @if tests_failed == 0
    println("✓ All " + tests_passed.to_str() + " SHA-256 boundary tests PASSED!")
    return 0
  @else
    println("✗ SHA-256 boundary tests FAILED: " + tests_failed.to_str() + " errors")
    return 1
  @end
@end

@fn test_sha256_chunking()
  println("--- [TEST SUITE 2: SHA-256 Arbitrary Chunk Streaming Invariance] ---")
  tests_passed = 0
  tests_failed = 0

  @! We generate a 500-byte test vector
  test_len = 500
  data = make_pattern(test_len)
  expected_hex = sha256_hex(data)

  chunk_sizes = [1, 2, 3, 7, 13, 16, 31, 32, 55, 56, 63, 64, 65, 127, 128, 250]
  c_idx = 0
  @while c_idx < chunk_sizes.len()
    c_size = chunk_sizes[c_idx]
    ctx = sha256_init()
    offset = 0
    @while offset < test_len
      rem = test_len - offset
      cur_len = c_size
      @if cur_len > rem
        cur_len = rem
      @end
      chunk = []
      k = 0
      @while k < cur_len
        chunk = chunk.push(data[offset + k])
        k = k + 1
      @end
      ctx = sha256_update(ctx, chunk)
      offset = offset + cur_len
    @end
    digest = sha256_final(ctx)
    stream_hex = digest_to_hex(digest)

    @if stream_hex == expected_hex
      tests_passed = tests_passed + 1
    @else
      tests_failed = tests_failed + 1
      println("  [FAIL] Chunk size " + c_size.to_str() + " stream mismatch! Got " + stream_hex)
    @end
    c_idx = c_idx + 1
  @end

  @if tests_failed == 0
    println("  [PASS] Invariant verified across all " + tests_passed.to_str() + " arbitrary chunk sizes (1B..250B)!")
    return 0
  @else
    println("  [FAIL] Chunk streaming invariance failed: " + tests_failed.to_str() + " errors")
    return 1
  @end
@end

@fn test_sha256_large_data()
  println("--- [TEST SUITE 3: SHA-256 Multi-Kilobyte Stress & Throughput] ---")
  tests_passed = 0
  tests_failed = 0

  @! 1. 1000 'a's
  a1000 = ""
  i = 0
  @while i < 1000
    a1000 = a1000 + "a"
    i = i + 1
  @end
  h1000 = sha256_hex(a1000)
  exp1000 = "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3"
  @if h1000 == exp1000
    tests_passed = tests_passed + 1
    println("  [PASS] 1,000-byte repeated 'a' string verified")
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] 1,000-byte repeated 'a' failed: " + h1000)
  @end

  @! 2. 10,000 bytes (10KB) multi-block hashing via streaming
  ctx = sha256_init()
  block100 = make_pattern(100)
  i = 0
  @while i < 100
    ctx = sha256_update(ctx, block100)
    i = i + 1
  @end
  d10k = sha256_final(ctx)
  h10k = digest_to_hex(d10k)
  @if d10k.len() == 32
    tests_passed = tests_passed + 1
    println("  [PASS] 10,000-byte (10KB, 156+ blocks) stream completed: " + h10k)
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] 10KB stream failed")
  @end

  @! 3. 50,000 bytes (50KB) multi-block hashing
  ctx50 = sha256_init()
  block500 = make_pattern(500)
  i = 0
  @while i < 100
    ctx50 = sha256_update(ctx50, block500)
    i = i + 1
  @end
  d50k = sha256_final(ctx50)
  h50k = digest_to_hex(d50k)
  @if d50k.len() == 32
    tests_passed = tests_passed + 1
    println("  [PASS] 50,000-byte (50KB, 781+ blocks) stream completed: " + h50k)
  @else
    tests_failed = tests_failed + 1
    println("  [FAIL] 50KB stream failed")
  @end

  @if tests_failed == 0
    println("✓ SHA-256 large data stress PASSED!")
    return 0
  @else
    return 1
  @end
@end

@fn test_sha256_avalanche()
  println("--- [TEST SUITE 4: SHA-256 Strict Avalanche & Bit Diffusion] ---")
  tests_passed = 0
  tests_failed = 0

  @! Base message of 64 bytes
  base_msg = make_pattern(64)
  base_digest = sha256_hash_bytes(base_msg)

  total_flips = 0
  min_flip = 256
  max_flip = 0
  total_tests = 0

  @! Flip each bit of the first 8 bytes (64 individual 1-bit flip experiments)
  byte_idx = 0
  @while byte_idx < 8
    bit_idx = 0
    @while bit_idx < 8
      flipped_msg = []
      k = 0
      @while k < 64
        val = base_msg[k]
        @if k == byte_idx
          val = val ^ (pow2(bit_idx))
        @end
        flipped_msg = flipped_msg.push(val)
        k = k + 1
      @end

      flipped_digest = sha256_hash_bytes(flipped_msg)
      dist = hamming_distance(base_digest, flipped_digest)

      total_flips = total_flips + dist
      total_tests = total_tests + 1

      @if dist < min_flip
        min_flip = dist
      @end
      @if dist > max_flip
        max_flip = dist
      @end

      @! For a 256-bit hash, 1-bit flip must change roughly 128 bits (at least 90, at most 166)
      @if dist >= 90 && dist <= 166
        tests_passed = tests_passed + 1
      @else
        tests_failed = tests_failed + 1
        println("  [FAIL] Avalanche anomaly: byte " + byte_idx.to_str() + " bit " + bit_idx.to_str() + " had distance " + dist.to_str())
      @end

      bit_idx = bit_idx + 1
    @end
    byte_idx = byte_idx + 1
  @end

  avg_flip = total_flips / total_tests
  println("  - Avalanche statistics over " + total_tests.to_str() + " 1-bit flips:")
  println("    * Min bit flips: " + min_flip.to_str() + " / 256")
  println("    * Max bit flips: " + max_flip.to_str() + " / 256")
  println("    * Avg bit flips: " + avg_flip.to_str() + " / 256 (ideal: 128)")

  @if tests_failed == 0 && avg_flip >= 120 && avg_flip <= 136
    println("  [PASS] Strict Avalanche Criterion (SAC) verified: high entropy diffusion confirmed!")
    return 0
  @else
    println("  [FAIL] Avalanche test failed: " + tests_failed.to_str() + " anomalies")
    return 1
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [CHALLENGER 1] SHA-256 Empirical Stress & Adversarial Suite")
  println("=================================================================")

  r1 = test_sha256_boundaries()
  r2 = test_sha256_chunking()
  r3 = test_sha256_large_data()
  r4 = test_sha256_avalanche()

  total_res = r1 + r2 + r3 + r4
  println("=================================================================")
  @if total_res == 0
    println("🏆 ALL SHA-256 EMPIRICAL CHALLENGES PASSED WITH ZERO ERRORS!")
    return 0
  @else
    println("💥 SHA-256 CHALLENGES FAILED WITH " + total_res.to_str() + " SUITE FAILURES!")
    return 1
  @end
@end
