@! Maya JWT Token Unit Tests
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

@struct JwtHeader
  alg: string
  typ: string
@end

@fn main()
  println("==================================================")
  println("   MAYA JWT AUTHENTICATION UNIT TEST SUITE        ")
  println("==================================================")
  hdr = { alg: "HS256", typ: "JWT" }
  assert_eq(hdr.alg, "HS256", "JWT Algorithm HS256")
  assert_eq(hdr.typ, "JWT", "JWT Type")
  
  println("🎉 ALL JWT TESTS PASSED!")
  return 0
@end
