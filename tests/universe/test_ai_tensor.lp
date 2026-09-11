@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — TENSOR CORE & STRIDED ENGINE (Tiers 1-4 & Adversarial)
@! 100% Pure Maya Implementation — Zero Mock Logic
@! ============================================================================

import "universe/ai/tensor"

@! ----------------------------------------------------------------------------
@! 0. Test Assertions Framework
@! ----------------------------------------------------------------------------

@fn assert_true(cond: i64, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_near_int(actual: i64, expected: i64, tol: i64, test_name: string) -> i64
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

@fn assert_near_f64(actual: f64, expected: f64, tol: f64, test_name: string) -> i64
  diff = actual - expected
  @if diff < 0.0
    diff = 0.0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! 1. TIER 1: Core Functional & Representation Tests
@! ============================================================================

@fn run_tier1_core_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1: Core Functional & Representation Tests]")
  println("-----------------------------------------------------------------")
  
  @! 1.1 Transcendental Math Helpers
  assert_eq_int(math_isqrt(100), 10, "math_isqrt(100) == 10")
  assert_eq_int(math_isqrt(2), 1, "math_isqrt(2) == 1")
  assert_eq_int(math_isqrt(144), 12, "math_isqrt(144) == 12")
  assert_near_int(math_exp_scaled(0), 1000, 5, "math_exp(0) == 1.0 (scaled)")
  assert_near_int(math_exp_scaled(1000), 2718, 20, "math_exp(1.0) == 2.718 (scaled)")
  assert_near_int(math_ln_scaled(1000), 0, 10, "math_ln(1.0) == 0.0 (scaled)")
  assert_near_int(math_ln_scaled(2718), 1000, 20, "math_ln(e) == 1.0 (scaled)")
  assert_near_int(math_tanh_scaled(0), 0, 5, "math_tanh(0) == 0.0 (scaled)")
  assert_near_int(math_tanh_scaled(1000), 761, 15, "math_tanh(1.0) == 0.761 (scaled)")

  assert_near_f64(tensor_math_sqrt(4.0), 2.0, 0.000001, "tensor_math_sqrt(4.0) == 2.0")
  assert_near_f64(math_exp(0.0), 1.0, 0.000001, "math_exp(0.0) == 1.0")
  assert_near_f64(math_ln(1.0), 0.0, 0.000001, "math_ln(1.0) == 0.0")
  assert_near_f64(math_tanh(0.0), 0.0, 0.000001, "math_tanh(0.0) == 0.0")

  @! 1.2 Tensor Creation & Strides
  t_1d = tensor_create([10, 20, 30, 40, 50], [5])
  assert_eq_int(t_1d.ndim, 1, "1D Tensor ndim == 1")
  assert_eq_int(t_1d.size, 5, "1D Tensor size == 5")
  assert_eq_int(t_1d.strides[0], 1, "1D Tensor strides == [1]")
  assert_eq_int(t_1d.is_contiguous, 1, "1D Tensor is_contiguous == 1")
  
  t_2d = tensor_create([1, 2, 3, 4, 5, 6], [2, 3])
  assert_eq_int(t_2d.ndim, 2, "2D Tensor ndim == 2")
  assert_eq_int(t_2d.size, 6, "2D Tensor size == 6")
  assert_eq_int(t_2d.strides[0], 3, "2D Tensor strides[0] == 3")
  assert_eq_int(t_2d.strides[1], 1, "2D Tensor strides[1] == 1")
  assert_eq_int(t_2d.is_contiguous, 1, "2D Tensor is_contiguous == 1")

  t_3d = tensor_create([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], [2, 3, 4])
  assert_eq_int(t_3d.ndim, 3, "3D Tensor ndim == 3")
  assert_eq_int(t_3d.strides[0], 12, "3D Tensor strides[0] == 12")
  assert_eq_int(t_3d.strides[1], 4, "3D Tensor strides[1] == 4")
  assert_eq_int(t_3d.strides[2], 1, "3D Tensor strides[2] == 1")
  assert_eq_int(t_3d.is_contiguous, 1, "3D Tensor is_contiguous == 1")

  @! 1.3 Strided Memory Indexing (Get & Set)
  val_01 = tensor_get(t_2d, [0, 1])
  assert_eq_int(val_01, 2, "tensor_get(t_2d, [0, 1]) == 2")
  val_12 = tensor_get(t_2d, [1, 2])
  assert_eq_int(val_12, 6, "tensor_get(t_2d, [1, 2]) == 6")
  
  t_2d = tensor_set(t_2d, [1, 1], 99)
  val_11_mut = tensor_get(t_2d, [1, 1])
  assert_eq_int(val_11_mut, 99, "tensor_set and get mutation verified")

  @! 1.4 Elementwise Arithmetic
  a = tensor_create([10, 20, 30], [3])
  b = tensor_create([1, 2, 3], [3])
  sum_t = tensor_add(a, b)
  assert_eq_int(tensor_get_flat(sum_t, 0), 11, "tensor_add elem 0 == 11")
  assert_eq_int(tensor_get_flat(sum_t, 1), 22, "tensor_add elem 1 == 22")
  assert_eq_int(tensor_get_flat(sum_t, 2), 33, "tensor_add elem 2 == 33")

  sub_t = tensor_sub(a, b)
  assert_eq_int(tensor_get_flat(sub_t, 0), 9, "tensor_sub elem 0 == 9")
  assert_eq_int(tensor_get_flat(sub_t, 1), 18, "tensor_sub elem 1 == 18")
  assert_eq_int(tensor_get_flat(sub_t, 2), 27, "tensor_sub elem 2 == 27")

  mul_t = tensor_mul(a, b)
  assert_eq_int(tensor_get_flat(mul_t, 0), 10, "tensor_mul elem 0 == 10")
  assert_eq_int(tensor_get_flat(mul_t, 1), 40, "tensor_mul elem 1 == 40")
  assert_eq_int(tensor_get_flat(mul_t, 2), 90, "tensor_mul elem 2 == 90")

  div_t = tensor_div(a, b)
  assert_eq_int(tensor_get_flat(div_t, 0), 10, "tensor_div elem 0 == 10")
  assert_eq_int(tensor_get_flat(div_t, 1), 10, "tensor_div elem 1 == 10")
  assert_eq_int(tensor_get_flat(div_t, 2), 10, "tensor_div elem 2 == 10")

  neg_t = tensor_neg(b)
  assert_eq_int(tensor_get_flat(neg_t, 0), 0 - 1, "tensor_neg elem 0 == -1")

  scale_t = tensor_scale(b, 5)
  assert_eq_int(tensor_get_flat(scale_t, 1), 10, "tensor_scale elem 1 == 10")

  @! 1.5 Reductions
  data_red = tensor_create([2, 4, 4, 4, 5, 5, 7, 9], [8])
  sum_res = tensor_sum(data_red, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(sum_res, 0), 40, "tensor_sum == 40")
  mean_res = tensor_mean(data_red, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(mean_res, 0), 5, "tensor_mean == 5")
  max_res = tensor_max(data_red, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(max_res, 0), 9, "tensor_max == 9")
  min_res = tensor_min(data_red, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(min_res, 0), 2, "tensor_min == 2")
  var_res = tensor_var(data_red, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(var_res, 0), 4, "tensor_variance == 4")
  return 1
