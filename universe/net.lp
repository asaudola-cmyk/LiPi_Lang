// ==============================================================================
// 👑 LIPI UNIVERSE NET — GRAND UMBRELLA PRELUDE (universe/net.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero C | Zero External Tools
// ==============================================================================
//
// WHY: Provides a unified gateway for all networking, socket protocols,
// encryption, and asynchronous I/O engines in pure Lipi.
// Developers can simply write:
//     import "universe/net"
// to access raw POSIX sockets, HTTP/1.1 & HTTP/2, RFC 6455 WebSockets,
// TLS 1.3 cryptographic transport, and Linux io_uring zero-syscall ring buffers.
// ==============================================================================

import "universe/net/socket"
import "universe/net/tcp"
import "universe/net/udp"
import "universe/net/http"
import "universe/net/websocket"
import "universe/net/tls/tls13"
import "universe/net/io_uring_ring"
import "universe/net/lipirpc"

// ── Quick TCP Socket Helper ───────────────────────────────────────────────────
// WHY: Creates an AF_INET (IPv4) streaming socket directly via Linux syscalls.
@fn lipi_socket_tcp_new()
    return sys_socket(2, 1, 0)
@end

@fn লিপি_টিসিপি_সকেট_নতুন()
    return lipi_socket_tcp_new()
@end
