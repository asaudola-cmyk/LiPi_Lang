@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — ONNX PROTOBUF BOUNDARIES & STRESS SUITE
@! File: tests/ai/test_onnx_protobuf_boundaries.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 2
@! TAGS: ai, onnx, protobuf, boundaries
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
@! PROTOBUF BOUNDARY & WIRE PARSER
@! ============================================================================

@struct WireField
  field_num: i64
  wire_type: i64
  val_int: i64
  raw_len: i64
  next_idx: i64
@end

@struct DAGNode
  id: i64
  name: string
  deps: array
  visited: i64
@end

@fn proto_read_varint_safe(bytes, pos)
  val = 0
  shift = 0
  idx = pos
  more = 1
  bytes_read = 0
  @while more == 1 && idx < bytes.len() && bytes_read < 10
    b = bytes[idx]
    chunk = b & 127
    val = val + (chunk << shift)
    @if b & 128 == 0
      more = 0
    @end
    shift = shift + 7
    idx = idx + 1
    bytes_read = bytes_read + 1
  @end
  return [val, idx]
@end

@fn proto_skip_unknown_field(bytes, pos, wire_type)
  @if wire_type == 0  @! Varint
    res = proto_read_varint_safe(bytes, pos)
    return res[1]
  @elif wire_type == 1  @! 64-bit
    return pos + 8
  @elif wire_type == 2  @! Length-delimited
    len_res = proto_read_varint_safe(bytes, pos)
    l_len = len_res[0]
    l_end = len_res[1] + l_len
    @if l_end > bytes.len() return bytes.len() @end
    return l_end
  @elif wire_type == 5  @! 32-bit
    return pos + 4
  @end
  return pos + 1
@end

