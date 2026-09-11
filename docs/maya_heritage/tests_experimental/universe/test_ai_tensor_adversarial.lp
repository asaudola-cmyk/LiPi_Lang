@! ============================================================================
@! MAYA UNIVERSE ADVERSARIAL STRESS TEST SUITE — TENSOR ENGINE
@! Milestone 1: Pure Maya N-Dimensional Tensor Core & Strided Memory Engine
@! Adversarial Verification of: Extreme Dimensions, Negative Coordinates,
@! Zero Strides, Empty Slices, Non-Contiguous Slicing, Broadcasting Topologies,
@! 4D Permutations & Batched GEMM, Transcendental Stability, Reductions
@! ============================================================================

import "universe/ai/tensor"

@! ----------------------------------------------------------------------------
@! Test Framework Assertions
@! ----------------------------------------------------------------------------

@fn assert_true(cond: bool, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    return 0
  @end
@end

@fn assert_eq_i64(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    return 0
  @end
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
    println("    ✗ [FAIL] " + test_name + " (Diff " + diff.to_str() + " > " + tol.to_str() + ")")
    return 0
  @end
@end

@fn assert_near_i64(actual: i64, expected: i64, tol: i64, test_name: string) -> i64
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    println("    ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Diff " + diff.to_str() + " > " + tol.to_str() + ")")
    return 0
  @end
@end

@! ----------------------------------------------------------------------------
@! 1. Extreme Tensor Dimensions & High-Rank Topologies
@! ----------------------------------------------------------------------------

@fn test_extreme_dimensions() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 1: Extreme Tensor Dimensions & High-Rank Topologies]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 1.1 0D Scalar Tensor
  t0d = tensor_new([42], [])
  passes = passes + assert_eq_i64(t0d.ndim, 0, "0D scalar tensor ndim == 0")
  passes = passes + assert_eq_i64(t0d.size, 1, "0D scalar tensor size == 1")
  passes = passes + assert_eq_i64(tensor_get_flat(t0d, 0), 42, "0D scalar tensor_get_flat(0) == 42")
  passes = passes + assert_eq_i64(tensor_get(t0d, []), 42, "0D scalar tensor_get([]) == 42")

  @! Reshape 0D to 1D
  t0d_reshaped = tensor_reshape(t0d, [1])
  passes = passes + assert_eq_i64(t0d_reshaped.ndim, 1, "Reshape 0D to 1D ndim == 1")
  passes = passes + assert_eq_i64(tensor_get_flat(t0d_reshaped, 0), 42, "Reshaped 0D to 1D value == 42")

  @! 1.2 5D High-Rank Tensor: shape [2, 3, 1, 4, 2] -> size 48
  t5d_data = []
  i = 0
  @while i < 48
    t5d_data = t5d_data.push(i + 1)
    i = i + 1
  @end
  t5d = tensor_new(t5d_data, [2, 3, 1, 4, 2])
  passes = passes + assert_eq_i64(t5d.ndim, 5, "5D tensor ndim == 5")
  passes = passes + assert_eq_i64(t5d.size, 48, "5D tensor size == 48")
  passes = passes + assert_eq_i64(t5d.strides[0], 24, "5D strides[0] == 24")
  passes = passes + assert_eq_i64(t5d.strides[1], 8, "5D strides[1] == 8")
  passes = passes + assert_eq_i64(t5d.strides[2], 8, "5D strides[2] == 8 (dim size 1)")
  passes = passes + assert_eq_i64(t5d.strides[3], 2, "5D strides[3] == 2")
  passes = passes + assert_eq_i64(t5d.strides[4], 1, "5D strides[4] == 1")

  @! Element access: t5d[1, 2, 0, 3, 1] -> offset = 1*24 + 2*8 + 0*8 + 3*2 + 1*1 = 24 + 16 + 0 + 6 + 1 = 47 (value 48)
  v_5d = tensor_get(t5d, [1, 2, 0, 3, 1])
  passes = passes + assert_eq_i64(v_5d, 48, "5D tensor_get([1, 2, 0, 3, 1]) == 48")

  @! 5D Permutation: [4, 2, 0, 3, 1] -> shape [2, 1, 2, 4, 3]
  p5d = tensor_permute(t5d, [4, 2, 0, 3, 1])
  passes = passes + assert_eq_i64(p5d.ndim, 5, "5D permuted ndim == 5")
  passes = passes + assert_eq_i64(p5d.shape[0], 2, "5D permuted shape[0] == 2")
  passes = passes + assert_eq_i64(p5d.shape[1], 1, "5D permuted shape[1] == 1")
  passes = passes + assert_eq_i64(p5d.shape[2], 2, "5D permuted shape[2] == 2")
  passes = passes + assert_eq_i64(p5d.shape[3], 4, "5D permuted shape[3] == 4")
  passes = passes + assert_eq_i64(p5d.shape[4], 3, "5D permuted shape[4] == 3")
  @! Access permuted coords [1, 0, 1, 3, 2] -> original was [1, 2, 0, 3, 1] -> value 48
  v_p5d = tensor_get(p5d, [1, 0, 1, 3, 2])
  passes = passes + assert_eq_i64(v_p5d, 48, "5D permuted element access mapped correctly == 48")

  @! 1.3 6D High-Rank Tensor: shape [2, 2, 2, 2, 2, 2] -> size 64
  t6d = tensor_reshape(tensor_arange(1, 65, 1), [2, 2, 2, 2, 2, 2])
  passes = passes + assert_eq_i64(t6d.ndim, 6, "6D tensor ndim == 6")
  passes = passes + assert_eq_i64(t6d.size, 64, "6D tensor size == 64")
  passes = passes + assert_eq_i64(tensor_get(t6d, [1, 1, 1, 1, 1, 1]), 64, "6D tensor_get([1,1,1,1,1,1]) == 64")

  @! 1.4 Extreme Singleton Dimensions: [1, 1, 1, 1, 5, 1]
  t_sing = tensor_reshape(tensor_arange(10, 15, 1), [1, 1, 1, 1, 5, 1])
  passes = passes + assert_eq_i64(t_sing.ndim, 6, "Singleton-heavy tensor ndim == 6")
  passes = passes + assert_eq_i64(t_sing.size, 5, "Singleton-heavy tensor size == 5")
  passes = passes + assert_eq_i64(tensor_get(t_sing, [0, 0, 0, 0, 3, 0]), 13, "Singleton tensor_get([0,0,0,0,3,0]) == 13")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 2. Negative Indices & Coordinate Clamping
@! ----------------------------------------------------------------------------

@fn test_negative_coordinates() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 2: Negative Coordinates & Edge Indexing]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 2.1 3D Negative Indexing
  @! Shape [2, 3, 4] -> size 24
  t3d = tensor_reshape(tensor_arange(0, 24, 1), [2, 3, 4])
  passes = passes + assert_eq_i64(tensor_get(t3d, [0 - 1, 0 - 1, 0 - 1]), 23, "3D negative index [-1, -1, -1] == 23")
  passes = passes + assert_eq_i64(tensor_get(t3d, [0 - 2, 0 - 3, 0 - 4]), 0, "3D negative index [-2, -3, -4] == 0")
  passes = passes + assert_eq_i64(tensor_get(t3d, [0 - 1, 0 - 2, 0 - 3]), 17, "3D negative index [-1, -2, -3] == 17")

  @! 2.2 Negative Index Mutation via tensor_set
  tensor_set(t3d, [0 - 1, 0 - 1, 0 - 1], 7777)
  passes = passes + assert_eq_i64(tensor_get(t3d, [1, 2, 3]), 7777, "Mutation via [-1, -1, -1] updates [1, 2, 3]")

  @! 2.3 Negative arange
  neg_arange = tensor_arange(10, 0, 0 - 2)
  passes = passes + assert_eq_i64(neg_arange.size, 5, "Negative step arange size == 5")
  passes = passes + assert_eq_i64(tensor_get_flat(neg_arange, 0), 10, "neg_arange[0] == 10")
  passes = passes + assert_eq_i64(tensor_get_flat(neg_arange, 4), 2, "neg_arange[4] == 2")

  neg_arange2 = tensor_arange(0 - 5, 0 - 15, 0 - 3)
  passes = passes + assert_eq_i64(neg_arange2.size, 4, "Negative start/stop arange size == 4")
  passes = passes + assert_eq_i64(tensor_get_flat(neg_arange2, 0), 0 - 5, "neg_arange2[0] == -5")
  passes = passes + assert_eq_i64(tensor_get_flat(neg_arange2, 3), 0 - 14, "neg_arange2[3] == -14")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 3. Zero Strides & Complex Broadcasting Topologies
