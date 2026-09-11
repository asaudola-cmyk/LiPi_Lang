@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: PROCESS MANAGEMENT & CONTROL (universe/os/process)
@! File: tests/universe/test_os_process.maya
@! ============================================================================

import "universe/os/process"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/os/process (Process Subsystem)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: Process ID Query (process_getpid)
  @! --------------------------------------------------------------------------
  total = total + 1
  pid = process_getpid()
  @if pid > 0
    passed = passed + 1
    println("  [PASS] Test 1: process_getpid() returned valid PID (" + pid.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: process_getpid() returned non-positive PID: " + pid.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Parent Process ID Query (process_getppid)
  @! --------------------------------------------------------------------------
  total = total + 1
  ppid = process_getppid()
  @if ppid > 0
    passed = passed + 1
    println("  [PASS] Test 2: process_getppid() returned valid PPID (" + ppid.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: process_getppid() returned non-positive PPID: " + ppid.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: PID Consistency / Stability
  @! --------------------------------------------------------------------------
  total = total + 1
  pid_again = process_getpid()
  @if pid > 0 && pid == pid_again
    passed = passed + 1
    println("  [PASS] Test 3: Sequential process_getpid() calls return identical PID")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: process_getpid() returned differing or non-positive values")
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: Process Forking & Exit Status via process_wait
  @! --------------------------------------------------------------------------
  total = total + 1
  orig_pid = process_getpid()
  child_pid = process_fork()
  @if child_pid == 0
    curr_pid = process_getpid()
    @if orig_pid > 0 && curr_pid != orig_pid
      @! Genuine child process branch: exit with code 42
      exit(42)
    @else
      @! Incomplete or un-forked stub execution
      failed = failed + 1
      println("  [FAIL] Test 4: process_fork() returned 0 without PID divergence")
    @end
  @elif child_pid > 0
    @! Parent process branch: wait for child
    wait_status = process_wait(child_pid)
    child_exit_code = (wait_status / 256) & 255
    @if child_exit_code == 42 || wait_status == 42
      passed = passed + 1
      println("  [PASS] Test 4: process_fork() + process_wait() verified child exit code (42)")
    @else
      failed = failed + 1
      println("  [FAIL] Test 4: process_wait returned unexpected status: " + wait_status.to_str())
    @end
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: process_fork() returned error: " + child_pid.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: Process Signal Check (process_kill with signal 0)
  @! --------------------------------------------------------------------------
  total = total + 1
  @if pid > 0
    sig0_res = process_kill(pid, 0)
    @if sig0_res == 0
      passed = passed + 1
      println("  [PASS] Test 5: process_kill(self_pid, 0) verified process liveness")
    @else
      failed = failed + 1
      println("  [FAIL] Test 5: process_kill(self_pid, 0) returned non-zero: " + sig0_res.to_str())
    @end
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: Invalid PID for process_kill")
  @end

  println("-----------------------------------------------------------------")
  println("Process Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/os/process E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/os/process E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
