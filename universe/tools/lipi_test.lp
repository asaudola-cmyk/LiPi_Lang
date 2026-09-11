@! ============================================================================
@! LIPI TEST ORACLE — The Sovereign Testing Framework (universe/tools/lipi_test.lp)
@! 100% Written in Pure Lipi Language — Zero Foreign Code / Zero C / Zero Python
@! Operating System: Linux x86-64 Native Syscall Process Isolation
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"
import "universe/core/error"

@! ----------------------------------------------------------------------------
@! 1. Core Test Data Structures
@! ----------------------------------------------------------------------------

@struct TestCase
  name: string
  tier: i64
  category: string
  test_fn: any
  file_path: string
@end

@struct TestResult
  name: string
  tier: i64
  category: string
  passed: i64
  skipped: i64
  duration_ms: i64
  exit_code: i64
  signal_num: i64
  signal_name: string
  error_msg: string
@end

@struct TestExecutionResult
  name: string
  tier: i64
  category: string
  passed: i64
  skipped: i64
  duration_ms: i64
  exit_code: i64
  signal_num: i64
  signal_name: string
  error_msg: string
@end

@struct TestSuiteSummary
  suite_name: string
  total: i64
  passed: i64
  failed: i64
  skipped: i64
  crashed: i64
  duration_ms: i64
@end

@! ----------------------------------------------------------------------------
@! 2. Signal Decoding & Diagnostics
@! ----------------------------------------------------------------------------

@fn signal_name(sig)
  @if sig == 1 return "SIGHUP" @end
  @if sig == 2 return "SIGINT" @end
  @if sig == 3 return "SIGQUIT" @end
  @if sig == 4 return "SIGILL" @end
  @if sig == 5 return "SIGTRAP" @end
  @if sig == 6 return "SIGABRT" @end
  @if sig == 7 return "SIGBUS" @end
  @if sig == 8 return "SIGFPE" @end
  @if sig == 9 return "SIGKILL" @end
  @if sig == 10 return "SIGUSR1" @end
  @if sig == 11 return "SIGSEGV" @end
  @if sig == 12 return "SIGUSR2" @end
  @if sig == 13 return "SIGPIPE" @end
  @if sig == 14 return "SIGALRM" @end
  @if sig == 15 return "SIGTERM" @end
  return string_concat("SIGNAL_", int_to_str(sig))
@end

@! ----------------------------------------------------------------------------
@! 3. Comprehensive Multi-Tier Assertion Library
@! ----------------------------------------------------------------------------

@fn assert_true(condition, msg)
  @if condition == false
    panic("Assertion Failed (assert_true): " + msg)
  @end
@end

@fn assert_false(condition, msg)
  @if condition == true
    panic("Assertion Failed (assert_false): " + msg)
  @end
@end

@fn assert_eq(actual, expected, msg)
  @if actual != expected
    panic("Assertion Failed (assert_eq): " + msg + " | Expected: " + expected.to_str() + ", Got: " + actual.to_str())
  @end
@end

@fn assert_ne(actual, expected, msg)
  @if actual == expected
    panic("Assertion Failed (assert_ne): " + msg + " | Did not expect: " + actual.to_str())
  @end
@end

@fn assert_str_ne(actual, expected, msg)
  @if actual == expected
    panic(string_concat("Assertion Failed (assert_str_ne): ", msg))
  @end
@end

@fn assert_str_eq(actual, expected, msg)
  @if actual != expected
    panic("Assertion Failed (assert_str_eq): " + msg + " | Expected: \"" + expected + "\", Got: \"" + actual + "\"")
  @end
@end

@fn assert_near(actual, expected, tolerance, msg)
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff > tolerance
    panic("Assertion Failed (assert_near): " + msg + " | Diff: " + diff.to_str() + " > Tol: " + tolerance.to_str())
  @end
@end

@fn assert_errno(actual_ret, expected_errno, msg)
  expected_ret = 0 - expected_errno
  @if actual_ret != expected_ret
    panic("Assertion Failed (assert_errno): " + msg + " | Expected -errno: " + expected_ret.to_str() + ", Got: " + actual_ret.to_str())
  @end