@! ----------------------------------------------------------------------------

@fn test_broadcasting_topologies() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 3: Zero Strides & Complex Broadcasting Topologies]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 3.1 1D to 3D Broadcast: [4] to [2, 3, 4]
  v = tensor_new([10, 20, 30, 40], [4])
  b1 = tensor_broadcast_to(v, [2, 3, 4])
  passes = passes + assert_eq_i64(b1.ndim, 3, "1D->3D broadcast ndim == 3")
  passes = passes + assert_eq_i64(b1.size, 24, "1D->3D broadcast size == 24")
  passes = passes + assert_eq_i64(b1.strides[0], 0, "1D->3D broadcast stride[0] == 0")
  passes = passes + assert_eq_i64(b1.strides[1], 0, "1D->3D broadcast stride[1] == 0")
  passes = passes + assert_eq_i64(b1.strides[2], 1, "1D->3D broadcast stride[2] == 1")
  passes = passes + assert_eq_i64(tensor_get(b1, [0, 0, 2]), 30, "b1[0, 0, 2] == 30")
  passes = passes + assert_eq_i64(tensor_get(b1, [1, 2, 2]), 30, "b1[1, 2, 2] == 30")

  @! Materialize broadcast view via tensor_contiguous
  cb1 = tensor_contiguous(b1)
  passes = passes + assert_eq_i64(cb1.is_contiguous, 1, "cb1 is_contiguous == 1")
  passes = passes + assert_eq_i64(cb1.data.len(), 24, "cb1 packed data length == 24")
  passes = passes + assert_eq_i64(cb1.data[23], 40, "cb1.data[23] == 40")

  @! 3.2 Complex 4D Multidirectional Broadcasting:
  @! A: [2, 1, 1, 4], B: [1, 3, 5, 1] -> Output: [2, 3, 5, 4] -> size 120
  a4 = tensor_full([2, 1, 1, 4], 3)
  b4 = tensor_full([1, 3, 5, 1], 7)
  c4 = tensor_add(a4, b4)
  passes = passes + assert_eq_i64(c4.ndim, 4, "4D broadcast add ndim == 4")
  passes = passes + assert_eq_i64(c4.shape[0], 2, "4D broadcast shape[0] == 2")
  passes = passes + assert_eq_i64(c4.shape[1], 3, "4D broadcast shape[1] == 3")
  passes = passes + assert_eq_i64(c4.shape[2], 5, "4D broadcast shape[2] == 5")
  passes = passes + assert_eq_i64(c4.shape[3], 4, "4D broadcast shape[3] == 4")
  passes = passes + assert_eq_i64(c4.size, 120, "4D broadcast size == 120")
  passes = passes + assert_eq_i64(tensor_get(c4, [1, 2, 4, 3]), 10, "c4[1, 2, 4, 3] == 3 + 7 = 10")

  @! 3.3 Incompatible Broadcast Shapes Check
  incompat_shape = tensor_broadcast_shapes([3, 4], [2, 5])
  passes = passes + assert_eq_i64(incompat_shape.len(), 0, "Incompatible shapes [3, 4] vs [2, 5] returns []")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 4. Degenerate & Empty Slices
