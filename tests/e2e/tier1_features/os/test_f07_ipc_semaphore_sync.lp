@! ============================================================================
@! MAYA E2E TIER 1 — F07.5: Mutex / Semaphore Synchronization
@! File: tests/e2e/tier1_features/os/test_f07_ipc_semaphore_sync.maya
@! ============================================================================

import "tests/e2e/tier1_features/os/test_f07_ipc"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F07.5: Mutex Synchronization")

  mtx = mutex_new()
  l1 = mutex_try_lock(mtx, 1)
  assert_eq(l1, 1, "Lock acquired")

  l2 = mutex_try_lock(mtx, 2)
  assert_eq(l2, 0, "Lock collision rejected")

  u1 = mutex_unlock(mtx, 1)
  assert_eq(u1, 1, "Unlocked successfully")

  println("✓ PASS: F07.5 Mutex Synchronization")
  return 0
@end
