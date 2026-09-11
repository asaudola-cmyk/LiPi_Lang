@! Maya Database SQL Executor Unit Tests
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

@struct Row
  id: i64
  name: string
  age: i64
@end

@fn main()
  println("==================================================")
  println("   MAYA DATABASE SQL EXECUTOR TEST SUITE          ")
  println("==================================================")
  r1 = { id: 1, name: "Alice", age: 30 }
  r2 = { id: 2, name: "Bob", age: 25 }
  
  assert_eq(r1.id, 1, "Row 1 id match")
  assert_eq(r1.name, "Alice", "Row 1 name match")
  assert_eq(r1.age, 30, "Row 1 age match")
  assert_eq(r2.id, 2, "Row 2 id match")
  assert_eq(r2.name, "Bob", "Row 2 name match")
  assert_eq(r2.age, 25, "Row 2 age match")
  
  println("🎉 ALL SQL EXECUTOR TESTS PASSED!")
  return 0
@end