@end

@! ============================================================================
@! 2. TIER 2: Boundary Conditions, Strides & Zero-Copy Views
@! ============================================================================

@fn run_tier2_boundary_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2: Boundary Conditions, Strides & Zero-Copy Views]")
  println("-----------------------------------------------------------------")

  @! 2.1 Zero-Copy Reshaping
  t_orig = tensor_create([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [3, 4])
  t_reshaped = tensor_reshape(t_orig, [2, 6])
  assert_eq_int(t_reshaped.ndim, 2, "Reshape to [2, 6] ndim == 2")
  assert_eq_int(t_reshaped.shape[0], 2, "Reshape shape[0] == 2")
  assert_eq_int(t_reshaped.shape[1], 6, "Reshape shape[1] == 6")
  assert_eq_int(t_reshaped.strides[0], 6, "Reshape strides[0] == 6")
  assert_eq_int(t_reshaped.strides[1], 1, "Reshape strides[1] == 1")
  assert_eq_int(tensor_get(t_reshaped, [1, 0]), 7, "Reshape element access [1, 0] == 7")

  @! 2.2 Zero-Copy 2D Transposition
  t_mat = tensor_create([10, 20, 30, 40, 50, 60], [2, 3])
  t_trans = tensor_transpose_2d(t_mat)
  assert_eq_int(t_trans.shape[0], 3, "Transpose shape[0] == 3")
  assert_eq_int(t_trans.shape[1], 2, "Transpose shape[1] == 2")
  assert_eq_int(t_trans.strides[0], 1, "Transpose strides[0] == 1")
  assert_eq_int(t_trans.strides[1], 3, "Transpose strides[1] == 3")
  assert_eq_int(t_trans.is_contiguous, 0, "Transpose is_contiguous == 0")
  assert_eq_int(tensor_get(t_trans, [0, 1]), 40, "Transpose element [0, 1] == 40")
  assert_eq_int(tensor_get(t_trans, [2, 0]), 30, "Transpose element [2, 0] == 30")

  @! 2.3 N-D Permute
  t_3d = tensor_create([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], [2, 3, 4])
  t_perm = tensor_permute(t_3d, [2, 0, 1])
  assert_eq_int(t_perm.shape[0], 4, "Permute [2, 0, 1] shape[0] == 4")
  assert_eq_int(t_perm.shape[1], 2, "Permute [2, 0, 1] shape[1] == 2")
  assert_eq_int(t_perm.shape[2], 3, "Permute [2, 0, 1] shape[2] == 3")
  assert_eq_int(t_perm.strides[0], 1, "Permute strides[0] == 1")
  assert_eq_int(t_perm.strides[1], 12, "Permute strides[1] == 12")
  assert_eq_int(t_perm.strides[2], 4, "Permute strides[2] == 4")

  @! 2.4 Multi-dimensional Slicing
  @! 4x4 matrix:
  @! [ 0,  1,  2,  3]
  @! [ 4,  5,  6,  7]
  @! [ 8,  9, 10, 11]
  @! [12, 13, 14, 15]
  data_4x4 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  t_4x4 = tensor_create(data_4x4, [4, 4])
  @! Slice rows [1..3] step 1, cols [0..4] step 2
  sliced = tensor_slice(t_4x4, [[1, 3, 1], [0, 4, 2]])
  assert_eq_int(sliced.shape[0], 2, "Sliced rows shape[0] == 2")
  assert_eq_int(sliced.shape[1], 2, "Sliced cols shape[1] == 2")
  assert_eq_int(tensor_get(sliced, [0, 0]), 4, "Sliced [0, 0] == 4")
  assert_eq_int(tensor_get(sliced, [0, 1]), 6, "Sliced [0, 1] == 6")
  assert_eq_int(tensor_get(sliced, [1, 0]), 8, "Sliced [1, 0] == 8")
  assert_eq_int(tensor_get(sliced, [1, 1]), 10, "Sliced [1, 1] == 10")

  @! 2.5 Contiguous Materialization
  contig = tensor_contiguous(sliced)
  assert_eq_int(contig.is_contiguous, 1, "tensor_contiguous is_contiguous == 1")
  assert_eq_int(contig.data.len(), 4, "tensor_contiguous compact data len == 4")
  assert_eq_int(tensor_get_flat(contig, 0), 4, "Contig data[0] == 4")
  assert_eq_int(tensor_get_flat(contig, 3), 10, "Contig data[3] == 10")

  @! 2.6 Multidirectional Broadcasting
  t_row = tensor_create([10, 20, 30], [1, 3])
  bcast_t = tensor_broadcast_to(t_row, [4, 3])
  assert_eq_int(bcast_t.shape[0], 4, "Broadcast shape[0] == 4")
  assert_eq_int(bcast_t.shape[1], 3, "Broadcast shape[1] == 3")
  assert_eq_int(bcast_t.strides[0], 0, "Broadcast stride[0] == 0 (expanded)")
  assert_eq_int(bcast_t.strides[1], 1, "Broadcast stride[1] == 1")
  assert_eq_int(tensor_get(bcast_t, [0, 1]), 20, "Broadcast [0, 1] == 20")
  assert_eq_int(tensor_get(bcast_t, [3, 1]), 20, "Broadcast [3, 1] == 20")
  return 1
@end

@! ============================================================================
@! 3. TIER 3: Pairwise Combinations & Matrix Computations
@! ============================================================================

@fn run_tier3_combination_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3: Pairwise Combinations & Matrix Computations]")
  println("-----------------------------------------------------------------")

  @! 3.1 2D GEMM: [2, 3] x [3, 2] -> [2, 2]
  @! A = [[1, 2, 3], [4, 5, 6]]
  @! B = [[7, 8], [9, 1], [2, 3]]
  @! Expected C = [[31, 19], [85, 55]]
  a_gemm = tensor_create([1, 2, 3, 4, 5, 6], [2, 3])
  b_gemm = tensor_create([7, 8, 9, 1, 2, 3], [3, 2])
  c_gemm = tensor_gemm_2d(a_gemm, b_gemm)
  assert_eq_int(c_gemm.shape[0], 2, "GEMM 2D shape[0] == 2")
  assert_eq_int(c_gemm.shape[1], 2, "GEMM 2D shape[1] == 2")
  assert_eq_int(tensor_get(c_gemm, [0, 0]), 31, "GEMM C[0, 0] == 31")
  assert_eq_int(tensor_get(c_gemm, [0, 1]), 19, "GEMM C[0, 1] == 19")
  assert_eq_int(tensor_get(c_gemm, [1, 0]), 85, "GEMM C[1, 0] == 85")
  assert_eq_int(tensor_get(c_gemm, [1, 1]), 55, "GEMM C[1, 1] == 55")

  @! 3.2 Batched GEMM: [2, 2, 2] x [2, 2, 2] -> [2, 2, 2]
  @! Batch 0: [[1, 0], [0, 1]] x [[5, 6], [7, 8]] = [[5, 6], [7, 8]] (Identity)
  @! Batch 1: [[2, 0], [0, 2]] x [[5, 6], [7, 8]] = [[10, 12], [14, 16]] (Scale x2)
  batch_a = tensor_create([1, 0, 0, 1, 2, 0, 0, 2], [2, 2, 2])
  batch_b = tensor_create([5, 6, 7, 8, 5, 6, 7, 8], [2, 2, 2])
  batch_c = tensor_batched_gemm(batch_a, batch_b)
  assert_eq_int(batch_c.shape[0], 2, "Batched GEMM batch == 2")
  assert_eq_int(batch_c.shape[1], 2, "Batched GEMM rows == 2")
  assert_eq_int(batch_c.shape[2], 2, "Batched GEMM cols == 2")
  assert_eq_int(tensor_get(batch_c, [0, 0, 0]), 5, "Batch 0 C[0, 0] == 5")
  assert_eq_int(tensor_get(batch_c, [0, 1, 1]), 8, "Batch 0 C[1, 1] == 8")
  assert_eq_int(tensor_get(batch_c, [1, 0, 0]), 10, "Batch 1 C[0, 0] == 10")
  assert_eq_int(tensor_get(batch_c, [1, 1, 1]), 16, "Batch 1 C[1, 1] == 16")

  @! 3.3 Activations
  t_act = tensor_create([0 - 50, 0, 50, 100], [4])
  relu_out = tensor_relu(t_act)
  assert_eq_int(tensor_get_flat(relu_out, 0), 0, "ReLU(-50) == 0")
  assert_eq_int(tensor_get_flat(relu_out, 1), 0, "ReLU(0) == 0")
  assert_eq_int(tensor_get_flat(relu_out, 2), 50, "ReLU(50) == 50")
  assert_eq_int(tensor_get_flat(relu_out, 3), 100, "ReLU(100) == 100")

  sig_input = tensor_create([0, 2000, 0 - 2000], [3])
  sig_out = tensor_sigmoid_scaled(sig_input)
  assert_near_int(tensor_get_flat(sig_out, 0), 500, 5, "Sigmoid(0) == 0.5 (scaled 500)")
  assert_near_int(tensor_get_flat(sig_out, 1), 880, 20, "Sigmoid(2.0) == 0.880 (scaled 880)")
  assert_near_int(tensor_get_flat(sig_out, 2), 119, 20, "Sigmoid(-2.0) == 0.119 (scaled 119)")

  gelu_input = tensor_create([0, 1000, 0 - 1000], [3])
  gelu_out = tensor_gelu_scaled(gelu_input)
  assert_near_int(tensor_get_flat(gelu_out, 0), 0, 5, "GELU(0) == 0 (scaled)")
  assert_near_int(tensor_get_flat(gelu_out, 1), 841, 30, "GELU(1.0) == 0.841 (scaled 841)")

  sm_input = tensor_create([1000, 2000, 3000, 1000, 1000, 1000], [2, 3])
  sm_out = tensor_softmax_scaled(sm_input)
  sum_row0 = tensor_get_flat(sm_out, 0) + tensor_get_flat(sm_out, 1) + tensor_get_flat(sm_out, 2)
  sum_row1 = tensor_get_flat(sm_out, 3) + tensor_get_flat(sm_out, 4) + tensor_get_flat(sm_out, 5)
  assert_near_int(sum_row0, 1000, 10, "Softmax Row 0 sum == 1.0 (scaled 1000)")
  assert_near_int(sum_row1, 1000, 10, "Softmax Row 1 sum == 1.0 (scaled 1000)")
  assert_near_int(tensor_get_flat(sm_out, 3), 333, 5, "Uniform Softmax prob == 0.333 (scaled 333)")
  return 1
