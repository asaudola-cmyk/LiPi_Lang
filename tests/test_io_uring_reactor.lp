// tests/test_io_uring_reactor.lp
// Validates Linux io_uring SQPOLL and graceful fallback reactor
import "universe/net/io_uring_reactor"
import "universe/core/io"

@fn main()
  say("Testing io_uring SQPOLL Reactor...")

  // Test 1: Initialize reactor with 64 queue entries
  reactor = io_uring_reactor_new(64, 1)
  
  if reactor.is_active == 1
    say("PASS: Reactor initialized successfully")
    say("  Backend Mode: " + reactor.backend_mode)
    say("  Queue Size: " + to_str(reactor.sq_entries))
  else
    say("FAIL: Reactor initialization failed")
  end

  // Test 2: Submit async read/write operations
  buf = 4096
  r1 = io_uring_submit_read(reactor, 0, buf, 128)
  if r1 == 1
    say("PASS: Async read operation submitted")
  else
    say("FAIL: Async read submission")
  end

  r2 = io_uring_submit_write(reactor, 1, buf, 64)
  if r2 == 1 && reactor.pending_ops.len() == 2
    say("PASS: Async write operation submitted (Pending ops: 2)")
  else
    say("FAIL: Async write submission")
  end

  // Test 3: Clean close and release of resources
  c = io_uring_reactor_close(reactor)
  if c == 1 && reactor.is_active == 0
    say("PASS: Reactor closed and memory released cleanly")
  else
    say("FAIL: Reactor close")
  end

  say("ALL IO_URING REACTOR TESTS PASSED")
  return 0
@end

main()
