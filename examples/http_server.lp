import "universe/net/tcp_server"

@fn parse_method(request)
  i = 0
  @while i < str_len(request)
    c = char_at(request, i)
    @if c == 32
      return str_substr(request, 0, i)
    @end
    i = i + 1
  @end
  return "GET"
@end

@fn parse_path(request)
  @! Find first space (end of method)
  i = 0
  @while i < str_len(request)
    @if char_at(request, i) == 32
      i = i + 1
      j = i
      @while j < str_len(request)
        @if char_at(request, j) == 32
          return str_substr(request, i, j)
        @end
        j = j + 1
      @end
      return str_substr(request, i, str_len(request))
    @end
    i = i + 1
  @end
  return "/"
@end

@fn http_response(status, content_type, body)
  header = "HTTP/1.1 " + status + "\r\n"
  header = header + "Content-Type: " + content_type + "\r\n"
  header = header + "Content-Length: " + int_to_str(str_len(body)) + "\r\n"
  header = header + "Connection: close\r\n"
  header = header + "Server: Lipi/2.0\r\n"
  header = header + "\r\n"
  return header + body
@end

@fn handle_request(path)
  @if path == "/"
    body = "<!DOCTYPE html><html><head><title>Lipi HTTP Server</title></head>"
    body = body + "<body><h1>Lipi is the Universe</h1>"
    body = body + "<p>This HTTP server is written entirely in Lipi.</p>"
    body = body + "<p>Maya karo help ney na - Maya r help sobai ney. Even C.</p>"
    body = body + "<ul><li><a href='/api/status'>/api/status</a></li>"
    body = body + "<li><a href='/api/version'>/api/version</a></li>"
    body = body + "<li><a href='/hello'>/hello</a></li></ul>"
    body = body + "</body></html>"
    return http_response("200 OK", "text/html", body)
  @end
  @if path == "/api/status"
    body = "{\"status\": \"ok\", \"lang\": \"maya\", \"version\": \"2.0.0\", \"universe\": true}"
    return http_response("200 OK", "application/json", body)
  @end
  @if path == "/api/version"
    body = "{\"name\": \"Maya\", \"version\": \"2.0.0\", \"codename\": \"Universe\", \"modules\": 612}"
    return http_response("200 OK", "application/json", body)
  @end
  @if path == "/hello"
    return http_response("200 OK", "text/plain", "Hello from Lipi! Maya is the Universe.")
  @end
  return http_response("404 Not Found", "text/plain", "Not found: " + path)
@end

@fn main()
  port = 8080
  println("Lipi HTTP Server starting on port " + int_to_str(port) + "...")
  println("Visit: http://localhost:" + int_to_str(port))
  println("Press Ctrl+C to stop")
  println("")
  
  server = tcp_server_new(port)
  
  @if server.ts_fd < 0
    println("Failed to start server")
    return 1
  @end
  
  println("[Lipi HTTP] Listening on 0.0.0.0:" + int_to_str(port))
  
  requests = 0
  @while server.ts_running == 1
    client_fd = tcp_server_accept(server)
    @if client_fd < 0
      println("accept error, retrying...")
    @else
      request = tcp_server_recv(client_fd)
      
      @if str_len(request) > 0
        method = parse_method(request)
        path = parse_path(request)
        requests = requests + 1
        
        println("[" + int_to_str(requests) + "] " + method + " " + path)
        
        response = handle_request(path)
        tcp_server_send(client_fd, response)
      @end
      
      net_tcp_close(client_fd)
    @end
  @end
  
  server = tcp_server_close(server)
  return 0
@end
