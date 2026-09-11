@! ============================================================================
@! MAYA E2E TIER 1 — F14: Tensor Activations
@! File: tests/e2e/tier1_features/ai/test_f14_tensor_activations.maya
@! ============================================================================

import "universe/ai/tensor"

@fn main()
  inp = tensor_new([0 - 10, 0, 10], [3])
  rel = tensor_relu(inp)
  @if tensor_get(rel, [0]) != 0 return 1 @end
  @if tensor_get(rel, [1]) != 0 return 1 @end
  @if tensor_get(rel, [2]) != 10 return 1 @end

  sm = tensor_softmax_scaled(inp)
  s0 = tensor_get(sm, [0])
  s1 = tensor_get(sm, [1])
  s2 = tensor_get(sm, [2])
  tot = s0 + s1 + s2
  @if tot < 990 || tot > 1010 return 1 @end
  @if s2 <= s1 || s1 <= s0 return 1 @end
  println("✓ PASS: test_f14_tensor_activations")
  return 0
@end
