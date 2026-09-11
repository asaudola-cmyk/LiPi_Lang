import "packages/web_router/src/lib"

@fn main()
  println("--- Web Router Test ---")
  
  r = route_add("/home", 42)
  @if r.handler_id == 42
    println("PASS: route_add")
  @else
    println("FAIL: route_add")
  @end
  
  return 0
@end
