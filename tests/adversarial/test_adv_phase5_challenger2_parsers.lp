@! ============================================================================
@! ADVERSARIAL TEST SUITE — PHASE 5: SAFETENSORS & ONNX PROTOBUF (CHALLENGER 2)
@! Module: tests/adversarial/test_adv_phase5_challenger2_parsers.maya
@! Stress-testing SafeTensors JSON parsing, LEB128 Varints, IEEE-754 Float32,
@! Protobuf wire format parsing, and ONNX graph runtime execution.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/core/json"
import "universe/ai/transformer/gpt"
import "universe/ai/onnx"

@fn assert_true(cond, msg: string)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_str(got: string, exp: string, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: '" + got + "', Expected: '" + exp + "')")
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_int(got: i64, exp: i64, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: " + got.to_str() + ", Expected: " + exp.to_str() + ")")
    exit(1)
  @else
    println("  [PASS] " + msg + " == " + exp.to_str())
  @end
@end

println("=================================================================")
println("⚡ ADVERSARIAL SAFETENSORS & ONNX PROTOBUF TEST SUITE (CHALLENGER 2) ⚡")
println("=================================================================")

@! ----------------------------------------------------------------------------
@! 1. SafeTensors 64-bit Header Size Decoding
@! ----------------------------------------------------------------------------
println("\n▶ Section 1: SafeTensors Header Binary Size Decoding...")

assert_eq_int(safetensors_read_header_size([10, 20]), 0, "Short buffer (< 8 bytes) returns 0")

b_100 = [100, 0, 0, 0, 0, 0, 0, 0]
assert_eq_int(safetensors_read_header_size(b_100), 100, "100-byte header size")

@! 0x01_00_00_12_34 = 4294971956
b_large = [52, 18, 0, 0, 1, 0, 0, 0]
assert_eq_int(safetensors_read_header_size(b_large), 52 + (18 * 256) + 4294967296, "64-bit large header size")

@! ----------------------------------------------------------------------------
@! 2. SafeTensors Multi-Tensor JSON Streaming Extraction
@! ----------------------------------------------------------------------------
println("\n▶ Section 2: SafeTensors Multi-Tensor Metadata Ingestion...")

complex_json = "{\"__metadata__\": {\"format\": \"pt\", \"framework\": \"pytorch\"}, \"model.embed.weight\": {\"dtype\": \"F32\", \"shape\": [32000, 4096], \"data_offsets\": [0, 524288000]}, \"model.layers.0.norm.weight\": {\"dtype\": \"BF16\", \"shape\": [4096], \"data_offsets\": [524288000, 524296192]}, \"model.lm_head.weight\": {\"dtype\": \"F16\", \"shape\": [32000, 4096], \"data_offsets\": [524296192, 786440192]}}"

single_hdr = safetensors_parse_header(complex_json)
assert_eq_str(single_hdr.tensor_name, "model.embed.weight", "Parsed first tensor skipping __metadata__")
assert_eq_str(single_hdr.data_type, "F32", "Tensor 1 dtype")
assert_eq_int(single_hdr.shape_dims.len(), 2, "Tensor 1 shape rank")
assert_eq_int(single_hdr.shape_dims[0], 32000, "Tensor 1 shape dim 0")
assert_eq_int(single_hdr.shape_dims[1], 4096, "Tensor 1 shape dim 1")
assert_eq_int(single_hdr.data_offset, 0, "Tensor 1 data offset")
assert_eq_int(single_hdr.data_size_bytes, 524288000, "Tensor 1 byte size")

all_hdrs = safetensors_parse_all_headers(complex_json)
assert_eq_int(all_hdrs.len(), 3, "Parsed all 3 non-metadata tensors")
assert_eq_str(all_hdrs[0].tensor_name, "model.embed.weight", "Header 0 name")
assert_eq_str(all_hdrs[1].tensor_name, "model.layers.0.norm.weight", "Header 1 name")
assert_eq_str(all_hdrs[1].data_type, "BF16", "Header 1 dtype")
assert_eq_int(all_hdrs[1].shape_dims[0], 4096, "Header 1 shape")
assert_eq_int(all_hdrs[1].data_offset, 524288000, "Header 1 start offset")
assert_eq_int(all_hdrs[1].data_size_bytes, 8192, "Header 1 size in bytes (524296192 - 524288000)")
assert_eq_str(all_hdrs[2].tensor_name, "model.lm_head.weight", "Header 2 name")
assert_eq_str(all_hdrs[2].data_type, "F16", "Header 2 dtype")
assert_eq_int(all_hdrs[2].data_size_bytes, 262144000, "Header 2 size in bytes")

@! ----------------------------------------------------------------------------
@! 3. Protobuf LEB128 Varint Decoding Under High Boundaries
@! ----------------------------------------------------------------------------
println("\n▶ Section 3: Protobuf LEB128 Varint Decoding...")

v1 = proto_read_varint([0], 0)
assert_eq_int(v1.val, 0, "Varint 0")
assert_eq_int(v1.next_pos, 1, "Varint 0 next_pos")

v2 = proto_read_varint([1], 0)
assert_eq_int(v2.val, 1, "Varint 1")

v127 = proto_read_varint([127], 0)
assert_eq_int(v127.val, 127, "Varint 127 (single-byte limit)")

@! 128 = 0x80, 0x01
v128 = proto_read_varint([128, 1], 0)
assert_eq_int(v128.val, 128, "Varint 128 (2 bytes)")
assert_eq_int(v128.next_pos, 2, "Varint 128 next_pos")