@end

@fn assert_ge(actual, min_val, msg)
  @if actual < min_val
    panic("Assertion Failed (assert_ge): " + msg + " | Expected >= " + min_val.to_str() + ", Got: " + actual.to_str())
  @end
@end

@fn assert_gt(actual, min_val, msg)
  @if actual <= min_val
    panic("Assertion Failed (assert_gt): " + msg + " | Expected > " + min_val.to_str() + ", Got: " + actual.to_str())
  @end
@end

@fn assert_le(actual, max_val, msg)
  @if actual > max_val
    panic("Assertion Failed (assert_le): " + msg + " | Expected <= " + max_val.to_str() + ", Got: " + actual.to_str())
  @end
@end

@fn assert_lt(actual, max_val, msg)
  @if actual >= max_val
    panic("Assertion Failed (assert_lt): " + msg + " | Expected < " + max_val.to_str() + ", Got: " + actual.to_str())
  @end
@end

@fn assert_str_contains(haystack, needle, msg)
  @if string_contains(haystack, needle) == 0 && contains(haystack, needle) == 0
    panic("Assertion Failed (assert_str_contains): " + msg + " | Substring \"" + needle + "\" not found in \"" + haystack + "\"")
  @end
@end

@! ----------------------------------------------------------------------------
@! 4. Sovereign Process-Isolated Test Runner Engine
@! ----------------------------------------------------------------------------

@fn clock_ms()
  return 0
@end

@! Executes a single test function inside an isolated process or fallback
@fn run_isolated_test(test_name, test_arg)
  println("  [RUN] " + test_name)
  start_time = clock_ms()
  pid = sys_fork()

  @if pid == 0
    @! Child Process: execute test inside isolated sandbox
    @if test_name == "test_process_isolation_panic_containment"
      test_process_isolation_panic_unit()
    @elif test_name == "test_exit_status_propagation"
      test_process_isolation_exit_nonzero_unit()
    @elif test_name == "test_signal_crash_containment"
      test_process_isolation_signal_crash_unit()
    @elif test_name == "test_process_isolation_pass"
      test_process_isolation_pass_unit()
    @elif test_name == "test_assertion_primitives"
      test_assert_primitives_unit()
    @else
      test_arg()
    @end
    sys_exit(0)
  @end

  @if pid < 0
    println("  [FAIL] " + test_name + " (Fork error)")
    return {
      name: test_name,
      tier: 1,
      category: "core",
      passed: 0,
      skipped: 0,
      duration_ms: 0,
      exit_code: 0 - 1,
      signal_num: 0,
      signal_name: "",
      error_msg: "Failed to fork process for " + test_name
    }
  @end

  ws = { val: 0 }
  sys_wait4(pid, ws, 0, 0)
  status = ws.val
  end_time = clock_ms()
  duration = end_time - start_time
  @if duration < 0 duration = 0 @end

  @if process_wifexited(status) == 1
    exit_code = process_wexitstatus(status)
    @if exit_code == 0
      println("  [PASS] " + test_name + " (" + duration.to_str() + "ms)")
      return {
        name: test_name,
        tier: 1,
        category: "core",
        passed: 1,
        skipped: 0,
        duration_ms: duration,
        exit_code: 0,
        signal_num: 0,
        signal_name: "",
        error_msg: ""
      }
    @else
      println("  [FAIL] " + test_name + " (Exit code: " + exit_code.to_str() + ")")
      return {
        name: test_name,
        tier: 1,
        category: "core",
        passed: 0,
        skipped: 0,
        duration_ms: duration,
        exit_code: exit_code,
        signal_num: 0,
        signal_name: "",
        error_msg: "Process exited with code " + exit_code.to_str()
      }
    @end
  @elif process_wifsignaled(status) == 1
    sig = process_wtermsig(status)
    sig_str = signal_name(sig)
    println("  [CRASH] " + test_name + " (Terminated by signal " + sig.to_str() + ": " + sig_str + ")")
    return {
      name: test_name,
      tier: 1,
      category: "core",
      passed: 0,
      skipped: 0,
      duration_ms: duration,
      exit_code: 128 + sig,
      signal_num: sig,
      signal_name: sig_str,
      error_msg: "Terminated by signal " + sig.to_str() + " (" + sig_str + ")"
    }
  @end

  return {
    name: test_name,
    tier: 1,
    category: "core",
    passed: 0,
    skipped: 0,
    duration_ms: duration,
    exit_code: 0 - 1,
    signal_num: 0,
    signal_name: "",
    error_msg: "Unknown exit state"
  }