@! ----------------------------------------------------------------------------

@fn test_empty_and_boundary_slices() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 4: Degenerate & Empty Slices]")
  println("-----------------------------------------------------------------")
  passes = 0

  t = tensor_reshape(tensor_arange(0, 20, 1), [4, 5])

  @! 4.1 Empty slice: start == stop (e.g. [2, 2, 1])
  s_empty = tensor_slice(t, [[2, 2, 1], [0, 5, 1]])
  passes = passes + assert_eq_i64(s_empty.shape[0], 0, "Empty slice shape[0] == 0")
  passes = passes + assert_eq_i64(s_empty.shape[1], 5, "Empty slice shape[1] == 5")
  passes = passes + assert_eq_i64(s_empty.size, 0, "Empty slice size == 0")

  @! 4.2 Inverted slice: start > stop (e.g. [4, 2, 1])
  s_inv = tensor_slice(t, [[4, 2, 1], [0, 5, 1]])
  passes = passes + assert_eq_i64(s_inv.shape[0], 0, "Inverted slice shape[0] == 0")
  passes = passes + assert_eq_i64(s_inv.shape[1], 5, "Inverted slice shape[1] == 5")
  passes = passes + assert_eq_i64(s_inv.size, 0, "Inverted slice size == 0")

  @! 4.3 Out-of-bounds start: start >= dim_size (e.g. [10, 20, 1])
  s_oob = tensor_slice(t, [[10, 20, 1], [0, 5, 1]])
  passes = passes + assert_eq_i64(s_oob.shape[0], 0, "OOB slice shape[0] == 0")
  passes = passes + assert_eq_i64(s_oob.size, 0, "OOB slice size == 0")

  @! 4.4 Boundary clamping: slice [ -100, 100, 1 ] on dim 4
  s_clamped = tensor_slice(t, [[0 - 100, 100, 1], [0, 5, 1]])
  passes = passes + assert_eq_i64(s_clamped.shape[0], 4, "Clamped slice shape[0] == 4")
  passes = passes + assert_eq_i64(s_clamped.shape[1], 5, "Clamped slice shape[1] == 5")
  passes = passes + assert_eq_i64(s_clamped.size, 20, "Clamped slice size == 20")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 5. Non-Contiguous Multi-Step Slicing & Strided Indexing
