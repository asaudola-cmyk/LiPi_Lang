@! ============================================================================
@! ADVERSARIAL CHALLENGER 3 VERIFICATION SUITE — PHASE 5 REMEDIATION ITERATION 2
@! ============================================================================
import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/ai/tensor"
import "universe/ai/onnx"

@fn assert_true(cond, msg: string) -> void
  @if cond == 0 || cond == false
    println("  ❌ [FAIL] " + msg)
    exit(1)
  @else
    println("  ✓ [PASS] " + msg)
  @end
@end

@fn compute_oracle_gemm(a: Tensor, b: Tensor, m: i64, k: i64, n: i64) -> array
  oracle = []
  r = 0
  @while r < m
    c = 0
    @while c < n
      sum = 0
      p = 0
      @while p < k
        va = tensor_get(a, [r, p])
        vb = tensor_get(b, [p, c])
        sum = sum + (va * vb)
        p = p + 1
      @end
      oracle = oracle.push(sum)
      c = c + 1
    @end
    r = r + 1
  @end
  return oracle
@end

@fn verify_amx_gemm_shape(m: i64, k: i64, n: i64) -> i64
  a = tensor_zeros([m, k])
  b = tensor_zeros([k, n])

  @! Populate deterministic pseudo-random / sequence data
  r = 0
  @while r < m
    c = 0
    @while c < k
      val = ((r * 7) + (c * 3) + 1) % 19 - 9
      tensor_set(a, [r, c], val)
      c = c + 1
    @end
    r = r + 1
  @end

  r = 0
  @while r < k
    c = 0
    @while c < n
      val = ((r * 5) + (c * 11) + 2) % 23 - 11
      tensor_set(b, [r, c], val)
      c = c + 1
    @end
    r = r + 1
  @end

  oracle = compute_oracle_gemm(a, b, m, k, n)
  c_res = tensor_gemm_amx_tiled(a, b, m, k, n)

  match_count = 0
  total = m * n
  idx = 0
  r = 0
  @while r < m
    c = 0
    @while c < n
      val_actual = tensor_get(c_res, [r, c])
      val_expected = oracle[idx]
      @if val_actual == val_expected
        match_count = match_count + 1
      @else
        println("    MISMATCH at (" + r.to_str() + ", " + c.to_str() + "): got " + val_actual.to_str() + ", expected " + val_expected.to_str())
      @end
      idx = idx + 1
      c = c + 1
    @end
    r = r + 1
  @end

  @if match_count == total
    assert_true(true, "AMX Tiled GEMM (" + m.to_str() + "x" + k.to_str() + "x" + n.to_str() + ") perfectly matches Oracle (" + match_count.to_str() + "/" + total.to_str() + ")")
    return 1
  @else
    assert_true(false, "AMX Tiled GEMM (" + m.to_str() + "x" + k.to_str() + "x" + n.to_str() + ") corrupted: " + match_count.to_str() + "/" + total.to_str() + " matches")
    return 0
  @end
@end

println("=================================================================")
println("🔥 EMPIRICAL CHALLENGER 3: AMX TILED GEMM EXHAUSTIVE ORACLE TEST 🔥")
println("=================================================================")

println("\n▶ Testing Required Matrix Shapes:")
verify_amx_gemm_shape(1, 1, 1)
verify_amx_gemm_shape(15, 15, 15)
verify_amx_gemm_shape(16, 16, 16)
verify_amx_gemm_shape(17, 19, 23)
verify_amx_gemm_shape(31, 31, 31)
verify_amx_gemm_shape(32, 32, 32)
verify_amx_gemm_shape(33, 33, 33)

println("\n▶ Testing Additional Boundary & Asymmetric Shapes:")
verify_amx_gemm_shape(1, 35, 1)
verify_amx_gemm_shape(35, 1, 35)
verify_amx_gemm_shape(7, 13, 11)
verify_amx_gemm_shape(48, 48, 48)
verify_amx_gemm_shape(49, 53, 59)
verify_amx_gemm_shape(2, 64, 3)
verify_amx_gemm_shape(65, 17, 33)

println("\n=================================================================")
println("🔥 EMPIRICAL CHALLENGER 3: ONNX GRAPH PROTO & EXECUTION TEST 🔥")
println("=================================================================")

