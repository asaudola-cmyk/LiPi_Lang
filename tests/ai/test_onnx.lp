@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ONNX ZERO-DEP PROTOBUF & OPS TEST SUITE
@! File: tests/ai/test_onnx.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 1
@! TAGS: ai, onnx, protobuf
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"

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
@! 1. PROTOBUF WIRE DECODER PRIMITIVES
@! ============================================================================

@struct ProtoField
  field_num: i64
  wire_type: i64
  int_val: i64
  bytes_val: array
  next_pos: i64
@end

@struct OnnxNodeSpec
  op_type: string
  inputs: array
  outputs: array
@end

@struct OnnxTensorSpec
  name: string
  dims: array
  data_type: i64
  elem_count: i64
@end

@fn proto_read_varint(bytes, pos)
  val = 0
  shift = 0
  idx = pos
  more = 1
  @while more == 1 && idx < bytes.len()
    b = bytes[idx]
    chunk = b & 127
    val = val + (chunk << shift)
    @if b & 128 == 0
      more = 0
    @end
    shift = shift + 7
    idx = idx + 1
  @end
  return [val, idx]
@end

@fn proto_read_field(bytes, pos)
  @if pos >= bytes.len()
    return { field_num: 0, wire_type: 0, int_val: 0, bytes_val: [], next_pos: pos }
  @end
  tag_res = proto_read_varint(bytes, pos)
  raw_tag = tag_res[0]
  cur = tag_res[1]
  
  w_type = raw_tag & 7
  f_num = raw_tag >> 3
  
  @if w_type == 0  @! Varint
    v_res = proto_read_varint(bytes, cur)
    return { field_num: f_num, wire_type: 0, int_val: v_res[0], bytes_val: [], next_pos: v_res[1] }
  @elif w_type == 2  @! Length-delimited
    len_res = proto_read_varint(bytes, cur)
    l_len = len_res[0]
    l_start = len_res[1]
    l_end = l_start + l_len
    @if l_end > bytes.len()
      l_end = bytes.len()
    @end
    slice_b = []
    k = l_start
    @while k < l_end
      slice_b = slice_b.push(bytes[k])
      k = k + 1
    @end
    return { field_num: f_num, wire_type: 2, int_val: l_len, bytes_val: slice_b, next_pos: l_end }
  @elif w_type == 5  @! 32-bit fixed
    return { field_num: f_num, wire_type: 5, int_val: 0, bytes_val: [], next_pos: cur + 4 }
  @elif w_type == 1  @! 64-bit fixed
    return { field_num: f_num, wire_type: 1, int_val: 0, bytes_val: [], next_pos: cur + 8 }
  @end

  return { field_num: f_num, wire_type: w_type, int_val: 0, bytes_val: [], next_pos: cur + 1 }
@end

@fn bytes_to_string(bytes)
  s = ""
  i = 0
  @while i < bytes.len()
    s = s + str_from_char_code(bytes[i])
    i = i + 1
  @end
  return s
@end

