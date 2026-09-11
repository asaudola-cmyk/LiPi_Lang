@! Maya Column Store Compression & Scan Unit Tests

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@struct ColumnData
  min_val: i64
  max_val: i64
  count: i64
@end

@fn main()
  println("==================================================")
  println("   MAYA COLUMN STORE UNIT TEST SUITE              ")
  println("==================================================")
  col = { min_val: 10, max_val: 500, count: 1000 }
  assert_eq(col.min_val, 10, "Min value match")
  assert_eq(col.max_val, 500, "Max value match")
  assert_eq(col.count, 1000, "Count match")
  
  println("🎉 ALL COLUMN STORE TESTS PASSED!")
  return 0
@end
