@! ============================================================================
@! MAYA NATIVE HTTP/1.1 WEBSERVER
@! Zero Dependencies — Pure Maya Web Stack
@! ============================================================================

import "universe/net/tcp"
import "universe/net/socket"
import "universe/core/string"

@! Starts a blocking HTTP server loop
@fn http_server_serve(port, route_handler_fn)
  server = tcp_server_start(port)
  @if server.error != "none"
    println("HTTP Server Error: " + server.error)
    return 0
  @end
  
  println("🚀 Maya HTTP Server listening on http://0.0.0.0:" + port.to_str())
  
  @while 1 == 1
    client = tcp_accept_client(server)
    @if client.error == "none"
      @! Read raw request
      raw_req = tcp_receive(client, 4096)
      
      @! Parse Request
      @! Format: GET /path HTTP/1.1
      path = "/"
      @if starts_with(raw_req, "GET ") || starts_with(raw_req, "POST ")
        parts = string_split(raw_req, " ")
        @if parts.len() > 1
          path = parts[1]
        @end
      @end
      
      @! Call user route handler
      response_body = route_handler_fn(path)
      
      @! Construct HTTP/1.1 Response
      content_len = response_body.len().to_str()
      
      http_res = "HTTP/1.1 200 OK\r\n"
      http_res = http_res + "Server: Maya Native Server\r\n"
      http_res = http_res + "Content-Type: text/html\r\n"
      http_res = http_res + "Content-Length: " + content_len + "\r\n"
      http_res = http_res + "Connection: close\r\n\r\n"
      http_res = http_res + response_body
      
      @! Send to client
      tcp_send(client, http_res)
      tcp_close_client(client)
    @end
  @end
  return 1
@end

@! High-Concurrency Non-Blocking Epoll HTTP Server
@fn http_server_serve_epoll(port, route_handler_fn)
  server = tcp_server_start(port)
  @if server.error != "none"
    println("HTTP Epoll Server Error: " + server.error)
    return 0
  @end
  
  epfd = epoll_new()
  epoll_add_fd(epfd, server.fd, 1)
  
  println("🚀 Maya Non-Blocking Epoll HTTP Server listening on http://0.0.0.0:" + port.to_str())
  
  @while 1 == 1
    events = epoll_poll(epfd, 32, 1000)
    @if events > 0
      client = tcp_accept_client(server)
      @if client.error == "none"
        raw_req = tcp_receive(client, 4096)
        path = "/"
        @if starts_with(raw_req, "GET ") || starts_with(raw_req, "POST ")
          parts = string_split(raw_req, " ")
          @if parts.len() > 1 path = parts[1] @end
        @end
        response_body = route_handler_fn(path)
        content_len = response_body.len().to_str()
        http_res = "HTTP/1.1 200 OK\r\nServer: Maya-Epoll\r\nContent-Type: text/html\r\nContent-Length: " + content_len + "\r\nConnection: close\r\n\r\n" + response_body
        tcp_send(client, http_res)
        tcp_close_client(client)
      @end
    @end
  @end
  return 1
@end
