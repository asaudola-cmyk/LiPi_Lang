@! ============================================================================
@! LIPI UNIVERSE NET - PURE MAYA TCP SOCKET STACK (universe/net/tcp.maya)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Complete Linux x86-64 BSD Sockets Implementation
@! ============================================================================

import "universe/os/syscalls"

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
    t1 = 0 * 256
    t2 = 0 * 65536
    t3 = 1 * 16777216
    r1 = 127 | t1
    r2 = t2 | t3
    return r1 | r2
  @end
  @if host == "" || host == "0.0.0.0"
    return 0
  @end

  a = 0
  b = 0
  c = 0
  d = 0
  part = 0
  curr = 0
  i = 0
  hlen = host.len()

  @while i < hlen
    ch = str_char_at(host, i)
    @if ch >= 48 && ch <= 57
      curr = (curr * 10) + (ch - 48)
    @elif ch == 46
      @if part == 0 a = curr @end
      @if part == 1 b = curr @end
      @if part == 2 c = curr @end
      part = part + 1
      curr = 0
    @end
    i = i + 1
  @end
  @if part == 3 d = curr @end

  w0 = a & 255
  b_byte = b & 255
  w1 = b_byte * 256
  c_byte = c & 255
  w2 = c_byte * 65536
  d_byte = d & 255
  w3 = d_byte * 16777216
  res01 = w0 | w1
  res23 = w2 | w3
  return res01 | res23
@end

@fn sockaddr_in_pack(host, port)
  sin_family = 2
  sin_port = htons(port)
  sin_addr = parse_ipv4_addr(host)

  w_fam = sin_family & 65535
  p_val = sin_port & 65535
  w_port = p_val * 65536
  w_addr = sin_addr * 4294967296
  t1 = w_fam | w_port
  w0 = t1 | w_addr
  w1 = 0

  return { w0: w0, w1: w1 }
@end

@fn tcp_socket_new()
  fd = sys_socket(2, 1, 6)
  return fd
@end

@fn tcp_bind(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  @! Enable SO_REUSEADDR
  optval = { val: 1 }
  sys_setsockopt(sockfd, 1, 2, optval, 4)

  addr = sockaddr_in_pack(host, port)
  res = sys_bind(sockfd, addr, 16)
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
  addr = sockaddr_in_pack(host, port)
  res = sys_connect(sockfd, addr, 16)
  return res
@end

@fn tcp_send(sockfd, data)
  @if sockfd < 0 return -1 @end
  dlen = data.len()
  @if dlen == 0 return 0 @end

  total_sent = 0
  @while total_sent < dlen
    written = sys_write(sockfd, data, dlen - total_sent)
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
  buf = maya_alloc(max_len + 1)
  n = sys_read(sockfd, buf, max_len)
  @if n <= 0
    return ""
  @end
  return maya_str_new(buf)
@end

@fn tcp_close(sockfd)
  @if sockfd < 0 return -1 @end
  res = sys_close(sockfd)
  return res
@end

@! ----------------------------------------------------------------------------
@! 4. Object-Oriented Abstractions: TcpListener & TcpStream
@! ----------------------------------------------------------------------------

@fn tcp_listener_bind(host, port)
  fd = tcp_socket_new()
  @if fd < 0
    return { fd: fd, host: host, port: port, error: "socket_failed" }
  @end

  bind_res = tcp_bind(fd, host, port)
  @if bind_res < 0
    tcp_close(fd)
    return { fd: -1, host: host, port: port, error: "bind_failed" }
  @end

  listen_res = tcp_listen(fd, 128)
  @if listen_res < 0
    tcp_close(fd)
    return { fd: -1, host: host, port: port, error: "listen_failed" }
  @end

  return { fd: fd, host: host, port: port, error: "" }
@end

@fn tcp_listener_accept(listener)
  @if listener.fd < 0
    return { fd: -1, peer_host: "", peer_port: 0, error: "invalid_listener" }
  @end

  client_fd = tcp_accept(listener.fd)
  @if client_fd < 0
    return { fd: client_fd, peer_host: "", peer_port: 0, error: "accept_failed" }
  @end

  return { fd: client_fd, peer_host: "", peer_port: 0, error: "" }
@end

@fn tcp_stream_connect(host, port)
  fd = tcp_socket_new()
  @if fd < 0
    return { fd: fd, peer_host: host, peer_port: port, error: "socket_failed" }
  @end

  conn_res = tcp_connect(fd, host, port)
  @if conn_res < 0
    tcp_close(fd)
    return { fd: -1, peer_host: host, peer_port: port, error: "connect_failed" }
  @end

  return { fd: fd, peer_host: host, peer_port: port, error: "" }
@end

@fn tcp_stream_read(stream, max_len)
  @if stream.fd < 0 return "" @end
  return tcp_recv(stream.fd, max_len)
@end

@fn tcp_stream_write(stream, data)
  @if stream.fd < 0 return -1 @end
  return tcp_send(stream.fd, data)
@end

@fn tcp_stream_close(stream)
  @if stream.fd >= 0
    res = tcp_close(stream.fd)
    stream.fd = -1
    return res
  @end
  return 0
@end
