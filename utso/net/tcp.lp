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
@fn AF_INET6() return 10 @end
@fn SOCK_STREAM() return 1 @end
@fn IPPROTO_TCP() return 6 @end
@fn SOL_SOCKET() return 1 @end
@fn SO_REUSEADDR() return 2 @end

@fn tcp_is_ipv6_host(host)
  hlen = host.len()
  i = 0
  @while i < hlen
    @if str_char_at(host, i) == 58
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn _tcp_hex_nibble(ch)
  @if ch >= 48 && ch <= 57 return ch - 48 @end
  @if ch >= 97 && ch <= 102 return ch - 87 @end
  @if ch >= 65 && ch <= 70 return ch - 55 @end
  return -1
@end

@fn parse_ipv6_bytes(host)
  // WHY: RFC 4291 / RFC 5952 IPv6 literal parser returning 16 network-order bytes.
  // Supports optional `[...]` brackets, `%zone` suffix, `::` zero compression, and
  // IPv4-mapped tails like `::ffff:127.0.0.1`.
  s = host
  slen = s.len()
  @if slen >= 2 && str_char_at(s, 0) == 91 && str_char_at(s, slen - 1) == 93
    s = str_sub(s, 1, slen - 1)
    slen = s.len()
  @end
  // Strip optional zone id (`fe80::1%eth0`)
  zi = 0
  @while zi < slen
    @if str_char_at(s, zi) == 37
      s = str_sub(s, 0, zi)
      slen = s.len()
      break
    @end
    zi = zi + 1
  @end
  @if slen < 2 return [] @end

  // Locate optional `::` compression marker (at most one allowed)
  dc_pos = -1
  i = 0
  @while i + 1 < slen
    @if str_char_at(s, i) == 58 && str_char_at(s, i + 1) == 58
      @if dc_pos >= 0 return [] @end
      dc_pos = i
      i = i + 2
      continue
    @end
    i = i + 1
  @end

  left_groups = []
  right_groups = []
  sides = []
  @if dc_pos >= 0
    sides = [str_sub(s, 0, dc_pos), str_sub(s, dc_pos + 2, slen)]
  @else
    sides = [s, ""]
  @end

  si = 0
  @while si < 2
    part = sides[si]
    plen = part.len()
    @if plen > 0
      // Leading or trailing single ':' inside a half is invalid
      @if str_char_at(part, 0) == 58 || str_char_at(part, plen - 1) == 58
        return []
      @end
      pos = 0
      @while pos < plen
        next_c = pos
        @while next_c < plen && str_char_at(part, next_c) != 58
          next_c = next_c + 1
        @end
        tok = str_sub(part, pos, next_c)
        tlen = tok.len()
        @if tlen == 0 return [] @end
        // Check for embedded IPv4 dotted quad at the very end of the address
        has_dot = 0
        di = 0
        @while di < tlen
          @if str_char_at(tok, di) == 46
            has_dot = 1
            break
          @end
          di = di + 1
        @end
        @if has_dot == 1
          @if next_c != plen return [] @end
          @if dc_pos >= 0 && si == 0 return [] @end
          v4 = parse_ipv4_addr(tok)
          @if v4 < 0 return [] @end
          b0 = v4 & 255
          b1 = (v4 >> 8) & 255
          b2 = (v4 >> 16) & 255
          b3 = (v4 >> 24) & 255
          g_hi = (b0 << 8) | b1
          g_lo = (b2 << 8) | b3
          @if si == 0
            left_groups = left_groups.push(g_hi)
            left_groups = left_groups.push(g_lo)
          @else
            right_groups = right_groups.push(g_hi)
            right_groups = right_groups.push(g_lo)
          @end
        @else
          @if tlen > 4 return [] @end
          val = 0
          hi = 0
          @while hi < tlen
            nib = _tcp_hex_nibble(str_char_at(tok, hi))
            @if nib < 0 return [] @end
            val = (val << 4) | nib
            hi = hi + 1
          @end
          @if si == 0
            left_groups = left_groups.push(val)
          @else
            right_groups = right_groups.push(val)
          @end
        @end
        @if next_c < plen
          pos = next_c + 1
        @else
          pos = plen
        @end
      @end
    @end
    si = si + 1
  @end

  lcnt = left_groups.len()
  rcnt = right_groups.len()
  @if dc_pos < 0
    @if lcnt != 8 return [] @end
  @else
    @if lcnt + rcnt >= 8 return [] @end
  @end

  groups = []
  gi = 0
  @while gi < lcnt
    groups = groups.push(left_groups[gi])
    gi = gi + 1
  @end
  @if dc_pos >= 0
    zeros = 8 - (lcnt + rcnt)
    zi2 = 0
    @while zi2 < zeros
      groups = groups.push(0)
      zi2 = zi2 + 1
    @end
    ri = 0
    @while ri < rcnt
      groups = groups.push(right_groups[ri])
      ri = ri + 1
    @end
  @end
  @if groups.len() != 8 return [] @end

  out = []
  oi = 0
  @while oi < 8
    gv = groups[oi]
    out = out.push((gv >> 8) & 255)
    out = out.push(gv & 255)
    oi = oi + 1
  @end
  return out
