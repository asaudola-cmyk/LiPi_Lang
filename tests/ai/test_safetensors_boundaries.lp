@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — SAFETENSORS BOUNDARIES & STRESS TEST SUITE
@! File: tests/ai/test_safetensors_boundaries.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: ai, safetensors, boundaries
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
  println("🧠 SAFETENSORS DYNAMIC BOUNDARIES & STRESS TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Large Header Stress (500+ Tensors Parsing)
  println("▶ Test 1: Large Header Stress (500+ Tensors Parsing)...")
  total_tests = total_tests + 1
  
  @! Generate JSON dictionary with 500 layers
  json_large = "{"
  idx = 0
  curr_off = 0
  @while idx < 500
    next_off = curr_off + 4096
    t_entry = "\"layer." + idx.to_str() + ".weight\":{\"dtype\":\"F16\",\"shape\":[64,32],\"data_offsets\":[" + curr_off.to_str() + "," + next_off.to_str() + "]}"
    @if idx < 499
      t_entry = t_entry + ","
    @end
    json_large = json_large + t_entry
    curr_off = next_off
    idx = idx + 1
  @end
  json_large = json_large + "}"

  parsed_large = safetensors_parse_all_headers(json_large)
  ok1_1 = assert_eq_int(parsed_large.len(), 500, "Successfully parsed all 500 tensor headers in streaming JSON")
  ok1_2 = assert_true(parsed_large[0].tensor_name == "layer.0.weight", "First tensor name matches layer.0.weight")
  ok1_3 = assert_true(parsed_large[499].tensor_name == "layer.499.weight", "Last tensor name matches layer.499.weight")
  ok1_4 = assert_eq_int(parsed_large[499].data_size_bytes, 4096, "Last tensor size correctly computed as 4096 bytes")
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: 500+ Tensors large header stress verified")
  @end

  @! TEST 2: Whitespace, Indentations & Newline Variations
  println("▶ Test 2: Whitespace & Formatting Invariance...")
  total_tests = total_tests + 1
  
  formatted_json = "{\n  \"model.embed_tokens.weight\": {\n    \"dtype\": \"BF16\",\n    \"shape\": [\n      128,\n      64\n    ],\n    \"data_offsets\": [\n      0,\n      16384\n    ]\n  }\n}"
  hdr_fmt = safetensors_parse_header(formatted_json)
  ok2_1 = assert_true(hdr_fmt.tensor_name == "model.embed_tokens.weight", "Parsed multi-line indented tensor name")
  ok2_2 = assert_true(hdr_fmt.data_type == "BF16", "Parsed dtype BF16 with newline formatting")
  ok2_3 = assert_eq_int(hdr_fmt.shape_dims[0], 128, "Shape dim 0 == 128")
  ok2_4 = assert_eq_int(hdr_fmt.shape_dims[1], 64, "Shape dim 1 == 64")
  ok2_5 = assert_eq_int(hdr_fmt.data_size_bytes, 16384, "Size is 16384")
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Whitespace & formatting invariance verified")
  @end

  @! TEST 3: Complex Hierarchical Parameter Names with Special Characters
  println("▶ Test 3: Complex Parameter Names (dots, underscores, slashes)...")
  total_tests = total_tests + 1
  
  hier_json = "{\"encoder/block_0/layer_norm.bias\":{\"dtype\":\"F32\",\"shape\":[768],\"data_offsets\":[1000,4072]}}"
  hdr_hier = safetensors_parse_header(hier_json)
  ok3_1 = assert_true(hdr_hier.tensor_name == "encoder/block_0/layer_norm.bias", "Preserved exact path with slashes and underscores")
  ok3_2 = assert_eq_int(hdr_hier.data_offset, 1000, "Offset start 1000")
  ok3_3 = assert_eq_int(hdr_hier.data_size_bytes, 3072, "Size 3072 bytes (4072 - 1000)")
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Complex hierarchical parameter names verified")
  @end

  @! TEST 4: Malformed JSON & Truncated Header Recovery
  println("▶ Test 4: Malformed JSON & Truncated Header Recovery...")
  total_tests = total_tests + 1
  
  @! Test empty JSON
  empty_res = safetensors_parse_all_headers("")
  ok4_1 = assert_eq_int(empty_res.len(), 0, "Empty JSON returns empty headers list without crash")

  @! Test invalid non-JSON string
  bad_res = safetensors_parse_all_headers("NOT_JSON_DATA_CORRUPT")
  ok4_2 = assert_eq_int(bad_res.len(), 0, "Corrupted string handled gracefully returning empty list")

  @! Test default fallback from safetensors_parse_header
  hdr_fallback = safetensors_parse_header("")
  ok4_3 = assert_true(contains(hdr_fallback.tensor_name, "self_attn"), "Fallback returns safe default struct")
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Malformed JSON recovery verified")
  @end

  @! TEST 5: High-Rank Tensor Shapes (1D, 2D, 3D, 4D, 5D) & Offset Calculations
  println("▶ Test 5: High-Rank Tensor Shapes (1D to 5D) & Offsets...")
  total_tests = total_tests + 1
  
  ranks_json = "{\"rank1\":{\"dtype\":\"I32\",\"shape\":[1024],\"data_offsets\":[0,4096]},\"rank5\":{\"dtype\":\"F32\",\"shape\":[2,4,8,16,32],\"data_offsets\":[4096,36864]}}"
  parsed_ranks = safetensors_parse_all_headers(ranks_json)
  ok5_1 = assert_eq_int(parsed_ranks.len(), 2, "Parsed 2 high-rank tensors")
  ok5_2 = assert_eq_int(parsed_ranks[0].shape_dims.len(), 1, "Rank 1 tensor has 1 dimension")
  ok5_3 = assert_eq_int(parsed_ranks[1].shape_dims.len(), 5, "Rank 5 tensor has 5 dimensions [2, 4, 8, 16, 32]")
  ok5_4 = assert_eq_int(parsed_ranks[1].shape_dims[0], 2, "Rank 5 dim 0 == 2")
  ok5_5 = assert_eq_int(parsed_ranks[1].shape_dims[4], 32, "Rank 5 dim 4 == 32")
  ok5_6 = assert_eq_int(parsed_ranks[1].data_size_bytes, 32768, "Rank 5 data size == 32768 bytes")
  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1 && ok5_4 == 1 && ok5_5 == 1 && ok5_6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: High-rank tensor shapes verified")
  @end

  println("=================================================================")
  println("📊 SAFETENSORS BOUNDARIES TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 SAFETENSORS BOUNDARIES TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SAFETENSORS BOUNDARIES TESTS FAILED")
    return 1
  @end
@end
