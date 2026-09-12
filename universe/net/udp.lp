@! ============================================================================
@! LIPI UNIVERSE NET - PURE LIPI UDP SOCKET STACK (universe/net/udp.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Complete Linux x86-64 BSD Sockets Datagram & Broadcast Implementation
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Socket Constants & Bitwise Endian Helpers
@! ----------------------------------------------------------------------------

@fn AF_INET() return 2 @end
@fn SOCK_DGRAM() return 2 @end
@fn IPPROTO_UDP() return 17 @end
@fn SOL_SOCKET() return 1 @end
@fn SO_REUSEADDR() return 2 @end
@fn SO_REUSEPORT() return 15 @end
@fn SO_BROADCAST() return 6 @end
@fn MSG_DONTWAIT() return 64 @end

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

@fn udp_unpack_sender(w0)
  sin_port_raw = (w0 / 65536) & 65535
  port = ntohs(sin_port_raw)

  sin_addr_raw = (w0 / 4294967296) & 4294967295
  b0 = sin_addr_raw & 255
  b1 = (sin_addr_raw / 256) & 255
  b2 = (sin_addr_raw / 65536) & 255
  b3 = (sin_addr_raw / 16777216) & 255
  host = b0.to_str() + "." + b1.to_str() + "." + b2.to_str() + "." + b3.to_str()

  return { host: host, port: port }
@end

@! ----------------------------------------------------------------------------
@! 3. Core Low-Level UDP Socket Functions
@! ----------------------------------------------------------------------------

@struct UdpRecvResult
  data: string
  sender_host: string
  sender_port: i64
  bytes_read: i64
@end

@fn udp_socket_new()
  @! AF_INET=2, SOCK_DGRAM=2, IPPROTO_UDP=17
  fd = sys_socket(2, 2, 17)
  return fd
@end

@fn udp_set_broadcast(sockfd, enable)
  @if sockfd < 0 return -1 @end
  optval = { val: enable }
  @! SOL_SOCKET=1, SO_BROADCAST=6
  res = sys_setsockopt(sockfd, 1, 6, optval, 4)
  return res
@end

@fn udp_set_reuse(sockfd)
  @if sockfd < 0 return -1 @end
  optval = { val: 1 }
  @! SOL_SOCKET=1, SO_REUSEADDR=2, SO_REUSEPORT=15
  r1 = sys_setsockopt(sockfd, 1, 2, optval, 4)
  r2 = sys_setsockopt(sockfd, 1, 15, optval, 4)
  @if r1 < 0 return r1 @end
  @if r2 < 0 return r2 @end
  return 0
@end

@fn udp_set_nonblocking(sockfd)
  @if sockfd < 0 return -1 @end
  flags = sys_fcntl(sockfd, 3, 0)
  @if flags < 0 return flags @end
  return sys_fcntl(sockfd, 4, flags | 2048)
@end

@fn udp_bind(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  udp_set_reuse(sockfd)
  addr = sockaddr_in_pack(host, port)
  res = sys_bind(sockfd, addr, 16)
  return res
@end

@fn udp_send_to(sockfd, host, port, data)
  @if sockfd < 0 return -1 @end
  dlen = data.len()
  @if dlen == 0 return 0 @end
  addr = sockaddr_in_pack(host, port)
  res = sys_sendto(sockfd, data, dlen, 0, addr, 16)
  return res
@end

@fn udp_recv_from(sockfd, max_len)
  @if sockfd < 0 || max_len <= 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: -1 }
  @end
  buf = maya_alloc(max_len + 1)
  src_addr = { w0: 0, w1: 0 }
  src_len = { val: 16 }
  n = sys_recvfrom(sockfd, buf, max_len, 0, src_addr, src_len)
  @if n <= 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: n }
  @end
  data_str = maya_str_new(buf)
  sender = udp_unpack_sender(src_addr.w0)
  return {
    data: data_str,
    sender_host: sender.host,
    sender_port: sender.port,
    bytes_read: n
  }
@end

@fn udp_recv_from_nonblocking(sockfd, max_len)
  @if sockfd < 0 || max_len <= 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: -1 }
  @end
  buf = maya_alloc(max_len + 1)
  src_addr = { w0: 0, w1: 0 }
  src_len = { val: 16 }
  @! MSG_DONTWAIT = 64
  n = sys_recvfrom(sockfd, buf, max_len, 64, src_addr, src_len)
  @if n <= 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: n }
  @end
  data_str = maya_str_new(buf)
  sender = udp_unpack_sender(src_addr.w0)
  return {
    data: data_str,
    sender_host: sender.host,
    sender_port: sender.port,
    bytes_read: n
  }
@end

@fn udp_close(sockfd)
  @if sockfd < 0 return -1 @end
  return sys_close(sockfd)
@end

@! ----------------------------------------------------------------------------
@! 4. Object-Oriented Abstraction: UdpSocket
@! ----------------------------------------------------------------------------

@struct UdpSocket
  fd: i64
  bound_port: i64
  is_broadcast: i64
@end

@fn udp_socket_bind(host, port, is_broadcast)
  fd = udp_socket_new()
  @if fd < 0
    return { fd: -1, bound_port: port, is_broadcast: is_broadcast }
  @end

  udp_set_reuse(fd)
  @if is_broadcast != 0
    udp_set_broadcast(fd, 1)
  @end

  bind_res = udp_bind(fd, host, port)
  @if bind_res < 0
    udp_close(fd)
    return { fd: -1, bound_port: port, is_broadcast: is_broadcast }
  @end

  return { fd: fd, bound_port: port, is_broadcast: is_broadcast }
@end

@fn udp_socket_send(sock, host, port, data)
  @if sock.fd < 0 return -1 @end
  return udp_send_to(sock.fd, host, port, data)
@end

@fn udp_socket_recv(sock, max_len)
  @if sock.fd < 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: -1 }
  @end
  return udp_recv_from(sock.fd, max_len)
@end

@fn udp_socket_recv_nonblocking(sock, max_len)
  @if sock.fd < 0
    return { data: "", sender_host: "", sender_port: 0, bytes_read: -1 }
  @end
  return udp_recv_from_nonblocking(sock.fd, max_len)
@end

@fn udp_socket_close(sock)
  @if sock.fd >= 0
    res = udp_close(sock.fd)
    sock.fd = -1
    return res
  @end
  return 0
@end
