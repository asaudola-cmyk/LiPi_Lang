@! ============================================================================
@! MAYA E2E TIER 1 — F05.3: Heap Large Block Splitting
@! File: tests/e2e/tier1_features/os/test_f05_alloc_block_split.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f05_memory"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F05.3: Block Splitting")

  heap = heap_new(4096)
  assert_eq(heap.blocks.len(), 1, "Initial 1 big block")

  heap_alloc(heap, 256, 1)
  assert_eq(heap.blocks.len(), 2, "Split into allocated 256 + free 3840")
  assert_eq(heap.blocks[0].size, 256, "Block 0 is 256")
  assert_eq(heap.blocks[1].size, 3840, "Block 1 is 3840")

  println("✓ PASS: F05.3 Block Splitting")
  return 0
@end
