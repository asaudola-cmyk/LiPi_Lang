@! ============================================================================
@! MAYA E2E TIER 1 — F05.4: Heap Adjacent Free Block Coalescing
@! File: tests/e2e/tier1_features/os/test_f05_alloc_block_coalesce.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f05_memory"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F05.4: Block Coalescing")

  heap = heap_new(4096)
  o1 = heap_alloc(heap, 128, 1)
  o2 = heap_alloc(heap, 128, 2)

  heap_free(heap, o1)
  heap_free(heap, o2)
  heap_coalesce(heap)

  assert_eq(heap.blocks[0].is_free, 1, "Merged block is free")
  assert_eq(heap.blocks[0].size, 4096, "Adjacent free blocks merged back into full capacity")

  println("✓ PASS: F05.4 Block Coalescing")
  return 0
@end
