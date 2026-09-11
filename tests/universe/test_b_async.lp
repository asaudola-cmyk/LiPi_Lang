import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/net"
import "universe/b_core/async"

@fn main()
  string_println("=== Native Maya Async Server (epoll) ===")
  
  sockfd = net_socket()
  @if sockfd < 0 sys_exit(1) @end
  
  optval = sys_mmap(0, 4, 3, 34, 0 - 1, 0)
  sys_poke(optval, 1)
  sys_syscall(54, sockfd, 1, 2, optval, 4, 0) @! SO_REUSEADDR
  
  port = 8888
  res = net_bind(sockfd, port)
  @if res < 0 sys_exit(1) @end
  
  net_listen(sockfd, 128)
  async_make_nonblocking(sockfd)
  
  string_println("Async Server running on http://127.0.0.1:8888")
  
  epfd = async_epoll_create()
  @if epfd < 0
    string_println("Failed to create epoll.")
    sys_exit(1)
  @end
  
  async_epoll_add(epfd, sockfd)
  
  @! Buffer to hold up to 10 events (16 bytes each)
  events_buf = sys_mmap(0, 160, 3, 34, 0 - 1, 0)
  
  @! For testing, we will just count up to 3 processed events before exiting
  processed = 0
  
  @while processed < 3
    string_println("Waiting for events...")
    @! epoll_wait(epfd, events_buf, 10, -1)
    n_events = async_epoll_wait(epfd, events_buf, 10, 0 - 1)
    
    i = 0
    @while i < n_events
      event_flags = sys_peek(events_buf + (i * 16))
      event_fd = sys_peek(events_buf + (i * 16) + 8)
      
      @if event_fd == sockfd
        @! New incoming connection
        string_println("Event: New Connection!")
        client_fd = net_accept(sockfd)
        @if client_fd >= 0
          async_make_nonblocking(client_fd)
          async_epoll_add(epfd, client_fd)
        @end
      @else
        @! Data from client
        string_println("Event: Data Received!")
        read_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
        bytes = sys_syscall(0, event_fd, read_buf, 4096, 0, 0, 0) @! sys_read
        
        @if bytes > 0
          resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nHello from the Async Maya Event Loop!"
          sys_syscall(1, event_fd, resp, string_len(resp), 0, 0, 0) @! sys_write
        @end
        
        @! Close the connection (epoll automatically removes closed fds)
        sys_syscall(3, event_fd, 0, 0, 0, 0, 0)
        string_println("Connection closed.")
        processed = processed + 1
      @end
      
      i = i + 1
    @end
  @end
  
  sys_syscall(3, sockfd, 0, 0, 0, 0, 0)
  string_println("Async Server shutting down cleanly.")
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
