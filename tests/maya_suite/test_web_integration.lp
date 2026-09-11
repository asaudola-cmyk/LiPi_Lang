import "universe/web/router"

println("--- Web Router Integration Test ---")

r = router_new()
router_add(r, "GET", "/users", 1)
router_add(r, "POST", "/users", 2)
router_add(r, "GET", "/users/:id", 3)

match1 = router_match(r, "GET", "/users")
@if match1.matched == 1 && match1.handler_index == 1
  println("PASS: GET /users")
@else
  println("FAIL: GET /users")
@end

match2 = router_match(r, "POST", "/users")
@if match2.matched == 1 && match2.handler_index == 2
  println("PASS: POST /users")
@else
  println("FAIL: POST /users")
@end

match3 = router_match(r, "GET", "/users/123")
@if match3.matched == 1 && match3.handler_index == 3
  println("PASS: GET /users/:id")
@else
  println("FAIL: GET /users/:id")
@end

match4 = router_match(r, "DELETE", "/users")
@if match4.matched == 0 && match4.status_code == 405
  println("PASS: DELETE /users")
@else
  println("FAIL: DELETE /users")
@end