@! 300 = 0xAC, 0x02
v300 = proto_read_varint([172, 2], 0)
assert_eq_int(v300.val, 300, "Varint 300")

@! 16384 = 0x80, 0x80, 0x01
v16384 = proto_read_varint([128, 128, 1], 0)
assert_eq_int(v16384.val, 16384, "Varint 16384 (3 bytes)")

@! 2097152 = 0x80, 0x80, 0x80, 0x01
v2097152 = proto_read_varint([128, 128, 128, 1], 0)
assert_eq_int(v2097152.val, 2097152, "Varint 2097152 (4 bytes)")

@! ----------------------------------------------------------------------------
@! 4. Protobuf IEEE-754 Float32 Wire Decoding
@! ----------------------------------------------------------------------------
println("\n▶ Section 4: Protobuf IEEE-754 Float32 Decoding...")

flt_zero = proto_read_float32([0, 0, 0, 0], 0)
assert_eq_int(flt_zero.val, 0, "Float32 0.0")

@! 1.0f = 0x3F800000 -> bytes [0, 0, 128, 63]
flt_one = proto_read_float32([0, 0, 128, 63], 0)
assert_eq_int(flt_one.val, 1, "Float32 1.0")

@! -1.0f = 0xBF800000 -> bytes [0, 0, 128, 191]
flt_neg_one = proto_read_float32([0, 0, 128, 191], 0)
assert_eq_int(flt_neg_one.val, -1, "Float32 -1.0")

@! 2.0f = 0x40000000 -> bytes [0, 0, 0, 64]
flt_two = proto_read_float32([0, 0, 0, 64], 0)
assert_eq_int(flt_two.val, 2, "Float32 2.0")

@! 4.0f = 0x40800000 -> bytes [0, 0, 128, 64]
flt_four = proto_read_float32([0, 0, 128, 64], 0)
assert_eq_int(flt_four.val, 4, "Float32 4.0")

@! ----------------------------------------------------------------------------
@! 5. Protobuf Wire Message Parsing (Attributes & Tensors)
@! ----------------------------------------------------------------------------
println("\n▶ Section 5: Protobuf Wire Message Parsing...")

@! 5.1 Attribute Proto with packed ints [10, 20, 30]
attr_wire = [10, 4, 97, 120, 105, 115, 66, 3, 10, 20, 30]
attr_parsed = parse_proto_attribute(attr_wire)
assert_eq_str(attr_parsed.attr_name, "axis", "Attribute name 'axis'")
assert_eq_int(attr_parsed.ints_val.len(), 3, "Attribute 3 packed ints")
assert_eq_int(attr_parsed.ints_val[0], 10, "Attr ints[0]")
assert_eq_int(attr_parsed.ints_val[1], 20, "Attr ints[1]")
assert_eq_int(attr_parsed.ints_val[2], 30, "Attr ints[2]")

@! 5.2 Tensor Proto with packed dims [2, 2] and packed float data [1.0, 2.0, 3.0, 4.0]
tensor_wire = [
  66, 6, 119, 101, 105, 103, 104, 116,
  10, 2, 2, 2,
  16, 1,
  34, 16,
  0, 0, 128, 63,
  0, 0, 0, 64,
  0, 0, 64, 64,
  0, 0, 128, 64
]

t_proto = parse_proto_tensor(tensor_wire)
assert_eq_str(t_proto.name, "weight", "Tensor name 'weight'")
assert_eq_int(t_proto.dims.len(), 2, "Tensor dims len")
assert_eq_int(t_proto.dims[0], 2, "Tensor dim 0")
assert_eq_int(t_proto.dims[1], 2, "Tensor dim 1")
assert_eq_int(t_proto.float_data.len(), 4, "Tensor float_data length")
assert_eq_int(t_proto.float_data[0], 1, "Tensor val 0 == 1")
assert_eq_int(t_proto.float_data[1], 2, "Tensor val 1 == 2")
assert_eq_int(t_proto.float_data[2], 3, "Tensor val 2 == 3")
assert_eq_int(t_proto.float_data[3], 4, "Tensor val 3 == 4")

@! ----------------------------------------------------------------------------
@! 6. ONNX Computational Graph Execution (Chained Gemm + Relu)
@! ----------------------------------------------------------------------------
println("\n▶ Section 6: ONNX Computational Graph Execution Engine...")

@! Graph:
@! Initializer: W1 (3x2), B1 (2)
@! Input: X (2x3) = [[1, 2, 3], [-2, 0, 2]]
@! W1 = [[1, -1], [2, 0], [-1, 1]]
@! B1 = [1, 2]
@! Node 1: Gemm(X, W1, B1) -> H1
@!   Row 0: [1*1 + 2*2 + 3*(-1) + 1, 1*(-1) + 2*0 + 3*1 + 2] = [3, 4]
@!   Row 1: [-2*1 + 0*2 + 2*(-1) + 1, -2*(-1) + 0*0 + 2*1 + 2] = [-3, 6]
@! Node 2: Relu(H1) -> Y
@!   Row 0: [3, 4]
@!   Row 1: [0, 6]

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
assert_true(eval_results.len() >= 4, "Graph produced intermediate and final tensor values")

y_tensor = 0
r_idx = 0
@while r_idx < eval_results.len()
  @if eval_results[r_idx].name == "Y"
    y_tensor = eval_results[r_idx]
  @end
  r_idx = r_idx + 1
@end
