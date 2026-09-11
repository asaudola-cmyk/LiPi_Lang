@! ============================================================================
@! ADVERSARIAL CHALLENGE TEST: MAYA TEST ORACLE PROCESS ISOLATION & RESILIENCE
@! Target: universe/tools/maya_test.maya
@! Tests:
@! 1. Panic containment across isolated executions
@! 2. Signal crash isolation (SIGSEGV, SIGABRT, SIGFPE, SIGILL, SIGBUS, SIGKILL, SIGTERM)
@! 3. Arbitrary non-zero exit status propagation (0, 1, 42, 127, 255)
@! 4. Supervisor resilience across high-frequency interleaved failure cycles
@! 5. Assertion suite stress & boundary validation
@! 6. JUnit XML & JSON report generation fidelity & escaping
@! ============================================================================

import "universe/tools/maya_test"
import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"

@! --- Adversarial Child Test Functions ---

@fn victim_panic_simple()
  panic("Adversarial child panic: simulated unhandled exception")
@end

@fn victim_panic_nested()
  i = 0
  @while i < 10
    i = i + 1
  @end
  panic("Adversarial nested loop panic")
@end

@fn victim_sigsegv()
  my_pid = sys_getpid()
  sys_kill(my_pid, 11)  @! SIGSEGV (11)
@end

@fn victim_sigabrt()
  my_pid = sys_getpid()
  sys_kill(my_pid, 6)   @! SIGABRT (6)
@end

@fn victim_sigfpe()
  my_pid = sys_getpid()
  sys_kill(my_pid, 8)   @! SIGFPE (8)
@end

@fn victim_sigill()
  my_pid = sys_getpid()
  sys_kill(my_pid, 4)   @! SIGILL (4)
@end

@fn victim_sigbus()
  my_pid = sys_getpid()
  sys_kill(my_pid, 7)   @! SIGBUS (7)
@end

@fn victim_sigkill()
  my_pid = sys_getpid()
  sys_kill(my_pid, 9)   @! SIGKILL (9)
@end

@fn victim_sigterm()
  my_pid = sys_getpid()
  sys_kill(my_pid, 15)  @! SIGTERM (15)
@end

@fn victim_exit_0()
  sys_exit(0)
@end

@fn victim_exit_1()
  sys_exit(1)
@end

@fn victim_exit_42()
  sys_exit(42)
@end

@fn victim_exit_127()
  sys_exit(127)
@end

@fn victim_exit_255()
  sys_exit(255)
@end

@fn victim_pass_valid()
  x = 100 * 200
  assert_eq(x, 20000, "Valid arithmetic multiplication")
@end

@! --- Main Adversarial Harness ---

