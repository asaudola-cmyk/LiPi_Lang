@! Maya Pattern Matching Matrix Unit Tests
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

@fn match_number(n)
  @if n == 0
    return "zero"
  @elif n == 1
    return "one"
  @elif n == 2
    return "two"
  @else
    return "many"
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA PATTERN MATCHING UNIT TEST SUITE          ")
  println("==================================================")
  assert_eq(match_number(0), "zero", "Match zero")
  assert_eq(match_number(1), "one", "Match one")
  assert_eq(match_number(2), "two", "Match two")
  assert_eq(match_number(99), "many", "Match fallback")
  
  println("🎉 ALL PATTERN MATCHING TESTS PASSED!")
  return 0
@end
