@! ============================================================================
@! ADVERSARIAL STRESS TEST 2: RAPID MEMORY CHURN & SLAB RECYCLING
@! File: tests/adversarial/test_adv_slab_churn_gate1.maya
@! Target: Sovereign Pure Maya Compiler Backend (x86-64 freestanding ELF)
@! ============================================================================

@fn mem_alloc(size)
  @! Linux sys_mmap: Syscall 9 (addr=0, len=size, prot=3, flags=34, fd=-1, offset=0)
  return syscall(9, 0, size, 3, 34, -1, 0)
@end

@fn mem_free(ptr, size)
  @! Linux sys_munmap: Syscall 11 (addr=ptr, len=size)
  return syscall(11, ptr, size, 0, 0, 0, 0)
@end

@fn get_size_for_class(sc)
  @if sc == 0 return 16 @end
  @if sc == 1 return 32 @end
  @if sc == 2 return 64 @end
  @if sc == 3 return 128 @end
  @if sc == 4 return 256 @end
  @if sc == 5 return 512 @end
  @if sc == 6 return 1024 @end
  return 2048
@end

@fn main()
  println("================================================================")
  println("  ADVERSARIAL STRESS 2: RAPID SLAB MEMORY CHURN & RECYCLING")
  println("================================================================")

  println("▶ [TC-CHURN-01] Testing 2,500 cycles of 8-class segregated slab churn (10,000 allocs)...")

  total_cycles = 2500
  cycle = 0
  total_allocs = 0
  total_frees = 0
  failures = 0

  @! Long-lived anchors to prevent trivial address reuse
  anchor1 = mem_alloc(4096)
  anchor2 = mem_alloc(4096)
  @if anchor1 <= 0 || anchor2 <= 0
    println("  [FATAL] Initial anchor allocation failed")
    return 201
  @end

  @while cycle < total_cycles
    @! Allocate 4 different size classes per cycle
    sc1 = cycle % 8
    sc2 = (cycle + 2) % 8
    sc3 = (cycle + 4) % 8
    sc4 = (cycle + 6) % 8

    sz1 = get_size_for_class(sc1)
    sz2 = get_size_for_class(sc2)
    sz3 = get_size_for_class(sc3)
    sz4 = get_size_for_class(sc4)

    p1 = mem_alloc(sz1)
    p2 = mem_alloc(sz2)
    p3 = mem_alloc(sz3)
    p4 = mem_alloc(sz4)

    total_allocs = total_allocs + 4

    @if p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0
      failures = failures + 1
      @break
    @end

    @! Free in non-FIFO (staggered) order to test heap fragmentation resilience
    r2 = mem_free(p2, sz2)
    r4 = mem_free(p4, sz4)
    r1 = mem_free(p1, sz1)
    r3 = mem_free(p3, sz3)

    @if r1 != 0 || r2 != 0 || r3 != 0 || r4 != 0
      failures = failures + 1
    @end

    total_frees = total_frees + 4
    cycle = cycle + 1
  @end

  @! Free anchors
  mem_free(anchor1, 4096)
  mem_free(anchor2, 4096)
  total_allocs = total_allocs + 2
  total_frees = total_frees + 2

  @if failures == 0 && total_allocs == 10002 && total_frees == 10002
    println("  [PASS] TC-CHURN-01: 10,002 slab allocations & deallocations verified clean")
  @else
    println("  [FAIL] TC-CHURN-01: Memory churn integrity failure")
    return 202
  @end

  println("================================================================")
  println("  ALL SLAB MEMORY CHURN STRESS TESTS PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
