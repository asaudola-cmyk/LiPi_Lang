@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — CHALLENGER 2
@! Milestone 1: Pure Maya N-Dimensional Tensor Engine & GEMM
@! ============================================================================

import "universe/ai/tensor"

@fn assert_true(cond, test_name)
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@fn assert_eq_i64(actual, expected, test_name)
  @if actual == expected
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_near_f64(actual: f64, expected: f64, tol: f64, test_name)
  diff = actual - expected
  @if diff < 0.0
    diff = 0.0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ", Diff " + diff.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_near_i64(actual: i64, expected: i64, tol: i64, test_name)
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ", Diff " + diff.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! 1. ADVERSARIAL TEST: EXTREME LOGIT MAGNITUDES IN SOFTMAX
@! ============================================================================
@fn test_adv_softmax_extreme_logits() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 1: Extreme Logit Magnitudes in Softmax]")
  println("-----------------------------------------------------------------")

  @! 1.1 Huge difference: [10000, -10000] with scale = 1000.0
  t1 = tensor_new([10000, 0 - 10000], [1, 2])
  sm1 = tensor_softmax(t1, 1000.0)
  assert_near_i64(sm1.data[0], 1000, 1, "Softmax([10^4, -10^4]) -> elem 0 ~= 1000 (~1.0)")
  assert_near_i64(sm1.data[1], 0, 1, "Softmax([10^4, -10^4]) -> elem 1 ~= 0 (~0.0)")

  @! 1.2 Both huge positive: [100000, 100000] with scale = 1000.0
  t2 = tensor_new([100000, 100000], [1, 2])
  sm2 = tensor_softmax(t2, 1000.0)
  assert_eq_i64(sm2.data[0], 500, "Softmax([10^5, 10^5]) -> elem 0 == 500 (0.5)")
  assert_eq_i64(sm2.data[1], 500, "Softmax([10^5, 10^5]) -> elem 1 == 500 (0.5)")

  @! 1.3 Both huge negative: [-100000, -100000] with scale = 1000.0
  t3 = tensor_new([0 - 100000, 0 - 100000], [1, 2])
  sm3 = tensor_softmax(t3, 1000.0)
  assert_eq_i64(sm3.data[0], 500, "Softmax([-10^5, -10^5]) -> elem 0 == 500 (0.5)")
  assert_eq_i64(sm3.data[1], 500, "Softmax([-10^5, -10^5]) -> elem 1 == 500 (0.5)")

  @! 1.4 Wide dynamic range: [10000, 9000, 0, -10000] with scale = 1000.0
  t4 = tensor_new([10000, 9000, 0, 0 - 10000], [1, 4])
  sm4 = tensor_softmax(t4, 1000.0)
  assert_near_i64(sm4.data[0], 731, 2, "Softmax wide spectrum elem 0 ~= 731 (0.731)")
  assert_near_i64(sm4.data[1], 269, 2, "Softmax wide spectrum elem 1 ~= 269 (0.269)")
  assert_eq_i64(sm4.data[2], 0, "Softmax wide spectrum elem 2 == 0")
  assert_eq_i64(sm4.data[3], 0, "Softmax wide spectrum elem 3 == 0")

  @! 1.5 Scaled fixed-point softmax within supported fixed-point domain
  t_scaled = tensor_new([2000, 0], [1, 2])
  sm_scaled = tensor_softmax_scaled(t_scaled)
  assert_near_i64(sm_scaled.data[0], 881, 2, "Softmax_scaled([2000, 0]) -> elem 0 ~= 881 (0.881)")
  assert_near_i64(sm_scaled.data[1], 119, 2, "Softmax_scaled([2000, 0]) -> elem 1 ~= 119 (0.119)")

  t_scaled_sym = tensor_new([500000, 500000], [1, 2])
  sm_scaled_sym = tensor_softmax_scaled(t_scaled_sym)
  assert_eq_i64(sm_scaled_sym.data[0], 500, "Softmax_scaled([5*10^5, 5*10^5]) -> elem 0 == 500 (0.5)")
  assert_eq_i64(sm_scaled_sym.data[1], 500, "Softmax_scaled([5*10^5, 5*10^5]) -> elem 1 == 500 (0.5)")

  @! 1.6 Multidimensional 3D Softmax with extreme logits: [2, 2, 2]
  t_3d = tensor_new([10000, 0 - 10000, 500, 500, 0 - 5000, 0 - 5000, 20000, 20000], [2, 2, 2])
  sm_3d = tensor_softmax(t_3d, 1000.0)
  assert_near_i64(tensor_get(sm_3d, [0, 0, 0]), 1000, 1, "3D Softmax [0,0,0] ~= 1000")
  assert_eq_i64(tensor_get(sm_3d, [0, 0, 1]), 0, "3D Softmax [0,0,1] == 0")
  assert_eq_i64(tensor_get(sm_3d, [0, 1, 0]), 500, "3D Softmax [0,1,0] == 500")
  assert_eq_i64(tensor_get(sm_3d, [0, 1, 1]), 500, "3D Softmax [0,1,1] == 500")
  assert_eq_i64(tensor_get(sm_3d, [1, 0, 0]), 500, "3D Softmax [1,0,0] == 500")
  assert_eq_i64(tensor_get(sm_3d, [1, 1, 1]), 500, "3D Softmax [1,1,1] == 500")

  @! 1.7 Single-element slice softmax: [3, 1]
  t_single = tensor_new([100000, 0 - 50000, 42], [3, 1])
  sm_single = tensor_softmax(t_single, 1000.0)
  assert_eq_i64(tensor_get(sm_single, [0, 0]), 1000, "Single-element softmax [0, 0] == 1000 (1.0)")
  assert_eq_i64(tensor_get(sm_single, [1, 0]), 1000, "Single-element softmax [1, 0] == 1000 (1.0)")
  assert_eq_i64(tensor_get(sm_single, [2, 0]), 1000, "Single-element softmax [2, 0] == 1000 (1.0)")

  return 1
