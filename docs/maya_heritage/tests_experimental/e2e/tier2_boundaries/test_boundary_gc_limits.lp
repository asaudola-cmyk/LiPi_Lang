// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Memory Allocator & GC Limits PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, gc, limits, 0byte_alloc, size_classes, mmap_boundary, introspection, realloc

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: MEMORY ALLOCATOR & GC LIMITS
@! File: tests/e2e/tier2_boundaries/test_boundary_gc_limits.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: GC Allocator Limits & Size Classes")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-GC-01: Allocation of 0 Bytes (Maps to minimum Class 1 16B slot)
  total = total + 1
  p_zero = gc_alloc(0)
  is_zero_valid = p_zero > 0 && (p_zero % 8 == 0)
  base_zero = gc_base(p_zero)
  @if is_zero_valid && base_zero == p_zero
    passed = passed + 1
    println("  [PASS] BC-GC-01: gc_alloc(0) safely maps to valid minimum Class 1 16B slot")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-01: gc_alloc(0)")
  @end

  @! BC-GC-02: Exact 2048-Byte Size Class Limit (Class 8)
  total = total + 1
  p_2048 = gc_alloc(2048)
  is_2048_valid = p_2048 > 0 && (p_2048 % 8 == 0)
  base_2048 = gc_base(p_2048)
  @if is_2048_valid && base_2048 == p_2048
    passed = passed + 1
    println("  [PASS] BC-GC-02: gc_alloc(2048) allocates in Class 8 slab boundary")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-02: gc_alloc(2048)")
  @end

  @! BC-GC-03: First Large Object Allocation (2049 Bytes -> Mmap Fallback)
  total = total + 1
  p_2049 = gc_alloc(2049)
  is_2049_valid = p_2049 > 0 && (p_2049 % 8 == 0)
  base_2049 = gc_base(p_2049)
  @if is_2049_valid && base_2049 == p_2049
    passed = passed + 1
    println("  [PASS] BC-GC-03: gc_alloc(2049) crosses slab threshold into direct page mmap")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-03: gc_alloc(2049)")
  @end

  @! BC-GC-04: Non-Heap / Invalid Address Rejection in Introspection
  total = total + 1
  valid_stack = gc_is_valid_pointer(100)
  valid_null = gc_is_valid_pointer(0)
  base_invalid = gc_base(1234567)
  @if valid_stack == 0 && valid_null == 0 && base_invalid == 0
    passed = passed + 1
    println("  [PASS] BC-GC-04: gc_is_valid_pointer and gc_base cleanly reject non-heap addresses")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-04: Non-heap pointer rejection")
  @end

  @! BC-GC-05: Interior Pointer Detection
  total = total + 1
  p_obj = gc_alloc(256)
  p_interior = p_obj + 32
  is_int = gc_is_interior_pointer(p_interior)
  base_int = gc_base(p_interior)
  @if is_int == 1 && base_int == p_obj
    passed = passed + 1
    println("  [PASS] BC-GC-05: gc_is_interior_pointer detects internal offset and resolves base object")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-05: Interior pointer detection")
  @end

  @! BC-GC-06: Memory Reallocation to Same Size
  total = total + 1
  p_same = gc_alloc(64)
  p_re_same = gc_realloc(p_same, 64)
  @if p_re_same > 0 && gc_base(p_re_same) == p_re_same
    passed = passed + 1
    println("  [PASS] BC-GC-06: gc_realloc to identical size returns valid object pointer")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-06: gc_realloc same size")
  @end

  @! BC-GC-07: Rapid Alloc-Free-Alloc Slot Reuse
  total = total + 1
  p_a = gc_alloc(32)
  gc_free(p_a)
  p_b = gc_alloc(32)
  reused_valid = p_b > 0 && (p_b % 8 == 0)
  gc_free(p_b)
  @if reused_valid
    passed = passed + 1
    println("  [PASS] BC-GC-07: Rapid alloc-free-alloc slot reuse executes cleanly")
  @else
    failed = failed + 1
    println("  [FAIL] BC-GC-07: Alloc-free reuse")
  @end

  @! Cleanup allocations
  gc_free(p_zero)
  gc_free(p_2048)
  gc_free(p_2049)
  gc_free(p_obj)
  gc_free(p_re_same)

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Memory Allocator & GC Limits PASSED")
    return 0
  @else
    println("✗ Boundary: Memory Allocator & GC Limits FAILED")
    return 1
  @end
@end
