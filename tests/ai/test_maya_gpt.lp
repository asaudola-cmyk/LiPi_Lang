@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MAYA-GPT & SAFETENSORS TEST SUITE
@! File: tests/ai/test_maya_gpt.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: ai, transformer, gpt, safetensors
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/transformer/gpt"

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

@fn main()
  println("=================================================================")
  println("🧠 MAYA-GPT (NATIVE TRANSFORMER LLM ENGINE) TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: SafeTensors Dynamic JSON Weights Header Parsing
  println("▶ Test 1: SafeTensors Dynamic JSON Weights Header Parsing...")
  total_tests = total_tests + 1
  json_test = "{\"__metadata__\":{\"format\":\"pt\"},\"model.layers.0.self_attn.q_proj.weight\":{\"dtype\":\"F16\",\"shape\":[4096,4096],\"data_offsets\":[2048,33556480]}}"
  hdr = safetensors_parse_header(json_test)
  ok1 = assert_true(contains(hdr.tensor_name, "self_attn"), "Parsed tensor parameter name")
  ok2 = assert_eq_int(hdr.data_offset, 2048, "Memory map data offset is 2048")
  ok3 = assert_eq_int(hdr.data_size_bytes, 33554432, "Data buffer size is 32MB")
  ok4 = assert_eq_int(hdr.shape_dims.len(), 2, "2D shape extracted")
  ok5 = assert_eq_int(hdr.shape_dims[0], 4096, "Dim 0 is 4096")
  ok6 = assert_eq_int(hdr.shape_dims[1], 4096, "Dim 1 is 4096")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: SafeTensors dynamic JSON header parsing verified")
  @end

  @! TEST 2: Multi-Tensor Parsing & 8-byte LE Size Header
  println("▶ Test 2: Multi-Tensor Parsing & Little-Endian File Header...")
  total_tests = total_tests + 1
  multi_json = "{\"tensor_a\":{\"dtype\":\"F32\",\"shape\":[128,256],\"data_offsets\":[0,131072]},\"tensor_b\":{\"dtype\":\"F16\",\"shape\":[64,64],\"data_offsets\":[131072,139264]}}"
  all_hdrs = safetensors_parse_all_headers(multi_json)
  m_ok1 = assert_eq_int(all_hdrs.len(), 2, "Parsed 2 tensors from dictionary")
  m_ok2 = assert_true(all_hdrs[0].tensor_name == "tensor_a", "First tensor is tensor_a")
  m_ok3 = assert_eq_int(all_hdrs[0].data_size_bytes, 131072, "tensor_a size is 131072")
  m_ok4 = assert_true(all_hdrs[1].tensor_name == "tensor_b", "Second tensor is tensor_b")
  m_ok5 = assert_eq_int(all_hdrs[1].data_size_bytes, 8192, "tensor_b size is 8192")

  @! 8-byte LE header prefix for size 258: [2, 1, 0, 0, 0, 0, 0, 0]
  dummy_bytes = [2, 1, 0, 0, 0, 0, 0, 0]
  dummy_size = safetensors_read_header_size(dummy_bytes)
  m_ok6 = assert_eq_int(dummy_size, 258, "8-byte LE header size computed as 258")

  @if m_ok1 == 1 && m_ok2 == 1 && m_ok3 == 1 && m_ok4 == 1 && m_ok5 == 1 && m_ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Multi-tensor dictionary & binary LE header decoding verified")
  @end

  @! TEST 3: Multi-Head FlashAttention Forward Pass
  println("▶ Test 3: Multi-Head FlashAttention Matrix Forward Pass...")
  total_tests = total_tests + 1
  q = [1, 2, 3, 4]
  k = [1, 2, 3, 4, 2, 3, 4, 5] @! 2 tokens x 4 head_dim
  v = [10, 20, 30, 40, 50, 60, 70, 80]
  out_attn = flash_attention_forward_head(q, k, v, 2, 4)
  
  fa_ok1 = assert_eq_int(out_attn.len(), 4, "FlashAttention output matches head dimension 4")
  fa_ok2 = assert_true(out_attn[0] > 0, "Non-zero attention weighted representation calculated")
  @if fa_ok1 == 1 && fa_ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Multi-head FlashAttention forward pass verified")
  @end

  @! TEST 4: KV-Cache Ring Buffer & Token Sampler
  println("▶ Test 4: KV-Cache Ring Buffer & Token Softmax Sampling...")
  total_tests = total_tests + 1
  gpt = gpt_transformer_init("Maya-GPT-7B", 32000, 4096, 32, 32)
  gpt.kv_cache = kv_cache_append(gpt.kv_cache, [1, 2, 3, 4], [10, 20, 30, 40])
  kv_ok1 = assert_eq_int(gpt.kv_cache.current_pos, 1, "KV-Cache advanced by 1 token step")
  
  cfg = { temperature: 70, top_k: 40, top_p: 90 }
  logits = [10, 50, 20, 95, 30]
  best_tok = gpt_sample_token(logits, cfg)
  kv_ok2 = assert_eq_int(best_tok, 3, "Token sampler correctly selected highest logit index 3 (95)")
  @if kv_ok1 == 1 && kv_ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: KV-cache retention and token sampling verified")
  @end

  @! TEST 5: Diverse Dtypes & Multi-Rank Tensor Header Parsing
  println("▶ Test 5: Diverse Dtypes (F32/F16/BF16/I32/I8) & Multi-Rank Shapes...")
  total_tests = total_tests + 1
  
  multi_type_json = "{\"embed.weight\":{\"dtype\":\"BF16\",\"shape\":[32000,4096],\"data_offsets\":[0,262144000]},\"norm.bias\":{\"dtype\":\"F32\",\"shape\":[4096],\"data_offsets\":[262144000,262160384]},\"conv.weight\":{\"dtype\":\"I8\",\"shape\":[64,3,7,7],\"data_offsets\":[262160384,262169792]}}"
  parsed_types = safetensors_parse_all_headers(multi_type_json)
  
  t_ok1 = assert_eq_int(parsed_types.len(), 3, "Parsed 3 diverse tensor definitions")
  t_ok2 = assert_true(parsed_types[0].data_type == "BF16", "Parsed BF16 embedding tensor")
  t_ok3 = assert_eq_int(parsed_types[0].shape_dims.len(), 2, "2D embedding shape extracted")
  t_ok4 = assert_true(parsed_types[1].data_type == "F32", "Parsed F32 bias vector")
  t_ok5 = assert_eq_int(parsed_types[1].shape_dims.len(), 1, "1D bias vector shape extracted")
  t_ok6 = assert_true(parsed_types[2].data_type == "I8", "Parsed I8 quantized conv tensor")
  t_ok7 = assert_eq_int(parsed_types[2].shape_dims.len(), 4, "4D conv tensor shape extracted")
  @if t_ok1 == 1 && t_ok2 == 1 && t_ok3 == 1 && t_ok4 == 1 && t_ok5 == 1 && t_ok6 == 1 && t_ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Diverse dtypes and multi-rank shapes verified")
  @end

  println("=================================================================")
  println("📊 MAYA-GPT TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 MAYA-GPT TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MAYA-GPT TESTS FAILED")
    return 1
  @end
@end
