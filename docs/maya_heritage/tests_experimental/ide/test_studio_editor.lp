@! ============================================================================
@! MAYA SOVEREIGN IDE — MULTI-LINE CODE EDITOR COMPREHENSIVE TEST SUITE
@! File: tests/ide/test_studio_editor.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/ide/syntax"
import "universe/ide/editor"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0
    println("  [FAIL] Assertion failed (expected false): " + msg)
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
  println("📝 MAYA STUDIO MULTI-LINE CODE EDITOR TEST SUITE 📝")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Editor Initialization & Buffer Geometry
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Studio Editor Initialization & Buffer Geometry...")
  total_tests = total_tests + 1

  thm = syntax_theme_default()
  ed = studio_editor_new("src/main.maya", "", thm)

  ok1 = assert_eq_int(studio_editor_get_line_count(ed), 1, "Initial line count is 1")
  ok2 = assert_eq_str(studio_editor_get_text(ed), "", "Initial text is empty string")
  ok3 = assert_eq_int(ed.cursor_line, 0, "Initial cursor line is 0")
  ok4 = assert_eq_int(ed.cursor_col, 0, "Initial cursor col is 0")
  ok5 = assert_eq_str(ed.file_name, "main.maya", "File name parsed as main.maya")
  ok6 = assert_true(ed.lsp.server.is_initialized, "In-process LSP client attached and initialized")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Studio editor initialization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Text Insertion & Typing Progression
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Text Insertion & Typing Progression...")
  total_tests = total_tests + 1

  ed = studio_editor_insert_text(ed, "let count = 100")
  ok1 = assert_eq_str(studio_editor_get_text(ed), "let count = 100", "Inserted text 'let count = 100'")
  ok2 = assert_eq_int(ed.cursor_col, 15, "Cursor progressed to col 15")
  ok3 = assert_true(ed.is_dirty, "Editor buffer marked dirty after edit")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Character typing and cursor progression verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Newline Splitting & Multi-Line Buffer
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Newline Splitting & Multi-Line Buffering...")
  total_tests = total_tests + 1

  sample = "@fn greet()\n  println(\"Hello\")\n@end"
  ed = studio_editor_set_text(ed, sample)
  ok1 = assert_eq_int(studio_editor_get_line_count(ed), 3, "Loaded 3 lines")

  @! Position cursor on Line 1 at col 9 ("  println" | "(\"Hello\")")
  ed.cursor_line = 1
  ed.cursor_col = 9
  ed = studio_editor_handle_key(ed, 13, "\n", 0) @! Enter

  ok2 = assert_eq_int(studio_editor_get_line_count(ed), 4, "Split into 4 lines")
  ok3 = assert_eq_str(ed.lines[1], "  println", "Prefix kept on line 1")
  ok4 = assert_eq_str(ed.lines[2], "(\"Hello\")", "Suffix moved to line 2")
  ok5 = assert_eq_int(ed.cursor_line, 2, "Cursor moved to line 2")
  ok6 = assert_eq_int(ed.cursor_col, 0, "Cursor moved to col 0")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Newline splitting verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Backspace Deletion & Line Merging
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Backspace Deletion & Line Merging...")
  total_tests = total_tests + 1

  @! Backspace at (2, 0) merges line 2 back into line 1
  ed = studio_editor_handle_key(ed, 8, "", 0)
  ok1 = assert_eq_int(studio_editor_get_line_count(ed), 3, "Merged back to 3 lines")
  ok2 = assert_eq_str(ed.lines[1], "  println(\"Hello\")", "Line 1 restored")
  ok3 = assert_eq_int(ed.cursor_line, 1, "Cursor back to line 1")
  ok4 = assert_eq_int(ed.cursor_col, 9, "Cursor at junction col 9")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Line merging via backspace verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Cursor Navigation & Preferred Column Memory
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Cursor Navigation & Preferred Column Memory...")
  total_tests = total_tests + 1

  ed = studio_editor_set_text(ed, "Short\nA very long line with twenty-eight chars\nTiny")
  ed.cursor_line = 1
  ed.cursor_col = 20
  ed.preferred_col = 20

  @! Move Up (line 0, len 5)
  ed = studio_editor_handle_key(ed, 38, "", 0) @! Up
  ok1 = assert_eq_int(ed.cursor_line, 0, "Moved up to line 0")
  ok2 = assert_eq_int(ed.cursor_col, 5, "Clamped to line 0 length")

  @! Move Down (line 1, len 39) -> preferred col 20 restored
  ed = studio_editor_handle_key(ed, 40, "", 0) @! Down
  ok3 = assert_eq_int(ed.cursor_line, 1, "Moved down to line 1")
  ok4 = assert_eq_int(ed.cursor_col, 20, "Preferred column 20 restored")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Preferred column persistence across lines verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Text Selection & Batch Replacement (Select All)
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Selection & Batch Replacement...")
  total_tests = total_tests + 1

  ed = studio_editor_set_text(ed, "Alpha\nBeta\nGamma")
  ed = studio_editor_handle_key(ed, 65, "a", 2) @! Ctrl+A

  ok1 = assert_true(ed.selection.active, "Selection is active")
  ok2 = assert_eq_int(ed.selection.start_line, 0, "Selection starts at line 0")
  ok3 = assert_eq_int(ed.selection.end_line, 2, "Selection ends at line 2")

  ed = studio_editor_insert_text(ed, "Replaced All")
  ok4 = assert_eq_str(studio_editor_get_text(ed), "Replaced All", "Entire buffer replaced")
  ok5 = assert_false(ed.selection.active, "Selection cleared after replacement")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Selection range and batch replacement verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: Visual Canvas Framebuffer Rasterization
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: Canvas Pixel Rasterization...")
  total_tests = total_tests + 1

  ed = studio_editor_set_text(ed, "@fn test()\n  let x = 42\n@end")
  c = canvas_new(640, 300)
  f = font_default()
  c = studio_editor_render(ed, c, f, 0, 0, 640, 300)

  @! Gutter pixel at (10, 10) should be 0xFF252526
  px_gut = canvas_get_pixel(c, 10, 10)
  ok1 = assert_eq_int(px_gut, 0xFF252526, "Gutter background color (0xFF252526)")

  @! Active line highlight pixel in editor area at (200, 4) should be 0xFF282828
  px_act = canvas_get_pixel(c, 200, 4)
  ok2 = assert_eq_int(px_act, 0xFF282828, "Active line highlight color (0xFF282828)")

  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Studio editor canvas rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 STUDIO EDITOR TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " STUDIO EDITOR TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME STUDIO EDITOR TESTS FAILED")
    return 1
  @end
@end
