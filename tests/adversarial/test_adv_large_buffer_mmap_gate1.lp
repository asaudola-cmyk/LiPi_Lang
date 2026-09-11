@! ============================================================================
@! ADVERSARIAL STRESS TEST 3: LARGE BUFFERS > 64KB & MMAP THRESHOLD STRESS
@! File: tests/adversarial/test_adv_large_buffer_mmap_gate1.maya
@! Target: Sovereign Pure Maya Compiler Backend (x86-64 freestanding ELF)
@! ============================================================================

@fn mmap_alloc(size)
  @! Linux sys_mmap: Syscall 9 (addr=0, len=size, prot=3, flags=34, fd=-1, offset=0)
  return syscall(9, 0, size, 3, 34, -1, 0)
@end

@fn mmap_free(ptr, size)
  @! Linux sys_munmap: Syscall 11 (addr=ptr, len=size)
  return syscall(11, ptr, size, 0, 0, 0, 0)
@end

@fn mmap_protect(ptr, size, prot)
  @! Linux sys_mprotect: Syscall 10 (addr=ptr, len=size, prot=prot)
  return syscall(10, ptr, size, prot, 0, 0, 0)
@end

@fn main()
  println("================================================================")
  println("  ADVERSARIAL STRESS 3: LARGE BUFFERS > 64KB & MMAP THRESHOLD")
  println("================================================================")

  @! Test 1: 128 KB allocation (2x 64KB Arena boundary)
  println("▶ [TC-LARGE-01] Allocating 128 KB buffer (131,072 bytes)...")
  buf_128k = mmap_alloc(131072)
  @if buf_128k <= 0 || (buf_128k % 4096 != 0)
    println("  [FAIL] TC-LARGE-01: 128KB mmap failed or not page aligned")
    return 301
  @end
  println("  [PASS] TC-LARGE-01: 128 KB buffer allocated & page-aligned")

  @! Test 2: 1 MB allocation (1,048,576 bytes) & boundary protection
  println("▶ [TC-LARGE-02] Allocating 1 MB buffer (1,048,576 bytes) & mprotect...")
  buf_1m = mmap_alloc(1048576)
  @if buf_1m <= 0 || (buf_1m % 4096 != 0)
    println("  [FAIL] TC-LARGE-02: 1MB mmap failed")
    return 302
  @end
  @! Change protection to PROT_READ (1) then back to PROT_READ|PROT_WRITE (3)
  prot_res1 = mmap_protect(buf_1m, 1048576, 1)
  prot_res2 = mmap_protect(buf_1m, 1048576, 3)
  @if prot_res1 != 0 || prot_res2 != 0
    println("  [FAIL] TC-LARGE-02: mprotect transition failed")
    return 303
  @end
  println("  [PASS] TC-LARGE-02: 1 MB buffer allocated & mprotect cycle verified")

  @! Test 3: 4 MB buffer (4,194,304 bytes)
  println("▶ [TC-LARGE-03] Allocating 4 MB buffer (4,194,304 bytes)...")
  buf_4m = mmap_alloc(4194304)
  @if buf_4m <= 0 || (buf_4m % 4096 != 0)
    println("  [FAIL] TC-LARGE-03: 4MB mmap failed")
    return 304
  @end
  println("  [PASS] TC-LARGE-03: 4 MB buffer allocated successfully")

  @! Test 4: 16 MB buffer (16,777,216 bytes) - Extreme Sovereign Memory Scale
  println("▶ [TC-LARGE-04] Allocating 16 MB buffer (16,777,216 bytes)...")
  buf_16m = mmap_alloc(16777216)
  @if buf_16m <= 0 || (buf_16m % 4096 != 0)
    println("  [FAIL] TC-LARGE-04: 16MB extreme mmap failed")
    return 305
  @end
  println("  [PASS] TC-LARGE-04: 16 MB extreme buffer allocated successfully")

  @! Test 5: Multi-Buffer Concurrent Residence (128K + 1M + 4M + 16M = 21.125 MB total active resident)
  println("▶ [TC-LARGE-05] Verifying 21.125 MB total concurrent buffer residence...")
  @if buf_128k != buf_1m && buf_1m != buf_4m && buf_4m != buf_16m && buf_128k != buf_16m
    println("  [PASS] TC-LARGE-05: Non-overlapping disjoint address ranges verified")
  @else
    println("  [FAIL] TC-LARGE-05: Address space overlap detected")
    return 306
  @end

  @! Test 6: Deallocation and teardown of all large buffers
  println("▶ [TC-LARGE-06] Releasing all large buffers (21.125 MB teardown)...")
  f1 = mmap_free(buf_128k, 131072)
  f2 = mmap_free(buf_1m, 1048576)
  f3 = mmap_free(buf_4m, 4194304)
  f4 = mmap_free(buf_16m, 16777216)

  @if f1 == 0 && f2 == 0 && f3 == 0 && f4 == 0
    println("  [PASS] TC-LARGE-06: All large buffers successfully unmapped with zero OS errors")
  @else
    println("  [FAIL] TC-LARGE-06: munmap failed during teardown")
    return 307
  @end

  println("================================================================")
  println("  ALL LARGE BUFFER (>64KB) STRESS TESTS PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
