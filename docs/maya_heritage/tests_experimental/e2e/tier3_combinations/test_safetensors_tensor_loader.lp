@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: SAFETENSORS TO TENSOR MEMORY VIEWS
@! File: tests/e2e/tier3_combinations/test_safetensors_tensor_loader.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! TAGS: tier3, combinations, safetensors, tensor, ai
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

@fn main()
  println("=================================================================")
  println("🔗 TIER 3: SAFETENSORS STREAMING LOADER -> TENSOR ENGINE PIPELINE 🔗")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: SafeTensors Multi-Layer Metadata Extraction
  println("▶ Section 1: Ingesting SafeTensors Linear Layer Metadata...")
  total_tests = total_tests + 1
  
  st_json = "{\"layer.weight\":{\"dtype\":\"F32\",\"shape\":[4,4],\"data_offsets\":[0,64]},\"layer.bias\":{\"dtype\":\"F32\",\"shape\":[1,4],\"data_offsets\":[64,80]}}"
  headers = safetensors_parse_all_headers(st_json)
  
  ok1_1 = assert_eq_int(headers.len(), 2, "Decoded 2 tensor headers")
  ok1_2 = assert_true(headers[0].tensor_name == "layer.weight", "Header 0 is layer.weight")
  ok1_3 = assert_true(headers[0].shape_dims[0] == 4 && headers[0].shape_dims[1] == 4, "Weight shape [4, 4]")
  ok1_4 = assert_true(headers[1].tensor_name == "layer.bias", "Header 1 is layer.bias")
  ok1_5 = assert_true(headers[1].shape_dims[0] == 1 && headers[1].shape_dims[1] == 4, "Bias shape [1, 4]")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 1: SafeTensors layer metadata extracted successfully")
  @end

  @! SECTION 2: Mapping Weights to N-Dimensional Tensor Memory Views
  println("▶ Section 2: Initializing Live Tensors from Decoded Metadata...")
  total_tests = total_tests + 1
  
  @! 4x4 Weight: 2.0 * Identity matrix
  w_data = [
    2.0, 0.0, 0.0, 0.0,
    0.0, 2.0, 0.0, 0.0,
    0.0, 0.0, 2.0, 0.0,
    0.0, 0.0, 0.0, 2.0
  ]
  b_data = [10.0, 20.0, 30.0, 40.0]
  
  t_w = tensor_new(w_data, headers[0].shape_dims)
  t_b = tensor_new(b_data, headers[1].shape_dims)
  
  ok2_1 = assert_eq_int(t_w.ndim, 2, "Weight tensor is 2D")
  ok2_2 = assert_eq_int(t_w.size, 16, "Weight tensor contains 16 elements")
  ok2_3 = assert_eq_int(t_b.ndim, 2, "Bias tensor is 2D")
  ok2_4 = assert_eq_int(t_b.size, 4, "Bias tensor contains 4 elements")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 2: Live tensor structures initialized")
  @end

  @! SECTION 3: Feedforward Inference Pass: Y = X * W + B
  println("▶ Section 3: Feedforward Inference Pass (GEMM + Broadcast Add)...")
  total_tests = total_tests + 1
  
  @! Input X = [[1.0, 2.0, 3.0, 4.0]] (1x4)
  t_x = tensor_new([1.0, 2.0, 3.0, 4.0], [1, 4])
  
  @! X * W = [[2.0, 4.0, 6.0, 8.0]] (1x4)
  t_prod = tensor_matmul(t_x, t_w)
  
  ok3_1 = assert_eq_int(t_prod.shape[0], 1, "Product rows == 1")
  ok3_2 = assert_eq_int(t_prod.shape[1], 4, "Product cols == 4")
  ok3_3 = assert_true(t_prod.data[0] == 2.0, "Product[0] == 2.0")
  ok3_4 = assert_true(t_prod.data[1] == 4.0, "Product[1] == 4.0")
  ok3_5 = assert_true(t_prod.data[2] == 6.0, "Product[2] == 6.0")
  ok3_6 = assert_true(t_prod.data[3] == 8.0, "Product[3] == 8.0")
  
  @! Y = (X * W) + B = [[12.0, 24.0, 36.0, 48.0]]
  t_y = tensor_add(t_prod, t_b)
  ok3_7 = assert_true(t_y.data[0] == 12.0, "Output Y[0] == 12.0 (2 + 10)")
  ok3_8 = assert_true(t_y.data[1] == 24.0, "Output Y[1] == 24.0 (4 + 20)")
  ok3_9 = assert_true(t_y.data[2] == 36.0, "Output Y[2] == 36.0 (6 + 30)")
  ok3_10 = assert_true(t_y.data[3] == 48.0, "Output Y[3] == 48.0 (8 + 40)")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1 && ok3_6 == 1 && ok3_7 == 1 && ok3_8 == 1 && ok3_9 == 1 && ok3_10 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 3: Feedforward GEMM and bias addition verified")
  @end

  @! SECTION 4: Nonlinear Activation & Slicing
  println("▶ Section 4: Nonlinear Activation (ReLU) & Slicing...")
  total_tests = total_tests + 1
  
  t_mixed = tensor_new([-5.0, 15.0, -25.0, 35.0], [1, 4])
  t_relu = tensor_relu(t_mixed)
  
  ok4_1 = assert_true(t_relu.data[0] == 0.0, "ReLU(-5.0) == 0.0")
  ok4_2 = assert_true(t_relu.data[1] == 15.0, "ReLU(15.0) == 15.0")
  ok4_3 = assert_true(t_relu.data[2] == 0.0, "ReLU(-25.0) == 0.0")
  ok4_4 = assert_true(t_relu.data[3] == 35.0, "ReLU(35.0) == 35.0")
  
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 4: Nonlinear activation pipeline verified")
  @end

  println("=================================================================")
  println("📊 TIER 3 SAFETENSORS-TENSOR RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 TIER 3 SAFETENSORS-TENSOR INTEGRATION TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TIER 3 SAFETENSORS-TENSOR TESTS FAILED")
    return 1
  @end
@end
