@! ============================================================================
@! MAYA ADVERSARIAL CHALLENGER TEST SUITE: PURE MAYA END-TO-END GC STRESS
@! File: tests/gc/test_gc_adversarial_challenger.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct ChallengerCtx
  total: 0
  passed: 0
  failed: 0
@end

@fn c_assert_true(ctx, name, cond)
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

@fn c_assert_eq(ctx, name, actual, expected)
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

@fn c_assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> matched string \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn write_payload(ptr, content, pid)
  len = str_len(content)
  tmp_file = "/tmp/maya_challenger_w_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(tmp_file, 578, 420)
  sys_write(fd, content, len)
  sys_close(fd)

  fd_r = sys_open(tmp_file, 0, 0)
  sys_read(fd_r, ptr, len)
  sys_close(fd_r)
  sys_unlink(tmp_file)
  return len
@end

@fn read_payload(ptr, len, pid)
  tmp_file = "/tmp/maya_challenger_r_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(tmp_file, 578, 420)
  sys_write(fd, ptr, len)
  sys_close(fd)

  res = file_read(tmp_file)
  sys_unlink(tmp_file)
  return res
@end

@! --- Adversarial Tests ---

@fn test_adversarial_pointer_boundaries(ctx)
  println("\n--- [Challenger Test 1] Byte-by-Byte Boundary Introspection ---")

  @! Allocate 128 bytes
  p = gc_alloc(128)
  c_assert_true(ctx, "Buffer allocated", p > 0)
  c_assert_eq(ctx, "8-byte aligned", p % 8, 0)

  @! 1. Base pointer
  c_assert_eq(ctx, "gc_base(p) == p", gc_base(p), p)

  @! 2. Interior pointers at first, middle, last bytes
  c_assert_eq(ctx, "gc_base(p + 1) == p", gc_base(p + 1), p)
  c_assert_eq(ctx, "gc_base(p + 64) == p", gc_base(p + 64), p)
  c_assert_eq(ctx, "gc_base(p + 127) == p", gc_base(p + 127), p)

  @! 3. Slot padding / boundary rejection
  c_assert_eq(ctx, "gc_base(p + 128) == 0 (past payload)", gc_base(p + 128), 0)
  c_assert_eq(ctx, "gc_base(p - 1) == 0 (header byte)", gc_base(p - 1), 0)
  c_assert_eq(ctx, "gc_base(p - 16) == 0 (header base)", gc_base(p - 16), 0)

  @! 4. Free and verify rejection
  gc_free(p)
  c_assert_eq(ctx, "gc_base(freed) == 0", gc_base(p), 0)
  c_assert_eq(ctx, "gc_base(freed + 64) == 0", gc_base(p + 64), 0)

  @! 5. Alien pointer defenses
  c_assert_eq(ctx, "gc_base(0) == 0", gc_base(0), 0)
  c_assert_eq(ctx, "gc_base(-1) == 0", gc_base(0 - 1), 0)
  c_assert_eq(ctx, "gc_base(4096) == 0", gc_base(4096), 0)
@end

@fn test_adversarial_realloc_transitions(ctx)
  println("\n--- [Challenger Test 2] Multi-Stage Zig-Zag Reallocations ---")
  pid = sys_getpid()

  @! Stage 1: 16B allocation
  p = gc_alloc(16)
  write_payload(p, "STAGE1_16_BYTES!", pid)
  c_assert_str_eq(ctx, "Stage 1 data confirmed", read_payload(p, 16, pid), "STAGE1_16_BYTES!")

  @! Stage 2: Realloc to 64B
  p = gc_realloc(p, 64)
  c_assert_true(ctx, "Realloc to 64B successful", p > 0)
  c_assert_str_eq(ctx, "Stage 1 data preserved in 64B", read_payload(p, 16, pid), "STAGE1_16_BYTES!")
  write_payload(p + 16, "_STAGE2_NEW_48_BYTES_PAYLOAD_BLOCK_CONFIRMED_OK!", pid)

  @! Stage 3: Realloc to 512B
  p = gc_realloc(p, 512)
  c_assert_true(ctx, "Realloc to 512B successful", p > 0)
  c_assert_str_eq(ctx, "Stage 1 data preserved in 512B", read_payload(p, 16, pid), "STAGE1_16_BYTES!")

  @! Stage 4: Realloc to 4096B (Large Mmap)
  p = gc_realloc(p, 4096)
  c_assert_true(ctx, "Realloc to 4096B (mmap) successful", p > 0)
  c_assert_str_eq(ctx, "Stage 1 data preserved in 4096B mmap", read_payload(p, 16, pid), "STAGE1_16_BYTES!")

  @! Stage 5: Demote back to 32B Slab
  p = gc_realloc(p, 32)
  c_assert_true(ctx, "Demote to 32B slab successful", p > 0)
  c_assert_str_eq(ctx, "Stage 1 data preserved after demotion", read_payload(p, 16, pid), "STAGE1_16_BYTES!")

  gc_free(p)
