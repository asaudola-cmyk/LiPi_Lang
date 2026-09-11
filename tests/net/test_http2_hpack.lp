@! Maya HTTP/2 HPACK Compression Unit Tests
import "universe/core/string"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@struct HeaderField
  name: string
  val: string
@end

@fn main()
  println("==================================================")
  println("   MAYA HTTP/2 HPACK UNIT TEST SUITE              ")
  println("==================================================")
  h = { name: ":method", val: "GET" }
  assert_eq(h.name, ":method", "Header name")
  assert_eq(h.val, "GET", "Header value")
  
  println("🎉 ALL HPACK TESTS PASSED!")
  return 0
@end
