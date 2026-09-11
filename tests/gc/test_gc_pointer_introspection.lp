@! ============================================================================
@! MAYA UNMOCKED GC TEST SUITE: POINTER INTROSPECTION (gc_base)
@! File: tests/gc/test_gc_pointer_introspection.maya
@! Scope: O(1) pointer validation, interior pointer resolution, freed pointer
@!        rejection, and invalid/alien address defense.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct IntroContext
  total: 0
  passed: 0
  failed: 0
@end

@fn i_assert_true(ctx, name, cond)
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

@fn i_assert_eq(ctx, name, actual, expected)
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

@fn test_base_and_interior_pointers(ctx)
  println("\n--- [Introspection Group 1] Base & Interior Pointers ---")

  @! Allocate 256-byte slab object
  p = gc_alloc(256)
  i_assert_true(ctx, "TC-INTRO-01.1: Allocated 256B buffer", p > 0)

  @! 1. Exact base pointer
  i_assert_eq(ctx, "TC-INTRO-01.2: gc_base(p) == p", gc_base(p), p)

  @! 2. Interior offset +1
  i_assert_eq(ctx, "TC-INTRO-02: gc_base(p + 1) == p", gc_base(p + 1), p)

  @! 3. Interior offset +64
  i_assert_eq(ctx, "TC-INTRO-03: gc_base(p + 64) == p", gc_base(p + 64), p)

  @! 4. Interior offset +255 (last byte)
  i_assert_eq(ctx, "TC-INTRO-04: gc_base(p + 255) == p", gc_base(p + 255), p)

  @! 5. Boundary offset before buffer
  i_assert_eq(ctx, "TC-INTRO-05: gc_base(p - 1) == 0 (preceding byte)", gc_base(p - 1), 0)
  i_assert_eq(ctx, "TC-INTRO-06: gc_base(p - 16) == 0 (header address)", gc_base(p - 16), 0)

  @! 6. Large Mmap Object (8192 bytes)
  p_large = gc_alloc(8192)
  i_assert_eq(ctx, "TC-INTRO-13.1: Large mmap base pointer", gc_base(p_large), p_large)
  i_assert_eq(ctx, "TC-INTRO-13.2: Large mmap interior (+4096)", gc_base(p_large + 4096), p_large)
  i_assert_eq(ctx, "TC-INTRO-13.3: Large mmap interior (+8191)", gc_base(p_large + 8191), p_large)

  gc_free(p)
  gc_free(p_large)
@end

@fn test_freed_pointer_rejection(ctx)
  println("\n--- [Introspection Group 2] Freed Pointer Rejection ---")

  p = gc_alloc(64)
  p_base_before = gc_base(p)
  i_assert_eq(ctx, "TC-INTRO-07.1: Active pointer returns valid base", p_base_before, p)

  @! Free object and check immediately
  gc_free(p)
  p_base_after = gc_base(p)
  p_interior_after = gc_base(p + 20)

  i_assert_eq(ctx, "TC-INTRO-07.2: gc_base(freed_ptr) returns 0", p_base_after, 0)
  i_assert_eq(ctx, "TC-INTRO-08: gc_base(freed_ptr + 20) returns 0", p_interior_after, 0)
@end

@fn test_invalid_and_alien_addresses(ctx)
  println("\n--- [Introspection Group 3] Invalid & Alien Address Defense ---")

  @! 1. NULL pointer
  i_assert_eq(ctx, "TC-INTRO-09: gc_base(0) == 0", gc_base(0), 0)

  @! 2. Negative pointer
  i_assert_eq(ctx, "TC-INTRO-10.1: gc_base(-1) == 0", gc_base(0 - 1), 0)
  i_assert_eq(ctx, "TC-INTRO-10.2: gc_base(-4096) == 0", gc_base(0 - 4096), 0)

  @! 3. Low unmapped address (e.g. 0x1000 = 4096)
  i_assert_eq(ctx, "TC-INTRO-11: gc_base(4096) == 0", gc_base(4096), 0)

  @! 4. Alien High Address (e.g. 0x7FFFFFFF0000)
  i_assert_eq(ctx, "TC-INTRO-12: gc_base(alien_high_addr) == 0", gc_base(140737488289792), 0)

  @! 5. Arbitrary integer values
  i_assert_eq(ctx, "TC-INTRO-14.1: gc_base(12345) == 0", gc_base(12345), 0)
  i_assert_eq(ctx, "TC-INTRO-14.2: gc_base(999999) == 0", gc_base(999999), 0)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA NATIVE GC POINTER INTROSPECTION SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_base_and_interior_pointers(ctx)
  test_freed_pointer_rejection(ctx)
  test_invalid_and_alien_addresses(ctx)

  println("\n=================================================================")
  println("📊 POINTER INTROSPECTION TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of pointer introspection tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more pointer introspection tests failed.")
    return 1
  @end
@end
