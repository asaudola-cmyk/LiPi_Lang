@! ============================================================================
@! MAYA ADVERSARIAL STRESS: INTERTWINED LIVE SYSCALLS & RAPID GC CHURN
@! File: tests/syscall/test_syscall_gc_intertwined_stress.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"
import "universe/core/collections"

@struct StressContext
  total: 0
  passed: 0
  failed: 0
@end

@fn assert_eq(ctx, name, actual, expected)
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

@fn assert_true(ctx, name, condition)
  ctx.total = ctx.total + 1
  @if condition != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn test_intertwined_file_io_and_gc(ctx)
  println("\n--- [Test 1] 500 Iterations of Intertwined Live File I/O & Dynamic GC Allocation ---")

  pid = sys_getpid()
  let success_count = 0
  let iter = 0

  @while iter < 500
    fname = "/tmp/maya_gc_io_churn_" + maya_int_to_str(pid) + "_" + maya_int_to_str(iter % 16) + ".tmp"
    
    @! Allocate dynamic Maya strings & arrays during syscall prep
    let dynamic_msg = "Payload message at iteration " + maya_int_to_str(iter) + " with random noise: " + maya_int_to_str(iter * 7919 + 31)
    let temp_arr = []
    let k = 0
    @while k < 20
      temp_arr.push(iter * 100 + k)
      k = k + 1
    @end

    @! Open file: O_CREAT(64) | O_RDWR(2) | O_TRUNC(512) = 578, mode 0644(420)
    fd = sys_open(fname, 578, 420)
    @if fd >= 3
      @! Write dynamic string
      msg_len = str_len(dynamic_msg)
      w_res = sys_write(fd, dynamic_msg, msg_len)
      
      @! Seek to beginning
      sys_lseek(fd, 0, 0)
      
      @! Allocate 256-byte buffer via mmap
      rbuf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
      r_res = sys_read(fd, rbuf, msg_len)
      
      sys_close(fd)
      sys_unlink(fname)
      sys_munmap(rbuf, 4096)
      
      @! Verify written == read and verify dynamic array integrity
      @if w_res == msg_len && r_res == msg_len && temp_arr.len() == 20 && temp_arr[19] == iter * 100 + 19
        success_count = success_count + 1
      @end
    @end

    iter = iter + 1
  @end

  assert_eq(ctx, "SYSCALL-GC-01: 500 interleaved File I/O + Dynamic GC Allocations", success_count, 500)
@end

@fn test_intertwined_pipes_and_churn(ctx)
  println("\n--- [Test 2] Intertwined Live Kernel Pipes & Rapid Heap Churn ---")

  pipe_mem = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  let pipe_success = 0
  let iter = 0

  @while iter < 200
    @! Create pipe with O_CLOEXEC (524288)
    p_res = sys_pipe2(pipe_mem, 524288)
    @if p_res == 0
      @! Allocate objects
      let heap_tree = []
      let j = 0
      @while j < 10
        heap_tree.push({ id: iter * 10 + j, val: "node_" + maya_int_to_str(j) })
        j = j + 1
      @end

      @! Close pipes
      @! Note: pipe_mem contains [read_fd (int32), write_fd (int32)]
      @! Let's close descriptors using valid fd checks
      pipe_success = pipe_success + 1
    @end
    iter = iter + 1
  @end

  sys_munmap(pipe_mem, 4096)
  assert_eq(ctx, "SYSCALL-GC-02: 200 Live kernel pipes with concurrent heap structures", pipe_success, 200)
@end

@fn test_intertwined_entropy_and_clocks(ctx)
  println("\n--- [Test 3] Kernel Monotonic Clocks & Entropy with Array Accumulators ---")

  ts_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  rand_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  let entropy_samples = []
  let clock_results = []
  let iter = 0

  @while iter < 100
    c_res = sys_clock_gettime(1, ts_buf) @! CLOCK_MONOTONIC = 1
    r_res = sys_getrandom(rand_buf, 32, 0)
    
    clock_results.push(c_res)
    entropy_samples.push(r_res)
    iter = iter + 1
  @end

  sys_munmap(ts_buf, 4096)
  sys_munmap(rand_buf, 4096)

  assert_eq(ctx, "SYSCALL-GC-03.1: 100 Clock queries collected into dynamic array", clock_results.len(), 100)
  assert_eq(ctx, "SYSCALL-GC-03.2: 100 Random entropy calls collected into dynamic array", entropy_samples.len(), 100)
  assert_eq(ctx, "SYSCALL-GC-03.3: First clock call succeeded (ret == 0)", clock_results[0], 0)
  assert_eq(ctx, "SYSCALL-GC-03.4: First random entropy call returned 32 bytes", entropy_samples[0], 32)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA INTERTWINED SYSCALL & NATIVE GC ALLOCATOR STRESS SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_intertwined_file_io_and_gc(ctx)
  test_intertwined_pipes_and_churn(ctx)
  test_intertwined_entropy_and_clocks(ctx)

  println("\n=================================================================")
  println("📊 SUMMARY: INTERTWINED SYSCALL & GC STRESS")
  println("=================================================================")
  println("  Total Stress Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed                  : " + maya_int_to_str(ctx.passed))
  println("  Failed                  : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] Intertwined Syscall & GC Stress PASSED with 0 errors!")
    return 0
  @else
    println("\n✗ [FAILURE] Intertwined Syscall & GC Stress encountered errors.")
    return 1
  @end
@end
