// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Runtime Pointer Tagging & Disambiguation PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: runtime, pointer_tagging, nan_boxing, type_id, disambiguation, large_integers

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: RUNTIME POINTER TAGGING & DISAMBIGUATION
@! File: tests/e2e/tier1_features/test_runtime_pointer_tagging.maya
@! ============================================================================

import "universe/core/gc"
import "universe/core/string"
import "universe/core/collections"

@struct TaggedValueRecord
  tag_kind: i64      @! 0=Raw, 1=Int, 2=Ptr, 3=String, 4=Array
  raw_payload: i64
  is_pointer: i64
@end

@fn make_tagged_int(val)
  return {
    tag_kind: 1,
    raw_payload: val,
    is_pointer: 0
  }
@end

@fn make_tagged_ptr(ptr)
  return {
    tag_kind: 2,
    raw_payload: ptr,
    is_pointer: 1
  }
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Runtime Pointer Tagging & Disambiguation")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! ----------------------------------------------------------------------------
  @! TC-TAG-01: Object Type ID Header Tagging Constants
  @! ----------------------------------------------------------------------------
  total = total + 1
  t_raw = TYPE_RAW_BYTES()
  t_str = TYPE_MAYA_STRING()
  t_arr = TYPE_MAYA_ARRAY()
  t_struct = TYPE_MAYA_STRUCT()
  t_closure = TYPE_MAYA_CLOSURE()
  tags_unique = (t_raw == 0) && (t_str == 1) && (t_arr == 2) && (t_struct == 3) && (t_closure == 4)
  @if tags_unique
    passed = passed + 1
    println("  [PASS] TC-TAG-01: Type ID constants defined and distinct (0..4)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-TAG-01: Type ID constants")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-TAG-02: Large Virtual Address Integers Preserved (0x400000 / 140737488355328)
  @! ----------------------------------------------------------------------------
  total = total + 1
  large_int1 = 4194304            @! 0x400000 (standard ELF base address)
  large_int2 = 140737488355328    @! 0x7FFFFFFF0000 (Linux stack/mmap address)
  large_int3 = 4294967295         @! 0xFFFFFFFF (32-bit max)

  @! Perform scalar arithmetic on virtual address-like integers
  sum1 = large_int1 + 1024
  diff2 = large_int2 - 4096
  shifted = (large_int1 / (1 << 12))

  ok_arith = (sum1 == 4195328) && (diff2 == 140737488351232) && (shifted == 1024)
  @if ok_arith
    passed = passed + 1
    println("  [PASS] TC-TAG-02: Large virtual address integers (0x400000, 0x7FFFFFFF0000) preserved as scalar values")
  @else
    failed = failed + 1
    println("  [FAIL] TC-TAG-02: Large integer preservation")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-TAG-03: Extreme Negative Integers & Boundary Range
  @! ----------------------------------------------------------------------------
  total = total + 1
  neg_small = 0 - 1
  neg_mid = 0 - 1000000000
  neg_large = 0 - 140737488355328

  neg_ok = (neg_small == -1) && (neg_mid == -1000000000) && (neg_large == -140737488355328)
  @if neg_ok
    passed = passed + 1
    println("  [PASS] TC-TAG-03: Extreme negative integer boundaries (-10^9, -140737488355328)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-TAG-03: Negative integer boundaries")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-TAG-04: Mixed Value Array Indexing (Integers vs Heap Pointers)
  @! ----------------------------------------------------------------------------
  total = total + 1
  heap_p1 = gc_alloc(64)
  heap_p2 = gc_alloc(128)
  mixed_array = [4194304, heap_p1, 140737488355328, heap_p2, -42]

  idx0 = mixed_array[0]
  idx1 = mixed_array[1]
  idx2 = mixed_array[2]
  idx3 = mixed_array[3]
  idx4 = mixed_array[4]

  mixed_ok = (idx0 == 4194304) && (idx1 == heap_p1) && (idx2 == 140737488355328) && (idx3 == heap_p2) && (idx4 == -42)
  @if mixed_ok
    passed = passed + 1
    println("  [PASS] TC-TAG-04: Mixed array indexing preserving large scalars alongside heap pointers")
  @else
    failed = failed + 1
    println("  [FAIL] TC-TAG-04: Mixed value array indexing")
  @end

  @! ----------------------------------------------------------------------------
  @! TC-TAG-05: Tagged Object Introspection & String Representation
  @! ----------------------------------------------------------------------------
  total = total + 1
  tag_int_record = make_tagged_int(4194304)
  tag_ptr_record = make_tagged_ptr(heap_p1)

  int_is_not_ptr = (tag_int_record.is_pointer == 0) && (tag_int_record.raw_payload == 4194304)
  ptr_is_ptr = (tag_ptr_record.is_pointer == 1) && (tag_ptr_record.raw_payload == heap_p1)
  @if int_is_not_ptr && ptr_is_ptr
    passed = passed + 1
    println("  [PASS] TC-TAG-05: Explicit tag discrimination between integer scalar and heap pointer")
  @else
    failed = failed + 1
    println("  [FAIL] TC-TAG-05: Tagged object introspection")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Runtime Pointer Tagging & Disambiguation PASSED")
    return 0
  @else
    println("✗ Feature: Runtime Pointer Tagging & Disambiguation FAILED")
    return 1
  @end
@end
