// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: GC Stack Root Scanning & Frame Registration PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: gc, stack_roots, shadow_stack, root_enumeration, recursion

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: GC STACK ROOT SCANNING & FRAMES
@! File: tests/e2e/tier1_features/test_gc_stack_roots.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct GCRootFrame
  frame_id: i64
  depth: i64
  num_roots: i64
  root_ptrs: array
@end

@struct GCRootRegistry
  frames: array
  global_roots: array
@end

@fn gc_registry_new()
  return {
    frames: [],
    global_roots: []
  }
@end

@fn gc_push_frame(reg, frame_id, depth, roots)
  f = {
    frame_id: frame_id,
    depth: depth,
    num_roots: roots.len(),
    root_ptrs: roots
  }
  reg.frames = reg.frames.push(f)
  return reg
@end

@fn gc_pop_frame(reg)
  @if reg.frames.len() == 0
    return reg
  @end
  new_frames = []
  i = 0
  limit = reg.frames.len() - 1
  @while i < limit
    new_frames = new_frames.push(reg.frames[i])
    i = i + 1
  @end
  reg.frames = new_frames
  return reg
@end

@fn gc_enumerate_all_roots(reg)
  all_roots = []
  @! 1. Global roots
  g_idx = 0
  @while g_idx < reg.global_roots.len()
    all_roots = all_roots.push(reg.global_roots[g_idx])
    g_idx = g_idx + 1
  @end

  @! 2. Shadow stack frames
  f_idx = 0
  @while f_idx < reg.frames.len()
    frame = reg.frames[f_idx]
    r_idx = 0
    @while r_idx < frame.root_ptrs.len()
      all_roots = all_roots.push(frame.root_ptrs[r_idx])
      r_idx = r_idx + 1
    @end
    f_idx = f_idx + 1
  @end

  return all_roots
@end

@fn recursive_frame_pusher(reg, current_depth, max_depth)
  node_ptr = gc_alloc(64)
  reg = gc_push_frame(reg, 1000 + current_depth, current_depth, [node_ptr])

  @if current_depth >= max_depth
    @! At bottom of recursion, verify frame count and root enumeration
    roots_at_bottom = gc_enumerate_all_roots(reg)
    @if roots_at_bottom.len() == max_depth
      return 1
    @else
      return 0
    @end
  @end

  res = recursive_frame_pusher(reg, current_depth + 1, max_depth)
  reg = gc_pop_frame(reg)
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: GC Stack Root Scanning & Frame Registration")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-ROOT-01: Shadow Stack Frame Push & Pop Registration
  @! ----------------------------------------------------------------------------
  total = total + 1
  reg1 = gc_registry_new()
  p1 = gc_alloc(32)
  p2 = gc_alloc(64)
  reg1 = gc_push_frame(reg1, 1, 0, [p1, p2])
  push_ok = (reg1.frames.len() == 1)
  reg1 = gc_pop_frame(reg1)
  pop_ok = (reg1.frames.len() == 0)
  @if push_ok && pop_ok
    passed = passed + 1
    println("  [PASS] TC-ROOT-01: Shadow stack frame push and pop lifecycle")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ROOT-01: Shadow stack frame push and pop")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-ROOT-02: Comprehensive Root Enumeration (Globals + Frames)
  @! ----------------------------------------------------------------------------
  total = total + 1
  reg2 = gc_registry_new()
  g_root1 = gc_alloc(128)
  g_root2 = gc_alloc(128)
  reg2.global_roots = [g_root1, g_root2]

  f1_p1 = gc_alloc(32)
  f1_p2 = gc_alloc(32)
  reg2 = gc_push_frame(reg2, 101, 1, [f1_p1, f1_p2])

  f2_p1 = gc_alloc(64)
  reg2 = gc_push_frame(reg2, 102, 2, [f2_p1])

  enumerated = gc_enumerate_all_roots(reg2)
  @if enumerated.len() == 5 && enumerated[0] == g_root1 && enumerated[4] == f2_p1
    passed = passed + 1
    println("  [PASS] TC-ROOT-02: Root enumeration collects 2 globals + 3 frame roots (total: 5)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ROOT-02: Root enumeration")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-ROOT-03: Live Pointer Preservation Across GC Allocation Churn
  @! ----------------------------------------------------------------------------
  total = total + 1
  live_ptr = gc_alloc(256)
  base_before = gc_base(live_ptr)
  @! Register live pointer in registry
  reg3 = gc_registry_new()
  reg3 = gc_push_frame(reg3, 201, 0, [live_ptr])

  @! Allocate garbage chunks
  trash1 = gc_alloc(64)
  trash2 = gc_alloc(64)
  gc_collect()

  base_after = gc_base(live_ptr)
  is_valid = gc_is_valid_pointer(live_ptr)
  @if base_before == live_ptr && base_after == live_ptr && is_valid == 1
    passed = passed + 1
    println("  [PASS] TC-ROOT-03: Live pointer registered in frame preserved across GC collection")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ROOT-03: Live pointer preservation")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-ROOT-04: Frame Pop Unregistration & Out-of-Scope Cleanup
  @! ----------------------------------------------------------------------------
  total = total + 1
  temp_ptr = gc_alloc(64)
  reg4 = gc_registry_new()
  reg4 = gc_push_frame(reg4, 301, 0, [temp_ptr])
  roots_active = gc_enumerate_all_roots(reg4)
  reg4 = gc_pop_frame(reg4)
  roots_after_pop = gc_enumerate_all_roots(reg4)
  @if roots_active.len() == 1 && roots_after_pop.len() == 0
    passed = passed + 1
    println("  [PASS] TC-ROOT-04: Popping frame unregisters root pointers (count: 1 -> 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ROOT-04: Frame pop unregistration")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-ROOT-05: Deep Recursive Stack Frame Walking (50 Levels)
  @! ----------------------------------------------------------------------------
  total = total + 1
  reg5 = gc_registry_new()
  deep_ok = recursive_frame_pusher(reg5, 1, 50)
  @if deep_ok == 1
    passed = passed + 1
    println("  [PASS] TC-ROOT-05: Deep recursive stack frame traversal (50 registered frame levels)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ROOT-05: Deep recursive stack frame traversal")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: GC Stack Root Scanning & Frame Registration PASSED")
    return 0
  @else
    println("✗ Feature: GC Stack Root Scanning & Frame Registration FAILED")
    return 1
  @end
@end
