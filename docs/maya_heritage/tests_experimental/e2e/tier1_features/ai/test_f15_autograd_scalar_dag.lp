@! ============================================================================
@! MAYA E2E TIER 1 — F15: Autograd Scalar DAG
@! File: tests/e2e/tier1_features/ai/test_f15_autograd_scalar_dag.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@fn main()
  x = leaf_tensor([3], [1])
  x2 = tensor_mul(x, x)
  y = tensor_scale(x2, 2) @! y = 2*x^2 -> dy/dx = 4*x = 12
  tensor_backward(y)
  @if x.grad[0] != 12 return 1 @end
  println("✓ PASS: test_f15_autograd_scalar_dag")
  return 0
@end
