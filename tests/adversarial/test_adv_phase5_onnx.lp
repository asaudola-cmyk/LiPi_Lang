@! ============================================================================
@! ADVERSARIAL STRESS TEST: SafeTensors & ONNX Zero-Dep Protobuf & Runtime (Challenger 1)
@! File: tests/adversarial/test_adv_phase5_onnx.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/core/json"
import "universe/ai/transformer/gpt"
import "universe/ai/onnx"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  ❌ [ADV FAIL] " + msg)
    return 0
  @end
  println("  ✓ [ADV PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got '" + actual + "')")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

println("=================================================================")
println("🔥 [CHALLENGE 2: SafeTensors JSON & ONNX Protobuf Wire Format] 🔥")
println("=================================================================")

total_asserts = 0
passed_asserts = 0

@! 2.1 Multi-Tensor SafeTensors JSON Metadata Parser
st_json = "{\n  \"__metadata__\": {\"format\": \"pt\"},\n  \"model.embed_tokens.weight\": {\"dtype\": \"F32\", \"shape\": [32000, 4096], \"data_offsets\": [0, 524288000]},\n  \"model.layers.0.self_attn.q_proj.weight\": {\"dtype\": \"F16\", \"shape\": [4096, 4096], \"data_offsets\": [524288000, 557842432]},\n  \"model.layers.0.mlp.gate_proj.weight\": {\"dtype\": \"BF16\", \"shape\": [11008, 4096], \"data_offsets\": [557842432, 648028160]},\n  \"model.norm.weight\": {\"dtype\": \"F32\", \"shape\": [4096], \"data_offsets\": [648028160, 648044544]}\n}"

all_st_headers = safetensors_parse_all_headers(st_json)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(all_st_headers.len(), 4, "Parsed all 4 non-metadata tensors from SafeTensors JSON")

h0 = all_st_headers[0]
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_str(h0.tensor_name, "model.embed_tokens.weight", "Header 0 tensor_name")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_str(h0.data_type, "F32", "Header 0 dtype is F32")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h0.shape_dims[0], 32000, "Header 0 shape[0] == 32000")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h0.shape_dims[1], 4096, "Header 0 shape[1] == 4096")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h0.data_offset, 0, "Header 0 start offset == 0")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h0.data_size_bytes, 524288000, "Header 0 size_bytes == 524288000")

h2 = all_st_headers[2]
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_str(h2.tensor_name, "model.layers.0.mlp.gate_proj.weight", "Header 2 tensor_name")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_str(h2.data_type, "BF16", "Header 2 dtype is BF16")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h2.shape_dims[0], 11008, "Header 2 shape[0] == 11008")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(h2.data_offset, 557842432, "Header 2 start offset == 557842432")

@! 2.2 Little-Endian 8-byte Header Size Decoding
buf8 = [0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] @! 4096
sz4096 = safetensors_read_header_size(buf8)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(sz4096, 4096, "Decoded 8-byte Little-Endian size (4096)")

buf8_large = [0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] @! 65535
sz65535 = safetensors_read_header_size(buf8_large)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(sz65535, 65535, "Decoded 8-byte Little-Endian size (65535)")

@! 2.3 LEB128 Varint Decoding: Multi-Byte & Boundary Values
@! 1 byte: 0, 1, 127
v0 = proto_read_varint([0], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v0.val, 0, "Varint(0) == 0")

v127 = proto_read_varint([127], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v127.val, 127, "Varint(127) == 127")

@! 2 bytes: 128 -> [0x80, 0x01], 300 -> [0xAC, 0x02]
v128 = proto_read_varint([0x80, 0x01], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v128.val, 128, "Varint(128) == 128")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v128.next_pos, 2, "Varint(128) consumes 2 bytes")

v300 = proto_read_varint([0xAC, 0x02], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v300.val, 300, "Varint(300) == 300")

@! 3 bytes: 16384 -> [0x80, 0x80, 0x01]
v16384 = proto_read_varint([0x80, 0x80, 0x01], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v16384.val, 16384, "Varint(16384) == 16384")

