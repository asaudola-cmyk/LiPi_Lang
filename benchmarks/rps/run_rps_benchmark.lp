// ==============================================================================
// 👑 PURE LIPI EMPIRICAL HTTP RPS BENCHMARK HARNESS (0% Python / 0% wrk)
// File: benchmarks/rps/run_rps_benchmark.lp
// ⚡ Spawns a live pure-Lipi loopback HTTP/1.1 server and executes real TCP
//    requests, measuring authentic Requests/Sec and average latency.
// ==============================================================================

import "utso/io"
import "utso/string"
import "utso/net/tcp"
import "utso/net/http"

@fn rps_now_ns(ts_buf)
  rc = syscall(228, 1, ts_buf, 0, 0, 0, 0)
  @if rc < 0 return 0 @end
  return mem_read(ts_buf, 0) * 1000000000 + mem_read(ts_buf, 8)
@end

@fn rps_write_file(path, content)
  fd = syscall(2, path, 577, 420, 0, 0, 0)
  @if fd < 0 return 0 @end
  n = str_len(content)
  written = 0
  @while written < n
    w = syscall(1, fd, content + written, n - written, 0, 0, 0)
    @if w <= 0 break @end
    written = written + w
  @end
  syscall(3, fd, 0, 0, 0, 0, 0)
  return 1
@end

@fn main()
  println("======================================================================")
  println("🚀 LIPI SOVEREIGN HTTP/1.1 LOOPBACK RPS BENCHMARK (100% Pure Lipi)")
  println("======================================================================")

  port = 18891
  total_reqs = 200
  listener = tcp_listener_bind("127.0.0.1", port)
  @if listener.tcpl_fd < 0
    println("❌ FAIL: Could not bind loopback benchmark port")
    exit(1)
  @end

  pid = syscall(57, 0, 0, 0, 0, 0, 0)
  @if pid == 0
    served = 0
    resp_wire = http_format_response(200, "text/plain", "Hello, World!")
    @while served < total_reqs
      s = tcp_listener_accept(listener)
      @if s.tcp_fd >= 0
        raw = tcp_stream_read(s, 1024)
        @if str_len(raw) > 0
          tcp_stream_write(s, resp_wire)
        @end
        tcp_stream_close(s)
        served = served + 1
      @end
    @end
    tcp_close(listener.tcpl_fd)
    syscall(60, 0, 0, 0, 0, 0, 0)
  @end

  tcp_close(listener.tcpl_fd)
  ts_buf = lipi_alloc(16)
  t0 = rps_now_ns(ts_buf)
  ok_count = 0
  req_wire = "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"

  i = 0
  @while i < total_reqs
    c = tcp_stream_connect("127.0.0.1", port)
    @if c.tcp_fd >= 0
      tcp_stream_write(c, req_wire)
      resp = tcp_stream_read(c, 1024)
      tcp_stream_close(c)
      @if str_contains(resp, "Hello, World!") == 1
        ok_count = ok_count + 1
      @end
    @end
    i = i + 1
  @end

  t1 = rps_now_ns(ts_buf)
  lipi_free_sized(ts_buf, 16)
  st_buf = lipi_alloc(8)
  syscall(61, pid, st_buf, 0, 0, 0, 0)
  lipi_free_sized(st_buf, 8)

  dt_ns = t1 - t0
  @if dt_ns <= 0 dt_ns = 1 @end
  dt_ms = dt_ns / 1000000
  @if dt_ms <= 0 dt_ms = 1 @end
  rps = (ok_count * 1000000000) / dt_ns
  avg_us = (dt_ns / 1000) / total_reqs

  println("  ✔ Completed Requests : " + to_str(ok_count) + "/" + to_str(total_reqs))
  println("  ✔ Total Elapsed Time : " + to_str(dt_ms) + " ms")
  println("  ✔ Measured Throughput: " + to_str(rps) + " req/sec (single-client sequential loopback)")
  println("  ✔ Average Latency    : " + to_str(avg_us) + " us/req")

  json = "[\n  {\"lang\":\"LiPi\",\"completed\":" + to_str(ok_count) + ",\"rps\":" + to_str(rps) + ",\"avg_latency_us\":" + to_str(avg_us) + "}\n]\n"
  rps_write_file("benchmarks/rps/rps_results.json", json)

  @if ok_count != total_reqs
    println("❌ FAIL: Dropped HTTP requests")
    exit(1)
  @end
  return 0
@end

main()
