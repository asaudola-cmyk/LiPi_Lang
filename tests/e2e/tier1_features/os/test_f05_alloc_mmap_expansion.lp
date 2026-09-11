@! ============================================================================
@! MAYA E2E TIER 1 — F05.5: Dynamic Heap Expansion via sys_mmap
@! File: tests/e2e/tier1_features/os/test_f05_alloc_mmap_expansion.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F05.5: Dynamic Arena Expansion")

  ptr = sys_mmap(0, 131072, 3, 34, 0 - 1, 0)
  assert_gt(ptr, 0, "128KB dynamic arena allocated")
  res = sys_munmap(ptr, 131072)
  assert_eq(res, 0, "128KB arena freed")

  println("✓ PASS: F05.5 Dynamic Arena Expansion")
  return 0
@end