@! 4 bytes: 2097152 -> [0x80, 0x80, 0x80, 0x01]
v2M = proto_read_varint([0x80, 0x80, 0x80, 0x01], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(v2M.val, 2097152, "Varint(2097152) == 2097152")

@! 2.4 IEEE-754 Single-Precision Float Decoding
f0 = proto_read_float32([0x00, 0x00, 0x00, 0x00], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(f0.val == 0.0, "Float32(0.0) == 0.0")

f1 = proto_read_float32([0x00, 0x00, 0x80, 0x3F], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(f1.val >= 0.9999 && f1.val <= 1.0001, "Float32(1.0) == 1.0")

f_neg1 = proto_read_float32([0x00, 0x00, 0x80, 0xBF], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(f_neg1.val >= -1.0001 && f_neg1.val <= -0.9999, "Float32(-1.0) == -1.0")

f_neg42 = proto_read_float32([0x00, 0x00, 0x28, 0xC2], 0)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(f_neg42.val >= -42.001 && f_neg42.val <= -41.999, "Float32(-42.0) == -42.0")

@! 2.5 Synthetic Protobuf TensorProto & NodeProto Parsing
w_tensor_bytes = [
  10, 2, 2, 2,                                      @! dims = [2, 2]
  16, 1,                                            @! data_type = 1
  66, 1, 87,                                        @! name = "W"
  74, 16,                                           @! raw_data (16 bytes)
  0x00, 0x00, 0x80, 0x3F,                           @! 1.0
  0x00, 0x00, 0x00, 0x40,                           @! 2.0
  0x00, 0x00, 0x40, 0x40,                           @! 3.0
  0x00, 0x00, 0x80, 0x40                            @! 4.0
]
parsed_t = parse_proto_tensor(w_tensor_bytes)
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_str(parsed_t.name, "W", "Parsed TensorProto name 'W'")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(parsed_t.dims.len(), 2, "Parsed TensorProto ndim == 2")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(parsed_t.dims[0], 2, "Parsed dims[0] == 2")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(parsed_t.dims[1], 2, "Parsed dims[1] == 2")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_eq_int(parsed_t.float_data.len(), 4, "Decoded 4 raw floats")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(parsed_t.float_data[0] >= 0.99 && parsed_t.float_data[0] <= 1.01, "Float data[0] == 1.0")
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(parsed_t.float_data[3] >= 3.99 && parsed_t.float_data[3] <= 4.01, "Float data[3] == 4.0")

@! 2.6 Full ONNX Runtime Graph Execution (Gemm + Relu)
@! Model: Y = Relu(X * W1 + B1)
init_w1 = {
  name: "W1",
  dims: [3, 2],
  data_type: 1,
  float_data: [1, -1, 2, 0, -1, 1],
  int64_data: []
}

init_b1 = {
  name: "B1",
  dims: [2],
  data_type: 1,
  float_data: [1, 2],
  int64_data: []
}

node_gemm = {
  op_type: "Gemm",
  name: "gemm_layer1",
  inputs: ["X", "W1", "B1"],
  outputs: ["H1"],
  attributes: []
}

node_relu = {
  op_type: "Relu",
  name: "relu_layer1",
  inputs: ["H1"],
  outputs: ["Y"],
  attributes: []
}

test_graph = {
  name: "mlp_test_graph",
  nodes: [node_gemm, node_relu],
  initializers: [init_w1, init_b1],
  graph_inputs: ["X"],
  graph_outputs: ["Y"]
}

input_x = {
  name: "X",
  dims: [2, 3],
  data_type: 1,
  float_data: [1, 2, 3, -2, 0, 2],
  int64_data: []
}

eval_results = onnx_run_graph(test_graph, [input_x])
total_asserts = total_asserts + 1
passed_asserts = passed_asserts + assert_true(eval_results.len() >= 4, "ONNX Graph produced intermediate and final tensor values")

y_tensor = 0
h1_tensor = 0
r_idx = 0
@while r_idx < eval_results.len()
  @if eval_results[r_idx].name == "H1"
    h1_tensor = eval_results[r_idx]
  @end
  @if eval_results[r_idx].name == "Y"
    y_tensor = eval_results[r_idx]
  @end
  r_idx = r_idx + 1
@end
