@! ============================================================================
@! MAYA UNMOCKED GC TEST SUITE: FREE-LIST RECYCLING & HEAP CONTAINMENT
@! File: tests/gc/test_gc_free_recycle.maya
@! Scope: Immediate LIFO/FIFO slot recycling, 100-block slab arena reuse,
@!        checkerboard gap filling, and mmap munmap validation.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct RecycleContext
  total: 0
  passed: 0
  failed: 0
@end

@fn rc_assert_true(ctx, name, cond)
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

@fn rc_assert_eq(ctx, name, actual, expected)
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

@fn test_immediate_slot_recycling(ctx)
  println("\n--- [Recycle Group 1] Immediate LIFO Slot Reuse ---")

  @! Allocate 64-byte block
  p1 = gc_alloc(64)
  p1_valid = (p1 > 0)
  
  @! Free block and immediately check base and reallocate before any string allocations
  gc_free(p1)
  p1_base_after_free = gc_base(p1)
  p2 = gc_alloc(64)
  p2_base = gc_base(p2)

  rc_assert_true(ctx, "TC-RECYCLE-01.1: First alloc(64) returns valid address", p1_valid)
  rc_assert_eq(ctx, "TC-RECYCLE-01.2: gc_base(p1) is 0 after free", p1_base_after_free, 0)
  rc_assert_eq(ctx, "TC-RECYCLE-01.3: Immediate next alloc(64) reuses exact same memory slot", p2, p1)
  rc_assert_eq(ctx, "TC-RECYCLE-01.4: gc_base(p2) is active again", p2_base, p2)

  gc_free(p2)
@end

@fn test_100_block_slab_recycling(ctx)
  println("\n--- [Recycle Group 2] 100-Block Slab Arena Fill & Full Recycling ---")

  @! Step 1: Allocate 100 blocks of 128 bytes
  ptrs = []
  i = 0
  @while i < 100
    p = gc_alloc(128)
    ptrs = ptrs.push(p)
    i = i + 1
  @end
  rc_assert_eq(ctx, "TC-RECYCLE-02.1: 100 blocks allocated", ptrs.len(), 100)

  @! Step 2: Free all 100 blocks
  i = 0
  @while i < 100
    gc_free(ptrs[i])
    i = i + 1
  @end

  @! Step 3: Re-allocate 100 blocks of 128 bytes
  new_ptrs = []
  i = 0
  @while i < 100
    np = gc_alloc(128)
    new_ptrs = new_ptrs.push(np)
    i = i + 1
  @end
  rc_assert_eq(ctx, "TC-RECYCLE-02.2: 100 recycled blocks allocated", new_ptrs.len(), 100)

  @! Assert that all new_ptrs are within the same address pool as original ptrs
  all_recycled = 1
  i = 0
  @while i < 100
    np = new_ptrs[i]
    found = 0
    j = 0
    @while j < 100
      @if ptrs[j] == np
        found = 1
      @end
      j = j + 1
    @end
    @if found == 0
      all_recycled = 0
    @end
    i = i + 1
  @end

  rc_assert_true(ctx, "TC-RECYCLE-02.3: 100% of reallocations reused existing slab slots without heap expansion", all_recycled != 0)

  @! Free all
  i = 0
  @while i < 100
    gc_free(new_ptrs[i])
    i = i + 1
  @end
@end

@fn test_checkerboard_gap_filling(ctx)
  println("\n--- [Recycle Group 3] Checkerboard Staggered Free & Gap Filling ---")

  @! Allocate 40 blocks of 700 bytes (Class 6: 1024B)
  blocks = []
  i = 0
  @while i < 40
    blocks = blocks.push(gc_alloc(700))
    i = i + 1
  @end

  @! Free odd-indexed blocks (indices 1, 3, 5, ..., 39 = 20 blocks)
  freed_slots = []
  i = 1
  @while i < 40
    gc_free(blocks[i])
    freed_slots = freed_slots.push(blocks[i])
    i = i + 2
  @end

  @! Immediately reallocate 20 new blocks of 700 bytes
  reclaimed_blocks = []
  i = 0
  @while i < 20
    reclaimed_blocks = reclaimed_blocks.push(gc_alloc(700))
    i = i + 1
  @end

  rc_assert_eq(ctx, "TC-RECYCLE-03.1: 20 odd blocks freed", freed_slots.len(), 20)

  @! Verify that the 20 newly allocated blocks correspond to the 20 freed slots
  reclaimed_all_freed = 1
  i = 0
  @while i < 20
    rp = reclaimed_blocks[i]
    found = 0
    j = 0
    @while j < 20
      @if freed_slots[j] == rp
        found = 1
      @end
      j = j + 1
    @end
    @if found == 0
      reclaimed_all_freed = 0
    @end
    i = i + 1
  @end

  rc_assert_true(ctx, "TC-RECYCLE-03.2: Staggered freed slots were 100% gap-filled by new allocations", reclaimed_all_freed != 0)

  @! Clean up remaining even blocks and reclaimed blocks
  i = 0
  @while i < 40
    @if i % 2 == 0
      gc_free(blocks[i])
    @end
    i = i + 1
  @end
  i = 0
  @while i < 20
    gc_free(reclaimed_blocks[i])
    i = i + 1
  @end
@end

@fn test_large_mmap_munmap(ctx)
  println("\n--- [Recycle Group 4] Large Object Munmap Release ---")

  p_large = gc_alloc(1048576) @! 1MB
  rc_assert_true(ctx, "TC-RECYCLE-04.1: Large mmap allocated", p_large > 0)
  rc_assert_eq(ctx, "TC-RECYCLE-04.2: gc_base(p_large) active", gc_base(p_large), p_large)

  gc_free(p_large)
  rc_assert_eq(ctx, "TC-RECYCLE-04.3: gc_base(p_large) is 0 after munmap", gc_base(p_large), 0)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA NATIVE GC FREE-LIST RECYCLING & HEAP REUSE SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_immediate_slot_recycling(ctx)
  test_100_block_slab_recycling(ctx)
  test_checkerboard_gap_filling(ctx)
  test_large_mmap_munmap(ctx)

  println("\n=================================================================")
  println("📊 FREE-LIST RECYCLING TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of free-list recycling tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more free-list recycling tests failed.")
    return 1
  @end
@end
