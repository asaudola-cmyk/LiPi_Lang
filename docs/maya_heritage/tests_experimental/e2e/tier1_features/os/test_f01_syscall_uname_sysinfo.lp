@! ============================================================================
@! MAYA E2E TIER 1 — F01.5: Syscall uname & System Information
@! File: tests/e2e/tier1_features/os/test_f01_syscall_uname_sysinfo.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F01.5: Syscall uname")

  uname_buf = sys_mmap(0, 512, 3, 34, 0 - 1, 0)
  assert_gt(uname_buf, 0, "mmap for uname buffer succeeded")

  res = sys_uname(uname_buf)
  assert_eq(res, 0, "sys_uname returned 0")
  sys_munmap(uname_buf, 512)

  println("✓ PASS: F01.5 Syscall uname")
  return 0
@end