@end

@! ============================================================================
@! 2. ADVERSARIAL TEST: NEAR-ZERO INPUTS FOR SQRT AND LN
@! ============================================================================
@fn test_adv_near_zero_sqrt_ln() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 2: Near-Zero Inputs for sqrt & ln]")
  println("-----------------------------------------------------------------")

  @! 2.1 math_sqrt on near-zero and zero
  assert_near_f64(math_sqrt(0.0), 0.0, 0.0000001, "math_sqrt(0.0) == 0.0")
  assert_near_f64(math_sqrt(0.0001), 0.01, 0.00001, "math_sqrt(1e-4) == 0.01")
  assert_near_f64(math_sqrt(0.000001), 0.001, 0.000001, "math_sqrt(1e-6) == 0.001")
  assert_near_f64(math_sqrt(0.00000001), 0.0001, 0.0000001, "math_sqrt(1e-8) == 1e-4")
  assert_near_f64(math_sqrt(0.0 - 0.00001), 0.0, 0.0000001, "math_sqrt(-1e-5) == 0.0 (bounded)")

  @! 2.2 math_isqrt on boundary integers
  assert_eq_i64(math_isqrt(0), 0, "math_isqrt(0) == 0")
  assert_eq_i64(math_isqrt(0 - 100), 0, "math_isqrt(-100) == 0")
  assert_eq_i64(math_isqrt(1), 1, "math_isqrt(1) == 1")
  assert_eq_i64(math_isqrt(2), 1, "math_isqrt(2) == 1")
  assert_eq_i64(math_isqrt(3), 1, "math_isqrt(3) == 1")
  assert_eq_i64(math_isqrt(4), 2, "math_isqrt(4) == 2")
  assert_eq_i64(math_isqrt(1000000), 1000, "math_isqrt(10^6) == 1000")
  assert_eq_i64(math_isqrt(100000000), 10000, "math_isqrt(10^8) == 10000")

  @! 2.3 math_ln on near-zero and boundaries
  assert_near_f64(math_ln(0.0), 0.0 - 1000000.0, 1.0, "math_ln(0.0) == -1000000 (safe fallback)")
  assert_near_f64(math_ln(0.0 - 10.0), 0.0 - 1000000.0, 1.0, "math_ln(-10.0) == -1000000 (safe fallback)")
  assert_near_f64(math_ln(0.5), 0.0 - 0.69314718, 0.0001, "math_ln(0.5) == -0.693147")
  assert_near_f64(math_ln(0.1), 0.0 - 2.30258509, 0.0001, "math_ln(0.1) == -2.302585")
  assert_near_f64(math_ln(0.01), 0.0 - 4.60517018, 0.0001, "math_ln(0.01) == -4.605170")
  assert_near_f64(math_ln(0.001), 0.0 - 6.90775527, 0.001, "math_ln(0.001) == -6.907755")
  assert_near_f64(math_ln(0.00001), 0.0 - 11.512925, 0.005, "math_ln(1e-5) == -11.5129")

  @! 2.4 math_ln_scaled on near-zero
  assert_eq_i64(math_ln_scaled(0), 0 - 999999, "math_ln_scaled(0) == -999999")
  assert_eq_i64(math_ln_scaled(0 - 500), 0 - 999999, "math_ln_scaled(-500) == -999999")
  assert_near_i64(math_ln_scaled(500), 0 - 693, 5, "math_ln_scaled(500) ~= -693")

  return 1
