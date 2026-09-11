@! ============================================================================
@! TEST: tests/runtime/test_gc_real.maya
@! Phase 6 — Real GC memory-stability test
@! Allocates objects in batches, collects, and verifies freed bytes > 0.
@! An intentional-break guard: if GC is broken, freed == 0 and test FAILS.
@! ============================================================================

import "runtime/maya_gc"

g_passed = 0
g_failed = 0

@fn check(label, cond)
  @if cond == 1
    g_passed = g_passed + 1
    println("  PASS: " + label)
  @else
    g_failed = g_failed + 1
    println("  FAIL: " + label)
  @end
@end

@fn main()
  println("=== GC Real Memory-Leak Prevention Test ===")

  gc_init()

  @! ---- Round 1: Allocate 100 unrooted objects of 64 bytes each ----
  @! Total: 6400 bytes allocated but NOT registered as roots
  i = 0
  @while i < 100
    gc_alloc(64)
    i = i + 1
  @end

  s1 = gc_stats()
  @! Must have allocated something
  check("allocated_bytes > 0 after 100 allocs", s1.total_allocated_bytes > 0)

  freed1 = gc_collect()
  @! All 100 objects are unrooted — GC MUST free them
  check("freed1 > 0 after collecting 100 unrooted 64-byte objects", freed1 > 0)
  check("collections_run == 1 after first collect", gc_stats().collections_run == 1)

  @! ---- Round 2: Allocate 50 objects, root 10, collect ----
  @! Expectation: only the 40 un-rooted objects get freed
  j = 0
  @while j < 50
    p = gc_alloc(128)
    @if j < 10
      gc_register_root(p)
    @end
    j = j + 1
  @end

  freed2 = gc_collect()
  @! 40 unrooted × 128 bytes = 5120 bytes freed at minimum
  check("freed2 > 0 after collecting 40 unrooted 128-byte objects", freed2 > 0)
  check("freed2 >= 5120 (40 * 128)", freed2 >= 5120)

  @! ---- Round 3: Large objects (> 2048) are also reclaimed ----
  gc_alloc(4096)
  gc_alloc(8192)
  freed3 = gc_collect()
  check("freed3 > 0 for unrooted large objects", freed3 > 0)
  check("freed3 >= 12288 (4096 + 8192)", freed3 >= 12288)

  @! ---- Intentional-break guard ----
  @! If gc_collect returned 0 for every round where unrooted objects exist,
  @! that means GC is a no-op — both freed1 and freed2 must be > 0.
  total_freed = freed1 + freed2 + freed3
  check("total_freed > 0 (GC is NOT a no-op)", total_freed > 0)

  println("=== RESULTS: " + g_passed.to_str() + " passed, " + g_failed.to_str() + " failed ===")
  @if g_failed == 0
    println("ALL GC REAL TESTS PASSED")
  @else
    println("SOME GC REAL TESTS FAILED — GC may be broken")
  @end
@end
