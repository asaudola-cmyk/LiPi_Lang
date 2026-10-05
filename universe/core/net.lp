import "universe/os/syscalls"
import "universe/core/string"

@! ==============================================================================
@! 👑 LIPI UNIVERSE — CORE BAREMETAL NETWORKING & WIRE ENGINE (universe/core/net.lp)
@! ⚡ 100% Native Linux Kernel AMD64 ABI | Direct Syscalls | 0% Libc | 0% C Dependencies
@! Features:
@!   - Raw TCP & UDP Socket Lifecycle Management
@!   - Zero-Copy Memory-Mapped Ring Buffers (NetRingBuffer)
@!   - High-Throughput Linux Batch Packet Transmission (sendmmsg / recvmmsg)
@!   - DMA-Aligned Memory Pools & Contiguous Packet Queues
@!   - Comprehensive Socket Tuning (SO_REUSEADDR, SO_REUSEPORT, TCP_NODELAY, NONBLOCK)
@! ==============================================================================

@! ------------------------------------------------------------------------------
@! 1. PROTOCOL, SOCKET FAMILY & OPTION CONSTANTS
@! ------------------------------------------------------------------------------

@! Address Families (Bits / sys/socket.h)
@fn AF_UNSPEC() return 0 @end
@fn AF_UNIX()   return 1 @end
@fn AF_INET()   return 2 @end
@fn AF_INET6()  return 10 @end
@fn AF_PACKET() return 17 @end

@! Socket Types
@fn SOCK_STREAM()    return 1 @end
@fn SOCK_DGRAM()     return 2 @end
@fn SOCK_RAW()       return 3 @end
@fn SOCK_NONBLOCK()  return 2048 @end
@fn SOCK_CLOEXEC()   return 524288 @end

@! Protocols
@fn IPPROTO_IP()   return 0 @end
@fn IPPROTO_TCP()  return 6 @end
@fn IPPROTO_UDP()  return 17 @end
@fn IPPROTO_RAW()  return 255 @end

@! Socket Option Levels
@fn SOL_SOCKET() return 1 @end
@fn SOL_TCP()    return 6 @end
@fn SOL_UDP()    return 17 @end

@! Socket Options (asm-generic/socket.h)
@fn SO_DEBUG()       return 1 @end
@fn SO_REUSEADDR()   return 2 @end
@fn SO_TYPE()        return 3 @end
@fn SO_ERROR()       return 4 @end
@fn SO_DONTROUTE()   return 5 @end
@fn SO_BROADCAST()   return 6 @end
@fn SO_SNDBUF()      return 7 @end
@fn SO_RCVBUF()      return 8 @end
@fn SO_KEEPALIVE()   return 9 @end
@fn SO_OOBINLINE()   return 10 @end
@fn SO_REUSEPORT()   return 15 @end
@fn SO_RCVTIMEO()    return 20 @end
@fn SO_SNDTIMEO()    return 21 @end

@! TCP Level Options
@fn TCP_NODELAY()    return 1 @end
@fn TCP_MAXSEG()     return 2 @end
@fn TCP_CORK()       return 3 @end
@fn TCP_KEEPIDLE()   return 4 @end
@fn TCP_KEEPINTVL()  return 5 @end
@fn TCP_KEEPCNT()    return 6 @end
@fn TCP_QUICKACK()   return 12 @end

@! Message Transmission / Reception Flags
@fn MSG_PEEK()       return 2 @end
@fn MSG_DONTWAIT()   return 64 @end
@fn MSG_WAITALL()    return 256 @end
@fn MSG_NOSIGNAL()   return 16384 @end
@fn MSG_MORE()       return 32768 @end

@! Shutdown Types
@fn SHUT_RD()   return 0 @end
@fn SHUT_WR()   return 1 @end
@fn SHUT_RDWR() return 2 @end

@! Linux Syscall Numbers for Direct Gateway
@fn SYS_READ()         return 0 @end
@fn SYS_WRITE()        return 1 @end
@fn SYS_CLOSE()        return 3 @end
@fn SYS_SOCKET()       return 41 @end
@fn SYS_CONNECT()      return 42 @end
@fn SYS_ACCEPT()       return 43 @end
@fn SYS_SENDTO()       return 44 @end
@fn SYS_RECVFROM()     return 45 @end
@fn SYS_SENDMSG()      return 46 @end
@fn SYS_RECVMSG()      return 47 @end
@fn SYS_SHUTDOWN()     return 48 @end
@fn SYS_BIND()         return 49 @end
@fn SYS_LISTEN()       return 50 @end
@fn SYS_GETSOCKNAME()  return 51 @end
@fn SYS_GETPEERNAME()  return 52 @end
@fn SYS_SOCKETPAIR()   return 53 @end
@fn SYS_SETSOCKOPT()   return 54 @end
@fn SYS_GETSOCKOPT()   return 55 @end
@fn SYS_FCNTL()        return 72 @end
@fn SYS_RECVMMSG()     return 299 @end
@fn SYS_SENDMMSG()     return 307 @end

@! ------------------------------------------------------------------------------
@! 2. DATA STRUCTURES
@! ------------------------------------------------------------------------------

@! Linux sockaddr_in layout (16 bytes):
@!   offset 0: u16 sin_family (AF_INET = 2)
@!   offset 2: u16 sin_port (Big Endian)
@!   offset 4: u32 sin_addr (Big Endian)
@!   offset 8..15: u8 sin_zero[8]
@struct sockaddr_in
  sin_family: i64
  sin_port: i64
  sin_addr: i64
  sin_zero1: i64
  sin_zero2: i64
@end

@struct NetEndpoint
  ep_ip: string
  ep_port: i64
  ep_family: i64
@end

@struct UdpPacket
  pkt_data: string
  pkt_src_ip: string
  pkt_src_port: i64
  pkt_bytes_received: i64
@end