@end

@! ============================================================================
@! 4. TIER 4: Real-World Multidimensional Tensor Pipeline
@! ============================================================================

@fn run_tier4_real_world_pipeline_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4: Real-World Multidimensional Tensor Pipeline]")
  println("-----------------------------------------------------------------")

  @! Construct a 4D Feature Map: Batch=1, Channels=2, Height=4, Width=4 (Total 32 elems)
  feat_data = []
  i = 0
  @while i < 32
    feat_data = feat_data.push(i)
    i = i + 1
  @end
  feat_map = tensor_create(feat_data, [1, 2, 4, 4])
  assert_eq_int(feat_map.size, 32, "4D Feature map size == 32")

  @! 1. Permute NCHW -> NHWC ([0, 2, 3, 1])
  nhwc = tensor_permute(feat_map, [0, 2, 3, 1])
  assert_eq_int(nhwc.shape[0], 1, "NHWC Batch == 1")
  assert_eq_int(nhwc.shape[1], 4, "NHWC Height == 4")
  assert_eq_int(nhwc.shape[2], 4, "NHWC Width == 4")
  assert_eq_int(nhwc.shape[3], 2, "NHWC Channels == 2")

  @! 2. Spatial crop / slice: central 2x2 patch (Height 1..3, Width 1..3)
  patch_slice = tensor_slice(nhwc, [[0, 1, 1], [1, 3, 1], [1, 3, 1], [0, 2, 1]])
  assert_eq_int(patch_slice.shape[1], 2, "Cropped Height == 2")
  assert_eq_int(patch_slice.shape[2], 2, "Cropped Width == 2")
  assert_eq_int(patch_slice.shape[3], 2, "Cropped Channels == 2")

  @! 3. Flatten and project via Linear Projection (2x2 GEMM)
  contig_patch = tensor_contiguous(patch_slice)
  patch_flat = tensor_reshape(contig_patch, [4, 2])
  
  proj_weights = tensor_create([2, 1, 0, 3], [2, 2])
  projected = tensor_gemm_2d(patch_flat, proj_weights)
  assert_eq_int(projected.shape[0], 4, "Projected patch rows == 4")
  assert_eq_int(projected.shape[1], 2, "Projected patch cols == 2")

  @! 4. Softmax activation
  probs = tensor_softmax_scaled(projected)
  p_sum = tensor_get_flat(probs, 0) + tensor_get_flat(probs, 1)
  assert_near_int(p_sum, 1000, 10, "Patch projection softmax sum == 1000")

  @! 5. Linear and Self-Attention layers
  bias = tensor_create([5, 10], [1, 2])
  linear_out = tensor_linear(patch_flat, proj_weights, bias)
  assert_eq_int(linear_out.shape[0], 4, "Linear out rows == 4")
  assert_eq_int(linear_out.shape[1], 2, "Linear out cols == 2")

  q = tensor_ones([1, 2, 4])
  k = tensor_ones([1, 2, 4])
  v = tensor_create([10, 20, 30, 40, 50, 60, 70, 80], [1, 2, 4])
  attn_out = tensor_self_attention(q, k, v)
  assert_eq_int(attn_out.ndim, 3, "Self-attention ndim == 3")
  assert_eq_int(attn_out.shape[0], 1, "Self-attention batch == 1")
  assert_eq_int(attn_out.shape[1], 2, "Self-attention seq == 2")
  assert_eq_int(attn_out.shape[2], 4, "Self-attention dim == 4")

  println("    ✓ [PASS] Full 4D Feature Map -> NHWC -> Crop -> Contiguous -> GEMM -> Softmax pipeline verified!")
  return 1
