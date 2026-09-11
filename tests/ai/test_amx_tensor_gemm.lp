@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — INTEL AMX & AVX-512 TENSOR GEMM TEST SUITE
@! File: tests/ai/test_amx_tensor_gemm.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"

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
  println("⚡ MAYA INTEL AMX & AVX-512 TENSOR GEMM ACCELERATION TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Dynamic CPUID / SIMD Hardware Capability Detection
  println("▶ Section 1: SIMD Hardware Capabilities Detection...")
  total_tests = total_tests + 1
  caps = tensor_detect_simd_capabilities()
  ok1 = assert_true(caps.has_amx == 0 || caps.has_amx == 1, "AMX capability flag is valid boolean")
  ok2 = assert_true(caps.has_avx512 == 0 || caps.has_avx512 == 1, "AVX-512 capability flag is valid boolean")
  ok3 = assert_true(caps.has_avx2 == 0 || caps.has_avx2 == 1, "AVX2 capability flag is valid boolean")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hardware SIMD introspection verified (AMX=" + caps.has_amx.to_str() + ", AVX512=" + caps.has_avx512.to_str() + ", AVX2=" + caps.has_avx2.to_str() + ")")
  @end

  @! SECTION 2: 16x16 Single-Tile AMX GEMM (A * I_16 == A)
  println("▶ Section 2: 16x16 Single Tile AMX Matrix Multiplication...")
  total_tests = total_tests + 1
  
  @! Create 16x16 matrix A with distinct sequential values: A[i, j] = i * 16 + j + 1
  a_data = []
  i = 0
  @while i < 256
    a_data = a_data.push(i + 1)
    i = i + 1
  @end
  t_a = tensor_new(a_data, [16, 16])

  @! Create 16x16 identity matrix I
  eye_data = []
  r = 0
  @while r < 16
    c = 0
    @while c < 16
      @if r == c
        eye_data = eye_data.push(1)
      @else
        eye_data = eye_data.push(0)
      @end
      c = c + 1
    @end
    r = r + 1
  @end
  t_eye = tensor_new(eye_data, [16, 16])

  t_c = tensor_gemm_amx_tiled(t_a, t_eye, 16, 16, 16)
  
  match_count = 0
  k = 0
  @while k < 256
    @if t_c.data[k] == t_a.data[k]
      match_count = match_count + 1
    @end
    k = k + 1
  @end
  ok4 = assert_eq_int(match_count, 256, "16x16 Tile GEMM with Identity matches 100% (256/256 elements)")
  @if ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 16x16 Single-Tile AMX GEMM verified")
  @end

  @! SECTION 3: 32x32 Multi-Tile AMX GEMM (2x2 Tile Grid)
  println("▶ Section 3: 32x32 Multi-Tile AMX Matrix Multiplication (4 Tiles)...")
  total_tests = total_tests + 1
  
  @! Matrix A: all 1s (32x32)
  @! Matrix B: all 2s (32x32)
  @! C = A * B -> each element should be sum_{k=0..31}(1 * 2) = 64
  a_ones = []
  b_twos = []
  k = 0
  @while k < 1024
    a_ones = a_ones.push(1)
    b_twos = b_twos.push(2)
    k = k + 1
  @end
  t_a32 = tensor_new(a_ones, [32, 32])
  t_b32 = tensor_new(b_twos, [32, 32])
  t_c32 = tensor_gemm_amx_tiled(t_a32, t_b32, 32, 32, 32)
  
  all_64 = 1
  k = 0
  @while k < 1024
    @if t_c32.data[k] != 64
      all_64 = 0
    @end
    k = k + 1
  @end
  ok5 = assert_true(all_64 == 1, "32x32 Multi-Tile GEMM produces uniform 64 for all 1024 elements")
  @if ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 32x32 Multi-Tile AMX GEMM verified")
  @end

  @! SECTION 4: Non-Aligned Prime Dimensions GEMM (17 x 19 x 23)
  println("▶ Section 4: Non-Aligned Dimension Boundary & Fringe GEMM (17x19x23)...")
  total_tests = total_tests + 1
  
  @! Matrix A (17 x 19) all 2s
  @! Matrix B (19 x 23) all 3s
  @! C = A * B (17 x 23): each element = 19 * (2 * 3) = 114
  a17 = []
  k = 0
  @while k < 17 * 19
    a17 = a17.push(2)
    k = k + 1
  @end
  b19 = []
  k = 0
  @while k < 19 * 23
    b19 = b19.push(3)
    k = k + 1
  @end
  t_a17 = tensor_new(a17, [17, 19])
  t_b19 = tensor_new(b19, [19, 23])
  t_c17 = tensor_matmul(t_a17, t_b19)
  
  all_114 = 1
  k = 0
  @while k < 17 * 23
    @if t_c17.data[k] != 114
      all_114 = 0
    @end
    k = k + 1
  @end
  ok6 = assert_true(all_114 == 1, "Non-aligned 17x23 GEMM produces exact 114 across all boundary tiles")
  @if ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Boundary & fringe GEMM verified")
  @end

  @! SECTION 5: AVX-512 16-Wide Vectorized FMA Kernel
  println("▶ Section 5: AVX-512 16-Wide Vectorized FMA Kernel...")
  total_tests = total_tests + 1
  t_avx = tensor_gemm_avx512(t_a, t_eye, 16, 16, 16)
  avx_match = 1
  k = 0
  @while k < 256
    @if t_avx.data[k] != t_a.data[k]
      avx_match = 0
    @end
    k = k + 1
  @end
  ok7 = assert_true(avx_match == 1, "AVX-512 16-Wide FMA GEMM matches exact analytical product")
  @if ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] AVX-512 16-wide FMA GEMM verified")
  @end

  println("=================================================================")
  println("📊 AMX & AVX-512 GEMM TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 AMX & AVX-512 TENSOR GEMM TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME AMX & AVX-512 GEMM TESTS FAILED")
    return 1
  @end
@end
