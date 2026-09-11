@! ============================================================================
@! MAYA E2E TIER 1 — F08.3: 4-Level MMU Paging & Virtual Address Splitting
@! File: tests/e2e/tier1_features/os/test_f08_boot_paging_pml4.maya
@! ============================================================================

import "universe/os/drivers/memory"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F08.3: 4-Level Paging")

  alloc = page_allocator_new(1048576)
  f0 = page_alloc_frame(alloc)
  assert_eq(f0, 0, "Allocated frame 0 at address 0")

  va = page_split_virtual_address(4096)
  assert_eq(va.offset_in_page, 0, "Offset in page is 0")
  assert_eq(va.pt_index, 1, "PT index is 1")

  println("✓ PASS: F08.3 4-Level Paging")
  return 0
@end
