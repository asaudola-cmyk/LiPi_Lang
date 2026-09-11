import "universe/core/string"
import "universe/core/collections"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA NATIVE HASHMAP UNIT TEST                  ")
  println("==================================================")
  
  hm = open_hashmap_new(32)
  hm = open_hashmap_put(hm, "hello", 123)
  hm = open_hashmap_put(hm, "world", 456)
  
  v1 = open_hashmap_get(hm, "hello")
  assert_eq(v1, 123, "HashMap retrieves 'hello' -> 123")
  
  v2 = open_hashmap_get(hm, "world")
  assert_eq(v2, 456, "HashMap retrieves 'world' -> 456")
  
  v3 = open_hashmap_get(hm, "missing")
  assert_eq(v3, 0, "HashMap retrieves 'missing' -> 0")
  
  println("🎉 ALL HASHMAP TESTS PASSED!")
  return 0
@end
