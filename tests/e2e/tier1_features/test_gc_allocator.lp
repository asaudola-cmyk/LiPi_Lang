// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Memory Allocator & GC PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: gc, allocator, slab, mmap, realloc, free

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: PURE MAYA GC & MEMORY ALLOCATOR
@! File: tests/e2e/tier1_features/test_gc_allocator.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Memory Allocator & Slab Arenas")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-GC-01: Slab Arena Allocations Across Size Classes (16B, 64B, 512B, 2048B)
  total = total + 1
  p1 = gc_alloc(16)
  p2 = gc_alloc(64)
  p3 = gc_alloc(512)
  p4 = gc_alloc(2048)
  all_valid = p1 > 0 && p2 > 0 && p3 > 0 && p4 > 0
  all_aligned = (p1 % 8 == 0) && (p2 % 8 == 0) && (p3 % 8 == 0) && (p4 % 8 == 0)
  @if all_valid && all_aligned
    passed = passed + 1
    println("  [PASS] TC-GC-01: Segregated slab allocation across size classes (16B, 64B, 512B, 2048B)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC-01: Slab arena allocation")
  @end

  @! TC-GC-02: Large Object Direct Mmap Allocation (>2048B: 64KB)
  total = total + 1
  p_large = gc_alloc(65536)
  p_large_valid = p_large > 0 && (p_large % 8 == 0)
  @if p_large_valid
    passed = passed + 1
    println("  [PASS] TC-GC-02: Large object direct mmap allocation (64KB payload)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC-02: Large object mmap allocation")
  @end

  @! TC-GC-03: Pointer Introspection & gc_base Lookup
  total = total + 1
  ptr = gc_alloc(128)
  base = gc_base(ptr)
  is_valid = gc_is_valid_pointer(ptr)
  @if base == ptr && is_valid == 1
    passed = passed + 1
    println("  [PASS] TC-GC-03: Object base pointer introspection (gc_base == ptr, is_valid == 1)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC-03: Pointer introspection")
  @end

  @! TC-GC-04: Memory Reallocation (gc_realloc)
  total = total + 1
  p_orig = gc_alloc(32)
  p_grown = gc_realloc(p_orig, 256)
  is_grown_valid = p_grown > 0 && (p_grown % 8 == 0)
  @if is_grown_valid
    passed = passed + 1
    println("  [PASS] TC-GC-04: Memory reallocation from 32B to 256B (gc_realloc)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC-04: Memory reallocation")
  @end

  @! TC-GC-05: Explicit Free & Freed Pointer Rejection (gc_free)
  total = total + 1
  p_to_free = gc_alloc(64)
  p_base_before = gc_base(p_to_free)
  gc_free(p_to_free)
  p_base_after = gc_base(p_to_free)
  @if p_base_before == p_to_free && p_base_after == 0
    passed = passed + 1
    println("  [PASS] TC-GC-05: Explicit memory deallocation (gc_base(freed) == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC-05: Explicit memory deallocation")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Memory Allocator & GC PASSED")
    return 0
  @else
    println("✗ Feature: Memory Allocator & GC FAILED")
    return 1
  @end
@end
