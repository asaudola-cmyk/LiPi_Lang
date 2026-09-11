@! ============================================================================
@! MAYA E2E TIER 1 — F16: Neural Network MultiHeadAttention
@! File: tests/e2e/tier1_features/ai/test_f16_nn_multihead_attention.maya
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/nn"

@fn main()
  mha = multihead_attention_new(4, 2)
  x = tensor_new([1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 4])
  out = multihead_attention_forward(mha, x, 0)
  @if out.shape.len() != 3 return 1 @end
  @if out.shape[0] != 1 || out.shape[1] != 2 || out.shape[2] != 4 return 1 @end
  println("✓ PASS: test_f16_nn_multihead_attention")
  return 0
@end
