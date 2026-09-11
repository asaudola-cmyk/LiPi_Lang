@! ============================================================================
@! MAYA E2E TIER 1 — F17: Transformer Block
@! File: tests/e2e/tier1_features/ai/test_f17_transformer_block.maya
@! ============================================================================

import "universe/ai/transformer/gpt"

@fn main()
  m = gpt_transformer_init("transformer_block_test", 1000, 128, 4, 2)
  @if m.hidden_dim != 128 || m.num_heads != 4 || m.head_dim != 32 return 1 @end
  println("✓ PASS: test_f17_transformer_block")
  return 0
@end
