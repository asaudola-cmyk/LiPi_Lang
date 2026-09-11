import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/net"

@fn main()
  string_println("=== Native Maya Web Server ===")
  
  sockfd = net_socket()
  @if sockfd < 0
    string_println("Failed to create socket.")
    sys_exit(1)
  @end
  
  @! Enable SO_REUSEADDR (sys_setsockopt syscall = 54)
  @! level = SOL_SOCKET (1), optname = SO_REUSEADDR (2)
  optval = sys_mmap(0, 4, 3, 34, 0 - 1, 0)
  sys_poke(optval, 1) @! int = 1
  sys_syscall(54, sockfd, 1, 2, optval, 4, 0)
  
  port = 8080
  string_print("Binding to port: ")
  print_int(port)
  
  res = net_bind(sockfd, port)
  @if res < 0
    string_println("Failed to bind socket.")
    sys_exit(1)
  @end
  
  res = net_listen(sockfd, 10)
  @if res < 0
    string_println("Failed to listen.")
    sys_exit(1)
  @end
  
  string_println("Server is running on http://127.0.0.1:8080 ...")
  
  @! Run one iteration for testing (so it doesn't block forever)
  client_fd = net_accept(sockfd)
  @if client_fd >= 0
    string_println("Client connected!")
    
    @! Read HTTP Request
    buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
    bytes_read = net_read(client_fd, buf, 4096)
    
    @if bytes_read > 0
      string_println("Received Request:")
      sys_syscall(1, 1, buf, bytes_read, 0, 0, 0)
      
      @! Send HTTP Response
      resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n<h1>Hello from Native Maya (Universe B)!</h1><p>Served by a custom language compiler written in itself.</p>"
      resp_len = string_len(resp)
      
      net_write(client_fd, resp, resp_len)
      string_println("Response sent.")
    @end
    
    net_close(client_fd)
  @end
  
  net_close(sockfd)
  string_println("Server shut down cleanly.")
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