@! ----------------------------------------------------------------------------

@fn test_non_contiguous_slicing() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 5: Non-Contiguous Multi-Step Slicing & Strided Indexing]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 5.1 2D Multi-Axis Strided Slicing:
  @! 6x6 matrix with values 0..35
  @! Slicing rows with step=2 (rows 0, 2, 4) and cols with step=3 (cols 0, 3)
  @! Result shape: [3, 2]
  @! Row 0: [ 0,  3]
  @! Row 1: [12, 15]
  @! Row 2: [24, 27]
  t6x6 = tensor_reshape(tensor_arange(0, 36, 1), [6, 6])
  s2d = tensor_slice(t6x6, [[0, 6, 2], [0, 6, 3]])
  passes = passes + assert_eq_i64(s2d.shape[0], 3, "2D slice shape[0] == 3")
  passes = passes + assert_eq_i64(s2d.shape[1], 2, "2D slice shape[1] == 2")
  passes = passes + assert_eq_i64(s2d.strides[0], 12, "2D slice strides[0] == 12 (6 * 2)")
  passes = passes + assert_eq_i64(s2d.strides[1], 3, "2D slice strides[1] == 3 (1 * 3)")
  passes = passes + assert_eq_i64(s2d.is_contiguous, 0, "2D slice is_contiguous == 0")

  passes = passes + assert_eq_i64(tensor_get(s2d, [0, 0]), 0, "s2d[0, 0] == 0")
  passes = passes + assert_eq_i64(tensor_get(s2d, [0, 1]), 3, "s2d[0, 1] == 3")
  passes = passes + assert_eq_i64(tensor_get(s2d, [1, 0]), 12, "s2d[1, 0] == 12")
  passes = passes + assert_eq_i64(tensor_get(s2d, [1, 1]), 15, "s2d[1, 1] == 15")
  passes = passes + assert_eq_i64(tensor_get(s2d, [2, 0]), 24, "s2d[2, 0] == 24")
  passes = passes + assert_eq_i64(tensor_get(s2d, [2, 1]), 27, "s2d[2, 1] == 27")

  @! Contiguous materialization of 2D strided slice
  cs2d = tensor_contiguous(s2d)
  passes = passes + assert_eq_i64(cs2d.size, 6, "cs2d size == 6")
  passes = passes + assert_eq_i64(cs2d.data[0], 0, "cs2d.data[0] == 0")
  passes = passes + assert_eq_i64(cs2d.data[1], 3, "cs2d.data[1] == 3")
  passes = passes + assert_eq_i64(cs2d.data[2], 12, "cs2d.data[2] == 12")
  passes = passes + assert_eq_i64(cs2d.data[3], 15, "cs2d.data[3] == 15")
  passes = passes + assert_eq_i64(cs2d.data[4], 24, "cs2d.data[4] == 24")
  passes = passes + assert_eq_i64(cs2d.data[5], 27, "cs2d.data[5] == 27")

  @! 5.2 Nested Slicing View Mutation
  @! Sub-slice of s2d: rows [1, 3], cols [0, 2] -> shape [2, 2]
  @! Corresponds to t6x6 rows 2 and 4, cols 0 and 3 -> values [12, 15], [24, 27]
  sub_s = tensor_slice(s2d, [[1, 3, 1], [0, 2, 1]])
  passes = passes + assert_eq_i64(tensor_get(sub_s, [0, 0]), 12, "sub_s[0, 0] == 12")
  passes = passes + assert_eq_i64(tensor_get(sub_s, [1, 1]), 27, "sub_s[1, 1] == 27")

  @! In-place mutation through nested slice view
  tensor_set(sub_s, [1, 1], 9999)
  passes = passes + assert_eq_i64(tensor_get(t6x6, [4, 3]), 9999, "Mutating nested slice updates underlying t6x6[4, 3] to 9999")

  @! 5.3 1D Strided Slice (Testing known contiguity condition)
  t1d = tensor_arange(0, 10, 1)
  s1d = tensor_slice(t1d, [[0, 10, 2]])
  v_coord1 = tensor_get(s1d, [1])
  passes = passes + assert_eq_i64(v_coord1, 2, "1D slice tensor_get([1]) == 2 via coordinate strides")

  @! Check 1D flat vs coordinate access
  v_flat1 = tensor_get_flat(s1d, 1)
  @if v_flat1 == 2
    println("    ✓ [PASS] 1D slice tensor_get_flat(1) == 2")
    passes = passes + 1
  @else
    println("    ✗ [FAIL] 1D slice tensor_get_flat(1) returned " + v_flat1.to_str() + " due to ndim<=1 is_contiguous assumption")
  @end

  return passes
