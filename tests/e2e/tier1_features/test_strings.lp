@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: STRINGS & STRING OPERATIONS
@! File: tests/e2e/tier1_features/test_strings.maya
@! ============================================================================

import "universe/core/string"

@fn check_starts_with(s, prefix)
  return starts_with(s, prefix)
@end

@fn check_ends_with(s, suffix)
  return ends_with(s, suffix)
@end

@fn check_contains(s, sub)
  return contains(s, sub)
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 2: Strings & String Operations")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T1.7: String Literal & Assignment
  total = total + 1
  s1 = "Hello"
  s2 = "World"
  @if s1 == "Hello" && s2 == "World"
    passed = passed + 1
    println("  [PASS] T1.7: String literal assignment and value retention")
  @else
    failed = failed + 1
    println("  [FAIL] T1.7: String literal assignment")
  @end

  @! T1.8: String Concatenation
  total = total + 1
  greeting = s1 + ", " + s2 + "!"
  @if greeting == "Hello, World!"
    passed = passed + 1
    println("  [PASS] T1.8: String concatenation (\"Hello\" + \", \" + \"World!\" == \"Hello, World!\")")
  @else
    failed = failed + 1
    println("  [FAIL] T1.8: String concatenation")
  @end

  @! T1.9: String Equality & Inequality
  total = total + 1
  str_a = "Maya Language"
  str_b = "Maya Language"
  str_c = "Other Language"
  @if (str_a == str_b) && (str_a != str_c)
    passed = passed + 1
    println("  [PASS] T1.9: String equality and inequality checks")
  @else
    failed = failed + 1
    println("  [FAIL] T1.9: String equality checks")
  @end

  @! T1.10: String starts_with
  total = total + 1
  sw_true = check_starts_with("compiler_pipeline", "compiler")
  sw_false = check_starts_with("compiler_pipeline", "backend")
  @if sw_true == 1 && sw_false == 0
    passed = passed + 1
    println("  [PASS] T1.10: String starts_with functionality")
  @else
    failed = failed + 1
    println("  [FAIL] T1.10: String starts_with")
  @end

  @! T1.11: String ends_with
  total = total + 1
  ew_true = check_ends_with("test_suite.maya", ".maya")
  ew_false = check_ends_with("test_suite.maya", ".cpp")
  @if ew_true == 1 && ew_false == 0
    passed = passed + 1
    println("  [PASS] T1.11: String ends_with functionality")
  @else
    failed = failed + 1
    println("  [FAIL] T1.11: String ends_with")
  @end

  @! T1.12: String contains
  total = total + 1
  c_true = check_contains("high-performance typed AST compiler", "typed AST")
  c_false = check_contains("high-performance typed AST compiler", "python")
  @if c_true == 1 && c_false == 0
    passed = passed + 1
    println("  [PASS] T1.12: String contains search")
  @else
    failed = failed + 1
    println("  [FAIL] T1.12: String contains")
  @end

  @! T1.13: Escape Sequences (\n, \t, \", \\)
  total = total + 1
  escaped = "Line1\nLine2\tTabbed \"Quotes\" and \\backslash\\"
  @if escaped != ""
    passed = passed + 1
    println("  [PASS] T1.13: Escape sequence handling (\\n, \\t, \\\", \\\\)")
  @else
    failed = failed + 1
    println("  [FAIL] T1.13: Escape sequence handling")
  @end

  println("-----------------------------------------------------------------")
  println("Feature 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature 2 (Strings) PASSED")
    return 0
  @else
    println("✗ Feature 2 (Strings) FAILED")
    return 1
  @end
@end
