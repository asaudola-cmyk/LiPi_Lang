// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: String Interpolation & String Primitives PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: strings, interpolation, concat, substr, trim, case_transform

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: STRING INTERPOLATION & UTILITIES
@! File: tests/e2e/tier1_features/test_strings_interp.maya
@! ============================================================================

@struct User
  name: string
  age: i64
@end

@fn format_greeting(name: string)
  return "Welcome to {name}!"
@end

@fn format_point(x: i64, y: i64)
  return "Point({x}, {y})"
@end

@fn format_user_card(u: User)
  return "User: {u.name} (age {u.age})"
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: String Interpolation & Primitives")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-STR-01: Simple Variable String Interpolation
  total = total + 1
  greet = format_greeting("Maya Universe")
  @if greet == "Welcome to Maya Universe!"
    passed = passed + 1
    println("  [PASS] TC-STR-01: Simple interpolation (\"Welcome to {name}!\")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-01: Simple interpolation")
  @end

  @! TC-STR-02: Multi-Variable Interpolation
  total = total + 1
  pt_str = format_point(10, 20)
  @if pt_str == "Point(10, 20)"
    passed = passed + 1
    println("  [PASS] TC-STR-02: Multi-variable interpolation (\"Point({x}, {y})\")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-02: Multi-variable interpolation")
  @end

  @! TC-STR-03: Dotted Field Interpolation
  total = total + 1
  u = { name: "Alice", age: 30 }
  u_card = format_user_card(u)
  @if u_card == "User: Alice (age 30)"
    passed = passed + 1
    println("  [PASS] TC-STR-03: Dotted struct field interpolation (\"User: {u.name} (age {u.age})\")")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-03: Dotted field interpolation")
  @end

  @! TC-STR-04: String Concatenation & Length
  total = total + 1
  s1 = "Hello, "
  s2 = "Maya!"
  s_all = s1 + s2
  len = str_len(s_all)
  @if s_all == "Hello, Maya!" && len == 12
    passed = passed + 1
    println("  [PASS] TC-STR-04: String concatenation and length calculation (len == 12)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-04: String concatenation and length")
  @end

  @! TC-STR-05: Substring & Character Code Introspection
  total = total + 1
  sub = str_substr("Hello World", 0, 5)
  ch_code = str_char_at("ABC", 0)
  from_c = str_from_char_code(65)
  @if sub == "Hello" && ch_code == 65 && from_c == "A"
    passed = passed + 1
    println("  [PASS] TC-STR-05: str_substr, str_char_at, and str_from_char_code")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-05: Substring and char code")
  @end

  @! TC-STR-06: Case Transformations, Trimming & Replacement
  total = total + 1
  upper = str_to_upper("maya")
  lower = str_to_lower("UNIVERSE")
  trimmed = str_trim("   clean   ")
  replaced = str_replace("foo-bar-foo", "foo", "baz")
  @if upper == "MAYA" && lower == "universe" && trimmed == "clean" && replaced == "baz-bar-baz"
    passed = passed + 1
    println("  [PASS] TC-STR-06: str_to_upper, str_to_lower, str_trim, and str_replace")
  @else
    failed = failed + 1
    println("  [FAIL] TC-STR-06: Case transformations and trim")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: String Interpolation & String Primitives PASSED")
    return 0
  @else
    println("✗ Feature: String Interpolation & String Primitives FAILED")
    return 1
  @end
@end
