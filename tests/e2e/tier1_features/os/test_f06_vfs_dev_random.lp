@! ============================================================================
@! MAYA E2E TIER 1 — F06.5: VFS /dev/urandom Character Device
@! File: tests/e2e/tier1_features/os/test_f06_vfs_dev_random.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F06.5: /dev/urandom")

  fd = sys_open("/dev/urandom", 0, 0)
  assert_gt(fd, 0, "/dev/urandom opened for read")
  buf = maya_alloc(32)
  n = sys_read(fd, buf, 32)
  assert_eq(n, 32, "Read 32 bytes of random entropy")
  sys_close(fd)

  println("✓ PASS: F06.5 /dev/urandom")
  return 0
@end
