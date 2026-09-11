@! ============================================================================
@! TEST: runtime/maya_gc — Tri-Color Mark-and-Sweep Garbage Collector
@! Pure Maya syntax — zero C / Rust / Python
@! Every assertion tests a COMPUTED value against an EXPECTED value.
@! ============================================================================

import "runtime/maya_gc"

@! ---------------------------------------------------------------------------
@! Helpers
@! ---------------------------------------------------------------------------
g_test_passed = 0
g_test_failed = 0

@fn assert_eq(label, got, expected)
  @if got == expected
    g_test_passed = g_test_passed + 1
    println("  PASS: " + label + " == " + expected.to_str())
  @else
    g_test_failed = g_test_failed + 1
    println("  FAIL: " + label + " got=" + got.to_str() + " expected=" + expected.to_str())
  @end
@end

@fn assert_gt(label, got, threshold)
  @if got > threshold
    g_test_passed = g_test_passed + 1
    println("  PASS: " + label + " = " + got.to_str() + " > " + threshold.to_str())
  @else
    g_test_failed = g_test_failed + 1
    println("  FAIL: " + label + " = " + got.to_str() + " NOT > " + threshold.to_str())
  @end
@end

@fn assert_neq(label, got, unexpected)
  @if got != unexpected
    g_test_passed = g_test_passed + 1
    println("  PASS: " + label + " != " + unexpected.to_str())
  @else
    g_test_failed = g_test_failed + 1
    println("  FAIL: " + label + " unexpectedly == " + unexpected.to_str())
  @end
@end

@! ---------------------------------------------------------------------------
@! Test 1: gc_init() initialises global state to zero
@! ---------------------------------------------------------------------------
@fn test_gc_init()
  println("=== test_gc_init ===")
  gc_init()
  s = gc_stats()
  assert_eq("total_allocated_bytes after init", s.total_allocated_bytes, 0)
  assert_eq("total_freed_bytes after init",     s.total_freed_bytes,     0)
  assert_eq("collections_run after init",       s.collections_run,       0)
@end

@! ---------------------------------------------------------------------------
@! Test 2: gc_alloc returns a non-zero pointer and increments bytes counter
@! ---------------------------------------------------------------------------
@fn test_gc_alloc_returns_nonzero()
  println("=== test_gc_alloc_returns_nonzero ===")
  gc_init()
  ptr = gc_alloc(64)
  assert_neq("gc_alloc(64) pointer", ptr, 0)
  s = gc_stats()
  assert_gt("total_allocated_bytes > 0 after alloc", s.total_allocated_bytes, 0)
@end

@! ---------------------------------------------------------------------------
@! Test 3: gc_alloc for different size classes returns distinct pointers
@! ---------------------------------------------------------------------------
@fn test_gc_alloc_distinct_pointers()
  println("=== test_gc_alloc_distinct_pointers ===")
  gc_init()
  p1 = gc_alloc(16)
  p2 = gc_alloc(32)
  p3 = gc_alloc(64)
  p4 = gc_alloc(128)
  assert_neq("ptr16 != ptr32",  p1, p2)
  assert_neq("ptr32 != ptr64",  p2, p3)
  assert_neq("ptr64 != ptr128", p3, p4)
  assert_neq("ptr16 != ptr128", p1, p4)
@end

@! ---------------------------------------------------------------------------
@! Test 4: gc_free marks the allocation as freed and increases freed counter
@! ---------------------------------------------------------------------------
@fn test_gc_free_increments_freed_bytes()
  println("=== test_gc_free_increments_freed_bytes ===")
  gc_init()
  ptr = gc_alloc(128)
  s_before = gc_stats()
  gc_free(ptr)
  s_after = gc_stats()
  assert_gt("total_freed_bytes increases after gc_free", s_after.total_freed_bytes, s_before.total_freed_bytes)
@end

@! ---------------------------------------------------------------------------
@! Test 5: gc_is_valid_pointer — only returns 1 for live, allocated pointers
@! ---------------------------------------------------------------------------
@fn test_gc_is_valid_pointer()
  println("=== test_gc_is_valid_pointer ===")
  gc_init()
  ptr = gc_alloc(64)
  assert_eq("valid pointer before free",  gc_is_valid_pointer(ptr), 1)
  gc_free(ptr)
  assert_eq("invalid pointer after free", gc_is_valid_pointer(ptr), 0)
  assert_eq("zero is never valid",        gc_is_valid_pointer(0),   0)
@end

@! ---------------------------------------------------------------------------
@! Test 6: size-class selection returns correct class for boundary values
@! ---------------------------------------------------------------------------
@fn test_size_class_selection()
  println("=== test_size_class_selection ===")
  assert_eq("size 1  -> class 1",   gc_get_size_class(1),    1)
  assert_eq("size 16 -> class 1",   gc_get_size_class(16),   1)
  assert_eq("size 17 -> class 2",   gc_get_size_class(17),   2)
  assert_eq("size 32 -> class 2",   gc_get_size_class(32),   2)
  assert_eq("size 33 -> class 3",   gc_get_size_class(33),   3)
  assert_eq("size 64 -> class 3",   gc_get_size_class(64),   3)
  assert_eq("size 128 -> class 4",  gc_get_size_class(128),  4)
  assert_eq("size 256 -> class 5",  gc_get_size_class(256),  5)
  assert_eq("size 512 -> class 6",  gc_get_size_class(512),  6)
  assert_eq("size 1024 -> class 7", gc_get_size_class(1024), 7)
  assert_eq("size 2048 -> class 8", gc_get_size_class(2048), 8)
  assert_eq("size 2049 -> large 0", gc_get_size_class(2049), 0)
  assert_eq("size 8192 -> large 0", gc_get_size_class(8192), 0)
