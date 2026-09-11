@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: PURE MAYA TCP SOCKETS (universe/net/tcp)
@! File: tests/universe/test_net_tcp.maya
@! ============================================================================

import "universe/net/tcp"
import "universe/os/process"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/net/tcp (TCP BSD Sockets)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: TCP Socket Creation (tcp_socket_new)
  @! --------------------------------------------------------------------------
  total = total + 1
  server_fd = tcp_socket_new()
  @if server_fd > 0
    passed = passed + 1
    println("  [PASS] Test 1: tcp_socket_new() created socket fd: " + server_fd.to_str())
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: tcp_socket_new() failed with fd: " + server_fd.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Bind Socket to Loopback Address 127.0.0.1 (tcp_bind)
  @! --------------------------------------------------------------------------
  total = total + 1
  my_pid = process_getpid()
  port = 20000 + (my_pid % 10000)
  bind_res = tcp_bind(server_fd, "127.0.0.1", port)
  @if server_fd > 0 && bind_res == 0
    passed = passed + 1
    println("  [PASS] Test 2: tcp_bind(127.0.0.1:" + port.to_str() + ") succeeded")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: tcp_bind failed with code: " + bind_res.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Listen on Bound Socket (tcp_listen)
  @! --------------------------------------------------------------------------
  total = total + 1
  listen_res = tcp_listen(server_fd, 5)
  @if server_fd > 0 && bind_res == 0 && listen_res == 0
    passed = passed + 1
    println("  [PASS] Test 3: tcp_listen(backlog=5) succeeded")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: tcp_listen failed with code: " + listen_res.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: Loopback Ping-Pong Communication (Fork Client & Accept in Server)
  @! --------------------------------------------------------------------------
  total = total + 1
  orig_pid = process_getpid()
  cpid = process_fork()
  @if cpid == 0
    curr_pid = process_getpid()
    @if orig_pid > 0 && curr_pid != orig_pid
      @! Genuine child process: Client
      client_fd = tcp_socket_new()
      conn_res = tcp_connect(client_fd, "127.0.0.1", port)
      @if conn_res == 0
        tcp_send(client_fd, "MAYA_PING")
        resp = tcp_recv(client_fd, 1024)
        tcp_close(client_fd)
        @if resp == "MAYA_PONG"
          exit(0)
        @else
          exit(2)
        @end
      @else
        exit(1)
      @end
    @else
      failed = failed + 1
      println("  [FAIL] Test 4: process_fork stub detected in TCP test")
    @end
  @elif cpid > 0
    @! Parent: Server process accepts incoming connection
    conn_fd = tcp_accept(server_fd)
    @if conn_fd > 0
      req = tcp_recv(conn_fd, 1024)
      @if req == "MAYA_PING"
        tcp_send(conn_fd, "MAYA_PONG")
      @end
      tcp_close(conn_fd)
    @end

    c_status = process_wait(cpid)
    c_exit = (c_status / 256) & 255
    @if c_exit == 0 || c_status == 0
      passed = passed + 1
      println("  [PASS] Test 4: Loopback TCP client-server ping-pong communication verified")
    @else
      failed = failed + 1
      println("  [FAIL] Test 4: Loopback TCP communication failed (child exit: " + c_exit.to_str() + ")")
    @end
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: process_fork failed for TCP client")
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: Close Server Socket (tcp_close)
  @! --------------------------------------------------------------------------
  total = total + 1
  @if server_fd > 0
    close_res = tcp_close(server_fd)
    @if close_res == 0
      passed = passed + 1
      println("  [PASS] Test 5: tcp_close() released server socket fd")
    @else
      failed = failed + 1
      println("  [FAIL] Test 5: tcp_close failed with code: " + close_res.to_str())
    @end
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: Invalid socket fd for tcp_close")
  @end

  println("-----------------------------------------------------------------")
  println("TCP Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/net/tcp E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/net/tcp E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
