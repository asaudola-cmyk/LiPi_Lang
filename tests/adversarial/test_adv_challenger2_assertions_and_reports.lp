@! ============================================================================
@! ADVERSARIAL CHALLENGER 2: ASSERTION SUITE & XML/JSON ESCAPING STRESS HARNESS
@! Target: universe/tools/maya_test.maya
@! Focus:
@! 1. assert_near: precision, boundary tolerances, negative ranges, symmetry, panics
@! 2. assert_str_eq: empty, multiline, unicode/ascii escapes, mismatch containment
@! 3. assert_errno: negative Linux syscall returns (-2, -9, -13, -22, etc.), panic on success/wrong
@! 4. assert_ge, assert_gt, assert_le, assert_lt: boundary transitions, negative integers, panics
@! 5. assert_str_contains: prefix, middle, suffix, empty needle, missing needle panics
@! 6. assert_true, assert_false, assert_eq, assert_ne: edge conditions
@! 7. xml_escape: ampersand (&), brackets (<, >), quotes (", '), control characters
@! 8. json_escape: backslash (\), quote ("), newline (\n), carriage return (\r), tab (\t)
@! 9. JUnit XML report generation: document structure, tag containment, escaping fidelity
@! 10. JSON report generation: valid syntax, nested fields, status harmony vs chaos
@! ============================================================================

import "universe/tools/maya_test"
import "universe/os/syscalls"
import "universe/os/process"
import "universe/core/string"
import "universe/core/error"

@! ----------------------------------------------------------------------------
@! 1. Adversarial Assertion Victim Functions (Expected to Panic)
@! ----------------------------------------------------------------------------

@fn victim_assert_near_upper_violation()
  assert_near(106, 100, 5, "106 exceeds tolerance 5 from 100")
@end

@fn victim_assert_near_lower_violation()
  assert_near(94, 100, 5, "94 exceeds tolerance 5 from 100")
@end

@fn victim_assert_near_zero_tol_violation()
  assert_near(101, 100, 0, "101 exceeds zero tolerance from 100")
@end

@fn victim_assert_str_eq_mismatch()
  assert_str_eq("expected_alpha", "got_beta", "String mismatch should trigger panic")
@end

@fn victim_assert_str_eq_case_mismatch()
  assert_str_eq("MayaLanguage", "mayalanguage", "Case mismatch should trigger panic")
@end

@fn victim_assert_errno_success_violation()
  @! Syscall returned 0 (success), but caller expected -ENOENT (2)
  assert_errno(0, 2, "Expected -ENOENT but got success 0")
@end

@fn victim_assert_errno_wrong_errno_violation()
  @! Syscall returned -EBADF (-9), but caller expected -ENOENT (2)
  assert_errno(0 - 9, 2, "Expected -ENOENT but got -EBADF")
@end

@fn victim_assert_ge_violation()
  assert_ge(9, 10, "9 is not >= 10")
@end

@fn victim_assert_gt_equal_violation()
  assert_gt(10, 10, "10 is not > 10")
@end

@fn victim_assert_gt_less_violation()
  assert_gt(8, 10, "8 is not > 10")
@end

@fn victim_assert_le_violation()
  assert_le(11, 10, "11 is not <= 10")
@end

@fn victim_assert_lt_equal_violation()
  assert_lt(10, 10, "10 is not < 10")
@end

@fn victim_assert_lt_greater_violation()
  assert_lt(12, 10, "12 is not < 10")
@end

@fn victim_assert_str_contains_missing()
  assert_str_contains("maya sovereign test engine", "quantum", "Missing substring quantum")
@end

@fn victim_assert_str_contains_empty_haystack()
  assert_str_contains("", "non_empty_needle", "Empty haystack should fail")
@end

@fn victim_assert_true_violation()
  assert_true(0, "0 condition must fail assert_true")
@end

@fn victim_assert_false_violation()
  assert_false(1, "1 condition must fail assert_false")
@end

@fn victim_assert_eq_violation()
  assert_eq(42, 99, "42 != 99 must fail assert_eq")
@end

@fn victim_assert_ne_violation()
  assert_ne(100, 100, "100 == 100 must fail assert_ne")
@end

@! ----------------------------------------------------------------------------
@! 2. Happy Path Assertion Stress Battery
@! ----------------------------------------------------------------------------

@fn test_assert_near_exhaustive()
  @! Boundary: Exact equality with zero tolerance
  assert_near(0, 0, 0, "Zero with zero tol")
  assert_near(100, 100, 0, "100 with zero tol")
  assert_near(0 - 50, 0 - 50, 0, "-50 with zero tol")

  @! Boundary: Upper and lower exact tolerance limits
  assert_near(105, 100, 5, "Upper tolerance boundary (100 + 5)")
  assert_near(95, 100, 5, "Lower tolerance boundary (100 - 5)")

  @! Negative values and zero crossing
  assert_near(0 - 95, 0 - 100, 5, "Negative range upper boundary")
  assert_near(0 - 105, 0 - 100, 5, "Negative range lower boundary")
  assert_near(0 - 3, 3, 6, "Crossing zero symmetric (-3 to 3 within 6)")
  assert_near(3, 0 - 3, 6, "Crossing zero symmetric (3 to -3 within 6)")

  @! Large integer scale
  assert_near(1000000, 1000050, 100, "Large number within 100 tol")
  assert_near(1000050, 1000000, 100, "Large number reverse within 100 tol")
@end

@fn test_assert_str_eq_exhaustive()
  assert_str_eq("", "", "Empty string equality")
  assert_str_eq("a", "a", "Single char equality")
  assert_str_eq("Maya Sovereign Universe", "Maya Sovereign Universe", "Standard string")
  assert_str_eq("Line 1\nLine 2\nLine 3", "Line 1\nLine 2\nLine 3", "Multiline string equality")
  assert_str_eq("Special: <xml>&\"quotes\"'apos'\\slash", "Special: <xml>&\"quotes\"'apos'\\slash", "Special character string")
@end

@fn test_assert_errno_exhaustive()
  @! Linux standard errno codes:
  @! ENOENT = 2, EBADF = 9, EACCES = 13, EEXIST = 17, EINVAL = 22, ENOSPC = 28, EPIPE = 32
  assert_errno(0 - 2, 2, "ENOENT error code 2")
  assert_errno(0 - 9, 9, "EBADF error code 9")
  assert_errno(0 - 13, 13, "EACCES error code 13")
  assert_errno(0 - 17, 17, "EEXIST error code 17")
  assert_errno(0 - 22, 22, "EINVAL error code 22")
  assert_errno(0 - 28, 28, "ENOSPC error code 28")
  assert_errno(0 - 32, 32, "EPIPE error code 32")
@end

@fn test_assert_inequalities_exhaustive()
  @! assert_ge
  assert_ge(10, 10, "10 >= 10")
  assert_ge(11, 10, "11 >= 10")
  assert_ge(0, 0, "0 >= 0")
  assert_ge(0 - 5, 0 - 10, "-5 >= -10")
  assert_ge(0 - 10, 0 - 10, "-10 >= -10")

  @! assert_gt
  assert_gt(11, 10, "11 > 10")
  assert_gt(1, 0, "1 > 0")
  assert_gt(0, 0 - 1, "0 > -1")
  assert_gt(0 - 5, 0 - 10, "-5 > -10")

  @! assert_le
  assert_le(10, 10, "10 <= 10")
  assert_le(9, 10, "9 <= 10")
  assert_le(0, 0, "0 <= 0")
  assert_le(0 - 10, 0 - 5, "-10 <= -5")
  assert_le(0 - 10, 0 - 10, "-10 <= -10")

  @! assert_lt
  assert_lt(9, 10, "9 < 10")
  assert_lt(0 - 1, 0, "-1 < 0")
  assert_lt(0 - 10, 0 - 5, "-10 < -5")
@end

@fn test_assert_str_contains_exhaustive()
  haystack = "The Sovereign Maya Test Oracle Engine (Process Isolated)"
  assert_str_contains(haystack, "The", "Prefix substring match")
  assert_str_contains(haystack, "Sovereign", "Middle word match")
  assert_str_contains(haystack, "Oracle", "Middle word match 2")
  assert_str_contains(haystack, "Isolated)", "Suffix substring match")
  assert_str_contains(haystack, haystack, "Exact full string match")
  assert_str_contains(haystack, "", "Empty needle match")
  assert_str_contains("a", "a", "Single char match")
@end

@fn test_assert_primitives_stress()
  i = 0
  @while i < 1000
    assert_true(i >= 0, "Counter non-negative")
    assert_false(i < 0, "Counter not negative")
    assert_eq(i + 10, 10 + i, "Commutative addition")
    assert_ne(i, i + 1, "Counter inequality")
    i = i + 1
  @end
@end

@! ----------------------------------------------------------------------------
@! 3. Report Escaping Unit Tests
@! ----------------------------------------------------------------------------

@fn test_xml_escaping_isolated()
  raw_amp = "&"
  raw_lt = "<"
  raw_gt = ">"
  raw_quot = "\""
  raw_apos = "'"
  raw_combined = "<script src=\"test.js?a=1&b=2\">alert('XSS > \"safe\"')</script>"

  assert_str_eq(xml_escape(raw_amp), "&amp;", "Escape ampersand")
  assert_str_eq(xml_escape(raw_lt), "&lt;", "Escape less-than")
  assert_str_eq(xml_escape(raw_gt), "&gt;", "Escape greater-than")
  assert_str_eq(xml_escape(raw_quot), "&quot;", "Escape double quote")
  assert_str_eq(xml_escape(raw_apos), "&apos;", "Escape single quote")
  assert_str_eq(xml_escape(""), "", "Empty string XML escape")

  escaped = xml_escape(raw_combined)
  assert_str_eq(escaped, "&lt;script src=&quot;test.js?a=1&amp;b=2&quot;&gt;alert(&apos;XSS &gt; &quot;safe&quot;&apos;)&lt;/script&gt;", "Combined XML escape")
@end

@fn test_json_escaping_isolated()
  raw_bs = "\\"
  raw_quote = "\""
  raw_nl = "\n"
  raw_cr = "\r"
  raw_tab = "\t"
  raw_complex = "Path: C:\\Users\\Maya\t\"quoted_val\"\r\nNewline & <tag>"

  assert_str_eq(json_escape(raw_bs), "\\\\", "Escape backslash")
  assert_str_eq(json_escape(raw_quote), "\\\"", "Escape quote")
  assert_str_eq(json_escape(raw_nl), "\\n", "Escape newline")
  assert_str_eq(json_escape(raw_cr), "\\r", "Escape carriage return")
  assert_str_eq(json_escape(raw_tab), "\\t", "Escape tab")
  assert_str_eq(json_escape(""), "", "Empty string JSON escape")

  escaped_json = json_escape(raw_complex)
  expected_json = "Path: C:\\\\Users\\\\Maya\\t\\\"quoted_val\\\"\\r\\nNewline & <tag>"
  assert_str_eq(escaped_json, expected_json, "Complex JSON escape")
@end

@fn test_junit_xml_report_generation()
  results = [
    {
      name: "test_pass_normal",
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
      name: "test_fail_assertion_<bad>",
      tier: 2,
      category: "boundary",
      passed: 0,
      skipped: 0,
      duration_ms: 25,
      exit_code: 1,
      signal_num: 0,
      signal_name: "",
      error_msg: "Assertion Failed: expected 10 & got <20>"
    },
    {
      name: "test_crash_sigsegv",
      tier: 3,
      category: "crash",
      passed: 0,
      skipped: 0,
      duration_ms: 5,
      exit_code: 139,
      signal_num: 11,
      signal_name: "SIGSEGV",
      error_msg: "Terminated by signal 11 (SIGSEGV)"
    },
    {
      name: "test_skipped_module",
      tier: 4,
      category: "app",
      passed: 0,
      skipped: 1,
      duration_ms: 0,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: "Skipped: feature not available"
    }
  ]

  xml_out = "build/reports/adv_c2_test_results.xml"
  xml_content = generate_junit_xml("Adversarial_Suite_<XML>&\"Test\"", results, xml_out)

  @! Verify XML structure contains required tags and proper escaping
  assert_str_contains(xml_content, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "XML header")
  assert_str_contains(xml_content, "<testsuite name=\"Adversarial_Suite_&lt;XML&gt;&amp;&quot;Test&quot;\"", "Escaped suite name")
  assert_str_contains(xml_content, "tests=\"4\" failures=\"2\" errors=\"1\" skipped=\"1\"", "Suite counts")
  assert_str_contains(xml_content, "name=\"test_pass_normal\"", "Pass testcase")
  assert_str_contains(xml_content, "name=\"test_fail_assertion_&lt;bad&gt;\"", "Escaped failure testcase name")
  assert_str_contains(xml_content, "<failure message=\"Assertion Failed: expected 10 &amp; got &lt;20&gt;\"", "Escaped failure message")
  assert_str_contains(xml_content, "<error message=\"Terminated by signal 11 (SIGSEGV)\" type=\"SignalCrash\">", "Crash error tag")
  assert_str_contains(xml_content, "<skipped message=\"Skipped: feature not available\" />", "Skipped tag")
  assert_str_contains(xml_content, "</testsuite>", "Closing testsuite tag")
  assert_str_contains(xml_content, "</testsuites>", "Closing testsuites tag")
@end

@fn test_json_report_generation()
  results = [
    {
      name: "test_json_pass",
      tier: 1,
      category: "os",
      passed: 1,
      skipped: 0,
      duration_ms: 10,
      exit_code: 0,
      signal_num: 0,
      signal_name: "",
      error_msg: ""
    },
    {
      name: "test_json_fail_\"quotes\"_\n_newline",
      tier: 2,
      category: "web",
      passed: 0,
      skipped: 0,
      duration_ms: 20,
      exit_code: 1,
      signal_num: 0,
      signal_name: "",
      error_msg: "Failed with \\ backslash and \" quotes \" \n newlines"
    }
  ]

  json_out = "build/reports/adv_c2_test_results.json"
  json_content = generate_json_report("Adversarial_JSON_\"Suite\"", results, json_out)

  assert_str_contains(json_content, "\"suite\": \"Adversarial_JSON_\\\"Suite\\\"\"", "Escaped JSON suite name")
  assert_str_contains(json_content, "\"total\": 2", "Total count")
  assert_str_contains(json_content, "\"passed\": 1", "Passed count")
  assert_str_contains(json_content, "\"failed\": 1", "Failed count")
  assert_str_contains(json_content, "\"status\": \"CHAOS DETECTED\"", "Chaos status on failure")
  assert_str_contains(json_content, "\"name\": \"test_json_pass\"", "Passed item name")
  assert_str_contains(json_content, "\"passed\": true", "Passed boolean true")
  assert_str_contains(json_content, "\"passed\": false", "Passed boolean false")
  assert_str_contains(json_content, "\"name\": \"test_json_fail_\\\"quotes\\\"_\\n_newline\"", "Escaped failed item name")
  assert_str_contains(json_content, "\"error_msg\": \"Failed with \\\\ backslash and \\\" quotes \\\" \\n newlines\"", "Escaped error message")
@end

@! ----------------------------------------------------------------------------
@! 4. Master Adversarial Orchestrator
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("▶ [ADVERSARIAL CHALLENGER 2] Maya Test Oracle Deep Stress Suite")
  println("=================================================================")

  total_challenges = 0
  passed_challenges = 0

  @! --- Category A: Happy Path Assertion Suites (Isolated) ---
  happy_tests = [
    ["assert_near_exhaustive", test_assert_near_exhaustive],
    ["assert_str_eq_exhaustive", test_assert_str_eq_exhaustive],
    ["assert_errno_exhaustive", test_assert_errno_exhaustive],
    ["assert_inequalities_exhaustive", test_assert_inequalities_exhaustive],
    ["assert_str_contains_exhaustive", test_assert_str_contains_exhaustive],
    ["assert_primitives_stress_1000", test_assert_primitives_stress],
    ["xml_escaping_isolated", test_xml_escaping_isolated],
    ["json_escaping_isolated", test_json_escaping_isolated],
    ["junit_xml_report_generation", test_junit_xml_report_generation],
    ["json_report_generation", test_json_report_generation]
  ]

  i = 0
  @while i < happy_tests.len()
    item = happy_tests[i]
    tname = item[0]
    tfn = item[1]
    total_challenges = total_challenges + 1

    res = run_isolated_test(tname, tfn)
    @if res.passed == 1
      passed_challenges = passed_challenges + 1
      println("  [CHALLENGE PASS] " + tname)
    @else
      println("  [CHALLENGE FAIL] " + tname + " (Exit code: " + res.exit_code.to_str() + ")")
    @end
    i = i + 1
  @end

  @! --- Category B: Negative Assertion Tests (Must Panic & Contain Cleanly) ---
  negative_tests = [
    ["neg_assert_near_upper", victim_assert_near_upper_violation],
    ["neg_assert_near_lower", victim_assert_near_lower_violation],
    ["neg_assert_near_zero_tol", victim_assert_near_zero_tol_violation],
    ["neg_assert_str_eq_mismatch", victim_assert_str_eq_mismatch],
    ["neg_assert_str_eq_case", victim_assert_str_eq_case_mismatch],
    ["neg_assert_errno_success", victim_assert_errno_success_violation],
    ["neg_assert_errno_wrong", victim_assert_errno_wrong_errno_violation],
    ["neg_assert_ge_violation", victim_assert_ge_violation],
    ["neg_assert_gt_equal_violation", victim_assert_gt_equal_violation],
    ["neg_assert_gt_less_violation", victim_assert_gt_less_violation],
    ["neg_assert_le_violation", victim_assert_le_violation],
    ["neg_assert_lt_equal_violation", victim_assert_lt_equal_violation],
    ["neg_assert_lt_greater_violation", victim_assert_lt_greater_violation],
    ["neg_assert_str_contains_missing", victim_assert_str_contains_missing],
    ["neg_assert_str_contains_empty", victim_assert_str_contains_empty_haystack],
    ["neg_assert_true_violation", victim_assert_true_violation],
    ["neg_assert_false_violation", victim_assert_false_violation],
    ["neg_assert_eq_violation", victim_assert_eq_violation],
    ["neg_assert_ne_violation", victim_assert_ne_violation]
  ]

  j = 0
  @while j < negative_tests.len()
    item = negative_tests[j]
    tname = item[0]
    tfn = item[1]
    total_challenges = total_challenges + 1

    res = run_isolated_test(tname, tfn)
    @! Negative test EXPECTS child process to fail/panic with exit code != 0
    @if res.passed == 0 && res.exit_code != 0
      passed_challenges = passed_challenges + 1
      println("  [CHALLENGE PASS] " + tname + " (Properly panicked in sandbox, exit code " + res.exit_code.to_str() + ")")
    @else
      println("  [CHALLENGE FAIL] " + tname + " (Expected panic but process did not report error)")
    @end
    j = j + 1
  @end

  println("=================================================================")
  println("Adversarial Challenger 2 Summary: " + passed_challenges.to_str() + " / " + total_challenges.to_str() + " challenges passed")
  println("=================================================================")

  @if passed_challenges == total_challenges
    println("Verdict: APPROVE — Assertion engine and XML/JSON formatters are fully resilient")
    return 0
  @else
    println("Verdict: REQUEST_CHANGES — Failure detected in assertion/reporting engine")
    return 1
  @end
@end
