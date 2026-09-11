@! ============================================================================
@! MAYA E2E TIER 1 — F16: Neural Network Optimizer Step
@! File: tests/e2e/tier1_features/ai/test_f16_nn_optimizer_step.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"
import "universe/ai/nn"

@fn main()
  w = leaf_tensor([100], [1])
  w.grad = [10]
  sgd = optimizer_sgd_create([w], 5, 0, 0)
  optimizer_sgd_step([w], 5, 0, 0, sgd.velocities)
  @! w_new = 100 - (5 * 10) = 50
  @if w.data[0] != 50 return 1 @end
  println("✓ PASS: test_f16_nn_optimizer_step")
  return 0
@end
