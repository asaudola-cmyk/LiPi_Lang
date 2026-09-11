@! ============================================================================
@! ADVERSARIAL LIVE HTTP CLIENT/SERVER STRESS TEST
@! ============================================================================

import "universe/net/http"
import "universe/net/tcp"
import "universe/os/process"
import "universe/os/syscalls"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("🌐 [LIVE HTTP CLIENT-SERVER ADVERSARIAL STRESS]")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  base_pid = process_getpid()
  port = 38000 + (base_pid % 5000)

  @! Start HTTP server in child process
  srv_pid = process_fork()
  @if srv_pid == 0
    listener = tcp_listener_bind("127.0.0.1", port)
    @if listener.fd < 0
      exit(1)
    @end

    @! Handle 5 requests then exit
    req_count = 0
    @while req_count < 5
      stream = tcp_listener_accept(listener)
      @if stream.fd >= 0
        raw_req = tcp_stream_read(stream, 4096)
        @if raw_req.len() > 0
          req = http_parse_request(raw_req)
          
          resp_text = ""
          @if req.path == "/hello"
            resp_text = http_format_response(200, "text/plain", "Hello Maya HTTP!")
          @elif req.path == "/echo"
            resp_text = http_format_response(201, "application/json", req.body)
          @elif req.path == "/notfound"
            resp_text = http_format_response(404, "text/plain", "Route Not Found")
          @elif req.path == "/empty"
            resp_text = http_format_response(204, "", "")
          @else
            resp_text = http_format_response(200, "text/plain", "DEFAULT_RESP_" + req_count.to_str())
          @end

          tcp_stream_write(stream, resp_text)
        @end
        tcp_stream_close(stream)
        req_count = req_count + 1
      @end
    @end

    tcp_close(listener.fd)
    exit(0)
  @end

  @! Allow server socket to bind
  sys_nanosleep(0, 200000000) @! 200ms sleep

  @! Client requests
  url_base = "http://127.0.0.1:" + port.to_str()

  @! Request 1: GET /hello
  r1 = http_get(url_base + "/hello")
  total = total + 1
  @if r1.status_code == 200 && r1.body == "Hello Maya HTTP!"
    passed = passed + 1
    println("  [PASS] HT_LIVE1: GET /hello returned 200 OK with expected payload")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE1: GET /hello failed: status=" + r1.status_code.to_str() + ", body=" + r1.body)
  @end

  @! Request 2: POST /echo
  post_hdrs = [{ name: "Content-Type", value: "application/json" }]
  post_payload = "{\"sender\":\"challenger1\",\"action\":\"test\"}"
  r2 = http_post(url_base + "/echo", post_hdrs, post_payload)
  total = total + 1
  @if r2.status_code == 201 && r2.body == post_payload
    passed = passed + 1
    println("  [PASS] HT_LIVE2: POST /echo returned 201 Created and echoed JSON body intact")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE2: POST /echo failed: status=" + r2.status_code.to_str() + ", body=" + r2.body)
  @end

  @! Request 3: GET /notfound
  r3 = http_get(url_base + "/notfound")
  total = total + 1
  @if r3.status_code == 404 && r3.body == "Route Not Found"
    passed = passed + 1
    println("  [PASS] HT_LIVE3: GET /notfound returned 404 Route Not Found")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE3: GET /notfound failed: status=" + r3.status_code.to_str())
  @end

  @! Request 4: GET /empty (204 No Content)
  r4 = http_get(url_base + "/empty")
  total = total + 1
  @if r4.status_code == 204 && r4.body == ""
    passed = passed + 1
    println("  [PASS] HT_LIVE4: GET /empty returned 204 No Content")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE4: GET /empty failed: status=" + r4.status_code.to_str())
  @end

  @! Request 5: GET /custom
  r5 = http_get(url_base + "/custom")
  total = total + 1
  @if r5.status_code == 200 && r5.body == "DEFAULT_RESP_4"
    passed = passed + 1
    println("  [PASS] HT_LIVE5: GET /custom returned 200 OK with sequential response ID")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE5: GET /custom failed: status=" + r5.status_code.to_str() + ", body=" + r5.body)
  @end

  @! Wait for server process
  srv_st = process_wait(srv_pid)
  srv_ex = (srv_st / 256) & 255

  total = total + 1
  @if srv_ex == 0
    passed = passed + 1
    println("  [PASS] HT_LIVE6: HTTP server process terminated cleanly with exit code 0")
  @else
    failed = failed + 1
    println("  [FAIL] HT_LIVE6: HTTP server process exited with error code: " + srv_ex.to_str())
  @end

  println("=================================================================")
  println("LIVE HTTP SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if failed == 0
    return 0
  @else
    return 1
  @end
@end
