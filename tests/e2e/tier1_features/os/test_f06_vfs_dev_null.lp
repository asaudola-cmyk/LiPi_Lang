@! ============================================================================
@! MAYA E2E TIER 1 — F06.3: VFS /dev/null Character Device
@! File: tests/e2e/tier1_features/os/test_f06_vfs_dev_null.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F06.3: /dev/null")

  fd = sys_open("/dev/null", 1, 0)
  assert_gt(fd, 0, "/dev/null opened for write")
  data = "TEST_PAYLOAD"
  n = sys_write(fd, data, data.len())
  assert_eq(n, data.len(), "Wrote to /dev/null")
  sys_close(fd)

  println("✓ PASS: F06.3 /dev/null")
  return 0
@end
