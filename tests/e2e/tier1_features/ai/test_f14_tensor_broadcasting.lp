@! ============================================================================
@! MAYA E2E TIER 1 — F14: Tensor Broadcasting
@! File: tests/e2e/tier1_features/ai/test_f14_tensor_broadcasting.maya
@! ============================================================================

import "universe/ai/tensor"

@fn main()
  mat = tensor_new([1, 2, 3, 4, 5, 6], [2, 3])
  bias = tensor_new([10, 20, 30], [1, 3])
  res = tensor_add(mat, bias)
  @if res.shape[0] != 2 || res.shape[1] != 3 return 1 @end
  @if tensor_get(res, [0, 0]) != 11 return 1 @end
  @if tensor_get(res, [0, 1]) != 22 return 1 @end
  @if tensor_get(res, [0, 2]) != 33 return 1 @end
  @if tensor_get(res, [1, 0]) != 14 return 1 @end
  @if tensor_get(res, [1, 1]) != 25 return 1 @end
  @if tensor_get(res, [1, 2]) != 36 return 1 @end
  println("✓ PASS: test_f14_tensor_broadcasting")
  return 0
@end
