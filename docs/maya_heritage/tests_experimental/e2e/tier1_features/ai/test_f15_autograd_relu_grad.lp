@! ============================================================================
@! MAYA E2E TIER 1 — F15: Autograd ReLU Grad
@! File: tests/e2e/tier1_features/ai/test_f15_autograd_relu_grad.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@fn main()
  x = leaf_tensor([0 - 5, 10], [2])
  y = tensor_relu(x)
  loss = tensor_sum(y, 0 - 1, 0)
  tensor_backward(loss)
  @! Gradient of ReLU: 0 for negative, 1 for positive
  @if x.grad[0] != 0 || x.grad[1] != 1 return 1 @end
  println("✓ PASS: test_f15_autograd_relu_grad")
  return 0
@end
