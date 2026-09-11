@! ============================================================================
@! ADVERSARIAL TEST SUITE: WEBASSEMBLY LEB128 BOUNDARY VALUES & STRESS
@! File: tests/adversarial/test_phase2_leb128_adversarial.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"
import "compiler/backend/wasm/codegen"

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_bytes_eq(buf_bytes, expected_list, test_name)
  @if buf_bytes.len() != expected_list.len()
    println("  [FAIL] " + test_name + " length mismatch: expected " + expected_list.len().to_str() + ", got " + buf_bytes.len().to_str())
    return 0
  @end
  i = 0
  @while i < expected_list.len()
    @if buf_bytes[i] != expected_list[i]
      println("  [FAIL] " + test_name + " byte[" + i.to_str() + "] mismatch: expected " + expected_list[i].to_str() + ", got " + buf_bytes[i].to_str())
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn test_sleb(val, expected, name)
  b = bytebuf_new()
  encode_i64_leb128(b, val)
  ok1 = assert_bytes_eq(b.bytes, expected, "encode_i64_leb128 " + name)

  wb = wasm_buf_new()
  wasm_buf_sleb128(wb, val)
  ok2 = assert_bytes_eq(wb.wb_data, expected, "wasm_buf_sleb128 " + name)

  @if ok1 == 1 && ok2 == 1
    return 1
  @end
  return 0
@end

@fn test_uleb(val, expected, name)
  b = bytebuf_new()
  encode_u64_leb128(b, val)
  ok1 = assert_bytes_eq(b.bytes, expected, "encode_u64_leb128 " + name)

  wb = wasm_buf_new()
  wasm_buf_leb128(wb, val)
  ok2 = assert_bytes_eq(wb.wb_data, expected, "wasm_buf_leb128 " + name)

  @if ok1 == 1 && ok2 == 1
    return 1
  @end
  return 0
@end

@fn main()
  println("=================================================================")
  println("⚡ ADVERSARIAL LEB128 BOUNDARY & STRESS VERIFICATION ⚡")
  println("=================================================================")

  total = 0
  passed = 0

  @! 1. SLEB128 Zero & Single-Byte Boundaries
  println("▶ Section 1: SLEB128 Basic & Single-Byte Boundaries...")
  total = total + 1
  ok = 1
  ok = ok & test_sleb(0, [0], "0")
  ok = ok & test_sleb(1, [1], "1")
  ok = ok & test_sleb(-1, [127], "-1")
  ok = ok & test_sleb(63, [63], "63 (0x3F)")
  ok = ok & test_sleb(-64, [64], "-64 (0x40)")
  @if ok == 1
    passed = passed + 1
    println("  [PASS] Single-byte SLEB128 boundaries verified")
  @end

  @! 2. SLEB128 Multi-Byte 7-bit Transitions
  println("▶ Section 2: SLEB128 7-bit Multi-Byte Transitions...")
  total = total + 1
  ok = 1
  ok = ok & test_sleb(64, [192, 0], "64 (0x40 positive extension)")
  ok = ok & test_sleb(-65, [191, 127], "-65")
  ok = ok & test_sleb(127, [255, 0], "127")
  ok = ok & test_sleb(-128, [128, 127], "-128")
  ok = ok & test_sleb(128, [128, 1], "128")
  ok = ok & test_sleb(-129, [255, 126], "-129")
  ok = ok & test_sleb(255, [255, 1], "255")
  ok = ok & test_sleb(-256, [128, 126], "-256")
  ok = ok & test_sleb(256, [128, 2], "256")
  ok = ok & test_sleb(624485, [229, 142, 38], "624485")
  ok = ok & test_sleb(-624485, [155, 241, 89], "-624485")
  @if ok == 1
    passed = passed + 1
    println("  [PASS] Multi-byte SLEB128 transition vectors verified")
  @end

  @! 3. SLEB128 32-bit and 64-bit Extremes
  println("▶ Section 3: SLEB128 32-Bit & 64-Bit Extremes...")
  total = total + 1
  ok = 1
  ok = ok & test_sleb(2147483647, [255, 255, 255, 255, 7], "INT32_MAX (2147483647)")
  ok = ok & test_sleb(-2147483648, [128, 128, 128, 128, 120], "INT32_MIN (-2147483648)")
  ok = ok & test_sleb(4294967295, [255, 255, 255, 255, 15], "2^32 - 1")
  ok = ok & test_sleb(4294967296, [128, 128, 128, 128, 16], "2^32")
  @if ok == 1
    passed = passed + 1
    println("  [PASS] 32-bit & 64-bit SLEB128 extreme vectors verified")
  @end

  @! 4. ULEB128 Boundary & Bit Transitions
  println("▶ Section 4: ULEB128 Boundary Vectors...")
  total = total + 1
  ok = 1
  ok = ok & test_uleb(0, [0], "ULEB 0")
  ok = ok & test_uleb(1, [1], "ULEB 1")
  ok = ok & test_uleb(127, [127], "ULEB 127")
  ok = ok & test_uleb(128, [128, 1], "ULEB 128")
  ok = ok & test_uleb(255, [255, 1], "ULEB 255")
  ok = ok & test_uleb(256, [128, 2], "ULEB 256")
  ok = ok & test_uleb(16383, [255, 127], "ULEB 16383 (0x3FFF)")
  ok = ok & test_uleb(16384, [128, 128, 1], "ULEB 16384 (0x4000)")
  ok = ok & test_uleb(624485, [229, 142, 38], "ULEB 624485")
  ok = ok & test_uleb(4294967295, [255, 255, 255, 255, 15], "ULEB UINT32_MAX")
  @if ok == 1
    passed = passed + 1
    println("  [PASS] ULEB128 boundary vectors verified")
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL LEB128 RESULTS: " + passed.to_str() + " / " + total.to_str() + " sections passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL ADVERSARIAL LEB128 TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ ADVERSARIAL LEB128 TESTS FAILED")
    return 1
  @end
@end
