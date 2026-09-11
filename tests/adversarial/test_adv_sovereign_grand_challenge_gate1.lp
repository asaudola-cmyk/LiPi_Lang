@! ============================================================================
@! ADVERSARIAL STRESS TEST 5: SOVEREIGN FREESTANDING GRAND CHALLENGE
@! File: tests/adversarial/test_adv_sovereign_grand_challenge_gate1.maya
@! Target: Sovereign Pure Maya Compiler Backend (x86-64 freestanding ELF)
@! ============================================================================

@fn gcd(a, b)
  @while b != 0
    t = b
    b = a % b
    a = t
  @end
  return a
@end

@fn count_primes(limit)
  primes_found = 0
  n = 2
  @while n <= limit
    is_p = 1
    d = 2
    @while d * d <= n
      @if n % d == 0
        is_p = 0
        d = n
      @end
      d = d + 1
    @end
    @if is_p == 1
      primes_found = primes_found + 1
    @end
    n = n + 1
  @end
  return primes_found
@end

@fn fact_rec(n)
  @if n <= 1 return 1 @end
  prev = fact_rec(n - 1)
  return n * prev
@end

@fn ackermann(m, n)
  @if m == 0 return n + 1 @end
  @if m > 0 && n == 0 return ackermann(m - 1, 1) @end
  inner = ackermann(m, n - 1)
  return ackermann(m - 1, inner)
@end

@fn mem_alloc(size)
  return syscall(9, 0, size, 3, 34, -1, 0)
@end

@fn mem_free(ptr, size)
  return syscall(11, ptr, size, 0, 0, 0, 0)
@end

@fn main()
  println("================================================================")
  println("  SOVEREIGN MAYA FREESTANDING GRAND CHALLENGE — GATE 1")
  println("================================================================")

  @! --- Stage 1: Mathematical Engine ---
  println("▶ [STAGE 1] Testing Pure Computational Algorithms...")
  g = gcd(1071, 462)
  @if g != 21
    println("  [FAIL] STAGE 1: GCD mismatch")
    return 501
  @end

  p_cnt = count_primes(1000)
  @if p_cnt != 168
    println("  [FAIL] STAGE 1: Prime sieve mismatch")
    return 502
  @end

  f8 = fact_rec(8)
  @if f8 != 40320
    println("  [FAIL] STAGE 1: Factorial mismatch")
    return 503
  @end
  println("  [PASS] STAGE 1: GCD(1071,462)=21, Primes[2..1000]=168, Fact(8)=40320 verified")

  @! --- Stage 2: Deep Call Stack & Ackermann ---
  println("▶ [STAGE 2] Testing Call Stack Integrity & Ackermann(3, 4)...")
  ack = ackermann(3, 4)
  @if ack != 125
    println("  [FAIL] STAGE 2: Ackermann mismatch")
    return 504
  @end
  println("  [PASS] STAGE 2: Ackermann(3, 4) == 125 verified")

  @! --- Stage 3: Rapid Memory Churn (4,000 allocations & deallocations) ---
  println("▶ [STAGE 3] Testing 1,000 Cycles Multi-Slab Churn (4,000 allocs/frees)...")
  c = 0
  c_allocs = 0
  c_frees = 0
  @while c < 1000
    p1 = mem_alloc(64)
    p2 = mem_alloc(256)
    p3 = mem_alloc(1024)
    p4 = mem_alloc(2048)
    c_allocs = c_allocs + 4

    @if p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0
      println("  [FAIL] STAGE 3: Allocation failure during churn")
      return 505
    @end

    mem_free(p2, 256)
    mem_free(p4, 2048)
    mem_free(p1, 64)
    mem_free(p3, 1024)
    c_frees = c_frees + 4

    c = c + 1
  @end
  @if c_allocs != 4000 || c_frees != 4000
    println("  [FAIL] STAGE 3: Churn counter mismatch")
    return 506
  @end
  println("  [PASS] STAGE 3: 4,000 rapid allocations & deallocations completed clean")

  @! --- Stage 4: Large Buffers (>64KB, 1MB, 4MB) & Memory Protection ---
  println("▶ [STAGE 4] Testing Large Mmap Buffers (128KB, 1MB, 4MB)...")
  b128k = mem_alloc(131072)
  b1m = mem_alloc(1048576)
  b4m = mem_alloc(4194304)
  @if b128k <= 0 || b1m <= 0 || b4m <= 0
    println("  [FAIL] STAGE 4: Large buffer allocation failure")
    return 507
  @end

  @! Verify mprotect
  prot_res = syscall(10, b1m, 1048576, 1, 0, 0, 0)
  prot_res_restore = syscall(10, b1m, 1048576, 3, 0, 0, 0)
  @if prot_res != 0 || prot_res_restore != 0
    println("  [FAIL] STAGE 4: mprotect failure")
    return 508
  @end

  mem_free(b128k, 131072)
  mem_free(b1m, 1048576)
  mem_free(b4m, 4194304)
  println("  [PASS] STAGE 4: Large buffer mmap, mprotect, and teardown verified")

  @! --- Stage 5: Raw Syscall Pipeline & File I/O Roundtrip ---
  println("▶ [STAGE 5] Testing Raw Syscall File I/O Chaining & Kernel Subsystems...")
  pid = syscall(39, 0, 0, 0, 0, 0, 0)
  uid = syscall(102, 0, 0, 0, 0, 0, 0)
  @if pid <= 0 || uid < 0
    println("  [FAIL] STAGE 5: Invalid PID/UID")
    return 509
  @end

  tmp_file = "/tmp/maya_adv_grand_challenge.tmp"
  fd_w = syscall(2, tmp_file, 578, 420, 0, 0, 0)
  @if fd_w < 0
    println("  [FAIL] STAGE 5: sys_open (write) failed")
    return 510
  @end

  io_buf = mem_alloc(256)
  w_bytes = syscall(1, fd_w, io_buf, 256, 0, 0, 0)
  syscall(3, fd_w, 0, 0, 0, 0, 0)
  @if w_bytes != 256
    println("  [FAIL] STAGE 5: sys_write byte count mismatch")
    return 511
  @end

  fd_r = syscall(2, tmp_file, 0, 0, 0, 0, 0)
  r_sz = syscall(8, fd_r, 0, 2, 0, 0, 0)
  syscall(8, fd_r, 0, 0, 0, 0, 0)
  rd_buf = mem_alloc(256)
  r_bytes = syscall(0, fd_r, rd_buf, 256, 0, 0, 0)
  syscall(3, fd_r, 0, 0, 0, 0, 0)
  syscall(87, tmp_file, 0, 0, 0, 0, 0)

  @if r_sz != 256 || r_bytes != 256
    println("  [FAIL] STAGE 5: sys_read roundtrip mismatch")
    return 512
  @end

  mem_free(io_buf, 256)
  mem_free(rd_buf, 256)
  println("  [PASS] STAGE 5: Raw kernel file I/O roundtrip verified")

  println("================================================================")
  println("  ALL GRAND CHALLENGE STRESS GATES PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
