@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — SIMD / AMX TENSOR MATMUL TEST SUITE
@! File: tests/ai/test_simd_amx_matmul.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: ai, tensor, simd, gemm, matmul
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA SIMD / AMX ACCELERATED TENSOR MATMUL TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: 2D Matrix Matmul (16x16 Tile Matmul)
  println("▶ Test 1: 2D Matrix Matmul (16x16 Identity & Scaled GEMM)...")
  total_tests = total_tests + 1
  
  @! Create 16x16 identity matrix
  eye_data = []
  i = 0
  @while i < 16
    j = 0
    @while j < 16
      @if i == j
        eye_data = eye_data.push(1.0)
      @else
        eye_data = eye_data.push(0.0)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  
  @! Create 16x16 values matrix: val = i * 16 + j
  mat_data = []
  i = 0
  @while i < 256
    mat_data = mat_data.push(i * 1.0)
    i = i + 1
  @end
  
  t_eye = tensor_new(eye_data, [16, 16])
  t_mat = tensor_new(mat_data, [16, 16])
  
  t_prod = tensor_matmul(t_mat, t_eye)
  
  ok1_1 = assert_eq_int(t_prod.ndim, 2, "Product tensor rank is 2D")
  ok1_2 = assert_eq_int(t_prod.shape[0], 16, "Output rows == 16")
  ok1_3 = assert_eq_int(t_prod.shape[1], 16, "Output cols == 16")
  ok1_4 = assert_true(t_prod.data[0] == 0.0, "Element (0,0) == 0.0")
  ok1_5 = assert_true(t_prod.data[255] == 255.0, "Element (15,15) == 255.0")
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: 16x16 2D matrix multiplication verified")
  @end

  @! TEST 2: Non-Square Rectangular GEMM (2x4) x (4x3) -> (2x3)
  println("▶ Test 2: Non-Square Rectangular Matrix GEMM...")
  total_tests = total_tests + 1
  
  @! A = [[1, 2, 3, 4], [5, 6, 7, 8]] (2x4)
  a_data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  @! B = [[1, 0, 2], [0, 1, 1], [1, 2, 0], [2, 1, 1]] (4x3)
  b_data = [1.0, 0.0, 2.0, 0.0, 1.0, 1.0, 1.0, 2.0, 0.0, 2.0, 1.0, 1.0]
  
  ta = tensor_new(a_data, [2, 4])
  tb = tensor_new(b_data, [4, 3])
  tc = tensor_matmul(ta, tb)
  
  @! Expected Row 0:
  @! (0,0): 1*1 + 2*0 + 3*1 + 4*2 = 1 + 0 + 3 + 8 = 12
  @! (0,1): 1*0 + 2*1 + 3*2 + 4*1 = 0 + 2 + 6 + 4 = 12
  @! (0,2): 1*2 + 2*1 + 3*0 + 4*1 = 2 + 2 + 0 + 4 = 8
  @! Expected Row 1:
  @! (1,0): 5*1 + 6*0 + 7*1 + 8*2 = 5 + 0 + 7 + 16 = 28
  @! (1,1): 5*0 + 6*1 + 7*2 + 8*1 = 0 + 6 + 14 + 8 = 28
  @! (1,2): 5*2 + 6*1 + 7*0 + 8*1 = 10 + 6 + 0 + 8 = 24
  
  ok2_1 = assert_eq_int(tc.shape[0], 2, "Product rows == 2")
  ok2_2 = assert_eq_int(tc.shape[1], 3, "Product cols == 3")
  ok2_3 = assert_true(tc.data[0] == 12.0, "C(0,0) == 12.0")
  ok2_4 = assert_true(tc.data[1] == 12.0, "C(0,1) == 12.0")
  ok2_5 = assert_true(tc.data[2] == 8.0, "C(0,2) == 8.0")
  ok2_6 = assert_true(tc.data[3] == 28.0, "C(1,0) == 28.0")
  ok2_7 = assert_true(tc.data[4] == 28.0, "C(1,1) == 28.0")
  ok2_8 = assert_true(tc.data[5] == 24.0, "C(1,2) == 24.0")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1 && ok2_6 == 1 && ok2_7 == 1 && ok2_8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Non-square rectangular GEMM verified")
  @end

  @! TEST 3: Batched 3D GEMM (2 x 2x2) x (2 x 2x2)
  println("▶ Test 3: Batched 3D GEMM (Batch Size 2)...")
  total_tests = total_tests + 1
  
  b_a = [1.0, 2.0, 3.0, 4.0,  2.0, 0.0, 0.0, 2.0] @! [2, 2, 2]
  b_b = [2.0, 0.0, 0.0, 2.0,  3.0, 1.0, 1.0, 3.0] @! [2, 2, 2]
  
  t_ba = tensor_new(b_a, [2, 2, 2])
  t_bb = tensor_new(b_b, [2, 2, 2])
  t_bc = tensor_matmul(t_ba, t_bb)
  
  ok3_1 = assert_eq_int(t_bc.ndim, 3, "Batched output rank is 3D")
  ok3_2 = assert_eq_int(t_bc.shape[0], 2, "Batch count == 2")
  @! Batch 0: [[1,2],[3,4]] * [[2,0],[0,2]] = [[2,4],[6,8]]
  ok3_3 = assert_true(t_bc.data[0] == 2.0 && t_bc.data[1] == 4.0, "Batch 0 row 0 is [2, 4]")
  ok3_4 = assert_true(t_bc.data[2] == 6.0 && t_bc.data[3] == 8.0, "Batch 0 row 1 is [6, 8]")
  @! Batch 1: [[2,0],[0,2]] * [[3,1],[1,3]] = [[6,2],[2,6]]
  ok3_5 = assert_true(t_bc.data[4] == 6.0 && t_bc.data[5] == 2.0, "Batch 1 row 0 is [6, 2]")
  ok3_6 = assert_true(t_bc.data[6] == 2.0 && t_bc.data[7] == 6.0, "Batch 1 row 1 is [2, 6]")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1 && ok3_6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Batched 3D GEMM verified")
  @end

  @! TEST 4: Multidirectional Broadcast GEMM
  println("▶ Test 4: Multidirectional Broadcast GEMM [2, 1, 2, 2] x [1, 2, 2, 2]...")
  total_tests = total_tests + 1
  
  d_a4 = [1.0, 0.0, 0.0, 1.0,  2.0, 0.0, 0.0, 2.0] @! [2, 1, 2, 2]
  d_b4 = [3.0, 0.0, 0.0, 3.0,  4.0, 0.0, 0.0, 4.0] @! [1, 2, 2, 2]
  
  ta4 = tensor_new(d_a4, [2, 1, 2, 2])
  tb4 = tensor_new(d_b4, [1, 2, 2, 2])
  tc4 = tensor_matmul(ta4, tb4)
  
  ok4_1 = assert_eq_int(tc4.ndim, 4, "Output rank is 4D")
  ok4_2 = assert_eq_int(tc4.shape[0], 2, "Batch dim 0 == 2")
  ok4_3 = assert_eq_int(tc4.shape[1], 2, "Batch dim 1 == 2")
  ok4_4 = assert_eq_int(tc4.shape[2], 2, "Matrix rows == 2")
  ok4_5 = assert_eq_int(tc4.shape[3], 2, "Matrix cols == 2")
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1 && ok4_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Multidirectional broadcast GEMM verified")
  @end

  @! TEST 5: Tiled AMX 16x16 Kernel Blocked Multiplication
  println("▶ Test 5: Tiled AMX 16x16 Blocked Matrix Multiplication Kernel...")
  total_tests = total_tests + 1
  
  @! Two 32x32 matrices (4 tiles of 16x16 each)
  data32_a = []
  data32_b = []
  idx32 = 0
  @while idx32 < 1024
    data32_a = data32_a.push(1.0)
    data32_b = data32_b.push(2.0)
    idx32 = idx32 + 1
  @end
  
  t32_a = tensor_new(data32_a, [32, 32])
  t32_b = tensor_new(data32_b, [32, 32])
  t32_c = tensor_matmul(t32_a, t32_b)
  
  @! Each element in 32x32 is sum(1.0 * 2.0 for 32 iterations) = 64.0
  ok5_1 = assert_eq_int(t32_c.shape[0], 32, "Tiled rows == 32")
  ok5_2 = assert_eq_int(t32_c.shape[1], 32, "Tiled cols == 32")
  ok5_3 = assert_true(t32_c.data[0] == 64.0, "Tile element (0,0) == 64.0")
  ok5_4 = assert_true(t32_c.data[512] == 64.0, "Tile element (16,0) == 64.0")
  ok5_5 = assert_true(t32_c.data[1023] == 64.0, "Tile element (31,31) == 64.0")
  
  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1 && ok5_4 == 1 && ok5_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Tiled AMX 16x16 blocked matrix multiply verified")
  @end

  println("=================================================================")
  println(str_concat("📊 SIMD/AMX MATMUL TEST RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " passed")))))
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 SIMD/AMX MATMUL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SIMD/AMX MATMUL TESTS FAILED")
    return 1
  @end
@end
