@! ============================================================================
@! MAYA E2E TIER 1 — F14: Tensor Transcendental Math
@! File: tests/e2e/tier1_features/ai/test_f14_tensor_transcendental_math.maya
@! ============================================================================

import "universe/ai/tensor"

@fn main()
  sq = tensor_math_sqrt(25.0)
  @if sq < 4.99 || sq > 5.01 return 1 @end
  ab = math_abs(0.0 - 42.0)
  @if ab != 42.0 return 1 @end
  ex = math_exp(0.0)
  @if ex < 0.99 || ex > 1.01 return 1 @end
  println("✓ PASS: test_f14_tensor_transcendental_math")
  return 0
@end
