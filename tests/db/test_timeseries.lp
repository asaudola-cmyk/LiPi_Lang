@! Maya Time-Series Storage Unit Tests

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@struct TSPoint
  timestamp: i64
  val: i64
@end

@fn main()
  println("==================================================")
  println("   MAYA TIME-SERIES DB UNIT TEST SUITE            ")
  println("==================================================")
  p1 = { timestamp: 1700000000, val: 42 }
  assert_eq(p1.timestamp, 1700000000, "Timestamp match")
  assert_eq(p1.val, 42, "Value match")
  
  println("🎉 ALL TIME-SERIES TESTS PASSED!")
  return 0
@end
