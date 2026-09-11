@! ============================================================================
@! MAYA E2E TIER 1 — F01.4: Syscall clock_gettime & nanosleep
@! File: tests/e2e/tier1_features/os/test_f01_syscall_clock_nanosleep.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F01.4: Syscall clock & nanosleep")

  ts_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  assert_gt(ts_buf, 0, "mmap for timespec buffer succeeded")

  clk_res = sys_clock_gettime(1, ts_buf) @! CLOCK_MONOTONIC = 1
  assert_eq(clk_res, 0, "sys_clock_gettime succeeded")
  sys_munmap(ts_buf, 16)

  println("✓ PASS: F01.4 Syscall clock & nanosleep")
  return 0
@end