@end

@fn test_adversarial_high_frequency_churn(ctx)
  println("\n--- [Challenger Test 3] 10,000 Churn Iterations with Sliding Window ---")
  pid = sys_getpid()
  window_size = 128
  total_cycles = 10000

  slots = []
  sizes = []
  sigs = []

  i = 0
  @while i < window_size
    slots = slots.push(0)
    sizes = sizes.push(0)
    sigs = sigs.push("")
    i = i + 1
  @end

  churn_pass = 1
  cycle = 0

  @while cycle < total_cycles
    idx = cycle % window_size
    old_p = slots[idx]

    @if old_p != 0
      @! Verify pointer
      @if gc_base(old_p) != old_p
        churn_pass = 0
        println("  [ERROR] gc_base mismatch at cycle " + maya_int_to_str(cycle))
      @end

      @! Verify signature for sampled cycles
      exp_sig = sigs[idx]
      exp_len = str_len(exp_sig)
      @if exp_len > 0 && (cycle % 25 == 0)
        act_sig = read_payload(old_p, exp_len, pid)
        @if act_sig != exp_sig
          churn_pass = 0
          println("  [ERROR] Payload mismatch at cycle " + maya_int_to_str(cycle))
        @end
      @end

      gc_free(old_p)
      slots[idx] = 0
      sizes[idx] = 0
      sigs[idx] = ""
    @end

    @! Allocate varied size
    req_sz = ((cycle * 83 + 29) % 2000) + 16
    @if cycle % 200 == 0
      req_sz = 8192 @! Mmap chunk
    @end

    new_p = gc_alloc(req_sz)
    @if new_p <= 0
      churn_pass = 0
      println("  [FATAL] OOM at cycle " + maya_int_to_str(cycle))
    @end

    sig = ""
    @if cycle % 25 == 0
      sig = "SIG_" + maya_int_to_str(cycle) + "_OK"
      write_payload(new_p, sig, pid)
    @end

    slots[idx] = new_p
    sizes[idx] = req_sz
    sigs[idx] = sig

    @if cycle % 2500 == 0 && cycle > 0
      println("    ... " + maya_int_to_str(cycle) + " / " + maya_int_to_str(total_cycles) + " churn iterations completed")
    @end

    cycle = cycle + 1
  @end

  @! Sweep remaining
  i = 0
  @while i < window_size
    rem_p = slots[i]
    @if rem_p != 0
      gc_free(rem_p)
    @end
    i = i + 1
  @end

  c_assert_true(ctx, "10,000 churn cycles completed successfully with 100% integrity", churn_pass != 0)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA EMPIRICAL CHALLENGER ADVERSARIAL VERIFICATION SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_adversarial_pointer_boundaries(ctx)
  test_adversarial_realloc_transitions(ctx)
  test_adversarial_high_frequency_churn(ctx)

  println("\n=================================================================")
  println("📊 PURE MAYA CHALLENGER SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [CHALLENGER SUCCESS] Pure Maya GC Challenger Suite Passed 100%!")
    return 0
  @else
    println("\n✗ [CHALLENGER FAILURE] GC Challenger Suite Failed.")
    return 1
  @end
@end
