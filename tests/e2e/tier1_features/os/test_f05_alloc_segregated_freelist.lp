@! ============================================================================
@! MAYA E2E TIER 1 — F05.2: Segregated Free List Sized Allocations
@! File: tests/e2e/tier1_features/os/test_f05_alloc_segregated_freelist.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f05_memory"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F05.2: Sized Free List Allocations")

  heap = heap_new(4096)
  o1 = heap_alloc(heap, 32, 1)
  o2 = heap_alloc(heap, 64, 2)
  o3 = heap_alloc(heap, 128, 3)

  assert_eq(o1, 0, "32B block at 0")
  assert_eq(o2, 32, "64B block at 32")
  assert_eq(o3, 96, "128B block at 96")

  println("✓ PASS: F05.2 Sized Free List Allocations")
  return 0
@end
