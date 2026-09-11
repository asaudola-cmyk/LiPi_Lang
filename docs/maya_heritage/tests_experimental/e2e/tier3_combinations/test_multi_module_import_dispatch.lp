@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: MULTI-MODULE IMPORT & CROSS-MODULE DISPATCH
@! File: tests/e2e/tier3_combinations/test_multi_module_import_dispatch.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/core/string"
import "universe/core/math"
import "universe/core/collections"

@struct UserProfile
  username: ""
  raw_score: 0
  normalized_score: 0
  category: ""
@end

@fn process_user(raw_name, score)
  clean_name = string_trim(raw_name)
  upper_name = string_upper(clean_name)
  clamped_score = clamp(score, 0, 100)
  gcd_val = gcd(clamped_score, 100)

  cat = "STANDARD"
  @if string_starts_with(upper_name, "ADMIN_") == 1
    cat = "PRIVILEGED"
  @elif clamped_score >= 90
    cat = "HONORS"
  @end

  return {
    username: upper_name,
    raw_score: score,
    normalized_score: clamped_score,
    category: cat
  }
@end

@fn profile_to_score(p)
  return p.normalized_score
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 7: Multi-Module Import & Dispatch")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.7.1: Math Library Dispatch (gcd, clamp, pow_int, factorial)
  total = total + 1
  m_gcd = gcd(144, 60)         @! 12
  m_clamp = clamp(150, 0, 100)  @! 100
  m_pow = pow_int(2, 8)         @! 256
  m_fact = factorial(5)         @! 120

  @if m_gcd == 12 && m_clamp == 100 && m_pow == 256 && m_fact == 120
    passed = passed + 1
    println("  [PASS] T3.7.1: Math module cross-import dispatch (gcd=12, clamp=100, pow=256, fact=120)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7.1: Math module dispatch failed")
  @end

  @! T3.7.2: String Library Dispatch (string_trim, string_upper, string_starts_with, string_replace)
  total = total + 1
  s_raw = "   admin_super_user   "
  s_trimmed = string_trim(s_raw)
  s_upper = string_upper(s_trimmed)
  s_starts = string_starts_with(s_upper, "ADMIN_")
  s_rep = string_replace(s_upper, "SUPER", "ROOT")

  @if s_trimmed == "admin_super_user" && s_upper == "ADMIN_SUPER_USER" && s_starts == 1 && s_rep == "ADMIN_ROOT_USER"
    passed = passed + 1
    println("  [PASS] T3.7.2: String module cross-import dispatch (trim, upper, starts_with, replace)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7.2: String module dispatch failed")
  @end

  @! T3.7.3: Collections Library Dispatch (list_map, list_filter, list_reduce)
  total = total + 1
  raw_users = [
    process_user("  admin_alice  ", 120),
    process_user("bob_regular", 85),
    process_user("  charlie_honor", 95),
    process_user("david_zero", -10)
  ]

  scores = list_map(raw_users, profile_to_score)
  @! Clamped: [100, 85, 95, 0]
  @! Sum: 100 + 85 + 95 + 0 = 280
  score_sum = list_reduce(scores, sum_reducer, 0)

  @if scores.len() == 4 && scores[0] == 100 && scores[3] == 0 && score_sum == 280
    passed = passed + 1
    println("  [PASS] T3.7.3: Collections combinators over imported struct records (score_sum == 280)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7.3: Collections over structs failed")
  @end

  @! T3.7.4: Multi-Module Compound Integration
  total = total + 1
  u0 = raw_users[0]
  u1 = raw_users[1]
  u2 = raw_users[2]
  @if u0.category == "PRIVILEGED" && u1.category == "STANDARD" && u2.category == "HONORS"
    passed = passed + 1
    println("  [PASS] T3.7.4: Cross-module validation of classified user profiles")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7.4: User profile classification mismatch")
  @end

  @! T3.7.5: Reversing Array from Collections Module
  total = total + 1
  rev_scores = list_reverse(scores)
  @if rev_scores[0] == 0 && rev_scores[3] == 100
    passed = passed + 1
    println("  [PASS] T3.7.5: list_reverse from collections module correctly inverts array")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7.5: list_reverse failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 7 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 7 (Multi-Module Import & Dispatch) PASSED")
    return 0
  @else
    println("✗ Combination 7 (Multi-Module Import & Dispatch) FAILED")
    return 1
  @end
@end

@fn sum_reducer(acc, x)
  return acc + x
@end