@end

@! ============================================================================
@! 3. ADVERSARIAL TEST: LARGE INPUTS FOR EXP AND TANH
@! ============================================================================
@fn test_adv_large_exp_tanh() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 3: Large Inputs for exp & tanh]")
  println("-----------------------------------------------------------------")

  @! 3.1 math_exp large positive and negative inputs
  assert_near_f64(math_exp(0.0), 1.0, 0.00001, "math_exp(0.0) == 1.0")
  assert_near_f64(math_exp(5.0), 148.413159, 0.001, "math_exp(5.0) == 148.413")
  assert_near_f64(math_exp(10.0), 22026.46579, 0.1, "math_exp(10.0) == 22026.46")
  assert_near_f64(math_exp(0.0 - 10.0), 0.0000453999, 0.000001, "math_exp(-10.0) ~= 4.54e-5")
  
  @! Extreme bounds clamping
  assert_true(math_exp(800.0) > 1000000000.0, "math_exp(800.0) clamped to exp(700.0) > 1e9 without inf overflow")
  assert_true(math_exp(10000.0) > 1000000000.0, "math_exp(10000.0) clamped without crashing")
  assert_near_f64(math_exp(0.0 - 800.0), 0.0, 0.0000001, "math_exp(-800.0) clamped to 0.0")
  assert_near_f64(math_exp(0.0 - 10000.0), 0.0, 0.0000001, "math_exp(-10000.0) clamped to 0.0")

  @! 3.2 math_tanh large positive and negative inputs
  assert_near_f64(math_tanh(0.0), 0.0, 0.00001, "math_tanh(0.0) == 0.0")
  assert_near_f64(math_tanh(1.0), 0.76159415, 0.0001, "math_tanh(1.0) == 0.76159")
  assert_near_f64(math_tanh(5.0), 0.9999092, 0.0001, "math_tanh(5.0) == 0.99991")
  assert_near_f64(math_tanh(25.0), 1.0, 0.000001, "math_tanh(25.0) == 1.0 (asymptote)")
  assert_near_f64(math_tanh(1000.0), 1.0, 0.000001, "math_tanh(1000.0) == 1.0 (extreme)")
  assert_near_f64(math_tanh(0.0 - 25.0), 0.0 - 1.0, 0.000001, "math_tanh(-25.0) == -1.0 (asymptote)")
  assert_near_f64(math_tanh(0.0 - 1000.0), 0.0 - 1.0, 0.000001, "math_tanh(-1000.0) == -1.0 (extreme)")

  @! 3.3 Scaled versions
  assert_eq_i64(math_tanh_scaled(10000), 999, "math_tanh_scaled(10000) == 999")
  assert_eq_i64(math_tanh_scaled(0 - 10000), 0 - 999, "math_tanh_scaled(-10000) == -999")

  @! 3.4 Tensor Activations under Extreme Magnitudes
  t_ext = tensor_new([1000000, 0 - 1000000], [2])
  relu_ext = tensor_relu(t_ext)
  assert_eq_i64(relu_ext.data[0], 1000000, "ReLU(10^6) == 10^6")
  assert_eq_i64(relu_ext.data[1], 0, "ReLU(-10^6) == 0")

  sig_ext = tensor_sigmoid(t_ext, 1000.0)
  assert_eq_i64(sig_ext.data[0], 1000, "Sigmoid(10^6) == 1000 (1.0)")
  assert_eq_i64(sig_ext.data[1], 0, "Sigmoid(-10^6) == 0 (0.0)")

  gelu_ext = tensor_gelu(t_ext, 1000.0)
  assert_eq_i64(gelu_ext.data[0], 1000000, "GELU(10^6) ~= 10^6")
  assert_eq_i64(gelu_ext.data[1], 0, "GELU(-10^6) == 0")

  return 1
