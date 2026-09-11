import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/net"
import "universe/b_core/async"

@! Helper to broadcast message to all clients except sender
@fn broadcast(client_fds, max_clients, sender_fd, msg)
  len = string_len(msg)
  i = 0
  @while i < max_clients
    fd = sys_peek(client_fds + (i * 8))
    @if fd > 0
      @if fd != sender_fd
        sys_syscall(1, fd, msg, len, 0, 0, 0)
      @end
    @end
    i = i + 1
  @end
  return 0
@end

@fn main()
  string_println("=== Native Maya Multiplayer Game Server ===")
  
  max_clients = 10
  client_fds = sys_mmap(0, max_clients * 8, 3, 34, 0 - 1, 0)
  
  @! Initialize fds to 0
  i = 0
  @while i < max_clients
    sys_poke(client_fds + (i * 8), 0)
    i = i + 1
  @end
  
  sockfd = net_socket()
  @if sockfd < 0 sys_exit(1) @end
  
  optval = sys_mmap(0, 4, 3, 34, 0 - 1, 0)
  sys_poke(optval, 1)
  sys_syscall(54, sockfd, 1, 2, optval, 4, 0) @! SO_REUSEADDR
  
  port = 7777
  res = net_bind(sockfd, port)
  @if res < 0 sys_exit(1) @end
  
  net_listen(sockfd, 10)
  async_make_nonblocking(sockfd)
  
  epfd = async_epoll_create()
  async_epoll_add(epfd, sockfd)
  
  events_buf = sys_mmap(0, 160, 3, 34, 0 - 1, 0)
  string_println("Game Server running on port 7777. Waiting for players...")
  
  @! Run the loop for 100 events (enough for testing)
  processed = 0
  @while processed < 100
    n_events = async_epoll_wait(epfd, events_buf, 10, 0 - 1)
    
    i = 0
    @while i < n_events
      event_fd = sys_peek(events_buf + (i * 16) + 8)
      
      @if event_fd == sockfd
        @! New Player Connected
        client_fd = net_accept(sockfd)
        @if client_fd >= 0
          async_make_nonblocking(client_fd)
          async_epoll_add(epfd, client_fd)
          
          @! Find empty slot
          j = 0
          added = 0
          @while j < max_clients
            @if sys_peek(client_fds + (j * 8)) == 0
              sys_poke(client_fds + (j * 8), client_fd)
              added = 1
              
              @! Send welcome
              msg = "Welcome to Maya Realm! You are Player connected.\n"
              sys_syscall(1, client_fd, msg, string_len(msg), 0, 0, 0)
              
              @! Broadcast
              broadcast(client_fds, max_clients, client_fd, "A new player has joined the realm!\n")
              string_println("Player joined!")
              break
            @end
            j = j + 1
          @end
          
          @if added == 0
            msg = "Server Full!\n"
            sys_syscall(1, client_fd, msg, string_len(msg), 0, 0, 0)
            sys_syscall(3, client_fd, 0, 0, 0, 0, 0)
          @end
        @end
      @else
        @! Player sent data (movement or chat)
        read_buf = sys_mmap(0, 256, 3, 34, 0 - 1, 0)
        bytes = sys_syscall(0, event_fd, read_buf, 256, 0, 0, 0)
        
        @if bytes > 0
          sys_poke8(read_buf + bytes, 0)
          
          @! Broadcast their action
          prefix = "Action: "
          full_msg = string_concat(prefix, read_buf)
          broadcast(client_fds, max_clients, event_fd, full_msg)
          string_println("Player Action broadcasted.")
        @else
          @! Player disconnected
          sys_syscall(3, event_fd, 0, 0, 0, 0, 0)
          
          @! Remove from array
          j = 0
          @while j < max_clients
            @if sys_peek(client_fds + (j * 8)) == event_fd
              sys_poke(client_fds + (j * 8), 0)
              break
            @end
            j = j + 1
          @end
          
          broadcast(client_fds, max_clients, 0, "A player has left the realm.\n")
          string_println("Player disconnected.")
        @end
      @end
      
      i = i + 1
    @end
    processed = processed + 1
  @end
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
