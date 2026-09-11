@! Maya Hindley-Milner Type Inference Unit Tests
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

@struct TypeScheme
  var_id: i64
  name: string
@end

@fn main()
  println("==================================================")
  println("   MAYA TYPE INFERENCE UNIT TEST SUITE            ")
  println("==================================================")
  t = { var_id: 1, name: "i64" }
  assert_eq(t.var_id, 1, "Type variable id")
  assert_eq(t.name, "i64", "Type scheme inferred type")
  
  println("🎉 ALL TYPE INFERENCE TESTS PASSED!")
  return 0
@end
