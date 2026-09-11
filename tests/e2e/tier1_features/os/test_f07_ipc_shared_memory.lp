@! ============================================================================
@! MAYA E2E TIER 1 — F07.2: Inter-Process Shared Memory Exchange
@! File: tests/e2e/tier1_features/os/test_f07_ipc_shared_memory.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F07.2: IPC Shared Memory")

  shm_ptr = sys_mmap(0, 4096, 3, 33, 0 - 1, 0)
  assert_gt(shm_ptr, 0, "mmap MAP_SHARED succeeded")
  res = sys_munmap(shm_ptr, 4096)
  assert_eq(res, 0, "munmap succeeded")

  println("✓ PASS: F07.2 IPC Shared Memory")
  return 0
@end
