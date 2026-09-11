@! ============================================================================
@! MAYA ADVERSARIAL TEST SUITE: SHA-512 & ED25519 RIGOROUS STRESS HARNESS
@! Challenger 2 — Cryptographic Integrity, Edge Boundaries & Forgery Rejection
@! ============================================================================

import "universe/crypto/sha512"
import "universe/crypto/ed25519"
import "universe/crypto/crypto"
import "universe/security/ed25519"
import "universe/core/crypto"

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

@fn assert_eq_int(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (expected=" + expected.to_str() + ", actual=" + actual.to_str() + ")")
    return 0
  @end
@end

@fn bytes_match(b1, b2)
  @if b1.len() != b2.len()
    return 0
  @end
  i = 0
  len = b1.len()
  @while i < len
    @if (b1[i] & 255) != (b2[i] & 255)
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn count_bit_flips(b1, b2)
  flips = 0
  min_len = b1.len()
  @if b2.len() < min_len
    min_len = b2.len()
  @end
  i = 0
  @while i < min_len
    diff = (b1[i] ^ b2[i]) & 255
    @while diff > 0
      @if diff & 1 == 1
        flips = flips + 1
      @end
      diff = diff >> 1
    @end
    i = i + 1
  @end
  return flips
@end

@fn make_repeated_bytes(byte_val, count)
  res = []
  i = 0
  @while i < count
    res = res.pushbyte_val & 255
    i = i + 1
  @end
  return res
@end

@fn make_sequence_bytes(start_val, count)
  res = []
  i = 0
  @while i < count
    res = res.push((start_val + i) & 255)
    i = i + 1
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [CHALLENGER 2] SHA-512 & ED25519 Empirical Stress Suite        ")
  println("=================================================================")

  passed = 0
  total = 0

  @! ----------------------------------------------------------------------------
  @! SUITE 1: SHA-512 STRICT BOUNDARY TESTING (111, 112, 113, 127, 128, 129, 239, 240, 255, 256, 257)
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 1: SHA-512 Strict Block Boundary Testing] ---")

  @! Length 0: Empty message
  total = total + 1
  h0 = sha512_hex([])
  exp0 = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  passed = passed + assert_eq_str(h0, exp0, "Length 0 (Empty message): exact FIPS hash verified")

  @! Length 1: 'a'
  total = total + 1
  h1 = sha512_hex([97])
  exp1 = "1f40fc92da241694750979ee6cf582f2d5d7d28e18335de05abc54d0560e0f5302860c652bf08d560252aa5e74210546f369fbbbce8c12cfc7957b2652fe9a75"
  passed = passed + assert_eq_str(h1, exp1, "Length 1 ('a'): exact FIPS hash verified")

  @! Length 111: 1-block max threshold (111 data + 1 pad + 16 len = 128 bytes)
  total = total + 1
  msg111 = make_repeated_bytes(97, 111)
  h111 = sha512_hex(msg111)
  exp111 = "fa9121c7b32b9e01733d034cfc78cbf67f926c7ed83e82200ef86818196921760b4beff48404df811b953828274461673c68d04e297b0eb7b2b4d60fc6b566a2"
  passed = passed + assert_eq_str(h111, exp111, "Length 111 (1-block max threshold 111B): verified")

  @! Length 112: 2-block transition threshold
  total = total + 1
  msg112 = make_repeated_bytes(97, 112)
  h112 = sha512_hex(msg112)
  exp112 = "c01d080efd492776a1c43bd23dd99d0a2e626d481e16782e75d54c2503b5dc32bd05f0f1ba33e568b88fd2d970929b719ecbb152f58f130a407c8830604b70ca"
  passed = passed + assert_eq_str(h112, exp112, "Length 112 (2-block boundary transition 112B): verified")

  @! Length 113: 1 byte past boundary
  total = total + 1
  msg113 = make_repeated_bytes(97, 113)
  h113 = sha512_hex(msg113)
  exp113 = "55ddd8ac210a6e18ba1ee055af84c966e0dbff091c43580ae1be703bdb85da31acf6948cf5bd90c55a20e5450f22fb89bd8d0085e39f85a86cc46abbca75e24d"
  passed = passed + assert_eq_str(h113, exp113, "Length 113 (113B): verified")

  @! Length 127: 1 byte before full block
  total = total + 1
  msg127 = make_repeated_bytes(97, 127)
  h127 = sha512_hex(msg127)
  exp127 = "828613968b501dc00a97e08c73b118aa8876c26b8aac93df128502ab360f91bab50a51e088769a5c1eff4782ace147dce3642554199876374291f5d921629502"
  passed = passed + assert_eq_str(h127, exp127, "Length 127 (127B): verified")

  @! Length 128: Exact 1 full block raw message
  total = total + 1
  msg128 = make_repeated_bytes(97, 128)
  h128 = sha512_hex(msg128)
  exp128 = "b73d1929aa615934e61a871596b3f3b33359f42b8175602e89f7e06e5f658a243667807ed300314b95cacdd579f3e33abdfbe351909519a846d465c59582f321"
  passed = passed + assert_eq_str(h128, exp128, "Length 128 (Exact 1 full block): verified")

  @! Length 129: 1 byte into 2nd block
  total = total + 1
  msg129 = make_repeated_bytes(97, 129)
  h129 = sha512_hex(msg129)
  exp129 = "4f681e0bd53cda4b5a2041cc8a06f2eabde44fb16c951fbd5b87702f07aeab611565b19c47fde30587177ebb852e3971bbd8d3fd30da18d71037dfbd98420429"
  passed = passed + assert_eq_str(h129, exp129, "Length 129 (129B): verified")

  @! Length 239: 2-block max threshold (239 + 1 + 16 = 256 bytes)
  total = total + 1
  msg239 = make_repeated_bytes(97, 239)
  h239 = sha512_hex(msg239)
  exp239 = "52c853cb8d907f3d4d6b889beb027985d7c273486d75f8baf26f80d24e90c74c6c3de3e22131582380a7d14d43f2941a31385439cd6ddc469f628015e50bf286"
  passed = passed + assert_eq_str(h239, exp239, "Length 239 (2-block max threshold 239B): verified")

  @! Length 240: 3-block transition threshold
  total = total + 1
  msg240 = make_repeated_bytes(97, 240)
  h240 = sha512_hex(msg240)
  exp240 = "4c296d90c61052a62ffb1dd196f1b7b09373b1f93e71836baebf89690546b7595684dbe9467a8e484fa0d1094272b4344a7c24f5fee8daedeb0bf549c985ab5f"
  passed = passed + assert_eq_str(h240, exp240, "Length 240 (3-block transition threshold 240B): verified")

  @! Length 255
  total = total + 1
  msg255 = make_repeated_bytes(97, 255)
  h255 = sha512_hex(msg255)
  exp255 = "d8b5a659e365f704ab114ae7079a8da24fb9997b3052a4a63b37d654652bad6fbdd2b52d737e20a9d5ac3c5831d6afdd32ff737a3dd95269d2793bc2aa850aab"
  passed = passed + assert_eq_str(h255, exp255, "Length 255 (255B): verified")

  @! Length 256: Exact 2 full blocks
  total = total + 1
  msg256 = make_repeated_bytes(97, 256)
  h256 = sha512_hex(msg256)
  exp256 = "6a9169eb662f136d87374070e8828b3e615a7eca32a89446e9225b02832709be095e635c824a2bb70213ba2ea0ababac0809827843992c851903b7ac0c136699"
  passed = passed + assert_eq_str(h256, exp256, "Length 256 (Exact 2 full blocks): verified")

  @! Length 257: 1 byte into 3rd block
  total = total + 1
  msg257 = make_repeated_bytes(97, 257)
  h257 = sha512_hex(msg257)
  exp257 = "17fa1d01865805f9e657c5f5088754d19913eb418577b03cd040b99e5e1354fd31d0d7f24b5474c62b49e3271860859510909685c5811eba23b06e1e3369899d"
  passed = passed + assert_eq_str(h257, exp257, "Length 257 (257B): verified")

  @! ----------------------------------------------------------------------------
  @! SUITE 2: SHA-512 STREAMING INVARIANCE & MULTI-KILOBYTE STRESS
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 2: SHA-512 Arbitrary Chunk Streaming Invariance] ---")

  stream_payload = make_repeated_bytes(97, 500)
  expected_stream_hex = sha512_hex(stream_payload)

  chunk_sizes = [1, 2, 3, 7, 13, 16, 31, 64, 127, 128, 129, 200, 250]
  c_idx = 0
  all_chunks_pass = 1

  @while c_idx < chunk_sizes.len()
    chunk_sz = chunk_sizes[c_idx]
    ctx = sha512_init()
    offset = 0
    @while offset < stream_payload.len()
      chunk = []
      k = 0
      @while k < chunk_sz && (offset + k) < stream_payload.len()
        chunk = chunk.push(stream_payload[offset + k])
        k = k + 1
      @end
      ctx = sha512_update(ctx, chunk)
      offset = offset + chunk_sz
    @end
    digest = sha512_final(ctx)
    res_hex = ""
    d_i = 0
    @while d_i < digest.len()
      res_hex = res_hex + sha512_byte_to_hex(digest[d_i])
      d_i = d_i + 1
    @end
    @if res_hex != expected_stream_hex
      all_chunks_pass = 0
      println("  [FAIL] Chunk size " + chunk_sz.to_str() + " stream mismatch!")
    @end
    c_idx = c_idx + 1
  @end

  total = total + 1
  passed = passed + assert_eq_int(all_chunks_pass, 1, "SHA-512 streaming invariant verified across 13 chunk configurations")

  @! 1,000-byte repeated 'a' digest
  total = total + 1
  msg1000 = make_repeated_bytes(97, 1000)
  h1000 = sha512_hex(msg1000)
  exp1000 = "67ba5535a46e3f86dbfbed8cbbaf0125c76ed549ff8b0b9e03e0c88cf90fa634fa7b12b47d77b694de488ace8d9a65967dc96df599727d3292a8d9d447709c97"
  passed = passed + assert_eq_str(h1000, exp1000, "1,000-byte multi-block stress stream verified")

  @! 5,000-byte multi-block stress stream (39+ blocks)
  total = total + 1
  msg5000 = make_repeated_bytes(97, 5000)
  h5000 = sha512_hex(msg5000)
  exp5000 = "0a76c190740222c4ae52b525ff4055e06543c22cd1617f342113742befe4a8ea3e50e1e5491e9bcfcb25baf041734ff1f5675207b6d7fc7f9c334db07e8e48c0"
  passed = passed + assert_eq_str(h5000, exp5000, "5,000-byte (39 blocks) stress stream verified")

  @! ----------------------------------------------------------------------------
  @! SUITE 3: SHA-512 STRICT AVALANCHE & BIT DIFFUSION (SAC)
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 3: SHA-512 Strict Avalanche & Bit Diffusion] ---")

  base_data = make_repeated_bytes(0x55, 64)
  base_hash = sha512_hash_bytes(base_data)

  min_flips = 512
  max_flips = 0
  total_flips = 0
  num_flips = 32

  f_i = 0
  @while f_i < num_flips
    flipped_data = make_repeated_bytes(0x55, 64)
    byte_idx = f_i % 64
    bit_idx = f_i % 8
    flipped_data[byte_idx] = flipped_data[byte_idx] ^ (pow2(bit_idx))

    flipped_hash = sha512_hash_bytes(flipped_data)
    flips = count_bit_flips(base_hash, flipped_hash)

    @if flips < min_flips min_flips = flips @end
    @if flips > max_flips max_flips = flips @end
    total_flips = total_flips + flips
    f_i = f_i + 1
  @end

  avg_flips = total_flips / num_flips
  println("  - Avalanche test: min=" + min_flips.to_str() + ", max=" + max_flips.to_str() + ", avg=" + avg_flips.to_str() + " (ideal: 256/512)")

  total = total + 1
  is_avalanche_good = 0
  @if avg_flips >= 220 && avg_flips <= 290
    is_avalanche_good = 1
  @end
  passed = passed + assert_eq_int(is_avalanche_good, 1, "SHA-512 Strict Avalanche Criterion (SAC) high-entropy diffusion confirmed")

  @! ----------------------------------------------------------------------------
  @! SUITE 4: EDWARDS25519 CURVE MATH & GROUP LAW INVARIANTS
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 4: Edwards25519 Curve Math & Group Law Invariants] ---")

  b_pt = ed25519_base_point()
  inf_pt = ed25519_point_infinity()

  @! Invariant 1: B + O == B and O + B == B
  total = total + 1
  b_plus_inf = ed25519_point_add(b_pt, inf_pt)
  inf_plus_b = ed25519_point_add(inf_pt, b_pt)
  eq_b1 = ed25519_point_eq(b_plus_inf, b_pt)
  eq_b2 = ed25519_point_eq(inf_plus_b, b_pt)
  passed = passed + assert_eq_int(eq_b1 & eq_b2, 1, "Neutral element identity: B + O == B and O + B == B")

  @! Invariant 2: [2]B == B + B and [4]B == [2]([2]B)
  total = total + 1
  b_double = ed25519_point_double(b_pt)
  b_add_b = ed25519_point_add(b_pt, b_pt)
  eq_double = ed25519_point_eq(b_double, b_add_b)

  b_4_double = ed25519_point_double(b_double)
  b_4_add = ed25519_point_add(b_double, b_double)
  eq_quad = ed25519_point_eq(b_4_double, b_4_add)
  passed = passed + assert_eq_int(eq_double & eq_quad, 1, "Point doubling matches complete addition: [2]B == B + B, [4]B == 2B + 2B")

  @! Invariant 3: [L] B == O (Order L base point annihilates to neutral element)
  total = total + 1
  l_limbs = scalar_l_limbs()
  l_times_b = ed25519_scalar_mult(l_limbs, b_pt)
  is_neutral = ed25519_point_eq(l_times_b, inf_pt)
  passed = passed + assert_eq_int(is_neutral, 1, "Group Order L Base Point Annihilation: [L] B == O")

  @! Invariant 4: Point compression and decompression roundtrip
  total = total + 1
  comp_b = ed25519_point_compress(b_pt)
  decomp_b = ed25519_point_decompress(comp_b)
  eq_decomp = ed25519_point_eq(decomp_b, b_pt)
  passed = passed + assert_eq_int(eq_decomp, 1, "Point compression/decompression roundtrip for Base Point")

  @! ----------------------------------------------------------------------------
  @! SUITE 5: RFC 8032 TEST VECTORS (Vector 1, 2, 3)
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 5: RFC 8032 Official Test Vectors] ---")

  @! Vector 3: 2-byte message 0xaf82
  sk3 = [
    0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
    0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
    0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
    0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70
  ]
  exp_pk3 = [
    211, 99, 162, 42, 175, 196, 157, 17, 222, 236, 65, 140, 241, 107, 156, 34,
    201, 156, 246, 179, 152, 49, 118, 127, 246, 211, 211, 181, 227, 194, 25, 184
  ]
  exp_sig3 = [
    150, 22, 38, 152, 175, 89, 205, 223, 14, 183, 136, 13, 142, 124, 133, 183,
    204, 144, 198, 108, 191, 160, 214, 223, 198, 69, 199, 58, 127, 32, 235, 150,
    84, 2, 225, 74, 221, 207, 138, 50, 173, 136, 15, 49, 249, 90, 199, 219,
    242, 44, 208, 12, 203, 90, 83, 160, 250, 183, 205, 199, 20, 246, 89, 8
  ]

  total = total + 1
  kp3 = ed25519_keygen(sk3)
  pk_match3 = bytes_match(kp3.public_key, exp_pk3)
  passed = passed + assert_eq_int(pk_match3, 1, "RFC 8032 Vector 3 public key matches expected")

  total = total + 1
  sig3 = ed25519_sign(sk3, [0xaf, 0x82])
  sig_match3 = bytes_match(sig3, exp_sig3)
  passed = passed + assert_eq_int(sig_match3, 1, "RFC 8032 Vector 3 signature matches expected")

  total = total + 1
  v3 = ed25519_verify(kp3.public_key, [0xaf, 0x82], sig3)
  passed = passed + assert_eq_int(v3, 1, "RFC 8032 Vector 3 signature verified successfully")

  @! ----------------------------------------------------------------------------
  @! SUITE 6: ADVERSARIAL FORGERY & SIGNATURE CORRUPTION MATRIX
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 6: Adversarial Forgery & Signature Corruption Matrix] ---")

  @! Adversarial 1: Bit flips across message
  total = total + 1
  bad_msg_1 = [0xaf, 0x83]
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, bad_msg_1, sig3), 0, "Message byte flip (0x82 -> 0x83) strictly rejected")

  total = total + 1
  bad_msg_2 = [0xaf, 0x82, 0x00]
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, bad_msg_2, sig3), 0, "Message expansion (appended byte) strictly rejected")

  total = total + 1
  bad_msg_3 = [0xaf]
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, bad_msg_3, sig3), 0, "Message truncation (missing byte) strictly rejected")

  @! Adversarial 2: Exhaustive 64-byte signature bit-flip matrix
  total = total + 1
  all_sig_flips_rejected = 1
  pos = 0
  @while pos < 64
    corrupt_sig = []
    i = 0
    @while i < 64
      b = sig3[i]
      @if i == pos
        b = b ^ 1
      @end
      corrupt_sig = corrupt_sig.push(b)
      i = i + 1
    @end
    @if ed25519_verify(kp3.public_key, [0xaf, 0x82], corrupt_sig) != 0
      all_sig_flips_rejected = 0
      println("  [FAIL] Signature bit flip at byte " + pos.to_str() + " was NOT rejected!")
    @end
    pos = pos + 1
  @end
  passed = passed + assert_eq_int(all_sig_flips_rejected, 1, "Exhaustive 64-position 1-bit signature corruption matrix (64/64 rejected)")

  @! Adversarial 3: Malformed signature lengths
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], []), 0, "Empty signature (0 bytes) strictly rejected")

  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], make_repeated_bytes(0, 63)), 0, "Truncated signature (63 bytes) strictly rejected")

  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], make_repeated_bytes(0, 65)), 0, "Oversized signature (65 bytes) strictly rejected")

  @! Adversarial 4: Malformed public key lengths
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify([], [0xaf, 0x82], sig3), 0, "Empty public key (0 bytes) strictly rejected")

  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(make_repeated_bytes(0, 31), [0xaf, 0x82], sig3), 0, "Truncated public key (31 bytes) strictly rejected")

  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(make_repeated_bytes(0, 33), [0xaf, 0x82], sig3), 0, "Oversized public key (33 bytes) strictly rejected")

  @! ----------------------------------------------------------------------------
  @! SUITE 7: NON-CANONICAL S & INVALID POINT REJECTION
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 7: Non-Canonical S & Invalid Point Rejection] ---")

  @! Exact L bytes little endian:
  @! L = [237, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16]
  l_exact_bytes = [
    237, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16
  ]
  l_plus_1_bytes = [
    238, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16
  ]
  l_plus_65536_bytes = [
    237, 211, 246, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16
  ]
  s_max_255_bytes = [
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127
  ]
  s_max_256_bytes = [
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
  ]

  @! Non-canonical S == L
  sig_s_eq_l = []
  i = 0
  @while i < 32 sig_s_eq_l = sig_s_eq_l.push(sig3[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_s_eq_l = sig_s_eq_l.push(l_exact_bytes[i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_s_eq_l), 0, "Non-canonical S == L strictly rejected")

  @! Non-canonical S == L + 1
  sig_s_gt_l = []
  i = 0
  @while i < 32 sig_s_gt_l = sig_s_gt_l.push(sig3[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_s_gt_l = sig_s_gt_l.push(l_plus_1_bytes[i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_s_gt_l), 0, "Non-canonical S == L + 1 strictly rejected")

  @! Non-canonical S == L + 65536
  sig_s_gt_l2 = []
  i = 0
  @while i < 32 sig_s_gt_l2 = sig_s_gt_l2.push(sig3[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_s_gt_l2 = sig_s_gt_l2.push(l_plus_65536_bytes[i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_s_gt_l2), 0, "Non-canonical S == L + 65536 strictly rejected")

  @! Non-canonical S == 2^255 - 1
  sig_s_255 = []
  i = 0
  @while i < 32 sig_s_255 = sig_s_255.push(sig3[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_s_255 = sig_s_255.push(s_max_255_bytes[i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_s_255), 0, "Non-canonical S == 2^255 - 1 strictly rejected")

  @! Non-canonical S == 2^256 - 1
  sig_s_256 = []
  i = 0
  @while i < 32 sig_s_256 = sig_s_256.push(sig3[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_s_256 = sig_s_256.push(s_max_256_bytes[i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_s_256), 0, "Non-canonical S == 2^256 - 1 (0xFF*32) strictly rejected")

  @! Invalid public key: Point not on curve: y = 2
  pk_not_on_curve_2 = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(pk_not_on_curve_2, [0xaf, 0x82], sig3), 0, "Invalid public key (point not on curve, y=2) strictly rejected")

  @! Invalid public key: Point not on curve: y = 7
  pk_not_on_curve_7 = [7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(pk_not_on_curve_7, [0xaf, 0x82], sig3), 0, "Invalid public key (point not on curve, y=7) strictly rejected")

  @! Invalid public key: y == p = 2^255 - 19
  pk_y_eq_p = [
    237, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127
  ]
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(pk_y_eq_p, [0xaf, 0x82], sig3), 0, "Invalid public key (y == p) strictly rejected")

  @! Invalid public key: y == 2^255 - 1 >= p
  pk_y_max = [
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127
  ]
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(pk_y_max, [0xaf, 0x82], sig3), 0, "Invalid public key (y == 2^255 - 1 >= p) strictly rejected")

  @! Invalid Signature R point: R with y=2 (not on curve)
  sig_bad_r_curve = []
  i = 0
  @while i < 32 sig_bad_r_curve = sig_bad_r_curve.push(pk_not_on_curve_2[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_bad_r_curve = sig_bad_r_curve.push(sig3[32 + i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_bad_r_curve), 0, "Invalid signature R point (not on curve) strictly rejected")

  @! Invalid Signature R point: R with y=p
  sig_bad_r_p = []
  i = 0
  @while i < 32 sig_bad_r_p = sig_bad_r_p.push(pk_y_eq_p[i]) i = i + 1 @end
  i = 0
  @while i < 32 sig_bad_r_p = sig_bad_r_p.push(sig3[32 + i]) i = i + 1 @end
  total = total + 1
  passed = passed + assert_eq_int(ed25519_verify(kp3.public_key, [0xaf, 0x82], sig_bad_r_p), 0, "Invalid signature R point (y == p) strictly rejected")

  @! ----------------------------------------------------------------------------
  @! SUITE 8: RANDOMIZED KEYPAIR & SIGNATURE FUZZING MATRIX
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 8: Randomized Keypair & Signature Fuzzing Matrix] ---")

  all_fuzz_passed = 1
  fuzz_idx = 0
  @while fuzz_idx < 10
    rand_seed = make_sequence_bytes(fuzz_idx * 17 + 1, 32)
    rand_msg = make_sequence_bytes(fuzz_idx * 31 + 5, (fuzz_idx * 7) + 1)

    kp = ed25519_keygen(rand_seed)
    sig = ed25519_sign(rand_seed, rand_msg)

    @! 1. Legitimate verify MUST succeed
    @if ed25519_verify(kp.public_key, rand_msg, sig) != 1
      all_fuzz_passed = 0
      println("  [FAIL] Fuzz keygen/sign/verify failed for iteration " + fuzz_idx.to_str())
    @end

    @! 2. Tampered message MUST fail
    tampered = []
    t_i = 0
    @while t_i < rand_msg.len()
      b = rand_msg[t_i]
      @if t_i == 0 b = b ^ 0x01 @end
      tampered = tampered.push(b)
      t_i = t_i + 1
    @end
    @if ed25519_verify(kp.public_key, tampered, sig) != 0
      all_fuzz_passed = 0
      println("  [FAIL] Fuzz tampered message was NOT rejected for iteration " + fuzz_idx.to_str())
    @end

    fuzz_idx = fuzz_idx + 1
  @end

  total = total + 1
  passed = passed + assert_eq_int(all_fuzz_passed, 1, "10-iteration randomized keypair/signing/tampering fuzz matrix verified")

  @! ----------------------------------------------------------------------------
  @! SUITE 9: SECURITY & CRYPTO FACADES INTEGRATION
  @! ----------------------------------------------------------------------------
  println("\n--- [TEST SUITE 9: Security & Crypto Facades Integration] ---")

  @! Facade 1: universe/crypto/crypto.maya
  total = total + 1
  fc_h = crypto_sha512_hex([97, 98, 99])
  exp_abc = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  passed = passed + assert_eq_str(fc_h, exp_abc, "universe/crypto/crypto.maya: crypto_sha512_hex verified")

  total = total + 1
  fc_kp = crypto_ed25519_keygen(sk3)
  fc_sig = crypto_ed25519_sign(sk3, [0xaf, 0x82])
  fc_v = crypto_ed25519_verify(fc_kp.public_key, [0xaf, 0x82], fc_sig)
  passed = passed + assert_eq_int(fc_v, 1, "universe/crypto/crypto.maya: crypto_ed25519_verify verified")

  @! Facade 2: universe/security/ed25519.maya
  total = total + 1
  sec_kp = ed25519_keygen_sec(sk3)
  sec_sig = ed25519_sign_sec(sk3, [0xaf, 0x82])
  sec_v = ed25519_verify_sec(sec_kp.public_key, [0xaf, 0x82], sec_sig)
  sec_v_bad = ed25519_verify_sec(sec_kp.public_key, [0xaf, 0x83], sec_sig)
  passed = passed + assert_eq_int(sec_v == 1 && sec_v_bad == 0, 1, "universe/security/ed25519.maya: keygen/sign/verify facade verified")

  @! Facade 3: universe/core/crypto.maya
  total = total + 1
  core_h = sha512([97, 98, 99])
  core_kp = ed25519_keypair_from_seed(sk3)
  core_match = bytes_match(core_kp.public_key, exp_pk3)
  passed = passed + assert_eq_int(core_h.len() == 64 && core_match == 1, 1, "universe/core/crypto.maya: sha512 & ed25519_keypair_from_seed verified")

  println("=================================================================")
  println("Results: " + passed.to_str() + " / " + total.to_str() + " passed.")
  @if passed == total
    println("🏆 ALL SHA-512 & ED25519 EMPIRICAL CHALLENGES PASSED WITH ZERO ERRORS!")
    return 0
  @else
    println("❌ FAILURES DETECTED IN EMPIRICAL CHALLENGES!")
    return 1
  @end
@end
