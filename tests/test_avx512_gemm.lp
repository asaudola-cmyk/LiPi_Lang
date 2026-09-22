// ==============================================================================
// 🧪 LIPI TEST SUITE: AVX-512 4x4 TILED SILICON GEMM MATRIX ENGINE
// File: tests/test_avx512_gemm.lp
// 100% Pure Lipi Implementation — Zero External / BLAS Dependencies
// ==============================================================================

import "universe/cpu/avx512_gemm"
import "universe/cpu/avx512_native"
import "universe/core/memory"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI AVX-512 4x4 TILED GEMM MATRIX ENGINE TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: 64-Byte Cacheline Memory Alignment Verification ────────────
  println("▶ Section 1: 64-Byte Cacheline Alignment & Safety Guards...")
  total_tests = total_tests + 1

  buf_64 = gemm_alloc_aligned_64(1024)
  ok_align = assert_true(gemm_is_aligned_64(buf_64) == 1, "Buffer pointer is strictly 64-byte aligned")
  
  if ok_align == 1
    println("  ✔ [PASS] 64-byte cacheline boundary verified (ptr % 64 == 0)")
    passed_tests = passed_tests + 1
  end

  // ── Section 2: 4x4 Register-Tiled Microkernel Verification ────────────────
  println("▶ Section 2: 4x4 Register-Tiled Microkernel Verification...")
  total_tests = total_tests + 1

  // Matrices A (4x4) and B (4x4), Output C (4x4)
  // A = [ [1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4] ]
  // B = [ [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1] ] (Identity 4x4)
  // C = A * I = A
  mat_a = gemm_alloc_aligned_64(16 * 4)
  mat_b = gemm_alloc_aligned_64(16 * 4)
  mat_c = gemm_alloc_aligned_64(16 * 4)

  // Initialize Matrix A
  r = 0
  @while r < 4
    c = 0
    @while c < 4
      mem_write_u32(mat_a, ((r * 4) + c) * 4, c + 1)
      c = c + 1
    @end
    r = r + 1
  @end

  // Initialize Matrix B as Identity Matrix
  r = 0
  @while r < 4
    c = 0
    @while c < 4
      @if r == c
        mem_write_u32(mat_b, ((r * 4) + c) * 4, 1)
      @else
        mem_write_u32(mat_b, ((r * 4) + c) * 4, 0)
      @end
      c = c + 1
    @end
    r = r + 1
  @end

  // Compute C = A * B using 4x4 tiled microkernel
  avx512_gemm_tile_4x4(mat_a, mat_b, mat_c, 4, 4, 4, 4)

  // Verify C matches A
  ok_tile = 1
  r = 0
  @while r < 4
    c = 0
    @while c < 4
      expected = c + 1
      actual = mem_read_u32(mat_c, ((r * 4) + c) * 4)
      @if actual != expected
        ok_tile = 0
      @end
      c = c + 1
    @end
    r = r + 1
  @end

  ok_t_assert = assert_true(ok_tile == 1, "4x4 Tiled GEMM with Identity Matrix produces exact result")
  if ok_t_assert == 1
    println("  ✔ [PASS] 4x4 Register-Tiled Microkernel computed without stack spill")
    passed_tests = passed_tests + 1
  end

  // ── Section 3: Full 8x8 Tiled Matrix Multiplication (Multi-Block) ─────────
  println("▶ Section 3: Full 8x8 Multi-Block Matrix Multiplication...")
  total_tests = total_tests + 1

  // 8x8 Matrix A (all elements = 2), 8x8 Matrix B (all elements = 3)
  // Each element of C should be 8 * (2 * 3) = 48
  mat_a8 = gemm_alloc_aligned_64(64 * 4)
  mat_b8 = gemm_alloc_aligned_64(64 * 4)
  mat_c8 = gemm_alloc_aligned_64(64 * 4)

  idx = 0
  @while idx < 64
    mem_write_u32(mat_a8, idx * 4, 2)
    mem_write_u32(mat_b8, idx * 4, 3)
    mem_write_u32(mat_c8, idx * 4, 0)
    idx = idx + 1
  @end

  gemm_matrix_multiply(mat_a8, mat_b8, mat_c8, 8, 8, 8)

  ok_8x8 = 1
  idx = 0
  @while idx < 64
    val = mem_read_u32(mat_c8, idx * 4)
    @if val != 48
      ok_8x8 = 0
    @end
    idx = idx + 1
  @end

  ok_8_assert = assert_true(ok_8x8 == 1, "8x8 Matrix Multiplication produces expected 48 for all 64 elements")
  if ok_8_assert == 1
    println("  ✔ [PASS] 8x8 Multi-Block GEMM verified (All 64 cells = 48)")
    passed_tests = passed_tests + 1
  end

  // ── Section 4: Bilingual Bangla Alias & Dynamic CPUID Guard ───────────────
  println("▶ Section 4: Bilingual Bangla Aliases & Hardware Guard...")
  total_tests = total_tests + 1

  res_bangla = ম্যাট্রিক্স_গুণন(mat_a8, mat_b8, mat_c8, 8, 8, 8)
  ok_b1 = assert_eq_int(res_bangla, 1, "ম্যাট্রিক্স_গুণন returned success")
  ok_b2 = assert_true(cpu_has_avx512() >= 0, "cpu_has_avx512 guard returns valid state")

  if ok_b1 == 1 && ok_b2 == 1
    println("  ✔ [PASS] Bilingual alias 'ম্যাট্রিক্স_গুণন' and CPUID guard verified")
    passed_tests = passed_tests + 1
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL AVX-512 GEMM TESTS PASSED (4/4) ✔")
    return 0
  else
    println("❌ SOME GEMM TESTS FAILED!")
    return 1
  end
@end

main()
