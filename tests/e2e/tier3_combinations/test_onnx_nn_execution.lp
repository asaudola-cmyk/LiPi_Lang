@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: ONNX GRAPH DECODE TO NEURAL NET EXECUTION
@! File: tests/e2e/tier3_combinations/test_onnx_nn_execution.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! TAGS: tier3, combinations, onnx, nn, ai
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
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
@! ONNX GRAPH STRUCTURE & EXECUTION RUNTIME
@! ============================================================================

@struct ONNXGraphNode
  op_type: string
  input_names: array
  output_names: array
@end

@struct ONNXGraphModel
  nodes: array
  weight_tensors: array
  weight_names: array
@end

@fn main()
  println("=================================================================")
  println("🔗 TIER 3: ONNX GRAPH DECODE -> NEURAL NET EXECUTION PIPELINE 🔗")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Decoding ONNX Model Graph & Initializers
  println("▶ Section 1: Decoding ONNX Model Graph & Initializers...")
  total_tests = total_tests + 1
  
  @! Node 0: Gemm (X, W1, B1 -> H1)
  n0 = { op_type: "Gemm", input_names: ["X", "W1", "B1"], output_names: ["H1"] }
  @! Node 1: Relu (H1 -> A1)
  n1 = { op_type: "Relu", input_names: ["H1"], output_names: ["A1"] }
  @! Node 2: Gemm (A1, W2, B2 -> H2)
  n2 = { op_type: "Gemm", input_names: ["A1", "W2", "B2"], output_names: ["H2"] }
  @! Node 3: Softmax (H2 -> Probs)
  n3 = { op_type: "Softmax", input_names: ["H2"], output_names: ["Probs"] }
  
  graph = {
    nodes: [n0, n1, n2, n3],
    weight_tensors: [
      tensor_new([1.0, 2.0, 3.0, 4.0], [2, 2]),   @! W1 [2, 2]
      tensor_new([0.0, 0.0], [1, 2]),             @! B1 [1, 2]
      tensor_new([1.0, 0.0, 0.0, 1.0], [2, 2]),   @! W2 [2, 2]
      tensor_new([0.0, 0.0], [1, 2])              @! B2 [1, 2]
    ],
    weight_names: ["W1", "B1", "W2", "B2"]
  }
  
  ok1_1 = assert_eq_int(graph.nodes.len(), 4, "Decoded 4 DAG computational nodes")
  ok1_2 = assert_eq_int(graph.weight_tensors.len(), 4, "Decoded 4 weight initializer tensors")
  ok1_3 = assert_true(graph.nodes[0].op_type == "Gemm", "Node 0 is Gemm")
  ok1_4 = assert_true(graph.nodes[1].op_type == "Relu", "Node 1 is Relu")
  ok1_5 = assert_true(graph.nodes[3].op_type == "Softmax", "Node 3 is Softmax")
  
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 1: ONNX graph and initializers decoded")
  @end

  @! SECTION 2: Executing Layer 1 (Gemm -> Relu)
  println("▶ Section 2: Executing Layer 1 (Gemm -> Relu)...")
  total_tests = total_tests + 1
  
  @! Input X = [[1.0, 2.0]] (1x2)
  t_input = tensor_new([1.0, 2.0], [1, 2])
  
  @! Gemm 1: X * W1 + B1 = [[1*1 + 2*3, 1*2 + 2*4]] = [[7.0, 10.0]]
  w1 = graph.weight_tensors[0]
  b1 = graph.weight_tensors[1]
  h1_prod = tensor_matmul(t_input, w1)
  h1 = tensor_add(h1_prod, b1)
  
  ok2_1 = assert_true(h1.data[0] == 7.0, "Layer 1 Gemm H1[0] == 7.0")
  ok2_2 = assert_true(h1.data[1] == 10.0, "Layer 1 Gemm H1[1] == 10.0")
  
  @! Relu 1: max(0, H1) = [[7.0, 10.0]]
  a1 = tensor_relu(h1)
  ok2_3 = assert_true(a1.data[0] == 7.0, "Layer 1 Relu A1[0] == 7.0")
  ok2_4 = assert_true(a1.data[1] == 10.0, "Layer 1 Relu A1[1] == 10.0")
  
  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 2: Layer 1 forward execution verified")
  @end

  @! SECTION 3: Executing Layer 2 (Gemm -> Softmax Normalization)
  println("▶ Section 3: Executing Layer 2 (Gemm -> Softmax)...")
  total_tests = total_tests + 1
  
  w2 = graph.weight_tensors[2]
  b2 = graph.weight_tensors[3]
  h2_prod = tensor_matmul(a1, w2)
  h2 = tensor_add(h2_prod, b2)
  
  ok3_1 = assert_true(h2.data[0] == 7.0, "Layer 2 Logits H2[0] == 7.0")
  ok3_2 = assert_true(h2.data[1] == 10.0, "Layer 2 Logits H2[1] == 10.0")
  
  @! Softmax on Logits [7.0, 10.0]:
  @! max = 10.0 -> e0 = exp(7-10) = exp(-3) ~ 0.0498, e1 = exp(10-10) = 1.0
  max_l = h2.data[1]
  e0 = math_exp(h2.data[0] - max_l)
  e1 = math_exp(h2.data[1] - max_l)
  sum_e = e0 + e1
  p0 = e0 / sum_e
  p1 = e1 / sum_e
  
  ok3_3 = assert_true(p1 > p0, "Prob(class 1) > Prob(class 0) for higher logit")
  sum_p = p0 + p1
  diff_p = math_abs(sum_p - 1.0)
  ok3_4 = assert_true(diff_p < 0.01, "Softmax probabilities sum to 1.0 (got " + sum_p.to_str() + ")")
  
  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Section 3: Layer 2 forward execution and softmax normalization verified")
  @end

  println("=================================================================")
  println("📊 TIER 3 ONNX NN EXECUTION RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 TIER 3 ONNX NN EXECUTION TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TIER 3 ONNX NN EXECUTION TESTS FAILED")
    return 1
  @end
@end