@end

@! ----------------------------------------------------------------------------
@! 6. 4D Multi-Head Attention Permutations & Batched GEMM
@! ----------------------------------------------------------------------------

@fn test_4d_permutations_and_gemm() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 6: 4D Permutations & Batched GEMM]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 6.1 MHA Permutations: [B=2, S=3, H=4, D=5] -> size 120
  t_mha = tensor_reshape(tensor_arange(0, 120, 1), [2, 3, 4, 5])

  @! Permute to [B, H, S, D] -> order [0, 2, 1, 3] -> shape [2, 4, 3, 5]
  q = tensor_permute(t_mha, [0, 2, 1, 3])
  passes = passes + assert_eq_i64(q.shape[0], 2, "MHA Q shape[0] == 2")
  passes = passes + assert_eq_i64(q.shape[1], 4, "MHA Q shape[1] == 4")
  passes = passes + assert_eq_i64(q.shape[2], 3, "MHA Q shape[2] == 3")
  passes = passes + assert_eq_i64(q.shape[3], 5, "MHA Q shape[3] == 5")

  @! Permute K to [B, H, D, S] -> order [0, 2, 3, 1] -> shape [2, 4, 5, 3]
  k_t = tensor_permute(t_mha, [0, 2, 3, 1])
  passes = passes + assert_eq_i64(k_t.shape[0], 2, "MHA K^T shape[0] == 2")
  passes = passes + assert_eq_i64(k_t.shape[1], 4, "MHA K^T shape[1] == 4")
  passes = passes + assert_eq_i64(k_t.shape[2], 5, "MHA K^T shape[2] == 5")
  passes = passes + assert_eq_i64(k_t.shape[3], 3, "MHA K^T shape[3] == 3")

  @! Batched GEMM: Q @ K^T -> shape [2, 4, 3, 3] -> size 72
  attn_scores = tensor_matmul(q, k_t)
  passes = passes + assert_eq_i64(attn_scores.ndim, 4, "Attn scores ndim == 4")
  passes = passes + assert_eq_i64(attn_scores.shape[0], 2, "Attn scores shape[0] == 2")
  passes = passes + assert_eq_i64(attn_scores.shape[1], 4, "Attn scores shape[1] == 4")
  passes = passes + assert_eq_i64(attn_scores.shape[2], 3, "Attn scores shape[2] == 3")
  passes = passes + assert_eq_i64(attn_scores.shape[3], 3, "Attn scores shape[3] == 3")
  passes = passes + assert_eq_i64(attn_scores.size, 72, "Attn scores size == 72")

  @! Check exact analytical GEMM values:
  @! attn_scores[0, 0, 0, 0] = sum(d=0..4) d*d = 30
  @! attn_scores[0, 0, 0, 1] = sum(d=0..4) d*(20+d) = 230
  passes = passes + assert_eq_i64(tensor_get(attn_scores, [0, 0, 0, 0]), 30, "attn_scores[0, 0, 0, 0] == 30")
  passes = passes + assert_eq_i64(tensor_get(attn_scores, [0, 0, 0, 1]), 230, "attn_scores[0, 0, 0, 1] == 230")

  @! 6.2 Batched GEMM with Leading Broadcast Dimensions:
  @! A: [2, 1, 2, 3] (filled 1), B: [1, 3, 3, 2] (filled 2) -> Out: [2, 3, 2, 2]
  @! Result = 1 * 2 * 3 (inner dim) = 6
  a_bmm = tensor_ones([2, 1, 2, 3])
  b_bmm = tensor_full([1, 3, 3, 2], 2)
  c_bmm = tensor_matmul(a_bmm, b_bmm)
  passes = passes + assert_eq_i64(c_bmm.shape[0], 2, "BMM broadcast shape[0] == 2")
  passes = passes + assert_eq_i64(c_bmm.shape[1], 3, "BMM broadcast shape[1] == 3")
  passes = passes + assert_eq_i64(c_bmm.shape[2], 2, "BMM broadcast shape[2] == 2")
  passes = passes + assert_eq_i64(c_bmm.shape[3], 2, "BMM broadcast shape[3] == 2")
  passes = passes + assert_eq_i64(tensor_get(c_bmm, [0, 0, 0, 0]), 6, "c_bmm[0, 0, 0, 0] == 6")
  passes = passes + assert_eq_i64(tensor_get(c_bmm, [1, 2, 1, 1]), 6, "c_bmm[1, 2, 1, 1] == 6")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 7. Transcendental Stability & Numerically Stable Activations
