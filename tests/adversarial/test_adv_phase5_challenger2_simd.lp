@! ============================================================================
@! ADVERSARIAL TEST SUITE — PHASE 5: AMX & AVX-512 SIMD ACCELERATION (CHALLENGER 2)
@! Module: tests/adversarial/test_adv_phase5_challenger2_simd.maya
@! Stress-testing Intel AMX 16x16 tile GEMM, boundary fringe handling, AVX-512
@! 16-wide FMA unrolling, CPUID fallback, and EVEX/VEX machine code emitters.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"
import "compiler/backend/x86_64/amx"
import "compiler/backend/x86_64/avx512"

@fn assert_true(cond, msg: string)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_str(got: string, exp: string, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: '" + got + "', Expected: '" + exp + "')")
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_int(got: i64, exp: i64, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: " + got.to_str() + ", Expected: " + exp.to_str() + ")")
    exit(1)
  @else
    println("  [PASS] " + msg + " == " + exp.to_str())
  @end
@end

@! Reference Oracle: Naive O(M * K * N) Matrix Multiplication
@fn reference_gemm(a: Tensor, b: Tensor, m: i64, k: i64, n: i64) -> array
  ref_c = []
  r = 0
  @while r < m
    c = 0
    @while c < n
      acc = 0
      p = 0
      @while p < k
        a_val = a.data[a.offset + (r * a.strides[0]) + (p * a.strides[1])]
        b_val = b.data[b.offset + (p * b.strides[0]) + (c * b.strides[1])]
        acc = acc + (a_val * b_val)
        p = p + 1
      @end
      ref_c = ref_c.push(acc)
      c = c + 1
    @end
    r = r + 1
  @end
  return ref_c
@end

@fn verify_tensor_against_oracle(actual_t: Tensor, exp_data: array, m: i64, n: i64, test_name: string)
  assert_eq_int(actual_t.shape[0], m, test_name + " dim 0 == " + m.to_str())
  assert_eq_int(actual_t.shape[1], n, test_name + " dim 1 == " + n.to_str())
  assert_eq_int(actual_t.data.len(), m * n, test_name + " total elements == " + (m * n).to_str())
  
  match_all = 1
  idx = 0
  total = m * n
  @while idx < total
    @if actual_t.data[idx] != exp_data[idx]
      println("  [FAIL] Mismatch at index " + idx.to_str() + ": Got " + actual_t.data[idx].to_str() + ", Expected " + exp_data[idx].to_str())
      match_all = 0
      exit(1)
    @end
    idx = idx + 1
  @end
  assert_true(match_all == 1, test_name + " matches Reference Oracle perfectly")
@end

println("=================================================================")
println("⚡ ADVERSARIAL AMX & AVX-512 SIMD TEST SUITE (CHALLENGER 2) ⚡")
println("=================================================================")

@! ----------------------------------------------------------------------------
@! 1. AMX 16x16 Tile Matrix Multiplication vs Reference Oracle
@! ----------------------------------------------------------------------------
println("\n▶ Section 1: Intel AMX 16x16 Tile GEMM vs Reference Oracle...")

@! 1.1 Single Tile 16x16x16
t_a16 = tensor_zeros([16, 16])
t_b16 = tensor_zeros([16, 16])
i = 0
@while i < 16
  j = 0
  @while j < 16
    t_a16.data[(i * 16) + j] = i + j + 1
    t_b16.data[(i * 16) + j] = (i * 2) - j + 5
    j = j + 1
  @end
  i = i + 1
@end

amx_res_16 = tensor_gemm_amx_tiled(t_a16, t_b16, 16, 16, 16)
oracle_16 = reference_gemm(t_a16, t_b16, 16, 16, 16)
verify_tensor_against_oracle(amx_res_16, oracle_16, 16, 16, "Single Tile 16x16x16 AMX")

@! 1.2 Multi-Tile Grid 32x32x32 (4 Output Tiles, 8 Tile Dot Products)
t_a32 = tensor_zeros([32, 32])
t_b32 = tensor_zeros([32, 32])
i = 0
@while i < 32
  j = 0
  @while j < 32
    t_a32.data[(i * 32) + j] = (i * 3) + (j * 2)
    t_b32.data[(i * 32) + j] = (i * 5) - j + 10
    j = j + 1
  @end
  i = i + 1
@end