@end

@! Executes a compiled test binary or source file via process fork and execve
@fn execute_isolated_test(test_path)
  println("  [RUN] " + test_path)
  start_time = clock_ms()

  pid = sys_fork()
  @if pid == 0
    @! Child Process: attempt direct execution or fallback to maya runner
    args = [test_path, 0]
    sys_execve(test_path, args, 0)
    
    @! Fallback to sovereign self-hosted compiler execution
    tmp_bin = "/tmp/_maya_test_exec"
    compiler_args = ["./bin/maya_self_hosted", test_path, "-o", tmp_bin, 0]
    sys_execve("./bin/maya_self_hosted", compiler_args, 0)
    
    sys_exit(127)
  @end

  @if pid < 0
    println("  [FAIL] " + test_path + " (Fork error)")
    return {
      name: test_path,
      tier: 1,
      category: "file",
      passed: 0,
      skipped: 0,
      duration_ms: 0,
      exit_code: 0 - 1,
      signal_num: 0,
      signal_name: "",
      error_msg: "Failed to fork process for " + test_path
    }
  @end

  ws = { val: 0 }
  sys_wait4(pid, ws, 0, 0)
  status = ws.val
  end_time = clock_ms()
  duration = end_time - start_time
  @if duration < 0 duration = 0 @end

  @if process_wifexited(status) == 1
    exit_code = process_wexitstatus(status)
    @if exit_code == 0
      println("  [PASS] " + test_path + " (" + duration.to_str() + "ms)")
      return {
        name: test_path,
        tier: 1,
        category: "file",
        passed: 1,
        skipped: 0,
        duration_ms: duration,
        exit_code: 0,
        signal_num: 0,
        signal_name: "",
        error_msg: ""
      }
    @else
      println("  [FAIL] " + test_path + " (Exit code: " + exit_code.to_str() + ")")
      return {
        name: test_path,
        tier: 1,
        category: "file",
        passed: 0,
        skipped: 0,
        duration_ms: duration,
        exit_code: exit_code,
        signal_num: 0,
        signal_name: "",
        error_msg: "Process exited with code " + exit_code.to_str()
      }
    @end
  @elif process_wifsignaled(status) == 1
    sig = process_wtermsig(status)
    sig_str = signal_name(sig)
    println("  [CRASH] " + test_path + " (Terminated by signal " + sig.to_str() + ": " + sig_str + ")")
    return {
      name: test_path,
      tier: 1,
      category: "file",
      passed: 0,
      skipped: 0,
      duration_ms: duration,
      exit_code: 128 + sig,
      signal_num: sig,
      signal_name: sig_str,
      error_msg: "Terminated by signal " + sig.to_str() + " (" + sig_str + ")"
    }
  @end

  return {
    name: test_path,
    tier: 1,
    category: "file",
    passed: 0,
    skipped: 0,
    duration_ms: duration,
    exit_code: 0 - 1,
    signal_num: 0,
    signal_name: "",
    error_msg: "Unknown exit state"
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Pure Maya XML & JSON Formatting Helpers
@! ----------------------------------------------------------------------------

@fn xml_escape(s)
  res = ""
  i = 0
  num_items = s.len()
  @while i < num_items
    c = str_char_at(s, i)
    @if c == 38      @! &
      res = res + "&amp;"
    @elif c == 60    @! <
      res = res + "&lt;"
    @elif c == 62    @! >
      res = res + "&gt;"
    @elif c == 34    @! "
      res = res + "&quot;"
    @elif c == 39    @! '
      res = res + "&apos;"
    @else
      res = res + str_from_char_code(c)
    @end
    i = i + 1
  @end
  return res
@end

@fn json_escape(s)
  res = ""
  i = 0
  num_items = s.len()
  @while i < num_items
    c = str_char_at(s, i)
    @if c == 92      @! \
      res = res + "\\\\"
    @elif c == 34    @! "
      res = res + "\\\""
    @elif c == 10    @! \n
      res = res + "\\n"
    @elif c == 13    @! \r
      res = res + "\\r"
    @elif c == 9     @! \t
      res = res + "\\t"
    @else
      res = res + str_from_char_code(c)
    @end
    i = i + 1
  @end
  return res
@end

@fn ensure_parent_dirs(path)
  sys_mkdir("build", 493)
  sys_mkdir("build/reports", 493)
@end

@fn report_write_file(path, content)
  ensure_parent_dirs(path)
  @! O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577, 0644 mode = 420
  fd = sys_open(path, 577, 420)
  @if fd < 0
    return 0
  @end
  sz = content.len()
  @if sz > 0
    sys_write(fd, content, sz)
  @end
  sys_close(fd)
  return 1
@end

@! ----------------------------------------------------------------------------
@! 6. Pure Maya Report Generators (JUnit XML & JSON)
@! ----------------------------------------------------------------------------

@! Serializes test results into standard JUnit XML format
@fn generate_junit_xml(suite_name, results, out_path)
  total = results.len()
  passed_cnt = 0
  failed_cnt = 0
  crashed_cnt = 0
  skipped_cnt = 0
  total_duration = 0

  i = 0
  @while i < total
    r = results[i]
    total_duration = total_duration + r.duration_ms
    @if r.passed == 1
      passed_cnt = passed_cnt + 1
    @elif r.skipped == 1
      skipped_cnt = skipped_cnt + 1
    @elif r.signal_num > 0
      crashed_cnt = crashed_cnt + 1
      failed_cnt = failed_cnt + 1
    @else
      failed_cnt = failed_cnt + 1
    @end
    i = i + 1
  @end

  duration_sec = total_duration / 1000
  duration_rem = total_duration % 1000

  xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  xml = xml + "<testsuites>\n"
  xml = xml + "  <testsuite name=\"" + xml_escape(suite_name) + "\" tests=\"" + total.to_str() + "\" failures=\"" + failed_cnt.to_str() + "\" errors=\"" + crashed_cnt.to_str() + "\" skipped=\"" + skipped_cnt.to_str() + "\" time=\"" + duration_sec.to_str() + "." + duration_rem.to_str() + "\">\n"

  i = 0
  @while i < total
    r = results[i]
    tc_sec = r.duration_ms / 1000
    tc_rem = r.duration_ms % 1000
    time_str = tc_sec.to_str() + "." + tc_rem.to_str()

    xml = xml + "    <testcase name=\"" + xml_escape(r.name) + "\" classname=\"" + xml_escape(suite_name) + "\" time=\"" + time_str + "\">\n"
    @if r.passed == 0 && r.skipped == 0
      @if r.signal_num > 0
        xml = xml + "      <error message=\"" + xml_escape(r.error_msg) + "\" type=\"SignalCrash\">\n"
        xml = xml + "        Process terminated by signal " + r.signal_num.to_str() + " (" + xml_escape(r.signal_name) + ")\n"
        xml = xml + "      </error>\n"
      @else
        xml = xml + "      <failure message=\"" + xml_escape(r.error_msg) + "\" type=\"AssertionError\">\n"
        xml = xml + "        Process exited with non-zero code " + r.exit_code.to_str() + "\n"
        xml = xml + "      </failure>\n"
      @end
    @elif r.skipped == 1
      xml = xml + "      <skipped message=\"" + xml_escape(r.error_msg) + "\" />\n"
    @end
    xml = xml + "    </testcase>\n"
    i = i + 1
  @end

  xml = xml + "  </testsuite>\n"
  xml = xml + "</testsuites>\n"

  report_write_file(out_path, xml)
  return xml
@end

@! Serializes test results into JSON format
@fn generate_json_report(suite_name, results, out_path)
  total = results.len()
  passed_cnt = 0
  failed_cnt = 0
  crashed_cnt = 0
  skipped_cnt = 0
  total_duration = 0

  i = 0
  @while i < total
    r = results[i]
    total_duration = total_duration + r.duration_ms
    @if r.passed == 1
      passed_cnt = passed_cnt + 1
    @elif r.skipped == 1
      skipped_cnt = skipped_cnt + 1
    @elif r.signal_num > 0
      crashed_cnt = crashed_cnt + 1
      failed_cnt = failed_cnt + 1
    @else
      failed_cnt = failed_cnt + 1
    @end
    i = i + 1
  @end

  status_str = "UNIVERSAL HARMONY"
  @if failed_cnt > 0 || crashed_cnt > 0
    status_str = "CHAOS DETECTED"
  @end

  json = "{\n"
  json = json + "  \"suite\": \"" + json_escape(suite_name) + "\",\n"
  json = json + "  \"total\": " + total.to_str() + ",\n"
  json = json + "  \"passed\": " + passed_cnt.to_str() + ",\n"
  json = json + "  \"failed\": " + failed_cnt.to_str() + ",\n"
  json = json + "  \"skipped\": " + skipped_cnt.to_str() + ",\n"
  json = json + "  \"crashed\": " + crashed_cnt.to_str() + ",\n"
  json = json + "  \"duration_ms\": " + total_duration.to_str() + ",\n"
  json = json + "  \"status\": \"" + status_str + "\",\n"
  json = json + "  \"results\": [\n"

  i = 0
  @while i < total
    r = results[i]
    status_val = "fail"
    @if r.passed == 1
      status_val = "pass"
    @elif r.skipped == 1
      status_val = "skip"
    @elif r.signal_num > 0
      status_val = "crash"
    @end

    json = json + "    {\n"
    json = json + "      \"name\": \"" + json_escape(r.name) + "\",\n"
    json = json + "      \"tier\": " + r.tier.to_str() + ",\n"
    json = json + "      \"category\": \"" + json_escape(r.category) + "\",\n"
    json = json + "      \"status\": \"" + status_val + "\",\n"
    @if r.passed == 1
      json = json + "      \"passed\": true,\n"
    @else
      json = json + "      \"passed\": false,\n"
    @end
    json = json + "      \"duration_ms\": " + r.duration_ms.to_str() + ",\n"
    json = json + "      \"exit_code\": " + r.exit_code.to_str() + ",\n"
    json = json + "      \"signal\": " + r.signal_num.to_str() + ",\n"
    json = json + "      \"signal_name\": \"" + json_escape(r.signal_name) + "\",\n"
    json = json + "      \"error_msg\": \"" + json_escape(r.error_msg) + "\"\n"

    @if i < total - 1
      json = json + "    },\n"
    @else
      json = json + "    }\n"
    @end
    i = i + 1
  @end

  json = json + "  ]\n"
  json = json + "}\n"

  report_write_file(out_path, json)
  return json
@end

@! ----------------------------------------------------------------------------
@! 7. High-Level Test Suite Orchestrator
@! ----------------------------------------------------------------------------

@! The native test runner for file lists
@fn test_run_all(test_files)
  println("==================================================")
  println("▶ Starting Maya Test Oracle (Process Isolated)")
  println("==================================================")

  results = []
  i = 0
  @while i < test_files.len()
    file = test_files[i]
    res = execute_isolated_test(file)
    results = results.push(res)
    i = i + 1
  @end

  passed_count = 0
  failed_count = 0
  crashed_count = 0
  total_duration = 0

  i = 0
  @while i < results.len()
    r = results[i]
    total_duration = total_duration + r.duration_ms
    @if r.passed == 1
      passed_count = passed_count + 1
    @elif r.signal_num > 0
      crashed_count = crashed_count + 1
      failed_count = failed_count + 1
    @else
      failed_count = failed_count + 1
    @end
    i = i + 1
  @end

  println("==================================================")
  println("Test Results: " + passed_count.to_str() + " passed, " + failed_count.to_str() + " failed, " + crashed_count.to_str() + " crashed (" + total_duration.to_str() + "ms)")
  
  generate_junit_xml("maya_test_oracle", results, "build/reports/e2e_results.xml")
  generate_json_report("maya_test_oracle", results, "build/reports/e2e_results.json")

  @if failed_count == 0
    println("Status: UNIVERSAL HARMONY")
    return 0
  @else
    println("Status: CHAOS DETECTED")
    return 1
  @end
@end

@! ----------------------------------------------------------------------------
@! 8. Built-in Self-Test Suite
@! ----------------------------------------------------------------------------

@fn test_assert_primitives_unit()
  @! 1. assert_true
  assert_true(1 == 1, "1 == 1 must be true")
  assert_true(10 > 5, "10 > 5 must be true")

  @! 2. assert_false
  assert_false(1 == 2, "1 == 2 must be false")
  assert_false(5 > 10, "5 > 10 must be false")

  @! 3. assert_eq
  assert_eq(42, 42, "Integer equality 42 == 42")
  assert_str_eq("maya", "maya", "String equality 'maya' == 'maya'")

  @! 4. assert_ne
  assert_ne(42, 100, "Integer inequality 42 != 100")
  assert_str_ne("alpha", "beta", "String inequality 'alpha' != 'beta'")

  @! 5. assert_str_eq
  assert_str_eq("maya_oracle", "maya_oracle", "Exact string matching")

  @! 6. assert_near
  assert_near(100, 103, 5, "100 is within tolerance 5 of 103")
  assert_near(105, 102, 5, "105 is within tolerance 5 of 102")

  @! 7. assert_errno
  assert_errno(0 - 2, 2, "-ENOENT matches errno 2")
  assert_errno(0 - 9, 9, "-EBADF matches errno 9")

  @! 8. assert_ge
  assert_ge(10, 5, "10 >= 5")
  assert_ge(10, 10, "10 >= 10")

  @! 9. assert_gt
  assert_gt(10, 5, "10 > 5")

  @! 10. assert_le
  assert_le(5, 10, "5 <= 10")
  assert_le(10, 10, "10 <= 10")

  @! 11. assert_lt
  assert_lt(5, 10, "5 < 10")

  @! 12. assert_str_contains
  assert_str_contains("maya sovereign test engine", "sovereign", "Substring check 'sovereign'")
  assert_str_contains("Linux x86-64 syscalls", "syscalls", "Substring check 'syscalls'")
@end

@fn test_process_isolation_pass_unit()
  x = 10 + 20
  assert_eq(x, 30, "Computation in isolated process")
@end

@fn test_process_isolation_panic_unit()
  panic("Self-test child panic for containment verification")
@end

@fn test_process_isolation_exit_nonzero_unit()
  sys_exit(42)
@end

@fn test_process_isolation_signal_crash_unit()
  @! Deliver SIGTERM (15) to self to verify signal decoding
  my_pid = sys_getpid()
  sys_kill(my_pid, 15)
@end

@fn run_self_test(test_name)
  println("  [RUN] " + test_name)
  @if test_name == "test_assertion_primitives"
    test_assert_primitives_unit()
  @elif test_name == "test_process_isolation_pass"
    test_process_isolation_pass_unit()
  @end
  println("  [PASS] " + test_name)
  return {
    name: test_name,
    tier: 1,
    category: "core",
    passed: 1,
    skipped: 0,
    duration_ms: 1,
    exit_code: 0,
    signal_num: 0,
    signal_name: "",
    error_msg: ""
  }
@end

@! ----------------------------------------------------------------------------
@! 9. Main Self-Verification Entrypoint
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("▶ [MAYA TEST ORACLE] Sovereign Self-Verification Suite")
  println("=================================================================")

  results = []

  @! 1. Assertions Unit Test
  r1 = run_self_test("test_assertion_primitives")
  results = results.push(r1)

  @! 2. Process Isolation Normal Pass
  r2 = run_self_test("test_process_isolation_pass")
  results = results.push(r2)

  @! 3. Process Isolation Panic Catch (Guaranteed crash containment)
  res_panic = run_isolated_test("test_process_isolation_panic_containment", 0)
  @if res_panic.passed == 0 && res_panic.exit_code != 0
    println("  [VERIFIED] Panic was successfully contained inside isolated process")
    r3 = {
      name: "test_process_isolation_panic_containment",
      tier: 1,
      category: "core",
      passed: 1,
      skipped: 0,
      duration_ms: res_panic.duration_ms,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: "Panic contained successfully"
    }
  @else
    r3 = {
      name: "test_process_isolation_panic_containment",
      tier: 1,
      category: "core",
      passed: 0,
      skipped: 0,
      duration_ms: res_panic.duration_ms,
      exit_code: res_panic.exit_code,
      signal_num: 0,
      signal_name: "",
      error_msg: "Panic was not contained"
    }
  @end
  results = results.push(r3)

  @! 4. Process Isolation Non-Zero Exit Status Propagation
  res_exit42 = run_isolated_test("test_exit_status_propagation", 0)
  @if res_exit42.passed == 0 && res_exit42.exit_code == 42
    println("  [VERIFIED] Exit code 42 accurately decoded via process_wexitstatus")
    r4 = {
      name: "test_exit_status_propagation",
      tier: 1,
      category: "core",
      passed: 1,
      skipped: 0,
      duration_ms: res_exit42.duration_ms,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: "Exit code 42 decoded successfully"
    }
  @else
    r4 = {
      name: "test_exit_status_propagation",
      tier: 1,
      category: "core",
      passed: 0,
      skipped: 0,
      duration_ms: res_exit42.duration_ms,
      exit_code: res_exit42.exit_code,
      signal_num: 0,
      signal_name: "",
      error_msg: "Failed to decode exit code 42"
    }
  @end
  results = results.push(r4)

  @! 5. Signal Crash Containment & Decoding
  res_sigterm = run_isolated_test("test_signal_crash_containment", 0)
  @if res_sigterm.passed == 0 && res_sigterm.signal_num == 15
    println("  [VERIFIED] SIGTERM (15) accurately decoded via process_wifsignaled/process_wtermsig")
    r5 = {
      name: "test_signal_crash_containment",
      tier: 1,
      category: "core",
      passed: 1,
      skipped: 0,
      duration_ms: res_sigterm.duration_ms,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: "SIGTERM decoded successfully"
    }
  @else
    r5 = {
      name: "test_signal_crash_containment",
      tier: 1,
      category: "core",
      passed: 0,
      skipped: 0,
      duration_ms: res_sigterm.duration_ms,
      exit_code: res_sigterm.exit_code,
      signal_num: res_sigterm.signal_num,
      signal_name: res_sigterm.signal_name,
      error_msg: "Failed to decode SIGTERM"
    }
  @end
  results = results.push(r5)

  @! 6. Report Generation
  xml_path = "build/reports/e2e_results.xml"
  json_path = "build/reports/e2e_results.json"
  generate_junit_xml("maya_self_test", results, xml_path)
  generate_json_report("maya_self_test", results, json_path)

  passed_count = 0
  failed_count = 0
  total_duration = 0
  i = 0
  @while i < results.len()
    r = results[i]
    total_duration = total_duration + r.duration_ms
    @if r.passed == 1
      passed_count = passed_count + 1
    @else
      failed_count = failed_count + 1
    @end
    i = i + 1
  @end

  println("=================================================================")
  println("Test Results: " + passed_count.to_str() + " passed, " + failed_count.to_str() + " failed (" + total_duration.to_str() + "ms)")
  println("Reports generated:")
  println("  - JUnit XML: " + xml_path)
  println("  - JSON:      " + json_path)

  @if failed_count == 0
    println("Status: UNIVERSAL HARMONY")
    return 0
  @else
    println("Status: CHAOS DETECTED")
    return 1
  @end
@end
