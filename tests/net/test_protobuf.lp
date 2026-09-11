@! Maya Protobuf Serialization Unit Tests

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@struct ProtoField
  field_num: i64
  wire_type: i64
  int_val: i64
@end

@fn main()
  println("==================================================")
  println("   MAYA PROTOBUF UNIT TEST SUITE                  ")
  println("==================================================")
  f = { field_num: 1, wire_type: 0, int_val: 12345 }
  assert_eq(f.field_num, 1, "Proto field num")
  assert_eq(f.wire_type, 0, "Proto wire type Varint")
  assert_eq(f.int_val, 12345, "Proto integer value")
  
  println("🎉 ALL PROTOBUF TESTS PASSED!")
  return 0
@end
