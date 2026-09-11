@! ============================================================================
@! MAYA E2E TIER 1 — F16: Neural Network Loss Functions
@! File: tests/e2e/tier1_features/ai/test_f16_nn_loss_functions.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/nn"

@fn main()
  pred = tensor_new([10, 20], [1, 2])
  target = tensor_new([10, 20], [1, 2])
  res = loss_mse(pred, target)
  @! Since pred == target, loss is 0
  @if res.loss.data[0] != 0 return 1 @end
  println("✓ PASS: test_f16_nn_loss_functions")
  return 0
@end
