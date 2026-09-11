import "universe/web/router"
import "universe/web/server"

@fn handle_index(req)
  return "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>Hello from Lipi!</h1><p>Maya is the Universe.</p>"
@end

@fn handle_api_status(req)
  return "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\": \"ok\", \"lang\": \"maya\", \"version\": \"2.0.0\"}"
@end

@fn handle_not_found(req)
  return "HTTP/1.1 404 Not Found\r\n\r\nNot found"
@end

@fn main()
  println("Lipi HTTP Server Demo")
  println("Simulating request handling...")
  
  @! Simulate router
  r = router_new()
  router_add(r, "GET", "/", 1)
  router_add(r, "GET", "/api/status", 2)
  
  @! Test route matching
  m1 = router_match(r, "GET", "/")
  println("GET / -> handler ID: " + int_to_str(m1.handler_index))
  
  m2 = router_match(r, "GET", "/api/status")
  println("GET /api/status -> handler ID: " + int_to_str(m2.handler_index))
  
  @! Simulate responses
  println(handle_index(""))
  println(handle_api_status(""))
  
  println("[OK] HTTP routing works!")
  return 0
@end
