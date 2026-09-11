@! ============================================================================
@! MAYA E2E TIER 1 — F14: Tensor Creation & Strides
@! File: tests/e2e/tier1_features/ai/test_f14_tensor_creation_strides.maya
@! ============================================================================

import "universe/ai/tensor"

@fn main()
  t = tensor_new([1, 2, 3, 4, 5, 6], [2, 3])
  @if t.ndim != 2 return 1 @end
  @if t.size != 6 return 1 @end
  @if t.strides[0] != 3 return 1 @end
  @if t.strides[1] != 1 return 1 @end
  @if t.is_contiguous != 1 return 1 @end
  println("✓ PASS: test_f14_tensor_creation_strides")
  return 0
@end
