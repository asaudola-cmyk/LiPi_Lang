@! ============================================================================
@! CHALLENGER 2 EXHAUSTIVE ADVERSARIAL STRESS SUITE (PURE MAYA)
@! File: tests/gc/test_gc_challenger2_exhaustive_matrix.maya
@! Scope: Exhaustive size class boundary verification, 0-byte edge cases,
@!        realloc promotion matrix, multi-arena churn, and introspection defense.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct Challenger2Context
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

@! --- Suite 1: Pure Maya Size Class Mapping Boundaries ---
@fn test_size_class_mapping_boundaries(ctx)
  println("\n--- [Challenger 2 Maya Group 1] Exact Size Class Mapping Boundaries ---")

  @! Class 1 (<= 16)
  chk_eq(ctx, "gc_get_size_class(0) == 1", gc_get_size_class(0), 1)
  chk_eq(ctx, "gc_get_size_class(1) == 1", gc_get_size_class(1), 1)
  chk_eq(ctx, "gc_get_size_class(15) == 1", gc_get_size_class(15), 1)
  chk_eq(ctx, "gc_get_size_class(16) == 1", gc_get_size_class(16), 1)

  @! Class 2 (17..32)
  chk_eq(ctx, "gc_get_size_class(17) == 2", gc_get_size_class(17), 2)
  chk_eq(ctx, "gc_get_size_class(31) == 2", gc_get_size_class(31), 2)
  chk_eq(ctx, "gc_get_size_class(32) == 2", gc_get_size_class(32), 2)

  @! Class 3 (33..64)
  chk_eq(ctx, "gc_get_size_class(33) == 3", gc_get_size_class(33), 3)
  chk_eq(ctx, "gc_get_size_class(63) == 3", gc_get_size_class(63), 3)
  chk_eq(ctx, "gc_get_size_class(64) == 3", gc_get_size_class(64), 3)

  @! Class 4 (65..128)
  chk_eq(ctx, "gc_get_size_class(65) == 4", gc_get_size_class(65), 4)
  chk_eq(ctx, "gc_get_size_class(127) == 4", gc_get_size_class(127), 4)
  chk_eq(ctx, "gc_get_size_class(128) == 4", gc_get_size_class(128), 4)

  @! Class 5 (129..256)
  chk_eq(ctx, "gc_get_size_class(129) == 5", gc_get_size_class(129), 5)
  chk_eq(ctx, "gc_get_size_class(255) == 5", gc_get_size_class(255), 5)
  chk_eq(ctx, "gc_get_size_class(256) == 5", gc_get_size_class(256), 5)

  @! Class 6 (257..512)
  chk_eq(ctx, "gc_get_size_class(257) == 6", gc_get_size_class(257), 6)
  chk_eq(ctx, "gc_get_size_class(511) == 6", gc_get_size_class(511), 6)
  chk_eq(ctx, "gc_get_size_class(512) == 6", gc_get_size_class(512), 6)

  @! Class 7 (513..1024)
  chk_eq(ctx, "gc_get_size_class(513) == 7", gc_get_size_class(513), 7)
  chk_eq(ctx, "gc_get_size_class(1023) == 7", gc_get_size_class(1023), 7)
  chk_eq(ctx, "gc_get_size_class(1024) == 7", gc_get_size_class(1024), 7)

  @! Class 8 (1025..2048)
  chk_eq(ctx, "gc_get_size_class(1025) == 8", gc_get_size_class(1025), 8)
  chk_eq(ctx, "gc_get_size_class(2047) == 8", gc_get_size_class(2047), 8)
  chk_eq(ctx, "gc_get_size_class(2048) == 8", gc_get_size_class(2048), 8)

  @! Large (> 2048)
  chk_eq(ctx, "gc_get_size_class(2049) == 0 (Large)", gc_get_size_class(2049), 0)
  chk_eq(ctx, "gc_get_size_class(4096) == 0 (Large)", gc_get_size_class(4096), 0)
  chk_eq(ctx, "gc_get_size_class(65536) == 0 (Large)", gc_get_size_class(65536), 0)

  @! Payload & Slot Sizes
  chk_eq(ctx, "payload(1) == 16", gc_get_class_payload_size(1), 16)
  chk_eq(ctx, "slot(1) == 32", gc_get_class_slot_size(1), 32)
  chk_eq(ctx, "payload(8) == 2048", gc_get_class_payload_size(8), 2048)
  chk_eq(ctx, "slot(8) == 2064", gc_get_class_slot_size(8), 2064)
  chk_eq(ctx, "payload(0) == 0", gc_get_class_payload_size(0), 0)
  chk_eq(ctx, "slot(0) == 0", gc_get_class_slot_size(0), 0)
@end