@end

@! ============================================================================
@! 4. ADVERSARIAL TEST: NON-SQUARE GEMM (1 x 128 x 128 x 1)
@! ============================================================================
@fn test_adv_non_square_gemm() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 4: Non-Square GEMM (1x128 x 128x1 & 128x1 x 1x128)]")
  println("-----------------------------------------------------------------")

  @! Construct vector A of shape [1, 128]: all 1s
  a_data = []
  i = 0
  @while i < 128
    a_data = a_data.push(1)
    i = i + 1
  @end
  t_a = tensor_new(a_data, [1, 128])

  @! Construct vector B of shape [128, 1]: values 0..127
  b_data = []
  i = 0
  @while i < 128
    b_data = b_data.push(i)
    i = i + 1
  @end
  t_b = tensor_new(b_data, [128, 1])

  @! 4.1 Inner Product: [1, 128] x [128, 1] -> [1, 1]
  @! Expected: sum_{i=0..127} 1 * i = 127 * 128 / 2 = 8128
  c_inner = tensor_matmul(t_a, t_b)
  assert_eq_i64(c_inner.ndim, 2, "Inner product ndim == 2")
  assert_eq_i64(c_inner.shape[0], 1, "Inner product shape[0] == 1")
  assert_eq_i64(c_inner.shape[1], 1, "Inner product shape[1] == 1")
  assert_eq_i64(tensor_get(c_inner, [0, 0]), 8128, "Inner product C[0, 0] == 8128 (sum 0..127)")

  @! 4.2 Outer Product: [128, 1] x [1, 128] -> [128, 128]
  @! Expected: D[i, j] = B[i, 0] * A[0, j] = i * 1 = i
  d_outer = tensor_matmul(t_b, t_a)
  assert_eq_i64(d_outer.ndim, 2, "Outer product ndim == 2")
  assert_eq_i64(d_outer.shape[0], 128, "Outer product shape[0] == 128")
  assert_eq_i64(d_outer.shape[1], 128, "Outer product shape[1] == 128")
  assert_eq_i64(d_outer.size, 16384, "Outer product size == 16384")
  assert_eq_i64(tensor_get(d_outer, [0, 0]), 0, "Outer product D[0, 0] == 0")
  assert_eq_i64(tensor_get(d_outer, [10, 50]), 10, "Outer product D[10, 50] == 10")
  assert_eq_i64(tensor_get(d_outer, [64, 100]), 64, "Outer product D[64, 100] == 64")
  assert_eq_i64(tensor_get(d_outer, [127, 127]), 127, "Outer product D[127, 127] == 127")

  @! 4.3 Non-square GEMM with Transposed/Sliced Views
  t_b_trans = tensor_transpose(t_b, 0, 1)
  assert_eq_i64(t_b_trans.shape[0], 1, "t_b_trans shape[0] == 1")
  assert_eq_i64(t_b_trans.shape[1], 128, "t_b_trans shape[1] == 128")
  c_trans_inner = tensor_matmul(t_b_trans, t_b)
  @! Sum of squares: sum_{i=0..127} i^2 = 127 * 128 * 255 / 6 = 690880
  assert_eq_i64(tensor_get(c_trans_inner, [0, 0]), 690880, "Transposed view GEMM sum of squares == 690880")

  @! 4.4 Highly Rectangular GEMM: [2, 512] x [512, 3] -> [2, 3]
  t_rect_a = tensor_ones([2, 512])
  t_rect_b = tensor_full([512, 3], 2)
  c_rect = tensor_matmul(t_rect_a, t_rect_b)
  assert_eq_i64(c_rect.shape[0], 2, "Rectangular shape[0] == 2")
  assert_eq_i64(c_rect.shape[1], 3, "Rectangular shape[1] == 3")
  assert_eq_i64(tensor_get(c_rect, [0, 0]), 1024, "Rectangular C[0, 0] == 1024 (512 * 1 * 2)")
  assert_eq_i64(tensor_get(c_rect, [1, 2]), 1024, "Rectangular C[1, 2] == 1024")

  return 1