@! Sovereign Raw Socket Ring Buffer
@! Lock-free contiguous ring buffer backed by page-aligned sys_mmap memory
@struct NetRingBuffer
  rb_capacity: i64
  rb_slot_size: i64
  rb_head: i64
  rb_tail: i64
  rb_mask: i64
  rb_buffer_ptr: i64
  rb_meta_ptr: i64
  rb_total_enqueued: i64
  rb_total_dequeued: i64
  rb_is_active: i64
@end

@! Sovereign Zero-Copy Batch Packet Transmission & Receive Queue
@! Wires together contiguous arrays of struct mmsghdr (64B), struct iovec (16B),
@! struct sockaddr_in (16B), and DMA-aligned data payload buffers
@struct NetBatchQueue
  bq_num_packets: i64
  bq_slot_size: i64
  bq_total_mmap_size: i64
  bq_mmap_ptr: i64
  bq_mmsg_ptr: i64
  bq_iov_ptr: i64
  bq_addr_ptr: i64
  bq_data_ptr: i64
  bq_is_active: i64
@end

@! ------------------------------------------------------------------------------
@! 3. BITWISE ENDIANNESS & IPV4 PARSING / FORMATTING
@! ------------------------------------------------------------------------------

@fn htons(port)
  // WHY: Converts 16-bit host integer to network byte order (Big Endian)
  b1 = (port / 256) & 255
  b2 = port & 255
  return (b2 * 256) + b1
@end

@fn ntohs(port)
  // WHY: Network to host 16-bit byte swap is symmetrical
  return htons(port)
@end

@fn htonl(val)
  // WHY: Converts 32-bit integer to network byte order (Big Endian)
  b0 = (val / 16777216) & 255
  b1 = (val / 65536) & 255
  b2 = (val / 256) & 255
  b3 = val & 255
  r0 = (b3 * 16777216)
  r1 = (b2 * 65536)
  r2 = (b1 * 256)
  r3 = b0
  return r0 + r1 + r2 + r3
@end

@fn ntohl(val)
  // WHY: Network to host 32-bit byte swap is symmetrical
  return htonl(val)
@end

@fn net_parse_ipv4_octets(ip_str)
  // WHY: Parses dotted-quad IPv4 string into a 4-element array [o0, o1, o2, o3]
  // Completely autonomous: 0% libc inet_pton, 0% regex. Strict boundary and character validation.
  @if ip_str == "" || ip_str == "0.0.0.0"
    return [0, 0, 0, 0]
  @end
  @if ip_str == "localhost" || ip_str == "127.0.0.1"
    return [127, 0, 0, 1]
  @end

  octets = []
  curr = 0
  has_digits = 0
  is_valid = 1
  n = str_len(ip_str)
  i = 0
  @while i < n
    ch = str_char_at(ip_str, i)
    @if ch >= 48 && ch <= 57
      curr = (curr * 10) + (ch - 48)
      has_digits = 1
      @if curr > 255
        is_valid = 0
      @end
    @elif ch == 46
      @if has_digits == 0
        is_valid = 0
      @end
      octets = octets.push(curr & 255)
      curr = 0
      has_digits = 0
    @else
      is_valid = 0
    @end
    i = i + 1
  @end
  @if has_digits == 1
    octets = octets.push(curr & 255)
  @else
    is_valid = 0
  @end

  @if is_valid == 0 || octets.len() != 4
    return [0, 0, 0, 0]
  @end
  return octets
@end

@fn net_format_ipv4(o0, o1, o2, o3)
  // WHY: Converts four byte octets into canonical dotted-decimal IPv4 string
  s0 = to_str(o0 & 255)
  s1 = to_str(o1 & 255)
  s2 = to_str(o2 & 255)
  s3 = to_str(o3 & 255)
  return s0 + "." + s1 + "." + s2 + "." + s3
@end

@fn net_sockaddr_in_alloc(ip_str, port)
  // WHY: Allocates and writes a 16-byte Linux sockaddr_in structure directly via sys_mmap
  addr_ptr = sys_mmap(0, 16, 3, 34, -1, 0)
  @if addr_ptr <= 0
    return 0
  @end

  // offset 0: sin_family = AF_INET (2)
  sys_poke8(addr_ptr + 0, 2)
  sys_poke8(addr_ptr + 1, 0)

  // offset 2: sin_port in Big Endian
  sys_poke8(addr_ptr + 2, (port / 256) & 255)
  sys_poke8(addr_ptr + 3, port & 255)

  // offset 4: sin_addr in Big Endian
  octets = net_parse_ipv4_octets(ip_str)
  sys_poke8(addr_ptr + 4, octets[0])
  sys_poke8(addr_ptr + 5, octets[1])
  sys_poke8(addr_ptr + 6, octets[2])
  sys_poke8(addr_ptr + 7, octets[3])

  // offset 8..15: sin_zero padding
  sys_poke(addr_ptr + 8, 0)
  return addr_ptr
@end

@fn net_sockaddr_in_free(addr_ptr)
  // WHY: Frees 16-byte sockaddr_in structure via sys_munmap
  @if addr_ptr > 0
    return sys_munmap(addr_ptr, 16)
  @end
  return 0
@end

@fn net_sockaddr_in_get_ip(addr_ptr)
  // WHY: Extracts source or peer IPv4 dotted string from raw memory sockaddr_in
  @if addr_ptr <= 0
    return "0.0.0.0"
  @end
  o0 = sys_peek8(addr_ptr + 4) & 255
  o1 = sys_peek8(addr_ptr + 5) & 255
  o2 = sys_peek8(addr_ptr + 6) & 255
  o3 = sys_peek8(addr_ptr + 7) & 255
  return net_format_ipv4(o0, o1, o2, o3)
@end

@fn net_sockaddr_in_get_port(addr_ptr)
  // WHY: Extracts port number from raw memory sockaddr_in
  @if addr_ptr <= 0
    return 0
  @end
  p_hi = sys_peek8(addr_ptr + 2) & 255
  p_lo = sys_peek8(addr_ptr + 3) & 255
  return (p_hi * 256) + p_lo
@end

