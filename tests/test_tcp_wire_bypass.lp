import "src/runtime/io_uring_bypass"
import "universe/core/net"
import "universe/core/string"
import "universe/os/syscalls"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  ❌ [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " -> Expected " + to_str(expected) + ", got " + to_str(actual))
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  ❌ [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI TCP WIRE BYPASS ENGINE TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  engine = io_uring_bypass_new(64, 0, 32, 2048)
  total_tests = total_tests + 1
  ok_eng = assert_true(engine != 0, "Engine allocated")
  @if ok_eng == 1
    println("  ✔ [PASS] io_uring bypass engine active: " + engine.be_backend_mode)
    passed_tests = passed_tests + 1
  @end

  tcp_port = 29882
  listen_fd = net_tcp_socket()
  net_set_reuseaddr(listen_fd, 1)
  net_tcp_bind(listen_fd, tcp_port)
  net_tcp_listen(listen_fd, 16)

  // Connect client
  client_fd = net_tcp_connect_to("127.0.0.1", tcp_port)
  ok_c = assert_true(client_fd >= 0, "TCP client connected")

  // Accept server connection
  server_conn = net_tcp_accept_endpoint(listen_fd)
  ok_s = assert_true(server_conn.client_fd >= 0, "TCP server accepted connection")
  ok_ip = assert_eq_str(server_conn.client_ip, "127.0.0.1", "Client IP is 127.0.0.1")

  // Test 1: Live transmission via bypass_tcp_send and bypass_tcp_recv
  total_tests = total_tests + 1
  payload = "TCP_WIRE_BYPASS_STREAM_PAYLOAD_12345"
  bytes_sent = bypass_tcp_send(engine, client_fd, payload)
  ok_snd = assert_eq_int(bytes_sent, str_len(payload), "Payload bytes sent via bypass_tcp_send")

  received_str = bypass_tcp_recv(engine, server_conn.client_fd, 1024)
  ok_rcv = assert_eq_str(received_str, payload, "Payload received via bypass_tcp_recv with 100% byte fidelity")

  @if ok_c == 1 && ok_s == 1 && ok_ip == 1 && ok_snd == 1 && ok_rcv == 1
    println("  ✔ [PASS] bypass_tcp_send and bypass_tcp_recv verified over live socket")
    passed_tests = passed_tests + 1
  @end

  // Test 2: Batch stream transmission via bypass_tcp_batch_send
  total_tests = total_tests + 1
  batch_chunks = ["BURST_STREAM_A", "BURST_STREAM_B", "BURST_STREAM_C"]
  batch_sent = bypass_tcp_batch_send(engine, client_fd, batch_chunks)
  ok_bsnd = assert_true(batch_sent >= 1, "Submitted batch packets via bypass_tcp_batch_send")

  // Server reaps the stream burst
  r_chunk1 = bypass_tcp_recv(engine, server_conn.client_fd, 14)
  r_chunk2 = bypass_tcp_recv(engine, server_conn.client_fd, 14)
  r_chunk3 = bypass_tcp_recv(engine, server_conn.client_fd, 14)
  all_received = r_chunk1 + r_chunk2 + r_chunk3
  expected_stream = "BURST_STREAM_ABURST_STREAM_BBURST_STREAM_C"
  ok_brecv = assert_eq_str(all_received, expected_stream, "All stream chunks reaped in exact FIFO sequence")

  @if ok_bsnd == 1 && ok_brecv == 1
    println("  ✔ [PASS] bypass_tcp_batch_send burst stream verified")
    passed_tests = passed_tests + 1
  @end

  // Cleanup
  net_tcp_close(client_fd)
  net_tcp_close(server_conn.client_fd)
  net_tcp_close(listen_fd)
  io_uring_bypass_close(engine)

  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL TCP WIRE BYPASS TESTS PASSED (" + to_str(passed_tests) + "/" + to_str(total_tests) + ") ✔")
    return 0
  @else
    println("❌ TCP WIRE BYPASS TESTS FAILED (" + to_str(passed_tests) + "/" + to_str(total_tests) + ")")
    return 1
  @end
@end

main()