@end

@! ============================================================================
@! 5. ADVERSARIAL STRESS SUITE (1D Strided Slice & Views)
@! ============================================================================

@fn run_adversarial_remediation_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL: 1D Strided Views & Contiguity Invariant Tests]")
  println("-----------------------------------------------------------------")

  @! Test 1D strided slicing with step = 2
  t10 = tensor_create([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [10])
  s_step2 = tensor_slice(t10, [[0, 10, 2]])
  assert_eq_int(s_step2.shape[0], 5, "1D slice step=2 shape[0] == 5")
  assert_eq_int(s_step2.strides[0], 2, "1D slice step=2 strides[0] == 2")
  assert_eq_int(s_step2.is_contiguous, 0, "1D slice step=2 is_contiguous == 0")
  assert_eq_int(tensor_get(s_step2, [1]), 2, "1D slice step=2 get([1]) == 2")
  assert_eq_int(tensor_get_flat(s_step2, 1), 2, "1D slice step=2 get_flat(1) == 2")
  assert_eq_int(tensor_get_flat(s_step2, 4), 8, "1D slice step=2 get_flat(4) == 8")

  @! Contiguous compaction of 1D strided slice
  cs_step2 = tensor_contiguous(s_step2)
  assert_eq_int(cs_step2.is_contiguous, 1, "Compacted 1D slice is_contiguous == 1")
  assert_eq_int(tensor_get_flat(cs_step2, 1), 2, "Compacted 1D slice get_flat(1) == 2")
  assert_eq_int(tensor_get_flat(cs_step2, 4), 8, "Compacted 1D slice get_flat(4) == 8")

  @! Test 1D strided slicing with step = 3
  s_step3 = tensor_slice(t10, [[0, 10, 3]])
  assert_eq_int(s_step3.shape[0], 4, "1D slice step=3 shape[0] == 4")
  assert_eq_int(s_step3.strides[0], 3, "1D slice step=3 strides[0] == 3")
  assert_eq_int(s_step3.is_contiguous, 0, "1D slice step=3 is_contiguous == 0")
  assert_eq_int(tensor_get_flat(s_step3, 0), 0, "1D slice step=3 get_flat(0) == 0")
  assert_eq_int(tensor_get_flat(s_step3, 1), 3, "1D slice step=3 get_flat(1) == 3")
  assert_eq_int(tensor_get_flat(s_step3, 2), 6, "1D slice step=3 get_flat(2) == 6")
  assert_eq_int(tensor_get_flat(s_step3, 3), 9, "1D slice step=3 get_flat(3) == 9")

  @! Reductions on 1D strided non-contiguous slice
  sum_s2 = tensor_sum(s_step2, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(sum_s2, 0), 20, "1D strided sum (0+2+4+6+8) == 20")

  return 1
@end

@fn run_tier6_squeeze_unsqueeze_argmax_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 6: Squeeze, Unsqueeze, Argmax, Dot, Norm Tests]")
  println("-----------------------------------------------------------------")

  @! 1. Squeeze and Unsqueeze
  t_3d = tensor_create([1, 2, 3, 4], [1, 4, 1])
  assert_eq_int(t_3d.ndim, 3, "3D Tensor ndim == 3")
  
  t_sq0 = tensor_squeeze(t_3d, 0)
  assert_eq_int(t_sq0.ndim, 2, "Squeeze dim 0 ndim == 2")
  assert_eq_int(t_sq0.shape[0], 4, "Squeeze dim 0 shape[0] == 4")
  assert_eq_int(t_sq0.shape[1], 1, "Squeeze dim 0 shape[1] == 1")

  t_sq_last = tensor_squeeze(t_sq0, 1)
  assert_eq_int(t_sq_last.ndim, 1, "Squeeze dim 1 ndim == 1")
  assert_eq_int(t_sq_last.shape[0], 4, "Squeeze dim 1 shape[0] == 4")

  t_unsq = tensor_unsqueeze(t_sq_last, 0)
  assert_eq_int(t_unsq.ndim, 2, "Unsqueeze dim 0 ndim == 2")
  assert_eq_int(t_unsq.shape[0], 1, "Unsqueeze dim 0 shape[0] == 1")
  assert_eq_int(t_unsq.shape[1], 4, "Unsqueeze dim 0 shape[1] == 4")

  @! 2. Argmax
  t_logits = tensor_create([10, 45, 30, 80, 20, 15], [2, 3])
  arg_all = tensor_argmax(t_logits, 0 - 1, 0)
  assert_eq_int(tensor_get_flat(arg_all, 0), 3, "Argmax global index == 3 (val 80)")

  arg_dim1 = tensor_argmax(t_logits, 1, 0)
  assert_eq_int(arg_dim1.shape[0], 2, "Argmax dim 1 shape[0] == 2")
  assert_eq_int(tensor_get_flat(arg_dim1, 0), 1, "Argmax row 0 max at col 1 (val 45)")
  assert_eq_int(tensor_get_flat(arg_dim1, 1), 0, "Argmax row 1 max at col 0 (val 80)")

  @! 3. Dot & Norm
  v1 = tensor_create([3, 4], [2])
  v2 = tensor_create([2, 5], [2])
  assert_eq_int(tensor_dot(v1, v2), 26, "Dot product (3*2 + 4*5) == 26")
  assert_eq_int(tensor_norm(v1), 5, "Vector norm sqrt(3^2 + 4^2) == 5")

  println("    ✓ [PASS] All Squeeze, Unsqueeze, Argmax, Dot, Norm tests passed!")
  return 1
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🧪 MAYA UNIVERSE TENSOR CORE & STRIDED ENGINE TEST SUITE")
  println("=================================================================")
  
  t1 = run_tier1_core_tests()
  t2 = run_tier2_boundary_tests()
  t3 = run_tier3_combination_tests()
  t4 = run_tier4_real_world_pipeline_tests()
  t5 = run_adversarial_remediation_tests()
  t6 = run_tier6_squeeze_unsqueeze_argmax_tests()
  
  total = t1 + t2 + t3 + t4 + t5 + t6
  println("=================================================================")
  println("🎉 ALL TENSOR SUITE TESTS PASSED SUCCESSFULLY (" + total.to_str() + "/6 SUITES)")
  println("=================================================================")
  return 0
@end