@! Build a 2-Layer MLP ONNX Graph:
@! X: [3, 4] (Input)
@! W1: [4, 5] (Initializer)
@! B1: [5]    (Initializer)
@! Node 1: Gemm(X, W1, B1) -> H1 [3, 5]
@! Node 2: Relu(H1) -> A1 [3, 5]
@! W2: [5, 2] (Initializer)
@! B2: [2]    (Initializer)
@! Node 3: Gemm(A1, W2, B2) -> H2 [3, 2]
@! Node 4: Relu(H2) -> Y [3, 2]

w1_data = [
  1.0, -2.0,  3.0, -1.0,  2.0,
 -1.0,  0.0,  2.0, -3.0,  1.0,
  2.0,  1.0, -1.0,  0.0, -2.0,
  0.0,  3.0,  1.0,  2.0, -1.0
]
b1_data = [1.0, -5.0, 2.0, -10.0, 3.0]

w2_data = [
  2.0, -1.0,
 -3.0,  2.0,
  1.0,  4.0,
  0.0, -2.0,
 -1.0,  3.0
]
b2_data = [-4.0, 5.0]

init_w1 = { name: "W1", dims: [4, 5], data_type: 1, float_data: w1_data, int64_data: [] }
init_b1 = { name: "B1", dims: [5], data_type: 1, float_data: b1_data, int64_data: [] }
init_w2 = { name: "W2", dims: [5, 2], data_type: 1, float_data: w2_data, int64_data: [] }
init_b2 = { name: "B2", dims: [2], data_type: 1, float_data: b2_data, int64_data: [] }

node1 = { op_type: "Gemm", name: "gemm1", inputs: ["X", "W1", "B1"], outputs: ["H1"], attributes: [] }
node2 = { op_type: "Relu", name: "relu1", inputs: ["H1"], outputs: ["A1"], attributes: [] }
node3 = { op_type: "Gemm", name: "gemm2", inputs: ["A1", "W2", "B2"], outputs: ["H2"], attributes: [] }
node4 = { op_type: "Relu", name: "relu2", inputs: ["H2"], outputs: ["Y"], attributes: [] }

graph = {
  name: "TwoLayerMLP",
  nodes: [node1, node2, node3, node4],
  initializers: [init_w1, init_b1, init_w2, init_b2],
  graph_inputs: ["X"],
  graph_outputs: ["Y"]
}

@! Check graph struct field alignments
assert_true(graph.graph_inputs.len() == 1, "graph.graph_inputs has 1 entry")
assert_true(graph.graph_inputs[0] == "X", "graph.graph_inputs[0] == 'X'")
assert_true(graph.graph_outputs.len() == 1, "graph.graph_outputs has 1 entry")
assert_true(graph.graph_outputs[0] == "Y", "graph.graph_outputs[0] == 'Y'")
assert_true(graph.nodes.len() == 4, "graph.nodes has 4 nodes")
assert_true(graph.initializers.len() == 4, "graph.initializers has 4 weights")

@! Check node field alignments
assert_true(node1.inputs.len() == 3, "node1.inputs has 3 entries ('X', 'W1', 'B1')")
assert_true(node1.inputs[0] == "X", "node1.inputs[0] == 'X'")
assert_true(node1.inputs[1] == "W1", "node1.inputs[1] == 'W1'")
assert_true(node1.inputs[2] == "B1", "node1.inputs[2] == 'B1'")
assert_true(node1.outputs.len() == 1, "node1.outputs has 1 entry ('H1')")
assert_true(node1.outputs[0] == "H1", "node1.outputs[0] == 'H1'")

@! Define Input X: [3, 4]
x_data = [
  1.0, 2.0, 3.0, 4.0,
  0.0, -1.0, 2.0, -2.0,
  3.0, 1.0, 0.0, 2.0
]
input_x = {
  name: "X",
  dims: [3, 4],
  data_type: 1,
  float_data: x_data,
  int64_data: []
}

@! Execute graph
res_map = onnx_run_graph(graph, [input_x])
assert_true(res_map.len() >= 9, "Execution returned all tensors (initializers + inputs + intermediate + outputs)")

@! Find H1, A1, H2, Y
t_h1 = 0
t_a1 = 0
t_h2 = 0
t_y = 0
idx = 0
@while idx < res_map.len()
  tv = res_map[idx]
  @if tv.name == "H1" t_h1 = tv @end
  @if tv.name == "A1" t_a1 = tv @end
  @if tv.name == "H2" t_h2 = tv @end
  @if tv.name == "Y" t_y = tv @end
  idx = idx + 1
@end
