@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: BITWISE OPS + FIXED-POINT MATH PIPELINE
@! File: tests/e2e/tier3_combinations/test_bitwise_fixed_point.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@fn FP_SCALE() return 65536 @end @! 16-bit fractional precision

@fn fp_from_int(x)
  return x * FP_SCALE()
@end

@fn fp_to_int(x)
  return x / FP_SCALE()
@end

@fn fp_mul(a, b)
  return (a * b) / FP_SCALE()
@end

@fn fp_div(a, b)
  return (a * FP_SCALE()) / b
@end

@fn fp_abs(x)
  @if x < 0
    return 0 - x
  @end
  return x
@end

@fn fp_sqrt(val)
  @if val <= 0
    return 0
  @end
  @! Newton-Raphson approximation in fixed point
  x = val
  i = 0
  @while i < 16
    next_x = (x + fp_div(val, x)) / 2
    @if next_x == x || next_x == x - 1
      return next_x
    @end
    x = next_x
    i = i + 1
  @end
  return x
@end

@fn fp_distance(x1, y1, x2, y2)
  dx = x2 - x1
  dy = y2 - y1
  dx_sq = fp_mul(dx, dx)
  dy_sq = fp_mul(dy, dy)
  return fp_sqrt(dx_sq + dy_sq)
@end

@fn pack_rgba(r, g, b, a)
  r_clamped = r & 255
  g_clamped = g & 255
  b_clamped = b & 255
  a_clamped = a & 255
  return (r_clamped * 16777216) | (g_clamped * 65536) | (b_clamped * 256) | a_clamped
@end

@fn unpack_r(color)
  return (color / 16777216) & 255
@end

@fn unpack_g(color)
  return (color / 65536) & 255
@end

@fn unpack_b(color)
  return (color / 256) & 255
@end

@fn unpack_a(color)
  return color & 255
@end

@fn bit_popcount(val)
  count = 0
  v = val
  @while v > 0
    count = count + v & 1
    v = v / 2
  @end
  return count
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 8: Bitwise Ops & Fixed-Point Math")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.8.1: Fixed-Point Basic Multiplication & Division
  total = total + 1
  fp_3 = fp_from_int(3)
  fp_4 = fp_from_int(4)
  fp_12 = fp_mul(fp_3, fp_4)
  fp_res_div = fp_div(fp_12, fp_3)

  @if fp_12 == fp_from_int(12) && fp_res_div == fp_4
    passed = passed + 1
    println("  [PASS] T3.8.1: Fixed-point arithmetic precision (3 * 4 == 12, 12 / 3 == 4)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8.1: Fixed-point mul/div failed")
  @end

  @! T3.8.2: Fixed-Point Euclidean Distance 3-4-5 Triangle
  total = total + 1
  p1_x = fp_from_int(0)
  p1_y = fp_from_int(0)
  p2_x = fp_from_int(3)
  p2_y = fp_from_int(4)
  dist_fp = fp_distance(p1_x, p1_y, p2_x, p2_y)
  dist_int = fp_to_int(dist_fp)

  @if dist_int == 5
    passed = passed + 1
    println("  [PASS] T3.8.2: 2D Euclidean distance using fixed-point Newton sqrt (dist == 5.0)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8.2: Fixed-point distance expected 5, got " + int_to_str(dist_int))
  @end

  @! T3.8.3: Bitwise RGBA Word Packing and Unpacking
  total = total + 1
  packed = pack_rgba(255, 128, 64, 200)
  r = unpack_r(packed)
  g = unpack_g(packed)
  b = unpack_b(packed)
  a = unpack_a(packed)

  @if r == 255 && g == 128 && b == 64 && a == 200
    passed = passed + 1
    println("  [PASS] T3.8.3: 32-bit RGBA bitwise pack/unpack round-trip (255, 128, 64, 200)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8.3: RGBA bitwise pack/unpack failed: r=" + int_to_str(r) + ", g=" + int_to_str(g))
  @end

  @! T3.8.4: Bitwise Population Count (Hamming Weight)
  total = total + 1
  @! 0xFF (255) has 8 bits, 0x1000 (4096) has 1 bit, 0xAAAA (43690) has 8 bits
  pop_255 = bit_popcount(255)
  pop_4096 = bit_popcount(4096)
  pop_43690 = bit_popcount(43690)

  @if pop_255 == 8 && pop_4096 == 1 && pop_43690 == 8
    passed = passed + 1
    println("  [PASS] T3.8.4: Bitwise population count (Hamming weight: 255->8, 4096->1, 0xAAAA->8)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8.4: Popcount failed")
  @end

  @! T3.8.5: Complex Bitwise Masking and XOR Inversion
  total = total + 1
  val_a = 0x55AA55AA
  val_b = 0xFFFFFFFF
  val_xor = val_a ^ val_b  @! Invert bits
  val_restored = val_xor ^ val_b

  @if val_restored == val_a && (val_a & 0xFFFF0000) == 0x55AA0000
    passed = passed + 1
    println("  [PASS] T3.8.5: 32-bit XOR involutive inversion and bitmask extraction")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8.5: Bitwise mask and XOR failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 8 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 8 (Bitwise Ops & Fixed-Point Math) PASSED")
    return 0
  @else
    println("✗ Combination 8 (Bitwise Ops & Fixed-Point Math) FAILED")
    return 1
  @end
@end
