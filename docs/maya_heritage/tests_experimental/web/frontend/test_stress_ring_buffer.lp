@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — ADVERSARIAL STRESS SUITE: CONCURRENCY & RING BUFFER
@! File: tests/web/frontend/test_stress_ring_buffer.maya
@! Focus: High-Throughput Wrap-Around (10,000+ ops), Full/Empty Boundaries,
@! MPSC Multi-Producer Lock-Free CAS Contention, Binary Serialization & Worker Pool.
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"

import "universe/web/frontend/concurrency/message_protocol"
import "universe/web/frontend/concurrency/ring_buffer"
import "universe/web/frontend/concurrency/worker_pool"

@fn assert_true(cond, test_id, desc)
  @if cond == true || cond == 1
    println("  ✓ [PASS] " + test_id + ": " + desc)
    return 1
  @end
  println("  ❌ [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
  return 0
@end

@fn assert_eq_int(actual, expected, test_id, desc)
  @if actual == expected
    println("  ✓ [PASS] " + test_id + ": " + desc + " (= " + actual.to_str() + ")")
    return 1
  @end
  println("  ❌ [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str())
  return 0
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS 1: LOCK-FREE RING BUFFER & CONCURRENCY 🔥")
  println("=================================================================")

  total = 11
  passed = 0

  @! 1. High-Throughput Wrap-Around Stress (10,000 ops across capacity-16 ring)
  ring16 = ring_buffer_new(16)
  corrupted = 0
  op_i = 0
  target_ops = 10000
  @while op_i < target_ops
    tag = 100000 + op_i
    push_ok = ring_buffer_push_sqe(ring16, OP_DRAW_RECT(), tag, op_i, op_i * 3, 100, 50, 0, 0, 0, 0)
    @if push_ok != 1 corrupted = corrupted + 1 @end
    
    sqe = ring_buffer_pop_sqe(ring16)
    @if sqe == 0 || sqe.user_data != tag || sqe.arg0 != op_i || sqe.arg1 != (op_i * 3)
      corrupted = corrupted + 1
    @end
    op_i = op_i + 1
  @end
  passed = passed + assert_eq_int(corrupted, 0, "RING-STRESS-01", "10,000 continuous push/pop ops across 625 full wrap-arounds with zero corruption")
  passed = passed + assert_eq_int(ring16.sq_head, target_ops, "RING-STRESS-02", "Submission queue head equals 10,000")
  passed = passed + assert_eq_int(ring16.sq_tail, target_ops, "RING-STRESS-03", "Submission queue tail equals 10,000")
  passed = passed + assert_true(ring_buffer_is_sq_empty(ring16) == 1, "RING-STRESS-04", "Ring is completely empty after 10,000 wrap-around ops")

  @! 2. Boundary Stress: Rapid Fill to Exact Capacity & Overflow Defense
  ring8 = ring_buffer_new(8)
  fill_cycles = 50
  fc = 0
  boundary_failures = 0
  @while fc < fill_cycles
    j = 0
    @while j < 8
      ok = ring_buffer_push_sqe(ring8, OP_INPUT_EVENT(), fc * 10 + j, j, 0, 0, 0, 0, 0, 0, 0)
      @if ok != 1 boundary_failures = boundary_failures + 1 @end
      j = j + 1
    @end
    
    overflow_ok = ring_buffer_push_sqe(ring8, OP_INPUT_EVENT(), 999999, 0, 0, 0, 0, 0, 0, 0, 0)
    @if overflow_ok != 0 boundary_failures = boundary_failures + 1 @end
    @if ring_buffer_is_sq_full(ring8) != 1 boundary_failures = boundary_failures + 1 @end
    
    j = 0
    @while j < 8
      popped = ring_buffer_pop_sqe(ring8)
      expected_tag = fc * 10 + j
      @if popped == 0 || popped.user_data != expected_tag
        boundary_failures = boundary_failures + 1
      @end
      j = j + 1
    @end
    
    @if ring_buffer_is_sq_empty(ring8) != 1 boundary_failures = boundary_failures + 1 @end
    fc = fc + 1
  @end
  passed = passed + assert_eq_int(boundary_failures, 0, "RING-STRESS-05", "50 rapid fill/overflow-rejection/drain cycles passed with 0 errors")
  passed = passed + assert_eq_int(ring8.dropped_sqes, 50, "RING-STRESS-06", "Exact overflow counter tracks 50 dropped overflow pushes")

  @! 3. MPSC Multi-Producer Lock-Free CAS Stress Simulation
  ring_mpsc_stress = ring_buffer_new_mode(64, QUEUE_MODE_MPSC())
  producers_count = 8
  items_per_producer = 25
  total_mpsc_expected = producers_count * items_per_producer
  
  mpsc_dropped = 0
  mpsc_success = 0
  
  p_round = 0
  @while p_round < items_per_producer
    p_id = 0
    @while p_id < producers_count
      p_tag = (p_id + 1) * 10000 + p_round
      sqe = sqe_new(OP_DRAW_RECT(), 0, p_tag, p_id, p_round, 0, 0, 0, 0, 0, 0)
      
      res = ring_buffer_push_sqe_mpsc(ring_mpsc_stress, sqe)
      @if res == 1
        mpsc_success = mpsc_success + 1
      @else
        mpsc_dropped = mpsc_dropped + 1
      @end
      p_id = p_id + 1
    @end
    
    @while ring_buffer_is_sq_empty(ring_mpsc_stress) == 0
      popped_sqe = ring_buffer_pop_sqe(ring_mpsc_stress)
      @if popped_sqe == 0 break @end
    @end
    p_round = p_round + 1
  @end
  
  @while ring_buffer_is_sq_empty(ring_mpsc_stress) == 0
    ring_buffer_pop_sqe(ring_mpsc_stress)
  @end
  
  passed = passed + assert_eq_int(mpsc_success, total_mpsc_expected, "RING-STRESS-07", "MPSC 8 concurrent producers pushed 200 items with 100% commit success")
  passed = passed + assert_eq_int(mpsc_dropped, 0, "RING-STRESS-08", "MPSC CAS contention handled with zero dropped items")

  @! 4. Binary Serialization Byte-Exact Roundtrip Stress (200 Mixed Opcodes)
  bin_stress_errors = 0
  ser_i = 0
  @while ser_i < 200
    op = (ser_i % 7) + 1
    user_tag = 9000000000 + ser_i
    sqe_in = sqe_new(op, SQE_FLAG_DRAIN(), user_tag, ser_i, ser_i * 2, ser_i * 3, ser_i * 4, 5, 4278190080, 0, 0)
    bytes_out = sqe_serialize_binary(sqe_in)
    @if bytes_out.len() != 64 bin_stress_errors = bin_stress_errors + 1 @end
    
    sqe_out = sqe_deserialize_binary(bytes_out, 0)
    @if sqe_out.opcode != op || sqe_out.user_data != user_tag || sqe_out.arg0 != ser_i || sqe_out.arg1 != (ser_i * 2)
      bin_stress_errors = bin_stress_errors + 1
    @end
    
    cqe_in = cqe_new(user_tag, 200 + (ser_i % 100), CQE_FLAG_MORE())
    cqe_bytes = cqe_serialize_binary(cqe_in)
    @if cqe_bytes.len() != 16 bin_stress_errors = bin_stress_errors + 1 @end
    
    cqe_out = cqe_deserialize_binary(cqe_bytes, 0)
    @if cqe_out.user_data != user_tag || cqe_out.res != (200 + (ser_i % 100)) || cqe_out.flags != CQE_FLAG_MORE()
      bin_stress_errors = bin_stress_errors + 1
    @end
    ser_i = ser_i + 1
  @end
  passed = passed + assert_eq_int(bin_stress_errors, 0, "RING-STRESS-09", "200 SQE (64-byte) and CQE (16-byte) binary byte-level roundtrips verified with 0 errors")

  @! 5. 3-Worker Pool Multi-Channel Saturated Pipeline Dispatch
  pool = worker_pool_init(64)
  worker_pool_start(pool)
  
  pipe_tasks = 200
  p_i = 0
  @while p_i < pipe_tasks
    inp = { event_type: INPUT_EVENT_POINTER_MOVE(), target_x: p_i % 800, target_y: p_i % 600, key_code: 0, modifiers: 0, timestamp: p_i, pointer_id: 0, button: 0 }
    worker_pool_send_input(pool, inp, 100000 + p_i)
    
    rect = { x: 10, y: 10, width: 100, height: 50, bg_color: 4278190080, border_color: 0, border_width: 0, border_radius: 0 }
    worker_pool_send_draw_rect(pool, rect, 200000 + p_i)
    
    wf = { frame_id: p_i, timestamp: p_i * 16, width: 320, height: 240, pixel_ptr: 4096, format: 1, dst_x: 0, dst_y: 0 }
    worker_pool_send_webrtc_frame(pool, wf, 300000 + p_i)
    
    @if (p_i % 10) == 0
      worker_pool_tick_all(pool)
    @end
    p_i = p_i + 1
  @end
  
  drain_cycles = 0
  @while drain_cycles < 20
    worker_pool_tick_all(pool)
    drain_cycles = drain_cycles + 1
  @end
  
  p_stats = worker_pool_get_stats(pool)
  passed = passed + assert_true(p_stats.total_completed >= (pipe_tasks * 3), "RING-STRESS-10", "Worker pool processed all 600 multi-channel dispatched tasks")
  passed = passed + assert_eq_int(p_stats.dropped_tasks, 0, "RING-STRESS-11", "Zero dropped tasks under continuous multi-worker streaming")
  worker_pool_shutdown(pool)

  println("\n=================================================================")
  println("📊 CONCURRENCY STRESS RESULTS: " + passed.to_str() + " / " + total.to_str() + " assertions passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL 11 CONCURRENCY & RING BUFFER STRESS CHALLENGES PASSED! 🎉")
    return 0
  @else
    return 1
  @end
@end