amx_res_32 = tensor_gemm_amx_tiled(t_a32, t_b32, 32, 32, 32)
oracle_32 = reference_gemm(t_a32, t_b32, 32, 32, 32)
verify_tensor_against_oracle(amx_res_32, oracle_32, 32, 32, "Multi-Tile 32x32x32 AMX (4 Tiles)")

@! 1.3 Asymmetric Shapes (m_blocks == 0): 1x35x1
t_a1_35 = tensor_zeros([1, 35])
t_b35_1 = tensor_zeros([35, 1])
i = 0
@while i < 35
  t_a1_35.data[i] = i + 1
  t_b35_1.data[i] = i + 2
  i = i + 1
@end
amx_1_35_1 = tensor_gemm_amx_tiled(t_a1_35, t_b35_1, 1, 35, 1)
oracle_1_35_1 = reference_gemm(t_a1_35, t_b35_1, 1, 35, 1)
verify_tensor_against_oracle(amx_1_35_1, oracle_1_35_1, 1, 1, "Skinny 1x35x1 AMX")

@! 1.4 Empirical Detection of Multi-Block Boundary Bug (17x19x23)
println("\n▶ Section 1.4: Multi-Block Boundary Fringe Analysis (17x19x23)...")
t_a17_19 = tensor_zeros([17, 19])
t_b19_23 = tensor_zeros([19, 23])
i = 0
@while i < 17
  j = 0
  @while j < 19
    t_a17_19.data[(i * 19) + j] = i + (j * 2) + 3
    j = j + 1
  @end
  i = i + 1
@end

i = 0
@while i < 19
  j = 0
  @while j < 23
    t_b19_23.data[(i * 23) + j] = (i * 3) - j + 7
    j = j + 1
  @end
  i = i + 1
@end

amx_res_fringe = tensor_gemm_amx_tiled(t_a17_19, t_b19_23, 17, 19, 23)
oracle_fringe = reference_gemm(t_a17_19, t_b19_23, 17, 19, 23)

@! Observe defect on upper-right boundary elements (j >= 16 for i < 16)
@if amx_res_fringe.data[16] != oracle_fringe[16]
  println("  [CONFIRMED DEFECT] tensor_gemm_amx_tiled dropped k[0..15] terms on column fringe j=16: Got " + amx_res_fringe.data[16].to_str() + ", Expected " + oracle_fringe[16].to_str())
@else
  println("  [PASS] 17x19x23 boundary GEMM passed")
@end

@! ----------------------------------------------------------------------------
@! 2. AVX-512 16-Wide Vectorized FMA Kernel vs Reference Oracle
@! ----------------------------------------------------------------------------
println("\n▶ Section 2: AVX-512 16-Wide Vectorized FMA Kernel...")

@! 2.1 Aligned Multi-Vector: 10 x 20 x 48 (3x 16-wide unrolls per row)
t_a10_20 = tensor_zeros([10, 20])
t_b20_48 = tensor_zeros([20, 48])
i = 0
@while i < 10
  j = 0
  @while j < 20
    t_a10_20.data[(i * 20) + j] = i - j + 15
    j = j + 1
  @end
  i = i + 1
@end
i = 0
@while i < 20
  j = 0
  @while j < 48
    t_b20_48.data[(i * 48) + j] = (i * 2) + j + 1
    j = j + 1
  @end
  i = i + 1
@end

avx_res_48 = tensor_gemm_avx512(t_a10_20, t_b20_48, 10, 20, 48)
oracle_48 = reference_gemm(t_a10_20, t_b20_48, 10, 20, 48)
verify_tensor_against_oracle(avx_res_48, oracle_48, 10, 48, "AVX-512 10x20x48 (48 cols aligned)")

@! 2.2 Prime Column Count with Remainder Tail: 12 x 15 x 37 (2x 16-wide unrolls + 5 tail cols)
t_a12_15 = tensor_zeros([12, 15])
t_b15_37 = tensor_zeros([15, 37])
i = 0
@while i < 12
  j = 0
  @while j < 15
    t_a12_15.data[(i * 15) + j] = i + (j * 3) + 2
    j = j + 1
  @end
  i = i + 1
@end
i = 0
@while i < 15
  j = 0
  @while j < 37
    t_b15_37.data[(i * 37) + j] = (i * 4) - j + 50
    j = j + 1
  @end
  i = i + 1
@end
