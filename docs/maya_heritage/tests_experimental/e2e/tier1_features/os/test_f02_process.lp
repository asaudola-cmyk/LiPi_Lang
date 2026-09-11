@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F02: PROCESS MANAGEMENT
@! File: tests/e2e/tier1_features/os/test_f02_process.maya
@! Description: Validates process creation, synchronization, signals & exit codes
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/tools/maya_test"

@fn test_f02_01_fork_parent_child()
  child_pid = process_fork()
  @if child_pid == 0
    @! In child: exit with success
    process_exit(0)
  @end

  assert_gt(child_pid, 0, "process_fork in parent must return positive child PID")
  status = process_wait(child_pid)
  assert_ge(status, 0, "process_wait must succeed")
  assert_eq(process_wifexited(status), 1, "Child must have exited normally")
  assert_eq(process_wexitstatus(status), 0, "Child exit status must be 0")
@end

@fn test_f02_02_wait_exit_code()
  target_exit_code = 77
  child_pid = process_fork()
  @if child_pid == 0
    process_exit(target_exit_code)
  @end

  status = process_wait(child_pid)
  assert_eq(process_wifexited(status), 1, "Child process must have terminated via exit()")
  exit_code = process_wexitstatus(status)
  assert_eq(exit_code, target_exit_code, "Parent must decode exact exit status 77")
@end

@fn test_f02_03_spawn_and_run()
  @! Use /bin/true or /bin/echo
  bin_path = "/bin/true"
  @if sys_access(bin_path, 1) != 0
    bin_path = "/usr/bin/true"
  @end

  exit_status = process_run(bin_path, [bin_path])
  assert_eq(exit_status, 0, "process_run on /bin/true must return exit code 0")
@end

@fn test_f02_04_kill_sigterm()
  child_pid = process_fork()
  @if child_pid == 0
    @! Child enters sleep loop waiting for signal
    @while 1 == 1
      process_sleep_ms(100)
    @end
    process_exit(0)
  @end

  @! Give child a moment to start
  process_sleep_ms(20)
  kill_res = process_kill(child_pid, SIGTERM())
  assert_eq(kill_res, 0, "process_kill(SIGTERM) must succeed")

  status = process_wait(child_pid)
  assert_eq(process_wifsignaled(status), 1, "process_wifsignaled must return 1 on killed child")
  termsig = process_wtermsig(status)
  assert_eq(termsig, 15, "Terminating signal must be SIGTERM (15)")
@end

@fn test_f02_05_waitpid_wnohang()
  child_pid = process_fork()
  @if child_pid == 0
    process_sleep_ms(50)
    process_exit(42)
  @end

  @! Non-blocking wait immediately while child is still sleeping
  status_now = process_waitpid(child_pid, WNOHANG())
  @! status_now should either be 0 (child running) or decoded status
  assert_ge(status_now, 0, "process_waitpid(WNOHANG) must not error")

  @! Blocking wait to cleanly reap child
  status_final = process_wait(child_pid)
  assert_eq(process_wifexited(status_final), 1, "Child must exit normally")
  assert_eq(process_wexitstatus(status_final), 42, "Child exit status must be 42")
@end

@fn test_f02_06_process_credentials()
  pid = process_getpid()
  ppid = process_getppid()
  uid = process_getuid()
  gid = process_getgid()
  assert_gt(pid, 0, "PID must be positive")
  assert_gt(ppid, 0, "PPID must be positive")
  assert_ge(uid, 0, "UID must be non-negative")
  assert_ge(gid, 0, "GID must be non-negative")
@end

@fn run_all_f02_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F02: Process Management Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f02_01_fork_parent_child")
  test_f02_01_fork_parent_child()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_01_fork_parent_child")

  println("  [RUN] test_f02_02_wait_exit_code")
  test_f02_02_wait_exit_code()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_02_wait_exit_code")

  println("  [RUN] test_f02_03_spawn_and_run")
  test_f02_03_spawn_and_run()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_03_spawn_and_run")

  println("  [RUN] test_f02_04_kill_sigterm")
  test_f02_04_kill_sigterm()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_04_kill_sigterm")

  println("  [RUN] test_f02_05_waitpid_wnohang")
  test_f02_05_waitpid_wnohang()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_05_waitpid_wnohang")

  println("  [RUN] test_f02_06_process_credentials")
  test_f02_06_process_credentials()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f02_06_process_credentials")

  println("-----------------------------------------------------------------")
  println("F02 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f02_tests()
@end
