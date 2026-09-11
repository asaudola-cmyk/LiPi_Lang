// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Empty Strings PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, empty_strings, strings, zero_length, trim, substr, comparison

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: EMPTY STRINGS
@! File: tests/e2e/tier2_boundaries/test_empty_strings.maya
@! ============================================================================

@fn concat_with_empty(s)
  empty = ""
  return empty + s + empty
@end

@fn format_with_empty(empty_val: string)
  return "prefix_{empty_val}_suffix"
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Empty Strings & Zero-Length Edge Cases")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-STR-01: Zero-Length String Literal & str_len
  total = total + 1
  empty_str = ""
  len0 = str_len(empty_str)
  @if empty_str == "" && len0 == 0
    passed = passed + 1
    println("  [PASS] BC-STR-01: Empty string literal \"\" has length 0")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-01: Empty string length")
  @end

  @! BC-STR-02: Concatenation with Empty Strings
  total = total + 1
  c_res = concat_with_empty("core_data")
  @if c_res == "core_data"
    passed = passed + 1
    println("  [PASS] BC-STR-02: Concatenation with empty string retains identity (\"\" + \"core_data\" + \"\")")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-02: Empty string concatenation")
  @end

  @! BC-STR-03: Interpolation with Empty String Variable
  total = total + 1
  empty_var = ""
  interp_res = format_with_empty(empty_var)
  @if interp_res == "prefix__suffix"
    passed = passed + 1
    println("  [PASS] BC-STR-03: String interpolation with empty variable (\"prefix__suffix\")")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-03: Empty string interpolation")
  @end

  @! BC-STR-04: Trimming Empty and Whitespace Strings
  total = total + 1
  trim_empty = str_trim("")
  trim_spaces = str_trim("     ")
  @if trim_empty == "" && trim_spaces == ""
    passed = passed + 1
    println("  [PASS] BC-STR-04: str_trim on empty string and whitespace-only string produces \"\"")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-04: Trimming empty string")
  @end

  @! BC-STR-05: Substring on Empty String and 0-Length Slice
  total = total + 1
  sub_empty = str_substr("", 0, 0)
  sub_zero_len = str_substr("MayaUniverse", 4, 4)
  @if sub_empty == "" && sub_zero_len == ""
    passed = passed + 1
    println("  [PASS] BC-STR-05: str_substr on empty string and 0-length slice yields \"\"")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-05: Substring on empty string")
  @end

  @! BC-STR-06: String Starts With & Ends With Empty Prefix/Suffix
  total = total + 1
  sw = str_starts_with("Maya", "")
  ew = str_ends_with("Maya", "")
  @if sw == 1 && ew == 1
    passed = passed + 1
    println("  [PASS] BC-STR-06: str_starts_with and str_ends_with on empty substring evaluate to true")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-06: Starts/Ends with empty string")
  @end

  @! BC-STR-07: String Equality and Inequality against Empty String
  total = total + 1
  s_non_empty = "non_empty"
  @if (empty_str == "") && (s_non_empty != "") && !(empty_str != "")
    passed = passed + 1
    println("  [PASS] BC-STR-07: Boolean equality & inequality operators against empty string")
  @else
    failed = failed + 1
    println("  [FAIL] BC-STR-07: Empty string equality")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Empty Strings PASSED")
    return 0
  @else
    println("✗ Boundary: Empty Strings FAILED")
    return 1
  @end
@end
