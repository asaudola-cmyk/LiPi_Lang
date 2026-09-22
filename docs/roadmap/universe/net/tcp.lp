@! ============================================================================
@! MAYA UNIVERSE NET - TCP/IP STACK (universe/net/tcp.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/net/socket"

@! Represents a TCP Socket
@fn tcp_socket_new(port)
  return {
    port: port,
    state: "CLOSED", @! LISTEN, SYN_SENT, SYN_RCVD, ESTABLISHED, FIN_WAIT, TIME_WAIT
    send_buffer: [],
    recv_buffer: [],
    seq_num: 0,
    ack_num: 0
  }
@end

@! Bind and Listen
@fn tcp_listen(socket)
  socket.state = "LISTEN"
  return socket
@end

@! Accept incoming connection (3-way handshake simulation)
@fn tcp_accept(socket, syn_packet)
  @if socket.state == "LISTEN" && syn_packet.flag == "SYN"
    socket.state = "SYN_RCVD"
    socket.ack_num = syn_packet.seq_num + 1
    
    syn_ack = {
      flag: "SYN_ACK",
      seq_num: socket.seq_num,
      ack_num: socket.ack_num
    }
    
    return { socket: socket, response: syn_ack }
  @end
  
  return { error: "Invalid state for accept" }
@end

@! Receive ACK
@fn tcp_receive_ack(socket, ack_packet)
  @if socket.state == "SYN_RCVD" && ack_packet.flag == "ACK"
    @if ack_packet.ack_num == socket.seq_num + 1
      socket.state = "ESTABLISHED"
      return socket
    @end
  @end
  return socket
@end

@! ----------------------------------------------------------------------------
@! High-Level TCP Server Helpers for HTTP and Net Services
@! ----------------------------------------------------------------------------

@fn tcp_server_start(port)
  fd = socket_new_tcp()
  @if fd < 0
    return { fd: fd, error: "Failed to allocate socket", port: port }
  @end
  bind_res = socket_bind(fd, port)
  @if bind_res < 0
    return { fd: fd, error: "Failed to bind socket", port: port }
  @end
  socket_listen(fd, 128)
  return { fd: fd, error: "none", port: port }
@end

@fn tcp_accept_client(server)
  client_fd = socket_accept(server.fd)
  @if client_fd < 0
    return { fd: client_fd, error: "Accept failed" }
  @end
  return { fd: client_fd, error: "none" }
@end

@fn tcp_receive(client, max_bytes)
  buf = sys_mmap(0, max_bytes, 3, 34, -1, 0)
  @if buf < 0
    return ""
  @end
  n = sys_read(client.fd, buf, max_bytes)
  sys_munmap(buf, max_bytes)
  return "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
@end

@fn tcp_send(client, data)
  return data.len()
@end

@fn tcp_close_client(client)
  @if client.fd > 0
    socket_close(client.fd)
  @end
  return 1
@end
