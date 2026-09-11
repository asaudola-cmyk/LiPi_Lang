@! ============================================================================
@! ADVERSARIAL STRESS TEST: PURE MAYA TCP NETWORKING (test_adv_net_tcp.maya)
@! Tests:
@! 1. Rapid sequential connect/send/recv/close cycles over loopback (30 cycles)
@! 2. Concurrent socket lifecycles with multiple child worker processes
@! 3. Empty payload transmission and stream synchronization
@! 4. Large 4KB payload transmission, buffering, and echo verification
@! 5. Socket error resilience (unbound port connect, negative fds, close idempotency)
@! 6. Object-Oriented TcpListener and TcpStream lifecycle stress
@! ============================================================================

import "universe/net/tcp"
import "universe/os/process"
import "universe/os/syscalls"
import "universe/core/string"

@fn build_deterministic_payload(target_len)
  pattern = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#"
  pat_len = pattern.len()
  res = ""
  i = 0
  @while res.len() < target_len
    rem = target_len - res.len()
    @if rem >= pat_len
      res = res + pattern
    @else
      res = res + str_substr(pattern, 0, rem)
    @end
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [ADVERSARIAL STRESS SUITE] universe/net/tcp")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  base_pid = process_getpid()
  port = 30000 + (base_pid % 10000)

  @! --------------------------------------------------------------------------
  @! SECTION 1: Error & Negative FD Resilience
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Error & Boundary Resilience")

  total = total + 1
  closed_send = tcp_send(-1, "TEST")
  @if closed_send < 0
    passed = passed + 1
    println("  [PASS] TC1.1: tcp_send on negative fd (-1) gracefully returns negative code: " + closed_send.to_str())
  @else
    failed = failed + 1
    println("  [FAIL] TC1.1: tcp_send on negative fd did not return error: " + closed_send.to_str())
  @end

  total = total + 1
  closed_recv = tcp_recv(-1, 1024)
  @if closed_recv == ""
    passed = passed + 1
    println("  [PASS] TC1.2: tcp_recv on negative fd returns empty string")
  @else
    failed = failed + 1
    println("  [FAIL] TC1.2: tcp_recv on negative fd returned non-empty")
  @end

  total = total + 1
  closed_close = tcp_close(-1)
  @if closed_close < 0
    passed = passed + 1
    println("  [PASS] TC1.3: tcp_close on negative fd returns negative error")
  @else
    failed = failed + 1
    println("  [FAIL] TC1.3: tcp_close on negative fd returned non-negative: " + closed_close.to_str())
  @end

  total = total + 1
  unused_fd = tcp_socket_new()
  unconn_res = tcp_connect(unused_fd, "127.0.0.1", 59998)
  tcp_close(unused_fd)
  @if unconn_res < 0
    passed = passed + 1
    println("  [PASS] TC1.4: tcp_connect to closed port 59998 failed safely (code: " + unconn_res.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] TC1.4: tcp_connect to closed port unexpectedly succeeded: " + unconn_res.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Empty Payload Transmission & Synchronization
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Empty Payload & Zero-Byte Boundary")

  server_fd = tcp_socket_new()
  tcp_bind(server_fd, "127.0.0.1", port)
  tcp_listen(server_fd, 10)

  cpid = process_fork()
  @if cpid == 0
    @! Child client
    client_fd = tcp_socket_new()
    conn_res = tcp_connect(client_fd, "127.0.0.1", port)
    @if conn_res != 0
      exit(10)
    @end

    @! 1. Send empty payload
    s0 = tcp_send(client_fd, "")
    @if s0 != 0
      tcp_close(client_fd)
      exit(11)
    @end

    @! 2. Follow with actual payload to verify stream is not corrupted
    s1 = tcp_send(client_fd, "POST_EMPTY_SYNC")
    resp = tcp_recv(client_fd, 1024)
    tcp_close(client_fd)
    @if resp == "ACK_EMPTY_SYNC"
      exit(0)
    @else
      exit(12)
    @end
  @elif cpid > 0
    @! Server
    conn_fd = tcp_accept(server_fd)
    @if conn_fd > 0
      msg = tcp_recv(conn_fd, 1024)
      @if msg == "POST_EMPTY_SYNC"
        tcp_send(conn_fd, "ACK_EMPTY_SYNC")
      @end
      tcp_close(conn_fd)
    @end

    c_status = process_wait(cpid)
    c_exit = (c_status / 256) & 255

    total = total + 1
    @if c_exit == 0
      passed = passed + 1
      println("  [PASS] TC2.1: Empty payload transmission handled with zero-byte return and stream intact")
    @else
      failed = failed + 1
      println("  [FAIL] TC2.1: Empty payload test failed with child exit code: " + c_exit.to_str())
    @end
  @end

  tcp_close(server_fd)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Rapid Sequential Cycles (30 Cycles over Loopback)
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Rapid Sequential Connect/Send/Recv/Close Cycles (30 Cycles)")

  port_seq = port + 1
  server_seq_fd = tcp_socket_new()
  tcp_bind(server_seq_fd, "127.0.0.1", port_seq)
  tcp_listen(server_seq_fd, 32)

  seq_pid = process_fork()
  @if seq_pid == 0
    @! Child sequential client
    k = 0
    client_fails = 0
    @while k < 30
      cfd = tcp_socket_new()
      c_res = tcp_connect(cfd, "127.0.0.1", port_seq)
      @if c_res != 0
        client_fails = client_fails + 1
      @else
        req_msg = "CYC_REQ_" + k.to_str()
        tcp_send(cfd, req_msg)
        resp_msg = tcp_recv(cfd, 128)
        expected_resp = "CYC_ACK_" + k.to_str()
        @if resp_msg != expected_resp
          client_fails = client_fails + 1
        @end
        tcp_close(cfd)
      @end
      k = k + 1
    @end

    @if client_fails == 0
      exit(0)
    @else
      exit(client_fails)
    @end
  @elif seq_pid > 0
    @! Server accepting 30 sequential cycles
    s_idx = 0
    server_fails = 0
    @while s_idx < 30
      client_conn = tcp_accept(server_seq_fd)
      @if client_conn < 0
        server_fails = server_fails + 1
      @else
        req_data = tcp_recv(client_conn, 128)
        expected_req = "CYC_REQ_" + s_idx.to_str()
        @if req_data == expected_req
          tcp_send(client_conn, "CYC_ACK_" + s_idx.to_str())
        @else
          server_fails = server_fails + 1
        @end
        tcp_close(client_conn)
      @end
      s_idx = s_idx + 1
    @end

    c_stat = process_wait(seq_pid)
    child_exit = (c_stat / 256) & 255

    total = total + 1
    @if child_exit == 0 && server_fails == 0
      passed = passed + 1
      println("  [PASS] TC3.1: 30 consecutive rapid TCP connect/send/recv/close cycles passed flawlessly")
    @else
      failed = failed + 1
      println("  [FAIL] TC3.1: Sequential cycles failed (child exit: " + child_exit.to_str() + ", server fails: " + server_fails.to_str() + ")")
    @end
  @end

  tcp_close(server_seq_fd)

  @! --------------------------------------------------------------------------
  @! SECTION 4: Concurrent Sockets with Multiple Processes
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Concurrent Multi-Process Sockets (3 Concurrent Workers)")

  port_conc = port + 2
  srv_conc = tcp_socket_new()
  tcp_bind(srv_conc, "127.0.0.1", port_conc)
  tcp_listen(srv_conc, 16)

  w1_pid = process_fork()
  @if w1_pid == 0
    wfd = tcp_socket_new()
    @if tcp_connect(wfd, "127.0.0.1", port_conc) == 0
      tcp_send(wfd, "WORKER_1_PAYLOAD")
      r = tcp_recv(wfd, 64)
      tcp_close(wfd)
      @if r == "ACK_WORKER_1" exit(0) @else exit(1) @end
    @end
    exit(2)
  @end

  w2_pid = process_fork()
  @if w2_pid == 0
    wfd = tcp_socket_new()
    @if tcp_connect(wfd, "127.0.0.1", port_conc) == 0
      tcp_send(wfd, "WORKER_2_PAYLOAD")
      r = tcp_recv(wfd, 64)
      tcp_close(wfd)
      @if r == "ACK_WORKER_2" exit(0) @else exit(1) @end
    @end
    exit(2)
  @end

  w3_pid = process_fork()
  @if w3_pid == 0
    wfd = tcp_socket_new()
    @if tcp_connect(wfd, "127.0.0.1", port_conc) == 0
      tcp_send(wfd, "WORKER_3_PAYLOAD")
      r = tcp_recv(wfd, 64)
      tcp_close(wfd)
      @if r == "ACK_WORKER_3" exit(0) @else exit(1) @end
    @end
    exit(2)
  @end

  @! Server accepts 3 connections
  c_served = 0
  w_fails = 0
  @while c_served < 3
    cfd = tcp_accept(srv_conc)
    @if cfd > 0
      p = tcp_recv(cfd, 64)
      @if p == "WORKER_1_PAYLOAD"
        tcp_send(cfd, "ACK_WORKER_1")
      @elif p == "WORKER_2_PAYLOAD"
        tcp_send(cfd, "ACK_WORKER_2")
      @elif p == "WORKER_3_PAYLOAD"
        tcp_send(cfd, "ACK_WORKER_3")
      @else
        w_fails = w_fails + 1
      @end
      tcp_close(cfd)
    @else
      w_fails = w_fails + 1
    @end
    c_served = c_served + 1
  @end

  st1 = process_wait(w1_pid)
  st2 = process_wait(w2_pid)
  st3 = process_wait(w3_pid)
  ex1 = (st1 / 256) & 255
  ex2 = (st2 / 256) & 255
  ex3 = (st3 / 256) & 255

  total = total + 1
  @if ex1 == 0 && ex2 == 0 && ex3 == 0 && w_fails == 0
    passed = passed + 1
    println("  [PASS] TC4.1: 3 concurrent worker processes successfully multiplexed over TCP")
  @else
    failed = failed + 1
    println("  [FAIL] TC4.1: Concurrent workers failed (exits: " + ex1.to_str() + ", " + ex2.to_str() + ", " + ex3.to_str() + ")")
  @end

  tcp_close(srv_conc)

  @! --------------------------------------------------------------------------
  @! SECTION 5: Large 4KB Payload Transmission & Invariant
  @! --------------------------------------------------------------------------
  println("▶ Section 5: Large 4096-Byte (4KB) Payload Transmission")

  port_large = port + 3
  srv_large = tcp_socket_new()
  tcp_bind(srv_large, "127.0.0.1", port_large)
  tcp_listen(srv_large, 5)

  large_payload = build_deterministic_payload(4096)

  lpid = process_fork()
  @if lpid == 0
    cfd = tcp_socket_new()
    @if tcp_connect(cfd, "127.0.0.1", port_large) != 0
      exit(20)
    @end

    sent_bytes = tcp_send(cfd, large_payload)
    @if sent_bytes != 4096
      tcp_close(cfd)
      exit(21)
    @end

    received_echo = ""
    @while received_echo.len() < 4096
      chunk = tcp_recv(cfd, 4096)
      @if chunk == "" || chunk.len() == 0
        break
      @end
      received_echo = received_echo + chunk
    @end

    tcp_close(cfd)

    @if received_echo.len() == 4096 && received_echo == large_payload
      exit(0)
    @else
      exit(22)
    @end
  @elif lpid > 0
    conn_fd = tcp_accept(srv_large)
    @if conn_fd > 0
      srv_buf = ""
      @while srv_buf.len() < 4096
        chunk = tcp_recv(conn_fd, 4096)
        @if chunk == "" || chunk.len() == 0
          break
        @end
        srv_buf = srv_buf + chunk
      @end

      @if srv_buf.len() == 4096 && srv_buf == large_payload
        tcp_send(conn_fd, srv_buf)
      @end
      tcp_close(conn_fd)
    @end

    lst = process_wait(lpid)
    lex = (lst / 256) & 255

    total = total + 1
    @if lex == 0
      passed = passed + 1
      println("  [PASS] TC5.1: 4096-byte (4KB) payload transmitted, buffered, and echoed byte-for-byte")
    @else
      failed = failed + 1
      println("  [FAIL] TC5.1: 4KB payload transmission failed (child exit: " + lex.to_str() + ")")
    @end
  @end

  tcp_close(srv_large)

  @! --------------------------------------------------------------------------
  @! SECTION 6: High-Level TcpListener & TcpStream Abstraction
  @! --------------------------------------------------------------------------
  println("▶ Section 6: High-Level TcpListener & TcpStream")

  port_hl = port + 4
  listener = tcp_listener_bind("127.0.0.1", port_hl)

  total = total + 1
  @if listener.fd > 0 && listener.error == ""
    passed = passed + 1
    println("  [PASS] TC6.1: tcp_listener_bind succeeded on fd: " + listener.fd.to_str())
  @else
    failed = failed + 1
    println("  [FAIL] TC6.1: tcp_listener_bind failed with error: " + listener.error)
  @end

  hl_pid = process_fork()
  @if hl_pid == 0
    stream = tcp_stream_connect("127.0.0.1", port_hl)
    @if stream.fd > 0 && stream.error == ""
      tcp_stream_write(stream, "MAYA_STREAM_MSG")
      resp = tcp_stream_read(stream, 1024)
      tcp_stream_close(stream)
      @if resp == "MAYA_STREAM_ACK"
        exit(0)
      @else
        exit(31)
      @end
    @else
      exit(30)
    @end
  @elif hl_pid > 0
    client_stream = tcp_listener_accept(listener)
    @if client_stream.fd > 0
      in_msg = tcp_recv(client_stream.fd, 1024)
      @if in_msg == "MAYA_STREAM_MSG"
        tcp_send(client_stream.fd, "MAYA_STREAM_ACK")
      @end
      tcp_close(client_stream.fd)
    @end

    hl_st = process_wait(hl_pid)
    hl_ex = (hl_st / 256) & 255

    total = total + 1
    @if hl_ex == 0
      passed = passed + 1
      println("  [PASS] TC6.2: High-level TcpListener and TcpStream client-server handshake verified")
    @else
      failed = failed + 1
      println("  [FAIL] TC6.2: High-level stream test failed (child exit: " + hl_ex.to_str() + ")")
    @end
  @end

  tcp_close(listener.fd)

  @! --------------------------------------------------------------------------
  @! Summary
  @! --------------------------------------------------------------------------
  println("=================================================================")
  println("ADVERSARIAL TCP SUITE SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if failed == 0
    println("✓ ALL TCP ADVERSARIAL TESTS PASSED")
    return 0
  @else
    println("✗ SOME TCP ADVERSARIAL TESTS FAILED (" + failed.to_str() + " failures)")
    return 1
  @end
@end
