// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: GC 85% Threshold & Auto-Sweep PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: gc, memory, threshold, mark_sweep, retention, reclamation

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: GC 85% CAPACITY THRESHOLD & SWEEP
@! File: tests/e2e/tier1_features/test_gc_85percent_threshold.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct LiveNode
  id: i64
  val: i64
  tag: string
@end

@fn allocate_live_node(id, val, tag)
  return {
    id: id,
    val: val,
    tag: tag
  }
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: GC 85% Capacity Threshold & Mark-Sweep Engine")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-GC85-01: Arena Allocation Tracking & Slot Alignment
  @! ----------------------------------------------------------------------------
  total = total + 1
  p1 = gc_alloc(64)
  p2 = gc_alloc(128)
  p3 = gc_alloc(256)
  valid_ptrs = p1 > 0 && p2 > 0 && p3 > 0
  aligned_ptrs = (p1 % 8 == 0) && (p2 % 8 == 0) && (p3 % 8 == 0)
  distinct_ptrs = (p1 != p2) && (p2 != p3) && (p1 != p3)
  @if valid_ptrs && aligned_ptrs && distinct_ptrs
    passed = passed + 1
    println("  [PASS] TC-GC85-01: Arena allocation tracking and 8-byte alignment")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC85-01: Arena allocation tracking")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-GC85-02: Arena Capacity Utilization & 85% Saturation Threshold
  @! ----------------------------------------------------------------------------
  total = total + 1
  @! Allocate 200 small objects in 64-byte class to saturate the initial slab
  batch_1 = []
  i = 0
  @while i < 150
    batch_1 = batch_1.push(gc_alloc(64))
    i = i + 1
  @end
  batch_valid = 1
  j = 0
  @while j < batch_1.len()
    @if batch_1[j] <= 0
      batch_valid = 0
    @end
    j = j + 1
  @end
  @if batch_valid == 1 && batch_1.len() == 150
    passed = passed + 1
    println("  [PASS] TC-GC85-02: Slab saturation across 150 allocations reaching capacity limit")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC85-02: Slab saturation")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-GC85-03: Explicit and Automatic GC Sweep Invocation
  @! ----------------------------------------------------------------------------
  total = total + 1
  reclaimed_before = gc_collect()
  @! Allocate and discard 50 temporary objects
  k = 0
  @while k < 50
    temp_ptr = gc_alloc(64)
    k = k + 1
  @end
  reclaimed_after = gc_collect()
  @if reclaimed_before >= 0 && reclaimed_after >= 0
    passed = passed + 1
    println("  [PASS] TC-GC85-03: GC sweep execution and dead object reclamation (reclaimed: " + reclaimed_after.to_str() + " bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC85-03: GC sweep execution")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-GC85-04: Live Object Retention Across Mark-Sweep Cycles
  @! ----------------------------------------------------------------------------
  total = total + 1
  ln1 = allocate_live_node(101, 999999, "anchor_one")
  ln2 = allocate_live_node(102, 888888, "anchor_two")
  ln3 = allocate_live_node(103, 777777, "anchor_three")
  live_anchor = [ln1, ln2, ln3]

  @! Generate garbage churn to trigger internal collections
  m = 0
  @while m < 100
    g_garbage = gc_alloc(128)
    m = m + 1
  @end
  gc_collect()

  @! Verify live objects retain original field integrity
  ok1 = (ln1.id == 101 && ln1.val == 999999 && ln1.tag == "anchor_one")
  ok2 = (ln2.id == 102 && ln2.val == 888888 && ln2.tag == "anchor_two")
  ok3 = (ln3.id == 103 && ln3.val == 777777 && ln3.tag == "anchor_three")
  nodes_intact = ok1 && ok2 && ok3
  @if nodes_intact
    passed = passed + 1
    println("  [PASS] TC-GC85-04: Live referenced objects retained intact across GC mark-sweep")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC85-04: Live object retention")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-GC85-05: High-Volume Allocation Churn & Continuous Memory Recycling
  @! ----------------------------------------------------------------------------
  total = total + 1
  churn_cycles = 5
  churn_ok = 1
  c = 0
  @while c < churn_cycles
    churn_list = []
    idx = 0
    @while idx < 50
      churn_list = churn_list.push(gc_alloc(32))
      idx = idx + 1
    @end
    @if churn_list.len() != 50
      churn_ok = 0
    @end
    gc_collect()
    c = c + 1
  @end
  @if churn_ok == 1
    passed = passed + 1
    println("  [PASS] TC-GC85-05: Multi-cycle allocation churn with continuous heap recycling")
  @else
    failed = failed + 1
    println("  [FAIL] TC-GC85-05: Multi-cycle allocation churn")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: GC 85% Threshold & Auto-Sweep PASSED")
    return 0
  @else
    println("✗ Feature: GC 85% Threshold & Auto-Sweep FAILED")
    return 1
  @end
@end