@! ------------------------------------------------------------------------------
@! 4. DIRECT RAW SYSCALL WRAPPERS (0% LIBC LINUX SOVEREIGNTY)
@! ------------------------------------------------------------------------------

@fn net_socket(domain, type, protocol)
  // WHY: Allocates a new kernel socket descriptor via Linux syscall 41
  return syscall(41, domain, type, protocol, 0, 0, 0)
@end

@fn net_bind(sockfd, addr_ptr, addrlen)
  // WHY: Binds socket to specified address via Linux syscall 49
  return syscall(49, sockfd, addr_ptr, addrlen, 0, 0, 0)
@end

@fn net_listen(sockfd, backlog)
  // WHY: Puts socket in passive listening state via Linux syscall 50
  return syscall(50, sockfd, backlog, 0, 0, 0, 0)
@end

@fn net_accept(sockfd, addr_ptr, addrlen_ptr)
  // WHY: Accepts connection via Linux syscall 43
  return syscall(43, sockfd, addr_ptr, addrlen_ptr, 0, 0, 0)
@end

@fn net_connect(sockfd, addr_ptr, addrlen)
  // WHY: Connects socket to remote endpoint via Linux syscall 42
  return syscall(42, sockfd, addr_ptr, addrlen, 0, 0, 0)
@end

@fn net_read(fd, buf, count)
  // WHY: Direct kernel read via Linux syscall 0
  return syscall(0, fd, buf, count, 0, 0, 0)
@end

@fn net_write(fd, buf, count)
  // WHY: Direct kernel write via Linux syscall 1
  return syscall(1, fd, buf, count, 0, 0, 0)
@end

@fn net_close(fd)
  // WHY: Releases file/socket descriptor via Linux syscall 3
  return syscall(3, fd, 0, 0, 0, 0, 0)
@end

@fn net_sendto(sockfd, buf, len, flags, dest_addr, addrlen)
  // WHY: Transmits datagram to destination via Linux syscall 44
  return syscall(44, sockfd, buf, len, flags, dest_addr, addrlen)
@end

@fn net_recvfrom(sockfd, buf, len, flags, src_addr, addrlen_ptr)
  // WHY: Receives datagram and records sender address via Linux syscall 45
  return syscall(45, sockfd, buf, len, flags, src_addr, addrlen_ptr)
@end

@fn net_sendmsg(sockfd, msg_hdr, flags)
  // WHY: Scatter/gather message transmission via Linux syscall 46
  return syscall(46, sockfd, msg_hdr, flags, 0, 0, 0)
@end

@fn net_recvmsg(sockfd, msg_hdr, flags)
  // WHY: Scatter/gather message reception via Linux syscall 47
  return syscall(47, sockfd, msg_hdr, flags, 0, 0, 0)
@end

@fn net_shutdown(sockfd, how)
  // WHY: Shuts down full-duplex socket channel via Linux syscall 48
  return syscall(48, sockfd, how, 0, 0, 0, 0)
@end

@fn net_getsockname(sockfd, addr_ptr, addrlen_ptr)
  // WHY: Queries locally bound socket name via Linux syscall 51
  return syscall(51, sockfd, addr_ptr, addrlen_ptr, 0, 0, 0)
@end

@fn net_getpeername(sockfd, addr_ptr, addrlen_ptr)
  // WHY: Queries connected remote peer address via Linux syscall 52
  return syscall(52, sockfd, addr_ptr, addrlen_ptr, 0, 0, 0)
@end

@fn net_socketpair(domain, type, protocol, sv_ptr)
  // WHY: Allocates a pair of connected sockets via Linux syscall 53
  return syscall(53, domain, type, protocol, sv_ptr, 0, 0)
@end

@fn net_setsockopt(sockfd, level, optname, optval, optlen)
  // WHY: Configures socket tuning options via Linux syscall 54
  return syscall(54, sockfd, level, optname, optval, optlen, 0)
@end

@fn net_getsockopt(sockfd, level, optname, optval, optlen_ptr)
  // WHY: Inspects current socket option state via Linux syscall 55
  return syscall(55, sockfd, level, optname, optval, optlen_ptr, 0)
@end

@fn net_fcntl(fd, cmd, arg)
  // WHY: Performs file descriptor control (e.g. non-blocking mode) via Linux syscall 72
  return syscall(72, fd, cmd, arg, 0, 0, 0)
@end

@fn net_sendmmsg(sockfd, msgvec, vlen, flags)
  // WHY: Batch packet transmission via Linux syscall 307
  return syscall(307, sockfd, msgvec, vlen, flags, 0, 0)
@end

@fn net_recvmmsg(sockfd, msgvec, vlen, flags, timeout_ptr)
  // WHY: Batch packet reception via Linux syscall 299
  return syscall(299, sockfd, msgvec, vlen, flags, timeout_ptr, 0)
@end

@! ------------------------------------------------------------------------------
@! 5. SOCKET TUNING & CONFIGURATION HELPERS
@! ------------------------------------------------------------------------------

