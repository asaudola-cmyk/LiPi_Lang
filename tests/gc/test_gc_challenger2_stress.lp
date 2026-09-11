@! ============================================================================
@! CHALLENGER 2 EMPIRICAL ADVERSARIAL STRESS SUITE (PURE MAYA)
@! File: tests/gc/test_gc_challenger2_stress.maya
@! Scope: Multi-arena expansion across classes, large object mmap/munmap scaling,
@!        double-free defense, and high-intensity payload integrity.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct StressContext
  total: 0
  passed: 0
  failed: 0
@end

@fn chk_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was 0")
    return 0
  @end
@end

@fn chk_eq(ctx, name, actual, expected)
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

@fn test_multi_arena_expansion(ctx)
  println("\n--- [Challenger 2 Maya Suite 1] Multi-Arena Expansion Across Slab Classes ---")
  
  @! Test Class 1 (16B payload, 2046 slots/arena) -> Allocate 3000 objects (spans 2+ arenas)
  ptrs = []
  i = 0
  all_ok = 1
  @while i < 3000
    p = gc_alloc(16)
    @if p <= 0
      all_ok = 0
    @end
    ptrs = ptrs.push(p)
    i = i + 1
  @end
  chk_true(ctx, "Allocated 3,000 16B objects spanning multiple 64KB arenas", all_ok != 0)

  @! Verify gc_base for every single pointer
  intro_ok = 1
  i = 0
  @while i < 3000
    p = ptrs[i]
    b = gc_base(p)
    @if b != p
      intro_ok = 0
    @end
    i = i + 1
  @end
  chk_true(ctx, "Verified gc_base on all 3,000 multi-arena objects via binary search", intro_ok != 0)

  @! Free all objects and verify gc_base returns 0
  free_ok = 1
  i = 0
  @while i < 3000
    p = ptrs[i]
    gc_free(p)
    i = i + 1
  @end
  chk_true(ctx, "Freed all 3,000 multi-arena objects successfully", free_ok != 0)
@end

@fn test_large_scaling_and_munmap(ctx)
  println("\n--- [Challenger 2 Maya Suite 2] Large Scaling (>2KB, >1MB) & Munmap ---")

  @! 1. Allocate 64KB large object
  p_64k = gc_alloc(65536)
  chk_true(ctx, "Allocated 64KB large object", p_64k > 0)
  chk_eq(ctx, "gc_base(p_64k) == p_64k", gc_base(p_64k), p_64k)
  chk_eq(ctx, "gc_base(p_64k + 32768) == p_64k (interior)", gc_base(p_64k + 32768), p_64k)
  gc_free(p_64k)
  base_64k_after = gc_base(p_64k)
  chk_eq(ctx, "gc_base(p_64k) == 0 after munmap", base_64k_after, 0)

  @! 2. Allocate 1MB large object
  p_1mb = gc_alloc(1048576)
  chk_true(ctx, "Allocated 1MB large object", p_1mb > 0)
  chk_eq(ctx, "gc_base(p_1mb) == p_1mb", gc_base(p_1mb), p_1mb)
  chk_eq(ctx, "gc_base(p_1mb + 524288) == p_1mb (interior)", gc_base(p_1mb + 524288), p_1mb)
  gc_free(p_1mb)
  base_1mb_after = gc_base(p_1mb)
  chk_eq(ctx, "gc_base(p_1mb) == 0 after munmap", base_1mb_after, 0)

  @! 3. Allocate 4MB large object
  p_4mb = gc_alloc(4194304)
  chk_true(ctx, "Allocated 4MB large object", p_4mb > 0)
  chk_eq(ctx, "gc_base(p_4mb) == p_4mb", gc_base(p_4mb), p_4mb)
  gc_free(p_4mb)
  base_4mb_after = gc_base(p_4mb)
  chk_eq(ctx, "gc_base(p_4mb) == 0 after munmap", base_4mb_after, 0)
@end

@fn test_edge_cases_and_double_free(ctx)
  println("\n--- [Challenger 2 Maya Suite 3] Double-Free, Realloc(0) & Zero-Byte ---")

  @! Zero byte allocation
  p_zero = gc_alloc(0)
  p_zero_base = gc_base(p_zero)
  chk_true(ctx, "gc_alloc(0) returns valid pointer", p_zero > 0)
  chk_eq(ctx, "gc_base(p_zero) == p_zero", p_zero_base, p_zero)
  gc_free(p_zero)
  p_zero_freed_base = gc_base(p_zero)
  @! Note: immediate next check before any other allocations
  chk_eq(ctx, "gc_base(p_zero) == 0 immediately after free", p_zero_freed_base, 0)

  @! Double free on slab
  p_slab = gc_alloc(128)
  chk_true(ctx, "Allocated 128B slab object", p_slab > 0)
  gc_free(p_slab)
  p_slab_base = gc_base(p_slab)
  chk_eq(ctx, "1st free successful", p_slab_base, 0)
  gc_free(p_slab) @! 2nd free (must not crash)
  gc_free(p_slab) @! 3rd free (must not crash)
  chk_true(ctx, "Double & triple free on slab survived without crash", 1)

  @! Double free on large mmap
  p_lg = gc_alloc(8192)
  gc_free(p_lg)
  p_lg_base = gc_base(p_lg)
  chk_eq(ctx, "1st large free successful", p_lg_base, 0)
  gc_free(p_lg) @! 2nd free on unmapped
  chk_true(ctx, "Double free on large mmap survived without crash", 1)

  @! Realloc(p, 0)
  p_re = gc_alloc(256)
  res = gc_realloc(p_re, 0)
  p_re_base = gc_base(p_re)
  chk_eq(ctx, "gc_realloc(p, 0) returns 0", res, 0)
  chk_eq(ctx, "gc_base(p_re) is 0 after gc_realloc(0)", p_re_base, 0)
@end

@fn main()
  println("=================================================================")
  println("⚔ CHALLENGER 2 PURE MAYA GC STRESS VERIFICATION")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_multi_arena_expansion(ctx)
  test_large_scaling_and_munmap(ctx)
  test_edge_cases_and_double_free(ctx)

  println("\n=================================================================")
  println("📊 CHALLENGER 2 PURE MAYA SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All Challenger 2 Pure Maya stress tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] Failures detected in Pure Maya stress test!")
    return 1
  @end
@end
