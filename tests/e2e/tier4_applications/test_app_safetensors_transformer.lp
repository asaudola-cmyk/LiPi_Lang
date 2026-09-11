@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: FULL TRANSFORMER SAFETENSORS INFERENCE
@! File: tests/e2e/tier4_applications/test_app_safetensors_transformer.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! TAGS: tier4, applications, transformer, safetensors, gpt, inference
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/transformer/gpt"
import "universe/ai/tensor"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@! ============================================================================
@! TRANSFORMER WEIGHT STRUCT & INFERENCE ENGINE
@! ============================================================================

@struct TransformerWeights
  w_embed: Tensor
  w_q: Tensor
  w_k: Tensor
  w_v: Tensor
  w_out: Tensor
  w_mlp_up: Tensor
  w_mlp_down: Tensor
  w_lm_head: Tensor
@end

@fn main()
  println("=================================================================")
  println("🚀 TIER 4: AUTOREGRESSIVE TRANSFORMER WITH SAFETENSORS INFERENCE 🚀")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! STAGE 1: SafeTensors Weight Ingestion & Model Configuration
  println("▶ Stage 1: Parsing SafeTensors Model Weights...")
  total_tests = total_tests + 1
  
  st_meta = "{\"embed.weight\":{\"dtype\":\"F32\",\"shape\":[8,4],\"data_offsets\":[0,128]},\"attn.q_proj\":{\"dtype\":\"F32\",\"shape\":[4,4],\"data_offsets\":[128,192]},\"attn.k_proj\":{\"dtype\":\"F32\",\"shape\":[4,4],\"data_offsets\":[192,256]},\"attn.v_proj\":{\"dtype\":\"F32\",\"shape\":[4,4],\"data_offsets\":[256,320]},\"attn.out_proj\":{\"dtype\":\"F32\",\"shape\":[4,4],\"data_offsets\":[320,384]},\"mlp.up_proj\":{\"dtype\":\"F32\",\"shape\":[4,8],\"data_offsets\":[384,512]},\"mlp.down_proj\":{\"dtype\":\"F32\",\"shape\":[8,4],\"data_offsets\":[512,640]},\"lm_head.weight\":{\"dtype\":\"F32\",\"shape\":[4,8],\"data_offsets\":[640,768]}}"
  headers = safetensors_parse_all_headers(st_meta)
  
  ok1_1 = assert_eq_int(headers.len(), 8, "Loaded 8 SafeTensors transformer layer weights")
  ok1_2 = assert_true(headers[0].tensor_name == "embed.weight", "Weight 0 is embedding table")
  ok1_3 = assert_true(headers[7].tensor_name == "lm_head.weight", "Weight 7 is LM head")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 1: SafeTensors weights parsed")
  @end

  @! STAGE 2: Constructing Model Tensors & KV-Cache
  println("▶ Stage 2: Initializing Transformer Parameters & KV-Cache Ring...")
  total_tests = total_tests + 1
  
  @! Vocabulary size 8, Hidden dim 4
  embed_table = [
    0.1, 0.2, 0.3, 0.4,
    0.5, 0.6, 0.7, 0.8,
    0.9, 1.0, 1.1, 1.2,
    1.3, 1.4, 1.5, 1.6,
    1.7, 1.8, 1.9, 2.0,
    2.1, 2.2, 2.3, 2.4,
    2.5, 2.6, 2.7, 2.8,
    2.9, 3.0, 3.1, 3.2
  ]
  
  eye4 = [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
  ]
  
  mlp_up_data = []
  i = 0
  @while i < 32
    mlp_up_data = mlp_up_data.push(1.0)
    i = i + 1
  @end
  
  mlp_down_data = []
  i = 0
  @while i < 32
    mlp_down_data = mlp_down_data.push(0.25)
    i = i + 1
  @end
  
  head_data = [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0
  ]
  
  t_w_embed = tensor_new(embed_table, [8, 4])
  t_w_q = tensor_new(eye4, [4, 4])
  t_w_k = tensor_new(eye4, [4, 4])
  t_w_v = tensor_new(eye4, [4, 4])
  t_w_out = tensor_new(eye4, [4, 4])
  t_w_up = tensor_new(mlp_up_data, [4, 8])
  t_w_down = tensor_new(mlp_down_data, [8, 4])
  t_w_head = tensor_new(head_data, [4, 8])
  
  weights = {
    w_embed: t_w_embed,
    w_q: t_w_q,
    w_k: t_w_k,
    w_v: t_w_v,
    w_out: t_w_out,
    w_mlp_up: t_w_up,
    w_mlp_down: t_w_down,
    w_lm_head: t_w_head
  }
  
  gpt_model = gpt_transformer_init("Maya-Tiny-Transformer", 8, 4, 1, 1)
  ok2_1 = assert_eq_int(gpt_model.vocab_size, 8, "Vocab size 8")
  ok2_2 = assert_eq_int(gpt_model.hidden_dim, 4, "Hidden dimension 4")
  ok2_3 = assert_eq_int(gpt_model.kv_cache.current_pos, 0, "KV-cache initialized empty at position 0")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 2: Transformer model parameters initialized")
  @end

  @! STAGE 3: Single Token Forward Step & FlashAttention
  println("▶ Stage 3: Executing Single Token Forward Step (Attention + MLP + LM Head)...")
  total_tests = total_tests + 1
  
  @! Prompt token ID = 2 (Embedding: [0.9, 1.0, 1.1, 1.2])
  tok_id = 2
  tok_embed = [
    embed_table[tok_id * 4 + 0],
    embed_table[tok_id * 4 + 1],
    embed_table[tok_id * 4 + 2],
    embed_table[tok_id * 4 + 3]
  ]
  t_x = tensor_new(tok_embed, [1, 4])
  
  @! 1. Attention Projections: Q = X * Wq, K = X * Wk, V = X * Wv
  t_q = tensor_matmul(t_x, weights.w_q)
  t_k = tensor_matmul(t_x, weights.w_k)
  t_v = tensor_matmul(t_x, weights.w_v)
  
  @! 2. FlashAttention head forward
  kv = gpt_model.kv_cache
  kv = kv_cache_append(kv, t_k.data, t_v.data)
  attn_out = flash_attention_forward_head(t_q.data, kv.k_cache_flat, kv.v_cache_flat, 1, 4)
  t_attn = tensor_new(attn_out, [1, 4])
  
  @! 3. Residual connection: X + Attn(X)
  t_res1 = tensor_add(t_x, t_attn)
  
  @! 4. MLP Block: (Res1 * W_up) -> ReLU -> (* W_down) -> + Res1
  t_up = tensor_matmul(t_res1, weights.w_mlp_up)
  t_act = tensor_relu(t_up)
  t_down = tensor_matmul(t_act, weights.w_mlp_down)
  t_hidden = tensor_add(t_res1, t_down)
  
  @! 5. LM Head: Logits = Hidden * W_lm_head (1x4) x (4x8) -> (1x8)
  t_logits = tensor_matmul(t_hidden, weights.w_lm_head)
  
  ok3_1 = assert_eq_int(t_logits.shape[0], 1, "Logits row == 1")
  ok3_2 = assert_eq_int(t_logits.shape[1], 8, "Logits vocab dimension == 8")
  ok3_3 = assert_true(t_logits.data[2] > 0.0, "Active token logit is positive")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 3: Single token forward pass verified")
  @end

  @! STAGE 4: Multi-Step Autoregressive Generation Loop
  println("▶ Stage 4: Multi-Step Autoregressive Generation Loop (3 Steps)...")
  total_tests = total_tests + 1
  
  gen_tokens = [tok_id]
  step = 0
  sampler = { temperature: 70, top_k: 4, top_p: 90 }
  
  @while step < 3
    next_tok = gpt_sample_token(t_logits.data, sampler)
    gen_tokens = gen_tokens.push(next_tok)
    
    @! Update step and append next token embedding
    next_embed = [
      embed_table[next_tok * 4 + 0],
      embed_table[next_tok * 4 + 1],
      embed_table[next_tok * 4 + 2],
      embed_table[next_tok * 4 + 3]
    ]
    t_next_x = tensor_new(next_embed, [1, 4])
    t_next_q = tensor_matmul(t_next_x, weights.w_q)
    t_next_k = tensor_matmul(t_next_x, weights.w_k)
    t_next_v = tensor_matmul(t_next_x, weights.w_v)
    
    kv = kv_cache_append(kv, t_next_k.data, t_next_v.data)
    next_attn = flash_attention_forward_head(t_next_q.data, kv.k_cache_flat, kv.v_cache_flat, step + 2, 4)
    t_next_attn = tensor_new(next_attn, [1, 4])
    t_next_res = tensor_add(t_next_x, t_next_attn)
    t_next_up = tensor_matmul(t_next_res, weights.w_mlp_up)
    t_next_down = tensor_matmul(tensor_relu(t_next_up), weights.w_mlp_down)
    t_next_hidden = tensor_add(t_next_res, t_next_down)
    t_logits = tensor_matmul(t_next_hidden, weights.w_lm_head)
    
    step = step + 1
  @end

  ok4_1 = assert_eq_int(gen_tokens.len(), 4, "Generated 4 tokens total (1 prompt + 3 autoregressive)")
  ok4_2 = assert_eq_int(kv.current_pos, 4, "KV-cache holds 4 token history states")
  
  @if ok4_1 == 1 && ok4_2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Stage 4: Multi-step autoregressive generation loop verified")
  @end

  println("=================================================================")
  println("📊 TIER 4 TRANSFORMER RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 TIER 4 TRANSFORMER INFERENCE TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TIER 4 TRANSFORMER TESTS FAILED")
    return 1
  @end
@end
