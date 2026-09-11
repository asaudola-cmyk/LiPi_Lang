@! ==================================================================
@! MAYA UNIVERSE - HTTP Server (Phase 14)
@! ==================================================================

@struct HttpRequest
  method
  path
  version
  headers
  body
@end

@struct HttpResponse
  status_code
  status_text
  headers
  body
@end

@fn http_listen(port)
  println("Starting HTTP Server on port...")
  server_fd = net_tcp_listen(port)
  @if server_fd < 0
    println("Failed to bind HTTP server")
    return server_fd
  @end
  
  @while 1 == 1
    client_fd = net_accept(server_fd, 0, 0)
    println("Accepted connection!")
    @if client_fd > 0
      http_handle_client(client_fd)
    @end
  @end
  return 0
@end

@! Extracts characters until a space or \r is found
@fn http_extract_token(buf, start_idx, max_len)
  i = start_idx
  @while i < max_len
    c = sys_peek8(buf + i)
    @if c == 32 return i @end @! Space
    @if c == 13 return i @end @! \r
    @if c == 0 return i @end
    i = i + 1
  @end
  return i
@end

@fn http_parse_request(buf, bytes_read, req)
  method_end = http_extract_token(buf, 0, bytes_read)
  req.method = str_slice(buf, 0, method_end)
  
  path_start = method_end + 1
  path_end = http_extract_token(buf, path_start, bytes_read)
  req.path = str_slice(buf, path_start, path_end)
  
  return 0
@end

@fn http_handle_client(client_fd)
  buf = malloc(4096)
  bytes_read = net_read(client_fd, buf, 4096)
  
  @if bytes_read > 0
    req = malloc(40)
    http_parse_request(buf, bytes_read, req)
    
    println("--- NEW REQUEST ---")
    println(req.method)
    println(req.path)
    
    @if str_eq(req.path, "/") == 1
      file_content = fs_read_all("index.html")
      @if file_content != 0
        headers = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
        full_response = str_concat(headers, file_content)
        net_write(client_fd, full_response, str_len(full_response))
        free(file_content)
        free(full_response)
      @else
        response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n404 - index.html not found\n"
        net_write(client_fd, response, str_len(response))
      @end
    @elif str_eq(req.path, "/api") == 1
      response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"status\": \"success\", \"message\": \"Maya OS File I/O is alive!\"}\n"
      net_write(client_fd, response, str_len(response))
    @else
      response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n404 - Route not found\n"
      net_write(client_fd, response, str_len(response))
    @end
    
    free(req.method)
    free(req.path)
    free(req)
  @end
  
  free(buf)
  net_close(client_fd)
  return 0
@end