@end

@! ============================================================================
@! 5. ADVERSARIAL TEST: ODD RANK BATCHED GEMM ([3, 2, 5, 4] x [3, 2, 4, 6])
@! ============================================================================
@fn test_adv_odd_rank_batched_gemm() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 5: Odd & High-Rank Batched GEMM]")
  println("-----------------------------------------------------------------")

  @! 5.1 4D Batched GEMM: [3, 2, 5, 4] x [3, 2, 4, 6] -> [3, 2, 5, 6]
  a_4d_data = []
  b0 = 0
  @while b0 < 3
    b1 = 0
    @while b1 < 2
      i = 0
      @while i < 5
        k = 0
        @while k < 4
          a_4d_data = a_4d_data.push(b0 + 1)
          k = k + 1
        @end
        i = i + 1
      @end
      b1 = b1 + 1
    @end
    b0 = b0 + 1
  @end
  t_a_4d = tensor_new(a_4d_data, [3, 2, 5, 4])

  b_4d_data = []
  b0 = 0
  @while b0 < 3
    b1 = 0
    @while b1 < 2
      k = 0
      @while k < 4
        j = 0
        @while j < 6
          b_4d_data = b_4d_data.push(b1 + 1)
          j = j + 1
        @end
        k = k + 1
      @end
      b1 = b1 + 1
    @end
    b0 = b0 + 1
  @end
  t_b_4d = tensor_new(b_4d_data, [3, 2, 4, 6])

  c_4d = tensor_matmul(t_a_4d, t_b_4d)
  assert_eq_i64(c_4d.ndim, 4, "4D Batched GEMM ndim == 4")
  assert_eq_i64(c_4d.shape[0], 3, "4D Batched GEMM shape[0] == 3")
  assert_eq_i64(c_4d.shape[1], 2, "4D Batched GEMM shape[1] == 2")
  assert_eq_i64(c_4d.shape[2], 5, "4D Batched GEMM shape[2] == 5")
  assert_eq_i64(c_4d.shape[3], 6, "4D Batched GEMM shape[3] == 6")
  assert_eq_i64(c_4d.size, 180, "4D Batched GEMM size == 180")

  @! Verify elements at all batch coordinates:
  @! b0=0, b1=0 -> 4 * 1 * 1 = 4
  assert_eq_i64(tensor_get(c_4d, [0, 0, 0, 0]), 4, "Batch [0, 0] elem == 4")
  assert_eq_i64(tensor_get(c_4d, [0, 0, 4, 5]), 4, "Batch [0, 0] elem [4,5] == 4")
  @! b0=0, b1=1 -> 4 * 1 * 2 = 8
  assert_eq_i64(tensor_get(c_4d, [0, 1, 2, 3]), 8, "Batch [0, 1] elem == 8")
  @! b0=1, b1=0 -> 4 * 2 * 1 = 8
  assert_eq_i64(tensor_get(c_4d, [1, 0, 1, 1]), 8, "Batch [1, 0] elem == 8")
  @! b0=2, b1=1 -> 4 * 3 * 2 = 24
  assert_eq_i64(tensor_get(c_4d, [2, 1, 3, 2]), 24, "Batch [2, 1] elem == 24")

  @! 5.2 3D Batched GEMM (Rank 3): [3, 5, 4] x [3, 4, 6] -> [3, 5, 6]
  t_a_3d = tensor_ones([3, 5, 4])
  t_b_3d = tensor_full([3, 4, 6], 2)
  c_3d = tensor_matmul(t_a_3d, t_b_3d)
  assert_eq_i64(c_3d.ndim, 3, "3D Batched GEMM ndim == 3")
  assert_eq_i64(c_3d.shape[0], 3, "3D Batched GEMM shape[0] == 3")
  assert_eq_i64(c_3d.shape[1], 5, "3D Batched GEMM shape[1] == 5")
  assert_eq_i64(c_3d.shape[2], 6, "3D Batched GEMM shape[2] == 6")
  assert_eq_i64(tensor_get(c_3d, [1, 2, 3]), 8, "3D Batched GEMM elem == 8 (4 * 1 * 2)")

  @! 5.3 5D Batched GEMM (Rank 5 with batch broadcasting): [2, 1, 3, 4, 2] x [2, 2, 3, 2, 5] -> [2, 2, 3, 4, 5]
  t_a_5d = tensor_ones([2, 1, 3, 4, 2])
  t_b_5d = tensor_full([2, 2, 3, 2, 5], 3)
  c_5d = tensor_matmul(t_a_5d, t_b_5d)
  assert_eq_i64(c_5d.ndim, 5, "5D Batched GEMM ndim == 5")
  assert_eq_i64(c_5d.shape[0], 2, "5D Batched GEMM shape[0] == 2")
  assert_eq_i64(c_5d.shape[1], 2, "5D Batched GEMM shape[1] == 2")
  assert_eq_i64(c_5d.shape[2], 3, "5D Batched GEMM shape[2] == 3")
  assert_eq_i64(c_5d.shape[3], 4, "5D Batched GEMM shape[3] == 4")
  assert_eq_i64(c_5d.shape[4], 5, "5D Batched GEMM shape[4] == 5")
  assert_eq_i64(tensor_get(c_5d, [1, 1, 2, 3, 4]), 6, "5D Batched GEMM elem == 6 (2 * 1 * 3)")

  @! 5.4 Batched GEMM with 2D Broadcast: [3, 4, 2] x [2, 5] -> [3, 4, 5]
  t_batch_3d = tensor_ones([3, 4, 2])
  t_mat_2d = tensor_full([2, 5], 4)
  c_bcast_2d = tensor_matmul(t_batch_3d, t_mat_2d)
  assert_eq_i64(c_bcast_2d.ndim, 3, "Broadcast GEMM ndim == 3")
  assert_eq_i64(c_bcast_2d.shape[0], 3, "Broadcast GEMM shape[0] == 3")
  assert_eq_i64(c_bcast_2d.shape[1], 4, "Broadcast GEMM shape[1] == 4")
  assert_eq_i64(c_bcast_2d.shape[2], 5, "Broadcast GEMM shape[2] == 5")
  assert_eq_i64(tensor_get(c_bcast_2d, [2, 3, 4]), 8, "Broadcast GEMM elem == 8 (2 * 1 * 4)")

  return 1
