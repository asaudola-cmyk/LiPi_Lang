@! ==================================================================
@! MAYA UNIVERSE - Core Networking Library (Phase 9/10)
@! ==================================================================
@! Provides native TCP/UDP socket networking via raw Linux syscalls
@! Syscall documentation:
@! socket = 41
@! connect = 42
@! accept = 43
@! bind = 49
@! listen = 50
@! ==================================================================

@struct sockaddr_in
  sin_family
  sin_port
  sin_addr
  sin_zero1
  sin_zero2
@end

@fn net_socket(domain, type, protocol)
  return sys_syscall(41, domain, type, protocol, 0, 0)
@end

@fn net_bind(sockfd, addr_ptr, addrlen)
  return sys_syscall(49, sockfd, addr_ptr, addrlen, 0, 0)
@end

@fn net_listen(sockfd, backlog)
  return sys_syscall(50, sockfd, backlog, 0, 0, 0)
@end

@fn net_accept(sockfd, addr_ptr, addrlen_ptr)
  return sys_syscall(43, sockfd, addr_ptr, addrlen_ptr, 0, 0)
@end

@fn net_connect(sockfd, addr_ptr, addrlen)
  return sys_syscall(42, sockfd, addr_ptr, addrlen, 0, 0)
@end

@fn net_read(fd, buf, count)
  return sys_syscall(0, fd, buf, count, 0, 0)
@end

@fn net_write(fd, buf, count)
  return sys_syscall(1, fd, buf, count, 0, 0)
@end

@fn net_close(fd)
  return sys_syscall(3, fd, 0, 0, 0, 0)
@end

@fn htons(port)
  b1 = port / 256
  b2 = port - (b1 * 256)
  return (b2 * 256) + b1
@end

@fn net_tcp_listen(port)
  sockfd = net_socket(2, 1, 0)
  @if sockfd < 0 return sockfd @end
  
  @! Use our native struct for sockaddr_in!
  @! Note: fields are 64-bit aligned (8 bytes) so the struct is 40 bytes!
  @! Wait... Linux expects exactly 16 bytes for sockaddr_in!
  @! We cannot use native Maya struct for syscall arguments yet because
  @! Maya structs are currently arrays of 64-bit pointers/ints (8 bytes each)!
  
  addr = sys_mmap(0, 16, 3, 34, -1, 0)
  sys_poke8(addr + 0, 2)
  sys_poke8(addr + 1, 0)
  
  h_port = htons(port)
  p1 = h_port / 256
  p2 = h_port - (p1 * 256)
  sys_poke8(addr + 2, p2)
  sys_poke8(addr + 3, p1)
  
  sys_poke8(addr + 4, 0)
  sys_poke8(addr + 5, 0)
  sys_poke8(addr + 6, 0)
  sys_poke8(addr + 7, 0)
  
  optval = sys_mmap(0, 4, 3, 34, -1, 0)
  sys_poke8(optval + 0, 1)
  sys_poke8(optval + 1, 0)
  sys_poke8(optval + 2, 0)
  sys_poke8(optval + 3, 0)
  println("Optval pointer:")
  print_int(optval)
  sys_syscall(54, sockfd, 1, 2, optval, 4)
  
  res = net_bind(sockfd, addr, 16)
  @if res < 0 return res @end
  
  res = net_listen(sockfd, 10)
  @if res < 0 return res @end
  
  return sockfd
@end
