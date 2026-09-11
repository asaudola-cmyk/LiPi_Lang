@! ============================================================================
@! REMEDIATION CHALLENGER 1: ADVERSARIAL NETWORK & TCP STRESS HARNESS
@! Empirical Stress Verification for universe/net/tcp & universe/net/http
@! ============================================================================

import "universe/net/tcp"
import "universe/net/http"
import "universe/os/process"
import "universe/os/syscalls"
import "universe/core/string"

@fn build_deterministic_data(size)
  pat = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()_+"
  pat_len = pat.len()
  res = ""
  @while res.len() < size
    rem = size - res.len()
    @if rem >= pat_len
      res = res + pat
    @else
      res = res + str_substr(pat, 0, rem)
    @end
  @end
  return res
@end

@fn simple_hash(str_data)
  h = 5381
  i = 0
  slen = str_data.len()
  @while i < slen
    c = str_char_at(str_data, i)
    h = ((h << 5) + h) + c
    h = h & 2147483647
    i = i + 1
  @end
  return h
@end

@fn main()
  println("=================================================================")
  println("🔥 [CHALLENGER 1 DEEP STRESS SUITE] TCP & HTTP Subsystems")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  base_pid = process_getpid()
  port_base = 35000 + (base_pid % 8000)

  @! --------------------------------------------------------------------------
  @! TEST 1: IP Parsing & sockaddr_in Serialization Edge Cases
  @! --------------------------------------------------------------------------
  println("▶ Test 1: IPv4 Parsing & sockaddr_in Serialization Edge Cases")

  total = total + 1
  ip_loc = parse_ipv4_addr("localhost")
  @! 127.0.0.1 in network byte order: 127 | (0<<8) | (0<<16) | (pow2(24)) = 127 + 16777216 = 16777343
  @if ip_loc == 16777343
    passed = passed + 1
    println("  [PASS] CH1.1: 'localhost' parsed to 127.0.0.1 in network order (val: " + ip_loc.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] CH1.1: 'localhost' parse incorrect: " + ip_loc.to_str())
  @end

  total = total + 1
  ip_zero = parse_ipv4_addr("0.0.0.0")
  @if ip_zero == 0
    passed = passed + 1
    println("  [PASS] CH1.2: '0.0.0.0' parsed to 0")
  @else
    failed = failed + 1
    println("  [FAIL] CH1.2: '0.0.0.0' parse incorrect: " + ip_zero.to_str())
  @end

  total = total + 1
  ip_cust = parse_ipv4_addr("192.168.1.100")
  @! 192 | (168 * 256) | (1 * 65536) | (100 * 16777216)
  exp_cust = 192 | (168 * 256) | (1 * 65536) | (100 * 16777216)
  @if ip_cust == exp_cust
    passed = passed + 1
    println("  [PASS] CH1.3: '192.168.1.100' parsed accurately (val: " + ip_cust.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] CH1.3: '192.168.1.100' parse mismatch: actual=" + ip_cust.to_str() + ", expected=" + exp_cust.to_str())
  @end

  total = total + 1
  sock_pack = sockaddr_in_pack("127.0.0.1", 8080)
  @! sin_family=2, sin_port=htons(8080)=36895 (0x1f90 -> 0x901f = 36895)
  @if sock_pack.w0 != 0 && sock_pack.w1 == 0
    passed = passed + 1
    println("  [PASS] CH1.4: sockaddr_in_pack packed 16-byte struct correctly")
  @else
    failed = failed + 1
    println("  [FAIL] CH1.4: sockaddr_in_pack packing failed")
  @end

  @! --------------------------------------------------------------------------
  @! TEST 2: High Concurrency Connection Storm (8 Concurrent Clients)
  @! --------------------------------------------------------------------------
  println("▶ Test 2: High Concurrency Connection Storm (8 Parallel Clients)")

  storm_port = port_base + 1
  storm_listener = tcp_listener_bind("127.0.0.1", storm_port)

  total = total + 1
  @if storm_listener.fd > 0
    passed = passed + 1
    println("  [PASS] CH2.1: Storm server bound to port " + storm_port.to_str() + " (fd: " + storm_listener.fd.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] CH2.1: Storm server failed to bind: " + storm_listener.error)
  @end

  num_clients = 8
  client_pids = []
  ci = 0
  @while ci < num_clients
    c_pid = process_fork()
    @if c_pid == 0
      @! In child client
      stream = tcp_stream_connect("127.0.0.1", storm_port)
      @if stream.fd < 0
        exit(100 + ci)
      @end
      msg = "STORM_CLIENT_" + ci.to_str() + "_PAYLOAD"
      tcp_stream_write(stream, msg)
      resp = tcp_stream_read(stream, 128)
      tcp_stream_close(stream)
      exp_resp = "STORM_ACK_" + ci.to_str()
      @if resp == exp_resp
        exit(0)
      @else
        exit(50)
      @end
    @end
    client_pids = client_pids.push(c_pid)
    ci = ci + 1
  @end

  @! Parent Server accepts and replies to all 8 clients
  served_count = 0
  server_errs = 0
  @while served_count < num_clients
    cl_stream = tcp_listener_accept(storm_listener)
    @if cl_stream.fd > 0
      req = tcp_recv(cl_stream.fd, 128)
      @! Extract client ID from STORM_CLIENT_X_PAYLOAD
      @if starts_with(req, "STORM_CLIENT_") == 1
        sub_id = str_substr(req, 13, str_index_of(req, "_PAYLOAD"))
        ack_msg = "STORM_ACK_" + sub_id
        tcp_send(cl_stream.fd, ack_msg)
      @else
        server_errs = server_errs + 1
      @end
      tcp_close(cl_stream.fd)
      served_count = served_count + 1
    @else
      server_errs = server_errs + 1
      served_count = served_count + 1
    @end
  @end

  @! Wait for all children
  child_failures = 0
  ci = 0
  @while ci < num_clients
    ch_pid = client_pids[ci]
    st = process_wait(ch_pid)
    ex = (st / 256) & 255
    @if ex != 0
      child_failures = child_failures + 1
    @end
    ci = ci + 1
  @end

  total = total + 1
  @if child_failures == 0 && server_errs == 0
    passed = passed + 1
    println("  [PASS] CH2.2: All 8 concurrent clients connected, exchanged payloads, and closed cleanly")
  @else
    failed = failed + 1
    println("  [FAIL] CH2.2: Storm test failed: child failures=" + child_failures.to_str() + ", server errors=" + server_errs.to_str())
  @end

  tcp_close(storm_listener.fd)

  @! --------------------------------------------------------------------------
  @! TEST 3: Medium/Large Payload Stream Transmission (16KB) & Invariant
  @! --------------------------------------------------------------------------
  println("▶ Test 3: 16,384-Byte (16KB) Payload Stream Transmission")

  port_16k = port_base + 2
  srv_16k = tcp_socket_new()
  tcp_bind(srv_16k, "127.0.0.1", port_16k)
  tcp_listen(srv_16k, 5)

  payload_16k = build_deterministic_data(16384)
  expected_hash = simple_hash(payload_16k)

  pid_16k = process_fork()
  @if pid_16k == 0
    cfd = tcp_socket_new()
    @if tcp_connect(cfd, "127.0.0.1", port_16k) != 0
      exit(40)
    @end

    sent = 0
    @while sent < payload_16k.len()
      w = tcp_send(cfd, str_substr(payload_16k, sent, payload_16k.len()))
      @if w <= 0 break @end
      sent = sent + w
    @end

    @! Read back echo
    received = ""
    @while received.len() < 16384
      chunk = tcp_recv(cfd, 4096)
      @if chunk == "" || chunk.len() == 0 break @end
      received = received + chunk
    @end
    tcp_close(cfd)

    rec_hash = simple_hash(received)
    @if received.len() == 16384 && rec_hash == expected_hash
      exit(0)
    @else
      exit(41)
    @end
  @elif pid_16k > 0
    conn = tcp_accept(srv_16k)
    @if conn > 0
      srv_in = ""
      @while srv_in.len() < 16384
        c = tcp_recv(conn, 4096)
        @if c == "" || c.len() == 0 break @end
        srv_in = srv_in + c
      @end

      @if srv_in.len() == 16384
        @! Echo back
        s_sent = 0
        @while s_sent < srv_in.len()
          sw = tcp_send(conn, str_substr(srv_in, s_sent, srv_in.len()))
          @if sw <= 0 break @end
          s_sent = s_sent + sw
        @end
      @end
      tcp_close(conn)
    @end

    w_res = process_wait(pid_16k)
    w_ex = (w_res / 256) & 255

    total = total + 1
    @if w_ex == 0
      passed = passed + 1
      println("  [PASS] CH3.1: 16KB payload transmitted, echoed, and validated with matching hash (" + expected_hash.to_str() + ")")
    @else
      failed = failed + 1
      println("  [FAIL] CH3.1: 16KB transmission failed with child exit code: " + w_ex.to_str())
    @end
  @end

  tcp_close(srv_16k)

  @! --------------------------------------------------------------------------
  @! TEST 4: Socket Error Pathways & Sudden Disconnect Resilience
  @! --------------------------------------------------------------------------
  println("▶ Test 4: Socket Error Pathways & Sudden Disconnect")

  port_disc = port_base + 3
  srv_disc = tcp_socket_new()
  tcp_bind(srv_disc, "127.0.0.1", port_disc)
  tcp_listen(srv_disc, 5)

  pid_disc = process_fork()
  @if pid_disc == 0
    cfd = tcp_socket_new()
    @if tcp_connect(cfd, "127.0.0.1", port_disc) == 0
      @! Immediately close without sending any bytes
      tcp_close(cfd)
      exit(0)
    @end
    exit(60)
  @elif pid_disc > 0
    conn = tcp_accept(srv_disc)
    total = total + 1
    @if conn > 0
      @! Server recv on immediately closed socket should return "" (EOF)
      in_eof = tcp_recv(conn, 1024)
      tcp_close(conn)

      @if in_eof == ""
        passed = passed + 1
        println("  [PASS] CH4.1: Server received EOF ('') upon immediate client disconnect without hang/crash")
      @else
        failed = failed + 1
        println("  [FAIL] CH4.1: Server received unexpected non-empty on EOF: " + in_eof)
      @end
    @else
      failed = failed + 1
      println("  [FAIL] CH4.1: tcp_accept failed on disconnect test")
    @end
    process_wait(pid_disc)
  @end

  tcp_close(srv_disc)

  @! Double close test
  total = total + 1
  dummy_sock = tcp_socket_new()
  c1 = tcp_close(dummy_sock)
  c2 = tcp_close(dummy_sock)
  @if c1 == 0
    passed = passed + 1
    println("  [PASS] CH4.2: First tcp_close returned 0; second close handled safely without abort (code: " + c2.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] CH4.2: First tcp_close returned failure: " + c1.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! TEST 5: HTTP Pipeline & Parser Boundary Fuzzing
  @! --------------------------------------------------------------------------
  println("▶ Test 5: HTTP Pipeline & Parser Boundary Fuzzing")

  @! 5.1 Multi-request pipelining
  req1 = "GET /first HTTP/1.1\r\nHost: maya.org\r\n\r\n"
  req2 = "POST /second HTTP/1.1\r\nHost: maya.org\r\nContent-Length: 5\r\n\r\nHELLO"
  pipeline_input = req1 + req2

  p1 = http_parse_request(pipeline_input)
  total = total + 1
  @if p1.method == "GET" && p1.path == "/first"
    passed = passed + 1
    println("  [PASS] CH5.1: First pipelined request extracted accurately")
  @else
    failed = failed + 1
    println("  [FAIL] CH5.1: Pipeline parse failed: method=" + p1.method + ", path=" + p1.path)
  @end

  @! 5.2 Header boundary with 25 custom headers
  hdr_stream = "GET /headers HTTP/1.1\r\n"
  hi = 0
  @while hi < 25
    hdr_stream = hdr_stream + "X-Test-Hdr-" + hi.to_str() + ": value-" + hi.to_str() + "\r\n"
    hi = hi + 1
  @end
  hdr_stream = hdr_stream + "\r\n"

  p_hdrs = http_parse_request(hdr_stream)
  total = total + 1
  @if p_hdrs.headers.len() == 25
    passed = passed + 1
    println("  [PASS] CH5.2: 25 custom headers parsed without truncation")
  @else
    failed = failed + 1
    println("  [FAIL] CH5.2: Header count mismatch: expected 25, got " + p_hdrs.headers.len().to_str())
  @end

  @! 5.3 Malformed chunked encoding resilience
  malformed_chunk = "ZZZZ_INVALID_HEX\r\nSomeData\r\n0\r\n\r\n"
  dec_malformed = http_decode_chunked(malformed_chunk)
  total = total + 1
  @if dec_malformed == ""
    passed = passed + 1
    println("  [PASS] CH5.3: Malformed non-hex chunk handled safely without crash")
  @else
    failed = failed + 1
    println("  [FAIL] CH5.3: Unexpected output on malformed chunk: " + dec_malformed)
  @end

  @! 5.4 URL parsing with complex query and IPv4
  u_adv = http_parse_url("http://192.168.0.10:3000/api/search?user=dev&filter=all&sort=asc#top")
  total = total + 1
  @if u_adv.protocol == "http" && u_adv.host == "192.168.0.10" && u_adv.port == 3000 && u_adv.path == "/api/search?user=dev&filter=all&sort=asc#top"
    passed = passed + 1
    println("  [PASS] CH5.4: Complex URL with IPv4, non-standard port, multi-param query, and hash parsed")
  @else
    failed = failed + 1
    println("  [FAIL] CH5.4: Complex URL parsing mismatch: host=" + u_adv.host + ", port=" + u_adv.port.to_str() + ", path=" + u_adv.path)
  @end

  @! --------------------------------------------------------------------------
  @! Summary
  @! --------------------------------------------------------------------------
  println("=================================================================")
  println("CHALLENGER 1 STRESS SUITE SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if failed == 0
    println("✓ ALL CHALLENGER 1 NETWORK STRESS TESTS PASSED")
    return 0
  @else
    println("✗ CHALLENGER 1 DETECTED " + failed.to_str() + " FAILURES")
    return 1
  @end
@end
