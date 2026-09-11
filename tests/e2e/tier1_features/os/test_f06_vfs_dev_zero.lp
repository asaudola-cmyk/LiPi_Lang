@! ============================================================================
@! MAYA E2E TIER 1 — F06.4: VFS /dev/zero Character Device
@! File: tests/e2e/tier1_features/os/test_f06_vfs_dev_zero.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F06.4: /dev/zero")

  fd = sys_open("/dev/zero", 0, 0)
  assert_gt(fd, 0, "/dev/zero opened for read")
  buf = maya_alloc(64)
  n = sys_read(fd, buf, 64)
  assert_eq(n, 64, "Read 64 bytes from /dev/zero")
  sys_close(fd)

  println("✓ PASS: F06.4 /dev/zero")
  return 0
@end