@end

@fn _tcp_pack_sockaddr6_buf(host, port, allow_any_empty)
  // WHY: Linux x86_64 `struct sockaddr_in6` is exactly 28 bytes:
  // family(2 LE) + port(2 BE) + flowinfo(4) + addr(16 BE) + scope_id(4).
  ip_host = host
  @if ip_host == "" && allow_any_empty == 1
    ip_host = "::"
  @end
  ip_bytes = parse_ipv6_bytes(ip_host)
  @if ip_bytes.len() != 16 return 0 @end
  buf = lipi_alloc(28)
  @if buf <= 0 return 0 @end
  k = 0
  @while k < 28
    sys_poke8(buf + k, 0)
    k = k + 1
  @end
  sys_poke8(buf + 0, 10) // AF_INET6 = 10 LE
  sys_poke8(buf + 1, 0)
  sys_poke8(buf + 2, (port >> 8) & 255)
  sys_poke8(buf + 3, port & 255)
  bi = 0
  @while bi < 16
    sys_poke8(buf + 8 + bi, ip_bytes[bi] & 255)
    bi = bi + 1
  @end
  return buf
@end

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

@fn tcp_socket_new_v6()
  fd = sys_socket(10, 1, 6)
  return fd
@end

@fn tcp_bind_v6(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  opt_buf = lipi_alloc(8)
  sys_poke32(opt_buf, 1)
  sys_setsockopt(sockfd, 1, 2, opt_buf, 4)
  sys_setsockopt(sockfd, 1, 15, opt_buf, 4)
  lipi_free(opt_buf)

  addr_buf = _tcp_pack_sockaddr6_buf(host, port, 1)
  @if addr_buf <= 0 return -1 @end
  res = sys_bind(sockfd, addr_buf, 28)
  lipi_free(addr_buf)
  return res
@end

@fn tcp_bind(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  @if tcp_is_ipv6_host(host) == 1
    return tcp_bind_v6(sockfd, host, port)
  @end
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

@fn tcp_connect_v6(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  addr_buf = _tcp_pack_sockaddr6_buf(host, port, 0)
  @if addr_buf <= 0 return -1 @end
  res = sys_connect(sockfd, addr_buf, 28)
  lipi_free(addr_buf)
  return res
@end

@fn tcp_connect(sockfd, host, port)
  @if sockfd < 0 return -1 @end
  @if tcp_is_ipv6_host(host) == 1
    return tcp_connect_v6(sockfd, host, port)
  @end
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

@fn tcp_listener_bind_v6(host, port) -> TcpListener
  fd = tcp_socket_new_v6()
  @if fd < 0
    return TcpListener(fd, host, port, "socket_failed")
  @end

  bind_res = tcp_bind_v6(fd, host, port)
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

@fn tcp_listener_bind(host, port) -> TcpListener
  @if tcp_is_ipv6_host(host) == 1
    return tcp_listener_bind_v6(host, port)
  @end
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

@fn tcp_stream_connect_v6(host, port) -> TcpStream
  @if host == "" || port <= 0
    return TcpStream(-1, host, port, "invalid_endpoint")
  @end
  @if parse_ipv6_bytes(host).len() != 16
    return TcpStream(-1, host, port, "invalid_ipv6")
  @end
  fd = tcp_socket_new_v6()
  @if fd < 0
    return TcpStream(fd, host, port, "socket_failed")
  @end
  tcp_set_timeout(fd, 5)

  conn_res = tcp_connect_v6(fd, host, port)
  @if conn_res < 0
    tcp_close(fd)
    return TcpStream(-1, host, port, "connect_failed")
  @end

  return TcpStream(fd, host, port, "")
@end

@fn tcp_stream_connect(host, port) -> TcpStream
  @if host == "" || port <= 0
    return TcpStream(-1, host, port, "invalid_endpoint")
  @end
  @if tcp_is_ipv6_host(host) == 1
    return tcp_stream_connect_v6(host, port)
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
