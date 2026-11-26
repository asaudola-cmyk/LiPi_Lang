@! ============================================================================
@! LIPI UNIVERSE NET - PURE LIPI TCP SOCKET STACK (utso/net/tcp.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Complete Linux x86-64 BSD Sockets Implementation
@! ============================================================================

import "utso/os/syscalls"
import "utso/net/dns_client"

@! ----------------------------------------------------------------------------
@! 1. Socket Constants & Bitwise Endian Helpers
@! ----------------------------------------------------------------------------

@fn AF_INET() return 2 @end
@fn SOCK_STREAM() return 1 @end
@fn IPPROTO_TCP() return 6 @end
@fn SOL_SOCKET() return 1 @end
@fn SO_REUSEADDR() return 2 @end

@fn htons(val)
  v_byte = val & 255
  b0 = v_byte * 256
  v_div = val / 256
  b1 = v_div & 255
  res = b0 | b1
  return res & 65535
@end

@fn ntohs(val)
  return htons(val)
@end

@fn parse_ipv4_addr(host)
  @if host == "localhost"
    return (127 | (1 * 16777216)) & 4294967295
  @end
  @if host == "0.0.0.0"
    return 0
  @end
  @if host == ""
    return -1
  @end

  a = 0
  b = 0
  c = 0
  d = 0
  part = 0
  curr = 0
  has_digit = 0
  i = 0
  hlen = host.len()

  @while i < hlen
    ch = str_char_at(host, i)
    @if ch >= 48 && ch <= 57
      curr = (curr * 10) + (ch - 48)
      has_digit = 1
      @if curr > 255 return -1 @end
    @elif ch == 46
      @if has_digit == 0 || part >= 3 return -1 @end
      @if part == 0 a = curr @end
      @if part == 1 b = curr @end
      @if part == 2 c = curr @end
      part = part + 1
      curr = 0
      has_digit = 0
    @else
      return -1
    @end
    i = i + 1
  @end
  @if has_digit == 0 || part != 3 return -1 @end
  d = curr

  res = (a & 255) | ((b & 255) * 256) | ((c & 255) * 65536) | ((d & 255) * 16777216)
  return res & 4294967295
@end

@fn _tcp_pack_sockaddr_buf(host, port, allow_any_empty)
  ip_host = host
  @if ip_host == "" && allow_any_empty == 1
    ip_host = "0.0.0.0"
  @end
  sin_addr = parse_ipv4_addr(ip_host)
  @if sin_addr < 0 return 0 @end
  buf = lipi_alloc(16)
  @if buf <= 0 return 0 @end
  k = 0
  @while k < 16
    sys_poke8(buf + k, 0)
    k = k + 1
  @end
  sys_poke8(buf + 0, 2) // AF_INET = 2 LE
  sys_poke8(buf + 1, 0)
  sys_poke8(buf + 2, (port >> 8) & 255)
  sys_poke8(buf + 3, port & 255)
  sys_poke8(buf + 4, sin_addr & 255)
  sys_poke8(buf + 5, (sin_addr >> 8) & 255)
  sys_poke8(buf + 6, (sin_addr >> 16) & 255)
  sys_poke8(buf + 7, (sin_addr >> 24) & 255)
  return buf
@end

@fn sockaddr_in_pack(host, port)
  sin_family = 2
  sin_port = htons(port)
  sin_addr = parse_ipv4_addr(host)
  @if sin_addr < 0 sin_addr = 0 @end

  w_fam = sin_family & 65535
  p_val = sin_port & 65535
  w_port = p_val * 65536
  w_addr = (sin_addr & 4294967295) * 4294967296
  t1 = w_fam | w_port
  w0 = t1 | w_addr
  w1 = 0

  return { w0: w0, w1: w1 }
@end

@fn tcp_set_timeout(sockfd, seconds)
  @if sockfd < 0 return -1 @end
  tv = lipi_alloc(16)
  @if tv <= 0 return -1 @end
  mem_write(tv, 0, seconds)
  mem_write(tv, 8, 0)
  sys_setsockopt(sockfd, 1, 20, tv, 16) // SO_RCVTIMEO
  sys_setsockopt(sockfd, 1, 21, tv, 16) // SO_SNDTIMEO
  lipi_free(tv)
  return 0
@end

@fn tcp_set_timeout_ms(sockfd, timeout_ms)
  @if sockfd < 0 return -1 @end
  ms = timeout_ms
  @if ms < 0 ms = 0 @end
  tv = lipi_alloc(16)
  @if tv <= 0 return -1 @end
  mem_write(tv, 0, ms / 1000)
  mem_write(tv, 8, (ms % 1000) * 1000)
  sys_setsockopt(sockfd, 1, 20, tv, 16) // SO_RCVTIMEO
  sys_setsockopt(sockfd, 1, 21, tv, 16) // SO_SNDTIMEO
  lipi_free(tv)
  return 0
@end

@fn tcp_socket_new()
  fd = sys_socket(2, 1, 6)
  return fd
@end

@fn tcp_bind(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  @! Enable SO_REUSEADDR (2) & SO_REUSEPORT (15)
  opt_buf = lipi_alloc(8)
  sys_poke32(opt_buf, 1)
  sys_setsockopt(sockfd, 1, 2, opt_buf, 4)
  sys_setsockopt(sockfd, 1, 15, opt_buf, 4)
  lipi_free(opt_buf)

  addr_buf = _tcp_pack_sockaddr_buf(host, port, 1)
  @if addr_buf <= 0 return -1 @end
  res = sys_bind(sockfd, addr_buf, 16)
  lipi_free(addr_buf)
  return res
@end

@fn tcp_listen(sockfd, backlog)
  @if sockfd < 0 return -1 @end
  @if backlog <= 0 backlog = 128 @end
  res = sys_listen(sockfd, backlog)
  return res
@end

@fn tcp_accept(sockfd)
  @if sockfd < 0 return -1 @end
  client_fd = sys_accept(sockfd, 0, 0)
  return client_fd
@end

@fn tcp_connect(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  ip_str = host
  @if parse_ipv4_addr(ip_str) < 0
    ip_str = dns_resolve_ipv4(host)
    @if ip_str == "" return -1 @end
  @end
  addr_buf = _tcp_pack_sockaddr_buf(ip_str, port, 0)
  @if addr_buf <= 0 return -1 @end
  res = sys_connect(sockfd, addr_buf, 16)
  lipi_free(addr_buf)
  return res
@end

@fn _tcp_raw_ptr(x) return x @end

@fn tcp_send(sockfd, data)
  @if sockfd < 0 return -1 @end
  dlen = data.len()
  @if dlen == 0 return 0 @end
  d_ptr = _tcp_raw_ptr(data)

  total_sent = 0
  @while total_sent < dlen
    written = syscall(44, sockfd, d_ptr + total_sent, dlen - total_sent, 16384, 0, 0)
    @if written == (0 - 4)
      continue
    @end
    @if written == (0 - 88)
      written = sys_write(sockfd, d_ptr + total_sent, dlen - total_sent)
    @end
    @if written <= 0
      @if total_sent > 0 return total_sent @end
      return written
    @end
    total_sent = total_sent + written
  @end
  return total_sent
@end

@fn tcp_recv(sockfd, max_len)
  @if sockfd < 0 || max_len <= 0 return "" @end
  buf = lipi_alloc(max_len + 1)
  @if buf <= 0 return "" @end
  n = sys_read(sockfd, buf, max_len)
  @while n == (0 - 4)
    n = sys_read(sockfd, buf, max_len)
  @end
  @if n <= 0
    lipi_free_sized(buf, max_len + 1)
    return ""
  @end
  out = bytes_to_str(buf, n)
  lipi_free_sized(buf, max_len + 1)
  return out
@end

@fn tcp_close(sockfd)
  @if sockfd < 0 return -1 @end
  res = sys_close(sockfd)
  return res
@end

@! ----------------------------------------------------------------------------
@! 4. Object-Oriented Abstractions: TcpListener & TcpStream
@! ----------------------------------------------------------------------------

@struct TcpListener
  tcpl_fd: i64
  tcpl_host: string
  tcpl_port: i64
  tcpl_error: string
@end

@struct TcpStream
  tcp_fd: i64
  tcp_peer_host: string
  tcp_peer_port: i64
  tcp_error: string
@end

@fn tcp_listener_bind(host, port) -> TcpListener
  fd = tcp_socket_new()
  @if fd < 0
    return TcpListener(fd, host, port, "socket_failed")
  @end

  bind_res = tcp_bind(fd, host, port)
  @if bind_res < 0
    tcp_close(fd)
    return TcpListener(-1, host, port, "bind_failed")
  @end

  listen_res = tcp_listen(fd, 128)
  @if listen_res < 0
    tcp_close(fd)
    return TcpListener(-1, host, port, "listen_failed")
  @end

  return TcpListener(fd, host, port, "")
@end

@fn tcp_listener_accept(listener: TcpListener) -> TcpStream
  @if listener.tcpl_fd < 0
    return TcpStream(-1, "", 0, "invalid_listener")
  @end

  client_fd = tcp_accept(listener.tcpl_fd)
  @if client_fd < 0
    return TcpStream(client_fd, "", 0, "accept_failed")
  @end

  return TcpStream(client_fd, "", 0, "")
@end

@fn tcp_listener_close(listener: TcpListener)
  @if listener.tcpl_fd >= 0
    res = tcp_close(listener.tcpl_fd)
    listener.tcpl_fd = -1
    return res
  @end
  return 0
@end

@fn tcp_stream_connect(host, port) -> TcpStream
  @if host == "" || port <= 0
    return TcpStream(-1, host, port, "invalid_endpoint")
  @end
  resolved_ip = host
  @if parse_ipv4_addr(resolved_ip) < 0
    resolved_ip = dns_resolve_ipv4(host)
    @if resolved_ip == ""
      return TcpStream(-1, host, port, "dns_failed")
    @end
  @end
  fd = tcp_socket_new()
  @if fd < 0
    return TcpStream(fd, host, port, "socket_failed")
  @end
  tcp_set_timeout(fd, 5)

  conn_res = tcp_connect(fd, resolved_ip, port)
  @if conn_res < 0
    tcp_close(fd)
    return TcpStream(-1, host, port, "connect_failed")
  @end

  return TcpStream(fd, host, port, "")
@end

@fn tcp_stream_read(stream: TcpStream, max_len)
  @if stream.tcp_fd < 0 return "" @end
  return tcp_recv(stream.tcp_fd, max_len)
@end

@fn tcp_stream_write(stream: TcpStream, data)
  @if stream.tcp_fd < 0 return -1 @end
  return tcp_send(stream.tcp_fd, data)
@end

@fn tcp_stream_close(stream: TcpStream)
  @if stream.tcp_fd >= 0
    res = tcp_close(stream.tcp_fd)
    stream.tcp_fd = -1
    return res
  @end
  return 0
@end