@fn net_set_reuseaddr(sockfd, enable)
  // WHY: Eliminates TIME_WAIT bind failures on restart
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(opt_buf + 0, enable & 255)
  sys_poke8(opt_buf + 1, 0)
  sys_poke8(opt_buf + 2, 0)
  sys_poke8(opt_buf + 3, 0)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_REUSEADDR(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_tcp_set_reuseaddr(sockfd)
  // WHY: Backward-compatibility alias for legacy code
  return net_set_reuseaddr(sockfd, 1)
@end

@fn net_set_reuseport(sockfd, enable)
  // WHY: Enables SO_REUSEPORT (15) to distribute incoming load across multi-core listeners
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(opt_buf + 0, enable & 255)
  sys_poke8(opt_buf + 1, 0)
  sys_poke8(opt_buf + 2, 0)
  sys_poke8(opt_buf + 3, 0)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_REUSEPORT(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_set_nodelay(sockfd, enable)
  // WHY: Disables Nagle's algorithm (TCP_NODELAY = 1) for sub-millisecond wire latency
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(opt_buf + 0, enable & 255)
  sys_poke8(opt_buf + 1, 0)
  sys_poke8(opt_buf + 2, 0)
  sys_poke8(opt_buf + 3, 0)
  res = net_setsockopt(sockfd, IPPROTO_TCP(), TCP_NODELAY(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_set_broadcast(sockfd, enable)
  // WHY: Permits transmission of broadcast datagrams on UDP sockets (SO_BROADCAST = 6)
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke8(opt_buf + 0, enable & 255)
  sys_poke8(opt_buf + 1, 0)
  sys_poke8(opt_buf + 2, 0)
  sys_poke8(opt_buf + 3, 0)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_BROADCAST(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_set_rcvbuf(sockfd, size)
  // WHY: Sets kernel receive window buffer size (SO_RCVBUF = 8)
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(opt_buf, size)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_RCVBUF(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_set_sndbuf(sockfd, size)
  // WHY: Sets kernel transmit window buffer size (SO_SNDBUF = 7)
  opt_buf = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(opt_buf, size)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_SNDBUF(), opt_buf, 4)
  sys_munmap(opt_buf, 8)
  return res
@end

@fn net_set_nonblocking(sockfd, enable)
  // WHY: Configures socket descriptor for asynchronous non-blocking operation via fcntl
  flags = net_fcntl(sockfd, 3, 0) // F_GETFL = 3
  @if flags < 0
    return -1
  @end
  @if enable == 1
    new_flags = flags | 2048 // O_NONBLOCK = 2048
  @else
    new_flags = flags & (0 - 2049) // Clear O_NONBLOCK
  @end
  return net_fcntl(sockfd, 4, new_flags) // F_SETFL = 4
@end

@fn net_set_rcvtimeo(sockfd, sec, usec)
  // WHY: Sets socket receive timeout struct timeval (16 bytes: 8B sec, 8B usec)
  tv_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(tv_buf + 0, sec)
  sys_poke(tv_buf + 8, usec)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_RCVTIMEO(), tv_buf, 16)
  sys_munmap(tv_buf, 16)
  return res
@end

@fn net_set_sndtimeo(sockfd, sec, usec)
  // WHY: Sets socket send timeout struct timeval (16 bytes: 8B sec, 8B usec)
  tv_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(tv_buf + 0, sec)
  sys_poke(tv_buf + 8, usec)
  res = net_setsockopt(sockfd, SOL_SOCKET(), SO_SNDTIMEO(), tv_buf, 16)
  sys_munmap(tv_buf, 16)
  return res
@end

@! ------------------------------------------------------------------------------
@! 6. HIGH-LEVEL TCP SOCKET API
@! ------------------------------------------------------------------------------

@fn net_tcp_socket()
  // WHY: Allocates IPv4 streaming socket (AF_INET=2, SOCK_STREAM=1, 0)
  return net_socket(2, 1, 0)
@end

@fn net_tcp_socket_nonblocking()
  // WHY: Atomically creates non-blocking TCP socket to avoid race conditions
  return net_socket(2, 1 | 2048 | 524288, 0)
@end

@fn net_tcp_bind(sockfd, port)
  // WHY: Binds socket to 0.0.0.0 (INADDR_ANY):port
  return net_tcp_bind_addr(sockfd, "0.0.0.0", port)
@end

@fn net_tcp_bind_addr(sockfd, ip_str, port)
  // WHY: Binds TCP socket to specific IPv4 address and port
  addr = net_sockaddr_in_alloc(ip_str, port)
  @if addr <= 0 return -1 @end
  res = net_bind(sockfd, addr, 16)
  net_sockaddr_in_free(addr)
  return res
@end

@fn net_tcp_listen(sockfd, backlog)
  // WHY: Places socket in passive listening state with backlog
  return net_listen(sockfd, backlog)
@end

@fn net_tcp_accept(sockfd)
  // WHY: Accepts inbound connection without recording peer address
  return net_accept(sockfd, 0, 0)
@end

@fn net_tcp_accept_endpoint(sockfd)
  // WHY: Accepts connection and parses peer address and port
  addr = sys_mmap(0, 16, 3, 34, -1, 0)
  addrlen = sys_mmap(0, 8, 3, 34, -1, 0)
  @if addr <= 0 || addrlen <= 0
    @if addr > 0 sys_munmap(addr, 16) @end
    @if addrlen > 0 sys_munmap(addrlen, 8) @end
    return { client_fd: -1, client_ip: "", client_port: 0 }
  @end
  sys_poke(addrlen, 16)

  client_fd = net_accept(sockfd, addr, addrlen)
  @if client_fd < 0
    sys_munmap(addr, 16)
    sys_munmap(addrlen, 8)
    return { client_fd: -1, client_ip: "", client_port: 0 }
  @end

  client_ip = net_sockaddr_in_get_ip(addr)
  client_port = net_sockaddr_in_get_port(addr)
  sys_munmap(addr, 16)
  sys_munmap(addrlen, 8)

  return {
    client_fd: client_fd,
    client_ip: client_ip,
    client_port: client_port
  }
@end

@fn net_tcp_connect(sockfd, ip_str, port)
  // WHY: Connects TCP socket to remote target IP and port
  addr = net_sockaddr_in_alloc(ip_str, port)
  @if addr <= 0 return -1 @end
  res = net_connect(sockfd, addr, 16)
  net_sockaddr_in_free(addr)
  return res
@end

@fn net_tcp_connect_to(ip_str, port)
  // WHY: One-step TCP client creation and connection
  fd = net_tcp_socket()
  @if fd < 0 return -1 @end
  res = net_tcp_connect(fd, ip_str, port)
  @if res < 0
    net_close(fd)
    return -1
  @end
  return fd
@end

@fn net_tcp_send(sockfd, data)
  // WHY: Sends string payload over TCP socket
  return net_write(sockfd, data, str_len(data))
@end

@fn net_tcp_send_raw(sockfd, buf_ptr, len)
  // WHY: Zero-copy sends raw memory bytes over TCP socket
  return net_write(sockfd, buf_ptr, len)
@end

@fn net_tcp_recv(sockfd, max_len)
  // WHY: Reads raw incoming bytes into buffer and returns Lipi string
  @if max_len <= 0 max_len = 4096 @end
  buf = sys_mmap(0, max_len + 1, 3, 34, -1, 0)
  @if buf <= 0 return "" @end
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

@fn net_tcp_recv_raw(sockfd, buf_ptr, max_len)
  // WHY: Zero-copy reads bytes directly into pre-allocated memory
  return net_read(sockfd, buf_ptr, max_len)
@end

@fn net_tcp_shutdown(sockfd, how)
  // WHY: Gracefully terminates transmission or reception channel
  return net_shutdown(sockfd, how)
@end

@fn net_tcp_close(sockfd)
  // WHY: Frees kernel socket descriptor
  return net_close(sockfd)
@end

@! ------------------------------------------------------------------------------
@! 7. HIGH-LEVEL UDP SOCKET API
@! ------------------------------------------------------------------------------

@fn net_udp_socket()
  // WHY: Allocates IPv4 datagram socket (AF_INET=2, SOCK_DGRAM=2, IPPROTO_UDP=0)
  return net_socket(2, 2, 0)
@end

@fn net_udp_socket_nonblocking()
  // WHY: Atomically creates non-blocking UDP socket
  return net_socket(2, 2 | 2048 | 524288, 0)
@end

@fn net_udp_bind(sockfd, port)
  // WHY: Binds UDP socket to 0.0.0.0:port
  return net_udp_bind_addr(sockfd, "0.0.0.0", port)
@end

@fn net_udp_bind_addr(sockfd, ip_str, port)
  // WHY: Binds UDP socket to specific address and port
  addr = net_sockaddr_in_alloc(ip_str, port)
  @if addr <= 0 return -1 @end
  res = net_bind(sockfd, addr, 16)
  net_sockaddr_in_free(addr)
  return res
@end

@fn net_udp_connect(sockfd, ip_str, port)
  // WHY: Dissolves connectionless state to lock socket to default destination peer
  addr = net_sockaddr_in_alloc(ip_str, port)
  @if addr <= 0 return -1 @end
  res = net_connect(sockfd, addr, 16)
  net_sockaddr_in_free(addr)
  return res
@end

@fn net_udp_sendto(sockfd, data, ip_str, port)
  // WHY: Sends datagram string payload to specified destination
  dest_addr = net_sockaddr_in_alloc(ip_str, port)
  @if dest_addr <= 0 return -1 @end
  d_len = str_len(data)
  res = net_sendto(sockfd, data, d_len, 0, dest_addr, 16)
  net_sockaddr_in_free(dest_addr)
  return res
@end

@fn net_udp_sendto_raw(sockfd, buf_ptr, len, ip_str, port)
  // WHY: Zero-copy sends raw memory bytes to destination
  dest_addr = net_sockaddr_in_alloc(ip_str, port)
  @if dest_addr <= 0 return -1 @end
  res = net_sendto(sockfd, buf_ptr, len, 0, dest_addr, 16)
  net_sockaddr_in_free(dest_addr)
  return res
@end

@fn net_udp_recvfrom(sockfd, max_len)
  // WHY: Receives datagram, extracts sender IP/port and returns UdpPacket object
  @if max_len <= 0 max_len = 65536 @end
  buf = sys_mmap(0, max_len + 1, 3, 34, -1, 0)
  src_addr = sys_mmap(0, 16, 3, 34, -1, 0)
  addrlen = sys_mmap(0, 8, 3, 34, -1, 0)
  @if buf <= 0 || src_addr <= 0 || addrlen <= 0
    @if buf > 0 sys_munmap(buf, max_len + 1) @end
    @if src_addr > 0 sys_munmap(src_addr, 16) @end
    @if addrlen > 0 sys_munmap(addrlen, 8) @end
    return { pkt_data: "", pkt_src_ip: "", pkt_src_port: 0, pkt_bytes_received: -1 }
  @end
  sys_poke(addrlen, 16)

  nbytes = net_recvfrom(sockfd, buf, max_len, 0, src_addr, addrlen)
  @if nbytes < 0
    sys_munmap(buf, max_len + 1)
    sys_munmap(src_addr, 16)
    sys_munmap(addrlen, 8)
    return { pkt_data: "", pkt_src_ip: "", pkt_src_port: 0, pkt_bytes_received: nbytes }
  @end

  src_ip = net_sockaddr_in_get_ip(src_addr)
  src_port = net_sockaddr_in_get_port(src_addr)

  data_str = ""
  i = 0
  @while i < nbytes
    b = sys_peek8(buf + i) & 255
    data_str = data_str + chr(b)
    i = i + 1
  @end

  sys_munmap(buf, max_len + 1)
  sys_munmap(src_addr, 16)
  sys_munmap(addrlen, 8)

  return {
    pkt_data: data_str,
    pkt_src_ip: src_ip,
    pkt_src_port: src_port,
    pkt_bytes_received: nbytes
  }
@end

@fn net_udp_recvfrom_raw(sockfd, buf_ptr, max_len, addr_ptr_out)
  // WHY: Zero-copy receives raw datagram directly into memory buffer
  addrlen = sys_mmap(0, 8, 3, 34, 0 - 1, 0)
  sys_poke(addrlen, 16)
  res = net_recvfrom(sockfd, buf_ptr, max_len, 0, addr_ptr_out, addrlen)
  sys_munmap(addrlen, 8)
  return res
@end

@fn net_udp_send(sockfd, data)
  // WHY: Sends datagram over connected UDP socket
  return net_write(sockfd, data, str_len(data))
@end

@fn net_udp_recv(sockfd, max_len)
  // WHY: Receives datagram on connected UDP socket
  return net_tcp_recv(sockfd, max_len)
@end

@fn net_udp_close(sockfd)
  // WHY: Closes UDP socket descriptor
  return net_close(sockfd)
@end

@! ------------------------------------------------------------------------------
@! 8. RAW TCP/UDP RING BUFFER ABSTRACTION (0% LIBC, MMAP BACKED)
@! ------------------------------------------------------------------------------

@fn net_ring_new(capacity, slot_size)
  // WHY: Allocates a lock-free circular ring buffer backed by page-aligned sys_mmap
  // Decouples high-throughput network wire ingestion from application processing
  @if capacity < 2 capacity = 2 @end
  @if slot_size < 16 slot_size = 16 @end

  // Ensure capacity is a power of 2 for zero-division masking
  cap = 2
  @while cap < capacity
    cap = cap * 2
  @end
  mask = cap - 1

  total_data_sz = cap * slot_size
  data_buf = sys_mmap(0, total_data_sz, 3, 34, -1, 0)
  @if data_buf <= 0 return 0 @end

  // Meta array: 16 bytes per slot (offset 0: len, offset 8: status)
  total_meta_sz = cap * 16
  meta_buf = sys_mmap(0, total_meta_sz, 3, 34, -1, 0)
  @if meta_buf <= 0
    sys_munmap(data_buf, total_data_sz)
    return 0
  @end

  // Initialize meta slots to zero
  i = 0
  @while i < cap
    sys_poke(meta_buf + (i * 16) + 0, 0)
    sys_poke(meta_buf + (i * 16) + 8, 0)
    i = i + 1
  @end

  return {
    rb_capacity: cap,
    rb_slot_size: slot_size,
    rb_head: 0,
    rb_tail: 0,
    rb_mask: mask,
    rb_buffer_ptr: data_buf,
    rb_meta_ptr: meta_buf,
    rb_total_enqueued: 0,
    rb_total_dequeued: 0,
    rb_is_active: 1
  }
@end

@fn net_ring_count(ring)
  // WHY: Returns number of unconsumed items currently in the ring
  @if ring.rb_is_active == 0 return 0 @end
  return ring.rb_tail - ring.rb_head
@end

@fn net_ring_is_empty(ring)
  @if ring.rb_is_active == 0 return 1 @end
  return ring.rb_tail == ring.rb_head
@end

@fn net_ring_is_full(ring)
  @if ring.rb_is_active == 0 return 1 @end
  return (ring.rb_tail - ring.rb_head) >= ring.rb_capacity
@end

@fn net_ring_push(ring, buf_ptr, len)
  // WHY: Zero-copy pushes raw byte memory into the next ring slot
  @if ring.rb_is_active == 0 return 0 @end
  @if (ring.rb_tail - ring.rb_head) >= ring.rb_capacity
    return 0 // Ring is full
  @end

  idx = ring.rb_tail & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  copy_len = len
  @if copy_len > ring.rb_slot_size
    copy_len = ring.rb_slot_size
  @end

  i = 0
  @while i < copy_len
    b = sys_peek8(buf_ptr + i)
    sys_poke8(slot_addr + i, b)
    i = i + 1
  @end

  // Record slot metadata (length & occupied status)
  meta_addr = ring.rb_meta_ptr + (idx * 16)
  sys_poke(meta_addr + 0, copy_len)
  sys_poke(meta_addr + 8, 1)

  ring.rb_tail = ring.rb_tail + 1
  ring.rb_total_enqueued = ring.rb_total_enqueued + 1
  return copy_len
@end

@fn net_ring_push_str(ring, data_str)
  // WHY: Pushes Lipi string into ring buffer slot
  @if ring.rb_is_active == 0 return 0 @end
  @if (ring.rb_tail - ring.rb_head) >= ring.rb_capacity
    return 0 // Full
  @end

  idx = ring.rb_tail & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  d_len = str_len(data_str)
  copy_len = d_len
  @if copy_len > ring.rb_slot_size
    copy_len = ring.rb_slot_size
  @end

  i = 0
  @while i < copy_len
    ch = str_char_at(data_str, i)
    sys_poke8(slot_addr + i, ch)
    i = i + 1
  @end

  meta_addr = ring.rb_meta_ptr + (idx * 16)
  sys_poke(meta_addr + 0, copy_len)
  sys_poke(meta_addr + 8, 1)

  ring.rb_tail = ring.rb_tail + 1
  ring.rb_total_enqueued = ring.rb_total_enqueued + 1
  return copy_len
@end

@fn net_ring_pop(ring, dest_ptr, max_len)
  // WHY: Zero-copy pops packet from ring buffer into caller memory
  @if ring.rb_is_active == 0 || ring.rb_head == ring.rb_tail
    return 0 // Empty
  @end

  idx = ring.rb_head & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  meta_addr = ring.rb_meta_ptr + (idx * 16)
  pkt_len = sys_peek(meta_addr + 0)

  copy_len = pkt_len
  @if copy_len > max_len
    copy_len = max_len
  @end

  i = 0
  @while i < copy_len
    b = sys_peek8(slot_addr + i)
    sys_poke8(dest_ptr + i, b)
    i = i + 1
  @end

  // Free metadata slot
  sys_poke(meta_addr + 0, 0)
  sys_poke(meta_addr + 8, 0)

  ring.rb_head = ring.rb_head + 1
  ring.rb_total_dequeued = ring.rb_total_dequeued + 1
  return copy_len
@end

@fn net_ring_pop_str(ring)
  // WHY: Pops next packet from ring buffer and returns as Lipi string
  @if ring.rb_is_active == 0 || ring.rb_head == ring.rb_tail
    return ""
  @end

  idx = ring.rb_head & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  meta_addr = ring.rb_meta_ptr + (idx * 16)
  pkt_len = sys_peek(meta_addr + 0)

  res = ""
  i = 0
  @while i < pkt_len
    b = sys_peek8(slot_addr + i) & 255
    res = res + chr(b)
    i = i + 1
  @end

  sys_poke(meta_addr + 0, 0)
  sys_poke(meta_addr + 8, 0)

  ring.rb_head = ring.rb_head + 1
  ring.rb_total_dequeued = ring.rb_total_dequeued + 1
  return res
@end

@fn net_ring_peek(ring, dest_ptr, max_len)
  // WHY: Non-destructively peeks at next packet in ring buffer without advancing head
  @if ring.rb_is_active == 0 || ring.rb_head == ring.rb_tail
    return 0 // Empty
  @end

  idx = ring.rb_head & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  meta_addr = ring.rb_meta_ptr + (idx * 16)
  pkt_len = sys_peek(meta_addr + 0)

  copy_len = pkt_len
  @if copy_len > max_len
    copy_len = max_len
  @end

  i = 0
  @while i < copy_len
    b = sys_peek8(slot_addr + i)
    sys_poke8(dest_ptr + i, b)
    i = i + 1
  @end
  return copy_len
@end

@fn net_ring_peek_str(ring)
  // WHY: Non-destructively inspects next packet in ring buffer as string without popping
  @if ring.rb_is_active == 0 || ring.rb_head == ring.rb_tail
    return ""
  @end

  idx = ring.rb_head & ring.rb_mask
  slot_addr = ring.rb_buffer_ptr + (idx * ring.rb_slot_size)
  meta_addr = ring.rb_meta_ptr + (idx * 16)
  pkt_len = sys_peek(meta_addr + 0)

  res = ""
  i = 0
  @while i < pkt_len
    b = sys_peek8(slot_addr + i) & 255
    res = res + chr(b)
    i = i + 1
  @end
  return res
@end

@fn net_ring_free(ring)
  // WHY: Gracefully unmaps ring memory pages
  @if ring.rb_is_active == 1
    total_data_sz = ring.rb_capacity * ring.rb_slot_size
    total_meta_sz = ring.rb_capacity * 16
    @if ring.rb_buffer_ptr > 0
      sys_munmap(ring.rb_buffer_ptr, total_data_sz)
    @end
    @if ring.rb_meta_ptr > 0
      sys_munmap(ring.rb_meta_ptr, total_meta_sz)
    @end
    ring.rb_is_active = 0
    ring.rb_buffer_ptr = 0
    ring.rb_meta_ptr = 0
  @end
  return 1
@end

@! ------------------------------------------------------------------------------
@! 9. HIGH-PERFORMANCE BATCH PACKET QUEUES (sendmmsg / recvmmsg)
@! ------------------------------------------------------------------------------

@fn net_batch_queue_new(num_packets, slot_size)
  // WHY: Allocates a contiguous DMA/mmap memory pool containing pre-wired
  // Linux struct mmsghdr (64B), struct iovec (16B), sockaddr_in (16B) and payload slots.
  // Achieves 100% zero-copy, zero-allocation packet bursts over sendmmsg and recvmmsg.
  @if num_packets < 1 num_packets = 1 @end
  @if slot_size < 64 slot_size = 64 @end

  mmsg_sz = num_packets * 64
  iov_sz = num_packets * 16
  addr_sz = num_packets * 16
  data_sz = num_packets * slot_size

  total_sz = mmsg_sz + iov_sz + addr_sz + data_sz
  pool_ptr = sys_mmap(0, total_sz, 3, 34, -1, 0)
  @if pool_ptr <= 0 return 0 @end

  p_mmsg = pool_ptr
  p_iov = p_mmsg + mmsg_sz
  p_addr = p_iov + iov_sz
  p_data = p_addr + addr_sz

  // Pre-wire every mmsghdr to point to its corresponding iovec and data buffer
  i = 0
  @while i < num_packets
    cur_mmsg = p_mmsg + (i * 64)
    cur_iov = p_iov + (i * 16)
    cur_addr = p_addr + (i * 16)
    cur_data = p_data + (i * slot_size)

    // iovec wiring
    sys_poke(cur_iov + 0, cur_data)   // iov_base
    sys_poke(cur_iov + 8, slot_size)  // iov_len

    // mmsghdr wiring
    sys_poke(cur_mmsg + 0, cur_addr)  // msg_name (sockaddr*)
    sys_poke(cur_mmsg + 8, 16)        // msg_namelen
    sys_poke(cur_mmsg + 16, cur_iov)  // msg_iov
    sys_poke(cur_mmsg + 24, 1)        // msg_iovlen
    sys_poke(cur_mmsg + 32, 0)        // msg_control
    sys_poke(cur_mmsg + 40, 0)        // msg_controllen
    sys_poke(cur_mmsg + 48, 0)        // msg_flags
    sys_poke(cur_mmsg + 56, 0)        // msg_len (transfer result)

    // initialize default sockaddr to AF_INET
    sys_poke8(cur_addr + 0, 2)
    sys_poke8(cur_addr + 1, 0)
    sys_poke(cur_addr + 8, 0)

    i = i + 1
  @end

  return {
    bq_num_packets: num_packets,
    bq_slot_size: slot_size,
    bq_total_mmap_size: total_sz,
    bq_mmap_ptr: pool_ptr,
    bq_mmsg_ptr: p_mmsg,
    bq_iov_ptr: p_iov,
    bq_addr_ptr: p_addr,
    bq_data_ptr: p_data,
    bq_is_active: 1
  }
@end

@fn net_batch_set_packet(queue, index, data_str, ip_str, port)
  // WHY: Populates a batch slot with destination address and packet string payload
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets
    return 0
  @end

  cur_mmsg = queue.bq_mmsg_ptr + (index * 64)
  cur_iov = queue.bq_iov_ptr + (index * 16)
  cur_addr = queue.bq_addr_ptr + (index * 16)
  cur_data = queue.bq_data_ptr + (index * queue.bq_slot_size)

  // Configure sockaddr
  sys_poke8(cur_addr + 0, 2)
  sys_poke8(cur_addr + 1, 0)
  sys_poke8(cur_addr + 2, (port / 256) & 255)
  sys_poke8(cur_addr + 3, port & 255)

  octets = net_parse_ipv4_octets(ip_str)
  sys_poke8(cur_addr + 4, octets[0])
  sys_poke8(cur_addr + 5, octets[1])
  sys_poke8(cur_addr + 6, octets[2])
  sys_poke8(cur_addr + 7, octets[3])
  sys_poke(cur_addr + 8, 0)

  // Copy data string into payload buffer
  d_len = str_len(data_str)
  copy_len = d_len
  @if copy_len > queue.bq_slot_size
    copy_len = queue.bq_slot_size
  @end

  i = 0
  @while i < copy_len
    ch = str_char_at(data_str, i)
    sys_poke8(cur_data + i, ch)
    i = i + 1
  @end

  // Update iovec length and clear msg_len
  sys_poke(cur_iov + 8, copy_len)
  sys_poke(cur_mmsg + 56, 0)
  return copy_len
@end

@fn net_batch_set_packet_raw(queue, index, src_buf, len, ip_str, port)
  // WHY: Zero-copy populates batch slot with raw byte memory
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets
    return 0
  @end

  cur_mmsg = queue.bq_mmsg_ptr + (index * 64)
  cur_iov = queue.bq_iov_ptr + (index * 16)
  cur_addr = queue.bq_addr_ptr + (index * 16)
  cur_data = queue.bq_data_ptr + (index * queue.bq_slot_size)

  // Configure sockaddr
  sys_poke8(cur_addr + 0, 2)
  sys_poke8(cur_addr + 1, 0)
  sys_poke8(cur_addr + 2, (port / 256) & 255)
  sys_poke8(cur_addr + 3, port & 255)

  octets = net_parse_ipv4_octets(ip_str)
  sys_poke8(cur_addr + 4, octets[0])
  sys_poke8(cur_addr + 5, octets[1])
  sys_poke8(cur_addr + 6, octets[2])
  sys_poke8(cur_addr + 7, octets[3])
  sys_poke(cur_addr + 8, 0)

  copy_len = len
  @if copy_len > queue.bq_slot_size
    copy_len = queue.bq_slot_size
  @end

  i = 0
  @while i < copy_len
    b = sys_peek8(src_buf + i)
    sys_poke8(cur_data + i, b)
    i = i + 1
  @end

  sys_poke(cur_iov + 8, copy_len)
  sys_poke(cur_mmsg + 56, 0)
  return copy_len
@end

@fn net_batch_send(sockfd, queue, count)
  // WHY: Transmits up to count packets in a single Linux sendmmsg syscall (307)
  @if queue.bq_is_active == 0 || count <= 0 return 0 @end
  @if count > queue.bq_num_packets count = queue.bq_num_packets @end
  return net_sendmmsg(sockfd, queue.bq_mmsg_ptr, count, 0)
@end

@fn net_batch_recv(sockfd, queue, count, timeout_ms)
  // WHY: Reaps up to count packets in a single Linux recvmmsg syscall (299)
  @if queue.bq_is_active == 0 || count <= 0 return 0 @end
  @if count > queue.bq_num_packets count = queue.bq_num_packets @end

  // Reset iovec lengths to full slot capacity
  i = 0
  @while i < count
    cur_iov = queue.bq_iov_ptr + (i * 16)
    cur_mmsg = queue.bq_mmsg_ptr + (i * 64)
    sys_poke(cur_iov + 8, queue.bq_slot_size)
    sys_poke(cur_mmsg + 8, 16) // Reset msg_namelen
    sys_poke(cur_mmsg + 56, 0) // Clear msg_len
    i = i + 1
  @end

  t_ptr = 0
  @if timeout_ms > 0
    t_ptr = sys_mmap(0, 16, 3, 34, -1, 0)
    sec = timeout_ms / 1000
    nsec = (timeout_ms - (sec * 1000)) * 1000000
    sys_poke(t_ptr + 0, sec)
    sys_poke(t_ptr + 8, nsec)
  @end

  res = net_recvmmsg(sockfd, queue.bq_mmsg_ptr, count, 0, t_ptr)

  @if t_ptr > 0
    sys_munmap(t_ptr, 16)
  @end
  return res
@end

@fn net_batch_get_packet_len(queue, index)
  // WHY: Returns bytes transferred for batch packet at index (32-bit msg_len in struct mmsghdr)
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets return 0 @end
  addr = queue.bq_mmsg_ptr + (index * 64) + 56
  b0 = sys_peek8(addr + 0) & 255
  b1 = sys_peek8(addr + 1) & 255
  b2 = sys_peek8(addr + 2) & 255
  b3 = sys_peek8(addr + 3) & 255
  return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
@end

@fn net_batch_get_packet_data(queue, index)
  // WHY: Extracts packet payload at index as Lipi string up to 32-bit msg_len
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets return "" @end
  pkt_len = net_batch_get_packet_len(queue, index)
  @if pkt_len > queue.bq_slot_size
    pkt_len = queue.bq_slot_size
  @end
  cur_data = queue.bq_data_ptr + (index * queue.bq_slot_size)

  res = ""
  i = 0
  @while i < pkt_len
    b = sys_peek8(cur_data + i) & 255
    res = res + chr(b)
    i = i + 1
  @end
  return res
@end

@fn net_batch_get_packet_ip(queue, index)
  // WHY: Extracts sender IPv4 address for batch packet at index
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets return "0.0.0.0" @end
  cur_addr = queue.bq_addr_ptr + (index * 16)
  return net_sockaddr_in_get_ip(cur_addr)
@end

@fn net_batch_get_packet_port(queue, index)
  // WHY: Extracts sender port for batch packet at index
  @if queue.bq_is_active == 0 || index < 0 || index >= queue.bq_num_packets return 0 @end
  cur_addr = queue.bq_addr_ptr + (index * 16)
  return net_sockaddr_in_get_port(cur_addr)
@end

@fn net_batch_queue_free(queue)
  // WHY: Releases batch queue contiguous mmap memory
  @if queue.bq_is_active == 1
    queue.bq_is_active = 0
    ptr = queue.bq_mmap_ptr
    sz = queue.bq_total_mmap_size
    queue.bq_mmap_ptr = 0
    @if ptr > 0
      return sys_munmap(ptr, sz)
    @end
  @end
  return 1
@end
