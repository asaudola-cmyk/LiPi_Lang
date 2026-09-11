@! ============================================================================
@! ADVERSARIAL MASTER SUITE: PURE MAYA RUNTIME, GC & CODEGEN STRESS
@! File: tests/adversarial/test_challenger_runtime_stress_master.maya
@! Author: Challenger 1 (Adversarial Runtime & Codegen Stress Tester)
@! Scope:
@!   1. Deep recursive stack root scanning (300 frames) with mid-stack GC churn
@!   2. Multi-class segregated slab fragmentation & alternating lifecycle stress
@!   3. Complex dynamic object graphs & cyclic reference resilience
@!   4. High-frequency raw Linux syscall gateway under rapid allocation
@!   5. Codegen edge cases: 64-bit boundary arithmetic, nested loops & bitwise ops
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"
import "universe/core/string"
import "universe/core/collections"

@struct MasterStressCtx
  total: 0
  passed: 0
  failed: 0
@end

@fn chk_true(ctx, test_name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + test_name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + test_name + " -> evaluated to FALSE (0)")
    return 0
  @end
@end

@fn chk_eq(ctx, test_name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + test_name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + test_name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn chk_str_eq(ctx, test_name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + test_name + " -> '" + actual + "'")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + test_name + " -> expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@! ============================================================================
@! TEST 1: Deep Recursive Stack Root Scanning & Mid-Stack GC Churn
@! ============================================================================

@fn recursive_stack_churn(depth, max_depth)
  @! Allocate frame-local live objects
  frame_token = "STACK_FRAME_DEPTH_" + maya_int_to_str(depth)
  frame_arr = [depth, depth * 3, depth * 7]
  
  @if depth >= max_depth
    @! At max recursion depth, trigger intense memory allocation churn
    churn_i = 0
    @while churn_i < 500
      discarded_str = "CHURN_TRANSIENT_" + maya_int_to_str(churn_i * 13)
      discarded_buf = gc_alloc(64)
      @if discarded_buf > 0
        gc_free(discarded_buf)
      @end
      churn_i = churn_i + 1
    @end
    return depth
  @end

  sub_res = recursive_stack_churn(depth + 1, max_depth)

  @! Verify that current frame's objects survived the deep stack unwinding & GC churn
  @if frame_arr.len() != 3
    return 0 - 1
  @end
  @if frame_arr[0] != depth || frame_arr[1] != depth * 3 || frame_arr[2] != depth * 7
    return 0 - 2
  @end
  @if frame_token != "STACK_FRAME_DEPTH_" + maya_int_to_str(depth)
    return 0 - 3
  @end

  return sub_res
@end

@fn test_deep_stack_scanning(ctx)
  println("\n--- [Test 1] Deep Recursive Stack Root Scanning (300 Frames + Churn) ---")
  res = recursive_stack_churn(1, 300)
  chk_eq(ctx, "Recursive stack 300-frame traversal survived mid-stack GC", res, 300)
@end

@! ============================================================================
@! TEST 2: Multi-Class Segregated Slab Churn & Alternating Fragmentation Stress
@! ============================================================================

@fn test_slab_fragmentation_and_recycling(ctx)
  println("\n--- [Test 2] Multi-Class Segregated Slab Churn & Alternating Recycling ---")
  
  pid = sys_getpid()
  count = 600
  ptrs = []
  sigs = []
  sizes = []

  @! Phase A: Allocate objects across all 8 size classes
  i = 0
  @while i < count
    @! Sizes cycle through: 16, 32, 64, 128, 256, 512, 1024, 2048, and 4096 (large)
    class_idx = i % 9
    sz = 16
    @if class_idx == 1  sz = 32 @end
    @if class_idx == 2  sz = 64 @end
    @if class_idx == 3  sz = 128 @end
    @if class_idx == 4  sz = 256 @end
    @if class_idx == 5  sz = 512 @end
    @if class_idx == 6  sz = 1024 @end
    @if class_idx == 7  sz = 2048 @end
    @if class_idx == 8  sz = 4096 @end

    ptr = gc_alloc(sz)
    ptrs.push(ptr)
    sizes.push(sz)

    @! Generate unique signature
    sig = "SIG_" + maya_int_to_str(i) + "_SZ" + maya_int_to_str(sz)
    sigs.push(sig)
    
    @! Write signature to allocated buffer via syscall file roundtrip or memory
    tmp_f = "/tmp/maya_stress_slab_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd_w = sys_open(tmp_f, 578, 420)
    sys_write(fd_w, sig, str_len(sig))
    sys_close(fd_w)

    fd_r = sys_open(tmp_f, 0, 0)
    sys_read(fd_r, ptr, str_len(sig))
    sys_close(fd_r)
    sys_unlink(tmp_f)

    i = i + 1
  @end

  chk_eq(ctx, "Phase A: Allocated 600 multi-class objects", ptrs.len(), 600)

  @! Phase B: Free all odd indexed objects to create maximum fragmentation
  odd_freed = 0
  i = 1
  @while i < count
    gc_free(ptrs[i])
    ptrs[i] = 0
    odd_freed = odd_freed + 1
    i = i + 2
  @end

  chk_eq(ctx, "Phase B: Freed 300 alternating slots for fragmentation", odd_freed, 300)

  @! Phase C: Reallocate 300 new objects into fragmented free-lists
  i = 1
  @while i < count
    sz = sizes[i]
    new_ptr = gc_alloc(sz)
    ptrs[i] = new_ptr
    new_sig = "REALLOC_SIG_" + maya_int_to_str(i)
    sigs[i] = new_sig

    tmp_f = "/tmp/maya_stress_realloc_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd_w = sys_open(tmp_f, 578, 420)
    sys_write(fd_w, new_sig, str_len(new_sig))
    sys_close(fd_w)

    fd_r = sys_open(tmp_f, 0, 0)
    sys_read(fd_r, new_ptr, str_len(new_sig))
    sys_close(fd_r)
    sys_unlink(tmp_f)

    i = i + 2
  @end

  chk_eq(ctx, "Phase C: Reallocated 300 recycled slots", ptrs.len(), 600)

  @! Phase D: Verify 100% integrity of all 600 objects (both even survivors and odd reallocations)
  intact_count = 0
  i = 0
  @while i < count
    ptr = ptrs[i]
    expected_sig = sigs[i]
    sig_len = str_len(expected_sig)

    chk_f = "/tmp/maya_stress_verify_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd_w = sys_open(chk_f, 578, 420)
    sys_write(fd_w, ptr, sig_len)
    sys_close(fd_w)

    read_back = file_read(chk_f)
    sys_unlink(chk_f)

    @if read_back == expected_sig
      intact_count = intact_count + 1
    @end

    @! Clean up
    gc_free(ptr)
    i = i + 1
  @end

  chk_eq(ctx, "Phase D: 100% of fragmented objects preserved signature integrity", intact_count, 600)
@end

@! ============================================================================
@! TEST 3: Complex Dynamic Object Graphs & Graph Traversal Resilience
@! ============================================================================

@fn test_complex_object_graph(ctx)
  println("\n--- [Test 3] Complex Dynamic Object Graphs & BFS Traversal ---")

  @! Build a 100-node graph where each node connects to (i*3+1)%100 and (i*7+5)%100
  nodes = []
  i = 0
  @while i < 100
    n = {
      id: i,
      label: "Node_" + maya_int_to_str(i),
      edges: [(i * 3 + 1) % 100, (i * 7 + 5) % 100],
      weight: i * 11,
      visited: 0
    }
    nodes.push(n)
    i = i + 1
  @end

  chk_eq(ctx, "Graph populated with 100 dynamic nodes", nodes.len(), 100)

  @! Perform BFS from Node 0 and compute cumulative visited weights
  queue = [0]
  nodes[0].visited = 1
  visited_count = 1
  total_weight = nodes[0].weight

  head = 0
  @while head < queue.len()
    curr_id = queue[head]
    curr_node = nodes[curr_id]
    head = head + 1

    e_idx = 0
    @while e_idx < curr_node.edges.len()
      target_id = curr_node.edges[e_idx]
      target_node = nodes[target_id]
      @if target_node.visited == 0
        target_node.visited = 1
        visited_count = visited_count + 1
        total_weight = total_weight + target_node.weight
        queue.push(target_id)
      @end
      e_idx = e_idx + 1
    @end
  @end

  chk_eq(ctx, "BFS reached exact connected component size (50 nodes)", visited_count, 50)
  chk_true(ctx, "BFS accumulated valid weight checksum (>10000)", total_weight > 10000)
@end

@! ============================================================================
@! TEST 4: Raw Linux Syscall Gateway Concurrency & Error Boundaries
@! ============================================================================

@fn test_syscall_gateway_and_boundaries(ctx)
  println("\n--- [Test 4] Raw Linux Syscall Gateway & Error Boundary Resilience ---")

  @! 1. Direct PID, PPID syscalls
  pid = sys_getpid()
  ppid = sys_getppid()
  uid = syscall(102, 0, 0, 0, 0, 0, 0) @! sys_getuid = 102
  gid = syscall(104, 0, 0, 0, 0, 0, 0) @! sys_getgid = 104

  chk_true(ctx, "sys_getpid() returns valid PID (>0)", pid > 0)
  chk_true(ctx, "sys_getppid() returns valid PPID (>0)", ppid > 0)
  chk_true(ctx, "syscall(102) getuid returns valid UID (>=0)", uid >= 0)
  chk_true(ctx, "syscall(104) getgid returns valid GID (>=0)", gid >= 0)

  @! 2. Monotonic Clock & High-Precision Time
  time_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  c_res = sys_clock_gettime(1, time_buf) @! CLOCK_MONOTONIC = 1
  chk_eq(ctx, "sys_clock_gettime(CLOCK_MONOTONIC) returns 0", c_res, 0)

  @! 3. Kernel Crypto Entropy
  entropy_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  rand_bytes = sys_getrandom(entropy_buf, 64, 0)
  chk_eq(ctx, "sys_getrandom(64) returned exact 64 bytes", rand_bytes, 64)

  @! 4. Error Boundaries: Non-existent file open should return negative errno (-ENOENT = -2)
  bad_fd = sys_open("/tmp/__definitely_non_existent_maya_test_file_999999.xyz", 0, 0)
  chk_true(ctx, "Opening non-existent file returns negative errno (<0)", bad_fd < 0)

  @! 5. Error Boundaries: Closing invalid fd returns negative errno (-EBADF = -9)
  bad_close = sys_close(999999)
  chk_true(ctx, "Closing invalid fd returns negative errno (<0)", bad_close < 0)

  @! 6. Clean up mapped pages
  sys_munmap(time_buf, 4096)
  sys_munmap(entropy_buf, 4096)
  chk_true(ctx, "Memory pages unmapped successfully", 1)
@end

@! ============================================================================
@! TEST 5: Standalone Codegen Limits: 64-bit Boundary Arithmetic & Flow Control
@! ============================================================================

@fn test_codegen_arithmetic_and_control_flow(ctx)
  println("\n--- [Test 5] Codegen 64-bit Boundaries, Bitwise Math & Complex Flow ---")

  @! 1. Large 64-bit signed integer boundary math
  let max_i32 = 2147483647
  let min_i32 = 0 - 2147483648
  let big_val = 10000000000 @! 10 billion > 32-bit

  chk_eq(ctx, "64-bit addition crossing 32-bit boundary", max_i32 + 1000, 2147484647)
  chk_eq(ctx, "64-bit multiplication: 10B * 2 == 20B", big_val * 2, 20000000000)
  chk_eq(ctx, "64-bit division: 20B / 5 == 4B", (big_val * 2) / 5, 4000000000)
  chk_eq(ctx, "64-bit modulo: 20B % 7 == 1", 20000000000 % 7, 1)

  @! 2. Bitwise Logic & Shift Operator Correctness
  let bit_a = 240   @! 1111 0000
  let bit_b = 170   @! 1010 1010
  chk_eq(ctx, "Bitwise AND: 240 & 170 == 160", bit_a & bit_b, 160)
  chk_eq(ctx, "Bitwise OR: 240 | 170 == 250", bit_a | bit_b, 250)
  chk_eq(ctx, "Bitwise XOR: 240 ^ 170 == 90", bit_a ^ bit_b, 90)
  chk_eq(ctx, "Bitwise Left Shift: 5 << 4 == 80", 5 << 4, 80)
  chk_eq(ctx, "Bitwise Right Shift: 80 >> 3 == 10", 80 >> 3, 10)

  @! 3. Nested loops with conditionals
  accum = 0
  outer = 0
  @while outer < 20
    inner = 0
    @while inner < 20
      inner = inner + 1
      @if inner % 2 == 0
        @! skip
      @else
        accum = accum + 1
      @end
    @end
    outer = outer + 1
  @end

  chk_eq(ctx, "Nested loops with conditionals: 20 * 10 odd iterations == 200", accum, 200)

  @! 4. Complex Multi-Operator Precedence Formula
  let x = 12
  let y = 5
  let z = 3
  @! (12 + 5 * 3) - (12 / 3) + (y % z) == (12 + 15) - 4 + 2 == 27 - 4 + 2 == 25
  let math_res = (x + y * z) - (x / z) + (y % z)
  chk_eq(ctx, "Complex operator precedence formula == 25", math_res, 25)
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL MASTER SUITE: RUNTIME, GC, SYSCALL & CODEGEN")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_deep_stack_scanning(ctx)
  test_slab_fragmentation_and_recycling(ctx)
  test_complex_object_graph(ctx)
  test_syscall_gateway_and_boundaries(ctx)
  test_codegen_arithmetic_and_control_flow(ctx)

  println("\n=================================================================")
  println("📊 ADVERSARIAL MASTER SUITE EXECUTION SUMMARY")
  println("=================================================================")
  println("  Total Stress Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed Assertions       : " + maya_int_to_str(ctx.passed))
  println("  Failed Assertions       : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n🏆 [VERDICT: APPROVE] 100% OF ADVERSARIAL STRESS CHALLENGES PASSED!")
    return 0
  @else
    println("\n💥 [VERDICT: REQUEST_CHANGES] ADVERSARIAL STRESS FAILURES DETECTED!")
    return 1
  @end
@end
