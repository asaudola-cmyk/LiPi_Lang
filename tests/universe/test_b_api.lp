import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/net"
import "universe/b_core/db"
import "universe/b_core/http"

@fn http_response(fd, status, body)
  h1 = "HTTP/1.1 "
  h2 = "\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
  
  head1 = string_concat(h1, status)
  head2 = string_concat(head1, h2)
  full_resp = string_concat(head2, body)
  
  net_write(fd, full_resp, string_len(full_resp))
  return 0
@end

@fn main()
  string_println("=== Native Maya REST API Server ===")
  db_file = "api_data.mdb"
  
  @! Seed DB
  db_set(db_file, "system", "Maya Universe B API")
  
  sockfd = net_socket()
  @if sockfd < 0 sys_exit(1) @end
  
  optval = sys_mmap(0, 4, 3, 34, 0 - 1, 0)
  sys_poke(optval, 1)
  sys_syscall(54, sockfd, 1, 2, optval, 4, 0)
  
  port = 9090
  res = net_bind(sockfd, port)
  @if res < 0 sys_exit(1) @end
  
  net_listen(sockfd, 10)
  string_println("API Server running on http://127.0.0.1:9090")
  
  @! Process 2 requests before shutting down
  req_count = 0
  @while req_count < 2
    client_fd = net_accept(sockfd)
    @if client_fd >= 0
      buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
      bytes = net_read(client_fd, buf, 4096)
      @if bytes > 0
        sys_poke8(buf + bytes, 0) @! Null terminate
        
        @! Parse Method and Path
        @! Format: GET /some/path HTTP/1.1
        first_space = string_find(buf, " ", 0)
        @if first_space > 0
          second_space = string_find(buf, " ", first_space + 1)
          @if second_space > 0
            path = string_substring(buf, first_space + 1, second_space)
            string_print("Request Path: ") string_println(path)
            
            @! Router logic
            get_prefix = "/get?key="
            set_prefix = "/set?key="
            
            p_get = string_find(path, get_prefix, 0)
            p_set = string_find(path, set_prefix, 0)
            
            @if p_get == 0
              key = string_substring(path, 9, string_len(path))
              val = db_get(db_file, key)
              @if val != 0
                http_response(client_fd, "200 OK", val)
              @else
                http_response(client_fd, "404 Not Found", "Key not found")
              @end
            @elif p_set == 0
              @! Format: /set?key=XXX&val=YYY
              amp = string_find(path, "&val=", 0)
              @if amp > 0
                key = string_substring(path, 9, amp)
                val = string_substring(path, amp + 5, string_len(path))
                db_set(db_file, key, val)
                http_response(client_fd, "200 OK", "OK")
              @else
                http_response(client_fd, "400 Bad Request", "Missing &val=")
              @end
            @else
              http_response(client_fd, "404 Not Found", "Invalid Endpoint")
            @end
          @end
        @end
      @end
      net_close(client_fd)
      req_count = req_count + 1
    @end
  @end
  
  net_close(sockfd)
  string_println("API Server shutting down cleanly.")
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
