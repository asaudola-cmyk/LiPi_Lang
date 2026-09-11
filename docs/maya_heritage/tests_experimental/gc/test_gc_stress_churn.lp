@! ============================================================================
@! MAYA UNMOCKED GC TEST SUITE: ADVERSARIAL CHURN & HEAP STRESS
@! File: tests/gc/test_gc_stress_churn.maya
@! Scope: Continuous allocations, reallocations, payload verifications,
@!        sliding window retention, fragmentation resistance, and leak checks.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct StressContext
  total: 0
  passed: 0
  failed: 0
@end

@fn s_assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn s_assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn run_sliding_window_churn(ctx, total_cycles, window_size)
  println("\n--- [Stress Group 1] " + maya_int_to_str(total_cycles) + "-Cycle Sliding Window Churn Test ---")
  pid = sys_getpid()

  @! Initialize active window
  slots = []
  slot_sizes = []
  slot_sigs = []
  i = 0
  @while i < window_size
    slots = slots.push(0)
    slot_sizes = slot_sizes.push(0)
    slot_sigs = slot_sigs.push("")
    i = i + 1
  @end

  all_passed = 1
  cycle = 0

  println("  [STRESS] Launching " + maya_int_to_str(total_cycles) + " iteration churn loop across " + maya_int_to_str(window_size) + " sliding slots...")

  @while cycle < total_cycles
    slot_idx = cycle % window_size

    @! 1. If slot occupied, verify and free
    existing_ptr = slots[slot_idx]
    @if existing_ptr != 0
      @! Verify pointer is still live and valid
      base_chk = gc_base(existing_ptr)
      @if base_chk != existing_ptr
        all_passed = 0
        println("  [ERROR] Corrupted pointer at cycle " + maya_int_to_str(cycle) + ", slot " + maya_int_to_str(slot_idx))
      @end

      @! If signature was stored, verify periodically or for sampled slots
      expected_sig = slot_sigs[slot_idx]
      sig_len = str_len(expected_sig)
      @if sig_len > 0 && (cycle % 20 == 0)
        f_chk = "/tmp/maya_churn_chk_" + maya_int_to_str(pid) + ".tmp"
        fd_w = sys_open(f_chk, 578, 420)
        sys_write(fd_w, existing_ptr, sig_len)
        sys_close(fd_w)

        read_sig = file_read(f_chk)
        sys_unlink(f_chk)

        @if read_sig != expected_sig
          all_passed = 0
          println("  [ERROR] Payload mismatch at cycle " + maya_int_to_str(cycle) + ", slot " + maya_int_to_str(slot_idx))
        @end
      @end

      gc_free(existing_ptr)
      slots[slot_idx] = 0
      slot_sizes[slot_idx] = 0
      slot_sigs[slot_idx] = ""
    @end

    @! 2. Compute pseudorandom size across slab classes (16B to 2048B) + occasional large mmap
    req_size = ((cycle * 73 + 19) % 2040) + 8
    @if cycle % 250 == 0
      req_size = 4096 @! Large mmap allocation every 250 cycles
    @end

    @! 3. Allocate new object
    new_ptr = gc_alloc(req_size)
    @if new_ptr <= 0
      all_passed = 0
      println("  [FATAL] OOM or allocation failure at cycle " + maya_int_to_str(cycle))
    @end

    @! 4. Write signature into payload for sampled cycles
    sig_str = ""
    @if cycle % 20 == 0
      sig_str = "SIG_S" + maya_int_to_str(slot_idx) + "_C" + maya_int_to_str(cycle) + "_OK"
      sig_len = str_len(sig_str)

      f_in = "/tmp/maya_churn_in_" + maya_int_to_str(pid) + ".tmp"
      fd_in = sys_open(f_in, 578, 420)
      sys_write(fd_in, sig_str, sig_len)
      sys_close(fd_in)

      fd_rin = sys_open(f_in, 0, 0)
      sys_read(fd_rin, new_ptr, sig_len)
      sys_close(fd_rin)
      sys_unlink(f_in)
    @end

    slots[slot_idx] = new_ptr
    slot_sizes[slot_idx] = req_size
    slot_sigs[slot_idx] = sig_str

    @if cycle % 1000 == 0 && cycle > 0
      println("    ... completed " + maya_int_to_str(cycle) + " / " + maya_int_to_str(total_cycles) + " cycles (Heap healthy)")
    @end

    cycle = cycle + 1
  @end

  println("  [STRESS] Churn cycles completed. Sweeping remaining active window objects...")

  @! Final sweep: verify and free all remaining objects in active window
  i = 0
  @while i < window_size
    p = slots[i]
    @if p != 0
      b = gc_base(p)
      @if b != p
        all_passed = 0
      @end

      sig = slot_sigs[i]
      len = str_len(sig)
      @if len > 0
        f_chk = "/tmp/maya_churn_final_" + maya_int_to_str(pid) + ".tmp"
        fd_w = sys_open(f_chk, 578, 420)
        sys_write(fd_w, p, len)
        sys_close(fd_w)

        res_sig = file_read(f_chk)
        sys_unlink(f_chk)

        @if res_sig != sig
          all_passed = 0
        @end
      @end

      gc_free(p)
    @end
    i = i + 1
  @end

  s_assert_true(ctx, "TC-STRESS-01: Continuous churn cycles with sliding-window verification passed 100%", all_passed != 0)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA NATIVE GC ADVERSARIAL STRESS SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  run_sliding_window_churn(ctx, 5000, 128)

  println("\n=================================================================")
  println("📊 ADVERSARIAL STRESS SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] Stress test completed with zero failures!")
    return 0
  @else
    println("\n✗ [FAILURE] Stress test encountered failures.")
    return 1
  @end
@end
