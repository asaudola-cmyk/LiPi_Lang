@! ============================================================================
@! MAYA E2E TIER 1 — F01.2: Syscall mmap & munmap Anonymous Page
@! File: tests/e2e/tier1_features/os/test_f01_syscall_mmap_munmap.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F01.2: Syscall mmap & munmap Anonymous Page")

  page_size = 4096
  @! PROT_READ (1) | PROT_WRITE (2) = 3, MAP_PRIVATE (2) | MAP_ANON (32) = 34
  ptr = sys_mmap(0, page_size, 3, 34, 0 - 1, 0)
  assert_gt(ptr, 0, "sys_mmap returned positive pointer")

  unmap_res = sys_munmap(ptr, page_size)
  assert_eq(unmap_res, 0, "sys_munmap returned 0")

  println("✓ PASS: F01.2 Syscall mmap & munmap Anonymous Page")
  return 0
@end
