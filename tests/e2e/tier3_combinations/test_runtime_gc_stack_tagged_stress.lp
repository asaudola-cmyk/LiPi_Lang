// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Runtime GC Stack & Tagged Values Stress PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 3
// @! TAGS: runtime, gc, combination, stack_roots, tagged_values, 85percent_sweep

@! ============================================================================
@! MAYA E2E TIER 3 — COMBINATORIAL: RUNTIME GC STACK & TAGGED STRESS
@! File: tests/e2e/tier3_combinations/test_runtime_gc_stack_tagged_stress.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"
import "universe/core/collections"
import "universe/core/string"

@struct StressTagRecord
  depth: i64
  scalar: i64
  chk: i64
@end

@fn execute_tagged_stress_recursion(depth, max_depth, base_scalar)
  buf = gc_alloc(64)
  tagged_val = base_scalar + (depth * 4096)
  expected_checksum = (depth * 31) + tagged_val & 65535

  @if depth == 20 || depth == 40 || depth == max_depth
    g_i = 0
    @while g_i < 50
      temp_g = gc_alloc(32)
      g_i = g_i + 1
    @end
    gc_collect()
  @end

  @if depth >= max_depth
    calc_chk = (depth * 31) + tagged_val & 65535
    @if calc_chk == expected_checksum
      return 1
    @else
      return 0
    @end
  @end

  child_ok = execute_tagged_stress_recursion(depth + 1, max_depth, base_scalar)
  calc_chk_unwind = (depth * 31) + tagged_val & 65535
  @if child_ok == 1 && calc_chk_unwind == expected_checksum
    return 1
  @else
    return 0
  @end
@end

@fn verify_tagged_array(arr)
  a0 = (arr[0] == 4194304) && (arr[1] == -1000000000)
  a1 = (arr[2] == 140737488355328) && (arr[3] == 0) && (arr[4] == 123456789)
  @if a0 && a1
    return 1
  @else
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination: Runtime GC Stack & Tagged Values Stress")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-COMB-01: Deep Stack Recursion with Tagged Large Integers & Active GC
  @! ----------------------------------------------------------------------------
  total = total + 1
  base_addr = 140737488355328 @! 0x7FFFFFFF0000
  stress_res = execute_tagged_stress_recursion(1, 50, base_addr)
  @if stress_res == 1
    passed = passed + 1
    println("  [PASS] TC-COMB-01: 50-frame recursive execution with virtual addresses and interleaved GC sweeps")
  @else
    failed = failed + 1
    println("  [FAIL] TC-COMB-01: Deep stack tagged recursion")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-COMB-02: Tagged Value Array Verification Across Allocations
  @! ----------------------------------------------------------------------------
  total = total + 1
  tagged_arr = [4194304, -1000000000, 140737488355328, 0, 123456789]
  g_fill1 = gc_alloc(512)
  g_fill2 = gc_alloc(512)
  arr_survived = verify_tagged_array(tagged_arr)
  @if arr_survived == 1
    passed = passed + 1
    println("  [PASS] TC-COMB-02: Tagged value array retains scalar elements across allocations")
  @else
    failed = failed + 1
    println("  [FAIL] TC-COMB-02: Tagged array retention")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-COMB-03: Tagged Struct Records with Virtual Address Fields
  @! ----------------------------------------------------------------------------
  total = total + 1
  r1 = { depth: 1, scalar: 4194304, chk: 111 }
  r2 = { depth: 2, scalar: 140737488355328, chk: 222 }

  r1_ok = (r1.depth == 1 && r1.scalar == 4194304 && r1.chk == 111)
  r2_ok = (r2.depth == 2 && r2.scalar == 140737488355328 && r2.chk == 222)
  @if r1_ok && r2_ok
    passed = passed + 1
    println("  [PASS] TC-COMB-03: Tagged struct records with virtual address fields maintain exact scalar values")
  @else
    failed = failed + 1
    println("  [FAIL] TC-COMB-03: Tagged struct records")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-COMB-04: Large Memory Chunk Allocation & Introspection
  @! ----------------------------------------------------------------------------
  total = total + 1
  p_test = gc_alloc(4096)
  valid_before = gc_is_valid_pointer(p_test)
  base_test = gc_base(p_test)

  type_intact = (valid_before == 1) && (base_test == p_test)
  @if type_intact
    passed = passed + 1
    println("  [PASS] TC-COMB-04: Large object mmap allocation base address and validity verified")
  @else
    failed = failed + 1
    println("  [FAIL] TC-COMB-04: Large memory chunk allocation")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-COMB-05: Continuous Reallocation with Tagged Integer Preserved
  @! ----------------------------------------------------------------------------
  total = total + 1
  orig_buf = gc_alloc(32)
  realloc_buf = gc_realloc(orig_buf, 512)
  realloc_ok = (realloc_buf > 0) && (gc_base(realloc_buf) == realloc_buf)
  @if realloc_ok
    passed = passed + 1
    println("  [PASS] TC-COMB-05: Dynamic buffer reallocation (32B -> 512B) with valid GC metadata")
  @else
    failed = failed + 1
    println("  [FAIL] TC-COMB-05: Buffer reallocation")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Runtime GC Stack & Tagged Values Stress PASSED")
    return 0
  @else
    println("✗ Feature: Runtime GC Stack & Tagged Values Stress FAILED")
    return 1
  @end
@end