@! ----------------------------------------------------------------------------

@fn test_transcendental_stability() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 7: Transcendental Stability & Activations]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! 7.1 Extreme Exponential values
  passes = passes + assert_near_f64(math_exp(700.0), math_exp(800.0), 0.0001, "math_exp(800.0) clamped against +Inf")
  passes = passes + assert_near_f64(math_exp(0.0 - 800.0), 0.0, 0.0001, "math_exp(-800.0) clamped to 0.0")

  @! 7.2 Extreme Logarithm values
  passes = passes + assert_near_f64(math_ln(0.0), 0.0 - 1000000.0, 0.0001, "math_ln(0.0) bounded against -Inf")
  passes = passes + assert_near_f64(math_ln(0.0 - 10.0), 0.0 - 1000000.0, 0.0001, "math_ln(-10.0) bounded against NaN")

  @! 7.3 Asymptotic Tanh values
  passes = passes + assert_near_f64(math_tanh(50.0), 1.0, 0.0001, "math_tanh(+50.0) == 1.0")
  passes = passes + assert_near_f64(math_tanh(0.0 - 50.0), 0.0 - 1.0, 0.0001, "math_tanh(-50.0) == -1.0")

  @! 7.4 Softmax Max-Subtraction Stabilization on Extreme Logits
  @! Logits: [10000, 20000, 30000] with scale 10000.0 (x = [1.0, 2.0, 3.0])
  logits = tensor_new([10000, 20000, 30000], [1, 3])
  probs = tensor_softmax(logits, 10000.0)
  p0 = tensor_get_flat(probs, 0)
  p1 = tensor_get_flat(probs, 1)
  p2 = tensor_get_flat(probs, 2)
  prob_sum = p0 + p1 + p2
  passes = passes + assert_near_i64(prob_sum, 10000, 2, "Softmax sum on extreme logits ~ 10000 (within fixed point tol)")

  @! 7.5 GELU Symmetry and Scaling
  t_gelu = tensor_new([0 - 2000, 0, 2000], [3])
  gelu_out = tensor_gelu(t_gelu, 1000.0)
  g_neg = tensor_get_flat(gelu_out, 0)
  g_zero = tensor_get_flat(gelu_out, 1)
  g_pos = tensor_get_flat(gelu_out, 2)
  passes = passes + assert_eq_i64(g_zero, 0, "GELU(0) == 0")
  cond_neg = g_neg < 0 && g_neg > 0 - 500
  passes = passes + assert_true(cond_neg, "GELU(-2) is negative bounded")
  cond_pos = g_pos > 1900 && g_pos < 2100
  passes = passes + assert_true(cond_pos, "GELU(+2) ~ 1.954 * 1000")

  return passes
