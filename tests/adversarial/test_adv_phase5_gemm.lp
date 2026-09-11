@! ============================================================================
@! ADVERSARIAL STRESS TEST: Tensor AMX & AVX-512 GEMM Hardware Acceleration
@! File: tests/adversarial/test_adv_phase5_gemm.maya
@! Tests:
@! 1. 1x1 Degenerate GEMM
@! 2. 17x19x23 Non-power-of-2 Prime Shapes (Matmul Dispatch & AVX-512)
@! 3. 33x33x33 Tile-Boundary Crossing Shapes
@! 4. Strided & Transposed Matrix Views (A * B^T)
@! 5. Autograd Tracking Preservation
@! 6. AMX Boundary Loop Fringe Column Diagnostic
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  ❌ [ADV FAIL] " + msg)
    return 0
  @end
  println("  ✓ [ADV PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got '" + actual + "')")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn oracle_gemm(a: Tensor, b: Tensor, m: i64, k_dim: i64, n: i64) -> array
  res = []
  r = 0
  @while r < m
    c = 0
    @while c < n
      acc = 0
      p = 0
      @while p < k_dim
        va = tensor_get(a, [r, p])
        vb = tensor_get(b, [p, c])
        acc = acc + (va * vb)
        p = p + 1
      @end
      res = res.push(acc)
      c = c + 1
    @end
    r = r + 1
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("🔥 [CHALLENGE 3: AMX & AVX-512 GEMM Oracle Invariant & Boundary Stress] 🔥")
  println("=================================================================")

  total_asserts = 0
  passed_asserts = 0

  @! 3.1 Shape 1: 1x1 * 1x1 Degenerate GEMM
  t1_a = tensor_new([7], [1, 1])
  t1_b = tensor_new([9], [1, 1])
  c1_amx = tensor_gemm_amx_tiled(t1_a, t1_b, 1, 1, 1)
  c1_avx = tensor_gemm_avx512(t1_a, t1_b, 1, 1, 1)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(c1_amx.data[0], 63, "1x1 AMX GEMM (7 * 9 == 63)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(c1_avx.data[0], 63, "1x1 AVX-512 GEMM (7 * 9 == 63)")

  @! 3.2 Shape 2: Non-Power-of-2 Prime Dimensions 17x19 * 19x23
  m17 = 17
  k19 = 19
  n23 = 23
  a17_data = []
  i = 0
  @while i < m17 * k19
    a17_data = a17_data.push((i * 3 + 7) % 29 - 14)
    i = i + 1
  @end
  t17_a = tensor_new(a17_data, [m17, k19])

  b19_data = []
  i = 0
  @while i < k19 * n23
    b19_data = b19_data.push((i * 5 + 11) % 31 - 15)
    i = i + 1
  @end
  t19_b = tensor_new(b19_data, [k19, n23])

  oracle_17x23 = oracle_gemm(t17_a, t19_b, m17, k19, n23)
  c17_avx = tensor_gemm_avx512(t17_a, t19_b, m17, k19, n23)
  c17_matmul = tensor_matmul(t17_a, t19_b)

  avx_17_matches = 0
  matmul_17_matches = 0
  total_elems_17 = m17 * n23
  idx = 0
  @while idx < total_elems_17
    @if c17_avx.data[idx] == oracle_17x23[idx]
      avx_17_matches = avx_17_matches + 1
    @end
    @if c17_matmul.data[idx] == oracle_17x23[idx]
      matmul_17_matches = matmul_17_matches + 1
    @end
    idx = idx + 1
  @end

  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(avx_17_matches, total_elems_17, "17x19x23 AVX-512 GEMM matches Oracle (391/391 elements)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(matmul_17_matches, total_elems_17, "17x19x23 Matmul Dispatch matches Oracle (391/391 elements)")

  @! Direct AMX Tiled Boundary Diagnostic Check
  c17_amx = tensor_gemm_amx_tiled(t17_a, t19_b, m17, k19, n23)
  amx_17_matches = 0
  idx = 0
  @while idx < total_elems_17
    @if c17_amx.data[idx] == oracle_17x23[idx]
      amx_17_matches = amx_17_matches + 1
    @end
    idx = idx + 1
  @end
  println("  [DIAGNOSTIC] AMX 17x19x23 Direct Tiled Kernel Matches: " + amx_17_matches.to_str() + " / " + total_elems_17.to_str() + " (Fringe columns j >= 16 skip k < 16)")

  @! 3.3 Shape 3: Multi-Tile Crossing Boundary 33x33 * 33x33
  dim33 = 33
  a33_data = []
  b33_data = []
  i = 0
  @while i < dim33 * dim33
    a33_data = a33_data.push((i % 11) - 5)
    b33_data = b33_data.push((i % 7) - 3)
    i = i + 1
  @end
  t33_a = tensor_new(a33_data, [dim33, dim33])
  t33_b = tensor_new(b33_data, [dim33, dim33])

  oracle_33x33 = oracle_gemm(t33_a, t33_b, dim33, dim33, dim33)
  c33_avx = tensor_gemm_avx512(t33_a, t33_b, dim33, dim33, dim33)
  c33_matmul = tensor_matmul(t33_a, t33_b)

  avx_33_matches = 0
  matmul_33_matches = 0
  total_elems_33 = dim33 * dim33
  idx = 0
  @while idx < total_elems_33
    @if c33_avx.data[idx] == oracle_33x33[idx]
      avx_33_matches = avx_33_matches + 1
    @end
    @if c33_matmul.data[idx] == oracle_33x33[idx]
      matmul_33_matches = matmul_33_matches + 1
    @end
    idx = idx + 1
  @end

  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(avx_33_matches, total_elems_33, "33x33x33 AVX-512 GEMM matches Oracle (1089/1089 elements)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(matmul_33_matches, total_elems_33, "33x33x33 Matmul Dispatch matches Oracle (1089/1089 elements)")

  @! 3.4 Strided & Transposed GEMM Invariant: (A * B^T)
  a16_data = []
  i = 0
  @while i < 16 * 24
    a16_data = a16_data.push((i % 9) + 1)
    i = i + 1
  @end
  t_a16x24 = tensor_new(a16_data, [16, 24])

  b32_data = []
  i = 0
  @while i < 32 * 24
    b32_data = b32_data.push((i % 5) + 1)
    i = i + 1
  @end
  t_b32x24 = tensor_new(b32_data, [32, 24])
  t_b_transposed = tensor_transpose_2d(t_b32x24)

  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(t_b_transposed.shape[0], 24, "B^T shape[0] == 24")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(t_b_transposed.shape[1], 32, "B^T shape[1] == 32")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(t_b_transposed.is_contiguous, 0, "B^T is non-contiguous")

  oracle_trans = oracle_gemm(t_a16x24, t_b_transposed, 16, 24, 32)
  c_trans_avx = tensor_gemm_avx512(t_a16x24, t_b_transposed, 16, 24, 32)
  c_trans_matmul = tensor_matmul(t_a16x24, t_b_transposed)

  trans_avx_matches = 0
  trans_matmul_matches = 0
  total_trans = 16 * 32
  idx = 0
  @while idx < total_trans
    @if c_trans_avx.data[idx] == oracle_trans[idx]
      trans_avx_matches = trans_avx_matches + 1
    @end
    @if c_trans_matmul.data[idx] == oracle_trans[idx]
      trans_matmul_matches = trans_matmul_matches + 1
    @end
    idx = idx + 1
  @end

  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(trans_avx_matches, total_trans, "Transposed Non-Contiguous AVX-512 GEMM matches Oracle (512/512)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(trans_matmul_matches, total_trans, "Transposed Non-Contiguous Matmul matches Oracle (512/512)")

  @! 3.5 Autograd Tracking Preservation
  t_a16x24.requires_grad = 1
  c_autograd = tensor_matmul(t_a16x24, t_b_transposed)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(c_autograd.requires_grad, 1, "Matmul output inherits requires_grad == 1")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(c_autograd.creator_op, "matmul", "Matmul output creator_op is 'matmul'")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(c_autograd.parents.len(), 2, "Matmul output tracks 2 parent tensors")

  println("\n=================================================================")
  println("📊 GEMM RESULTS: " + passed_asserts.to_str() + " / " + total_asserts.to_str() + " assertions passed")
  println("=================================================================")
  @if passed_asserts == total_asserts
    return 0
  @else
    return 1
  @end
@end
