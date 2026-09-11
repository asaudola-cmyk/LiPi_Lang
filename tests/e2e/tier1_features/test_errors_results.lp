// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Errors & Result Types PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: errors, results, errno, options, error_propagation

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: ERRORS, RESULTS & OPTIONS
@! File: tests/e2e/tier1_features/test_errors_results.maya
@! ============================================================================

import "runtime/maya_syscall"

@struct Result
  is_ok: i64
  value: i64
  err_msg: string
@end

@struct Option
  has_value: i64
  value: i64
@end

@fn ok_res(val)
  return { is_ok: 1, value: val, err_msg: "" }
@end

@fn err_res(msg: string)
  return { is_ok: 0, value: 0, err_msg: msg }
@end

@fn safe_divide(a, b)
  @if b == 0
    return err_res("ERR_DIV_BY_ZERO")
  @end
  return ok_res(a / b)
@end

@fn step1(x)
  @if x < 0
    return err_res("ERR_NEGATIVE_INPUT")
  @end
  return ok_res(x + 10)
@end

@fn step2(x)
  r1 = step1(x)
  @if r1.is_ok == 0
    return r1
  @end
  return ok_res(r1.value * 2)
@end

@fn step3(x)
  r2 = step2(x)
  @if r2.is_ok == 0
    return r2
  @end
  return ok_res(r2.value + 5)
@end

@fn find_in_array(arr, length, target)
  i = 0
  @while i < length
    @if arr[i] == target
      return { has_value: 1, value: i }
    @end
    i = i + 1
  @end
  return { has_value: 0, value: 0 }
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Errors, Result Types & Errno Handling")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-ERR-01: Syscall Errno Detection (is_error, is_ok, get_errno)
  total = total + 1
  res_err = 0 - 2  @! -ENOENT
  res_ok = 100
  err_detected = is_error(res_err)
  ok_detected = is_ok(res_ok)
  errno_val = get_errno(res_err)
  @if err_detected == 1 && ok_detected == 1 && errno_val == 2
    passed = passed + 1
    println("  [PASS] TC-ERR-01: is_error, is_ok, get_errno translation (-2 -> ENOENT 2)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ERR-01: Errno detection")
  @end

  @! TC-ERR-02: Errno Name & Strerror Translation
  total = total + 1
  name_enoent = errno_name(2)
  name_ebadf = errno_name(9)
  msg_enoent = errno_strerror(2)
  @if name_enoent == "ENOENT" && name_ebadf == "EBADF" && msg_enoent == "No such file or directory"
    passed = passed + 1
    println("  [PASS] TC-ERR-02: errno_name (\"ENOENT\", \"EBADF\") and errno_strerror")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ERR-02: Errno name translation")
  @end

  @! TC-ERR-03: Result Struct Pattern (safe_divide)
  total = total + 1
  div_success = safe_divide(100, 4)
  div_failure = safe_divide(100, 0)
  @if div_success.is_ok == 1 && div_success.value == 25 && div_failure.is_ok == 0 && div_failure.err_msg == "ERR_DIV_BY_ZERO"
    passed = passed + 1
    println("  [PASS] TC-ERR-03: Result struct pattern (safe_divide success & div-by-zero err)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ERR-03: Result struct pattern")
  @end

  @! TC-ERR-04: Error Propagation Chain (step1 -> step2 -> step3)
  total = total + 1
  @! step3(5): 5+10=15 -> 15*2=30 -> 30+5=35
  chain_ok = step3(5)
  @! step3(-5): step1 fails with ERR_NEGATIVE_INPUT, propagated through step2 and step3
  chain_err = step3(-5)
  @if chain_ok.is_ok == 1 && chain_ok.value == 35 && chain_err.is_ok == 0 && chain_err.err_msg == "ERR_NEGATIVE_INPUT"
    passed = passed + 1
    println("  [PASS] TC-ERR-04: Error propagation chain across 3 function levels")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ERR-04: Error propagation chain")
  @end

  @! TC-ERR-05: Option Pattern (find_in_array)
  total = total + 1
  items = [10, 20, 30, 40, 50]
  opt_found = find_in_array(items, 5, 30)
  opt_missing = find_in_array(items, 5, 999)
  @if opt_found.has_value == 1 && opt_found.value == 2 && opt_missing.has_value == 0
    passed = passed + 1
    println("  [PASS] TC-ERR-05: Option struct pattern (index 2 found vs missing)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-ERR-05: Option struct pattern")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Errors & Result Types PASSED")
    return 0
  @else
    println("✗ Feature: Errors & Result Types FAILED")
    return 1
  @end
@end
