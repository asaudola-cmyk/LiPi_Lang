import "packages/json_toolkit/src/lib"

@fn main()
  println("--- JSON Toolkit Test ---")
  
  v = json_validate("{}")
  @if v == 1
    println("PASS: json_validate")
  @else
    println("FAIL: json_validate")
  @end
  
  return 0
@end
