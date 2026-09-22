import "universe/os/syscalls"
@! ==================================================================
@! LIPI UNIVERSE - Core Networking Library (Phase 9/10)
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

@fn net_tcp_socket()
  // WHY: Allocates IPv4 (AF_INET=2) streaming (SOCK_STREAM=1) socket directly via Linux syscall 41.
  return net_socket(2, 1, 0)
@end

@fn net_tcp_set_reuseaddr(sockfd)
  // WHY: Sets SO_REUSEADDR (level 1, opt 2) via Linux sys_setsockopt (syscall 54) to eliminate TIME_WAIT bind failures.
  opt_buf = sys_mmap(0, 8, 3, 34, -1, 0)
  sys_poke8(opt_buf + 0, 1)
  sys_poke8(opt_buf + 1, 0)
  sys_poke8(opt_buf + 2, 0)
  sys_poke8(opt_buf + 3, 0)
  res = sys_syscall(54, sockfd, 1, 2, opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_tcp_bind(sockfd, port)
  // WHY: Binds socket to sockaddr_in using raw Linux syscall 49.
  addr = sys_mmap(0, 16, 3, 34, -1, 0)
  sys_poke8(addr + 0, 2)
  sys_poke8(addr + 1, 0)
  h_port = htons(port)
  p1 = h_port / 256
  p2 = h_port - (p1 * 256)
  sys_poke8(addr + 2, p2)
  sys_poke8(addr + 3, p1)
  k = 4
  @while k < 16
    sys_poke8(addr + k, 0)
    k = k + 1
  @end
  res = net_bind(sockfd, addr, 16)
  sys_munmap(addr, 16)
  return res
@end

@fn net_tcp_listen(sockfd, backlog)
  // WHY: Places socket in passive listening state with specified queue backlog.
  return net_listen(sockfd, backlog)
@end

@fn net_tcp_close(sockfd)
  // WHY: Frees kernel socket descriptor via sys_close.
  return net_close(sockfd)
@end

@fn net_tcp_accept(sockfd)
  // WHY: Accepts inbound client connection via sys_accept.
  return net_accept(sockfd, 0, 0)
@end

@fn net_tcp_send(sockfd, data)
  // WHY: Sends data payload over socket connection.
  return net_write(sockfd, data, str_len(data))
@end

@fn net_tcp_recv(sockfd, max_len)
  // WHY: Reads raw incoming bytes into buffer via sys_read and converts into a canonical STR0 Lipi string.
  buf = sys_mmap(0, max_len + 1, 3, 34, -1, 0)
  bytes_read = net_read(sockfd, buf, max_len)
  @if bytes_read <= 0
    sys_munmap(buf, max_len + 1)
    return ""
  @end
  res = ""
  i = 0
  @while i < bytes_read
    b = sys_peek8(buf + i) & 255
    res = res + chr(b)
    i = i + 1
  @end
  sys_munmap(buf, max_len + 1)
  return res
@end
