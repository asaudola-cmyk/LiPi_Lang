@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — NATIVE GUI CODE EDITOR APP TEST SUITE
@! File: tests/gui/test_gui_editor_app.maya
@! Milestone: M2 / E2E Track (Native GUI Applications)
@! 100% Pure Maya Implementation (@struct, @fn) — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/layout"
import "universe/gui/event"
import "universe/gui/widget"
import "universe/gui/compositor"
import "apps/gui_editor"

@! ============================================================================
@! 1. ASSERTION FRAMEWORK HELPERS
@! ============================================================================

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

@! ============================================================================
@! 2. TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("📝 MAYA GUI CODE EDITOR APPLICATION COMPREHENSIVE TEST SUITE 📝")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Editor Initialization & Buffer Geometry
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Editor App Initialization & Buffer Geometry...")
  
  app = editor_app_create(640, 480)
  total_tests = total_tests + 1
  ok1 = assert_eq_int(editor_app_get_line_count(app), 1, "Initial line count is 1")
  ok2 = assert_eq_str(editor_app_get_text(app), "", "Initial text is empty string")
  c_pos = editor_app_get_cursor(app)
  ok3 = assert_eq_int(c_pos.line, 0, "Initial cursor line is 0")
  ok4 = assert_eq_int(c_pos.col, 0, "Initial cursor col is 0")
  ok5 = assert_eq_int(app.width, 640, "Window width is 640")
  ok6 = assert_eq_int(app.height, 480, "Window height is 480")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Editor app initialization & geometry verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Text Insertion & Sequential Typing
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Text Insertion & Sequential Typing...")

  total_tests = total_tests + 1
  app = editor_app_type_string(app, "Hello, Maya!")
  ok1 = assert_eq_str(editor_app_get_text(app), "Hello, Maya!", "Typing string 'Hello, Maya!'")
  c_pos = editor_app_get_cursor(app)
  ok2 = assert_eq_int(c_pos.line, 0, "Cursor remains on line 0")
  ok3 = assert_eq_int(c_pos.col, 12, "Cursor advanced to col 12")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Character typing and cursor progression verified")
  @end

  total_tests = total_tests + 1
  app = editor_app_type_string(app, " Architecture")
  ok1 = assert_eq_str(editor_app_get_text(app), "Hello, Maya! Architecture", "Concatenation typing")
  c_pos = editor_app_get_cursor(app)
  ok2 = assert_eq_int(c_pos.col, 25, "Cursor at col 25")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Continuous stream typing verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Newline Splitting & Multi-Line Buffer
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Newline Splitting & Multi-Line Buffer Expansion...")

  total_tests = total_tests + 1
  app = editor_app_set_text(app, "Line 1\nLine 2\nLine 3")
  ok1 = assert_eq_int(editor_app_get_line_count(app), 3, "Buffer loaded with 3 lines")
  
  @! Position cursor on Line 2 (index 1) at column 4 ("Line" | " 2")
  app.state.cursor_line = 1
  app.state.cursor_col = 4
  app = editor_app_send_key(app, 13, "\n", 0) @! Send Enter
  
  ok2 = assert_eq_int(editor_app_get_line_count(app), 4, "Buffer split into 4 lines")
  ok3 = assert_eq_str(app.state.lines[0], "Line 1", "Line 0 unchanged")
  ok4 = assert_eq_str(app.state.lines[1], "Line", "Line 1 prefix kept")
  ok5 = assert_eq_str(app.state.lines[2], " 2", "Line 2 suffix moved to new line")
  ok6 = assert_eq_str(app.state.lines[3], "Line 3", "Line 3 shifted")
  c_pos = editor_app_get_cursor(app)
  ok7 = assert_eq_int(c_pos.line, 2, "Cursor moved to line 2")
  ok8 = assert_eq_int(c_pos.col, 0, "Cursor moved to col 0")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Mid-line newline splitting verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Backspace Character Deletion & Line Merging
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Backspace Deletion & Line Merging...")

  total_tests = total_tests + 1
  @! Press Backspace at (2, 0) to merge line 2 (" 2") into line 1 ("Line")
  app = editor_app_send_key(app, 8, "", 0)
  ok1 = assert_eq_int(editor_app_get_line_count(app), 3, "Lines merged back to 3")
  ok2 = assert_eq_str(app.state.lines[1], "Line 2", "Line 1 restored to 'Line 2'")
  c_pos = editor_app_get_cursor(app)
  ok3 = assert_eq_int(c_pos.line, 1, "Cursor restored to line 1")
  ok4 = assert_eq_int(c_pos.col, 4, "Cursor at merge junction col 4")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Line merging via backspace at col 0 verified")
  @end

  total_tests = total_tests + 1
  @! Backspace characters inside line
  app = editor_app_send_key(app, 8, "", 0) @! delete 'e'
  app = editor_app_send_key(app, 8, "", 0) @! delete 'n'
  ok1 = assert_eq_str(app.state.lines[1], "Li 2", "Characters deleted to 'Li 2'")
  c_pos = editor_app_get_cursor(app)
  ok2 = assert_eq_int(c_pos.col, 2, "Cursor at col 2")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Inline backspace character deletion verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Delete Key Forward Deletion & Next-Line Merging
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Delete Key Forward Deletion & Next-Line Merging...")

  total_tests = total_tests + 1
  app = editor_app_set_text(app, "ABC\nDEF")
  app.state.cursor_line = 0
  app.state.cursor_col = 0
  
  @! Forward delete 'A'
  app = editor_app_send_key(app, 46, "", 0)
  ok1 = assert_eq_str(app.state.lines[0], "BC", "Forward deleted 'A' -> 'BC'")
  
  @! Move to end of line 0
  app.state.cursor_col = 2
  @! Forward delete at end of line merges line 1 ("DEF") into line 0 ("BC")
  app = editor_app_send_key(app, 46, "", 0)
  ok2 = assert_eq_int(editor_app_get_line_count(app), 1, "Merged into 1 line")
  ok3 = assert_eq_str(editor_app_get_text(app), "BCDEF", "Merged text is 'BCDEF'")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Delete key forward deletion & next-line merge verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Cursor Navigation & Preferred Column Memory
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Cursor Navigation & Preferred Column Memory...")

  total_tests = total_tests + 1
  app = editor_app_set_text(app, "Short\nA very long line with twenty-eight chars\nTiny")
  
  @! Position cursor on Line 1 at col 20
  app.state.cursor_line = 1
  app.state.cursor_col = 20
  app.state.preferred_col = 20
  
  @! Move Up to line 0 (length 5) -> clamped to col 5
  app = editor_app_send_key(app, 38, "", 0) @! UP
  c1 = editor_app_get_cursor(app)
  ok1 = assert_eq_int(c1.line, 0, "Moved up to line 0")
  ok2 = assert_eq_int(c1.col, 5, "Clamped to end of short line (col 5)")
  
  @! Move Down back to line 1 (length 39) -> preferred_col 20 restored!
  app = editor_app_send_key(app, 40, "", 0) @! DOWN
  c2 = editor_app_get_cursor(app)
  ok3 = assert_eq_int(c2.line, 1, "Moved down to line 1")
  ok4 = assert_eq_int(c2.col, 20, "Restored preferred column 20")
  
  @! Test Home and End
  app = editor_app_send_key(app, 36, "", 0) @! HOME
  c3 = editor_app_get_cursor(app)
  ok5 = assert_eq_int(c3.col, 0, "Home moves cursor to col 0")
  
  app = editor_app_send_key(app, 35, "", 0) @! END
  c4 = editor_app_get_cursor(app)
  ok6 = assert_eq_int(c4.col, 40, "End moves cursor to col 40")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Preferred column persistence across vertical moves verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: Text Selection & Batch Replacement
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: Text Selection & Batch Replacement (Select All)...")

  total_tests = total_tests + 1
  app = editor_app_set_text(app, "Alpha\nBeta\nGamma")
  
  @! Select all using Ctrl+A (modifiers=2)
  app = editor_app_send_key(app, 65, "a", 2)
  ok1 = assert_true(app.state.selection.active, "Selection is active")
  ok2 = assert_eq_int(app.state.selection.start_line, 0, "Selection starts at line 0")
  ok3 = assert_eq_int(app.state.selection.start_col, 0, "Selection starts at col 0")
  ok4 = assert_eq_int(app.state.selection.end_line, 2, "Selection ends at line 2")
  ok5 = assert_eq_int(app.state.selection.end_col, 5, "Selection ends at col 5")
  
  @! Typing while text is selected replaces entire selection
  app = editor_app_type_string(app, "Replaced!")
  ok6 = assert_eq_str(editor_app_get_text(app), "Replaced!", "Selected buffer completely replaced")
  ok7 = assert_false(app.state.selection.active, "Selection deactivated after replacement")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full selection range and batch replacement verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 8: Viewport Scrolling & Long Document Handling
  @! ----------------------------------------------------------------------------
  println("▶ Section 8: Viewport Scrolling & Long Document Handling...")

  total_tests = total_tests + 1
  long_doc = ""
  i = 1
  @while i <= 60
    long_doc = long_doc + "Line " + i.to_str()
    @if i < 60 long_doc = long_doc + "\n" @end
    i = i + 1
  @end
  app = editor_app_set_text(app, long_doc)
  ok1 = assert_eq_int(editor_app_get_line_count(app), 60, "60-line document loaded")
  
  @! Move down 40 lines
  app.state.cursor_line = 40
  app.state.cursor_col = 0
  app = editor_ensure_cursor_visible(app)
  
  ok2 = assert_true(app.state.scroll_top_line > 0, "scroll_top_line adjusted to keep cursor in viewport")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dynamic viewport scrolling calculation verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 9: Visual Canvas Rasterization
  @! ----------------------------------------------------------------------------
  println("▶ Section 9: Visual Canvas Rendering & Pixel Inspection...")

  total_tests = total_tests + 1
  app = editor_app_set_text(app, "@fn main()\n  println(\"Hello\")\n@end")
  app = editor_app_render(app)
  
  title_px = canvas_get_pixel(app.canvas, 10, 10)
  gutter_px = canvas_get_pixel(app.canvas, 20, 30)
  editor_hl_px = canvas_get_pixel(app.canvas, 250, 30)
  status_px = canvas_get_pixel(app.canvas, 20, 470)
  
  ok1 = assert_eq_int(title_px, 0xFF007ACC, "Window title bar color (0xFF007ACC)")
  ok2 = assert_eq_int(gutter_px, 0xFF252526, "Line number gutter background (0xFF252526)")
  ok3 = assert_eq_int(editor_hl_px, 0xFF282828, "Active line highlight background (0xFF282828)")
  ok4 = assert_eq_int(status_px, 0xFF007ACC, "Status bar footer color (0xFF007ACC)")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complete Code Editor canvas rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 CODE EDITOR APP TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " GUI CODE EDITOR APP TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME GUI CODE EDITOR APP TESTS FAILED")
    return 1
  @end
@end
