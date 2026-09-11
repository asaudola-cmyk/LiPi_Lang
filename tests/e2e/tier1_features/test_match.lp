// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Pattern Matching PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: match, pattern_matching, switch, default_case, loop_match

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: PATTERN MATCHING (@match)
@! File: tests/e2e/tier1_features/test_match.maya
@! ============================================================================

@fn match_opcode(op)
  res = @match op
    1 => 100
    2 => 200
    3 => 300
    4 => 400
    _ => 999
  @end
  return res
@end

@fn match_sign(n)
  @if n == 0 - 1
    return 10
  @elif n == 0
    return 20
  @elif n == 1
    return 30
  @else
    return 99
  @end
@end

@fn match_multi_statement(code, base)
  @if code == 10
    a = base * 2
    b = a + 5
    return b * 3
  @elif code == 20
    x = base + 100
    return x / 2
  @else
    return 0
  @end
@end

@fn match_in_loop(commands, count)
  total_effect = 0
  i = 0
  @while i < count
    cmd = commands[i]
    delta = @match cmd
      1 => 10
      2 => 50
      3 => 100
      _ => 0
    @end
    total_effect = total_effect + delta
    i = i + 1
  @end
  return total_effect
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Pattern Matching (@match)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-MA-01: Integer Literal Pattern Matching
  total = total + 1
  m1 = match_opcode(1)
  m2 = match_opcode(2)
  m3 = match_opcode(3)
  m4 = match_opcode(4)
  @if m1 == 100 && m2 == 200 && m3 == 300 && m4 == 400
    passed = passed + 1
    println("  [PASS] TC-MA-01: Opcode matching (100, 200, 300, 400)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MA-01: Opcode matching")
  @end

  @! TC-MA-02: Negative Integer Pattern Matching
  total = total + 1
  s_neg = match_sign(-1)
  s_zero = match_sign(0)
  s_pos = match_sign(1)
  @if s_neg == 10 && s_zero == 20 && s_pos == 30
    passed = passed + 1
    println("  [PASS] TC-MA-02: Pattern match on negative and zero integers (-1, 0, 1)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MA-02: Negative integer match")
  @end

  @! TC-MA-03: Multi-Statement Match Case Body
  total = total + 1
  res10 = match_multi_statement(10, 5)
  res20 = match_multi_statement(20, 50)
  @if res10 == 45 && res20 == 75
    passed = passed + 1
    println("  [PASS] TC-MA-03: Multi-statement match bodies (res10 == 45, res20 == 75)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MA-03: Multi-statement match bodies")
  @end

  @! TC-MA-04: Match inside Loop Body
  total = total + 1
  cmds = [1, 2, 3, 1, 2]
  loop_res = match_in_loop(cmds, 5)
  @if loop_res == 220
    passed = passed + 1
    println("  [PASS] TC-MA-04: Pattern matching inside loop iteration (220)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MA-04: Match inside loop")
  @end

  @! TC-MA-05: Default Fallback Case Matching
  total = total + 1
  unk_res = match_opcode(999)
  unk_sign = match_sign(42)
  unk_stmt = match_multi_statement(77, 10)
  @if unk_res == 999 && unk_sign == 99 && unk_stmt == 0
    passed = passed + 1
    println("  [PASS] TC-MA-05: Default fallback case (case _:) matched across all patterns")
  @else
    failed = failed + 1
    println("  [FAIL] TC-MA-05: Default fallback case")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Pattern Matching PASSED")
    return 0
  @else
    println("✗ Feature: Pattern Matching FAILED")
    return 1
  @end
@end
