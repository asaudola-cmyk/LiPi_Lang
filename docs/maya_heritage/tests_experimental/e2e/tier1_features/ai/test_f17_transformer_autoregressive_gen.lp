@! ============================================================================
@! MAYA E2E TIER 1 — F17: Transformer Autoregressive Generation
@! File: tests/e2e/tier1_features/ai/test_f17_transformer_autoregressive_gen.maya
@! ============================================================================

import "universe/ai/transformer/gpt"

@fn main()
  kv = kv_cache_new(100, 16, 2)
  cfg = { temperature: 100, top_k: 1, top_p: 100 }
  
  tokens_gen = []
  step = 0
  @while step < 5
    fake_logits = [0, 0, 0, 0, 0]
    fake_logits[step] = 100
    next_tok = gpt_sample_token(fake_logits, cfg)
    tokens_gen = tokens_gen.push(next_tok)
    kv = kv_cache_append(kv, [next_tok], [next_tok])
    step = step + 1
  @end

  @if tokens_gen.len() != 5 return 1 @end
  @if kv.current_pos != 5 return 1 @end
  println("✓ PASS: test_f17_transformer_autoregressive_gen")
  return 0
@end
