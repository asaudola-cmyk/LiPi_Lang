@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — HIGH-PERFORMANCE AI TENSOR TEST SUITE
@! File: tests/ai/test_ai_tensor.maya
@! Milestone: 4, 5, 6 — AI Tensor Engine Verification
@! 100% Pure Maya Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"
import "universe/sys/syscalls"
import "universe/ai/tensor"

@! ============================================================================
@! ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@fn assert_true(cond: i64, msg: string) -> i64
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed (expected true): ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn assert_near_int(actual: i64, expected: i64, tol: i64, msg: string) -> i64
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    return 1
  @else
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Value ", str_concat(to_str(actual), str_concat(" outside tolerance of expected ", to_str(expected)))))))
    return 0
  @end
@end

@! ============================================================================
@! TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🧠 MAYA SOVEREIGN AI TENSOR VERIFICATION TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! TEST 1: Tensor 1D and 2D creation and shape indexing
  @! ----------------------------------------------------------------------------
  println("▶ Test 1: Tensor 1D & 2D Creation and Shape Indexing...")

  @! 1.1 1D Tensor Creation & Indexing
  total_tests = total_tests + 1
  t_1d = tensor_create([10, 20, 30, 40, 50], [5])
  ok_1d_ndim   = assert_eq_int(t_1d.ndim, 1, "1D Tensor ndim == 1")
  ok_1d_size   = assert_eq_int(t_1d.size, 5, "1D Tensor size == 5")
  ok_1d_s0     = assert_eq_int(t_1d.strides[0], 1, "1D Tensor stride[0] == 1")
  ok_1d_contig = assert_eq_int(t_1d.is_contiguous, 1, "1D Tensor is_contiguous == 1")
  
  ok_1d_g0 = assert_eq_int(tensor_get(t_1d, [0]), 10, "tensor_get(t_1d, [0]) == 10")
  ok_1d_g2 = assert_eq_int(tensor_get(t_1d, [2]), 30, "tensor_get(t_1d, [2]) == 30")
  ok_1d_g4 = assert_eq_int(tensor_get(t_1d, [4]), 50, "tensor_get(t_1d, [4]) == 50")
  ok_1d_gf = assert_eq_int(tensor_get_flat(t_1d, 3), 40, "tensor_get_flat(t_1d, 3) == 40")

  t_1d = tensor_set(t_1d, [2], 99)
  ok_1d_mut = assert_eq_int(tensor_get(t_1d, [2]), 99, "tensor_set mutates element [2] to 99")

  @if ok_1d_ndim == 1 && ok_1d_size == 1 && ok_1d_s0 == 1 && ok_1d_contig == 1 && ok_1d_g0 == 1 && ok_1d_g2 == 1 && ok_1d_g4 == 1 && ok_1d_gf == 1 && ok_1d_mut == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 1D Tensor allocation, striding and coordinate indexing verified")
  @end

  @! 1.2 2D Tensor Creation & Shape Indexing (2 rows x 3 columns)
  total_tests = total_tests + 1
  t_2d = tensor_create([1, 2, 3, 4, 5, 6], [2, 3])
  ok_2d_ndim   = assert_eq_int(t_2d.ndim, 2, "2D Tensor ndim == 2")
  ok_2d_size   = assert_eq_int(t_2d.size, 6, "2D Tensor size == 6")
  ok_2d_r      = assert_eq_int(t_2d.shape[0], 2, "2D Tensor rows shape[0] == 2")
  ok_2d_c      = assert_eq_int(t_2d.shape[1], 3, "2D Tensor cols shape[1] == 3")
  ok_2d_s0     = assert_eq_int(t_2d.strides[0], 3, "2D Tensor row stride == 3")
  ok_2d_s1     = assert_eq_int(t_2d.strides[1], 1, "2D Tensor col stride == 1")
  ok_2d_contig = assert_eq_int(t_2d.is_contiguous, 1, "2D Tensor is_contiguous == 1")

  ok_2d_g00 = assert_eq_int(tensor_get(t_2d, [0, 0]), 1, "tensor_get(t_2d, [0, 0]) == 1")
  ok_2d_g02 = assert_eq_int(tensor_get(t_2d, [0, 2]), 3, "tensor_get(t_2d, [0, 2]) == 3")
  ok_2d_g10 = assert_eq_int(tensor_get(t_2d, [1, 0]), 4, "tensor_get(t_2d, [1, 0]) == 4")
  ok_2d_g12 = assert_eq_int(tensor_get(t_2d, [1, 2]), 6, "tensor_get(t_2d, [1, 2]) == 6")

  t_2d = tensor_set(t_2d, [1, 1], 42)
  ok_2d_mut = assert_eq_int(tensor_get(t_2d, [1, 1]), 42, "tensor_set mutates element [1, 1] to 42")

  @if ok_2d_ndim == 1 && ok_2d_size == 1 && ok_2d_r == 1 && ok_2d_c == 1 && ok_2d_s0 == 1 && ok_2d_s1 == 1 && ok_2d_contig == 1 && ok_2d_g00 == 1 && ok_2d_g02 == 1 && ok_2d_g10 == 1 && ok_2d_g12 == 1 && ok_2d_mut == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 2D Tensor row-major indexing and mutation verified")
  @end

  @! 1.3 Tensor Zero-Copy Reshaping & Factory Functions
  total_tests = total_tests + 1
  t_zeros = tensor_zeros([2, 4])
  ok_z_sz = assert_eq_int(t_zeros.size, 8, "tensor_zeros([2, 4]) size == 8")
  ok_z_00 = assert_eq_int(tensor_get(t_zeros, [0, 0]), 0, "tensor_zeros element == 0")

  t_ones = tensor_ones([3, 2])
  ok_o_sz = assert_eq_int(t_ones.size, 6, "tensor_ones([3, 2]) size == 6")
  ok_o_00 = assert_eq_int(tensor_get(t_ones, [1, 1]), 1, "tensor_ones element == 1")

  t_base = tensor_create([1, 2, 3, 4, 5, 6], [2, 3])
  t_reshaped = tensor_reshape(t_base, [3, 2])
  ok_sh0 = assert_eq_int(t_reshaped.shape[0], 3, "Reshaped shape[0] == 3")
  ok_sh1 = assert_eq_int(t_reshaped.shape[1], 2, "Reshaped shape[1] == 2")
  ok_elem = assert_eq_int(tensor_get(t_reshaped, [1, 0]), 3, "Reshaped element [1, 0] == 3")

  @if ok_z_sz == 1 && ok_z_00 == 1 && ok_o_sz == 1 && ok_o_00 == 1 && ok_sh0 == 1 && ok_sh1 == 1 && ok_elem == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Tensor factory functions (zeros, ones) and zero-copy reshape verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 2: Vector dot-product calculation
  @! ----------------------------------------------------------------------------
  println("▶ Test 2: Vector Dot-Product Calculation...")

  @! 2.1 Standard Dot Product: [1, 2, 3, 4] . [5, 6, 7, 8]
  @! WHY: 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
  total_tests = total_tests + 1
  v1 = tensor_create([1, 2, 3, 4], [4])
  v2 = tensor_create([5, 6, 7, 8], [4])
  dot_val = tensor_dot(v1, v2)
  ok_dot1 = assert_eq_int(dot_val, 70, "Vector dot product [1,2,3,4].[5,6,7,8] == 70")
  @if ok_dot1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Standard vector dot-product calculation verified")
  @end

  @! 2.2 Orthogonal Vectors Dot Product: [1, 0, 0] . [0, 1, 0] == 0
  total_tests = total_tests + 1
  v_orth1 = tensor_create([1, 0, 0], [3])
  v_orth2 = tensor_create([0, 1, 0], [3])
  dot_orth = tensor_dot(v_orth1, v_orth2)
  ok_orth = assert_eq_int(dot_orth, 0, "Orthogonal vector dot product == 0")
  @if ok_orth == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Orthogonal vector dot product (zero-energy projection) verified")
  @end

  @! 2.3 Signed Vectors & Vector L2 Norm
  @! Signed dot: [3, 4] . [-2, 5] = 3*(-2) + 4*5 = -6 + 20 = 14
  @! L2 Norm: sqrt(3^2 + 4^2) = sqrt(25) = 5
  total_tests = total_tests + 1
  v_pos = tensor_create([3, 4], [2])
  v_neg = tensor_create([0 - 2, 5], [2])
  dot_signed = tensor_dot(v_pos, v_neg)
  ok_signed = assert_eq_int(dot_signed, 14, "Signed vector dot product == 14")
  
  l2_norm = tensor_norm(v_pos)
  ok_norm = assert_eq_int(l2_norm, 5, "Vector L2 Euclidean norm of [3, 4] == 5")
  @if ok_signed == 1 && ok_norm == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Signed dot product and L2 Euclidean vector norm verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 3: Matrix multiplication (GEMM) with pure Maya loops
  @! ----------------------------------------------------------------------------
  println("▶ Test 3: Matrix Multiplication (GEMM) with Pure Maya Loops...")

  @! 3.1 2x3 Matrix A multiplied by 3x2 Matrix B -> 2x2 Matrix C
  @! A = [[1, 2, 3],
  @!      [4, 5, 6]]
  @! B = [[7, 8],
  @!      [9, 1],
  @!      [2, 3]]
  @! Expected C:
  @! C[0, 0] = 1*7 + 2*9 + 3*2 = 7 + 18 + 6 = 31
  @! C[0, 1] = 1*8 + 2*1 + 3*3 = 8 + 2 + 9  = 19
  @! C[1, 0] = 4*7 + 5*9 + 6*2 = 28 + 45 + 12 = 85
  @! C[1, 1] = 4*8 + 5*1 + 6*3 = 32 + 5 + 18 = 55
  total_tests = total_tests + 1
  mat_a = tensor_create([1, 2, 3, 4, 5, 6], [2, 3])
  mat_b = tensor_create([7, 8, 9, 1, 2, 3], [3, 2])
  
  @! Execution via pure Maya 3-nested loop kernel
  c_pure = tensor_gemm_pure(mat_a, mat_b)
  ok_p_r0c0 = assert_eq_int(tensor_get(c_pure, [0, 0]), 31, "Pure GEMM C[0, 0] == 31")
  ok_p_r0c1 = assert_eq_int(tensor_get(c_pure, [0, 1]), 19, "Pure GEMM C[0, 1] == 19")
  ok_p_r1c0 = assert_eq_int(tensor_get(c_pure, [1, 0]), 85, "Pure GEMM C[1, 0] == 85")
  ok_p_r1c1 = assert_eq_int(tensor_get(c_pure, [1, 1]), 55, "Pure GEMM C[1, 1] == 55")

  @! Execution via standard matmul orchestrator
  c_disp = tensor_matmul(mat_a, mat_b)
  ok_d_r0c0 = assert_eq_int(tensor_get(c_disp, [0, 0]), 31, "Dispatch GEMM C[0, 0] == 31")
  ok_d_r0c1 = assert_eq_int(tensor_get(c_disp, [0, 1]), 19, "Dispatch GEMM C[0, 1] == 19")
  ok_d_r1c0 = assert_eq_int(tensor_get(c_disp, [1, 0]), 85, "Dispatch GEMM C[1, 0] == 85")
  ok_d_r1c1 = assert_eq_int(tensor_get(c_disp, [1, 1]), 55, "Dispatch GEMM C[1, 1] == 55")

  @if ok_p_r0c0 == 1 && ok_p_r0c1 == 1 && ok_p_r1c0 == 1 && ok_p_r1c1 == 1 && ok_d_r0c0 == 1 && ok_d_r0c1 == 1 && ok_d_r1c0 == 1 && ok_d_r1c1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 2D GEMM (2x3 by 3x2) matrix multiplication verified across both kernels")
  @end

  @! 3.2 3x3 Identity Matrix Invariant: A x I_3 == A
  total_tests = total_tests + 1
  mat_x = tensor_create([2, 3, 5, 7, 11, 13, 17, 19, 23], [3, 3])
  mat_i = tensor_create([1, 0, 0, 0, 1, 0, 0, 0, 1], [3, 3])
  c_ident = tensor_gemm_pure(mat_x, mat_i)
  
  ok_id_all = 1
  idx = 0
  @while idx < 9
    @if tensor_get_flat(c_ident, idx) != tensor_get_flat(mat_x, idx)
      ok_id_all = 0
    @end
    idx = idx + 1
  @end
  ok_ident = assert_eq_int(ok_id_all, 1, "Identity multiplication invariant (A x I_3 == A)")
  @if ok_ident == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Identity matrix multiplication invariant verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 4: Activation functions: ReLU and Sigmoid transformation
  @! ----------------------------------------------------------------------------
  println("▶ Test 4: Activation Functions: ReLU and Sigmoid Transformation...")

  @! 4.1 ReLU Activation: x > 0 ? x : 0
  total_tests = total_tests + 1
  t_act_in = tensor_create([0 - 50, 0 - 1, 0, 1, 50, 100], [6])
  t_relu = tensor_relu(t_act_in)
  ok_r0 = assert_eq_int(tensor_get_flat(t_relu, 0), 0, "ReLU(-50) == 0")
  ok_r1 = assert_eq_int(tensor_get_flat(t_relu, 1), 0, "ReLU(-1) == 0")
  ok_r2 = assert_eq_int(tensor_get_flat(t_relu, 2), 0, "ReLU(0) == 0")
  ok_r3 = assert_eq_int(tensor_get_flat(t_relu, 3), 1, "ReLU(1) == 1")
  ok_r4 = assert_eq_int(tensor_get_flat(t_relu, 4), 50, "ReLU(50) == 50")
  ok_r5 = assert_eq_int(tensor_get_flat(t_relu, 5), 100, "ReLU(100) == 100")
  @if ok_r0 == 1 && ok_r1 == 1 && ok_r2 == 1 && ok_r3 == 1 && ok_r4 == 1 && ok_r5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Pure Maya ReLU non-linear activation verified")
  @end

  @! 4.2 Scaled Fixed-Point Sigmoid Activation: 1 / (1 + exp(-x))
  @! Scaled by 1000:
  @! x = 0     -> Sigmoid(0) = 0.5   (scaled 500)
  @! x = +2000 -> Sigmoid(2.0) = 0.880 (scaled ~880)
  @! x = -2000 -> Sigmoid(-2.0) = 0.119 (scaled ~119)
  total_tests = total_tests + 1
  t_sig_in = tensor_create([0, 2000, 0 - 2000], [3])
  t_sig_out = tensor_sigmoid_scaled(t_sig_in)
  
  v_sig_0   = tensor_get_flat(t_sig_out, 0)
  v_sig_pos = tensor_get_flat(t_sig_out, 1)
  v_sig_neg = tensor_get_flat(t_sig_out, 2)
  
  ok_s0   = assert_near_int(v_sig_0, 500, 5, "Sigmoid(0) == 0.5 (scaled 500)")
  ok_spos = assert_near_int(v_sig_pos, 880, 20, "Sigmoid(+2.0) == 0.880 (scaled ~880)")
  ok_sneg = assert_near_int(v_sig_neg, 119, 20, "Sigmoid(-2.0) == 0.119 (scaled ~119)")
  
  @! Monotonicity check: Sigmoid(-2.0) < Sigmoid(0) < Sigmoid(+2.0)
  ok_mono = assert_true(v_sig_neg < v_sig_0 && v_sig_0 < v_sig_pos, "Sigmoid is strictly monotonic")

  @if ok_s0 == 1 && ok_spos == 1 && ok_sneg == 1 && ok_mono == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Scaled fixed-point Sigmoid activation and monotonicity verified")
  @end

  @! 4.3 Floating Scale Sigmoid Transformation: tensor_sigmoid(t, scale)
  total_tests = total_tests + 1
  t_sig_flt = tensor_sigmoid(t_sig_in, 1000.0)
  v_f_0   = tensor_get_flat(t_sig_flt, 0)
  v_f_pos = tensor_get_flat(t_sig_flt, 1)
  v_f_neg = tensor_get_flat(t_sig_flt, 2)

  ok_f0   = assert_near_int(v_f_0, 500, 5, "Floating Sigmoid(0) == 500")
  ok_fpos = assert_true(v_f_pos > 850, "Floating Sigmoid(+2.0) > 850")
  ok_fneg = assert_true(v_f_neg < 150, "Floating Sigmoid(-2.0) < 150")

  @if ok_f0 == 1 && ok_fpos == 1 && ok_fneg == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Floating-point scale Sigmoid transformation verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST SUMMARY
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  @if passed_tests == total_tests
    println(str_concat("🎉 ALL AI TENSOR TESTS PASSED: ", str_concat(to_str(passed_tests), str_concat("/", to_str(total_tests)))))
    println("=================================================================")
    return 0
  @else
    println(str_concat("❌ TESTS FAILED: ", str_concat(to_str(passed_tests), str_concat("/", to_str(total_tests)))))
    println("=================================================================")
    return 1
  @end
@end
