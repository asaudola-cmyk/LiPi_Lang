@! ============================================================================
@! MAYA E2E TIER 1 — F15: Autograd Matmul Backward
@! File: tests/e2e/tier1_features/ai/test_f15_autograd_matmul_backward.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@fn main()
  a = leaf_tensor([1, 2, 3, 4], [2, 2])
  b = leaf_tensor([1, 0, 0, 1], [2, 2]) @! Identity matrix
  c = tensor_matmul(a, b)
  loss = tensor_sum(c, 0 - 1, 0)
  tensor_backward(loss)
  @! dA = ones(2,2) * I = ones(2,2) = [1, 1, 1, 1]
  @if a.grad[0] != 1 || a.grad[1] != 1 || a.grad[2] != 1 || a.grad[3] != 1 return 1 @end
  println("✓ PASS: test_f15_autograd_matmul_backward")
  return 0
@end
