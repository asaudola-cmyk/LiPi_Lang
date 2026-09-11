@! ============================================================================
@! MAYA E2E TIER 1 — F17: Transformer KV Cache
@! File: tests/e2e/tier1_features/ai/test_f17_transformer_kv_cache.maya
@! ============================================================================

import "universe/ai/transformer/gpt"

@fn main()
  kv = kv_cache_new(512, 32, 2)
  kv = kv_cache_append(kv, [1, 2], [10, 20])
  @if kv.current_pos != 1 return 1 @end
  @if kv.k_cache_flat.len() != 2 || kv.v_cache_flat.len() != 2 return 1 @end
  println("✓ PASS: test_f17_transformer_kv_cache")
  return 0
@end
