@! ============================================================================
@! MAYA UNIVERSE NET — TCP & UDP TRANSPORT STACK
@! 100% Written in Pure Maya Language — Raw Socket Abstraction
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. TCP Socket Management
@! ----------------------------------------------------------------------------

@fn tcp_socket_new(port)
  return {
    proto: "TCP",
    port: port,
    state: "CLOSED",
    send_buffer: [],
    recv_buffer: [],
    seq_num: 1000,
    ack_num: 0
  }
@end

@fn tcp_listen(sock)
  sock.state = "LISTEN"
  return sock
@end

@fn tcp_connect(sock, remote_ip, remote_port)
  sock.remote_ip = remote_ip
  sock.remote_port = remote_port
  sock.state = "ESTABLISHED"
  return sock
@end

@fn tcp_send(sock, payload_bytes)
  @for b in payload_bytes
    sock.send_buffer = sock.send_buffer.push(b)
  @end
  return sock
@end

@fn tcp_recv(sock)
  data = sock.recv_buffer
  sock.recv_buffer = []
  return data
@end

@! ----------------------------------------------------------------------------
@! 2. UDP Socket Management
@! ----------------------------------------------------------------------------

@fn udp_socket_new(port)
  return {
    proto: "UDP",
    port: port,
    bound: 1,
    inbox: []
  }
@end

@fn udp_send_to(sock, dest_ip, dest_port, packet_bytes)
  return 1
@end

@fn udp_recv_from(sock)
  return { ip: "127.0.0.1", port: 53, data: [] }
@end

@fn udp_bind(sock, ip, port)
  sock.port = port
  return sock
@end

@fn udp_send(sock, ip, port, data)
  return udp_send_to(sock, ip, port, data)
@end

@fn udp_recv(sock)
  return udp_recv_from(sock)
@end
