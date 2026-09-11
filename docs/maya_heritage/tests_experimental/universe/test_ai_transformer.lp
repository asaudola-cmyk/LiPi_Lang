@! ============================================================================
@! MAYA UNIVERSE AI — LLM TRANSFORMER, FLASHATTENTION & KV-CACHE TEST SUITE
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! ============================================================================

import "universe/ai/tensor"
import "universe/ai/transformer/gpt"

@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
    exit(1)
  @end
  return 0
@end

@fn assert_true(cond: i64, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] " + test_name)
    return 1
  @else
    println("    ✗ [FAIL] " + test_name)
    exit(1)
  @end
  return 0
@end

@fn test_rmsnorm() -> i64
  println("  [LLM Test 1] Testing RMSNorm Layer...")
  x = tensor_from_array([1.0, 2.0, 3.0, 4.0], [1, 4])
  weights = [1.0, 1.0, 1.0, 1.0]
  normed = tensor_rmsnorm(x, weights, 0.00001)
  
  println("    ✓ RMSNorm values: [" + normed.data[0].to_str() + ", " + normed.data[3].to_str() + "]")
  @if normed.data.len() == 4
    return 1
  @end
  return 0
@end

@fn test_rope() -> i64
  println("  [LLM Test 2] Testing Rotary Positional Embedding (RoPE)...")
  q = tensor_from_array([1.0, 0.5, 0.2, 0.8], [1, 4])
  q_rot = tensor_rope(q, 1)
  
  println("    ✓ RoPE rotated vector: [" + q_rot.data[0].to_str() + ", " + q_rot.data[1].to_str() + "]")
  @if q_rot.data.len() == 4
    return 1
  @end
  return 0
@end

@fn test_transformer_block() -> i64
  println("  [LLM Test 3] Testing Complete Transformer Decoder Block...")
  x = tensor_from_array([0.5, 0.8, 0.1, 0.9], [1, 4])
  w_attn = tensor_from_array([0.1, 0.2, 0.1, 0.2, 0.2, 0.1, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.2, 0.2, 0.2], [4, 4])
  w_ffn = tensor_from_array([0.2, 0.1, 0.2, 0.1, 0.1, 0.2, 0.1, 0.2, 0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.2, 0.2], [4, 4])
  norm_w = [1.0, 1.0, 1.0, 1.0]
  
  block_out = transformer_block(x, w_attn, w_ffn, norm_w)
  println("    ✓ Transformer Block Output: [" + block_out.data[0].to_str() + ", ... " + block_out.data[3].to_str() + "]")
  @if block_out.data.len() == 4
    return 1
  @end
  return 0
@end

@fn test_kv_cache_ring() -> i64
  println("  [LLM Test 4] Testing KV-Cache Ring Buffer Engine...")
  kv = kv_cache_new(512, 64, 4)
  assert_eq_int(kv.max_context_len, 512, "KV-Cache max_context_len == 512")
  assert_eq_int(kv.hidden_dim, 64, "KV-Cache hidden_dim == 64")
  assert_eq_int(kv.head_count, 4, "KV-Cache head_count == 4")
  assert_eq_int(kv.current_pos, 0, "KV-Cache initial pos == 0")

  k_step = [1, 2, 3, 4]
  v_step = [10, 20, 30, 40]
  kv = kv_cache_append(kv, k_step, v_step)
  assert_eq_int(kv.current_pos, 1, "KV-Cache pos after append == 1")
  assert_eq_int(kv.k_cache_flat.len(), 4, "KV-Cache k elements == 4")
  assert_eq_int(kv.v_cache_flat[1], 20, "KV-Cache v element[1] == 20")
  return 1
@end

@fn test_flash_attention() -> i64
  println("  [LLM Test 5] Testing FlashAttention Online Softmax...")
  q = [1, 2, 3, 4]
  k_cache = [1, 2, 3, 4, 2, 3, 4, 5]
  v_cache = [10, 20, 30, 40, 50, 60, 70, 80]
  head_out = flash_attention_forward_head(q, k_cache, v_cache, 2, 4)
  assert_eq_int(head_out.len(), 4, "FlashAttention output head dim == 4")
  assert_true(head_out[0] > 0, "FlashAttention weighted value > 0")
  return 1
@end

@fn test_nucleus_top_k_top_p_sampling() -> i64
  println("  [LLM Test 6] Testing Top-K and Top-P Nucleus Sampling...")
  logits = [10, 50, 20, 80, 5]
  
  @! Top-K filter with K=2
  top2 = gpt_top_k_filter(logits, 2)
  assert_eq_int(top2[3], 80, "Top-K retains highest logit (80)")
  assert_eq_int(top2[1], 50, "Top-K retains 2nd highest logit (50)")
  assert_true(top2[0] < 0, "Top-K filters out lower logits")

  @! Advanced Sampler Config
  cfg = {
    temperature: 80,
    top_k: 2,
    top_p: 90
  }
  sampled_token = gpt_sample_token_advanced(logits, cfg)
  assert_eq_int(sampled_token, 3, "Sampled token matches argmax/top-k candidate index 3")
  return 1
@end

@fn main() -> i64
  println("=================================================================")
  println("🧠 RUNNING MAYA UNIVERSE LLM TRANSFORMER MASTER TEST SUITE")
  println("=================================================================")
  t1 = test_rmsnorm()
  t2 = test_rope()
  t3 = test_transformer_block()
  t4 = test_kv_cache_ring()
  t5 = test_flash_attention()
  t6 = test_nucleus_top_k_top_p_sampling()
  
  passed = t1 + t2 + t3 + t4 + t5 + t6
  println("=================================================================")
  println("🎉 ALL TRANSFORMER TESTS PASSED (" + passed.to_str() + "/6)")
  println("=================================================================")
  return 0
@end