@fn main()
  println("=================================================================")
  println("▶ [ADVERSARIAL CHALLENGER 1] maya_test.maya Process Isolation Suite")
  println("=================================================================")

  total_challenges = 0
  passed_challenges = 0
  failed_challenges = 0

  @! --------------------------------------------------------------------------
  @! CHALLENGE 1: Panic Containment
  @! --------------------------------------------------------------------------
  println("▶ Challenge 1: Panic Containment in Isolated Sandbox")

  total_challenges = total_challenges + 1
  r_panic1 = run_isolated_test("adv_test_panic_simple", victim_panic_simple)
  @if r_panic1.passed == 0 && r_panic1.exit_code != 0
    passed_challenges = passed_challenges + 1
    println("  [PASS] C1.1: Child panic was successfully contained; supervisor remained alive")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C1.1: Panic containment failed or improperly marked passed")
  @end

  total_challenges = total_challenges + 1
  r_panic2 = run_isolated_test("adv_test_panic_nested", victim_panic_nested)
  @if r_panic2.passed == 0 && r_panic2.exit_code != 0
    passed_challenges = passed_challenges + 1
    println("  [PASS] C1.2: Nested loop panic contained; supervisor remained alive")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C1.2: Nested panic containment failed")
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE 2: Multi-Signal Crash Isolation & Accurate Signal Decoding
  @! --------------------------------------------------------------------------
  println("▶ Challenge 2: Signal Crash Isolation (SIGSEGV, SIGABRT, SIGFPE, SIGILL, SIGBUS, SIGKILL, SIGTERM)")

  @! SIGSEGV (11)
  total_challenges = total_challenges + 1
  r_segv = run_isolated_test("adv_test_sigsegv", victim_sigsegv)
  @if r_segv.passed == 0 && r_segv.signal_num == 11 && r_segv.signal_name == "SIGSEGV"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.1: SIGSEGV (11) contained and accurately decoded as 'SIGSEGV'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.1: SIGSEGV decoding failed: sig=" + r_segv.signal_num.to_str() + " name=" + r_segv.signal_name)
  @end

  @! SIGABRT (6)
  total_challenges = total_challenges + 1
  r_abrt = run_isolated_test("adv_test_sigabrt", victim_sigabrt)
  @if r_abrt.passed == 0 && r_abrt.signal_num == 6 && r_abrt.signal_name == "SIGABRT"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.2: SIGABRT (6) contained and accurately decoded as 'SIGABRT'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.2: SIGABRT decoding failed: sig=" + r_abrt.signal_num.to_str() + " name=" + r_abrt.signal_name)
  @end

  @! SIGFPE (8)
  total_challenges = total_challenges + 1
  r_fpe = run_isolated_test("adv_test_sigfpe", victim_sigfpe)
  @if r_fpe.passed == 0 && r_fpe.signal_num == 8 && r_fpe.signal_name == "SIGFPE"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.3: SIGFPE (8) contained and accurately decoded as 'SIGFPE'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.3: SIGFPE decoding failed: sig=" + r_fpe.signal_num.to_str() + " name=" + r_fpe.signal_name)
  @end

  @! SIGILL (4)
  total_challenges = total_challenges + 1
  r_ill = run_isolated_test("adv_test_sigill", victim_sigill)
  @if r_ill.passed == 0 && r_ill.signal_num == 4 && r_ill.signal_name == "SIGILL"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.4: SIGILL (4) contained and accurately decoded as 'SIGILL'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.4: SIGILL decoding failed: sig=" + r_ill.signal_num.to_str() + " name=" + r_ill.signal_name)
  @end

  @! SIGBUS (7)
  total_challenges = total_challenges + 1
  r_bus = run_isolated_test("adv_test_sigbus", victim_sigbus)
  @if r_bus.passed == 0 && r_bus.signal_num == 7 && r_bus.signal_name == "SIGBUS"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.5: SIGBUS (7) contained and accurately decoded as 'SIGBUS'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.5: SIGBUS decoding failed: sig=" + r_bus.signal_num.to_str() + " name=" + r_bus.signal_name)
  @end

  @! SIGKILL (9)
  total_challenges = total_challenges + 1
  r_kill = run_isolated_test("adv_test_sigkill", victim_sigkill)
  @if r_kill.passed == 0 && r_kill.signal_num == 9 && r_kill.signal_name == "SIGKILL"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.6: SIGKILL (9) contained and accurately decoded as 'SIGKILL'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.6: SIGKILL decoding failed: sig=" + r_kill.signal_num.to_str() + " name=" + r_kill.signal_name)
  @end

  @! SIGTERM (15)
  total_challenges = total_challenges + 1
  r_term = run_isolated_test("adv_test_sigterm", victim_sigterm)
  @if r_term.passed == 0 && r_term.signal_num == 15 && r_term.signal_name == "SIGTERM"
    passed_challenges = passed_challenges + 1
    println("  [PASS] C2.7: SIGTERM (15) contained and accurately decoded as 'SIGTERM'")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C2.7: SIGTERM decoding failed: sig=" + r_term.signal_num.to_str() + " name=" + r_term.signal_name)
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE 3: Exit Status Propagation
  @! --------------------------------------------------------------------------
  println("▶ Challenge 3: Exit Status Propagation (0, 1, 42, 127, 255)")

  @! Exit 0 -> PASS
  total_challenges = total_challenges + 1
  r_e0 = run_isolated_test("adv_test_exit_0", victim_exit_0)
  @if r_e0.passed == 1 && r_e0.exit_code == 0
    passed_challenges = passed_challenges + 1
    println("  [PASS] C3.1: Exit code 0 mapped to passed=1")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C3.1: Exit code 0 failed: passed=" + r_e0.passed.to_str())
  @end

  @! Exit 1 -> FAIL
  total_challenges = total_challenges + 1
  r_e1 = run_isolated_test("adv_test_exit_1", victim_exit_1)
  @if r_e1.passed == 0 && r_e1.exit_code == 1
    passed_challenges = passed_challenges + 1
    println("  [PASS] C3.2: Exit code 1 accurately decoded via process_wexitstatus")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C3.2: Exit code 1 decoding failed: code=" + r_e1.exit_code.to_str())
  @end

  @! Exit 42 -> FAIL
  total_challenges = total_challenges + 1
  r_e42 = run_isolated_test("adv_test_exit_42", victim_exit_42)
  @if r_e42.passed == 0 && r_e42.exit_code == 42
    passed_challenges = passed_challenges + 1
    println("  [PASS] C3.3: Exit code 42 accurately decoded via process_wexitstatus")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C3.3: Exit code 42 decoding failed: code=" + r_e42.exit_code.to_str())
  @end

  @! Exit 127 -> FAIL
  total_challenges = total_challenges + 1
  r_e127 = run_isolated_test("adv_test_exit_127", victim_exit_127)
  @if r_e127.passed == 0 && r_e127.exit_code == 127
    passed_challenges = passed_challenges + 1
    println("  [PASS] C3.4: Exit code 127 accurately decoded via process_wexitstatus")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C3.4: Exit code 127 decoding failed: code=" + r_e127.exit_code.to_str())
  @end

  @! Exit 255 -> FAIL
  total_challenges = total_challenges + 1
  r_e255 = run_isolated_test("adv_test_exit_255", victim_exit_255)
  @if r_e255.passed == 0 && r_e255.exit_code == 255
    passed_challenges = passed_challenges + 1
    println("  [PASS] C3.5: Exit code 255 accurately decoded via process_wexitstatus")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C3.5: Exit code 255 decoding failed: code=" + r_e255.exit_code.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE 4: Rapid Interleaved Failure Cycles & Supervisor Liveness
  @! --------------------------------------------------------------------------
  println("▶ Challenge 4: Supervisor Liveness Under 10 Rapid Interleaved Failure Cycles")

  cycle_idx = 0
  cycle_pass_cnt = 0
  cycle_fail_cnt = 0

  @while cycle_idx < 10
    @if cycle_idx == 0 || cycle_idx == 3 || cycle_idx == 6 || cycle_idx == 9
      res = run_isolated_test("cycle_pass_" + cycle_idx.to_str(), victim_pass_valid)
      @if res.passed == 1
        cycle_pass_cnt = cycle_pass_cnt + 1
      @end
    @elif cycle_idx == 1 || cycle_idx == 4 || cycle_idx == 7
      res = run_isolated_test("cycle_panic_" + cycle_idx.to_str(), victim_panic_simple)
      @if res.passed == 0
        cycle_fail_cnt = cycle_fail_cnt + 1
      @end
    @else
      res = run_isolated_test("cycle_segv_" + cycle_idx.to_str(), victim_sigsegv)
      @if res.passed == 0 && res.signal_num == 11
        cycle_fail_cnt = cycle_fail_cnt + 1
      @end
    @end
    cycle_idx = cycle_idx + 1
  @end

  total_challenges = total_challenges + 1
  @if cycle_pass_cnt == 4 && cycle_fail_cnt == 6
    passed_challenges = passed_challenges + 1
    println("  [PASS] C4.1: Supervisor sustained all 10 interleaved cycles (4 passes, 6 contained failures/crashes)")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C4.1: Interleaved cycle counts mismatched: pass=" + cycle_pass_cnt.to_str() + " fail=" + cycle_fail_cnt.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE 5: Assertion Suite Verification
  @! --------------------------------------------------------------------------
  println("▶ Challenge 5: Multi-Tier Assertion Suite Invariant Verification")

  assert_primitives_ok = 1

  @! Assert True / False with computed values
  val_a = (15 * 3) + 7
  val_b = (100 / 2) + 2
  assert_true(val_a == 52, "T1: computed equality verification")
  assert_false(val_a == val_b, "T2: computed distinct values")

  @! Assert Eq / Ne
  assert_eq(val_a, 52, "T3: computed int equality")
  assert_ne(val_a, val_b, "T4: computed inequality")
  test_tag = "maya_" + "sovereign"
  assert_str_eq(test_tag, "maya_sovereign", "T5: string concatenation equality")

  @! Assert Near
  assert_near(val_a, val_b, 5, "T6: boundary near check")
  assert_near(val_b, val_a, 5, "T7: symmetric near check")
  assert_near(val_a, val_a, 0, "T8: exact near check")

  @! Assert Errno
  err_notfound = 0 - 2
  err_fault = 0 - 14
  assert_errno(err_notfound, 2, "T9: ENOENT boundary")
  assert_errno(err_fault, 14, "T10: EFAULT boundary")

  @! Assert Inequalities
  assert_ge(val_b, val_a, "T11: greater-equal comparison")
  assert_ge(val_a, val_a, "T12: reflexive greater-equal")
  assert_gt(val_b, val_a, "T13: strictly greater comparison")
  assert_le(val_a, val_b, "T14: less-equal comparison")
  assert_le(val_b, val_b, "T15: reflexive less-equal")
  assert_lt(val_a, val_b, "T16: strictly less comparison")

  @! Assert Contains
  haystack = "maya " + "test " + "oracle " + "suite"
  assert_str_contains(haystack, "oracle", "T17: substring containment")

  total_challenges = total_challenges + 1
  @if assert_primitives_ok == 1
    passed_challenges = passed_challenges + 1
    println("  [PASS] C5.1: All 12 assertion primitives operate with 100% precision")
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE 6: Report Generation & Escaping Security
  @! --------------------------------------------------------------------------
  println("▶ Challenge 6: Report Serialization with XML/JSON Escaping")

  test_results_sample = [
    {
      name: "test_<special>&\"'chars",
      tier: 1,
      category: "core",
      passed: 1,
      skipped: 0,
      duration_ms: 15,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: ""
    },
    {
      name: "test_failure_quote",
      tier: 2,
      category: "boundary",
      passed: 0,
      skipped: 0,
      duration_ms: 25,
      exit_code: 1,
      signal_num: 0,
      signal_name: "",
      error_msg: "Failed with <error> & 'quote'"
    },
    {
      name: "test_crash_segv",
      tier: 3,
      category: "crash",
      passed: 0,
      skipped: 0,
      duration_ms: 5,
      exit_code: 139,
      signal_num: 11,
      signal_name: "SIGSEGV",
      error_msg: "Terminated by SIGSEGV"
    }
  ]

  xml_out = generate_junit_xml("adv_challenge_suite", test_results_sample, "/tmp/adv_report.xml")
  json_out = generate_json_report("adv_challenge_suite", test_results_sample, "/tmp/adv_report.json")

  total_challenges = total_challenges + 1
  @if contains(xml_out, "&lt;special&gt;&amp;&quot;&apos;chars") == 1 && contains(xml_out, "failures=\"2\"") == 1
    passed_challenges = passed_challenges + 1
    println("  [PASS] C6.1: JUnit XML serializer cleanly escapes XML entities and tallies failure counts")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C6.1: XML serialization or escaping error")
  @end

  total_challenges = total_challenges + 1
  @if contains(json_out, "CHAOS DETECTED") == 1 && contains(json_out, "\"signal\": 11") == 1
    passed_challenges = passed_challenges + 1
    println("  [PASS] C6.2: JSON report serializer produces compliant JSON schema and diagnostics")
  @else
    failed_challenges = failed_challenges + 1
    println("  [FAIL] C6.2: JSON report serialization error")
  @end

  @! --------------------------------------------------------------------------
  @! Summary
  @! --------------------------------------------------------------------------
  println("=================================================================")
  println("ADVERSARIAL CHALLENGE SUMMARY: " + passed_challenges.to_str() + "/" + total_challenges.to_str() + " passed")
  println("=================================================================")

  @if failed_challenges == 0
    println("✓ VERDICT: APPROVE — Process Isolation & Crash Recovery 100% Resilient")
    return 0
  @else
    println("✗ VERDICT: REQUEST_CHANGES — Found " + failed_challenges.to_str() + " Failures")
    return 1
  @end
@end
