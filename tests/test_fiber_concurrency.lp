// ==============================================================================
// 🧪 LIPI REGRESSION TEST: High-Concurrency Fiber Reactor & Ring Channels
// ⚡ Verifies M:N cooperative fiber scheduling, lock-free ring channel communication,
//    and zero-allocation green concurrency (Challenging Go & PHP).
// ==============================================================================

include "universe/core/channel.lp"
include "universe/core/fiber_reactor.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI CONCURRENCY: FIBER REACTOR & RING CHANNELS (Pillar 1) 👑"
say "================================================================="

// ── Test 1: Lock-Free Circular Ring Channel FIFO Verification ─────────────────
say "▶ Test 1: Testing Ring-Buffer Channel Operations..."
ch = channel_new(4)
assert_true(ch > 0, "Channel allocated successfully")
assert_eq(channel_cap(ch), 4, "Channel capacity is 4")
assert_eq(channel_len(ch), 0, "Initial channel length is 0")

// Push 3 items into ring buffer
s1 = channel_send(ch, 100)
s2 = channel_send(ch, 200)
s3 = channel_send(ch, 300)
assert_eq(s1, 1, "Send 100 successful")
assert_eq(s2, 1, "Send 200 successful")
assert_eq(s3, 1, "Send 300 successful")
assert_eq(channel_len(ch), 3, "Channel length is now 3")

// Pop items and verify FIFO ordering
v1 = channel_recv(ch)
v2 = channel_recv(ch)
assert_eq(v1, 100, "First received item is 100 (FIFO)")
assert_eq(v2, 200, "Second received item is 200 (FIFO)")
assert_eq(channel_len(ch), 1, "Channel length after 2 pops is 1")

// Push 2 more items across ring boundary
s4 = channel_send(ch, 400)
s5 = channel_send(ch, 500)
assert_eq(s4, 1, "Send 400 across ring boundary")
assert_eq(s5, 1, "Send 500 across ring boundary")

v3 = channel_recv(ch)
v4 = channel_recv(ch)
v5 = channel_recv(ch)
assert_eq(v3, 300, "Third received item is 300")
assert_eq(v4, 400, "Fourth received item is 400")
assert_eq(v5, 500, "Fifth received item is 500")
assert_eq(channel_len(ch), 0, "Channel drained completely")

channel_close(ch)
channel_free(ch)

// ── Test 2: Cooperative Fiber Reactor Multi-Task Scheduling ───────────────────
say "\n▶ Test 2: Spawning & Scheduling Cooperative Fibers..."
reactor = reactor_new(16)
assert_true(reactor > 0, "Fiber Reactor allocated successfully")

// Create a pipe channel between producer and consumer
pipe_ch = channel_new(8)
result_ch = channel_new(8)

// Spawn Producer Fiber (Task Type 1: Increments counter to 5 and pushes to pipe_ch)
f_prod = reactor_spawn(reactor, 1, 5, 0, pipe_ch)
assert_true(f_prod > 0, "Producer fiber spawned")

// Spawn Consumer Fiber (Task Type 2: Reads from pipe_ch, multiplies by 10, writes to result_ch)
f_cons = reactor_spawn(reactor, 2, 10, pipe_ch, result_ch)
assert_true(f_cons > 0, "Consumer fiber spawned")

// Initial active count is 2
assert_eq(reactor_active_count(reactor), 2, "Active fibers count is 2")

// Run the reactor to drain all fibers cooperatively
drained = reactor_run_until_idle(reactor, 50)
assert_true(drained >= 2, "Both cooperative fibers executed and completed")
assert_eq(reactor_active_count(reactor), 0, "All fibers completed, active count is 0")

// Verify consumer produced the expected result (5 * 10 = 50)
final_res = channel_recv(result_ch)
assert_eq(final_res, 50, "Channel piped output: 5 * 10 = 50")

// Clean up
channel_free(pipe_ch)
channel_free(result_ch)
reactor_free(reactor)

say "\n🎉 ALL FIBER REACTOR & RING CHANNEL TESTS PASSED!"
