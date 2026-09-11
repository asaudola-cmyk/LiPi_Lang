@! ============================================================================
@! MAYA TCP SERVER — Real Linux TCP server using syscalls
@! ============================================================================

@struct TcpServer
  ts_fd: i64
  ts_port: i64
  ts_running: i64
@end

@fn tcp_server_new(port)
  fd = net_tcp_socket()
  @if fd < 0
    println("Error: failed to create socket")
    return { ts_fd: -1, ts_port: port, ts_running: 0 }
  @end
  r = net_tcp_bind(fd, port)
  @if r < 0
    println("Error: failed to bind port " + int_to_str(port))
    net_tcp_close(fd)
    return { ts_fd: -1, ts_port: port, ts_running: 0 }
  @end
  net_tcp_listen(fd, 128)
  return { ts_fd: fd, ts_port: port, ts_running: 1 }
@end

@fn tcp_server_accept(server)
  return net_tcp_accept(server.ts_fd)
@end

@fn tcp_server_send(client_fd, data)
  return net_tcp_send(client_fd, data)
@end

@fn tcp_server_recv(client_fd)
  return net_tcp_recv(client_fd, 4096)
@end

@fn tcp_server_close(server)
  net_tcp_close(server.ts_fd)
  server.ts_running = 0
  return server
@end
