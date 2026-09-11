@! ============================================================================
@! MAYA UNIVERSE WEB — SOVEREIGN WEB SERVER CONTAINER (universe/web/server.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! BSD TCP Socket Container, Request Ingestion, Response Serialization, Lifecycle
@! ============================================================================

import "universe/net/tcp"
import "universe/net/http"
import "universe/web/context"
import "universe/web/app"

@! ----------------------------------------------------------------------------
@! 1. Data Structures
@! ----------------------------------------------------------------------------

@struct WebServer
  server_app: 0
  listener: 0
  host: "127.0.0.1"
  port: 8080
  running: 0
  request_count: 0
@end

@! ----------------------------------------------------------------------------
@! 2. Constructor & Connection Handler
@! ----------------------------------------------------------------------------

@fn web_server_new(app)
  return {
    server_app: app,
    listener: 0,
    host: "127.0.0.1",
    port: 8080,
    running: 0,
    request_count: 0
  }
@end

@fn web_server_handle_connection(server, stream)
  raw_req = tcp_stream_read(stream, 4096)
  @if raw_req.len() > 0
    parsed = http_parse_request(raw_req)
    req = req_new(parsed.method, parsed.path, parsed.headers, parsed.body, stream.peer_host)
    res = app_dispatch(server.server_app, req)
    wire_resp = res_format_http(res)
    tcp_stream_write(stream, wire_resp)
  @end
  tcp_stream_close(stream)
@end

@! ----------------------------------------------------------------------------
@! 3. Server Lifecycle Operations
@! ----------------------------------------------------------------------------

@fn web_server_listen(server, host, port)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    println("Failed to bind " + host + ":" + port.to_str())
    return -1
  @end

  server.listener = listener
  server.host = host
  server.port = port
  server.running = 1
  server.request_count = 0

  @while server.running == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      web_server_handle_connection(server, stream)
      server.request_count = server.request_count + 1
    @end
  @end

  tcp_close(listener.fd)
  return 0
@end

@fn web_server_listen_limited(server, host, port, max_requests)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    println("Failed to bind " + host + ":" + port.to_str())
    return -1
  @end

  server.listener = listener
  server.host = host
  server.port = port
  server.running = 1
  server.request_count = 0

  @while server.running == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      web_server_handle_connection(server, stream)
      server.request_count = server.request_count + 1

      @if max_requests > 0 && server.request_count >= max_requests
        server.running = 0
      @end
    @end
  @end

  tcp_close(listener.fd)
  return 0
@end

@fn web_server_stop(server)
  server.running = 0
  @if server.listener != 0
    tcp_close(server.listener.fd)
  @end
@end

@! ----------------------------------------------------------------------------
@! 4. WebApp Convenience Helpers
@! ----------------------------------------------------------------------------

@fn app_listen(app, host, port)
  srv = web_server_new(app)
  return web_server_listen(srv, host, port)
@end

@fn app_listen_limited(app, host, port, max_requests)
  srv = web_server_new(app)
  return web_server_listen_limited(srv, host, port, max_requests)
@end
