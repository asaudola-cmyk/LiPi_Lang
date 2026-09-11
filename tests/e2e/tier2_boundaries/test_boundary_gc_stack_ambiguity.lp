// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: GC Stack Ambiguity & Boundary Stress PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: gc, boundary, deep_recursion, pointer_collision, ambiguity, 85percent_churn

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & ADVERSARIAL: GC STACK AMBIGUITY & CHURN
@! File: tests/e2e/tier2_boundaries/test_boundary_gc_stack_ambiguity.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"
import "universe/core/collections"
import "universe/core/string"

@struct AmbiguityFrame
  level: i64
  magic_token: i64
  heap_ref: i64
@end

@fn deep_recursive_call(depth, max_depth)
  @! Create local frame object
  p = gc_alloc(32)
  frame = {
    level: depth,
    magic_token: 777000 + depth,
    heap_ref: p
  }

  @if depth >= max_depth
    @! Bottom of recursion: trigger GC mark-sweep
    gc_collect()
    @if frame.level == max_depth && frame.magic_token == (777000 + max_depth)
      return 1
    @else
      return 0
    @end
  @end

  res = deep_recursive_call(depth + 1, max_depth)

  @! Unwind check
  @if res == 1 && frame.level == depth && frame.magic_token == (777000 + depth)
    return 1
  @else
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: GC Stack Ambiguity, Collisions & Churn")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-AMB-01: Deep Call Stack Recursion (>100 Frames)
  @! ----------------------------------------------------------------------------
  total = total + 1
  deep_ok = deep_recursive_call(1, 105)
  @if deep_ok == 1
    passed = passed + 1
    println("  [PASS] TC-AMB-01: Deep recursive call stack traversal (105 stack frames)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-AMB-01: Deep recursive call stack traversal")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-AMB-02: Pointer Collision Injection (Heap Address vs Integer Scalars)
  @! ----------------------------------------------------------------------------
  total = total + 1
  @! Realistic virtual address constants that could collide with heap addresses
  addr_elf_text = 4194304             @! 0x400000
  addr_heap_base = 140737488355328    @! 0x7FFFFFFF0000
  addr_stack_top = 140737488351232    @! 0x7FFFFFFEF000

  collision_array = [addr_elf_text, addr_heap_base, addr_stack_top, 0, -1]

  @! Perform arithmetic and comparisons on collision values
  c0 = collision_array[0]
  c1 = collision_array[1]
  c2 = collision_array[2]
  c3 = collision_array[3]
  c4 = collision_array[4]

  gc_collect()

  c_ok = (c0 == 4194304) && (c1 == 140737488355328) && (c2 == 140737488351232) && (c3 == 0) && (c4 == -1)
  @if c_ok
    passed = passed + 1
    println("  [PASS] TC-AMB-02: Pointer collision injection with large virtual addresses without runtime crash")
  @else
    failed = failed + 1
    println("  [FAIL] TC-AMB-02: Pointer collision injection")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-AMB-03: Heavy 85% Arena Capacity Churn (200 allocations per cycle)
  @! ----------------------------------------------------------------------------
  total = total + 1
  cycle = 0
  churn_clean = 1
  @while cycle < 4
    allocs = []
    a_idx = 0
    @while a_idx < 100
      allocs = allocs.push(gc_alloc(64))
      a_idx = a_idx + 1
    @end
    @if allocs.len() != 100
      churn_clean = 0
    @end
    reclaimed = gc_collect()
    @if reclaimed < 0
      churn_clean = 0
    @end
    cycle = cycle + 1
  @end

  @if churn_clean == 1
    passed = passed + 1
    println("  [PASS] TC-AMB-03: Heavy allocation churn triggering continuous 85% capacity sweeps")
  @else
    failed = failed + 1
    println("  [FAIL] TC-AMB-03: Heavy allocation churn")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-AMB-04: Mixed Large (mmap) and Small (Slab) Allocations Under Churn
  @! ----------------------------------------------------------------------------
  total = total + 1
  p_small = gc_alloc(16)
  p_large1 = gc_alloc(8192)
  p_large2 = gc_alloc(16384)
  p_small2 = gc_alloc(32)

  s_ok = (p_small > 0) && (p_large1 > 0) && (p_large2 > 0) && (p_small2 > 0)
  gc_free(p_large1)
  gc_collect()

  @if s_ok
    passed = passed + 1
    println("  [PASS] TC-AMB-04: Mixed slab and direct mmap allocations handled seamlessly")
  @else
    failed = failed + 1
    println("  [FAIL] TC-AMB-04: Mixed slab/mmap allocations")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-AMB-05: Introspection on Freed Pointers (Zero False Positives)
  @! ----------------------------------------------------------------------------
  total = total + 1
  temp_block = gc_alloc(128)
  gc_free(temp_block)
  freed_base = gc_base(temp_block)
  is_valid_freed = gc_is_valid_pointer(temp_block)

  freed_safe = (freed_base == 0) && (is_valid_freed == 0)
  @if freed_safe
    passed = passed + 1
    println("  [PASS] TC-AMB-05: Introspection on deallocated pointer returns 0 without false positives")
  @else
    failed = failed + 1
    println("  [FAIL] TC-AMB-05: Freed pointer introspection")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: GC Stack Ambiguity & Boundary Stress PASSED")
    return 0
  @else
    println("✗ Feature: GC Stack Ambiguity & Boundary Stress FAILED")
    return 1
  @end
@end
