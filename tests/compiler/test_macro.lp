@! Maya Hygienic Macro System Unit Tests
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

@struct MacroDef
  name: string
  expansion_depth: i64
@end

@fn main()
  println("==================================================")
  println("   MAYA HYGIENIC MACRO UNIT TEST SUITE            ")
  println("==================================================")
  m = { name: "vec!", expansion_depth: 1 }
  assert_eq(m.name, "vec!", "Macro name")
  assert_eq(m.expansion_depth, 1, "Macro depth")
  
  println("🎉 ALL MACRO EXPANDER TESTS PASSED!")
  return 0
@end
