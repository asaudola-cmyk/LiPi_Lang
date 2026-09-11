@! ============================================================================
@! MAYA E2E TIER 1 — F16: Neural Network LayerNorm
@! File: tests/e2e/tier1_features/ai/test_f16_nn_layer_norm.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/nn"

@fn main()
  ln = layernorm_new(3, 1.0)
  x = tensor_new([10, 20, 30], [1, 3])
  y = layernorm_forward(ln, x)
  @if y.shape[0] != 1 || y.shape[1] != 3 return 1 @end
  @if tensor_get(y, [0, 0]) >= 0 return 1 @end @! 10 is below mean 20 -> negative
  @if tensor_get(y, [0, 2]) <= 0 return 1 @end @! 30 is above mean 20 -> positive
  println("✓ PASS: test_f16_nn_layer_norm")
  return 0
@end
