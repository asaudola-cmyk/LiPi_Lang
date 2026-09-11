@! ============================================================================
@! MAYA E2E TIER 1 — F16: Neural Network Linear Layer
@! File: tests/e2e/tier1_features/ai/test_f16_nn_linear_layer.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/nn"

@fn main()
  lin = linear_new(2, 2)
  lin.weight.data = [1, 0, 0, 1] @! Identity
  lin.bias.data = [5, 5]
  x = tensor_new([10, 20], [1, 2])
  y = linear_forward(lin, x)
  @! y = [10+5, 20+5] = [15, 25]
  @if tensor_get(y, [0, 0]) != 15 return 1 @end
  @if tensor_get(y, [0, 1]) != 25 return 1 @end
  println("✓ PASS: test_f16_nn_linear_layer")
  return 0
@end
