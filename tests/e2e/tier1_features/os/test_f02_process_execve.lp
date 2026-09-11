@! ============================================================================
@! MAYA E2E TIER 1 — F02.2: Process Native ELF Execve
@! File: tests/e2e/tier1_features/os/test_f02_process_execve.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F02.2: Process Execve")

  bin_path = "/bin/true"
  @if sys_access(bin_path, 1) != 0
    bin_path = "/usr/bin/true"
  @end

  pid = process_spawn(bin_path, [bin_path])
  assert_gt(pid, 0, "process_spawn created valid child PID")

  status = process_wait(pid)
  assert_eq(process_wifexited(status), 1, "Child exited normally")
  assert_eq(process_wexitstatus(status), 0, "Execve binary exited with status 0")

  println("✓ PASS: F02.2 Process Execve")
  return 0
@end
