@! ============================================================================
@! MAYA E2E TIER 1 — F01.3: Syscall getpid & getppid Process Identity
@! File: tests/e2e/tier1_features/os/test_f01_syscall_getpid_getppid.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F01.3: Syscall getpid & getppid")

  pid = sys_getpid()
  ppid = sys_getppid()
  assert_gt(pid, 0, "sys_getpid() returned valid PID > 0")
  assert_gt(ppid, 0, "sys_getppid() returned valid PPID > 0")

  println("✓ PASS: F01.3 Syscall getpid & getppid")
  return 0
@end
