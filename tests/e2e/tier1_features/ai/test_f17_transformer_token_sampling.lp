@! ============================================================================
@! MAYA E2E TIER 1 — F17: Transformer Token Sampling
@! File: tests/e2e/tier1_features/ai/test_f17_transformer_token_sampling.maya
@! ============================================================================

import "universe/ai/transformer/gpt"

@fn main()
  logits = [5, 100, 20, 10]
  cfg = { temperature: 100, top_k: 1, top_p: 100 }
  tok = gpt_sample_token(logits, cfg)
  @if tok != 1 return 1 @end
  println("✓ PASS: test_f17_transformer_token_sampling")
  return 0
@end
