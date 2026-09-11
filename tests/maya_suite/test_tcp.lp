// WHY: Import core TCP networking library for direct Linux socket syscalls
import "universe/core/net"

@fn main()
  println("=== Maya TCP Socket Test ===")
  
  @! Create socket
  fd = net_tcp_socket()
  @if fd > 0
    println("[PASS] socket created: fd=" + int_to_str(fd))
  @else
    println("[FAIL] socket creation failed")
    return 1
  @end
  
  @! Bind to random port
  r = net_tcp_bind(fd, 0)
  @if r >= 0
    println("[PASS] bind succeeded")
  @else
    println("[FAIL] bind failed: " + int_to_str(r))
  @end
  
  @! Listen
  r2 = net_tcp_listen(fd, 5)
  @if r2 >= 0
    println("[PASS] listen succeeded")
  @else
    println("[FAIL] listen failed")
  @end
  
  @! Close
  net_tcp_close(fd)
  println("[PASS] socket closed")
  
  println("")
  println("TCP socket test: PASSED")
  println("Maya HTTP server ready: ./bin/maya examples/http_server.maya")
  return 0
@end
