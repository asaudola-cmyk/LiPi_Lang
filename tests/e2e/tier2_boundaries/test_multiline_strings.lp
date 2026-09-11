// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Multi-Line Strings & Escapes PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, multiline_strings, escapes, json_literal, formatting, quotes

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: MULTI-LINE STRINGS & ESCAPES
@! File: tests/e2e/tier2_boundaries/test_multiline_strings.maya
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Multi-Line Strings & Escape Sequences")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-MLS-01: Multi-Line String Literal
  total = total + 1
  multiline = "Line 1
Line 2
Line 3"
  len_ml = str_len(multiline)
  @if len_ml == 20
    passed = passed + 1
    println("  [PASS] BC-MLS-01: Multi-line string contains embedded newlines (len == 20)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-01: Multi-line string")
  @end

  @! BC-MLS-02: Standard Escape Characters (\n, \t, \r, \", \\)
  total = total + 1
  escapes = "Hello\tWorld\nTab\\Slash\"Quote\""
  len_esc = str_len(escapes)
  @if len_esc == 28
    passed = passed + 1
    println("  [PASS] BC-MLS-02: Escape sequences parsed correctly (len == 28)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-02: Escape sequences")
  @end

  @! BC-MLS-03: Hex Escape Characters (\x41, \x42, \x43)
  total = total + 1
  hex_str = "\x41\x42\x43"
  @if hex_str == "ABC" && str_len(hex_str) == 3
    passed = passed + 1
    println("  [PASS] BC-MLS-03: Hex escape sequences (\\x41\\x42\\x43 == \"ABC\")")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-03: Hex escape sequences")
  @end

  @! BC-MLS-04: Non-Interpolating Literal Braces (JSON payload)
  total = total + 1
  json_payload = "{\"key\": 100, \"valid\": true}"
  contains_key = str_contains(json_payload, "\"key\": 100")
  @if contains_key == 1 && str_len(json_payload) == 27
    passed = passed + 1
    println("  [PASS] BC-MLS-04: JSON string literal with braces preserved without false interpolation")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-04: JSON literal braces")
  @end

  @! BC-MLS-05: Multi-line Concatenation & Substring Slicing
  total = total + 1
  part1 = "SELECT id, name\n"
  part2 = "FROM users\n"
  part3 = "WHERE active = 1"
  query = part1 + part2 + part3
  starts_sel = str_starts_with(query, "SELECT")
  ends_act = str_ends_with(query, "active = 1")
  @if starts_sel == 1 && ends_act == 1
    passed = passed + 1
    println("  [PASS] BC-MLS-05: Multi-line SQL string concatenation and prefix/suffix validation")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-05: Multi-line SQL concatenation")
  @end

  @! BC-MLS-06: Escaped Quotes in Multi-Line Text
  total = total + 1
  quote_text = "He said:\n\"Maya is sovereign!\"\nAnd smiled."
  has_sovereign = str_contains(quote_text, "\"Maya is sovereign!\"")
  @if has_sovereign == 1
    passed = passed + 1
    println("  [PASS] BC-MLS-06: Escaped quotes inside multi-line text blocks")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-06: Escaped quotes in multi-line text")
  @end

  @! BC-MLS-07: Multi-Line Trimming
  total = total + 1
  padded_block = "   \n\n  Block Content  \n\n   "
  trimmed_block = str_trim(padded_block)
  @if trimmed_block == "Block Content"
    passed = passed + 1
    println("  [PASS] BC-MLS-07: Trimming multi-line string containing leading/trailing newlines and spaces")
  @else
    failed = failed + 1
    println("  [FAIL] BC-MLS-07: Multi-line trim")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Multi-Line Strings & Escapes PASSED")
    return 0
  @else
    println("✗ Boundary: Multi-Line Strings & Escapes FAILED")
    return 1
  @end
@end
