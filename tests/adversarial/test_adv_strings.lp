@! ============================================================================
@! ADVERSARIAL STRESS TEST: STRING BOUNDARIES & DYNAMICS (test_adv_strings.maya)
@! Tests:
@! 1. Empty string boundaries (equality, concatenation, starts/ends/contains)
@! 2. Multiline strings and escape sequences (\n, \t, \", \\)
@! 3. Large string concatenation chains and dynamic loop construction
@! 4. Dynamic string equality and inequality
@! 5. String manipulation utilities and methods
@! ============================================================================

@fn build_dynamic_string(prefix, count)
  let res = prefix
  let i = 0
  @while i < count
    res = res + "x"
    i = i + 1
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("ADVERSARIAL SUITE: STRING BOUNDARIES & DYNAMICS")
  println("=================================================================")

  let passed = 0
  let total = 0

  @! -------------------------------------------------------------
  @! 1. Empty Strings
  @! -------------------------------------------------------------
  println("▶ Section 1: Empty String Boundaries")

  total = total + 1
  let empty_s = ""
  @if empty_s.len() == 0
    passed = passed + 1
    println("  [PASS] ST1.1: Empty string length is 0")
  @else
    println("  [FAIL] ST1.1: Empty string length is not 0")
  @end

  total = total + 1
  let empty_cat = "" + ""
  @if empty_cat == "" && empty_cat.len() == 0
    passed = passed + 1
    println("  [PASS] ST1.2: Empty string concatenation with empty string")
  @else
    println("  [FAIL] ST1.2: Empty string concatenation")
  @end

  total = total + 1
  let cat_left = "" + "maya"
  let cat_right = "maya" + ""
  @if cat_left == "maya" && cat_right == "maya"
    passed = passed + 1
    println("  [PASS] ST1.3: Empty string left/right identity concatenation")
  @else
    println("  [FAIL] ST1.3: Empty string left/right concatenation")
  @end

  total = total + 1
  @if ("" == "") && ("" != "nonempty") && !("" == "nonempty")
    passed = passed + 1
    println("  [PASS] ST1.4: Empty string equality and inequality")
  @else
    println("  [FAIL] ST1.4: Empty string equality/inequality")
  @end

  total = total + 1
  let sw_empty = starts_with("maya", "")
  let ew_empty = ends_with("maya", "")
  let ct_empty = contains("maya", "")
  @if sw_empty == 1 && ew_empty == 1 && ct_empty == 1
    passed = passed + 1
    println("  [PASS] ST1.5: String starts_with / ends_with / contains empty prefix")
  @else
    println("  [FAIL] ST1.5: Empty string search matching")
  @end

  @! -------------------------------------------------------------
  @! 2. Multiline Strings & Escape Sequences
  @! -------------------------------------------------------------
  println("▶ Section 2: Multiline Strings & Escape Sequences")

  total = total + 1
  let escape_s = "Line1\nLine2\tTabbed\\Backslash\"Quote"
  @if escape_s.len() > 20 && escape_s.contains("\n") && escape_s.contains("\t")
    passed = passed + 1
    println("  [PASS] ST2.1: Escape sequences (\\n, \\t, \\\\, \\\") parsed correctly")
  @else
    println("  [FAIL] ST2.1: Escape sequences parsing")
  @end

  total = total + 1
  let multiline = "First Line
Second Line
Third Line"
  @if multiline.contains("Second Line") && multiline.contains("Third Line")
    passed = passed + 1
    println("  [PASS] ST2.2: Multiline literal string retains contents")
  @else
    println("  [FAIL] ST2.2: Multiline literal string")
  @end

  @! -------------------------------------------------------------
  @! 3. Concatenation Chains & Dynamic Loop Construction
  @! -------------------------------------------------------------
  println("▶ Section 3: Concatenation Chains & Stress")

  total = total + 1
  let chain = "a" + "b" + "c" + "d" + "e" + "f" + "g" + "h" + "i" + "j"
  @if chain == "abcdefghij" && chain.len() == 10
    passed = passed + 1
    println("  [PASS] ST3.1: 10-element binary concatenation chain")
  @else
    println("  [FAIL] ST3.1: 10-element binary concatenation chain")
  @end

  total = total + 1
  let dynamic_100 = build_dynamic_string("init_", 50)
  @if dynamic_100.len() == 55 && dynamic_100.starts_with("init_") && dynamic_100.ends_with("xxxx")
    passed = passed + 1
    println("  [PASS] ST3.2: Dynamic 50-iteration loop string concatenation (len = 55)")
  @else
    println("  [FAIL] ST3.2: Dynamic loop string concatenation")
  @end

  total = total + 1
  let num_str = "Count: " + (42).to_str() + ", Status: " + (1 == 1).to_str()
  @if num_str == "Count: 42, Status: true"
    passed = passed + 1
    println("  [PASS] ST3.3: Mixed string concatenation with .to_str() conversions")
  @else
    println("  [FAIL] ST3.3: Mixed string concatenation")
  @end

  @! -------------------------------------------------------------
  @! 4. Dynamic String Equality & Comparison
  @! -------------------------------------------------------------
  println("▶ Section 4: Dynamic String Equality")

  total = total + 1
  let part1 = "llvm_"
  let part2 = "backend"
  let combined = part1 + part2
  let target = "llvm_backend"
  @if combined == target && !(combined != target)
    passed = passed + 1
    println("  [PASS] ST4.1: Dynamic string equal to literal target")
  @else
    println("  [FAIL] ST4.1: Dynamic string equality")
  @end

  total = total + 1
  let diff1 = part1 + "1"
  let diff2 = part1 + "2"
  @if diff1 != diff2 && !(diff1 == diff2)
    passed = passed + 1
    println("  [PASS] ST4.2: Dynamic strings differing by last character")
  @else
    println("  [FAIL] ST4.2: Dynamic strings inequality")
  @end

  total = total + 1
  let comp_a = "abc" + "def"
  let comp_b = "ab" + "cdef"
  @if comp_a == comp_b
    passed = passed + 1
    println("  [PASS] ST4.3: Identical dynamic strings constructed from different parts")
  @else
    println("  [FAIL] ST4.3: Identical dynamic strings constructed differently")
  @end

  @! -------------------------------------------------------------
  @! 5. String Builtin Utilities
  @! -------------------------------------------------------------
  println("▶ Section 5: String Builtin Utilities")

  total = total + 1
  let trimmed = str_trim("   maya_lang   ")
  @if trimmed == "maya_lang"
    passed = passed + 1
    println("  [PASS] ST5.1: str_trim removes leading and trailing whitespace")
  @else
    println("  [FAIL] ST5.1: str_trim")
  @end

  total = total + 1
  let upper = str_to_upper("maya_compiler")
  let lower = str_to_lower("MAYA_COMPILER")
  @if upper == "MAYA_COMPILER" && lower == "maya_compiler"
    passed = passed + 1
    println("  [PASS] ST5.2: str_to_upper and str_to_lower case transformations")
  @else
    println("  [FAIL] ST5.2: Case transformations")
  @end

  total = total + 1
  let idx1 = str_index_of("programming in maya", "maya")
  let idx2 = str_index_of("programming in maya", "rust")
  @if idx1 == 15 && idx2 == -1
    passed = passed + 1
    println("  [PASS] ST5.3: str_index_of substring search (found = 15, not found = -1)")
  @else
    println("  [FAIL] ST5.3: str_index_of")
  @end

  total = total + 1
  let replaced = str_replace("banana bread", "a", "o")
  @if replaced == "bonono breod"
    passed = passed + 1
    println("  [PASS] ST5.4: str_replace character replacement")
  @else
    println("  [FAIL] ST5.4: str_replace")
  @end

  total = total + 1
  let ch_a = str_from_char_code(65)
  let ch_z = str_from_char_code(90)
  @if ch_a == "A" && ch_z == "Z"
    passed = passed + 1
    println("  [PASS] ST5.5: str_from_char_code ASCII conversions (65->A, 90->Z)")
  @else
    println("  [FAIL] ST5.5: str_from_char_code")
  @end

  println("=================================================================")
  println("STRING TESTS SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    return 0
  @else
    return 1
  @end
@end