@end

@! ---------------------------------------------------------------------------
@! Test 7: gc_collect on live roots does NOT free them, returns 0 freed
@! ---------------------------------------------------------------------------
@fn test_gc_collect_preserves_live_roots()
  println("=== test_gc_collect_preserves_live_roots ===")
  gc_init()
  p1 = gc_alloc(64)
  p2 = gc_alloc(64)
  @! Register both as roots so the GC sees them as live
  gc_register_root(p1)
  gc_register_root(p2)
  freed = gc_collect()
  @! Both objects are live roots; nothing should be freed
  assert_eq("no bytes freed when all objects are roots", freed, 0)
@end

@! ---------------------------------------------------------------------------
@! Test 8: gc_collect reclaims UNrooted objects (the key correctness test)
@! ---------------------------------------------------------------------------
@fn test_gc_collect_reclaims_unrooted()
  println("=== test_gc_collect_reclaims_unrooted ===")
  gc_init()
  @! Allocate 5 objects and register NONE as roots
  i = 0
  @while i < 5
    gc_alloc(64)
    i = i + 1
  @end
  s_before = gc_stats()
  freed = gc_collect()
  @! All 5 are unreachable — freed bytes must be > 0
  assert_gt("freed bytes > 0 for unrooted allocations", freed, 0)
  @! collections_run counter must have incremented
  s_after = gc_stats()
  assert_gt("collections_run incremented", s_after.collections_run, 0)
@end

@! ---------------------------------------------------------------------------
@! Test 9: large-object path (size > 2048) — alloc and collect
@! ---------------------------------------------------------------------------
@fn test_gc_large_object()
  println("=== test_gc_large_object ===")
  gc_init()
  big_ptr = gc_alloc(8192)
  assert_neq("large alloc returns non-zero ptr", big_ptr, 0)
  @! Do NOT register as root; collection should reclaim it
  freed = gc_collect()
  assert_gt("large object freed bytes > 0", freed, 0)
@end

@! ---------------------------------------------------------------------------
@! Test 10: Freelist reuse — freed slot must be returned on next alloc
@! ---------------------------------------------------------------------------
@fn test_freelist_reuse()
  println("=== test_freelist_reuse ===")
  gc_init()
  p1 = gc_alloc(64)
  gc_free(p1)
  @! The slot must be recycled; next alloc of same size returns same address
  p2 = gc_alloc(64)
  assert_eq("freelist recycles slot ptr", p2, p1)
@end

@! ---------------------------------------------------------------------------
@! Test 11: Intentional-break guard — if gc_collect returns negative, it broke
@! ---------------------------------------------------------------------------
@fn test_gc_collect_never_returns_negative()
  println("=== test_gc_collect_never_returns_negative ===")
  gc_init()
  gc_alloc(32)
  gc_alloc(32)
  freed = gc_collect()
  @! freed must be >= 0; negative means broken sweep logic
  @if freed < 0
    g_test_failed = g_test_failed + 1
    println("  FAIL: gc_collect returned negative: " + freed.to_str())
  @else
    g_test_passed = g_test_passed + 1
    println("  PASS: gc_collect returned >= 0: " + freed.to_str())
  @end
@end

@! ---------------------------------------------------------------------------
@! Test 12: gc_realloc preserves allocation (non-zero result)
@! ---------------------------------------------------------------------------
@fn test_gc_realloc()
  println("=== test_gc_realloc ===")
  gc_init()
  p1 = gc_alloc(64)
  assert_neq("original alloc non-zero", p1, 0)
  p2 = gc_realloc(p1, 256)
  assert_neq("realloc result non-zero", p2, 0)
@end

@! ---------------------------------------------------------------------------
@! main — run all tests
@! ---------------------------------------------------------------------------
@fn main()
  println("====================================================")
  println(" Maya GC Real Test Suite — runtime/maya_gc.maya")
  println("====================================================")

  test_gc_init()
  test_gc_alloc_returns_nonzero()
  test_gc_alloc_distinct_pointers()
  test_gc_free_increments_freed_bytes()
  test_gc_is_valid_pointer()
  test_size_class_selection()
  test_gc_collect_preserves_live_roots()
  test_gc_collect_reclaims_unrooted()
  test_gc_large_object()
  test_freelist_reuse()
  test_gc_collect_never_returns_negative()
  test_gc_realloc()

  println("====================================================")
  println("RESULTS: " + g_test_passed.to_str() + " passed, " + g_test_failed.to_str() + " failed")
  @if g_test_failed == 0
    println("ALL TESTS PASSED")
  @else
    println("SOME TESTS FAILED")
  @end
  println("====================================================")
@end
