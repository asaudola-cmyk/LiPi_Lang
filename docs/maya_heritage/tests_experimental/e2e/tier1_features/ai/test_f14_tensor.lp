@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: N-D TENSOR ENGINE (F14)
@! File: tests/e2e/tier1_features/ai/test_f14_tensor.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"

@fn run_all_f14_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature 14: N-D Tensor Engine Coverage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! TC-F14-01: Strided Transpose & GEMM Matrix Multiplication
  @! --------------------------------------------------------------------------
  total = total + 1
  a = tensor_new([1, 2, 3, 4, 5, 6], [2, 3])
  a_t = tensor_transpose_2d(a)
  b = tensor_new([2, 0, 1, 2], [2, 2])
  c = tensor_matmul(a_t, b)

  @! Check a_t shape: [3, 2]
  shape_ok = a_t.shape[0] == 3 && a_t.shape[1] == 2
  @! Check c shape: [3, 2]
  gemm_shape_ok = c.shape[0] == 3 && c.shape[1] == 2
  @! Row 0: 1*2 + 4*1 = 6, 1*0 + 4*2 = 8
  @! Row 1: 2*2 + 5*1 = 9, 2*0 + 5*2 = 10
  @! Row 2: 3*2 + 6*1 = 12, 3*0 + 6*2 = 12
  v00 = tensor_get(c, [0, 0])
  v01 = tensor_get(c, [0, 1])
  v10 = tensor_get(c, [1, 0])
  v11 = tensor_get(c, [1, 1])
  v20 = tensor_get(c, [2, 0])
  v21 = tensor_get(c, [2, 1])

  vals_ok = (v00 == 6) && (v01 == 8) && (v10 == 9) && (v11 == 10) && (v20 == 12) && (v21 == 12)

  @if shape_ok != 0 && gemm_shape_ok != 0 && vals_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F14-01: Strided transpose [2,3]->[3,2] & GEMM [3,2]*[2,2]->[3,2]")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F14-01: Strided transpose & GEMM")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F14-02: Multidirectional Broadcasting
  @! --------------------------------------------------------------------------
  total = total + 1
  b_shape = tensor_broadcast_shapes([2, 1, 3], [1, 4, 3])
  b_shape_ok = (b_shape.len() == 3) && (b_shape[0] == 2) && (b_shape[1] == 4) && (b_shape[2] == 3)

  t1 = tensor_new([1, 2, 3, 4, 5, 6], [2, 1, 3])
  t2_data = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]
  t2 = tensor_new(t2_data, [1, 4, 3])
  t_add = tensor_add(t1, t2)

  add_shape_ok = (t_add.shape.len() == 3) && (t_add.shape[0] == 2) && (t_add.shape[1] == 4) && (t_add.shape[2] == 3)
  @! Check t_add at [0, 0, 0] -> 1 + 10 = 11
  @! Check t_add at [1, 3, 2] -> 6 + 120 = 126
  val_000 = tensor_get(t_add, [0, 0, 0])
  val_132 = tensor_get(t_add, [1, 3, 2])

  @if b_shape_ok != 0 && add_shape_ok != 0 && val_000 == 11 && val_132 == 126
    passed = passed + 1
    println("  [PASS] TC-F14-02: Multidirectional broadcast [2,1,3] + [1,4,3] -> [2,4,3]")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F14-02: Multidirectional broadcast")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F14-03: Multi-dimensional Slicing & Reshape
  @! --------------------------------------------------------------------------
  total = total + 1
  m_data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  mat = tensor_new(m_data, [4, 4])
  sliced = tensor_slice(mat, [[1, 3], [1, 3]])
  slice_ok = (sliced.shape[0] == 2) && (sliced.shape[1] == 2)

  s00 = tensor_get(sliced, [0, 0]) @! 6
  s01 = tensor_get(sliced, [0, 1]) @! 7
  s10 = tensor_get(sliced, [1, 0]) @! 10
  s11 = tensor_get(sliced, [1, 1]) @! 11
  s_vals_ok = (s00 == 6) && (s01 == 7) && (s10 == 10) && (s11 == 11)

  reshaped = tensor_reshape(sliced, [1, 4])
  r_shape_ok = (reshaped.shape[0] == 1) && (reshaped.shape[1] == 4)
  r_val3 = tensor_get(reshaped, [0, 3]) @! 11

  @if slice_ok != 0 && s_vals_ok != 0 && r_shape_ok != 0 && r_val3 == 11
    passed = passed + 1
    println("  [PASS] TC-F14-03: Multi-dim slice [4,4]->[2,2] and reshape to [1,4]")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F14-03: Slicing & Reshape")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F14-04: Statistical Reductions (Sum, Mean, Max, Min)
  @! --------------------------------------------------------------------------
  total = total + 1
  r_data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  rt = tensor_new(r_data, [3, 4])

  t_sum = tensor_sum(rt, 1, 1) @! [3, 1] sum across dim 1
  sum_ok = (t_sum.shape[0] == 3) && (t_sum.shape[1] == 1)
  sum_0 = tensor_get(t_sum, [0, 0]) @! 1+2+3+4 = 10
  sum_1 = tensor_get(t_sum, [1, 0]) @! 5+6+7+8 = 26
  sum_2 = tensor_get(t_sum, [2, 0]) @! 9+10+11+12 = 42
  sum_vals_ok = (sum_0 == 10) && (sum_1 == 26) && (sum_2 == 42)

  t_mean = tensor_mean(rt, 1, 0) @! [3] mean across dim 1
  mean_0 = tensor_get(t_mean, [0]) @! 10 / 4 = 2
  mean_1 = tensor_get(t_mean, [1]) @! 26 / 4 = 6
  mean_2 = tensor_get(t_mean, [2]) @! 42 / 4 = 10
  mean_vals_ok = (mean_0 == 2) && (mean_1 == 6) && (mean_2 == 10)

  t_max = tensor_max(rt, 0, 0) @! [4] max across dim 0
  max_0 = tensor_get(t_max, [0]) @! max(1, 5, 9) = 9
  max_3 = tensor_get(t_max, [3]) @! max(4, 8, 12) = 12
  max_vals_ok = (max_0 == 9) && (max_3 == 12)

  t_min = tensor_min(rt, 1, 0) @! [3] min across dim 1
  min_0 = tensor_get(t_min, [0]) @! 1
  min_1 = tensor_get(t_min, [1]) @! 5
  min_2 = tensor_get(t_min, [2]) @! 9
  min_vals_ok = (min_0 == 1) && (min_1 == 5) && (min_2 == 9)

  @if sum_ok != 0 && sum_vals_ok != 0 && mean_vals_ok != 0 && max_vals_ok != 0 && min_vals_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F14-04: Tensor reductions (sum [3,1], mean [3], max [4], min [3])")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F14-04: Statistical reductions")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F14-05: Transcendental Math & Non-Linear Activations
  @! --------------------------------------------------------------------------
  total = total + 1
  act_input = tensor_new([0 - 5, 0, 5, 0 - 2, 8], [5])
  relu_out = tensor_relu(act_input)
  r0 = tensor_get(relu_out, [0]) @! 0
  r1 = tensor_get(relu_out, [1]) @! 0
  r2 = tensor_get(relu_out, [2]) @! 5
  r3 = tensor_get(relu_out, [3]) @! 0
  r4 = tensor_get(relu_out, [4]) @! 8
  relu_ok = (r0 == 0) && (r1 == 0) && (r2 == 5) && (r3 == 0) && (r4 == 8)

  @! Softmax on [100, 200, 300]
  sm_input = tensor_new([100, 200, 300], [3])
  sm_out = tensor_softmax_scaled(sm_input)
  sm_p0 = tensor_get(sm_out, [0])
  sm_p1 = tensor_get(sm_out, [1])
  sm_p2 = tensor_get(sm_out, [2])
  sm_sum = sm_p0 + sm_p1 + sm_p2
  @! Softmax scaled probabilities sum to approximately 1000 and sm_p2 > sm_p1 > sm_p0
  sm_ok = (sm_sum >= 990 && sm_sum <= 1010) && (sm_p2 > sm_p1) && (sm_p1 > sm_p0)

  @! Transcendental math checks
  sq_val = tensor_math_sqrt(16.0)
  sq_ok = (sq_val >= 3.99 && sq_val <= 4.01)

  @if relu_ok != 0 && sm_ok != 0 && sq_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F14-05: Activations (ReLU, Softmax partition sum ~1000, sqrt)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F14-05: Activations & transcendental math")
  @end

  println("=================================================================")
  println("📊 Feature 14 Summary: " + passed.to_str() + "/" + total.to_str() + " tests passed")
  println("=================================================================")

  @if failed > 0
    return 1
  @end
  return 0
@end

@fn main()
  return run_all_f14_tests()
@end