@end

@! ----------------------------------------------------------------------------
@! 8. Statistical Reductions on Non-Contiguous Views
@! ----------------------------------------------------------------------------

@fn test_reductions_on_views() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [ADVERSARIAL 8: Statistical Reductions on Non-Contiguous Views]")
  println("-----------------------------------------------------------------")
  passes = 0

  @! Matrix [2, 3]:
  @! [1, 2, 3]
  @! [4, 5, 6]
  @! Transpose to [3, 2]:
  @! [1, 4]
  @! [2, 5]
  @! [3, 6]
  m = tensor_reshape(tensor_arange(1, 7, 1), [2, 3])
  m_t = tensor_transpose(m, 0, 1)

  @! Sum along axis 0: [1+2+3, 4+5+6] = [6, 15]
  s0 = tensor_sum(m_t, 0, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(s0, 0), 6, "Sum axis 0 of transpose elem 0 == 6")
  passes = passes + assert_eq_i64(tensor_get_flat(s0, 1), 15, "Sum axis 0 of transpose elem 1 == 15")

  @! Sum along axis 1: [1+4, 2+5, 3+6] = [5, 7, 9]
  s1 = tensor_sum(m_t, 1, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(s1, 0), 5, "Sum axis 1 of transpose elem 0 == 5")
  passes = passes + assert_eq_i64(tensor_get_flat(s1, 1), 7, "Sum axis 1 of transpose elem 1 == 7")
  passes = passes + assert_eq_i64(tensor_get_flat(s1, 2), 9, "Sum axis 1 of transpose elem 2 == 9")

  @! Global sum (dim = -1)
  s_all = tensor_sum(m_t, 0 - 1, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(s_all, 0), 21, "Global sum of transpose == 21 (1+2+3+4+5+6)")

  @! Mean axis 0: [6/3, 15/3] = [2, 5]
  mu0 = tensor_mean(m_t, 0, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(mu0, 0), 2, "Mean axis 0 elem 0 == 2")
  passes = passes + assert_eq_i64(tensor_get_flat(mu0, 1), 5, "Mean axis 0 elem 1 == 5")

  @! Max axis 0: [3, 6]
  mx0 = tensor_max(m_t, 0, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(mx0, 0), 3, "Max axis 0 elem 0 == 3")
  passes = passes + assert_eq_i64(tensor_get_flat(mx0, 1), 6, "Max axis 0 elem 1 == 6")

  @! Min axis 1: [1, 2, 3]
  mn1 = tensor_min(m_t, 1, 0)
  passes = passes + assert_eq_i64(tensor_get_flat(mn1, 0), 1, "Min axis 1 elem 0 == 1")
  passes = passes + assert_eq_i64(tensor_get_flat(mn1, 1), 2, "Min axis 1 elem 1 == 2")
  passes = passes + assert_eq_i64(tensor_get_flat(mn1, 2), 3, "Min axis 1 elem 2 == 3")

  return passes
@end

@! ----------------------------------------------------------------------------
@! Main Test Runner
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("🧪 MAYA UNIVERSE ADVERSARIAL STRESS TEST SUITE — TENSOR ENGINE")
  println("=================================================================")

  total_passes = 0
  total_passes = total_passes + test_extreme_dimensions()
  total_passes = total_passes + test_negative_coordinates()
  total_passes = total_passes + test_broadcasting_topologies()
  total_passes = total_passes + test_empty_and_boundary_slices()
  total_passes = total_passes + test_non_contiguous_slicing()
  total_passes = total_passes + test_4d_permutations_and_gemm()
  total_passes = total_passes + test_transcendental_stability()
  total_passes = total_passes + test_reductions_on_views()

  println("=================================================================")
  println("Total Successful Assertions: " + total_passes.to_str())
  println("=================================================================")
@end