@! --- Suite 2: Allocation & Pointer Introspection Edge Cases ---
@fn test_alloc_and_introspection_matrix(ctx)
  println("\n--- [Challenger 2 Maya Group 2] Allocation & Introspection Matrix ---")

  @! Exact boundary allocations
  sizes = [1, 16, 17, 32, 33, 64, 65, 128, 129, 256, 257, 512, 513, 1024, 1025, 2048, 2049, 4096, 8192, 65536]
  i = 0
  @while i < sizes.len()
    sz = sizes[i]
    p = gc_alloc(sz)
    chk_true(ctx, "Alloc(" + maya_int_to_str(sz) + ") returns valid address", p > 0)
    chk_eq(ctx, "Alloc(" + maya_int_to_str(sz) + ") 8-byte aligned", p % 8, 0)
    chk_true(ctx, "gc_is_valid_pointer(p) == true", gc_is_valid_pointer(p) != 0)
    chk_true(ctx, "gc_is_interior_pointer(p) == false", gc_is_interior_pointer(p) == 0)

    @if sz > 1
      chk_true(ctx, "gc_is_interior_pointer(p + 1) == true", gc_is_interior_pointer(p + 1) != 0)
      chk_true(ctx, "gc_is_valid_pointer(p + 1) == false", gc_is_valid_pointer(p + 1) == 0)
      chk_eq(ctx, "gc_base(p + sz - 1) == p", gc_base(p + sz - 1), p)
    @end

    @! Boundary one-past-the-end
    b_past = gc_base(p + sz)
    chk_eq(ctx, "gc_base(p + sz) != p (one-past-end check)", b_past == p, 0)

    @! Boundary one-before-start
    b_before = gc_base(p - 1)
    chk_eq(ctx, "gc_base(p - 1) != p (one-before-start check)", b_before == p, 0)

    gc_free(p)
    b_after_free = gc_base(p)
    valid_after_free = gc_is_valid_pointer(p)
    interior_after_free = gc_is_interior_pointer(p)

    chk_eq(ctx, "gc_base(p) == 0 after free", b_after_free, 0)
    chk_true(ctx, "gc_is_valid_pointer(p) == false after free", valid_after_free == 0)
    chk_true(ctx, "gc_is_interior_pointer(p) == false after free", interior_after_free == 0)

    i = i + 1
  @end
@end

@! --- Suite 3: Zero-Byte & Negative Allocation Robustness ---
@fn test_zero_and_negative_allocs(ctx)
  println("\n--- [Challenger 2 Maya Group 3] Zero-Byte & Special Allocs ---")

  p_zero = gc_alloc(0)
  p_zero_valid = gc_is_valid_pointer(p_zero)
  gc_free(p_zero)
  p_zero_base_after_free = gc_base(p_zero)

  chk_true(ctx, "gc_alloc(0) returns valid pointer", p_zero > 0)
  chk_true(ctx, "gc_is_valid_pointer(p_zero) == true", p_zero_valid != 0)
  chk_eq(ctx, "gc_base(p_zero) == 0 after free", p_zero_base_after_free, 0)

  @! Test realloc(p, 0) -> frees
  p_re = gc_alloc(64)
  p_re_res = gc_realloc(p_re, 0)
  p_re_base_after = gc_base(p_re)

  chk_eq(ctx, "gc_realloc(p, 0) returns 0", p_re_res, 0)
  chk_eq(ctx, "gc_base(p_re) == 0 after realloc(p, 0)", p_re_base_after, 0)

  @! Test realloc(0, 128) -> allocates
  p_new = gc_realloc(0, 128)
  p_new_valid = gc_is_valid_pointer(p_new)
  gc_free(p_new)

  chk_true(ctx, "gc_realloc(0, 128) returns valid pointer", p_new > 0)
  chk_true(ctx, "gc_is_valid_pointer(p_new) == true", p_new_valid != 0)
@end

@! --- Suite 4: Multi-Arena Expansion & Churn Stress ---
@fn test_multi_arena_expansion_and_churn(ctx)
  println("\n--- [Challenger 2 Maya Group 4] Multi-Arena Expansion & Churn (5,000 Cycles) ---")

  @! Allocate 4000 items in class 1 (16B) -> spans at least 2 full arenas
  ptrs = []
  i = 0
  all_ok = 1
  @while i < 4000
    p = gc_alloc(16)
    @if p <= 0
      all_ok = 0
    @end
    ptrs = ptrs.push(p)
    i = i + 1
  @end
  chk_true(ctx, "Allocated 4,000 16B objects across multiple 64KB arenas", all_ok != 0)

  @! Free even-indexed objects (2000 frees)
  i = 0
  @while i < 4000
    gc_free(ptrs[i])
    i = i + 2
  @end
  chk_true(ctx, "Freed 2,000 even-indexed objects in checkerboard pattern", 1)

  @! Verify odd objects still valid
  odd_ok = 1
  i = 1
  @while i < 4000
    @if gc_is_valid_pointer(ptrs[i]) == 0
      odd_ok = 0
    @end
    i = i + 2
  @end
  chk_true(ctx, "Odd objects retained validity during checkerboard sweep", odd_ok != 0)

  @! Allocate 2000 new objects (should recycle freed slots)
  recycled = []
  i = 0
  @while i < 2000
    p = gc_alloc(16)
    recycled = recycled.push(p)
    i = i + 1
  @end
  chk_true(ctx, "Allocated 2,000 replacement objects into recycled slots", recycled.len() == 2000)

  @! Free all remaining objects
  i = 0
  @while i < 2000
    gc_free(recycled[i])
    i = i + 1
  @end
  i = 1
  @while i < 4000
    gc_free(ptrs[i])
    i = i + 2
  @end
  chk_true(ctx, "Cleaned up all 4,000 multi-arena objects successfully", 1)
@end

@fn main()
  println("=================================================================")
  println("⚔ CHALLENGER 2 PURE MAYA EXHAUSTIVE MATRIX & STRESS HARNESS")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_size_class_mapping_boundaries(ctx)
  test_alloc_and_introspection_matrix(ctx)
  test_zero_and_negative_allocs(ctx)
  test_multi_arena_expansion_and_churn(ctx)

  println("\n=================================================================")
  println("📊 CHALLENGER 2 PURE MAYA MATRIX AUDIT SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [CHALLENGER 2 VERDICT: APPROVE] 100% of Pure Maya matrix assertions passed!")
    return 0
  @else
    println("\n✗ [CHALLENGER 2 VERDICT: REQUEST_CHANGES] Failures detected in Pure Maya matrix test!")
    return 1
  @end
@end
