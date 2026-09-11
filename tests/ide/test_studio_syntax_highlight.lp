@! ============================================================================
@! MAYA SOVEREIGN IDE — SYNTAX HIGHLIGHTING COMPREHENSIVE TEST SUITE
@! File: tests/ide/test_studio_syntax_highlight.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/lexer"
import "universe/ide/syntax"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🎨 MAYA STUDIO SYNTAX HIGHLIGHTING & THEME TEST SUITE 🎨")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Syntax Themes (Default Dark & Light)
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Syntax Theme Palettes...")
  total_tests = total_tests + 1
  dark = syntax_theme_default()
  light = syntax_theme_light()

  ok1 = assert_eq_int(dark.bg_editor, 0xFF1E1E1E, "Default editor background (0xFF1E1E1E)")
  ok2 = assert_eq_int(dark.col_directive, 0xFFC586C0, "Default directive color (0xFFC586C0)")
  ok3 = assert_eq_int(dark.col_keyword, 0xFF569CD6, "Default keyword color (0xFF569CD6)")
  ok4 = assert_eq_int(dark.col_type, 0xFF4EC9B0, "Default type color (0xFF4EC9B0)")
  ok5 = assert_eq_int(dark.col_string, 0xFFCE9178, "Default string color (0xFFCE9178)")
  ok6 = assert_eq_int(dark.col_number, 0xFFB5CEA8, "Default number color (0xFFB5CEA8)")
  ok7 = assert_eq_int(dark.col_comment, 0xFF6A9955, "Default comment color (0xFF6A9955)")
  ok8 = assert_eq_int(light.bg_editor, 0xFFFFFFFF, "Light editor background (0xFFFFFFFF)")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syntax theme palettes initialized successfully")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Token Classifier & Lexer Token Colorization
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Lexer Token Color Classification...")
  total_tests = total_tests + 1
  
  tok_dir = make_token_full("DIRECTIVE", "@fn", "@fn", 50, 1, 1, 0, 0.0)
  tok_kw = make_token_full("FN", "let", "let", 91, 1, 1, 0, 0.0)
  tok_str = make_token_full("STR", "hello", "\"hello\"", 45, 1, 1, 0, 0.0)
  tok_num = make_token_full("INT", "42", "42", 43, 1, 1, 42, 0.0)
  tok_comm = make_token_full("COMMENT", "// note", "// note", 0, 1, 1, 0, 0.0)

  c_dir = syntax_color_for_token(tok_dir, dark)
  c_kw = syntax_color_for_token(tok_kw, dark)
  c_str = syntax_color_for_token(tok_str, dark)
  c_num = syntax_color_for_token(tok_num, dark)
  c_comm = syntax_color_for_token(tok_comm, dark)

  ok1 = assert_eq_int(c_dir, dark.col_directive, "Directive token color matches theme")
  ok2 = assert_eq_int(c_kw, dark.col_keyword, "Keyword token color matches theme")
  ok3 = assert_eq_int(c_str, dark.col_string, "String token color matches theme")
  ok4 = assert_eq_int(c_num, dark.col_number, "Number token color matches theme")
  ok5 = assert_eq_int(c_comm, dark.col_comment, "Comment token color matches theme")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Lexer token color resolver verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Line Tokenization — Function & Directives
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Line Tokenization for Directives & Function Signatures...")
  total_tests = total_tests + 1

  line = "@fn calculate(val: i64) -> i64"
  spans = syntax_tokenize_line(line, dark)
  
  ok1 = assert_true(spans.len() >= 6, "Expected at least 6 spans for function signature")
  @! Span 0: @fn (DIRECTIVE, 0..3)
  s0 = spans[0]
  ok2 = assert_eq_str(s0.token_type, "DIRECTIVE", "Span 0 is DIRECTIVE")
  ok3 = assert_eq_int(s0.start_col, 0, "Span 0 start_col is 0")
  ok4 = assert_eq_int(s0.end_col, 3, "Span 0 end_col is 3")
  ok5 = assert_eq_int(s0.color, dark.col_directive, "Span 0 color is purple")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Function signature line tokenization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Line Tokenization — Variables, Strings, Numbers, Comments
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Line Tokenization for Expressions, Literals & Comments...")
  total_tests = total_tests + 1

  line2 = "let msg = \"Result: \" + 0x2A // inline comment"
  spans2 = syntax_tokenize_line(line2, dark)

  ok_kw = 0
  ok_str = 0
  ok_num = 0
  ok_comm = 0

  i = 0
  @while i < spans2.len()
    sp = spans2[i]
    @if sp.token_type == "KEYWORD" && sp.color == dark.col_keyword ok_kw = 1 @end
    @if sp.token_type == "STRING" && sp.color == dark.col_string ok_str = 1 @end
    @if sp.token_type == "NUMBER" && sp.color == dark.col_number ok_num = 1 @end
    @if sp.token_type == "COMMENT" && sp.color == dark.col_comment ok_comm = 1 @end
    i = i + 1
  @end

  ok1 = assert_eq_int(ok_kw, 1, "Found keyword span 'let'")
  ok2 = assert_eq_int(ok_str, 1, "Found string span '\"Result: \"'")
  ok3 = assert_eq_int(ok_num, 1, "Found hex number span '0x2A'")
  ok4 = assert_eq_int(ok_comm, 1, "Found comment span '// inline comment'")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multi-construct expression tokenization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 SYNTAX HIGHLIGHT TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " SYNTAX HIGHLIGHTING TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME SYNTAX HIGHLIGHTING TESTS FAILED")
    return 1
  @end
@end
