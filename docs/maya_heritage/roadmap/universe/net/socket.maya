@! ============================================================================
@! MAYA NATIVE NETWORK SOCKET ABSTRACTION
@! 100% Pure Maya — Direct POSIX Socket Integration
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/memory"

@! Constants for IPv4 / TCP
@fn AF_INET() return 2 @end
@fn SOCK_STREAM() return 1 @end
@fn IPPROTO_TCP() return 6 @end

@! Creates a new TCP socket, returns fd
@fn socket_new_tcp()
  fd = sys_socket(AF_INET(), SOCK_STREAM(), IPPROTO_TCP())
  return fd
@end

@fn htons(val)
  return (((val & 255) << 8) | ((val >> 8) & 255)) & 0xFFFF
@end

@! Binds socket to a port (IPv4)
@fn socket_bind(fd, port)
  sockaddr_ptr = sys_mmap(0, 16, 3, 34, -1, 0)
  @if sockaddr_ptr > 0
    memory_write16(sockaddr_ptr, AF_INET())
    memory_write16(sockaddr_ptr + 2, htons(port))
    memory_write32(sockaddr_ptr + 4, 0) @! INADDR_ANY
  @end
  
  res = sys_bind(fd, sockaddr_ptr, 16)
  memory_free(0, sockaddr_ptr)
  return res
@end

@! Listens for incoming connections
@fn socket_listen(fd, backlog)
  return sys_listen(fd, backlog)
@end

@! Accepts an incoming connection
@fn socket_accept(server_fd)
  sockaddr_ptr = sys_mmap(0, 16, 3, 34, -1, 0)
  addrlen_ptr = sys_mmap(0, 4, 3, 34, -1, 0)
  @! memory_write32(addrlen_ptr, 16)
  
  client_fd = sys_accept(server_fd, sockaddr_ptr, addrlen_ptr)
  
  memory_free(0, sockaddr_ptr)
  memory_free(0, addrlen_ptr)
  return client_fd
@end

@! Closes a socket
@fn socket_close(fd)
  return sys_close(fd)
@end

@! ----------------------------------------------------------------------------
@! Linux Epoll Non-Blocking Event Multiplexing
@! ----------------------------------------------------------------------------

@fn epoll_new()
  return sys_epoll_create1(0)
@end

@fn epoll_add_fd(epfd, fd, events)
  @! EPOLL_CTL_ADD = 1
  @! event struct is 12 bytes: uint32 events, uint64 data (fd)
  event_buf = sys_mmap(0, 16, 3, 34, -1, 0)
  @if event_buf < 0 return -1 @end
  res = sys_epoll_ctl(epfd, 1, fd, event_buf)
  return res
@end

@fn epoll_poll(epfd, max_events, timeout_ms)
  events_buf = sys_mmap(0, max_events * 16, 3, 34, -1, 0)
  @if events_buf < 0 return 0 @end
  ready_count = sys_epoll_wait(epfd, events_buf, max_events, timeout_ms)
  return ready_count
@end
