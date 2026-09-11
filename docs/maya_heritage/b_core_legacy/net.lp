@! ============================================================================
@! UNIVERSE B CORE: NETWORKING (TCP Sockets)
@! ============================================================================

@fn net_socket()
  @! domain = AF_INET (2), type = SOCK_STREAM (1), protocol = 0
  return sys_syscall(41, 2, 1, 0, 0, 0, 0)
@end

@fn net_htons(port)
  @! Host to Network Short (Endian swap for 16-bit)
  low = port & 255
  high = (port >> 8) & 255
  return (low << 8) | high
@end

@fn net_bind(sockfd, port)
  @! Allocate 16 bytes for sockaddr_in
  addr_ptr = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  
  @! sin_family = AF_INET (2)
  sys_poke8(addr_ptr + 0, 2)
  sys_poke8(addr_ptr + 1, 0)
  
  @! sin_port = htons(port)
  nport = net_htons(port)
  sys_poke8(addr_ptr + 2, nport & 255)
  sys_poke8(addr_ptr + 3, (nport >> 8) & 255)
  
  @! sin_addr = INADDR_ANY (0)
  sys_poke8(addr_ptr + 4, 0)
  sys_poke8(addr_ptr + 5, 0)
  sys_poke8(addr_ptr + 6, 0)
  sys_poke8(addr_ptr + 7, 0)
  
  @! Zero padding
  sys_poke(addr_ptr + 8, 0)
  
  return sys_syscall(49, sockfd, addr_ptr, 16, 0, 0, 0)
@end

@fn net_listen(sockfd, backlog)
  return sys_syscall(50, sockfd, backlog, 0, 0, 0, 0)
@end

@fn net_accept(sockfd)
  @! We can pass 0 for addr_ptr and addrlen if we don't care about client IP
  return sys_syscall(43, sockfd, 0, 0, 0, 0, 0)
@end

@fn net_read(sockfd, buf, count)
  return sys_syscall(0, sockfd, buf, count, 0, 0, 0)
@end

@fn net_write(sockfd, buf, count)
  return sys_syscall(1, sockfd, buf, count, 0, 0, 0)
@end

@fn net_close(sockfd)
  return sys_syscall(3, sockfd, 0, 0, 0, 0, 0)
@end
