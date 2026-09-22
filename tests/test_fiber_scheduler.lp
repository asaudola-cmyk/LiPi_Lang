// ==============================================================================
// 🧪 LIPI TEST: M:N Ultra-Lightweight Fiber Runtime & Lock-Free Scheduler Test
// ⚡ Tests micro-stack allocation, stack guard canary bounds, lock-free ring queue,
//    fair cooperative scheduling, stack corruption prevention, and fiber channels.
// ==============================================================================

include "src/runtime/async/fiber.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi M:N Fiber Runtime & Lock-Free Scheduler"
say "========================================================"

// ── Test 1: Micro-Stack Allocation & Canary Verification ───────────────────────
say "[1/5] Testing Fiber Stack Allocation & Canary Guard..."
f1 = fiber_new(101, 1, 5, 4096)

assert_eq(get(f1, 0), 101, "Fiber ID is 101")
assert_eq(get(f1, 1), FIBER_READY, "Initial fiber state is FIBER_READY (0)")
assert_eq(get(f1, 3), 4096, "Fiber stack size is 4KB (4096)")

// Check canary integrity
canary_ok = fiber_check_stack_guard(f1)
assert_eq(canary_ok, 1, "Fiber stack canary guard is intact (0xDEADBEEF)")

// ── Test 2: Lock-Free Ring Buffer Queue ───────────────────────────────────────
say "[2/5] Testing Lock-Free Ring Buffer Fiber Queue..."
q = fiber_queue_new(4)
assert_eq(fiber_queue_len(q), 0, "Initial queue length is 0")

f_a = fiber_new(1, 1, 10, 1024)
f_b = fiber_new(2, 1, 20, 1024)
f_c = fiber_new(3, 1, 30, 1024)

fiber_queue_push(q, f_a)
fiber_queue_push(q, f_b)
fiber_queue_push(q, f_c)
assert_eq(fiber_queue_len(q), 3, "Queue length is 3 after 3 pushes")

popped1 = fiber_queue_pop(q)
assert_eq(get(popped1, 0), 1, "First popped fiber is f_a (ID 1)")
assert_eq(fiber_queue_len(q), 2, "Queue length decreased to 2")

popped2 = fiber_queue_pop(q)
assert_eq(get(popped2, 0), 2, "Second popped fiber is f_b (ID 2)")

// ── Test 3: Multi-Fiber Cooperative Scheduling ────────────────────────────────
say "[3/5] Testing Multi-Fiber Cooperative Time Slicing..."
sched = fiber_scheduler_new()

// Spawn 3 fibers:
// Fiber 1: count to 3
// Fiber 2: count to 5
// Fiber 3: accumulator add 100
fid1 = fiber_scheduler_spawn(sched, 1, 3)
fid2 = fiber_scheduler_spawn(sched, 1, 5)
fid3 = fiber_scheduler_spawn(sched, 2, 100)

assert_eq(fid1, 1, "Spawned fiber 1")
assert_eq(fid2, 2, "Spawned fiber 2")
assert_eq(fid3, 3, "Spawned fiber 3")

// Run scheduler until completion
completed = fiber_scheduler_run_all(sched, 100)
assert_eq(completed, 3, "All 3 concurrent fibers completed successfully")

fibers = get(sched, 4)
fib1 = get(fibers, 0)
fib2 = get(fibers, 1)
fib3 = get(fibers, 2)

assert_eq(get(fib1, 7), 3, "Fiber 1 counter reached 3")
assert_eq(get(fib2, 7), 5, "Fiber 2 counter reached 5")
assert_eq(get(fib3, 7), 100, "Fiber 3 accumulator reached 100")

assert_eq(get(fib1, 1), FIBER_DEAD, "Fiber 1 state is FIBER_DEAD")
assert_eq(get(fib2, 1), FIBER_DEAD, "Fiber 2 state is FIBER_DEAD")
assert_eq(get(fib3, 1), FIBER_DEAD, "Fiber 3 state is FIBER_DEAD")

// ── Test 4: Stack Overflow & Canary Corruption Prevention (Trap 1 Defense) ────
say "[4/5] Testing Stack Corruption Detection (Trap 1 Defense)..."
f_test = fiber_new(999, 1, 10, 2048)
stk_ptr = get(f_test, 2)

// Simulate stack overflow: overwrite bottom canary
mem_byte_write(stk_ptr, 0, 0)
corrupted_status = fiber_check_stack_guard(f_test)
assert_eq(corrupted_status, 0, "Corrupted canary correctly detected (0)")

// Execution slice must refuse to run and immediately terminate corrupted fiber
res_slice = fiber_execute_slice(f_test)
assert_eq(res_slice, -1, "Corrupted fiber execution aborted with -1")
assert_eq(get(f_test, 1), FIBER_DEAD, "Corrupted fiber terminated safely (FIBER_DEAD)")

fiber_free(f_test)

// ── Test 5: Fiber Channel Synchronization (chan) ──────────────────────────────
say "[5/5] Testing Fiber Channel Message Passing (chan)..."
ch = fiber_chan_new(2)

// Send 2 items
res1 = fiber_chan_send(ch, 42)
res2 = fiber_chan_send(ch, 99)
assert_eq(res1, 1, "Channel send 42 succeeded")
assert_eq(res2, 1, "Channel send 99 succeeded")

// Channel is now full; third send should return 0 (backpressure)
res3 = fiber_chan_send(ch, 100)
assert_eq(res3, 0, "Channel backpressure detected on full buffer (0)")

// Receive items
val_out = list()
fiber_chan_recv(ch, val_out)
assert_eq(get(val_out, 0), 42, "Received first channel value (42)")

val_out2 = list()
fiber_chan_recv(ch, val_out2)
assert_eq(get(val_out2, 0), 99, "Received second channel value (99)")

// Close channel
fiber_chan_close(ch)
res_closed = fiber_chan_send(ch, 123)
assert_eq(res_closed, -1, "Send on closed channel rejected with -1")

fiber_free(f1)
fiber_free(f_a)
fiber_free(f_b)
fiber_free(f_c)

say "========================================================"
say "PASS: Lipi M:N Fiber Runtime & Scheduler Verified 100%!"
say "========================================================"
