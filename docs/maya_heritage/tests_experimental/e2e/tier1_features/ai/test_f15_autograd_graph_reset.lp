@! ============================================================================
@! MAYA E2E TIER 1 — F15: Autograd Graph Reset
@! File: tests/e2e/tier1_features/ai/test_f15_autograd_graph_reset.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/autograd"

@fn main()
  w = leaf_tensor([5, 10], [2])
  w.grad = [100, 200]
  tensor_zero_grad(w)
  @if w.grad[0] != 0 || w.grad[1] != 0 return 1 @end
  println("✓ PASS: test_f15_autograd_graph_reset")
  return 0
@end
