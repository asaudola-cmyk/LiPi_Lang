@! ============================================================================
@! MAYA E2E TIER 1 — F14: Tensor GEMM Matmul
@! File: tests/e2e/tier1_features/ai/test_f14_tensor_gemm_matmul.maya
@! ============================================================================

import "universe/ai/tensor"

@fn main()
  a = tensor_new([1, 2, 3, 4], [2, 2])
  b = tensor_new([5, 6, 7, 8], [2, 2])
  c = tensor_matmul(a, b)
  @! c = [[1*5+2*7, 1*6+2*8], [3*5+4*7, 3*6+4*8]] = [[19, 22], [43, 50]]
  @if c.shape[0] != 2 || c.shape[1] != 2 return 1 @end
  @if tensor_get(c, [0, 0]) != 19 return 1 @end
  @if tensor_get(c, [0, 1]) != 22 return 1 @end
  @if tensor_get(c, [1, 0]) != 43 return 1 @end
  @if tensor_get(c, [1, 1]) != 50 return 1 @end
  println("✓ PASS: test_f14_tensor_gemm_matmul")
  return 0
@end
