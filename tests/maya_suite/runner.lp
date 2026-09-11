@! ============================================================================
@! MAYA NATIVE TEST RUNNER (tests/runner.maya)
@! 100% Pure Maya Language — Raw Linux Syscalls with Proper argv Pointer Array
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"

@struct ProcessStatus
  val: 0
@end

@fn run_test(test_path)
  println(str_concat("▶ Running test: ", test_path))
  
  tmp_bin = "/tmp/_test_runner_bin"
  
  @! Stage 1: Compile the test using the sovereign self-hosted compiler
  comp_pid = sys_fork()
  @if comp_pid == 0
    comp_argv = ["./bin/lipc", test_path, "-o", tmp_bin, 0]
    sys_execve("./bin/lipc", comp_argv, 0)
    sys_exit(1)
  @end
  
  @if comp_pid > 0
    ps = { val: 0 }
    sys_wait4(comp_pid, ps, 0, 0)
    status = ps.val
    @if process_wifexited(status) == 1
      comp_exit = process_wexitstatus(status)
      @if comp_exit != 0
        println(str_concat("  ❌ FAIL: Compilation error code ", to_str(comp_exit)))
        return 1
      @end
    @else
      println("  ❌ FAIL: Compiler crashed")
      return 1
    @end
  @end

  @! Stage 2: Execute the compiled standalone binary directly
  exec_pid = sys_fork()
  @if exec_pid == 0
    exec_argv = [tmp_bin, 0]
    sys_execve(tmp_bin, exec_argv, 0)
    sys_exit(1)
  @end

  @if exec_pid > 0
    ps = { val: 0 }
    sys_wait4(exec_pid, ps, 0, 0)
    status = ps.val
    
    @if process_wifexited(status) == 1
      exit_code = process_wexitstatus(status)
      @if exit_code == 0
        println(str_concat("  ✔ PASS: ", test_path))
        return 0
      @else
        println(str_concat("  ❌ FAIL: ", test_path))
        println(str_concat("    exit code: ", to_str(exit_code)))
        return 1
      @end
    @elif process_wifsignaled(status) == 1
      sig = process_wtermsig(status)
      println(str_concat("  ❌ CRASH: ", test_path))
      println(str_concat("    signal: ", to_str(sig)))
      return 1
    @else
      println(str_concat("  ❌ FAIL: ", test_path))
      println(str_concat("    unknown status: ", to_str(status)))
      return 1
    @end
  @end
  
  println("  ❌ FAIL: sys_fork failed")
  return 1
@end

@fn main()
  println("=================================================================")
  println("🚀 MAYA SOVEREIGN TEST RUNNER (UNMOCKED PROCESS ISOLATION) 🚀")
  println("=================================================================")
  
  fails = 0
  // WHY: Advanced features and native tests relocated to docs/maya_heritage/tests_experimental/universe for clean repo layout
  fails = fails + run_test("docs/maya_heritage/tests_experimental/universe/test_advanced_features.lp")
  fails = fails + run_test("docs/maya_heritage/tests_experimental/universe/test_crypto_sha256.lp")
  fails = fails + run_test("docs/maya_heritage/tests_experimental/universe/test_native_basic2.lp")
  
  println("=================================================================")
  @if fails == 0
    println("✔ ALL TEST SUITES PASSED CLEANLY!")
    return 0
  @else
    println(str_concat("❌ FAILED TEST SUITES: ", to_str(fails)))
    return 1
  @end
@end