@end

@! ============================================================================
@! 6. ADVERSARIAL TEST: REDUCTION ACROSS VARIOUS DIMENSIONS
@! ============================================================================
@fn test_adv_reductions_multidim() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADV 6: Reductions Across Various Dimensions & Keepdim Modes]")
  println("-----------------------------------------------------------------")

  @! Create 4D Tensor: shape [2, 3, 4, 5], values = 0..119
  t_data = []
  i = 0
  @while i < 120
    t_data = t_data.push(i)
    i = i + 1
  @end
  t = tensor_new(t_data, [2, 3, 4, 5])
  assert_eq_i64(t.size, 120, "Tensor size == 120")

  @! 6.1 Global Reductions (dim = -1)
  @! Sum: sum_{i=0..119} i = 119 * 120 / 2 = 7140
  sum_global = tensor_sum(t, 0 - 1, 0)
  assert_eq_i64(sum_global.size, 1, "Global sum size == 1")
  assert_eq_i64(sum_global.ndim, 1, "Global sum ndim == 1 (keepdim=0)")
  assert_eq_i64(tensor_get_flat(sum_global, 0), 7140, "Global sum == 7140")

  sum_global_kd = tensor_sum(t, 0 - 1, 1)
  assert_eq_i64(sum_global_kd.ndim, 4, "Global sum keepdim=1 ndim == 4")
  assert_eq_i64(sum_global_kd.shape[0], 1, "shape[0] == 1")
  assert_eq_i64(sum_global_kd.shape[1], 1, "shape[1] == 1")
  assert_eq_i64(sum_global_kd.shape[2], 1, "shape[2] == 1")
  assert_eq_i64(sum_global_kd.shape[3], 1, "shape[3] == 1")
  assert_eq_i64(tensor_get(sum_global_kd, [0, 0, 0, 0]), 7140, "Global sum kd == 7140")

  @! Global Mean: 7140 / 120 = 59
  mean_global = tensor_mean(t, 0 - 1, 0)
  assert_eq_i64(tensor_get_flat(mean_global, 0), 59, "Global mean == 59")

  @! Global Max: 119, Min: 0
  max_global = tensor_max(t, 0 - 1, 0)
  assert_eq_i64(tensor_get_flat(max_global, 0), 119, "Global max == 119")
  min_global = tensor_min(t, 0 - 1, 0)
  assert_eq_i64(tensor_get_flat(min_global, 0), 0, "Global min == 0")

  @! 6.2 Reduction Along Axis 0 (dim = 0): [2, 3, 4, 5] -> [3, 4, 5]
  sum_d0 = tensor_sum(t, 0, 0)
  assert_eq_i64(sum_d0.ndim, 3, "dim 0 sum ndim == 3")
  assert_eq_i64(sum_d0.shape[0], 3, "dim 0 sum shape[0] == 3")
  assert_eq_i64(sum_d0.shape[1], 4, "dim 0 sum shape[1] == 4")
  assert_eq_i64(sum_d0.shape[2], 5, "dim 0 sum shape[2] == 5")
  assert_eq_i64(tensor_get(sum_d0, [0, 0, 0]), 60, "sum_d0[0,0,0] == 0 + 60 = 60")
  assert_eq_i64(tensor_get(sum_d0, [2, 3, 4]), 178, "sum_d0[2,3,4] == 59 + 119 = 178")

  @! Reduction Along Axis 0 with keepdim = 1 -> [1, 3, 4, 5]
  sum_d0_kd = tensor_sum(t, 0, 1)
  assert_eq_i64(sum_d0_kd.ndim, 4, "dim 0 sum kd ndim == 4")
  assert_eq_i64(sum_d0_kd.shape[0], 1, "dim 0 sum kd shape[0] == 1")
  assert_eq_i64(sum_d0_kd.shape[1], 3, "dim 0 sum kd shape[1] == 3")
  assert_eq_i64(tensor_get(sum_d0_kd, [0, 0, 0, 0]), 60, "sum_d0_kd[0,0,0,0] == 60")

  @! 6.3 Reduction Along Axis 1 (dim = 1): [2, 3, 4, 5] -> [2, 4, 5]
  sum_d1 = tensor_sum(t, 1, 0)
  assert_eq_i64(sum_d1.ndim, 3, "dim 1 sum ndim == 3")
  assert_eq_i64(sum_d1.shape[0], 2, "dim 1 sum shape[0] == 2")
  assert_eq_i64(sum_d1.shape[1], 4, "dim 1 sum shape[1] == 4")
  assert_eq_i64(sum_d1.shape[2], 5, "dim 1 sum shape[2] == 5")
  assert_eq_i64(tensor_get(sum_d1, [0, 0, 0]), 60, "sum_d1[0,0,0] == 60")

  @! 6.4 Reduction Along Axis 2 (dim = 2): [2, 3, 4, 5] -> [2, 3, 5]
  sum_d2 = tensor_sum(t, 2, 0)
  assert_eq_i64(sum_d2.ndim, 3, "dim 2 sum ndim == 3")
  assert_eq_i64(sum_d2.shape[0], 2, "dim 2 sum shape[0] == 2")
  assert_eq_i64(sum_d2.shape[1], 3, "dim 2 sum shape[1] == 3")
  assert_eq_i64(sum_d2.shape[2], 5, "dim 2 sum shape[2] == 5")
  assert_eq_i64(tensor_get(sum_d2, [0, 0, 0]), 30, "sum_d2[0,0,0] == 30")

  @! 6.5 Reduction Along Axis 3 (dim = 3, innermost): [2, 3, 4, 5] -> [2, 3, 4]
  sum_d3 = tensor_sum(t, 3, 0)
  assert_eq_i64(sum_d3.ndim, 3, "dim 3 sum ndim == 3")
  assert_eq_i64(sum_d3.shape[0], 2, "dim 3 sum shape[0] == 2")
  assert_eq_i64(sum_d3.shape[1], 3, "dim 3 sum shape[1] == 3")
  assert_eq_i64(sum_d3.shape[2], 4, "dim 3 sum shape[2] == 4")
  assert_eq_i64(tensor_get(sum_d3, [0, 0, 0]), 10, "sum_d3[0,0,0] == 10 (0+1+2+3+4)")
  assert_eq_i64(tensor_get(sum_d3, [1, 2, 3]), 585, "sum_d3[1,2,3] == 585 (115+116+117+118+119)")

  @! 6.6 Max and Min Along Dim 2: [2, 3, 4, 5] -> [2, 3, 5]
  max_d2 = tensor_max(t, 2, 0)
  min_d2 = tensor_min(t, 2, 0)
  assert_eq_i64(tensor_get(max_d2, [0, 0, 0]), 15, "max_d2[0,0,0] == 15")
  assert_eq_i64(tensor_get(min_d2, [0, 0, 0]), 0, "min_d2[0,0,0] == 0")

  @! 6.7 Reductions on Non-Contiguous Strided Slice
  t_slice = tensor_slice(t, [[0, 2, 1], [0, 3, 1], [0, 4, 2], [0, 5, 2]])
  assert_eq_i64(t_slice.is_contiguous, 0, "t_slice.is_contiguous == 0")
  assert_eq_i64(t_slice.shape[0], 2, "slice shape[0] == 2")
  assert_eq_i64(t_slice.shape[1], 3, "slice shape[1] == 3")
  assert_eq_i64(t_slice.shape[2], 2, "slice shape[2] == 2")
  assert_eq_i64(t_slice.shape[3], 3, "slice shape[3] == 3")
  sum_slice_global = tensor_sum(t_slice, 0 - 1, 0)
  slice_expected_sum = 0
  s0 = 0
  @while s0 < 2
    s1 = 0
    @while s1 < 3
      s2 = 0
      @while s2 < 2
        s3 = 0
        @while s3 < 3
          slice_expected_sum = slice_expected_sum + tensor_get(t_slice, [s0, s1, s2, s3])
          s3 = s3 + 1
        @end
        s2 = s2 + 1
      @end
      s1 = s1 + 1
    @end
    s0 = s0 + 1
  @end
  assert_eq_i64(tensor_get_flat(sum_slice_global, 0), slice_expected_sum, "Non-contiguous slice global sum verified")

  return 1
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================
@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST SUITE — CHALLENGER 2")
  println("=================================================================")

  test_adv_softmax_extreme_logits()
  test_adv_near_zero_sqrt_ln()
  test_adv_large_exp_tanh()
  test_adv_non_square_gemm()
  test_adv_odd_rank_batched_gemm()
  test_adv_reductions_multidim()

  println("=================================================================")
  println("🏆 ALL ADVERSARIAL CHALLENGER TESTS PASSED SUCCESSFULLY! 🏆")
  println("=================================================================")
  return 0
@end
