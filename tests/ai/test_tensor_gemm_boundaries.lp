@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — TENSOR GEMM BOUNDARIES & CORNER CASES
@! File: tests/ai/test_tensor_gemm_boundaries.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: ai, tensor, gemm, boundaries
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
  println("⚡ TENSOR GEMM BOUNDARIES & NUMERICAL STABILITY TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Prime & Unaligned Matrix Dimensions (17x31) x (31x23) -> (17x23)
  println("▶ Test 1: Prime & Unaligned Dimensions (17x31 x 31x23)...")
  total_tests = total_tests + 1
  
  a_prime = []
  i = 0
  @while i < 17 * 31
    a_prime = a_prime.push(1.0)
    i = i + 1
  @end
  
  b_prime = []
  i = 0
  @while i < 31 * 23
    b_prime = b_prime.push(1.0)
    i = i + 1
  @end
  
  t_ap = tensor_new(a_prime, [17, 31])
  t_bp = tensor_new(b_prime, [31, 23])
  t_cp = tensor_matmul(t_ap, t_bp)
  
  ok1_1 = assert_eq_int(t_cp.shape[0], 17, "Output rows == 17")
  ok1_2 = assert_eq_int(t_cp.shape[1], 23, "Output cols == 23")
  @! Sum across k=31 ones = 31.0
  ok1_3 = assert_true(t_cp.data[0] == 31.0, "Element (0,0) == 31.0")
  ok1_4 = assert_true(t_cp.data[17 * 23 - 1] == 31.0, "Element (16,22) == 31.0")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: Prime & unaligned matrix GEMM verified")
  @end

  @! TEST 2: Vector Dot Product Boundary (1x1024) x (1024x1) -> (1x1)
  println("▶ Test 2: Large Vector Dot Product (1x1024 x 1024x1)...")
  total_tests = total_tests + 1
  
  vec_a = []
  vec_b = []
  i = 0
  @while i < 1024
    vec_a = vec_a.push(1.0)
    vec_b = vec_b.push(2.0)
    i = i + 1
  @end
  
  t_va = tensor_new(vec_a, [1, 1024])
  t_vb = tensor_new(vec_b, [1024, 1])
  t_dot = tensor_matmul(t_va, t_vb)
  
  ok2_1 = assert_eq_int(t_dot.shape[0], 1, "Output row == 1")
  ok2_2 = assert_eq_int(t_dot.shape[1], 1, "Output col == 1")
  @! Sum of 1024 * (1.0 * 2.0) = 2048.0
  ok2_3 = assert_true(t_dot.data[0] == 2048.0, "Dot product result == 2048.0")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Large vector dot product boundary verified")
  @end

  @! TEST 3: Transposed Operands (A x B^T) with Strided Memory Indexing
  println("▶ Test 3: Transposed View Multiplication (A x B^T)...")
  total_tests = total_tests + 1
  
  @! A = [[1, 2], [3, 4]] (2x2), B = [[1, 2], [3, 4]] (2x2)
  @! B^T = [[1, 3], [2, 4]]
  @! A x B^T = [[1*1 + 2*2, 1*3 + 2*4], [3*1 + 4*2, 3*3 + 4*4]] = [[5, 11], [11, 25]]
  t_a3 = tensor_new([1.0, 2.0, 3.0, 4.0], [2, 2])
  t_b3 = tensor_new([1.0, 2.0, 3.0, 4.0], [2, 2])
  t_b3_t = tensor_transpose(t_b3, 0, 1)
  
  ok3_strides = assert_true(t_b3_t.strides[0] == 1 && t_b3_t.strides[1] == 2, "Transposed strides inverted to [1, 2]")
  t_prod3 = tensor_matmul(t_a3, t_b3_t)
  
  ok3_1 = assert_true(t_prod3.data[0] == 5.0, "C(0,0) == 5.0")
  ok3_2 = assert_true(t_prod3.data[1] == 11.0, "C(0,1) == 11.0")
  ok3_3 = assert_true(t_prod3.data[2] == 11.0, "C(1,0) == 11.0")
  ok3_4 = assert_true(t_prod3.data[3] == 25.0, "C(1,1) == 25.0")
  
  @if ok3_strides == 1 && ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Transposed view multiplication verified")
  @end

  @! TEST 4: Numerical Stability & Large Dynamic Range Values
  println("▶ Test 4: Large Dynamic Range Stability (1e6 Scale)...")
  total_tests = total_tests + 1
  
  @! A = [[1000000.0, 2000000.0]], B = [[3.0], [4.0]]
  @! Product = 1000000.0 * 3.0 + 2000000.0 * 4.0 = 3000000.0 + 8000000.0 = 11000000.0
  t_extreme_a = tensor_new([1000000.0, 2000000.0], [1, 2])
  t_extreme_b = tensor_new([3.0, 4.0], [2, 1])
  t_extreme_c = tensor_matmul(t_extreme_a, t_extreme_b)
  
  ok4_1 = assert_true(t_extreme_c.data[0] == 11000000.0, "Large scale accumulation equals 11000000.0")
  @if ok4_1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Numerical stability across large dynamic range verified")
  @end

  @! TEST 5: Minimal 1x1 Matrix Multiplication Boundary
  println("▶ Test 5: Minimal 1x1 Matrix Multiplication Boundary...")
  total_tests = total_tests + 1
  
  t1x1_a = tensor_new([42.0], [1, 1])
  t1x1_b = tensor_new([3.0], [1, 1])
  t1x1_c = tensor_matmul(t1x1_a, t1x1_b)
  
  ok5_1 = assert_eq_int(t1x1_c.shape[0], 1, "Output row == 1")
  ok5_2 = assert_eq_int(t1x1_c.shape[1], 1, "Output col == 1")
  ok5_3 = assert_true(t1x1_c.data[0] == 126.0, "1x1 GEMM product 42.0 * 3.0 == 126.0")
  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Minimal 1x1 matrix GEMM boundary verified")
  @end

  println("=================================================================")
  println("📊 TENSOR GEMM BOUNDARIES TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 TENSOR GEMM BOUNDARIES TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TENSOR GEMM BOUNDARIES TESTS FAILED")
    return 1
  @end
@end