@! ============================================================================
@! MASTER TEST SUITE
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🧬 ONNX PROTOBUF BOUNDARIES & TOPOLOGICAL SORT TEST SUITE 🧬")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! TEST 1: Maximum 64-bit Varint & Boundary Varints
  println("▶ Test 1: Maximum 64-bit Varint Decoding...")
  total_tests = total_tests + 1
  
  @! 10-byte 64-bit max varint
  b_max = [255, 255, 255, 255, 255, 255, 255, 255, 127]
  v_max_res = proto_read_varint_safe(b_max, 0)
  ok1_1 = assert_true(v_max_res[0] > 0, "Decoded large 64-bit integer without overflow")
  ok1_2 = assert_eq_int(v_max_res[1], 9, "Consumed exactly 9 varint bytes")

  @! Single byte boundaries (127 vs 128)
  v127 = proto_read_varint_safe([127], 0)
  ok1_3 = assert_eq_int(v127[0], 127, "Varint 127 (single byte)")
  v128 = proto_read_varint_safe([128, 1], 0)
  ok1_4 = assert_eq_int(v128[0], 128, "Varint 128 (two bytes: 0x80, 0x01)")

  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 1: Maximum 64-bit varints & boundary values verified")
  @end

  @! TEST 2: Unknown & Foreign Field Tag Skipping
  println("▶ Test 2: Unrecognized Field Tag Skipping (Wire Types 0, 1, 2, 5)...")
  total_tests = total_tests + 1
  
  @! Stream:
  @! Tag (Field 99, Wire Type 0): [152, 6, 42] -> skip varint
  @! Tag (Field 100, Wire Type 1): [161, 6, 1, 2, 3, 4, 5, 6, 7, 8] -> skip 8 bytes
  @! Tag (Field 101, Wire Type 2): [170, 6, 3, 65, 66, 67] -> skip 3 bytes
  @! Tag (Field 1, Wire Type 0): [8, 10] -> target field 1 = 10
  stream = [152, 6, 42, 161, 6, 1, 2, 3, 4, 5, 6, 7, 8, 170, 6, 3, 65, 66, 67, 8, 10]
  
  pos = 0
  target_val = 0
  @while pos < stream.len()
    tag_r = proto_read_varint_safe(stream, pos)
    tag = tag_r[0]
    cur = tag_r[1]
    f_num = tag >> 3
    w_type = tag & 7
    @if f_num == 1
      v_r = proto_read_varint_safe(stream, cur)
      target_val = v_r[0]
      pos = v_r[1]
    @else
      pos = proto_skip_unknown_field(stream, cur, w_type)
    @end
  @end

  ok2_1 = assert_eq_int(target_val, 10, "Successfully skipped unknown fields 99, 100, 101 and read target field 1 = 10")
  @if ok2_1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 2: Unrecognized field skipping verified")
  @end

  @! TEST 3: Truncated Buffer & Corrupted Length Handling
  println("▶ Test 3: Truncated Buffer & Corrupted Delimiter Recovery...")
  total_tests = total_tests + 1
  
  @! Length delimiter says 50 bytes, but only 2 bytes available
  trunc_stream = [18, 50, 65, 66]
  tag_r3 = proto_read_varint_safe(trunc_stream, 0)
  cur3 = tag_r3[1]
  next_pos3 = proto_skip_unknown_field(trunc_stream, cur3, 2)
  
  ok3_1 = assert_eq_int(next_pos3, trunc_stream.len(), "Truncated length delimiter bounded to buffer end without out-of-bounds crash")
  @if ok3_1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 3: Truncated buffer recovery verified")
  @end

  @! TEST 4: ONNX Graph Topological Sorting (Dependency DAG Resolver)
  println("▶ Test 4: ONNX Graph Topological Sorting...")
  total_tests = total_tests + 1
  
  @! Nodes defined out of order:
  @! Node 0: "Softmax" (depends on "Relu")
  @! Node 1: "Conv" (depends on "Input")
  @! Node 2: "Relu" (depends on "Conv")
  @! Correct topological order: Node 1 ("Conv") -> Node 2 ("Relu") -> Node 0 ("Softmax")
  
  node_names = ["Softmax", "Conv", "Relu"]
  node_inputs = [["relu_out"], ["image_in"], ["conv_out"]]
  node_outputs = [["prob_out"], ["conv_out"], ["relu_out"]]
  
  resolved_order = []
  available_tensors = ["image_in"]
  
  pass_count = 0
  @while resolved_order.len() < 3 && pass_count < 10
    n_idx = 0
    @while n_idx < 3
      name = node_names[n_idx]
      already = 0
      r_i = 0
      @while r_i < resolved_order.len()
        @if resolved_order[r_i] == name already = 1 @end
        r_i = r_i + 1
      @end
      
      @if already == 0
        req_in = node_inputs[n_idx][0]
        has_in = 0
        a_i = 0
        @while a_i < available_tensors.len()
          @if available_tensors[a_i] == req_in has_in = 1 @end
          a_i = a_i + 1
        @end
        
        @if has_in == 1
          resolved_order = resolved_order.push(name)
          available_tensors = available_tensors.push(node_outputs[n_idx][0])
        @end
      @end
      n_idx = n_idx + 1
    @end
    pass_count = pass_count + 1
  @end

  ok4_1 = assert_eq_int(resolved_order.len(), 3, "Topologically sorted 3 nodes")
  ok4_2 = assert_true(resolved_order[0] == "Conv", "First resolved node is 'Conv'")
  ok4_3 = assert_true(resolved_order[1] == "Relu", "Second resolved node is 'Relu'")
  ok4_4 = assert_true(resolved_order[2] == "Softmax", "Third resolved node is 'Softmax'")
  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1 && ok4_4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 4: Graph topological sort verified")
  @end

  @! TEST 5: Zero-Byte & Minimal Protobuf Submessage Boundaries
  println("▶ Test 5: Zero-Byte & Minimal Submessage Parsing...")
  total_tests = total_tests + 1
  
  @! Empty byte stream
  empty_r = proto_read_varint_safe([], 0)
  ok5_1 = assert_eq_int(empty_r[0], 0, "Empty stream varint returns 0")
  ok5_2 = assert_eq_int(empty_r[1], 0, "Empty stream next pos is 0")
  
  @! Length-0 string field: Tag 0x0A (field 1, wire 2), len 0
  len0_stream = [10, 0]
  len0_r = proto_read_varint_safe(len0_stream, 0)
  len0_val = proto_read_varint_safe(len0_stream, len0_r[1])
  ok5_3 = assert_eq_int(len0_val[0], 0, "Length-0 delimited field parsed as 0 bytes")
  @if ok5_1 == 1 && ok5_2 == 1 && ok5_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Test 5: Zero-byte & minimal submessage boundaries verified")
  @end

  println("=================================================================")
  println("📊 ONNX BOUNDARIES TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 5 ONNX BOUNDARIES TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ONNX BOUNDARIES TESTS FAILED")
    return 1
  @end
@end
