@! ============================================================================
@! MAYA E2E TIER 1 — F05.1: Basic Heap Allocation & Deallocation
@! File: tests/e2e/tier1_features/os/test_f05_alloc_basic_malloc_free.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f05_memory"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F05.1: Basic Alloc & Free")

  heap = heap_new(4096)
  off1 = heap_alloc(heap, 128, 1)
  assert_eq(off1, 0, "Allocated at offset 0")
  assert_eq(heap.used_bytes, 128, "128 bytes used")

  free_res = heap_free(heap, off1)
  assert_eq(free_res, 0, "heap_free succeeded")
  assert_eq(heap.used_bytes, 0, "0 bytes used after free")

  println("✓ PASS: F05.1 Basic Alloc & Free")
  return 0
@end
