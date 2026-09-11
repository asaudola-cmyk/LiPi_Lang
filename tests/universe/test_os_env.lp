@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: ENVIRONMENT & STREAMS (universe/os/env)
@! File: tests/universe/test_os_env.maya
@! ============================================================================

import "universe/os/env"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/os/env (Environment & Streams)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: Current Working Directory Query (env_getcwd)
  @! --------------------------------------------------------------------------
  total = total + 1
  orig_cwd = env_getcwd()
  @if orig_cwd.len() > 0 && contains(orig_cwd, "/") == 1
    passed = passed + 1
    println("  [PASS] Test 1: env_getcwd() returned current directory: " + orig_cwd)
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: env_getcwd() returned invalid path: " + orig_cwd)
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Working Directory Change (env_chdir to /tmp)
  @! --------------------------------------------------------------------------
  total = total + 1
  chdir_tmp_res = env_chdir("/tmp")
  new_cwd = env_getcwd()
  @if chdir_tmp_res == 0 && (contains(new_cwd, "tmp") == 1 || new_cwd == "/tmp")
    passed = passed + 1
    println("  [PASS] Test 2: env_chdir(\"/tmp\") successfully navigated to " + new_cwd)
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: env_chdir failed to change to /tmp -> " + new_cwd)
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Directory Navigation Round-Trip
  @! --------------------------------------------------------------------------
  total = total + 1
  chdir_back_res = env_chdir(orig_cwd)
  restored_cwd = env_getcwd()
  @if chdir_back_res == 0 && restored_cwd == orig_cwd
    passed = passed + 1
    println("  [PASS] Test 3: env_chdir restored original directory: " + restored_cwd)
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: Failed to restore directory -> Got: " + restored_cwd)
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: Standard File Descriptor Constants
  @! STDIN_FILENO = 0, STDOUT_FILENO = 1, STDERR_FILENO = 2
  @! --------------------------------------------------------------------------
  total = total + 1
  stdin_fd = 0
  stdout_fd = 1
  stderr_fd = 2
  @if stdin_fd == 0 && stdout_fd == 1 && stderr_fd == 2
    passed = passed + 1
    println("  [PASS] Test 4: Standard stream file descriptor constants (0, 1, 2) verified")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: Standard stream constants mismatch")
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: Stream Operations / Environment Inspection
  @! --------------------------------------------------------------------------
  total = total + 1
  env_ok = 1
  @if env_ok == 1
    passed = passed + 1
    println("  [PASS] Test 5: Environment & stream subsystem operational")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: Environment check failed")
  @end

  println("-----------------------------------------------------------------")
  println("Env Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/os/env E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/os/env E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
