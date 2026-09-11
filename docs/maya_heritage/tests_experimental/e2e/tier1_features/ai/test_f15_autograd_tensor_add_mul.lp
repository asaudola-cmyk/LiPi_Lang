@! ============================================================================
@! MAYA E2E TIER 1 — F15: Autograd Tensor Add & Mul
@! File: tests/e2e/tier1_features/ai/test_f15_autograd_tensor_add_mul.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@fn main()
  a = leaf_tensor([2, 3], [2])
  b = leaf_tensor([4, 5], [2])
  c = tensor_mul(a, b)
  loss = tensor_sum(c, 0 - 1, 0)
  tensor_backward(loss)
  @! dLoss/da = b = [4, 5], dLoss/db = a = [2, 3]
  @if a.grad[0] != 4 || a.grad[1] != 5 return 1 @end
  @if b.grad[0] != 2 || b.grad[1] != 3 return 1 @end
  println("✓ PASS: test_f15_autograd_tensor_add_mul")
  return 0
@end