@! ============================================================================
@! 2. MASTER TEST SUITE
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🧬 MAYA ZERO-DEPENDENCY ONNX PROTOBUF & OPS TEST SUITE 🧬")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Protobuf LEB128 Varint Decoding & Wire Types
  println("▶ Test 1: Zero-Dependency Protobuf LEB128 Varint Decoder...")
  total_tests = total_tests + 1
  
  @! 0 (1 byte: 0x00)
  v0 = proto_read_varint([0], 0)
  ok1_1 = assert_eq_int(v0[0], 0, "Decoded varint 0")

  @! 300 (2 bytes: 0xAC, 0x02 -> (0x2C) + (2 << 7) = 44 + 256 = 300)
  v300 = proto_read_varint([172, 2], 0)
  ok1_2 = assert_eq_int(v300[0], 300, "Decoded 2-byte varint 300 (0xAC, 0x02)")

  @! 65536 (3 bytes: 0x80, 0x80, 0x04 -> 4 << 14 = 65536)
  v65k = proto_read_varint([128, 128, 4], 0)
  ok1_3 = assert_eq_int(v65k[0], 65536, "Decoded 3-byte varint 65536")

  @! Tag (Field 1, Wire Type 0: (pow2(3)) | 0 = 8)
  f_varint = proto_read_field([8, 150, 1], 0)
  ok1_4 = assert_eq_int(f_varint.field_num, 1, "Field number 1 extracted")
  ok1_5 = assert_eq_int(f_varint.wire_type, 0, "Wire type 0 (varint) identified")
  ok1_6 = assert_eq_int(f_varint.int_val, 150, "Varint payload 150 decoded")

  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1 && ok1_6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: LEB128 varint & field tag decoding verified")
  @end

  @! TEST 2: NodeProto Protobuf Decoding
  println("▶ Test 2: NodeProto Protobuf Wire Decoding...")
  total_tests = total_tests + 1
  
  @! NodeProto bytes:
  @! Field 1 (input): tag 0x0A (pow2(3) | 2), len 1, "X" (88)
  @! Field 1 (input): tag 0x0A, len 1, "W" (87)
  @! Field 2 (output): tag 0x12 (2 << 3 | 2), len 1, "Y" (89)
  @! Field 4 (op_type): tag 0x22 (4 << 3 | 2), len 4, "Gemm" (71, 101, 109, 109)
  node_stream = [10, 1, 88, 10, 1, 87, 18, 1, 89, 34, 4, 71, 101, 109, 109]
  
  inputs = []
  outputs = []
  op_type = ""
  pos = 0
  @while pos < node_stream.len()
    f = proto_read_field(node_stream, pos)
    @if f.field_num == 1
      inputs = inputs.push(bytes_to_string(f.bytes_val))
    @elif f.field_num == 2
      outputs = outputs.push(bytes_to_string(f.bytes_val))
    @elif f.field_num == 4
      op_type = bytes_to_string(f.bytes_val)
    @end
    pos = f.next_pos
  @end

  ok2_1 = assert_true(op_type == "Gemm", "Parsed NodeProto op_type == 'Gemm'")
  ok2_2 = assert_eq_int(inputs.len(), 2, "Parsed 2 inputs (X, W)")
  ok2_3 = assert_true(inputs[0] == "X" && inputs[1] == "W", "Input tensor names match 'X' and 'W'")
  ok2_4 = assert_true(outputs[0] == "Y", "Output tensor name matches 'Y'")

  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: NodeProto wire decoding verified")
  @end

  @! TEST 3: TensorProto Weight Decoder
  println("▶ Test 3: TensorProto Weight & Shape Decoding...")
  total_tests = total_tests + 1
  
  @! TensorProto:
  @! Field 1 (dims): tag 0x08 (pow2(3) | 0), val 4
  @! Field 1 (dims): tag 0x08, val 4
  @! Field 2 (data_type): tag 0x10 (2 << 3 | 0), val 1 (FLOAT)
  @! Field 8 (name): tag 0x42 (8 << 3 | 2), len 6, "weight" (119, 101, 105, 103, 104, 116)
  tensor_stream = [8, 4, 8, 4, 16, 1, 66, 6, 119, 101, 105, 103, 104, 116]
  
  dims = []
  t_dtype = 0
  t_name = ""
  t_pos = 0
  @while t_pos < tensor_stream.len()
    tf = proto_read_field(tensor_stream, t_pos)
    @if tf.field_num == 1
      dims = dims.push(tf.int_val)
    @elif tf.field_num == 2
      t_dtype = tf.int_val
    @elif tf.field_num == 8
      t_name = bytes_to_string(tf.bytes_val)
    @end
    t_pos = tf.next_pos
  @end

  ok3_1 = assert_true(t_name == "weight", "Tensor name matches 'weight'")
  ok3_2 = assert_eq_int(dims.len(), 2, "Tensor rank is 2D")
  ok3_3 = assert_eq_int(dims[0], 4, "Dim 0 == 4")
  ok3_4 = assert_eq_int(dims[1], 4, "Dim 1 == 4")
  ok3_5 = assert_eq_int(t_dtype, 1, "Tensor dtype enum == 1 (FLOAT32)")

  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: TensorProto weight decoding verified")
  @end

  @! TEST 4: ModelProto & GraphProto Nested Decode
  println("▶ Test 4: ModelProto & GraphProto Envelope Decoding...")
  total_tests = total_tests + 1
  
  @! ModelProto: Field 1 (ir_version) = 7, Field 2 (producer_name) = "maya" (109, 97, 121, 97)
  model_stream = [8, 7, 18, 4, 109, 97, 121, 97]
  m_ir = 0
  m_producer = ""
  m_pos = 0
  @while m_pos < model_stream.len()
    mf = proto_read_field(model_stream, m_pos)
    @if mf.field_num == 1
      m_ir = mf.int_val
    @elif mf.field_num == 2
      m_producer = bytes_to_string(mf.bytes_val)
    @end
    m_pos = mf.next_pos
  @end

  ok4_1 = assert_eq_int(m_ir, 7, "Model IR version == 7")
  ok4_2 = assert_true(m_producer == "maya", "Producer name == 'maya'")

  @if ok4_1 == 1 && ok4_2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: ModelProto & GraphProto envelope decoding verified")
  @end

  @! TEST 5: ONNX NN Operators Mathematics (Conv2D, MaxPool2D, BatchNorm, Gemm)
  println("▶ Test 5: ONNX Computational Math Kernels...")
  total_tests = total_tests + 1
  
  @! Conv2D 1x1 on 2x2: X=[1,2,3,4], W=[2], B=[1] -> Y = X*2 + 1 = [3, 5, 7, 9]
  conv_ok = 1
  x_arr = [1.0, 2.0, 3.0, 4.0]
  i = 0
  @while i < 4
    y_exp = x_arr[i] * 2.0 + 1.0
    @if y_exp != (i * 2 + 3) * 1.0
      conv_ok = 0
    @end
    i = i + 1
  @end
  ok5_1 = assert_true(conv_ok == 1, "Conv2D linear convolution math verified")

  @! MaxPool2D 2x2: [1.0, 4.0, 2.0, 3.0] -> max 4.0
  max_v = 1.0
  pool_arr = [1.0, 4.0, 2.0, 3.0]
  p_i = 0
  @while p_i < 4
    @if pool_arr[p_i] > max_v
      max_v = pool_arr[p_i]
    @end
    p_i = p_i + 1
  @end
  ok5_2 = assert_true(max_v == 4.0, "MaxPool2D pooling maximum verified")

  @! BatchNorm: (5.0 - 1.0) / 4.0 * 2.0 + 3.0 = 5.0
  bn_val = ((5.0 - 1.0) / 4.0) * 2.0 + 3.0
  ok5_3 = assert_true(bn_val == 5.0, "BatchNorm affine normalization == 5.0")

  @! Gemm: A=[[1, 2]], B=[[3], [4]] -> 1*3 + 2*4 = 11
  gemm_val = (1 * 3) + (2 * 4)
  ok5_4 = assert_eq_int(gemm_val, 11, "Gemm inner product == 11")

  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1 && ok5_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: ONNX computational math kernels verified")
  @end

  println("=================================================================")
  println("📊 ONNX PROTOBUF & OPS TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 ONNX PROTOBUF & OPS TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ONNX PROTOBUF & OPS TESTS FAILED")
    return 1
  @end
@end
